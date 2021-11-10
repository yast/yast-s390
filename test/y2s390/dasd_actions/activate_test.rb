require_relative "../../test_helper.rb"
require "y2s390/dasd_actions/activate"

describe Y2S390::DasdActions::Activate do
  let(:action) { described_class.new(selected) }
  let(:selected) { Y2S390::DasdsCollection.new([dasd_0150, dasd_0160, dasd_0fff]) }
  let(:dasd_0150) { Y2S390::Dasd.new("0.0.0150", status: "offline") }
  let(:dasd_0160) { Y2S390::Dasd.new("0.0.0160", status: "offline") }
  let(:dasd_0fff) { Y2S390::Dasd.new("0.0.0fff", status: "offline") }
  let(:controller) { Yast::DASDController }

  describe "#run" do
    let(:format_now) { false }

    before do
      allow(controller).to receive(:ProbeDisks)
      allow(controller).to receive(:FormatDisks)
      allow(action).to receive(:format_now?).and_return(format_now)
      allow(action).to receive(:activate)
    end

    it "iterates over the the selected DASDs trying to active them" do
      expect(action).to receive(:activate).with(dasd_0160)
      expect(action).to receive(:activate).with(dasd_0fff)
      # test method call through activate
      allow(action).to receive(:activate).with(dasd_0150).and_call_original
      expect(controller).to receive(:ActivateDisk).with(dasd_0150.id, false)

      action.run
    end

    context "when some of the the activated DASD is unformatted" do
      let(:to_format) { [dasd_0150] }

      before do
        allow(action).to receive(:activate).with(dasd_0150).and_return(8)
        allow(action).to receive(:activate).with(dasd_0160).and_return(0)
        allow(action).to receive(:activate).with(dasd_0fff).and_return(0)
      end

      it "asks for formatting the unformatted devices" do
        expect(action).to receive(:format_now?).with(to_format)
        action.run
      end

      context "when the user approve to format the unformatted disks" do
        let(:format_now) { true }

        before do
          allow(action).to receive(:device_for!).with(dasd_0150).and_return("dasda")
        end

        it "formats the unformatted disks wich has a device name and activates them" do
          expect(controller).to receive(:FormatDisks).with(to_format)
          expect(action).to receive(:activate).with(dasd_0150)
          action.run
        end
      end

      context "when the user does not approve to format the unformatted disks" do
        it "reloads the DASDs configuration forcing a probe of the disks" do
          expect(controller).to receive(:ProbeDisks)
          action.run
        end
      end

      it "returns true" do
        expect(action.run).to eql(true)
      end
    end
  end

  describe "#format_now?" do
    let(:to_format) { [dasd_0150] }
    let(:auto) { false }

    before do
      allow(action).to receive(:auto_mode?).and_return(auto)
    end

    context "during Autoinstallation" do
      let(:auto) { true }

      it "returns false" do
        expect(action.send(:format_now?, to_format)).to eql(false)
      end
    end

    context "when the unformatted disk list is empty?" do
      it "returns false" do
        expect(action.send(:format_now?, [])).to eql(false)
      end
    end

    context "when the unformatted disk list only has one disk" do

      it "shows a popup asking for formatting that specific disk" do
        expect(Yast::Popup).to receive(:ContinueCancel)
          .with("Device 0.0.0150 is not formatted. Format device now?")

        action.send(:format_now?, to_format)
      end
    end

    context "when the unformatted disk list only has more than one disk" do
      let(:to_format) { [dasd_0150, dasd_0160] }

      it "shows a popup asking for formatting all of them" do
        expect(Yast::Popup).to receive(:ContinueCancel)
          .with("There are 2 unformatted devices. Format them now?")

        action.send(:format_now?, to_format)
      end
    end
  end

  describe "#device_for!" do
    let(:device_name) { "dasda" }

    before do
      allow(dasd_0150).to receive(:sys_device_name).and_return(device_name)
    end

    it "sets the dasd device name obtained from the sysfs" do
      expect { action.send(:device_for!, dasd_0150) }
        .to change { dasd_0150.device_name }.from(nil).to(device_name)
    end

    context "when there is no device associated with the given DASD" do
      let(:device_name) { nil }

      it "shows a popup error" do
        expect(Yast::Popup).to receive(:Error).with("Couldn't find device for channel 0.0.0150.")
        action.send(:device_for!, dasd_0150)
      end
    end
  end
end
