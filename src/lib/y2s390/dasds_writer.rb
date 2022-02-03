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
require "y2s390/dasds_reader"
require "y2issues"
require "y2issues/list"
require "y2s390/issues/dasd_format_no_eckd"

Yast.import "Popup"
Yast.import "Mode"

module Y2S390
  # This class is responsible of activating and formatting the current selection of DASDs
  class DasdsWriter
    include Yast::Logger
    include Yast::I18n

    # @return [Y2S390::DasdsCollection] selection of DASDs to be formatted
    attr_reader :dasds
    # @return [Boolean] whether unformatted DASDS should be formatted
    attr_reader :format_unformatted
    # @return [Y2Issues::IssuesList]
    attr_reader :issues
    # @return [Y2S390::DasdsCollection]
    attr_accessor :to_format
    # @return [Y2S390::DasdsCollection]
    attr_accessor :to_reactivate

    # Constructor
    #
    # @param collection [Y2S390::DasdsCollection]
    # @param format_unformatted [Boolean]
    def initialize(collection)
      textdomain "s390"

      Yast.import "DASDController"
      @dasds = collection
      @issues = Y2Issues::List.new
      @to_reactivate = @to_format = Y2S390::DasdsCollection.new([])
    end

    # Activates and formats the current selection of DASDs
    def write
      pre_format_activation
      obtain_dasds_to_format
      sanitize_to_format
      report_issues
      format_dasds
      reactivate_dasds
      read_dasds_data
    end

  private

    # It updates the DASDs info reading the information from the system activating also the devices
    # which are offline
    def pre_format_activation
      read_dasds_data
      activate_offline_dasds
      read_dasds_data
    end

    # Obtains the DASDs which should be formatted taking into account "format_unformatted" option
    # when them are not selected explicitly and select the unformatted devices to be reactivated
    # after the format is done.
    def obtain_dasds_to_format
      @to_format = @dasds.to_format(format_unformatted: Yast::DASDController.format_unformatted)
      @dasds.unformatted.each { |d| to_format << d } if format_unformatted?(@dasds.unformatted)
      @to_reactivate = to_format.unformatted
    end

    # It checks and adds issues when found about the selected DASDs that should be formatted
    def sanitize_to_format
      to_remove_disks = []
      to_format.each do |dasd|
        next if dasd.type == "ECKD"

        to_remove_disks << dasd
        issues << Y2S390::Issues::DasdFormatNoECKD.new(dasd)
      end
      to_remove_disks.each do |dasd|
        to_format.delete(dasd.id)
        to_reactivate.delete(dasd.id)
      end
    end

    # It reports found issues if any
    def report_issues
      Y2Issues.report(issues, error: nil) unless issues.empty?
    end

    # It formats selected DASDs
    def format_dasds
      Yast::DASDController.FormatDisks(to_format) unless to_format.empty?
    end

    # It reactivate the DASDs selected to be reactivated
    def reactivate_dasds
      to_reactivate.each do |dasd|
        # FIXME: general activation error handling - also in sync with above
        Yast::DASDController.ActivateDisk(dasd.id, !!dasd.diag_wanted)
      end
    end

    def activate_offline_dasds
      dasds.offline.each { |d| Yast::DASDController.activate_if_needed(d) }
    end

    # Ask the user whether the unformatted DASDs should be formatted or not
    #
    # @param devices [Y2S390::DasdsCollection]
    # return [Boolean]
    def format_unformatted?(devices)
      return false if Yast::Mode.autoinst || devices.empty?

      message = if devices.size == 1
        format(_("Device %s is not formatted. Format device now?"),
          devices.first.device_name)
      else
        format(_("There are %s unformatted devices. Format them now?"),
          devices.size)
      end

      Yast::Popup.ContinueCancel(message)
    end

    # Convenience method to obtain a new {Y2S390::DasdsReader} instance
    def reader
      @reader ||= Y2S390::DasdsReader.new
    end

    # Convenience method to refresh the info / state of the current DASDs selection
    def read_dasds_data
      reader.refresh_data!(@dasds)
    end
  end
end
