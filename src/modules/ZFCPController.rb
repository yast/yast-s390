# Copyright (c) 2012 Novell, Inc.
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
# with this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may
# find current contact information at www.novell.com.

# File:  modules/ZFCPController.ycp
# Package:  Configuration of controller
# Summary:  Controller settings, input and output functions
# Authors:  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# Representation of the configuration of controller.
# Input and output routines.

require "yaml"
require "yast"

module Yast
  class ZFCPControllerClass < Module
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "s390"

      Yast.import "Mode"
      Yast.import "Report"
      Yast.import "Popup"
      Yast.import "Arch"

      @devices = {}

      @filter_min = "0.0.0000"
      @filter_max = "ff.f.ffff"

      @previous_settings = {}

      @controllers = nil

      @activated_controllers = nil

      @disk_configured = false

      # Data was modified?
      @modified = false

      @proposal_valid = false
    end

    # Data was modified?
    # @return true if modified
    def GetModified
      @modified
    end

    def SetModified(value)
      @modified = value

      nil
    end

    def IsValidChannel(channel)
      regexp = "^([[:xdigit:]]{1,2}).([[:xdigit:]]{1}).([[:xdigit:]]{4})$"
      Builtins.regexpmatch(channel, regexp)
    end

    def FormatChannel(channel)
      return channel if !IsValidChannel(channel)

      Builtins.tolower(channel)
    end

    def IsValidWWPN(wwpn)
      regexp = "^0x([[:xdigit:]]{1,16})$"
      Builtins.regexpmatch(wwpn, regexp)
    end

    def FormatWWPN(wwpn)
      return wwpn if !IsValidWWPN(wwpn)

      Builtins.tohexstring(Builtins.tointeger(wwpn), 16)
    end

    def IsValidLUN(lun)
      regexp = "^0x([[:xdigit:]]{1,16})$"
      Builtins.regexpmatch(lun, regexp)
    end

    def FormatLUN(lun)
      return lun if !IsValidLUN(lun)

      Builtins.tohexstring(Builtins.tointeger(lun), 16)
    end

    def GetNextLUN(lun)
      lun = "0" if lun.nil? || lun == ""

      old_lun = Builtins.tointeger(lun)
      new_lun = old_lun

      Builtins.foreach(@devices) do |_k, v|
        if old_lun ==
            Builtins.tointeger(Ops.get_string(v, ["detail", "fcp_lun"], ""))
          new_lun = if Ops.get_string(v, "vendor", "") == "IBM" &&
              Ops.get_string(v, "device", "") == "25f03"
            Ops.add(old_lun, 4294967296)
          else
            Ops.add(old_lun, 1)
          end
        end
      end

      Builtins.tohexstring(new_lun, 16)
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
      if !Mode.normal
        Builtins.foreach(@devices) do |_index, device|
          channel = Ops.get_string(device, ["detail", "controller_id"], "")
          wwpn = Ops.get_string(device, ["detail", "wwpn"], "")
          lun = Ops.get_string(device, ["detail", "fcp_lun"], "")
          ActivateDisk(channel, wwpn, lun)
        end
      end

      if !Mode.installation
        if @disk_configured
          # popup label
          UI.OpenDialog(Label(_("Running dracut.")))

          command = "/usr/bin/dracut --force"
          Builtins.y2milestone("Running command %1", command)
          ret = SCR.Execute(path(".target.bash"), command)
          Builtins.y2milestone("Exit code: %1", ret)

          UI.CloseDialog

          @disk_configured = false
        end
      end

      true
    end

    # Get all controller settings from the first parameter
    # (For use by autoinstallation.)
    # @param [Hash] settings The YCP structure to be imported.
    # @return [Boolean] True on success
    def Import(settings)
      settings = deep_copy(settings)
      index = -1
      @devices = Builtins.listmap(Ops.get_list(settings, "devices", [])) do |d|
        index = Ops.add(index, 1)
        m = {
          "detail" => {
            "controller_id" => FormatChannel(
              Ops.get_string(d, "controller_id", "")
            ),
            "wwpn"          => FormatWWPN(Ops.get_string(d, "wwpn", "")),
            "fcp_lun"       => FormatLUN(Ops.get_string(d, "fcp_lun", ""))
          }
        }
        { index => m }
      end

      true
    end

    # Dump the controller settings to a single map
    # (For use by autoinstallation.)
    # @return [Hash] Dumped settings (later acceptable by Import ())
    def Export
      l = Builtins.maplist(@devices) do |_k, v|
        {
          "controller_id" => Ops.get_string(v, ["detail", "controller_id"], ""),
          "wwpn"          => Ops.get_string(v, ["detail", "wwpn"], ""),
          "fcp_lun"       => Ops.get_string(v, ["detail", "fcp_lun"], "")
        }
      end

      { "devices" => l }
    end

    def GetDevices
      deep_copy(@devices)
    end

    # @param channel [String] "0.0.0000" "ab.c.Def0"
    # @return [String] "0000000" "abcdef0"
    def channel_sort_key(channel)
      parts = channel.downcase.split(".", 3)
      format("%02s%1s%4s", parts[0], parts[1], parts[2])
    end

    def GetFilteredDevices
      min = channel_sort_key(@filter_min)
      max = channel_sort_key(@filter_max)

      ret = GetDevices()
      Builtins.filter(ret) do |_k, d|
        channel = Ops.get_string(d, ["detail", "controller_id"], "")
        key = channel_sort_key(channel)
        min <= key && key <= max
      end
    end

    def AddDevice(device)
      device = deep_copy(device)
      index = 0
      index = Ops.add(index, 1) while Builtins.haskey(@devices, index)
      Ops.set(@devices, index, device)

      nil
    end

    def RemoveDevice(index)
      @devices = Builtins.remove(@devices, index)

      nil
    end

    def GetDeviceIndex(channel, wwpn, lun)
      ret = nil
      Builtins.foreach(@devices) do |index, d|
        if Ops.get_string(d, ["detail", "controller_id"], "") == channel &&
            Ops.get_string(d, ["detail", "wwpn"], "") == wwpn &&
            Ops.get_string(d, ["detail", "fcp_lun"], "") == lun
          ret = index
        end
      end
      ret
    end

    # Create a textual summary and a list of configured devices
    # @return summary of the current configuration
    def Summary
      ret = if Mode.config
        Builtins.maplist(@devices) do |_index, d|
          Builtins.sformat(
            _("Channel ID: %1, WWPN: %2, LUN: %3"),
            Ops.get_string(d, ["detail", "controller_id"], ""),
            Ops.get_string(d, ["detail", "wwpn"], ""),
            Ops.get_string(d, ["detail", "fcp_lun"], "")
          )
        end
      else
        Builtins.maplist(@devices) do |_index, d|
          Builtins.sformat(
            _("Channel ID: %1, WWPN: %2, LUN: %3, Device: %4"),
            Ops.get_string(d, ["detail", "controller_id"], ""),
            Ops.get_string(d, ["detail", "wwpn"], ""),
            Ops.get_string(d, ["detail", "fcp_lun"], ""),
            Ops.get_string(d, "dev_name", "")
          )
        end
      end

      Builtins.y2milestone("Summary: %1", ret)
      deep_copy(ret)
    end

    # Return packages needed to be installed and removed during
    # Autoinstallation to insure module has all needed software
    # installed.
    # @return [Hash] with 2 lists.
    def AutoPackages
      { "install" => [], "remove" => [] }
    end

    # Get available zfcp controllers
    # @return [Array<Hash{String => Object>}] of availabel Controllers
    def GetControllers
      if @controllers.nil?
        # Checking if it is a z/VM and evaluating all fcp controllers in
        # order to activate
        ret_vmcp = SCR.Execute(path(".target.bash_output"), "/sbin/vmcp q v fcp")
        if ret_vmcp["exit"] == 0
          devices = ret_vmcp["stdout"].split("\n").collect do |line|
            columns = line.split
            columns[1].downcase if columns[0] == "FCP"
          end.compact

          # Remove all needed devices from CIO device driver blacklist
          # in order to see it
          devices.each do |device|
            log.info "Removing #{device} from the CIO device driver blacklist"
            SCR.Execute(path(".target.bash"), "/sbin/cio_ignore -r #{device}")
          end
        end

        @controllers = Convert.convert(
          SCR.Read(path(".probe.storage")),
          from: "any",
          to:   "list <map <string, any>>"
        )
        @controllers = Builtins.filter(@controllers) do |c|
          Ops.get_string(c, "device", "") == "zFCP controller"
        end

        @controllers = Builtins.maplist(@controllers) do |c|
          Builtins.filter(c) do |k, _v|
            Builtins.contains(["sysfs_bus_id", "resource"], k)
          end
        end

        # zKVM uses virtio devices instead of ZFCP, skip the warning in that case
        if ret_vmcp != 0 && @controllers.empty? && !Arch.is_zkvm
          # TRANSLATORS: warning message
          Report.Warning(_("Cannot evaluate ZFCP controllers (e.g. in LPAR).\n" \
            "You will have to set it manually."))
        end

        Builtins.y2milestone("probed ZFCP controllers %1", @controllers)
      end
      deep_copy(@controllers)
    end

    # Check if ZFCP subsystem is available
    # @return [Boolean] whether the ZFCP-System is availble at all
    def IsAvailable
      !Builtins.isempty(GetControllers())
    end

    # Get available disks
    def ProbeDisks
      # popup label
      UI.OpenDialog(Label(_("Reading Configured ZFCP Devices")))

      index = -1
      @devices = Builtins.listmap(find_disks(force_probing: true)) do |d|
        index = Ops.add(index, 1)
        { index => d }
      end

      Builtins.y2milestone("probed ZFCP devices %1", @devices)

      UI.CloseDialog

      nil
    end

    # Report error occured during device activation
    # @param [String] channel string channel of the device
    # @param [Fixnum] ret integer exit code of the operation
    def ReportActivationError(channel, ret)
      case ret
      when 0

      when 1 # FIXME: check error codes in https://github.com/SUSE/s390-tools/blob/master/zfcp_host_configure#L60
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: no CCW was specified or sysfs is not mounted."),
            channel
          )
        )
      when 2
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: Invalid status for <online>."),
            channel
          )
        )
      when 3
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: No device found for <ccwid>."),
            channel
          )
        )
      when 4
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: WWPN invalid."),
            channel
          )
        )
      when 5
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: Could not activate WWPN for adapter %1."),
            channel
          )
        )
      when 6
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: Could not activate ZFCP device."),
            channel
          )
        )
      when 7
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: SCSI disk could not be deactivated."),
            channel
          )
        )
      when 8
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: LUN could not be unregistered."),
            channel
          )
        )
      when 9
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: WWPN could not be unregistered."),
            channel
          )
        )
      else
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification, %2 is integer code
            _("%1: Unknown error %2."),
            channel,
            ret
          )
        )
      end

      nil
    end

    # Report error occured during device activation
    # @param [String] channel string channel of the device
    # @param [Fixnum] ret integer exit code of the operation
    def ReportControllerActivationError(channel, ret)
      case ret
      when 0

      when 1
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: sysfs not mounted."),
            channel
          )
        )
      when 2
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: Invalid status for <online>."),
            channel
          )
        )
      when 3
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: Device <ccwid> does not exist."),
            channel
          )
        )
      when 4
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: Module zfcp could not be loaded."),
            channel
          )
        )
      when 5
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: Adapter status could not be changed."),
            channel
          )
        )
      when 6
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification
            _("%1: WWPN ports still active."),
            channel
          )
        )
      when 10
        msg = Builtins.sformat(
          # message, %1 is device identification
          _("%1: This host adapter supports auto LUN scan."),
          channel
        )
        # do not show this during auto install (bsc#1104021)
        Mode.autoinst ? log.info(msg) : Report.Message(msg)
      else
        Report.Error(
          Builtins.sformat(
            # error report, %1 is device identification, %2 is integer code
            _("%1: Unknown error %2."),
            channel,
            ret
          )
        )
      end

      nil
    end

    # Activates the controller unless it was already activated
    #
    # @param channel [String] channel
    def activate_controller(channel)
      return if activated_controller?(channel)

      command2 = Builtins.sformat(
        "/sbin/zfcp_host_configure '%1' %2",
        channel,
        1
      )
      Builtins.y2milestone("Running command \"%1\"", command2)
      ret2 = Convert.to_integer(SCR.Execute(path(".target.bash"), command2))
      Builtins.y2milestone(
        "Command \"%1\" returned with exit code %2",
        command2,
        ret2
      )

      if ret2 != 0
        ReportControllerActivationError(channel, ret2)
      else
        register_as_activated(channel)
      end
    end

    # Activate a disk
    # @param [String] channel string channel
    # @param [String] wwpn string wwpn (hexa number)
    # @param [String] lun string lun   (hexa number)
    def ActivateDisk(channel, wwpn, lun)
      disk = find_disk(channel, wwpn, lun)
      if disk
        log.info "Disk #{disk.inspect} is already active. Skipping the activation."
      else
        activate_controller(channel)
      end

      if disk.nil? && (wwpn != "" || lun != "") # we are not using allow_lun_scan
        command = Builtins.sformat(
          "/sbin/zfcp_disk_configure '%1' '%2' '%3' %4",
          channel,
          wwpn,
          lun,
          1
        )
        Builtins.y2milestone("Running command \"%1\"", command)
        ret = Convert.to_integer(SCR.Execute(path(".target.bash"), command))
        Builtins.y2milestone(
          "Command \"%1\" returned with exit code %2",
          command,
          ret
        )

        ReportActivationError(channel, ret)
      end

      @disk_configured = true

      nil
    end

    # Deactivate a disk
    # @param [String] channel string channel
    # @param [String] wwpn string wwpn (hexa number)
    # @param [String] lun string lun   (hexa number)
    def DeactivateDisk(channel, wwpn, lun)
      command = Builtins.sformat(
        "/sbin/zfcp_disk_configure '%1' '%2' '%3' %4",
        channel,
        wwpn,
        lun,
        0
      )
      Builtins.y2milestone("Running command \"%1\"", command)
      ret = Convert.to_integer(SCR.Execute(path(".target.bash"), command))
      Builtins.y2milestone(
        "Command \"%1\" returned with exit code %2",
        command,
        ret
      )

      ReportActivationError(channel, ret)

      @disk_configured = true

      nil
    end

    def runCommand(cmd)
      ret = []
      cmd_output = Convert.convert(
        SCR.Execute(path(".target.bash_output"), cmd),
        from: "any",
        to:   "map <string, any>"
      )
      if Ops.get_integer(cmd_output, "exit", -1) == 0
        ret = Builtins.splitstring(
          Ops.get_string(cmd_output, "stdout", ""),
          "\n"
        )
        ret = Builtins.filter(ret) do |row|
          Ops.greater_than(Builtins.size(row), 0)
        end
      else
        Popup.Error(Ops.get_string(cmd_output, "stderr", ""))
      end
      Builtins.y2milestone("command %1, output %2", cmd, cmd_output)
      deep_copy(ret)
    end

    def GetWWPNs(busid)
      runCommand(Builtins.sformat("zfcp_san_disc -b '%1' -W", busid))
    end

    def GetLUNs(busid, wwpn)
      runCommand(
        Builtins.sformat("zfcp_san_disc -b '%1' -p '%2' -L", busid, wwpn)
      )
    end

    publish variable: :devices, type: "map <integer, map <string, any>>"
    publish variable: :filter_min, type: "string"
    publish variable: :filter_max, type: "string"
    publish variable: :previous_settings, type: "map <string, any>"
    publish function: :ActivateDisk, type: "void (string, string, string)"
    publish function: :ProbeDisks, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish variable: :modified, type: "boolean"
    publish variable: :proposal_valid, type: "boolean"
    publish function: :SetModified, type: "void (boolean)"
    publish function: :IsValidChannel, type: "boolean (string)"
    publish function: :FormatChannel, type: "string (string)"
    publish function: :IsValidWWPN, type: "boolean (string)"
    publish function: :FormatWWPN, type: "string (string)"
    publish function: :IsValidLUN, type: "boolean (string)"
    publish function: :FormatLUN, type: "string (string)"
    publish function: :GetNextLUN, type: "string (string)"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
    publish function: :GetDevices, type: "map <integer, map <string, any>> ()"
    publish function: :GetFilteredDevices, type: "map <integer, map <string, any>> ()"
    publish function: :AddDevice, type: "void (map <string, any>)"
    publish function: :RemoveDevice, type: "void (integer)"
    publish function: :GetDeviceIndex, type: "integer (string, string, string)"
    publish function: :Summary, type: "list <string> ()"
    publish function: :AutoPackages, type: "map ()"
    publish function: :GetControllers, type: "list <map <string, any>> ()"
    publish function: :IsAvailable, type: "boolean ()"
    publish function: :DeactivateDisk, type: "void (string, string, string)"
    publish function: :GetWWPNs, type: "list <string> (string)"
    publish function: :GetLUNs, type: "list <string> (string, string)"

  private

    # In production, call SCR.Read(.probe.disk).
    # For testing, point YAST2_S390_PROBE_DISK to a YAML file
    # with the mock value.
    # Suggesstion:
    #   YAST2_S390_PROBE_DISK=test/data/probe_disk.yml rake run"[zfcp]"
    # @return [Array<Hash>] .probe.disk output
    def probe_or_mock_disks
      mock_filename = ENV["YAST2_S390_PROBE_DISK"]
      if mock_filename
        YAML.safe_load(File.read(mock_filename))
      else
        SCR.Read(path(".probe.disk"))
      end
    end

    # Finds the activated controllers
    #
    # Initially, it reads the activated controllers from hwinfo.
    #
    # @return [Array<String>] List of controller channels
    def activated_controllers
      return @activated_controllers if @activated_controllers

      ctrls = GetControllers().select do |ctrl|
        io = ctrl.fetch("resource", {}).fetch("io", [])
        io.any? { |i| i["active"] }
      end
      log.info "Already activated controllers: #{ctrls}"
      @activated_controllers = ctrls.map { |c| c["sysfs_bus_id"] }
    end

    # Mark a controller as activated
    #
    # @param channel [String] Channel
    def register_as_activated(channel)
      activated_controllers << channel
    end

    # Determines whether a controller is activated or not
    #
    # @param channel [String] Channel
    # @return [Boolean]
    def activated_controller?(channel)
      activated_controllers.include?(channel)
    end

    # Returns the zFCP disks
    #
    # Probes and returns the found zFCP . It caches the found disks.
    #
    # @param force_probing [Boolean] Ignore the cached values and probes again.
    # @return [Array<Hash>] Found zFCP disks
    def find_disks(force_probing: false)
      return @disks if @disks && !force_probing

      disks = probe_or_mock_disks
      disks = Builtins.filter(disks) do |d|
        d["driver"] == "zfcp"
      end

      tapes = Convert.convert(
        SCR.Read(path(".probe.tape")),
        from: "any",
        to:   "list <map <string, any>>"
      )
      tapes = Builtins.filter(tapes) do |d|
        Ops.get_string(d, "bus", "") == "SCSI"
      end

      disks_tapes = Convert.convert(
        Builtins.merge(disks, tapes),
        from: "list",
        to:   "list <map <string, any>>"
      )

      @disks = Builtins.maplist(disks_tapes) do |d|
        Builtins.filter(d) do |k, _v|
          Builtins.contains(["dev_name", "detail", "vendor", "device", "io"], k)
        end
      end
    end

    # Determines whether the disk is activated or not
    #
    # @param disk [Hash]
    # @return [Boolean]
    def active_disk?(disk)
      io = disk.fetch("resource", {}).fetch("io", []).first
      !!(io && io["active"])
    end

    # Finds a disk
    #
    # @param [String] channel string channel
    # @param [String] wwpn string wwpn (hexa number)
    # @param [String] lun string lun (hexa number)
    # @return [Hash,nil] Disk information is found; nil is the disk is not found
    def find_disk(channel, wwpn, lun)
      find_disks.find do |d|
        detail = d["detail"]
        next unless detail

        detail["controller_id"] == channel && detail["wwpn"] == wwpn && detail["fcp_lun"] == lun
      end
    end
  end

  ZFCPController = ZFCPControllerClass.new
  ZFCPController.main
end
