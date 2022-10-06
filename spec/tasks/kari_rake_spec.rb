# frozen_string_literal: true

require "spec_helper"
require "rake"

Rails.application.load_tasks

RSpec.describe "rake tasks" do
  before do
    allow(Kari.configuration).to receive(:tenants).and_return(%w[acme foo-inc star])
  end

  describe "kari:create" do
    subject { -> { capture_rake_task_output("kari:create") } }

    before do
      allow(Kari).to receive(:exists?).and_return(false)
      # acme already exists
      allow(Kari).to receive(:exists?).with("acme").and_return(true)
    end

    specify do
      expect(Kari).to receive(:create).with("foo-inc")
      expect(Kari).to receive(:create).with("star")
      expect(Kari).not_to receive(:create).with("acme")
      subject.call
    end
  end

  describe "kari:drop" do
    subject { -> { capture_rake_task_output("kari:drop") } }

    before do
      allow(Kari).to receive(:exists?).and_return(false)
      # acme already exists
      allow(Kari).to receive(:exists?).with("acme").and_return(true)
    end

    specify do
      expect(Kari).not_to receive(:drop).with("foo-inc")
      expect(Kari).not_to receive(:drop).with("star")
      expect(Kari).to receive(:drop).with("acme")
      subject.call
    end
  end

  describe "kari:migrate" do
    subject { -> { capture_rake_task_output("kari:migrate") } }

    before do
      allow(Kari).to receive(:exists?).and_return(false)
      # acme exists
      allow(Kari).to receive(:exists?).with("acme").and_return(true)
    end

    specify do
      expect(ActiveRecord::Tasks::DatabaseTasks).to receive(:migrate) do
        expect(Kari.current_tenant).to eq "acme"
      end

      subject.call
    end
  end

  describe "kari:seed" do
    subject { -> { capture_rake_task_output("kari:seed") } }

    before do
      allow(Kari).to receive(:exists?).and_return(false)

      allow(Kari).to receive(:exists?).with("acme").and_return(true)
      allow(Kari).to receive(:exists?).with("star").and_return(true)
    end

    specify do
      expect(Kari).not_to receive(:seed).with("foo-inc")
      expect(Kari).to receive(:seed).with("star")
      expect(Kari).to receive(:seed).with("acme")

      subject.call
    end
  end

  describe "kari:rollback" do
    subject { -> { capture_rake_task_output("kari:rollback") } }

    let(:conn) { double }
    let(:migration_context) { double }

    before do
      allow(Kari).to receive(:exists?).and_return(false)

      allow(Kari).to receive(:exists?).with("acme").and_return(true)
      allow(Kari).to receive(:exists?).with("star").and_return(true)

      allow(ActiveRecord::Base).to receive(:connection).and_return(conn)
      allow(conn).to receive(:migration_context).and_return(migration_context)
    end

    specify do
      expect(migration_context).to receive(:rollback).twice do
        expect(Kari.current_tenant).to be_in %w[acme star]
      end

      subject.call
    end

    context "with STEP given" do
      before { ENV["STEP"] = "42" }

      specify do
        expect(migration_context).to receive(:rollback).with(42).twice
        subject.call
      end
    end
  end

  describe "kari:migrate:up" do
    let(:conn) { double }
    let(:migration_context) { double }

    before do
      allow(Kari).to receive(:exists?).and_return(false)

      allow(Kari).to receive(:exists?).with("acme").and_return(true)
      allow(Kari).to receive(:exists?).with("star").and_return(true)

      allow(ActiveRecord::Base).to receive(:connection).and_return(conn)
      allow(conn).to receive(:migration_context).and_return(migration_context)
    end

    describe "kari:migrate:up" do
      subject { -> { capture_rake_task_output("kari:migrate:up") } }

      specify do
        expect(migration_context).to receive(:run).with(:up, nil).twice do
          expect(Kari.current_tenant).to be_in %w[acme star]
        end

        subject.call
      end

      context "with VERSION given" do
        before { stub_const("ENV", { "VERSION" => "20221003075254" }) }

        specify do
          expect(migration_context).to receive(:run).with(:up, 20_221_003_075_254).twice
          subject.call
        end
      end
    end

    describe "kari:migrate:down" do
      subject { -> { capture_rake_task_output("kari:migrate:down") } }

      specify do
        expect(migration_context).to receive(:run).with(:down, nil).twice do
          expect(Kari.current_tenant).to be_in %w[acme star]
        end

        subject.call
      end

      context "with VERSION given" do
        before { stub_const("ENV", { "VERSION" => "20221003075254" }) }

        specify do
          expect(migration_context).to receive(:run).with(:down, 20_221_003_075_254).twice
          subject.call
        end
      end
    end
  end

  context "with ENV['TENANT'] specified" do
    subject { -> { capture_rake_task_output("kari:drop") } }

    before { allow(Kari).to receive(:exists?).and_return(true) }
    before { stub_const("ENV", { "TENANT" => "foo,bar" }) }

    specify do
      expect(Kari).to receive(:drop).with("foo")
      expect(Kari).to receive(:drop).with("bar")

      subject.call
    end
  end

  def capture_rake_task_output(task_name)
    stdout = StringIO.new
    $stdout = stdout
    Rake::Task[task_name].invoke
    $stdout = STDOUT
    Rake.application[task_name].reenable
    stdout.string
  end
end
