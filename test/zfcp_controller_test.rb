#!/usr/bin/env rspec

require_relative "./test_helper"

Yast.import "ZFCPController"

describe "Yast::ZFCPController" do
  before do
    Yast::ZFCPController.main
  end

  describe "#ActivateDisk" do
    it "Activates the given disk" do
      expect(Yast::ZFCPController).to receive(:activate_controller).with("0.0.fc00")
      expect(Yast::SCR).to receive(:Execute)
        .with(anything, /\/sbin\/zfcp_disk_configure '0.0.fc00' '0x500' '0x401' 1/)
        .and_return(0)
      Yast::ZFCPController.ActivateDisk("0.0.fc00", "0x500", "0x401")
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
      allow(Yast::SCR).to receive(:Execute).with(anything, /\/sbin\/cio_ignore -r f800/).and_return(0)
    end

    it "activates the given controller" do
      expect(Yast::SCR).to receive(:Execute)
        .with(anything, /\/sbin\/zfcp_host_configure '0.0.fc00' 1/).and_return(0)
      expect(Yast::ZFCPController).to_not receive(:ReportControllerActivationError)
      Yast::ZFCPController.activate_controller(channel)
    end

    it "does not activate a controller twice" do
      expect(Yast::SCR).to receive(:Execute)
        .with(anything, /\/sbin\/zfcp_host_configure '0.0.fc00' 1/).once.and_return(0)
      Yast::ZFCPController.activate_controller(channel)
      Yast::ZFCPController.activate_controller(channel)
    end

    context "when the activation fails" do
      before do
        allow(Yast::SCR).to receive(:Execute)
          .with(anything, /\/sbin\/zfcp_host_configure '0.0.fc00' 1/).and_return(1)
      end

      it "reports the error" do
        expect(Yast::ZFCPController).to receive(:ReportControllerActivationError)
          .with("0.0.fc00", 1)
        Yast::ZFCPController.activate_controller(channel)
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
        Yast::ZFCPController.activate_controller(channel)
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
      expect(Yast::SCR).to receive(:Execute).with(anything, /\/sbin\/cio_ignore -r f800/).and_return(0)

      ctrls = Yast::ZFCPController.GetControllers
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
          Yast::ZFCPController.GetControllers
        end
      end

      context "in zKVM" do
        let(:is_zkvm) { true }
        it "does not report a warning" do
          expect(Yast::Report).to_not receive(:Warning).with(/Cannot evaluate ZFCP controllers/)
          Yast::ZFCPController.GetControllers
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

      expect(Yast::ZFCPController.Import(import_data)).to eq(true)
      expect(Yast::ZFCPController.GetDeviceIndex("0.0.f800", "", "")).to eq(2)
    end
  end

  describe "#ProbeDisks" do
    before do
      allow(Yast::SCR).to receive(:Read).with(Yast.path(".probe.disk")).once
        .and_return(load_data("probe_disk.yml"))
      allow(Yast::SCR).to receive(:Read).with(Yast.path(".probe.tape")).once.and_return([])
    end

    it "Probing disk" do
      expect(Yast::ZFCPController.ProbeDisks()).to eq(nil)
      expect(Yast::ZFCPController.devices).to eq(load_data("device_list.yml"))
    end
  end

  describe "#GetFilteredDevices" do
    it "Filters the devices" do
      import_data = { "devices" => [{ "controller_id" => "0.0.fa00" },
                                    { "controller_id" => "0.0.fb00" },
                                    { "controller_id" => "0.0.fc00" },
                                    { "controller_id" => "0.0.f800" },
                                    { "controller_id" => "0.0.f900" }] }

      expect(Yast::ZFCPController.Import(import_data)).to eq(true)
      Yast::ZFCPController.filter_max = Yast::ZFCPController.FormatChannel("0.0.FA00")
      Yast::ZFCPController.filter_min = Yast::ZFCPController.FormatChannel("0.0.f900")
      expect(Yast::ZFCPController.GetFilteredDevices()).to eq(
        0 => { "detail"=>{ "controller_id" => "0.0.fa00", "wwpn" => "", "fcp_lun" => "" } },
        4 => { "detail"=>{ "controller_id" => "0.0.f900", "wwpn" => "", "fcp_lun" => "" } }
      )
    end
  end
end
