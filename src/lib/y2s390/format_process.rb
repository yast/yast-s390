require "yast"
require "yast2/execute"

module Y2S390
  class FormatStatus
    attr_accessor :progress, :cylinders, :dasd
    # Constructor
    #
    # @param dasd [Dasd]
    # @param cylinders [Ingeger]
    # @param format_size [Integer]
    def initialize(dasd, cylinders, format_size = 10)
      @dasd = dasd
      @cylinders = cylinders
      @progress = 0
      @size = format_size
    end

    def update_progress
      @progress += @size
    end

    def done?
      @cylinders <= @progress
    end

    def step!
      update_progress
    end
  end

  # This class is responsible of formatting a set of DASD volumes maintaining also the status of the
  # progress.
  class FormatProcess
    include Yast::Logger
    attr_accessor :id, :dasds, :summary, :updated

    SIZE = 10

    # Constructor
    #
    # @param dasds [Integer]
    def initialize(dasds)
      @dasds = dasds
      @summary = {}
      @updated = {}
    end

    def disks_params
      dasds.map { |d| "-f /dev/#{d.device_name}" }.join(" ")
    end

    # Convenience method to start with the formatting process
    def start
      cmd = "/sbin/dasdfmt -Y -P #{dasds.size} -b 4096 -y -r #{SIZE} -m #{SIZE} #{disks_params}"

      @id = Yast::SCR.Execute(Yast.path(".process.start_shell"), cmd)
    end

    # Checks whether the formatting process is still running or not
    #
    # @return [Boolean] true when running; false otherwise
    def running?
      return false unless @id

      Yast::SCR.Read(Yast.path(".process.running"), @id)
    end

    def read_line
      return "" unless @id

      Yast::SCR.Read(Yast.path(".process.read_line"), @id)
    end

    def read
      Yast::SCR.Read(Yast.path(".process.read"), @id)
    end

    def status
      Yast::SCR.Read(Yast.path(".process.status"), @id)
    end

    def error
      stderr = ""
      loop do
        line = Yast::SCR.Read(Yast.path(".process.read_line_stderr"))
        break unless line

        stderr << line
      end

      stderr
    end

    def initialize_summary
      dasds.each_with_index { |d, i| @summary[i] = FormatStatus.new(d, read_line.to_i) }
    end

    def update_summary
      @updated = {}

      line = read

      return unless line

      log.info "Updating Summary"
      progress = line.split("|")
      progress.each do |d|
        next if d.to_s.empty?

        summary[d.to_i]&.update_progress
        @updated[d.to_i] = summary[d.to_i]
      end
      log.info("The summary is #{summary.inspect}")
      log.info("Updated #{updated.inspect}")

      updated
    end

    def cylinders
      log.info("The summary is #{summary.values.inspect}")
      summary.values.inject(0) { |sum, v| sum + v.cylinders }
    end

    def progress
      @summary.values.inject(0) { |sum, v| sum + v.progress }
    end
  end
end
