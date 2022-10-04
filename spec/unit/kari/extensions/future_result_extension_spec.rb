require "spec_helper"

RSpec.describe Kari::Extensions::FutureResultExtension do

  class MyFutureResult
    prepend Kari::Extensions::FutureResultExtension

    attr_reader :kwargs

    def initialize
      @kwargs = { init: 1 }
    end

    def schedule!(_session)
    end
  end

  let(:future_result) { MyFutureResult.new }
  let(:session) { double("sssion") }

  before do
    expect(Kari).to receive(:current_tenant).and_return(current_tenant)
  end

  let(:current_tenant) { "mytenant" }

  describe "#schedule!" do
    it "injects tenant" do
      expect { future_result.schedule!(session) }
        .to change { future_result.kwargs.to_a }.by([[:tenant, "mytenant"]])
    end
  end
end
