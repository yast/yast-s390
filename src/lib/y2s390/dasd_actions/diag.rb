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

require "y2s390/dasd_actions/base"

module Y2S390
  module DasdActions
    # Base class for DIAG access actions
    class Diag < Base
      # @return [Boolean] Whether the DIAG access should be active or not
      attr_accessor :use_diag

      # Activate or deactivate the DIAG access for selected DASDs
      #
      # Based on the valud of {#use_diag}. See {DiagOn} and {DiagOff}
      def run
        if Yast::Mode.config
          selected.each { |dasd| dasd.diag_wanted = !!use_diag }
        else
          selected.each do |dasd|
            controller.ActivateDiag(dasd.id, !!use_diag) if dasd.io_active?
            dasd.diag_wanted = !!use_diag
          end

          controller.ProbeDisks
        end

        true
      end
    end

    # Action for turning off the DIAG access of selected DASDs
    class DiagOff < Diag
      # Constructor
      #
      # @param selected [Array<Y2S390::Dasd>]
      def initialize(selected)
        @use_diag = false
        super(selected)
      end
    end

    # Action for turning on the DIAG access of selected DASDs
    class DiagOn < Diag
      # Constructor
      #
      # @param selected [Array<Y2S390::Dasd>]
      def initialize(selected)
        @use_diag = true
        super(selected)
      end
    end
  end
end
