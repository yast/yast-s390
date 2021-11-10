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
