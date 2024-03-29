#!/usr/bin/env rspec

require_relative "./test_helper"

Yast.import "ZFCPController"

describe Yast::ZFCPController do
  before do
    Yast::ZFCPController.main
  end

  describe "#ActivateDisk" do
    before do
      allow(Yast::Arch).to receive(:is_zkvm).and_return(false)
      allow(Yast::SCR).to receive(:Read).with(Yast.path(".probe.storage")).once
        .and_return(load_data("probe_storage.yml"))
      allow(Yast::SCR).to receive(:Read).with(Yast.path(".probe.disk")).once
        .and_return(load_data("probe_disk.yml"))
      allow(Yast::SCR).to receive(:Read).with(Yast.path(".probe.tape")).once.and_return([])
    end

    it "activates the controller and the given disk" do
      expect(subject).to receive(:activate_controller).with("0.0.fa00")
      expect(Yast::SCR).to receive(:Execute)
        .with(anything, /\/sbin\/zfcp_disk_configure '0.0.fa00' '0x500\d+' '0x401\d+' 1/)
        .and_return("exit" => "0", "stdout" => "")
      subject.ActivateDisk("0.0.fa00", "0x5000000000000000", "0x4010400000000000")
    end

    context "when the disk is already active" do
      it "does not try to active the given disk" do
        allow(subject).to receive(:activate_controller).with("0.0.fa00")
        expect(Yast::SCR).to_not receive(:Execute)
        subject.ActivateDisk("0.0.fa00", "0x500507630500873a", "0x4010400000000000")
      end
    end
  end

  describe "#activate_controller" do
    let(:channel) { "0.0.fc00" }

    before do
      allow(Yast::Arch).to receive(:is_zkvm).and_return(false)
      allow(Yast::SCR).to receive(:Read).with(Yast.path(".probe.storage")).once
        .and_return(load_data("probe_storage.yml"))

      # Removing all fcp devices from blacklist
      allow(Yast::SCR).to receive(:Execute).with(anything, /\/sbin\/vmcp q v fcp/).and_return(
        "exit"   => 0,
        "stdout" => "FCP  F800 ON FCP   F807 CHPID 1C SUBCHANNEL = 000B\n  F800 TOKEN = 0000000362A42C00"
      )
      allow(Yast::SCR).to receive(:Execute).with(anything, /\/sbin\/cio_ignore -r f800/)
        .and_return("exit" => "0", "stdout" => "")
    end

    it "activates the given controller" do
      expect(Yast::SCR)
        .to receive(:Execute).with(anything, /\/sbin\/zfcp_host_configure '0.0.fc00' 1/)
        .and_return("exit" => "0", "stdout" => "")
      expect(subject).to_not receive(:ReportControllerActivationError)
      subject.activate_controller(channel)
    end

    it "does not activate a controller twice" do
      expect(Yast::SCR)
        .to receive(:Execute).with(anything, /\/sbin\/zfcp_host_configure '0.0.fc00' 1/).once
        .and_return("exit" => "0", "stdout" => "")
      subject.activate_controller(channel)
      subject.activate_controller(channel)
    end

    context "when the activation fails" do
      before do
        allow(Yast::SCR)
          .to receive(:Execute).with(anything, /\/sbin\/zfcp_host_configure '0.0.fc00' 1/)
          .and_return("exit" => "1", "stdout" => "")
      end

      it "reports the error" do
        expect(subject).to receive(:ReportControllerActivationError)
          .with("0.0.fc00", 1)
        subject.activate_controller(channel)
      end
    end

    context "when the controller is already activated" do
      let(:channel) { "0.0.fa00" }

      before do
        allow(Yast::SCR).to receive(:Read).with(Yast.path(".probe.storage")).once
          .and_return(load_data("probe_storage.yml"))
      end

      it "does not activate the controller" do
        expect(Yast::SCR).to_not receive(:Execute).with(anything, /\/sbin\/zfcp_host_configure/)
        subject.activate_controller(channel)
      end
    end
  end

  describe "#GetControllers" do
    it "Returns all controllers" do
      allow(Yast::Arch).to receive(:is_zkvm).and_return(false)
      expect(Yast::SCR).to receive(:Read).with(Yast.path(".probe.storage")).once
        .and_return(load_data("probe_storage.yml"))

      # Removing all fcp devices from blacklist
      expect(Yast::SCR).to receive(:Execute).with(anything, /\/sbin\/vmcp q v fcp/).and_return(
        "exit"   => 0,
        "stdout" => "FCP  F800 ON FCP   F807 CHPID 1C SUBCHANNEL = 000B\n  F800 TOKEN = 0000000362A42C00"
      )
      expect(Yast::SCR)
        .to receive(:Execute).with(anything, /\/sbin\/cio_ignore -r f800/)
        .and_return("exit" => "0", "stdout" => "")

      ctrls = subject.GetControllers
      expect(ctrls).to contain_exactly(
        hash_including("sysfs_bus_id" => "0.0.f800"),
        hash_including("sysfs_bus_id" => "0.0.f900"),
        hash_including("sysfs_bus_id" => "0.0.fa00"),
        hash_including("sysfs_bus_id" => "0.0.fc00")
      )
      expect(ctrls.first["resource"]).to be_a(Hash)
    end

    context "no ZFCP controller found" do
      before do
        expect(Yast::SCR).to receive(:Read).with(Yast.path(".probe.storage")).once
          .and_return([])

        # Removing all fcp devices from blacklist
        expect(Yast::SCR).to receive(:Execute).with(anything, /\/sbin\/vmcp q v fcp/).and_return(
          "exit"   => -1,
          "stdout" => ""
        )
        expect(Yast::Arch).to receive(:is_zkvm).and_return(is_zkvm)
      end

      context "outside zKVM" do
        let(:is_zkvm) { false }
        it "reports a warning" do
          expect(Yast::Report).to receive(:Warning).with(/Cannot evaluate ZFCP controllers/)
          subject.GetControllers
        end
      end

      context "in zKVM" do
        let(:is_zkvm) { true }
        it "does not report a warning" do
          expect(Yast::Report).to_not receive(:Warning).with(/Cannot evaluate ZFCP controllers/)
          subject.GetControllers
        end
      end
    end
  end

  describe "#Import" do
    it "Imports the devices from a Hash" do
      import_data = { "devices" => [{ "controller_id" => "0.0.fa00" },
                                    { "controller_id" => "0.0.fc00" },
                                    { "controller_id" => "0.0.f800" },
                                    { "controller_id" => "0.0.f900" }] }

      expect(subject.Import(import_data)).to eq(true)
      expect(subject.GetDeviceIndex("0.0.f800", "", "")).to eq(2)
    end
  end

  describe "#ProbeDisks" do
    before do
      allow(Yast::SCR).to receive(:Read).with(Yast.path(".probe.disk")).once
        .and_return(load_data("probe_disk.yml"))
      allow(Yast::SCR).to receive(:Read).with(Yast.path(".probe.tape")).once.and_return([])
    end

    it "Probing disk" do
      expect(subject.ProbeDisks()).to eq(nil)
      expect(subject.devices).to eq(load_data("device_list.yml"))
    end
  end

  describe "#GetFilteredDevices" do
    it "Filters the devices" do
      import_data = { "devices" => [{ "controller_id" => "0.4.fa00" },
                                    { "controller_id" => "0.0.fb00" },
                                    { "controller_id" => "0.0.fc00" },
                                    { "controller_id" => "0.0.f800" },
                                    { "controller_id" => "0.0.f900" }] }

      expect(subject.Import(import_data)).to eq(true)
      subject.filter_max = subject.FormatChannel("10.0.FA00")
      subject.filter_min = subject.FormatChannel("0.0.f900")
      expect(subject.GetFilteredDevices()).to eq(
        0 => { "detail"=>{ "controller_id" => "0.4.fa00", "wwpn" => "", "fcp_lun" => "" } },
        1 => { "detail"=>{ "controller_id" => "0.0.fb00", "wwpn" => "", "fcp_lun" => "" } },
        2 => { "detail"=>{ "controller_id" => "0.0.fc00", "wwpn" => "", "fcp_lun" => "" } },
        4 => { "detail"=>{ "controller_id" => "0.0.f900", "wwpn" => "", "fcp_lun" => "" } }
      )
    end
  end
end
