require "y2s390/dasd_actions/base"

module Y2S390
  module DasdActions
    class Diag < Base
      attr_accessor :use_diag

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

    class DiagOff < Diag
      def initialize(selected)
        super(selected)
        @use_diag = false
      end
    end

    class DiagOn < Diag
      def initialize(selected)
        super(selected)
        @use_diag = true
      end
    end
  end
end
