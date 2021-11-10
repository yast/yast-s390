require_relative "../../test_helper.rb"
require "y2s390/dasd_actions/base"

describe Y2S390::DasdActions::Base do
  subject { described_class.new(selected) }
  let(:selected) { Y2S390::DasdsCollection.new([]) }

  describe ".run" do
    it "creates a new object of the class and call its run method" do
      expect(described_class).to receive(:new).with(selected).and_return(subject)
      expect(subject).to receive(:run)

      described_class.run(selected)
    end
  end

  describe "#config_mode?" do
    let(:config_mode) { true }

    before do
      allow(Yast::Mode).to receive(:config).and_return(config_mode)
    end

    context "in Mode.config" do
      it "returns true" do
        expect(subject.config_mode?).to eq(true)
      end
    end

    context "in other Mode" do
      let(:config_mode) { false }

      it "returns false" do
        expect(subject.config_mode?).to eq(false)
      end
    end
  end

  describe "#auto_mode?" do
    let(:auto_mode) { true }

    before do
      allow(Yast::Mode).to receive(:autoinst).and_return(auto_mode)
    end

    context "in Mode.autoinst" do
      it "returns true" do
        expect(subject.auto_mode?).to eq(true)
      end
    end

    context "in other Mode" do
      let(:auto_mode) { false }

      it "returns false" do
        expect(subject.auto_mode?).to eq(false)
      end
    end
  end
end
