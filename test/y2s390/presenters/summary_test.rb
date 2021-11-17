require_relative "../../test_helper"

require "cwm/rspec"
require "y2s390/presenters/summary"

describe Y2S390::Presenters::DasdSummary do
  subject { described_class.new(devices) }
  let(:devices) { Yast::DASDController.devices.by_ids(["0.0.0150", "0.0.0160"]) }

  mock_entries

  describe "#list" do
    before do
      Yast.import "DASDController"
      Yast::DASDController.ProbeDisks()
    end

    it "returns a summary of the dasds configuration" do
      dasd0160 = "Channel ID: 0.0.0160, Device: dasda, DIAG: No"
      dasd0150 = "Channel ID: 0.0.0150, Device: dasdb, DIAG: No"

      expect(subject.list).to include(dasd0150)
      expect(subject.list).to include(dasd0160)
    end
  end
end
