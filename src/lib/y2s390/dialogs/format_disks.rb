require "y2s390/dialogs/format_dialog"

module Y2S390
  module Dialogs
    class FormatDisks < FormatDialog
      def dialog_content
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
