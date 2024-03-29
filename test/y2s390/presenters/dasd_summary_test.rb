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

require_relative "../../test_helper"

require "cwm/rspec"
require "y2s390/presenters/dasd_summary"

describe Y2S390::Presenters::DasdSummary do
  subject { described_class.new(devices) }
  let(:devices) { Yast::DASDController.devices.by_ids(["0.0.0150", "0.0.0160"]) }

  mock_entries

  describe "#list" do
    before do
      Yast.import "DASDController"
      Yast::DASDController.ProbeDisks()
    end

    it "returns a summary of the dasds configuration" do
      dasd0160 = "Channel ID: 0.0.0160, Device: dasda, DIAG: No"
      dasd0150 = "Channel ID: 0.0.0150, Device: dasdb, DIAG: No"

      expect(subject.list).to include(dasd0150)
      expect(subject.list).to include(dasd0160)
    end
  end
end
