require "y2s390/base_collection"

module Y2S390
  # Represesnts a collection of DASD devices
  class DasdsCollection < BaseCollection
    # Returns a new collection holing only {Yast::Y2390::Dasd#active?} devices
    def active
      filter(&:active?)
    end

    # Returns a new collection after selecting devices matching given blcok
    def filter(&block)
      self.class.new(@elements.select(&block))
    end
  end
end
