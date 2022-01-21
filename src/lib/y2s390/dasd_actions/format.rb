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
    class FormatOff < Base
      def run
        selected.each { |dasd| dasd.format_wanted = false }
        true
      end
    end

    class FormatOn < Base
      def run
        selected.each { |dasd| dasd.format_wanted = true }
        true
      end
    end

    class Format < Base
      def run
        textdomain "s390"

        return false unless can_be_formatted?
        return false unless really_format?

        controller.FormatDisks(selected)

        # We used to explicitly activate the DASD devices here, don't do
        # it - see bsc#1187012.

        controller.ProbeDisks

        true
      end

    private

      def can_be_formatted?
        # check if disks are R/W and active
        problem = nil

        selected.each do |dasd|
          if !dasd.io_active?
            # error report, %s is device identification
            problem = format(_("Disk %s is not active."), dasd.id)
          elsif dasd.access_type != "rw"
            # error report, %s is device identification
            problem = format(_("Disk %s is not accessible for writing."), dasd.id)
          elsif !dasd.can_be_formatted?
            problem =
              # TRANSLATORS %s is device idetification
              format(_("Disk %s cannot be formatted. Only ECKD disks can be formatted."), dasd.id)
          end
        end

        if problem
          Yast::Popup.Message(problem)
          return false
        end

        true
      end

      def really_format?
        channels_str = selected.map(&:id).join(", ")

        Yast::Popup.AnyQuestionRichText(
          Yast::Popup.NoHeadline,
          # popup question
          format(
            _(
              "Formatting these disks destroys all data on them.<br>\n" \
                "Really format the following disks?<br>\n" \
                "%s"
            ), channels_str
          ),
          60,
          20,
          Yast::Label.YesButton,
          Yast::Label.NoButton,
          :focus_no
        )
      end
    end
  end
end
