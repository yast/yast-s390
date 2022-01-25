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
require_relative "base_collection_examples"
require "y2s390"

describe Y2S390::DasdsCollection do
  include_examples "config base collection"

  describe "#filter" do
    let(:elements) { [element1, element2, element3] }
    let(:element1) { Y2S390::Dasd.new("0.0.0150", status: "active", type: "EKCD") }
    let(:element2) { Y2S390::Dasd.new("0.0.0160", status: "offline", type: "EKCD") }
    let(:element3) { Y2S390::Dasd.new("0.0.0190", status: "active(ro)", type: "EKCD") }

    it "returns a new collection with the elements which the block returns true" do
      expect(subject.size).to eq(3)
      collection = subject.filter(&:offline?)
      expect(collection.size).to eq(1)
      expect(collection.by_id("0.0.0160")).to eq(element2)
    end
  end

  describe "#active" do
    let(:elements) { [element1, element2, element3] }
    let(:element1) { Y2S390::Dasd.new("0.0.0150", status: "active", type: "EKCD") }
    let(:element2) { Y2S390::Dasd.new("0.0.0160", status: "offline", type: "EKCD") }
    let(:element3) { Y2S390::Dasd.new("0.0.0190", status: "active(ro)", type: "EKCD") }

    it "returns a new collection with only the active elements" do
      expect(subject.active.ids).to eql(["0.0.0150", "0.0.0190"])
    end
  end
end
