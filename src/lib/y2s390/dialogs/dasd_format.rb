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
require "y2s390/dialogs/format_dialog"

module Y2S390
  module Dialogs
    # Class for displaying progress while formatting one or several DASDs.
    class DasdFormat < FormatDialog
      def dialog_content
        textdomain "s390"

        MarginBox(
          1, # left and right margin
          0.45, # top and bottom margin; NCurses rounds this down to 0
          VBox(
            Heading(_("Formatting DASDs")),
            MinHeight(7, tables),
            VSpacing(1),
            ProgressBar(Id(:progress_bar), _("Total Progress"), 100, 0),
            VSpacing(1)
          )
        )
      end

    private

      def tables
        HBox(
          MinWidth(
            38,
            VBox(
              Left(Label(_("In Progress"))),
              in_progress_table
            )
          ),
          HSpacing(4),
          MinWidth(
            26,
            VBox(
              Left(Label(_("Done"))),
              done_table
            )
          )
        )
      end

      def in_progress_table
        Table(
          Id(:in_progress_table),
          Header(
            Right(_("Channel ID")),
            "Device",
            Right(_("Cyl.") + " " * 6) # reserve some space for more digits
          ),
          in_progress_items
        )
      end

      def in_progress_items
        @fmt_process.summary.values.reject(&:done?).map { |s| in_progress_item_for(s) }
      end

      def id_for(dasd)
        Id(dasd.device_name.to_sym)
      end

      def in_progress_item_for(status)
        d = status.dasd
        Item(id_for(d), d.id, d.device_name, format_cyl(status.progress, status.cylinders))
      end

      def done_item_for(status)
        d = status.dasd
        Item(id_for(d), d.id, "/dev/#{d.device_name}")
      end

      def format_cyl(current_cyl, total_cyl)
        "#{current_cyl}/#{total_cyl}"
      end

      def done_table
        Table(
          Id(:done_table),
          Header(Right(_("Channel ID")), _("Device")),
          done_items
        )
      end

      def done_items
        fmt_process.summary.values.select(&:done?).map { |s| done_item_for(s) }
      end

      def update_progress
        fmt_process.update_summary
        sleep(0.2)
        progress = fmt_process.progress
        cylinders = fmt_process.cylinders
        update_progress_percent(100 * progress / cylinders) if cylinders > 0
        fmt_process.updated.each_value { |s| s.done? ? refresh_tables : update_cyl_cell(s) }

        fmt_process.running? ? :continue : :break
      end

      def refresh_tables
        Yast::UI.ChangeWidget(Id(:in_progress_table), :Items, in_progress_items)
        Yast::UI.ChangeWidget(Id(:done_table), :Items, done_items)
      end

      def update_progress_percent(percent)
        @progress = percent
        Yast::UI.ChangeWidget(Id(:progress_bar), :Value, @progress)
      end

      # Update the cylinder cell for one item of the "In Progress" table.
      #
      # @param item_id [Term] ID of the table item to update
      # @param cyl [Integer] Current cylinder of that DASD
      # @param total_cyl [Integer] Total number of cylinders of that DASD
      #
      def update_cyl_cell(status)
        item_id = id_for(status.dasd)
        cyl = status.progress
        total_cyl = status.cylinders
        return if cyl <= 0 || cyl > total_cyl

        Yast::UI.ChangeWidget(Id(:in_progress_table), Cell(item_id, 2), format_cyl(cyl, total_cyl))
      end
    end
  end
end
