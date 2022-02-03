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

require_relative "../test_helper"
require "y2s390/dasds_writer"

Yast.import "DASDController"

describe Y2S390::DasdsWriter do
  let(:dasd_150) { "0.0.0150" }
  let(:dasd_160) { "0.0.0160" }
  let(:dasd_300) { "0.0.0300" }
  let(:unformatted) { false }
  let(:s390_mocking) { true }
  let(:lsdasd_file) { "test/data/lsdasd.txt" }
  let(:lsdasd_file_offline) { "test/data/lsdasd_offline.txt" }

  before do
    allow(ENV).to receive(:[]).with("S390_MOCKING").and_return(false)
    allow(ENV).to receive(:[]).with("YAST2_S390_PROBE_DISK")
      .and_return("test/data/probe_disk_dasd.yml")
    allow(ENV).to receive(:[]).with("YAST2_S390_LSDASD")
      .and_return(lsdasd_file_offline, lsdasd_file)
  end

  let(:profile) do
    { "devices" => [
      { "channel" => dasd_150, "diag" => false, "format" => true },
      { "channel" => dasd_160, "diag" => false, "format" => false },
      { "channel" => dasd_300, "diag" => false, "format" => true }
    ], "format_unformatted" => unformatted }
  end

  describe "write" do
    subject { described_class.new(Yast::DASDController.devices) }

    before do
      Yast::DASDController.Import(profile)
      allow(subject).to receive(:format_dasds)
      allow(subject).to receive(:report_issues)
      allow(Yast::DASDController).to receive(:ActivateDisk)
    end

    it "activates the current devices if needed" do
      expect(subject).to receive(:pre_format_activation).and_call_original
      d300 = subject.dasds.by_id(dasd_300)
      d160 = subject.dasds.by_id(dasd_160)
      expect(Yast::DASDController).to receive(:activate_if_needed).with(d300)
      expect(Yast::DASDController).to receive(:activate_if_needed).with(d160)
      subject.write
    end

    it "obtains the DASDs to be formatted" do
      expect(subject).to receive(:obtain_dasds_to_format).and_call_original
      expect { subject.write }.to change { subject.to_format.size }.from(0).to(2)
    end

    context "in autoinstallation" do
      before do
        allow(Yast::Mode).to receive(:autoinst).and_return(true)
      end

      context "when format_unformated variable is set to true" do
        let(:unformatted) { true }

        it "also obtains not formatted DASDs" do
          expect(subject).to receive(:obtain_dasds_to_format).and_call_original
          expect { subject.write }.to change { subject.to_format.size }.from(0).to(3)
        end
      end
    end

    it "checks for issues in the candidates to be formatted disks" do
      expect(subject).to receive(:sanitize_to_format)
      subject.write
    end

    context "when an issue is found" do
      # FBA DASDs can't be formatted
      let(:profile) { { "devices" => [{ "channel" => "0.0.ffff", "format" => true }] } }

      it "removes the DASD with the issue from the format and reactivation lists" do
        allow(subject).to receive(:format_dasds).and_call_original
        expect(Yast::DASDController).to_not receive(:FormatDisks)
        subject.write
      end

      it "reports the issue" do
        expect(subject).to receive(:report_issues).and_call_original
        expect(Y2Issues).to receive(:report)
        subject.write
      end
    end

    it "formats the DASDs that are select and valid to be formatted" do
      allow(subject).to receive(:format_dasds).and_call_original
      expect(Yast::DASDController).to receive(:FormatDisks)
      subject.write
      expect(subject.to_format.ids).to eql([dasd_150, dasd_300])
    end

    context "when an unformatted device is formatted" do
      it "reactives it after formatted all the devices" do
        allow(subject).to receive(:activate_offline_dasds)
        allow(subject).to receive(:format_dasds).and_call_original
        expect(Yast::DASDController).to receive(:FormatDisks).ordered
        expect(Yast::DASDController).to receive(:ActivateDisk).with(dasd_300, false).ordered
        subject.write
      end
    end
  end
end
