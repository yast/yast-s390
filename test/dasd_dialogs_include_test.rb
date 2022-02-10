#!/usr/bin/env rspec

require_relative "./test_helper"

require_relative "../src/include/s390/dasd/dialogs.rb"

describe Yast::S390DasdDialogsInclude do
  subject do
    # create an anonymous YaST module for testing
    instance = Yast::Module.new
    Yast.include instance, "s390/dasd/dialogs.rb"
    instance
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("S390_MOCKING").and_return(true)
    Yast::DASDController.ProbeDisks()
  end

  describe "#item_elements_for" do
    let(:config_mode) { false }
    let(:dasd) { Yast::DASDController.devices.by_id("0.0.0150") }

    before do
      allow(Yast::Mode).to receive(:config).and_return(config_mode)
    end

    it "returns an array" do
      expect(subject.item_elements_for(dasd)).to be_a(Array)
    end

    it "returns the Term ID as the first element" do
      expect(subject.item_elements_for(dasd)[0]).to be_a(Yast::Term)
      expect(subject.item_elements_for(dasd)[0].value).to eql(:id)
    end

    context "unless it is in config Mode" do
      context "when the DASD is not active" do
        before do
          allow(dasd).to receive(:active?).and_return(false)
        end

        it "includes the DASD id, if diag access is active and '--' for the rest of elements" do
          expect(subject.item_elements_for(dasd)[1..-1])
            .to eql([dasd.id, "--", "--", "--", "No", "--", "--"])
        end
      end

      context "when the DASD is active" do
        it "includes the DASD id, device path, dasd type, type of access, format, use diag.." do
          expect(subject.item_elements_for(dasd)[1..-1]).to eql(
            [dasd.id, "/dev/dasdb", "3990/E9 3390/0A", "RW", "No", "No", ""]
          )
        end
      end
    end

    context "in config Mode" do
      let(:config_mode) { true }

      it "includes the DASD id, format is wanted, use diag is wanted" do
        expect(subject.item_elements_for(dasd)[1..-1]).to eql([dasd.id, "No", "No"])
        dasd.format_wanted = true
        dasd.diag_wanted = true
        expect(subject.item_elements_for(dasd)[1..-1]).to eql([dasd.id, "Yes", "Yes"])
      end
    end
  end
end
