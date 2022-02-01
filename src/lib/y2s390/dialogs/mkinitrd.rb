require "ui/dialog"

module Y2S390
  module Dialogs
    class Mkinitrd < ::UI::Dialog
      CMD = "/sbin/mkinitrd".freeze

      def dialog_content
        Label(_("Running mkinitrd."))
      end

      def self.run
        new.run
      end

      def run
        create_dialog
        Yast::Execute.on_target(CMD)
        close_dialog
      end
    end
  end
end
