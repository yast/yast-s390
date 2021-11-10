module Y2S390
  class FormattingStatus
    # @return [Symbol]
    attr_accessor :status
    # return [Integer, nil]
    attr_accessor :cylinders

    # return [Integer]
    attr_accessor :cylinders_formatted

    # return [String]
    attr_accessor :error_details

    # Constructor
    def initialize(cylinders = nil)
      @cylinders = cylinders
    end

    def format!
      @cylinders_formatted = 0
      @status = :formatting
    end

    def step!(cyl = 10)
      return if done?

      @cylinders_formatted += cyl
      done! if done?
    end

    def done?
      @cylinders_formatted >= @cylinders
    end

    def done!
      @status = :done
    end

    def error!(error)
      @status = :error
      @error_details = error
    end
  end
end
