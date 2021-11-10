require "y2s390/base_collection"

module Y2S390
  class DasdsCollection < BaseCollection
    def filter(&block)
      self.class.new(@elements.select(&block))
    end

    def active
      filter(&:active?)
    end
  end
end
