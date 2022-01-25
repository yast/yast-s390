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

require "y2s390/dialogs/format_dialog"

module Y2S390
  module Dialogs
    class FormatDisks < FormatDialog
      def dialog_content
        textdomain "s390"

        VBox(
          HSpacing(70),
          *dasds_progress_bars
        )
      end

    private

      def dasds_progress_bars
        dasds.map.with_index { |d, i| ProgressBar(Id(i), format(_("Formatting %s:"), d), 100, 0) }
      end

      def update_progress
        fmt_process.updated.each do |index, status|
          Yast::UI.ChangeWidget(
            Id(index),
            :Label,
            # progress bar, %1 is device name, %2 and %3
            # integers,
            # eg. Formatting /dev/dasda: cylinder 123 of 12334 done
            format(_("Formatting %s: cylinder %s of %s done"),
              status.dasd.id, status.progress, status.cylinders)
          )
          Yast::UI.ChangeWidget(Id(index), :Value, (100 * status.progress) / status.cylinders)
          Yast::UI.ChangeWidget(Id(index), :Enabled, true)
        end
      end
    end
  end
end
