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
require "y2s390"
require "y2s390/format_process"

describe Y2S390::FormatStatus do
  let(:dasd) { Y2S390::Dasd.new("0.0.0150", status: "active", type: "ECKD") }

  subject { described_class.new(dasd, 1500) }

  describe "#update_progress!" do
    it "increases the progress by the format size" do
      expect { subject.update_progress! }.to change { subject.progress }.from(0).to(10)
      expect { subject.update_progress! }.to change { subject.progress }.from(10).to(20)
    end
  end

  describe "#done?" do
    it "returns true when all the cylinders have been formatted" do
      expect(subject.done?).to eql(false)
      150.times { subject.update_progress! }
      expect(subject.done?).to eql(true)
    end

    it "returns false otherwise" do
      expect(subject.done?).to eql(false)
    end
  end
end

describe Y2S390::FormatProcess do
  let(:subject) { described_class.new(dasds) }
  let(:dasd_0150) do
    Y2S390::Dasd.new("0.0.0150", status: "active", type: "ECKD", device_name: "dasda")
  end
  let(:dasd_0160) do
    Y2S390::Dasd.new("0.0.0160", status: "active", type: "ECKD", device_name: "dasdb")
  end

  let(:dasds) { [dasd_0150, dasd_0160] }

  describe "#start" do
    it "starts a dasdfmt process in parallel with the disks given" do
      expect(Yast::SCR).to receive(:Execute).with(
        Yast.path(".process.start_shell"),
        "/sbin/dasdfmt -Y -P 2 -b 4096 -y -r 10 -m 10 -f /dev/dasda -f /dev/dasdb"
      )
      subject.start
    end

    it "returns the process id" do
      expect(Yast::SCR).to receive(:Execute).with(anything, anything).and_return(3200)
      expect(subject.start).to eql(3200)
    end
  end

  describe "#running?" do
    it "returns false if the process has not started" do
      expect(subject.running?).to eql(false)
    end
  end

  describe "#initialize_summary" do
  end

  describe "#update_summary" do
  end
end
