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

require "yast"
require "y2s390/dialogs/devices_preconf"

Yast.import "Kernel"
Yast.import "Arch"
Yast.import "GetInstArgs"

module Y2S390
  module Clients
    # I/O device auto-configuration is a mechanism by which users can specify IDs
    # and settings of I/O devices that should be automatically enabled.
    #
    # This client allows to trigger such mechanism.
    class InstDevicesPreconf
      include Yast::Logger

      AUTOCONFIG_FILE = "/sys/firmware/sclp_sd/config/data".freeze

      # @return [Symbol] :auto, :next, :back or :abort
      def run
        # :auto forwards the former action (:next or :back)
        return :auto if skip?

        result = dialog.run

        disable_autoconfig if result == :next && !dialog.autoconfig?

        result
      end

    private

      # Whether this client should be skipped
      #
      # The client is skipped when the file with devices configuration
      # does not exist or it has no content.
      #
      # @return [Boolean]
      def skip?
        missing_config_file? || empty_config_file?
      end

      # Whether the configuration file does not exist
      #
      # @return [Boolean]
      def missing_config_file?
        !File.exist?(AUTOCONFIG_FILE)
      end

      # Whether the configuration file has no content
      #
      # @return [Boolean]
      def empty_config_file?
        File.open(AUTOCONFIG_FILE, "rb") { |f| f.read(1).nil? }
      end

      # Dialog to select auto-configuration options
      #
      # @return [Dialogs::DevicesPreconf]
      def dialog
        @dialog ||= Dialogs::DevicesPreconf.new
      end

      # Adds a kernel parameter to disable devices auto-configuration
      def disable_autoconfig
        Yast::Kernel.AddCmdLine("rd.zdev", "no-auto")
      end
    end
  end
end
