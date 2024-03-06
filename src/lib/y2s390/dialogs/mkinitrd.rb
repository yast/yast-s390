require "ui/dialog"

module Y2S390
  module Dialogs
    class Mkinitrd < ::UI::Dialog
      CMD = ["/usr/bin/dracut", "--force"].freeze

      def dialog_content
        textdomain "s390"
        Label(_("Running dracut."))
      end

      def self.run
        new.run
      end

      def run
        create_dialog
        Yast::Execute.on_target(*CMD)
        close_dialog
      end
    end
  end
end
