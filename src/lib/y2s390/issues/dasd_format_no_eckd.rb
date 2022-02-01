require "yast"
require "yast/i18n"
require "y2issues"

module Y2S390
  module Issues
    class DasdFormatNoECKD < Y2Issues::Issue
      include Yast::I18n

      def initialize(dasd)
        textdomain "S390"

        super(build_message(dasd), severity: :error)
      end

    private

      def build_message(dasd)
        format(
          _("Cannot format device '%s'. Only ECKD disks can be formatted."),
          dasd.device_name
        )
      end
    end
  end
end
