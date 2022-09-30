# frozen_string_literal: true

BEFORE = %w[db:drop].freeze
AFTER = %w[db:migrate db:create db:seed db:rollback db:migrate:up db:migrate:down].freeze

def kari_task_name(task_name)
  sub_task_name = task_name.split(":", 2).last
  "kari:#{sub_task_name}"
end

BEFORE.each do |task_name|
  task = Rake::Task[task_name]
  task.enhance([kari_task_name(task_name)])
end

AFTER.each do |task_name|
  task = Rake::Task[task_name]
  task.enhance do
    Rake::Task[kari_task_name(task_name)].invoke
  end
end

def each_tenant(&block)
  # TENANT=tenant1,tenant2 bundle exec rake db:migrate
  # can override default tenants
  tenants = if ENV['TENANT']
              ENV['TENANT'].split(',').map(&:strip)
            else
              begin
                Kari.tenants
              rescue ActiveRecord::StatementInvalid => ex
                $stderr.puts "Could not retrieve tenants. Maybe default schema was not initialized yet."
                []
              end
            end

  tenants.each(&block)
end

namespace :kari do
  desc "Create all tenants"
  task :create do
    each_tenant do |schema|
      if Kari.schema_exists?(tenant)
        puts "Schema for tenant '#{tenant}' does already exist, cannot create"
      else
        puts "Create schema #{schema}"
        Kari.create_schema(tenant)
      end
    end
  end

  desc "Drop all schemas"
  task :drop do
    each_tenant do |schema|
      if Kari.schema_exists?(schema)
        puts "Drop schema #{schema}"
        Kari.drop_schema(schema)
      else
        puts "Schema #{schema} does not exist, cannot drop"
      end
    end
  end

  desc "Migrate all schemas"
  task :migrate do
    each_tenant do |schema|
      if Kari.schema_exists?(schema)
        puts "Migrate schema #{schema}"
        Kari.process(schema) do
          ActiveRecord::Tasks::DatabaseTasks.migrate
        end
      else
        puts "Schema #{schema} does not exist, cannot migrate"
      end
    end
  end

  desc "Seed all schemas"
  task :seed do
    each_tenant do |schema|
      if Kari.schema_exists?(schema)
        puts "Seed schema #{schema}"
        Kari.seed_schema(schema)
      else
        puts "Schema #{schema} does not exist, cannot seed"
      end
    end
  end

  desc "Rolls schemas back to the previous version (specify steps w/ STEP=n)"
  task :rollback do
    step = ENV["STEP"]&.to_i || 1

    each_tenant do |schema|
      if Kari.schema_exists?(schema)
        puts "Rolling back schema #{schema}"
        Kari.process(schema) do
          ActiveRecord::Base.connection.migration_context.rollback(step)
        end
      else
        puts "Schema #{schema} does not exist, cannot rollback"
      end
    end
  end

  namespace :migrate do
    desc 'Runs the "up" for a given migration VERSION across all schemas'
    task :up do
      version = ActiveRecord::Tasks::DatabaseTasks.target_version

      each_tenant do |schema|
        if Kari.schema_exists?(schema)
          puts "Migrate schema #{schema} up to #{version}"
          Kari.process(schema) do
            ActiveRecord::Base.connection.migration_context.run(:up, version)
          end
        else
          puts "Schema #{schema} does not exist, cannot migrate up"
        end
      end
    end

    desc 'Runs the "down" for a given migration VERSION across all schemas'
    task :down do
      version = ActiveRecord::Tasks::DatabaseTasks.target_version

      each_tenant do |schema|
        if Kari.schema_exists?(schema)
          puts "Migrate schema #{schema} down to #{version}"
          Kari.process(schema) do
            ActiveRecord::Base.connection.migration_context.run(:down, version)
          end
        else
          puts "Schema #{schema} does not exist, cannot migrate down"
        end
      end
    end
  end
end
