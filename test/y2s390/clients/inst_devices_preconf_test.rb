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
require "y2s390/clients/inst_devices_preconf"

describe Y2S390::Clients::InstDevicesPreconf do
  subject { described_class.new }

  describe "#run" do
    shared_examples "no action" do
      it "does not add kernel paramaters" do
        expect(Yast::Kernel).to_not receive(:AddCmdLine)

        subject.run
      end
    end

    shared_examples "forward action" do
      include_examples "no action"

      it "returns :auto" do
        expect(subject.run).to eq(:auto)
      end
    end

    before do
      allow(File).to receive(:exist?).with("/sys/firmware/sclp_sd/config/data")
        .and_return(exist_config_file)

      allow(File).to receive(:open).with("/sys/firmware/sclp_sd/config/data", any_args)
        .and_return(empty_config_file)

      allow(Y2S390::Dialogs::DevicesPreconf).to receive(:new).and_return(dialog)

      allow(dialog).to receive(:run).and_return(dialog_result)

      allow(dialog).to receive(:autoconfig?).and_return(dialog_autoconf)
    end

    let(:exist_config_file) { nil }

    let(:empty_config_file) { nil }

    let(:dialog) { instance_double(Y2S390::Dialogs::DevicesPreconf) }

    let(:dialog_result) { nil }

    let(:dialog_autoconf) { nil }

    context "when the config file does not exist" do
      let(:exist_config_file) { false }

      include_examples "forward action"
    end

    context "when the config file exists" do
      let(:exist_config_file) { true }

      context "and has no content" do
        let(:empty_config_file) { true }

        include_examples "forward action"
      end

      context "and has content" do
        let(:empty_config_file) { false }

        it "opens a dialog to pre-configure devices" do
          expect(dialog).to receive(:run)

          subject.run
        end

        context "and the user aborts" do
          let(:dialog_result) { :abort }

          include_examples "no action"

          it "returns :abort" do
            expect(subject.run).to eq(:abort)
          end
        end

        context "and the user goes back" do
          let(:dialog_result) { :back }

          include_examples "no action"

          it "returns :back" do
            expect(subject.run).to eq(:back)
          end
        end

        context "and the user goes next" do
          let(:dialog_result) { :next }

          context "and the auto-configuration option was selected" do
            let(:dialog_autoconf) { true }

            include_examples "no action"

            it "returns :next" do
              expect(subject.run).to eq(:next)
            end
          end

          context "and the auto-configuration option was not selected" do
            let(:dialog_autoconf) { false }

            it "adds kernel paramater to not auto-configure devices" do
              expect(Yast::Kernel).to receive(:AddCmdLine).with("rd.zdev", "no-auto")

              subject.run
            end

            it "returns :next" do
              expect(subject.run).to eq(:next)
            end
          end
        end
      end
    end
  end
end
