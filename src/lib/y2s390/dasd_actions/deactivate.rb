require "y2s390/dasd_actions/base"

module Y2S390
  module DasdActions
    class Deactivate < Base
      def run
        selected.each { |d| deactivate(d) }
        controller.ProbeDisks

        true
      end

    private

      def deactivate(dasd)
        controller.DeactivateDisk(dasd.id, dasd.diag_wanted)
      end
    end
  end
end
