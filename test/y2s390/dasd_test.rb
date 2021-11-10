require_relative "../test_helper"
require "y2s390"

describe Y2S390::Dasd do
  subject { described_class.new("0.0.0150") }
  let(:dasda) { described_class.new("0.0.0150", status: "active", device_name: "dasda") }

  describe "#hex_id" do
    it "returns an integer representation of the channel ID" do
      expect(subject.hex_id).to be_a(Integer)
      expect(subject.hex_id).to eql("000150".hex)
    end
  end

  describe "#active?" do
    it "returns true if the DASD status is :active or :read_only" do
      expect(dasda.active?).to eql(true)
    end

    it "returns false if it is offline" do
      expect(subject.active?).to eql(false)
    end
  end

  describe "#offline?" do
    subject { described_class.new("0.0.0190", status: "offline") }

    it "returns true if the DASD status is offline" do
      expect(subject.offline?).to eql(true)
    end

    it "returns false if the DASD status is not offline" do
      expect(dasda.offline?).to eql(false)
    end
  end

  describe "#status=" do
    context "when given a known status" do
      it "sets the corresponding one" do
        expect { subject.status = "offline" }.to change { subject.status }
          .from(:unknown).to(:offline)
        expect { subject.status = "active" }.to change { subject.status }
          .from(:offline).to(:active)
        expect { subject.status = "active(ro)" }.to change { subject.status }
          .from(:active).to(:read_only)
      end
    end

    context "when the given status is not known" do
      subject { described_class.new("0.0.0190", status: "offline") }

      it "sets the status as :unknown" do
        expect { subject.status = "another" }.to change { subject.status }
          .from(:offline).to(:unknown)
      end
    end
  end

  describe "#formatted?" do
    it "returns true if the DASD device is formmated according to internal state" do
      subject.formatted = true
      expect(subject.formatted?).to eql(true)
    end

    it "returns false otherwise" do
      subject.formatted = nil
      expect(subject.formatted?).to eql(false)
      subject.formatted = false
      expect(subject.formatted?).to eql(false)
    end
  end
end
