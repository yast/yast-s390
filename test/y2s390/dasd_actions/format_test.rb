require_relative "../../test_helper.rb"
require "y2s390/dasd_actions/format"

describe Y2S390::DasdActions::Format do
  let(:action) { described_class.new(selected) }
  let(:selected) { Y2S390::DasdsCollection.new([dasd_0150, dasd_0fff]) }
  let(:dasd_0150) { Y2S390::Dasd.new("0.0.0150", status: "active", type: "ECKD") }
  let(:dasd_0fff) { Y2S390::Dasd.new("0.0.0fff", status: "active(ro)", type: "FBA") }
  let(:controller) { Yast::DASDController }

  describe "#run" do
    let(:format_now) { false }
    let(:config_mode) { false }
    let(:io_active) { false }

    before do
      allow(controller).to receive(:ProbeDisks)
      allow(controller).to receive(:FormatDisks)
      allow(Yast::Mode).to receive(:config).and_return(config_mode)
      allow(dasd_0150).to receive(:io_active?).and_return(io_active)
      allow(dasd_0fff).to receive(:io_active?).and_return(io_active)
      allow(dasd_0150).to receive(:access_type).and_return("rw")
      allow(dasd_0fff).to receive(:access_type).and_return("ro")
    end

    context "when at least one of the DASD devices is not active" do
      it "reports the problem" do
        expect(Yast::Popup).to receive(:Message).with(/Disk 0.0.0fff is not active/)

        action.run
      end

      it "does not format any disk" do
        expect(controller).to_not receive(:FormatDisks)
        action.run
      end

      it "returns false" do
        expect(action.run).to eql(false)
      end
    end

    context "when at least one of the DASD devices is not accessible for writing" do
      let(:io_active) { true }

      it "reports the problem" do
        expect(Yast::Popup).to receive(:Message).with(/Disk 0.0.0fff is not accessible for writing/)

        action.run
      end

      it "does not format any disk" do
        expect(controller).to_not receive(:FormatDisks)
        action.run
      end

      it "returns false" do
        expect(action.run).to eql(false)
      end
    end

    context "when at least one of the DASD devices is not a ECKD one" do
      let(:io_active) { true }
      before do
        dasd_0fff.status = "active"
        allow(dasd_0fff).to receive(:access_type).and_return("rw")
      end

      it "reports the problem" do
        expect(Yast::Popup).to receive(:Message).with(/Disk 0.0.0fff cannot be formatted/)

        action.run
      end

      it "does not format any disk" do
        expect(controller).to_not receive(:FormatDisks)
        action.run
      end

      it "returns false" do
        expect(action.run).to eql(false)
      end
    end

    context "when all the DASDs can be formatted" do
      before do
        allow(action).to receive(:can_be_formatted?).and_return(true)
        allow(action).to receive(:really_format?).and_return(true)
      end

      it "asks the user to confirm the format of the selected disks" do
        allow(action).to receive(:really_format?).and_call_original
        expect(Yast::Popup).to receive(:AnyQuestionRichText)
        action.run
      end

      context "and the user accepts to procceed with the format of the selected disks" do
        it "formats the selected DASDs" do
          expect(controller).to receive(:FormatDisks).with(selected)
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

      context "and the user does not accept to procceed with the format of the selected disks" do
        it "returns false" do
          allow(action).to receive(:really_format?).and_return(false)
          expect(action.run).to eql(false)
        end
      end

    end
  end
end

describe Y2S390::DasdActions::FormatOn do
  let(:action) { described_class.new(selected) }
  let(:selected) { Y2S390::DasdsCollection.new([dasd_0150, dasd_0fff]) }
  let(:dasd_0150) { Y2S390::Dasd.new("0.0.0150", status: "offline") }
  let(:dasd_0fff) { Y2S390::Dasd.new("0.0.0fff", status: "offline") }
  let(:controller) { Yast::DASDController }

  describe "#run" do
    it "iterates over the the selected DASDs setting the format wanted to true" do
      expect { action.run }.to change { dasd_0150.format_wanted }.from(nil).to(true)
        .and change { dasd_0fff.format_wanted }.from(nil).to(true)
    end
  end
end

describe Y2S390::DasdActions::FormatOff do
  let(:action) { described_class.new(selected) }
  let(:selected) { Y2S390::DasdsCollection.new([dasd_0150, dasd_0fff]) }
  let(:dasd_0150) { Y2S390::Dasd.new("0.0.0150", status: "offline") }
  let(:dasd_0fff) { Y2S390::Dasd.new("0.0.0fff", status: "offline") }
  let(:controller) { Yast::DASDController }

  describe "#run" do
    it "iterates over the the selected DASDs setting the format wanted to true" do
      expect { action.run }.to change { dasd_0150.format_wanted }.from(nil).to(false)
        .and change { dasd_0fff.format_wanted }.from(nil).to(false)
    end
  end
end