#!/usr/bin/env rspec

require_relative "./test_helper"

Yast.import "DASDController"

describe Yast::DASDController do
  subject { Yast::DASDController }

  describe "#GetDeviceName" do
    let(:channel) { "0.0.0150" }
    let(:device_block_path) { "/sys/bus/ccw/devices/#{channel}/block/" }

    before do
      allow(Yast::SCR).to receive(:Read).with(Yast.path(".target.dir"), device_block_path)
        .once.and_return(["dasda"])
    end

    it "returns the associated device name" do
      expect(subject.GetDeviceName(channel)).to eq("/dev/dasda")
    end
  end

  describe "#ActivateDisk" do
    let(:exit_code) { 8 }
    let(:channel) { "0.0.0100" }

    before do
      allow(Yast::SCR).to receive(:Execute).and_return(
        "exit" => exit_code
      )
    end

    it "runs dasd_configure" do
      expect(Yast::SCR).to receive(:Execute).with(
        path(".target.bash_output"), "/sbin/dasd_configure '0.0.0100' 1 0"
      )
      subject.ActivateDisk(channel, false)
    end

    it "returns dasd_configure exit value" do
      expect(subject.ActivateDisk(channel, false)).to eq(exit_code)
    end

    context "when exit code is 7" do
      let(:exit_code) { 7 }

      it "deactivates the device" do
        expect(subject).to receive(:DeactivateDisk).with(channel, false)
        subject.ActivateDisk(channel, false)
      end
    end

    context "when exit code is other than 7 or 8" do
      let(:exit_code) { 1 }

      it "reports activation error" do
        expect(subject).to receive(:ReportActivationError).with(channel, "exit" => exit_code)
        subject.ActivateDisk(channel, false)
      end
    end
  end

  describe "#activate_disk_if_needed" do
    let(:channel) { "0.0.0150" }
    let(:formatted) { true }
    let(:active) { true }

    let(:disk) do
      {
        "dev_name"  => "/dev/dasda",
        "formatted" => formatted,
        "channel"   => channel,
        "resource"  => {
          "io" => [{ "active" => active }]
        }
      }
    end

    before do
      allow(subject).to receive(:find_disks).and_return([disk])
    end

    context "when the disk is already active" do
      it "does not activate the disk" do
        expect(subject).to_not receive(:ActivateDisk)
        subject.activate_disk_if_needed(channel, false)
      end

      context "and it is not formatted" do
        let(:formatted) { false }

        it "returns 8" do
          expect(subject.activate_disk_if_needed(channel, false)).to eq(8)
        end
      end

      context "and it is formatted" do
        it "returns 0" do
          expect(subject.activate_disk_if_needed(channel, false)).to eq(0)
        end
      end
    end

    context "when the disk is not active" do
      let(:active) { false }

      it "activates the disk" do
        expect(subject).to receive(:ActivateDisk).with(channel, false)
          .and_return(0)
        expect(subject.activate_disk_if_needed(channel, false)).to eq(0)
      end
    end
  end

  describe "#DeactivateDisk" do
    let(:auto) { false }
    let(:channel) { "0.0.0160" }
    let(:diagnose) { false }
    let(:exit_code) { 0 }
    let(:command_result) { { "exit" => exit_code } }

    before do
      allow(Yast::Mode).to receive(:auto).and_return(auto)
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

      context "but in Mode.auto" do
        let(:auto) { true }

        it "reports the error throught Yast::Report" do
          expect(Yast::Report).to receive(:Error)

          subject.DeactivateDisk(channel, diagnose)
        end
      end
    end

    context "when disk is being in use" do
      let(:exit_code) { 16 }
      let(:command_result) do
        {
          "exit"   => exit_code,
          "stderr" => "Warning: ECKD DASD 0.0.0150 is in use!\n" \
                      "The following resources may be affected:\n" \
                      "- Mount point /mnt\n",
          "stdout" => "Continue with operation? (yes/no)"
        }
      end

      it "returns nil" do
        expect(subject.DeactivateDisk(channel, diagnose)).to be_nil
      end

      it "reports an error using a popup with details" do
        expect(Yast2::Popup).to receive(:show).with(anything, hash_including(:headline, :details))

        subject.DeactivateDisk(channel, diagnose)
      end

      context "but in Mode.auto" do
        let(:auto) { true }

        it "reports the error throught Yast::Report" do
          expect(Yast::Report).to receive(:Error).with(/in use/)

          subject.DeactivateDisk(channel, diagnose)
        end
      end

      context "but there are not details to show" do
        let(:command_result) { { "exit" => exit_code } }

        it "reports an error throught Yast::Report" do
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
      expect(subject.IsAvailable()).to eq(true)
    end
  end

  describe "#GetDevices" do
    it "returns DASDs" do
      expect(Yast::SCR).to receive(:Read).with(Yast.path(".probe.disk")).once
        .and_return(load_data("probe_disk_dasd.yml"))
      expect(subject.ProbeDisks()).to eq(nil)
      expect(subject.GetDevices()).to eq(
        0 => { "detail"        => { "cu_model" => 233, "dev_model" => 10, "lcss" => 0 },
               "device_id"     => 276880,
               "resource"      => { "io" => [{ "active" => false,
                                               "length" => 1,
                                               "mode"   => "rw",
                                               "start"  => 352 }] },
               "sub_device_id" => 275344,
               "channel"       => "0.0.0150" },
        1 => { "detail"        => { "cu_model" => 233, "dev_model" => 10, "lcss" => 0 },
               "device_id"     => 276880,
               "resource"      => { "io" => [{ "active" => false,
                                               "length" => 1,
                                               "mode"   => "rw",
                                               "start"  => 352 }] },
               "sub_device_id" => 275344,
               "channel"       => "0.0.0160" }
      )
    end
  end

  describe "#FormatDisks" do
    it "formats the given disks using dasdfmt" do
      allow(Yast::SCR).to receive(:Read).with(path(".process.running"), 100).and_return(true, false)
      allow(Yast::SCR).to receive(:Read).with(path(".process.status"), 100).and_return(0)
      allow(Yast::SCR).to receive(:Read).with(path(".process.read_line"), 100).and_return("0")
      allow(Yast::SCR).to receive(:Read).with(path(".process.read_line_stderr")).and_return(nil)
      expect(Yast::SCR).to receive(:Execute).with(
        path(".process.start_shell"), "/sbin/dasdfmt -Y -P 1 -b 4096 -y -r 10 -m 10 -f '/dev/dasda'"
      ).and_return(100)
      subject.FormatDisks(["/dev/dasda"], 8)
    end
  end

  describe "#Write" do
    let(:data) do
      { "devices" => [{ "channel" => channel, "diag" => false,
        "format" => format }], "format_unformatted" => format_unformatted }
    end
    let(:format_unformatted) { false }
    let(:format) { true }
    let(:channel) { "0.0.0100" }

    before do
      allow(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"), /\/sbin\/dasdview/)
        .and_return("exitstatus" => 0, "stdout" => load_file("dasdview_eckd.txt"), "stderr" => "")

      allow(Yast::Mode).to receive(:normal).and_return(false)
      allow(Yast::Mode).to receive(:installation).and_return(true)
      allow(Yast::Mode).to receive(:autoinst).and_return(true)
      # speed up the test a bit
      allow(Yast::Builtins).to receive(:sleep)
      allow(subject).to receive(:ActivateDisk).and_return(0)
      allow(subject).to receive(:GetDeviceName).and_return("/dev/dasda")
    end

    context "during autoinstallation" do
      before do
        subject.Import(data)
      end

      it "activates the disk" do
        allow(subject).to receive(:FormatDisks)
        expect(subject).to receive(:ActivateDisk).with("0.0.0100", false)
        subject.Write
      end

      context "when 'format' is sets to true" do
        let(:format) { true }

        it "formats the disk" do
          expect(subject).to receive(:FormatDisks).with(["/dev/dasda"], 8)
          expect(subject.Write).to eq(true)
        end
      end

      context "when 'format' is set to false" do
        let(:format) { false }

        it "does not format the disk" do
          expect(subject).to_not receive(:FormatDisks)
          subject.Write
        end
      end

      context "when the activated device is not formatted" do
        NOT_FORMATTED_CODE = 8 # means that the device is not formatted

        let(:format) { false }

        before do
          allow(subject).to receive(:activate_disk_if_needed).with(channel, false)
            .and_return(NOT_FORMATTED_CODE)
        end

        context "and 'format_unformatted' is set to 'true'" do
          let(:format_unformatted) { true }

          it "formats the device" do
            expect(subject).to receive(:FormatDisks).with(["/dev/dasda"], anything)
            subject.Write
          end

          it "reactivates the disk" do
            allow(subject).to receive(:FormatDisks)
            expect(subject).to receive(:ActivateDisk).with(channel, false)
            subject.Write
          end
        end

        context "and 'format_unformatted' is set to 'false'" do
          let(:format_unformatted) { false }

          it "does not format the device" do
            expect(subject).to_not receive(:FormatDisks)
            subject.Write
          end

          it "does not reactivate the disk" do
            expect(subject).to_not receive(:ActivateDisk)
            subject.Write
          end
        end

        context "and 'format' is set to 'true'" do
          let(:format) { true }
          let(:format_unformatted) { false }

          it "formats the device" do
            expect(subject).to receive(:FormatDisks).with(["/dev/dasda"], anything)
            subject.Write
          end

          it "reactivates the disk" do
            expect(subject).to receive(:FormatDisks)
            expect(subject).to receive(:ActivateDisk).with(channel, false)
            subject.Write
          end
        end
      end

      it "does not format disk for FBA disk and report error" do
        allow(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"),
          /\/sbin\/dasdview/)
          .and_return("exitstatus" => 0, "stdout" => load_file("dasdview_fba.txt"), "stderr" => "")

        expect(Yast::SCR).to_not receive(:Execute).with(path(".process.start_shell"),
          /dasdfmt.*\/dev\/dasda/)

        expect(Yast::Report).to receive(:Error)

        expect(subject.Import(data)).to eq(true)
        expect(subject.Write).to eq(true)
      end
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
          "sysfs_id"     => "/class/block/dasda",
          "resource"     => {
            "io" => ["active" => true]
          }
        }
      end

      before do
        allow(File).to receive(:exist?).and_return(false)
      end

      it "is added to devices with formatted info" do
        allow(Yast::SCR).to receive(:Execute).with(path(".target.bash_output"),
          /\/sbin\/dasdview/)
          .and_return("exitstatus" => 0, "stdout" => load_file("dasdview_unformatted.txt"), "stderr" => "")

        subject.ProbeDisks

        expect(subject.devices.size).to eq 1
        expect(subject.devices.values.first["formatted"]).to eq false
      end

      context "when the 'use_diag' file exists" do
        let(:diag_path) { "/sys//class/block/dasda/device/use_diag" }

        before do
          allow(File).to receive(:exist?).with(diag_path)
            .and_return(true)
          allow(Yast::SCR).to receive(:Read)
            .with(Yast::Path.new(".target.string"), diag_path)
            .and_return("1")
        end

        it "reads its value" do
          subject.ProbeDisks
          device = subject.devices.values.first
          expect(device["diag"]).to eq(true)
          expect(subject.diag).to eq("0.0.0150" => true)
        end
      end
    end
  end

  describe "#ActivateDiag" do
    it "deactivates and reactivates dasd" do
      expect(subject).to receive(:DeactivateDisk).ordered
      expect(subject).to receive(:ActivateDisk).ordered
      expect(subject.ActivateDiag("0.0.3333", true)).to eq(nil)
    end
  end

  describe "#GetFilteredDevices" do
    it "Filters the devices (as a single large number)" do
      import_data = { "devices" => [{ "channel" => "0.4.fa00" },
                                    { "channel" => "0.0.fb00" },
                                    { "channel" => "0.0.fc00" },
                                    { "channel" => "0.0.f800" },
                                    { "channel" => "0.0.f900" }] }

      expect(subject.Import(import_data)).to eq(true)
      subject.filter_max = subject.FormatChannel("10.0.FA00")
      subject.filter_min = subject.FormatChannel("0.0.f900")
      expect(subject.GetFilteredDevices()).to eq(
        0 => { "channel" => "0.4.fa00" },
        1 => { "channel" => "0.0.fb00" },
        2 => { "channel" => "0.0.fc00" },
        4 => { "channel" => "0.0.f900" }
      )
    end
  end
end
