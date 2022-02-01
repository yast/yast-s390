# Copyright (c) [2012-2022] SUSE LLC
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
require "yast2/popup"
require "yast2/execute"
require "shellwords"
require "y2s390/dialogs/format"
require "y2s390/dialogs/mkinitrd"
require "y2s390/dasds_reader"
require "y2s390/dasds_writer"
require "y2issues"

module Yast
  # Dasd controller settings
  class DASDControllerClass < Module
    include Yast::Logger

    # @return [Boolean] whether unformated devices should be formatted upon activation
    attr_reader :format_unformatted

    def main
      Yast.import "UI"
      textdomain "s390"

      Yast.import "Mode"
      Yast.import "Report"
      Yast.import "FileUtils"
      Yast.import "Popup"
      Yast.import "String"

      @devices = Y2S390::DasdsCollection.new([])

      @filter_min = "0.0.0000"
      @filter_max = "ff.f.ffff"

      @diag = {}

      # Have DASDs been configured so that mkinitrd needs to be run?
      @disk_configured = false

      # Data was modified?
      @modified = false

      @format_unformatted = false

      @proposal_valid = false
    end

    # Data was modified?
    # @return [Boolean] true if modified
    def GetModified
      @modified
    end

    # Set the data as modified or not according to the given parameter
    #
    # @param value [Boolean]
    def SetModified(value)
      @modified = value

      nil
    end

    # Returns whether the DASD channel ID is valid or not
    # @param channel [String]
    # @return [Boolean]
    def IsValidChannel(channel)
      regexp = /^([[:xdigit:]]{1,2}).([[:xdigit:]]{1}).([[:xdigit:]]{4})$/
      channel.match?(regexp)
    end

    # @param channel [Boolean]
    def FormatChannel(channel)
      return channel if !IsValidChannel(channel)

      channel.downcase
    end

    # Read all controller settings
    # @return true on success
    def Read
      ProbeDisks()

      @disk_configured = false
      true
    end

    # Write all controller settings
    # @return true on success
    def Write
      Y2S390::DasdsWriter.new(@devices).write if !Mode.normal

      if !Mode.installation && @disk_configured
        Y2S390::Dialogs::Mkinitrd.new.run
        @disk_configured = false
      end

      true
    end

    # Get all controller settings from the first parameter
    # (For use by autoinstallation.)
    # @param [Hash] settings The YCP structure to be imported.
    # @return [Boolean] True on success
    def Import(settings)
      settings = deep_copy(settings)
      imported_devices = settings.fetch("devices", []).map do |device|
        channel = FormatChannel(device.fetch("channel", ""))
        d = Y2S390::Dasd.new(channel)
        d.format_wanted = device.fetch("format", false)
        d.diag_wanted = device.fetch("diag", false)
        d
      end

      @devices = Y2S390::DasdsCollection.new(imported_devices)

      @format_unformatted = settings["format_unformatted"] || false

      true
    end

    # Dump the controller settings to a single map
    # (For use by autoinstallation.)
    # @return [Hash] Dumped settings (later acceptable by Import ())
    def Export
      # Exporting active DASD only.
      # (bnc#887407)
      active_devices = @devices.active

      if active_devices.empty?
        # If no device is active we are exporting all. So the admin
        # can patch this manually.
        log.info("No active DASD found. --> Taking all")
        active_devices = @devices
      end

      l = active_devices.map do |d|
        { "channel" => d.id, "diag" => d.diag_wanted, "format" => d.format_wanted }.compact
      end

      {
        "devices"            => l,
        "format_unformatted" => @format_unformatted
      }
    end

    def GetDevices
      @devices
    end

    # @param channel [String] "0.0.0000" "ab.c.Def0"
    # @return [String] "0000000" "abcdef0"
    def channel_sort_key(channel)
      parts = channel.downcase.split(".", 3)
      format("%02s%1s%4s", parts[0], parts[1], parts[2])
    end

    # @return {GetDevices} but filtered by filter_min and filter_max
    def GetFilteredDevices
      min = channel_sort_key(@filter_min).hex
      max = channel_sort_key(@filter_max).hex

      GetDevices().filter { |d| min <= d.hex_id && d.hex_id <= max }
    end

    # Returns a text list with the summary of the configured devices
    #
    # @return summary of the current configuration
    def Summary
      require "y2s390/presenters/summary"
      Y2S390::Presenters::DasdsSummary.new(Yast::Mode.config ? @devices : @devices.active).list
    end

    # In production, call SCR.Read(.probe.disk).
    # For testing, point YAST2_S390_PROBE_DISK to a YAML file
    # with the mock value.
    # Suggesstion:
    #   YAST2_S390_PROBE_DISK=test/data/probe_disk_dasd.yml rake run"[dasd]"
    # @return [Array<Hash>] .probe.disk output
    def probe_or_mock_disks
      mock_filename = ENV["YAST2_S390_PROBE_DISK"]
      if mock_filename
        YAML.safe_load(File.read(mock_filename))
      else
        SCR.Read(path(".probe.disk"))
      end
    end

    # Return packages needed to be installed and removed during
    # Autoinstallation to insure module has all needed software
    # installed.
    # @return [Hash] with 2 lists.
    def AutoPackages
      { "install" => [], "remove" => [] }
    end

    # Check if DASD subsystem is available
    # @return [Boolean] True if more than one disk
    def IsAvailable
      disks = find_disks(force_probing: true)
      count = disks.size
      log.info("number of probed DASD devices #{count}")
      count > 0
    end

    def reader
      @reader ||= Y2S390::DasdsReader.new
    end

    # Probe for DASD disks
    def ProbeDisks
      # popup label
      UI.OpenDialog(Label(_("Reading Configured DASD Disks")))

      @devices = reader.list(force_probing: true)
      log.info("probed DASD devices #{@devices.inspect}")

      UI.CloseDialog

      nil
    end

    # Report error occured during device activation
    # @param [String] channel string channel of the device
    # @param [Hash] ret output of bash_output agent run
    def ReportActivationError(channel, ret)
      return if ret["exit"] == 0

      case ret["exit"]
      when 1
        # error report, %1 is device identification
        Report.Error(Builtins.sformat(_("%1: sysfs not mounted."), channel))
      when 2
        # error report, %1 is device identification
        Report.Error(Builtins.sformat(_("%1: Invalid status for <online>."), channel))
      when 3
        # error report, %1 is device identification
        Report.Error(Builtins.sformat(_("%1: No device found for <ccwid>."), channel))
      when 4
        # error report, %1 is device identification
        Report.Error(Builtins.sformat(_("%1: Could not change state of the device."), channel))
      when 5
        # https://bugzilla.novell.com/show_bug.cgi?id=446998#c15
        # error report, %1 is device identification
        Report.Error(Builtins.sformat(_("%1: Device is not a DASD."), channel))
      when 6
        # https://bugzilla.novell.com/show_bug.cgi?id=446998#c15
        # error report, %1 is device identification
        Report.Error(Builtins.sformat(_("%1: Could not load module."), channel))
      when 7
        # http://bugzilla.novell.com/show_bug.cgi?id=561876#c8
        # error report, %1 is device identification
        Report.Error(Builtins.sformat(_("%1: Failed to activate DASD."), channel))
      when 8
        # http://bugzilla.novell.com/show_bug.cgi?id=561876#c8
        # error report, %1 is device identification
        Report.Error(Builtins.sformat(_("%1: DASD is not formatted."), channel))
      when 16
        # https://bugzilla.suse.com/show_bug.cgi?id=1091797#c8
        # TRANSLATORS: error report, %1 is device identification
        message = Builtins.sformat(_("%1 DASD is in use and cannot be deactivated."), channel)
        report_error(_("Error: channel in use"), message, output_details(ret))
      else
        # TRANSLATORS: error message, %1 is device identification, %2 is an integer code
        message = Builtins.sformat(_("%1 Unknown error %2"), channel, ret["exit"])
        report_error(message, _("Unknown error"), output_details(ret))
      end

      nil
    end

    # Activate disk
    # @param [String] channel string Name of the disk to activate
    # @param [Boolean] diag boolean Activate DIAG or not
    # @return [Integer] exit code of the activation command
    def ActivateDisk(channel, diag)
      command = "/sbin/dasd_configure '#{channel}' 1 #{diag ? 1 : 0}"
      Builtins.y2milestone("Running command \"%1\"", command)
      ret = SCR.Execute(path(".target.bash_output"), command)
      Builtins.y2milestone("Command \"#{command}\" returned #{command}")

      case ret["exit"]
      when 8
        # unformatted disk is now handled now outside this function
        # however, don't issue any error
        log.info("Unformatted disk #{channel}, nothing to do")
      when 7
        # when return code is 7, set DASD offline
        # https://bugzilla.novell.com/show_bug.cgi?id=561876#c9
        DeactivateDisk(channel, diag)
      else
        ReportActivationError(channel, ret)
      end

      @disk_configured = true

      ret["exit"]
    end

    # Activates a disk if it is not active
    #
    # When the disk is already activated, it returns '8' if the
    # disk is unformatted or '0' otherwise. The idea is to mimic
    # the same API than ActivateDisk.
    #
    # @return [Integer] Returns an error code (8 means 'unformatted').
    def activate_if_needed(dasd)
      if dasd.io_active?
        log.info "Dasd #{dasd.inspect} is already active. Skipping the activation."
        return dasd.formatted? ? 0 : 8
      end

      ret = ActivateDisk(dasd.id, !!dasd.diag_wanted)
      reader.update_info(dasd, extended: true)
      ret
    end

    # Deactivate disk
    # @param [String] channel string Name of the disk to deactivate
    # @param [Boolean] diag boolean Activate DIAG or not
    def DeactivateDisk(channel, diag)
      command = "/sbin/dasd_configure '#{channel}' 0 #{diag ? 1 : 0} < /dev/null"
      log.info("Running command \"#{command}\"")
      ret = SCR.Execute(path(".target.bash_output"), command)
      log.info("Command \"#{command}\" returned with exit code #{ret}")

      ReportActivationError(channel, ret)

      @disk_configured = true

      nil
    end

    # Activate or deactivate diag on active disk
    # @param [String] channel string Name of the disk to operate on
    # @param [Boolean] value boolean Activate DIAG or not
    def ActivateDiag(channel, value)
      dasd = devices.by_id(channel)
      return if !dasd || value == dasd.diag_wanted

      DeactivateDisk(dasd.id, dasd.diag_wanted)
      ActivateDisk(dasd.id, value)
    end

    # It formats the given disks showing the progress in a separate dialog
    #
    # @param [S390::DasdsCollection] collection of dasds to be be formatted
    def FormatDisks(disks_list)
      log.info "Disks to format: #{disks_list}"

      format_dialog_for(disks_list).run
    end

    publish variable: :devices, type: "map <integer, map <string, any>>"
    publish variable: :filter_min, type: "string"
    publish variable: :filter_max, type: "string"
    publish variable: :diag, type: "map <string, boolean>"
    publish function: :ActivateDisk, type: "integer (string, boolean)"
    publish function: :DeactivateDisk, type: "void (string, boolean)"
    publish function: :ProbeDisks, type: "void ()"
    publish function: :FormatDisks, type: "void (list <string>, integer)"
    publish function: :GetModified, type: "boolean ()"
    publish variable: :proposal_valid, type: "boolean"
    publish function: :SetModified, type: "void (boolean)"
    publish function: :IsValidChannel, type: "boolean (string)"
    publish function: :FormatChannel, type: "string (string)"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map <string, list> ()"
    publish function: :GetDevices, type: "map <integer, map <string, any>> ()"
    publish function: :GetFilteredDevices, type: "map <integer, map <string, any>> ()"
    publish function: :Summary, type: "list <string> ()"
    publish function: :AutoPackages, type: "map ()"
    publish function: :IsAvailable, type: "boolean ()"

  private

    # It obtains the dialog to be used by the FormatProcess according to the NEW_FORMAT environment
    # variable
    #
    # @param [S390::DasdsCollection] collection of dasds to be be formatted
    def format_dialog_for(disks_list)
      if ENV["NEW_FORMAT"]
        Y2S390::Dialogs::DasdFormat
      else
        Y2S390::Dialogs::FormatDisks
      end.new(disks_list)
    end

    # Convenience method to convert the device ID to integers for filtering purposes
    #
    # @param [String] the DASD id
    # @return [Array<Integer, Integer, Integer>] the css, lcss and channel in integer format
    def int_channels(channel_id)
      css, lcss, chan = channel_id.split(".")
      [css, lcss, chan].map { |c| "0x#{c}".to_i }
    end

    # Returns an string containing the available stdout and/or stderr
    #
    # @param ret [Hash]
    # @return [String]
    def output_details(ret)
      output = {
        stderr: ret["stderr"].to_s.strip,
        stdout: ret["stdout"].to_s.strip
      }

      output.map { |k, v| "#{k}: #{v}" unless v.empty? }.compact.join("\n\n")
    end

    # Reports the error in the proper way
    #
    # When an error has details to give more feedback, it is preferable to display it in a Popup
    # unless the code has been executed by AutoYaST, in which case the Yast::Report.Error must be
    # used to avoid blocking it.
    def report_error(headline, message, details)
      if Mode.auto || details.empty?
        Report.Error("#{message}\n#{details}")
      else
        Yast2::Popup.show(message, headline: headline, details: details)
      end
    end

    # Determines whether the disk is activated or not
    #
    # Since any of its IO elements in 'resource' is active, consider the device
    # as 'active'.
    #
    # @param disk [Hash]
    # @return [Boolean]
    def active_disk?(disk)
      io = disk.fetch("resource", {}).fetch("io", [])
      io.any? { |i| i["active"] }
    end

    # Determines whether the disk is formatted or not
    #
    # @param disk [Hash]
    # @return [Boolean]
    def formatted?(disk)
      device = disk.fetch("dev_name", "")
      fmt_out = Yast::Execute.stdout.locally!(
        ["/sbin/dasdview", "--extended", device], ["grep", "formatted"]
      )
      fmt_out.empty? ? false : !fmt_out.upcase.match?(/NOT[ \t]*FORMATTED/)
    end

    # Determines whether the disk has the DIAG access enabled or not
    #
    # @param disk [Hash]
    # @return [Boolean]
    def use_diag?(disk)
      diag_file = "/sys/#{disk["sysfs_id"]}/device/use_diag"
      use_diag = SCR.Read(path(".target.string"), diag_file) if File.exist?(diag_file)
      use_diag.to_i == 1
    end

    DASD_ATTRS = ["channel", "diag", "resource", "formatted", "partition_info", "dev_name",
                  "detail", "device_id", "sub_device_id"].freeze

    # Returns the DASD disks
    #
    # Probes and returns the found DASD disks ordered by channel.
    # It caches the found disks.
    #
    # @param force_probing [Boolean] Ignore the cached values and probes again.
    # @return [Array<Hash>] Found DASD disks
    def find_disks(force_probing: false)
      reader = Y2S390::HwinfoReader.instance
      reader.reset if force_probing
      reader.data
    end
  end

  DASDController = DASDControllerClass.new
  DASDController.main
end
