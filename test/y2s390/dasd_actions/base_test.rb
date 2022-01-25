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

require_relative "../../test_helper.rb"
require "y2s390/dasd_actions/base"

describe Y2S390::DasdActions::Base do
  subject { described_class.new(selected) }
  let(:selected) { Y2S390::DasdsCollection.new([]) }

  describe ".run" do
    it "creates a new object of the class and call its run method" do
      expect(described_class).to receive(:new).with(selected).and_return(subject)
      expect(subject).to receive(:run)

      described_class.run(selected)
    end
  end

  describe "#config_mode?" do
    let(:config_mode) { true }

    before do
      allow(Yast::Mode).to receive(:config).and_return(config_mode)
    end

    context "in Mode.config" do
      it "returns true" do
        expect(subject.config_mode?).to eq(true)
      end
    end

    context "in other Mode" do
      let(:config_mode) { false }

      it "returns false" do
        expect(subject.config_mode?).to eq(false)
      end
    end
  end

  describe "#auto_mode?" do
    let(:auto_mode) { true }

    before do
      allow(Yast::Mode).to receive(:autoinst).and_return(auto_mode)
    end

    context "in Mode.autoinst" do
      it "returns true" do
        expect(subject.auto_mode?).to eq(true)
      end
    end

    context "in other Mode" do
      let(:auto_mode) { false }

      it "returns false" do
        expect(subject.auto_mode?).to eq(false)
      end
    end
  end
end
