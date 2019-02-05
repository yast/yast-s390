#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2s390/dialogs/devices_preconf"

Yast.import "UI"

describe Y2S390::Dialogs::DevicesPreconf do
  include Yast::UIShortcuts

  def term_with_id(widget_id, content)
    content.nested_find do |nested|
      next unless nested.is_a?(Yast::Term)
      nested.params.any? { |i| i.is_a?(Yast::Term) && i.value == :id && widget_id == i.params.first }
    end
  end

  subject { described_class.new }

  describe "#run" do
    before do
      allow(Yast::UI).to receive(:UserInput).and_return(*user_input)

      allow(Yast::UI).to receive(:QueryWidget).with(Id(:autoconfig), :Value)
        .and_return(marked_checkbox)
    end

    let(:user_input) { [:next] }

    let(:content) { subject.send(:dialog_content) }

    let(:marked_checkbox) { true }

    it "contains a button to apply auto-configuration" do
      expect(term_with_id(:load_autoconfig, content)).to_not be_nil
    end

    it "contains a checkbox to auto-configure devices in installed system" do
      expect(term_with_id(:autoconfig, content)).to_not be_nil
    end

    it "marks the checkbox by default" do
      widget = term_with_id(:autoconfig, content)

      expect(widget.params.last).to eq(true)
    end

    context "when the user clicks the button to apply auto-configuration" do
      let(:user_input) { [:load_autoconfig, :back] }

      it "tries to load the auto-configuration with 'chzdev' command" do
        expect(Yast::Execute).to receive(:locally).with("chzdev", any_args)

        subject.run
      end
    end

    context "when the user marks the checkbox" do
      let(:marked_checkbox) { true }

      context "and the user goes next" do
        let(:user_input) { [:next] }

        it "sets autoconfig to true" do
          subject.run

          expect(subject.autoconfig?).to eq(true)
        end
      end

      context "and the user goes back" do
        let(:user_input) { [:back] }

        it "sets autoconfig to false" do
          subject.run

          expect(subject.autoconfig?).to eq(false)
        end
      end
    end

    context "when the user does not mark the checkbox" do
      let(:marked_checkbox) { false }

      context "and the user goes next" do
        let(:user_input) { [:next] }

        it "sets autoconfig to false" do
          subject.run

          expect(subject.autoconfig?).to eq(false)
        end
      end

      context "and the user goes back" do
        let(:user_input) { [:back] }

        it "sets autoconfig to false" do
          subject.run

          expect(subject.autoconfig?).to eq(false)
        end
      end
    end
  end
end
