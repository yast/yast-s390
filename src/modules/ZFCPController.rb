# encoding: utf-8

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

# File:	modules/ZFCPController.ycp
# Package:	Configuration of controller
# Summary:	Controller settings, input and output functions
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# Representation of the configuration of controller.
# Input and output routines.
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


      @devices = {}

      @filter_min = "0.0.0000"
      @filter_max = "ff.f.ffff"

      @previous_settings = {}

      @controllers = nil

      @activated_controllers = {}


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
      lun = "0" if lun == nil || lun == ""

      old_lun = Builtins.tointeger(lun)
      new_lun = old_lun

      Builtins.foreach(@devices) do |k, v|
        if old_lun ==
            Builtins.tointeger(Ops.get_string(v, ["detail", "fcp_lun"], ""))
          if Ops.get_string(v, "vendor", "") == "IBM" &&
              Ops.get_string(v, "device", "") == "25f03"
            new_lun = Ops.add(old_lun, 4294967296)
          else
            new_lun = Ops.add(old_lun, 1)
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
      Builtins.foreach(@devices) do |index, device|
        channel = Ops.get_string(device, ["detail", "controller_id"], "")
        wwpn = Ops.get_string(device, ["detail", "wwpn"], "")
        lun = Ops.get_string(device, ["detail", "fcp_lun"], "")
        ActivateDisk(channel, wwpn, lun)
      end if !Mode.normal(
      )

      if !Mode.installation
        if @disk_configured
          # popup label
          UI.OpenDialog(Label(_("Running mkinitrd.")))

          command = "/sbin/mkinitrd"
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
      l = Builtins.maplist(@devices) do |k, v|
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



    def GetFilteredDevices
      min_strs = Builtins.splitstring(@filter_min, ".")
      min_css = Builtins.tointeger(Ops.add("0x", Ops.get(min_strs, 0, "")))
      min_lcss = Builtins.tointeger(Ops.add("0x", Ops.get(min_strs, 1, "")))
      min_chan = Builtins.tointeger(Ops.add("0x", Ops.get(min_strs, 2, "")))

      max_strs = Builtins.splitstring(@filter_max, ".")
      max_css = Builtins.tointeger(Ops.add("0x", Ops.get(max_strs, 0, "")))
      max_lcss = Builtins.tointeger(Ops.add("0x", Ops.get(max_strs, 1, "")))
      max_chan = Builtins.tointeger(Ops.add("0x", Ops.get(max_strs, 2, "")))

      ret = GetDevices()

      ret = Builtins.filter(ret) do |k, d|
        tmp_strs = Builtins.splitstring(
          Ops.get_string(d, ["detail", "controller_id"], ""),
          "."
        )
        tmp_css = Builtins.tointeger(Ops.add("0x", Ops.get(tmp_strs, 0, "")))
        tmp_lcss = Builtins.tointeger(Ops.add("0x", Ops.get(tmp_strs, 1, "")))
        tmp_chan = Builtins.tointeger(Ops.add("0x", Ops.get(tmp_strs, 2, "")))
        Ops.greater_or_equal(tmp_css, min_css) &&
          Ops.greater_or_equal(tmp_lcss, min_lcss) &&
          Ops.greater_or_equal(tmp_chan, min_chan) &&
          Ops.less_or_equal(tmp_css, max_css) &&
          Ops.less_or_equal(tmp_lcss, max_lcss) &&
          Ops.less_or_equal(tmp_chan, max_chan)
      end

      deep_copy(ret)
    end



    def AddDevice(d)
      d = deep_copy(d)
      index = 0
      while Builtins.haskey(@devices, index)
        index = Ops.add(index, 1)
      end
      Ops.set(@devices, index, d)

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
      ret = []

      if Mode.config
        ret = Builtins.maplist(@devices) do |index, d|
          Builtins.sformat(
            _("Channel ID: %1, WWPN: %2, LUN: %3"),
            Ops.get_string(d, ["detail", "controller_id"], ""),
            Ops.get_string(d, ["detail", "wwpn"], ""),
            Ops.get_string(d, ["detail", "fcp_lun"], "")
          )
        end
      else
        ret = Builtins.maplist(@devices) do |index, d|
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
      if @controllers == nil
        # Checking if it is a z/VM and evaluating all fcp controllers in
        # order to activate
        ret_vmcp = SCR.Execute(path(".target.bash_output"),"/sbin/vmcp q v fcp")
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
          :from => "any",
          :to   => "list <map <string, any>>"
        )
        @controllers = Builtins.filter(@controllers) do |c|
          Ops.get_string(c, "device", "") == "zFCP controller"
        end

        @controllers = Builtins.maplist(@controllers) { |c| Builtins.filter(c) do |k, v|
          Builtins.contains(["sysfs_bus_id"], k)
        end }

        if ret_vmcp != 0 && @controllers.size == 0
          # TRANSLATORS: warning message
          Report.Warning(_("Cannot evaluate ZFCP controllers (e.g. in LPAR).\nYou will have to set it manually."))
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

      disks = Convert.convert(
        SCR.Read(path(".probe.disk")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      disks = Builtins.filter(disks) do |d|
        Ops.get_string(d, "bus", "") == "SCSI"
      end

      tapes = Convert.convert(
        SCR.Read(path(".probe.tape")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      tapes = Builtins.filter(tapes) do |d|
        Ops.get_string(d, "bus", "") == "SCSI"
      end

      disks_tapes = Convert.convert(
        Builtins.merge(disks, tapes),
        :from => "list",
        :to   => "list <map <string, any>>"
      )

      disks_tapes = Builtins.maplist(disks_tapes) { |d| Builtins.filter(d) do |k, v|
        Builtins.contains(["dev_name", "detail", "vendor", "device"], k)
      end }

      index = -1
      @devices = Builtins.listmap(disks_tapes) do |d|
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
          Report.Message(
            Builtins.sformat(
              # message, %1 is device identification
              _("%1: This host adapter supports allow_lun_scan."),
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


    # Activate a disk
    # @param [String] channel string channel
    # @param [String] wwpn string wwpn (hexa number)
    # @param [String] lun string lun   (hexa number)
    def ActivateDisk(channel, wwpn, lun)
      if !Ops.get(@activated_controllers, channel, false)
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
          Ops.set(@activated_controllers, channel, true)
        end
      end

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
        :from => "any",
        :to   => "map <string, any>"
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

    publish :variable => :devices, :type => "map <integer, map <string, any>>"
    publish :variable => :filter_min, :type => "string"
    publish :variable => :filter_max, :type => "string"
    publish :variable => :previous_settings, :type => "map <string, any>"
    publish :function => :ActivateDisk, :type => "void (string, string, string)"
    publish :function => :ProbeDisks, :type => "void ()"
    publish :function => :GetModified, :type => "boolean ()"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :proposal_valid, :type => "boolean"
    publish :function => :SetModified, :type => "void (boolean)"
    publish :function => :IsValidChannel, :type => "boolean (string)"
    publish :function => :FormatChannel, :type => "string (string)"
    publish :function => :IsValidWWPN, :type => "boolean (string)"
    publish :function => :FormatWWPN, :type => "string (string)"
    publish :function => :IsValidLUN, :type => "boolean (string)"
    publish :function => :FormatLUN, :type => "string (string)"
    publish :function => :GetNextLUN, :type => "string (string)"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map ()"
    publish :function => :GetDevices, :type => "map <integer, map <string, any>> ()"
    publish :function => :GetFilteredDevices, :type => "map <integer, map <string, any>> ()"
    publish :function => :AddDevice, :type => "void (map <string, any>)"
    publish :function => :RemoveDevice, :type => "void (integer)"
    publish :function => :GetDeviceIndex, :type => "integer (string, string, string)"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :AutoPackages, :type => "map ()"
    publish :function => :GetControllers, :type => "list <map <string, any>> ()"
    publish :function => :IsAvailable, :type => "boolean ()"
    publish :function => :DeactivateDisk, :type => "void (string, string, string)"
    publish :function => :GetWWPNs, :type => "list <string> (string)"
    publish :function => :GetLUNs, :type => "list <string> (string, string)"
  end

  ZFCPController = ZFCPControllerClass.new
  ZFCPController.main
end
