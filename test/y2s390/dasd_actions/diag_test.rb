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
require "y2s390/dasd_actions/diag"

describe Y2S390::DasdActions::DiagOn do
  let(:action) { described_class.new(selected) }
  let(:selected) { Y2S390::DasdsCollection.new([dasd_0150, dasd_0fff]) }
  let(:dasd_0150) { Y2S390::Dasd.new("0.0.0150", status: "offline") }
  let(:dasd_0fff) { Y2S390::Dasd.new("0.0.0fff", status: "offline") }
  let(:controller) { Yast::DASDController }

  describe "#run" do
    let(:format_now) { false }
    let(:config_mode) { false }

    before do
      allow(controller).to receive(:ProbeDisks)
      allow(Yast::Mode).to receive(:config).and_return(config_mode)
      allow(dasd_0150).to receive(:io_active?).and_return(false)
      allow(dasd_0fff).to receive(:io_active?).and_return(false)
    end

    context "when running in config Mode" do
      let(:config_mode) { true }

      it "iterates over the the selected DASDs setting the diag wanted to true" do
        expect { action.run }.to change { dasd_0150.diag_wanted }.from(nil).to(true)
          .and change { dasd_0fff.diag_wanted }.from(nil).to(true)
      end
    end

    context "when not running in config Mode" do
      it "iterates over the selected DASDs setting the diag wanted to true" do
        expect { action.run }.to change { dasd_0150.diag_wanted }.from(nil).to(true)
          .and change { dasd_0fff.diag_wanted }.from(nil).to(true)
      end

      context "when the DASD is active according to sysfs" do
        before do
          allow(dasd_0150).to receive(:io_active?).and_return(true)
        end

        it "activates the DIAG" do
          expect(controller).to receive(:ActivateDiag).with("0.0.0150", true)

          action.run
        end
      end

      it "reloads the DASDs configuration forcing a probe of the disks" do
        expect(controller).to receive(:ProbeDisks)
        action.run
      end
    end

    it "returns true" do
      expect(action.run).to eql(true)
    end
  end
end

describe Y2S390::DasdActions::DiagOff do
  let(:action) { described_class.new(selected) }
  let(:selected) { Y2S390::DasdsCollection.new([dasd_0150, dasd_0fff]) }
  let(:dasd_0150) { Y2S390::Dasd.new("0.0.0150", status: "offline") }
  let(:dasd_0fff) { Y2S390::Dasd.new("0.0.0fff", status: "offline") }
  let(:controller) { Yast::DASDController }

  describe "#run" do
    let(:format_now) { false }
    let(:config_mode) { false }

    before do
      allow(controller).to receive(:ProbeDisks)
      allow(Yast::Mode).to receive(:config).and_return(config_mode)
      allow(dasd_0150).to receive(:io_active?).and_return(false)
      allow(dasd_0fff).to receive(:io_active?).and_return(false)
    end

    context "when running in config Mode" do
      let(:config_mode) { true }

      it "iterates over the the selected DASDs setting the diag wanted to false" do
        expect { action.run }.to change { dasd_0150.diag_wanted }.from(nil).to(false)
          .and change { dasd_0fff.diag_wanted }.from(nil).to(false)
      end
    end

    context "when not running in config Mode" do
      it "iterates over the selected DASDs setting the diag wanted to false" do
        expect { action.run }.to change { dasd_0150.diag_wanted }.from(nil).to(false)
          .and change { dasd_0fff.diag_wanted }.from(nil).to(false)
      end

      context "when the DASD is active according to sysfs" do
        before do
          allow(dasd_0150).to receive(:io_active?).and_return(true)
        end

        it "deactivates the DIAG" do
          expect(controller).to receive(:ActivateDiag).with("0.0.0150", false)

          action.run
        end
      end

      it "reloads the DASDs configuration forcing a probe of the disks" do
        expect(controller).to receive(:ProbeDisks)
        action.run
      end
    end

    it "returns true" do
      expect(action.run).to eql(true)
    end
  end
end
