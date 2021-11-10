require "yast"
require "abstract_method"

Yast.import "DASDController"
Yast.import "Mode"
Yast.import "Popup"

module Y2S390
  module DasdActions
    # Base class for all the DASD actions that can be performed over a collection of DASDs
    class Base
      include Yast::I18n

      # @return [Boolean]
      abstract_method :run
      # @return [Y2S390::DasdsCollection]
      attr_accessor :selected

      # Constructor
      #
      # @param selected [Y2S390::DasdsCollection] the collection of DASDs to which the action
      #   has to be applied
      def initialize(selected)
        textdomain "s390"
        @selected = selected
      end

      # @params selected [Y2S390::DasdsCollection] the collection of DASDs to which the action
      #   has to be applied
      def self.run(selected)
        new(selected).run
      end

      # @return [Boolean] true in config mode; false otherwise
      def config_mode?
        Yast::Mode.config
      end

      # @return [Boolean] true in autoinst mode; false otherwise
      def auto_mode?
        Yast::Mode.autoinst
      end

      # Convenience method
      def controller
        Yast::DASDController
      end
    end
  end
end
