# Copyright (c) [2022] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "yast2/execute"

module Y2S390
  # This class is responsible for maintaining an specific DASD format progress
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

    # It increments the progress status based on the configured format size
    def update_progress!
      @progress += @size
    end

    # Return whether the format progress has been completed according to the number of cylinders
    #
    # @return [Boolean] whether the format progress has been completed or not
    def done?
      @cylinders <= @progress
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
    # @param dasds [Array<Y2S390::Dasd>]
    def initialize(dasds)
      @dasds = dasds
      @summary = {}
      @updated = {}
    end

    # Convenience method to start with the formatting process
    def start
      @id = Yast::SCR.Execute(Yast.path(".process.start_shell"), fmt_cmd)
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

    # Initializes the summary for the DASDs given in the constructor
    def initialize_summary
      dasds.each_with_index { |d, i| @summary[i] = FormatStatus.new(d, read_line.to_i) }
    end

    # Update the summary of the formatting progress reading the output of the format process
    def update_summary
      @updated = {}

      line = read

      return unless line

      log.info "Updating Summary"
      progress = line.split("|")
      progress.each do |d|
        next if d.to_s.empty?

        summary[d.to_i]&.update_progress!
        @updated[d.to_i] = summary[d.to_i]
      end
      log.info("The summary is #{summary.inspect}")
      log.info("Updated #{updated.inspect}")

      updated
    end

    # Total number of cylinders to be formatted
    #
    # @return [Integer]
    def cylinders
      summary.values.inject(0) { |sum, v| sum + v.cylinders }
    end

    # Current progress according to the cylinders formatted
    #
    # @return [Integer]
    def progress
      @summary.values.inject(0) { |sum, v| sum + v.progress }
    end

  private

    def fmt_cmd
      "/sbin/dasdfmt -Y -P #{dasds.size} -b 4096 -y -r #{SIZE} -m #{SIZE} #{disks_params}"
    end

    def disks_params
      dasds.map { |d| "-f /dev/#{d.device_name}" }.join(" ")
    end
  end
end
