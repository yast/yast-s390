#!/usr/bin/env rspec

# Copyright (c) [2022] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require_relative "./test_helper"

Yast.import "DASDController"

describe Yast::DASDController do
  subject { Yast::DASDController }
  let(:mock_disks) { true }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("S390_MOCKING").and_return(mock_disks)
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

  describe "#activate_if_needed" do
    let(:dasd) { subject.devices.by_id(channel) }
    let(:channel) { "0.0.0150" }
    let(:active) { true }
    let(:formatted) { true }

    before do
      subject.ProbeDisks()
      allow(dasd).to receive(:io_active?).and_return(active)
      dasd.formatted = formatted
    end

    context "when the disk is already active" do
      it "does not activate the disk" do
        expect(subject).to_not receive(:ActivateDisk)
        subject.activate_if_needed(dasd)
      end

      context "and it is not formatted" do
        let(:formatted) { false }

        it "returns 8" do
          expect(subject.activate_if_needed(dasd)).to eq(8)
        end
      end

      context "and it is formatted" do
        it "returns 0" do
          expect(subject.activate_if_needed(dasd)).to eq(0)
        end
      end
    end

    context "when the disk is not active" do
      let(:active) { false }

      it "activates the disk" do
        expect(subject).to receive(:ActivateDisk).with(channel, false)
          .and_return(0)
        expect(subject.activate_if_needed(dasd)).to eq(0)
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
    context "when .probe.disk does not contain DASDS" do
      let(:mock_disks) { false }

      before do
        allow(Yast::SCR).to receive(:Read).with(Yast.path(".probe.disk")).and_return({})
      end

      it "returns false" do
        expect(subject.IsAvailable()).to eq(false)
      end
    end

    it "returns true if .probe.disk contains DASDs" do
      expect(subject.IsAvailable()).to eq(true)
    end
  end

  describe "#GetDevices" do
    it "returns cached DASDs" do
      expect(subject.GetDevices).to be_a(Y2S390::DasdsCollection)
    end
  end

  describe "#FormatDisks" do
    let(:disks) { Yast::DASDController.devices.by_ids(["0.0.0150"]) }
    let(:dialog) { Y2S390::Dialogs::DasdFormat }

    it "runs a Format Disk dialog for the given disks" do
      expect_any_instance_of(dialog).to receive(:run)

      subject.FormatDisks(disks)
    end
  end

  describe "#Write" do
    let(:data) do
      { "devices" => [{ "channel" => channel, "diag" => false,
        "format" => format }], "format_unformatted" => format_unformatted }
    end
    let(:format_unformatted) { false }
    let(:format) { true }
    let(:channel) { "0.0.0150" }

    before do
      allow(Yast::Mode).to receive(:normal).and_return(false)
      allow(Yast::Mode).to receive(:installation).and_return(true)
    end

    context "during autoinstallation" do
      let(:channel) { "0.0.0150" }
      let(:dasds) { Yast::DASDController.devices }
      let(:can_format) { true }

      before do
        subject.Import(data)
      end

      it "calls the dasds writers with the current devices" do
        expect(Y2S390::DasdsWriter).to receive(:new).with(dasds).and_call_original
        expect_any_instance_of(Y2S390::DasdsWriter).to receive(:write)
        subject.Write
      end
    end
  end

  describe "#ProbeDisks" do
    it "forces a read of the DASDs information from the system" do
      expect(subject.reader).to receive(:list).with(force_probing: true).and_call_original
      subject.ProbeDisks
    end
  end

  describe "#ActivateDiag" do
    it "deactivates and reactivates dasd" do
      expect(subject).to receive(:DeactivateDisk).ordered
      expect(subject).to receive(:ActivateDisk).ordered
      expect(subject.ActivateDiag("0.0.0150", true)).to eq(nil)
    end
  end

  describe "#GetFilteredDevices" do
    let(:imported_ids) { ["0.4.fa00", "0.0.fb00", "0.0.fc00", "0.0.f800", "0.0.f900"] }

    it "Filters the devices (as a single large number)" do
      import_data = { "devices" => imported_ids.map { |id| { "channel" => id } } }
      subject.Import(import_data)
      subject.filter_max = subject.FormatChannel("10.0.FA00")
      subject.filter_min = subject.FormatChannel("0.0.f900")
      devices = subject.GetFilteredDevices()

      expect(devices.size).to eq(4)
      expect(devices.ids).to eq(imported_ids.reject { |id| id == "0.0.f800" })
    end
  end

  describe "#Summary" do
    let(:config_mode) { false }

    before do
      subject.ProbeDisks
      allow(Yast::Mode).to receive(:config).and_return(config_mode)
    end

    it "shows a summary of active devices" do
      expect(subject.Summary).to include(
        "Channel ID: 0.0.0160, Device: dasda, DIAG: No",
        "Channel ID: 0.0.0150, Device: dasdb, DIAG: No"
      )
    end

    context "in config Mode" do
      let(:config_mode) { true }

      it "shows a summary of all the devices" do
        subject.devices.by_id("0.0.0190").format_wanted = true
        subject.devices.by_id("0.0.0191").diag_wanted = true
        expect(subject.Summary).to include(
          "Channel ID: 0.0.0190, Format: Yes, DIAG: No",
          "Channel ID: 0.0.0191, Format: No, DIAG: Yes"
        )
      end
    end
  end
end
