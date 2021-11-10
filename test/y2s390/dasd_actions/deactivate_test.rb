require_relative "../../test_helper.rb"
require "y2s390/dasd_actions/deactivate"

describe Y2S390::DasdActions::Deactivate do
  let(:action) { described_class.new(selected) }
  let(:selected) { Y2S390::DasdsCollection.new([dasd_0150, dasd_0fff]) }
  let(:dasd_0150) { Y2S390::Dasd.new("0.0.0150", status: "offline") }
  let(:dasd_0fff) { Y2S390::Dasd.new("0.0.0fff", status: "offline") }
  let(:controller) { Yast::DASDController }

  describe "#run" do
    let(:format_now) { false }

    before do
      allow(controller).to receive(:ProbeDisks)
      allow(action).to receive(:deactivate)
    end

    it "iterates over the the selected DASDs deactivating them" do
      expect(action).to receive(:deactivate).with(dasd_0150)
      expect(action).to receive(:deactivate).with(dasd_0fff)

      action.run
    end

    it "reloads the DASDs configuration forcing a probe of the disks" do
      expect(controller).to receive(:ProbeDisks)
      action.run
    end

    it "returns true" do
      expect(action.run).to eql(true)
    end
  end
end
