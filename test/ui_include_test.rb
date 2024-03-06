#!/usr/bin/env rspec

require_relative "./test_helper"

require_relative "../src/include/s390/dump/ui"

Yast.import "Wizard"
Yast.import "Dump"

describe Yast::S390DumpUiInclude do
  subject do
    # create an anonymous YaST module for testing
    instance = Yast::Module.new
    Yast.include instance, "s390/dump/ui.rb"
    instance
  end

  describe "#DumpSequence" do
    before do
      allow(Yast::Wizard).to receive(:CreateDialog)
      allow(Yast::Wizard).to receive(:SetDesktopIcon)
      allow(Yast::Wizard).to receive(:CloseDialog)
      allow(Yast::Dump).to receive(:Read)
      allow(subject).to receive(:DumpDialog)
    end

    it "opens a new dialog and sets the icon" do
      expect(Yast::Wizard).to receive(:CreateDialog)
      expect(Yast::Wizard).to receive(:SetDesktopIcon)
      subject.DumpSequence
    end

    it "closes the dialog at the end" do
      expect(Yast::Wizard).to receive(:CloseDialog)
      subject.DumpSequence
    end

    it "returns the result of the DumpDialog call" do
      ret = :next
      allow(subject).to receive(:DumpDialog).and_return(ret)
      # "equal" checks the object identity (the object ID)
      expect(subject.DumpSequence).to equal(ret)
    end

    context "when #DumpDialog returns :again" do
      before do
        allow(subject).to receive(:DumpDialog).and_return(:again, :next)
      end

      it "displays the dialog again if the dialog result is :again" do
        expect(subject).to receive(:DumpDialog).twice.and_return(:again, :next)
        subject.DumpSequence
      end

      it "reinitializes the devices again" do
        expect(Yast::Dump).to receive(:Read).twice
        subject.DumpSequence
      end
    end
  end

  describe "#DumpDialog" do
    # selected device
    let(:device) { "device" }
    # "force" check button state
    let(:force) { true }

    before do
      allow(Yast::Wizard).to receive(:SetContentsButtons)
      allow(Yast::Wizard).to receive(:HideBackButton)
      allow(Yast::Wizard).to receive(:SetAbortButton)
      allow(Yast::Dump).to receive(:dasd_disks).and_return([])
      allow(Yast::Dump).to receive(:zfcp_disks).and_return([])
      # success
      allow(Yast::Dump).to receive(:FormatDisk).and_return(true)
      allow(Yast::UI).to receive(:ChangeWidget)

      # finish, do not format yet another device
      allow(Yast::Popup).to receive(:YesNo).with(/success/).and_return(false)
      # confirm formatting
      allow(Yast::Popup).to receive(:YesNo).with(/Continue?/).and_return(true)
      # the "Force" check box is not selected
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:force), :Value)
        .and_return(force)
      # "ZFCP" radio button is selected
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:disk), :CurrentButton)
        .and_return(:zfcp)
      # selected device in the ZFCP disks ComboBox
      allow(Yast::UI).to receive(:QueryWidget).with(Id(:zfcp_disks), :Value)
        .and_return(device)
    end

    context "[Abort] button is pressed" do
      before do
        expect(Yast::UI).to receive(:UserInput).and_return(:abort)
      end

      it "does not format any disk" do
        expect(Yast::Dump).to_not receive(:FormatDisk)
        subject.DumpDialog
      end

      it "returns :abort symbol" do
        expect(subject.DumpDialog).to eq(:abort)
      end
    end

    context "[Next] button is pressed" do
      before do
        expect(Yast::UI).to receive(:UserInput).and_return(:next)
      end

      RSpec.shared_examples "returned symbol" do
        it "returns :cancel on success" do
          # success
          expect(Yast::Dump).to receive(:FormatDisk).and_return(true)
          expect(subject.DumpDialog).to eq(:cancel)
        end

        it "returns :again on failure" do
          # success
          expect(Yast::Dump).to receive(:FormatDisk).and_return(false)
          expect(subject.DumpDialog).to eq(:again)
        end
      end

      context "ZFCP radio button is selected" do
        let(:device) { "ZFCP_Device" }
        before do
          # "ZFCP" radio button is selected
          expect(Yast::UI).to receive(:QueryWidget).with(Id(:disk), :CurrentButton)
            .and_return(:zfcp)
          # selected device in the ZFCP disks ComboBox
          expect(Yast::UI).to receive(:QueryWidget).with(Id(:zfcp_disks), :Value)
            .and_return(device)
        end

        include_examples "returned symbol"

        it "Formats the selected device" do
          # success
          expect(Yast::Dump).to receive(:FormatDisk).with(device, force).and_return(true)
          subject.DumpDialog
        end
      end

      context "DASD radio button is selected" do
        let(:device) { "DASD_Device" }
        let(:device2) { "DASD_Device2" }

        before do
          # "DASD" radio button is selected
          expect(Yast::UI).to receive(:QueryWidget).with(Id(:disk), :CurrentButton)
            .and_return(:dasd)
          # selected device in the DASD disks ComboBox
          allow(Yast::UI).to receive(:QueryWidget).with(Id(:dasd_disks), :SelectedItems)
            .and_return([device])
        end

        include_examples "returned symbol"

        it "Formats the selected device" do
          # selected device in the DASD disks ComboBox
          expect(Yast::UI).to receive(:QueryWidget).with(Id(:dasd_disks), :SelectedItems)
            .and_return([device])
          # success
          expect(Yast::Dump).to receive(:FormatDisk).with(device, force).and_return(true)
          subject.DumpDialog
        end

        it "Formats all selected devices" do
          expect(Yast::UI).to receive(:QueryWidget).with(Id(:dasd_disks), :SelectedItems)
            .and_return([device, device2])
          # success
          expect(Yast::Dump).to receive(:FormatDisk).with("#{device} #{device2}", force).and_return(true)
          subject.DumpDialog
        end
      end
    end
  end
end
