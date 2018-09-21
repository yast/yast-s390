#!/usr/bin/env rspec

require_relative "./test_helper"

Yast.import "DASDController"

describe "Yast::DASDController" do
  subject { Yast::DASDController }

  describe "#DeactivateDisk" do
    let(:channel) { "0.0.0160" }
    let(:diagnose) { false }
    let(:exit_code) { 0 }
    let(:command_result) { { "exit" => exit_code } }

    before do
      allow(Yast::Report).to receive(:Error)
      allow(Yast2::Popup).to receive(:show)
      allow(Yast::SCR).to receive(:Execute).and_return(command_result)
      allow(Yast::SCR).to receive(:Read)
        .with(Yast.path(".probe.disk")).once
        .and_return(load_data("probe_disk_dasd.yml"))

      subject.ProbeDisks()
    end

    it "redirects output to /dev/null" do
      expect(Yast::SCR).to receive(:Execute)
        .with(anything, /\/sbin\/dasd_configure .* < \/dev\/null/)

      subject.DeactivateDisk(channel, diagnose)
    end

    context "whit unknown exit code" do
      let(:command_result) do
        {
          "exit"   => exit_code,
          "stderr" => "Warning: ECKD DASD 0.0.0150 is unknown!\n" \
                      "The following unknown resources may be affected:\n" \
                      "- Mount point /unknown\n",
          "stdout" => "Continue with operation? (yes/no)"
        }
      end
      let(:exit_code) { "unknown" }

      it "reports an error with details" do
        expect(Yast2::Popup).to receive(:show).with(anything, hash_including(:headline, :details))

        subject.DeactivateDisk(channel, diagnose)
      end
    end

    context "when disk is being in use" do
      let(:exit_code) { 16 }

      it "returns nil" do
        expect(subject.DeactivateDisk(channel, diagnose)).to be_nil
      end

      context "and there are details to show" do
        let(:command_result) do
          {
            "exit"   => exit_code,
            "stderr" => "Warning: ECKD DASD 0.0.0150 is in use!\n" \
                        "The following resources may be affected:\n" \
                        "- Mount point /mnt\n",
            "stdout" => "Continue with operation? (yes/no)"
          }
        end

        it "reports an error with details" do
          expect(Yast2::Popup).to receive(:show).with(anything, hash_including(:headline, :details))

          subject.DeactivateDisk(channel, diagnose)
        end
      end

      context "and there are not details to show" do
        it "reports an error" do
          expect(Yast::Report).to receive(:Error).with(/in use/)

          subject.DeactivateDisk(channel, diagnose)
        end
      end
    end
  end

  describe "#IsAvailable" do
    it "returns true if .probe.disk contains DASDs" do
      expect(Yast::SCR).to receive(:Read).with(Yast.path(".probe.disk")).once
        .and_return(load_data("probe_disk_dasd.yml"))
      expect(Yast::DASDController.IsAvailable()).to eq(true)
    end
  end

  describe "#Write" do
    let(:data) do
      { "devices" => [{ "channel" => "0.0.0100", "diag" => false,
        "format" => true }], "format_unformatted" => true }
    end

    before do
      allow(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"),
        /\/sbin\/dasdview/)
        .and_return("exitstatus" => 0, "stdout" => load_file("dasdview_eckd.txt"), "stderr" => "")

      allow(Yast::Mode).to receive(:normal).and_return(false)
      allow(Yast::Mode).to receive(:installation).and_return(true)
      allow(Yast::Mode).to receive(:autoinst).and_return(true)
      # speed up the test a bit
      allow(Yast::Builtins).to receive(:sleep)
      allow(Yast::DASDController).to receive(:ActivateDisk).and_return(0)
      allow(Yast::DASDController).to receive(:GetDeviceName).and_return("/dev/dasda")
    end

    it "writes the dasd settings to the target (formating disks)" do
      # bnc 928388
      expect(Yast::SCR).to receive(:Execute).with(path(".process.start_shell"),
        "/sbin/dasdfmt -Y -P 1 -b 4096 -y -r 10 -m 10 -f '/dev/dasda'")

      expect(Yast::DASDController.Import(data)).to eq(true)
      expect(Yast::DASDController.Write).to eq(true)
    end

    it "does not format disk for FBA disk" do
      allow(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"),
        /\/sbin\/dasdview/)
        .and_return("exitstatus" => 0, "stdout" => load_file("dasdview_fba.txt"), "stderr" => "")

      expect(Yast::SCR).to_not receive(:Execute).with(path(".process.start_shell"),
        /dasdfmt.*\/dev\/dasda/)

      expect(Yast::DASDController.Import(data)).to eq(true)
      expect(Yast::DASDController.Write).to eq(true)
    end
  end

  describe "#ProbeDisks" do
    let(:disks) { [disk] }

    let(:disk) do
      {
        "device"       => "DASD",
        "sysfs_bus_id" => "0.0.0150",
        "resource"     => {
          "io" => []
        }
      }
    end

    before do
      allow(Yast::SCR).to receive(:Read).with(path(".probe.disk")).and_return(disks)
    end

    context "there is non-dasd disk" do
      let(:disk) do
        {
          "device"       => "ZFCP",
          "sysfs_bus_id" => "0.0.0150",
          "resource"     => {
            "io" => []
          }
        }
      end

      it "is not added to devices" do
        subject.ProbeDisks

        expect(subject.devices).to be_empty
      end
    end

    context "there is not activated dasd disk" do
      let(:disk) do
        {
          "device"       => "DASD",
          "sysfs_bus_id" => "0.0.0150",
          "resource"     => {
            "io" => []
          }
        }
      end

      it "is added to devices with channel entry" do
        subject.ProbeDisks

        expect(subject.devices.size).to eq 1
        expect(subject.devices.values.first["channel"]).to eq "0.0.0150"
      end
    end

    context "there is activated dasd disk" do
      let(:disk) do
        {
          "device"       => "DASD",
          "dev_name"     => "/dev/dasda",
          "sysfs_bus_id" => "0.0.0150",
          "resource"     => {
            "io" => ["active" => true]
          }
        }
      end

      before do
        allow(Yast::FileUtils).to receive(:Exists).and_return(false)
      end

      it "is added to devices with formatted info" do
        allow(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"),
          /\/sbin\/dasdview/)
          .and_return("exitstatus" => 0, "stdout" => load_file("dasdview_unformatted.txt"), "stderr" => "")

        subject.ProbeDisks

        expect(subject.devices.size).to eq 1
        expect(subject.devices.values.first["formatted"]).to eq false
      end
    end
  end
end
