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
require "abstract_method"

Yast.import "DASDController"
Yast.import "Mode"
Yast.import "Popup"

module Y2S390
  module DasdActions
    # Base class for all the DASD actions that can be performed over a collection of DASDs
    class Base
      include Yast::I18n

      # @return [Boolean]
      abstract_method :run

      # @return [Y2S390::DasdsCollection]
      attr_accessor :selected

      # Constructor
      #
      # @param selected [Y2S390::DasdsCollection] the collection of DASDs to which the action
      #   has to be applied
      def initialize(selected)
        textdomain "s390"

        @selected = selected
      end

      # Shortcut for `.new(selected).run`
      #
      # @params selected [Y2S390::DasdsCollection] the collection of DASDs to which the action
      #   has to be applied
      def self.run(selected)
        new(selected).run
      end

      # @return [Boolean] true in config mode; false otherwise
      def config_mode?
        Yast::Mode.config
      end

      # @return [Boolean] true in autoinst mode; false otherwise
      def auto_mode?
        Yast::Mode.autoinst
      end

      # Convenience method for shortening access to Yast::DASDController
      #
      # @return [Yast::DASDController]
      def controller
        Yast::DASDController
      end
    end
  end
end
