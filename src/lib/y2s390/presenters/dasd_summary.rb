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

require "yast"

Yast.import "Mode"
Yast.import "String"

module Y2S390
  module Presenters
    # This class is responsible of returning a configuration summary of the given devices
    class DasdSummary
      include Yast::Logger
      include Yast::I18n

      # @return [Y2S390::DasdsCollection]
      attr_accessor :devices

      # Constructor
      #
      # @param devices [Y2S390::DasdsCollection]
      def initialize(devices)
        textdomain "s390"
        @devices = devices
      end

      # Return a list with the configuration summary for all the devices given in text plain
      #
      # @return [Array<String>]
      def list
        ret = devices.map { |d| format(template, *params(d)) }
        log.info("Summary: #{ret}")
        ret
      end

    private

      # Convenience method to obtain the arguments needed by the configuration template to be used
      # depending on the {Yast::Mode}
      #
      # @param device [Y2S390::Dasd]
      def params(device)
        return [device.id, format?(device), use_diag?(device)] if Yast::Mode.config

        [device.id, device.device_name, use_diag?(device)]
      end

      # Return the configuration summary template to be used depending on the {Yast::Mode}
      #
      # @return [String]
      def template
        return _("Channel ID: %s, Format: %s, DIAG: %s") if Yast::Mode.config

        _("Channel ID: %s, Device: %s, DIAG: %s")
      end

      def format?(device)
        Yast::String.YesNo(device.format_wanted)
      end

      def use_diag?(device)
        Yast::String.YesNo(Yast::Mode.config ? device.diag_wanted : device.use_diag)
      end
    end
  end
end
