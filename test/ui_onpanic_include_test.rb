#!/usr/bin/env rspec

require_relative "./test_helper"

require_relative "../src/include/s390/onpanic/ui.rb"

Yast.import "Wizard"
Yast.import "OnPanic"

describe Yast::S390OnpanicUiInclude do
  subject do
    # create an anonymous YaST module for testing
    instance = Yast::Module.new
    Yast.include instance, "s390/onpanic/ui.rb"
    instance
  end

  describe "#OnPanicSequence" do

    let(:ret) { :next }

    before do
      allow(Yast::Wizard).to receive(:CreateDialog)
      allow(Yast::Wizard).to receive(:SetDesktopIcon)
      allow(Yast::Wizard).to receive(:CloseDialog)
      allow(Yast::OnPanic).to receive(:Read)
      allow(subject).to receive(:OnPanicDialog).and_return(ret)
    end

    it "opens a new dialog and sets the icon" do
      expect(Yast::Wizard).to receive(:CreateDialog)
      expect(Yast::Wizard).to receive(:SetDesktopIcon)
      subject.OnPanicSequence
    end

    it "closes the dialog at the end" do
      expect(Yast::UI).to receive(:CloseDialog)
      subject.OnPanicSequence
    end

    it "returns the result of the OnPanicDialog call" do
      # "equal" checks the object identity (the object ID)
      expect(subject.OnPanicSequence).to equal(ret)
    end

    context "kdump is active while setup dumpconf" do
      it "asks the user to disable kdump" do
        expect(Yast::OnPanic).to receive(:start).and_return(true)
        expect(Yast::Service).to receive(:Enabled).with("kdump").and_return(true)
        allow(Yast::Service).to receive(:Active).with("kdump").and_return(false)
        expect(Yast::Popup).to receive(:YesNo).and_return(true)
        expect(Yast::Service).to receive(:Disable).with("kdump")
        subject.OnPanicSequence
      end
    end
    context "kdump is not active  while setup dumpconf" do
      it "does not ask the user and does not touch kdump" do
        expect(Yast::OnPanic).to receive(:start).and_return(true)
        expect(Yast::Service).to receive(:Enabled).with("kdump").and_return(false)
        allow(Yast::Service).to receive(:Active).with("kdump").and_return(false)
        expect(Yast::Popup).not_to receive(:YesNo)
        expect(Yast::Service).not_to receive(:Disable).with("kdump")
        subject.OnPanicSequence
      end
    end
  end

end
