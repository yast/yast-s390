require "yast"
require "y2s390/format_process"
require "ui/dialog"
require "ui/event_dispatcher"

Yast.import "UI"
Yast.import "Label"
Yast.import "Report"

module Y2S390
  module Dialogs
    # Class for displaying progress while formatting one or several DASDs.
    class FormatDialog < ::UI::Dialog
      attr_accessor :fmt_process
      attr_accessor :progress
      attr_accessor :cylinders
      attr_accessor :dasds

      abstract_method :dialog_content, :update_progress

      TIMEOUT_MILLISEC = 10

      # Constructor
      #
      # @param dasds [Array<Y2S390::Dasd>] list of DASDs to be formatted
      def initialize(dasds)
        textdomain "s390"
        @dasds = dasds
        @fmt_process = FormatProcess.new(dasds)
      end

      def run
        fmt_process.start
        wait_for_update
        return report_format_failed(fmt_process) unless fmt_process.running?

        fmt_process.initialize_summary
        create_dialog
        while fmt_process.running?
          fmt_process.update_summary
          wait_for_update
          update_progress
        end
        close_dialog
        return report_format_failed(fmt_process) if fmt_process.status.to_i != 0

        :refresh
      end

      def user_input
        Yast::UI.TimeoutUserInput(1000)
      end

    private

      def wait_for_update
        sleep(0.2)
      end

      def report_format_failed(process)
        Yast::Report.Error(format(_("Disks formatting failed. Exit code: %s.\nError output:%s"),
          process.status, process.error))

        nil
      end
    end
  end
end
