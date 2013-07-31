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

# File:	modules/DASDController.ycp
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
  class DASDControllerClass < Module
    def main
      Yast.import "UI"
      textdomain "s390"

      Yast.import "Mode"
      Yast.import "Report"
      Yast.import "FileUtils"
      Yast.import "Popup"
      Yast.import "String"


      @devices = {}

      @filter_min = "0.0.0000"
      @filter_max = "0.0.ffff"

      @diag = {}


      # Have DASDs been configured so that mkinitrd and zipl need to be run?
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


    # Is this kind of disk controller available?
    # @return [Boolean] true if it is
    def Available
      true
    end


    def GetDeviceName(channel)
      dir = Builtins.sformat("/sys/bus/ccw/devices/%1/block/", channel)
      files = Convert.convert(
        SCR.Read(path(".target.dir"), dir),
        :from => "any",
        :to   => "list <string>"
      )
      if Builtins.size(files) == 1
        return Ops.add("/dev/", Ops.get(files, 0, ""))
      end
      nil
    end


    def IsValidChannel(channel)
      regexp = "^([[:xdigit:]]{1}).([[:xdigit:]]{1}).([[:xdigit:]]{4})$"
      Builtins.regexpmatch(channel, regexp)
    end

    def FormatChannel(channel)
      return channel if !IsValidChannel(channel)

      Builtins.tolower(channel)
    end


    # Read all controller settings
    # @return true on success
    def Read
      ProbeDisks()

      if !Mode.normal
        @devices = Builtins.filter(@devices) do |index, d|
          Ops.get_boolean(d, ["resource", "io", 0, "active"], false)
        end

        @devices = Builtins.mapmap(@devices) do |index, d|
          Ops.set(d, "format", Ops.get_boolean(d, "format", false))
          Ops.set(d, "diag", Ops.get_boolean(d, "diag", false))
          { index => d }
        end
      end

      @disk_configured = false
      true
    end


    # Write all controller settings
    # @return true on success
    def Write
      if !Mode.normal
        to_format = []

        Builtins.foreach(@devices) do |index, device|
          channel = Ops.get_string(device, "channel", "")
          format = Ops.get_boolean(device, "format", false)
          do_diag = Ops.get_boolean(device, "diag", false)
          ActivateDisk(channel, do_diag)
          if format
            dev_name = GetDeviceName(channel)
            to_format = Builtins.add(to_format, dev_name) if dev_name != nil
          end
        end

        Builtins.y2milestone("Disks to format: %1", to_format)

        FormatDisks(to_format, 8) if !Builtins.isempty(to_format)
      end

      if !Mode.installation
        if @disk_configured
          # popup label
          UI.OpenDialog(Label(_("Running mkinitrd and zipl.")))

          command = "/sbin/mkinitrd && /sbin/zipl"
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
        Ops.set(d, "channel", FormatChannel(Ops.get_string(d, "channel", "")))
        d = Builtins.filter(d) do |k, v|
          Builtins.contains(["channel", "format", "diag"], k)
        end
        { index => d }
      end

      true
    end


    # Dump the controller settings to a single map
    # (For use by autoinstallation.)
    # @return [Hash] Dumped settings (later acceptable by Import ())
    def Export
      l = Builtins.maplist(@devices) { |i, d| Builtins.filter(d) do |k, v|
        Builtins.contains(["channel", "format", "diag"], k)
      end }

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
        tmp_strs = Builtins.splitstring(Ops.get_string(d, "channel", ""), ".")
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



    def GetDeviceIndex(channel)
      ret = nil
      Builtins.foreach(@devices) do |index, d|
        ret = index if Ops.get_string(d, "channel", "") == channel
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
            _("Channel ID: %1, Format: %2, DIAG: %3"),
            Ops.get_string(d, "channel", ""),
            String.YesNo(Ops.get_boolean(d, "format", false)),
            String.YesNo(Ops.get_boolean(d, "diag", false))
          )
        end
      else
        active_devices = Builtins.filter(@devices) do |index, device|
          Ops.get_boolean(device, ["resource", "io", 0, "active"], false)
        end

        ret = Builtins.maplist(active_devices) do |index, d|
          Builtins.sformat(
            _("Channel ID: %1, Device: %2, DIAG: %3"),
            Ops.get_string(d, "channel", ""),
            Ops.get_string(d, "dev_name", ""),
            String.YesNo(Ops.get_boolean(d, "diag", false))
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


    # Check if DASD subsystem is available
    # @return [Boolean] True if more than one disk
    def IsAvailable
      disks = Convert.convert(
        SCR.Read(path(".probe.disk")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      disks = Builtins.filter(disks) do |d|
        Builtins.tolower(Ops.get_string(d, "device", "")) == "dasd"
      end

      count = Builtins.size(disks)
      Builtins.y2milestone("number of probed DASD devices %1", count)

      Ops.greater_than(count, 0)
    end


    # Probe for DASD disks
    def ProbeDisks
      # popup label
      UI.OpenDialog(Label(_("Reading Configured DASD Disks")))

      disks = Convert.convert(
        SCR.Read(path(".probe.disk")),
        :from => "any",
        :to   => "list <map <string, any>>"
      )
      disks = Builtins.filter(disks) do |d|
        Builtins.tolower(Ops.get_string(d, "device", "")) == "dasd"
      end

      disks = Builtins.maplist(disks) do |d|
        channel = Ops.get_string(d, "sysfs_bus_id", "")
        Ops.set(d, "channel", channel)
        active = Ops.get_boolean(d, ["resource", "io", 0, "active"], false)
        if active
          device = Ops.get_string(d, "dev_name", "")
          scr_out = Convert.to_map(
            SCR.Execute(
              path(".target.bash_output"),
              Builtins.sformat("dasdview -x -f '%1' | grep formatted", device)
            )
          )
          formatted = false
          if Ops.get_integer(scr_out, "exit", 0) == 0
            out = Ops.get_string(scr_out, "stdout", "")
            formatted = !Builtins.regexpmatch(
              Builtins.toupper(out),
              "NOT[ \t]*FORMATTED"
            )
          end
          Ops.set(d, "formatted", formatted)

          Ops.set(d, "partition_info", GetPartitionInfo(device)) if formatted

          diag_file = Builtins.sformat(
            "/sys/%1/device/use_diag",
            Ops.get_string(d, "sysfs_id", "")
          )
          if FileUtils.Exists(diag_file)
            use_diag = Convert.to_string(
              SCR.Read(path(".target.string"), diag_file)
            )
            Ops.set(d, "diag", Builtins.substring(use_diag, 0, 1) == "1")
            Ops.set(@diag, channel, Builtins.substring(use_diag, 0, 1) == "1")
          end
        end
        d = Builtins.filter(d) do |k, v|
          Builtins.contains(
            [
              "channel",
              "diag",
              "resource",
              "formatted",
              "partition_info",
              "dev_name",
              "detail",
              "device_id",
              "sub_device_id"
            ],
            k
          )
        end
        deep_copy(d)
      end

      index = -1
      @devices = Builtins.listmap(disks) do |d|
        index = Ops.add(index, 1)
        { index => d }
      end

      Builtins.y2milestone("probed DASD devices %1", @devices)

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
              _("%1: Could not change state of the device."),
              channel
            )
          )
        when 5
          # https://bugzilla.novell.com/show_bug.cgi?id=446998#c15
          Report.Error(
            Builtins.sformat(
              # error report, %1 is device identification
              _("%1: Device is not a DASD."),
              channel
            )
          )
        when 6
          # https://bugzilla.novell.com/show_bug.cgi?id=446998#c15
          Report.Error(
            Builtins.sformat(
              # error report, %1 is device identification
              _("%1: Could not load module."),
              channel
            )
          )
        when 7
          # http://bugzilla.novell.com/show_bug.cgi?id=561876#c8
          Report.Error(
            Builtins.sformat(
              # error report, %1 is device identification
              _("%1: Failed to activate DASD."),
              channel
            )
          )
        when 8
          # http://bugzilla.novell.com/show_bug.cgi?id=561876#c8
          Report.Error(
            Builtins.sformat(
              # error report, %1 is device identification
              _("%1: DASD is not formatted."),
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


    # Activate disk
    # @param [String] channel string Name of the disk to activate
    # @param [Boolean] diag boolean Activate DIAG or not
    def ActivateDisk(channel, diag)
      command = Builtins.sformat(
        "/sbin/dasd_configure '%1' %2 %3",
        channel,
        1,
        diag ? 1 : 0
      )
      Builtins.y2milestone("Running command \"%1\"", command)
      ret = Convert.to_integer(SCR.Execute(path(".target.bash"), command))
      Builtins.y2milestone(
        "Command \"%1\" returned with exit code %2",
        command,
        ret
      )

      if ret == 8
        popup = Builtins.sformat(
          _(
            "Device %1 is not formatted. Format device now?\n" +
              "If you want to format multiple devices in parallel,\n" +
              "press 'Cancel' and select 'Perform Action', 'Format' later on.\n"
          ),
          channel
        )
        if Mode.autoinst && Popup.TimedOKCancel(popup, 10) ||
            Popup.ContinueCancel(popup)
          cmd = Builtins.sformat(
            "ls '/sys/bus/ccw/devices/%1/block/' | tr -d '\n'",
            channel
          )
          disk = Convert.convert(
            SCR.Execute(path(".target.bash_output"), cmd),
            :from => "any",
            :to   => "map <string, any>"
          )
          if Ops.get_integer(disk, "exit", -1) == 0 &&
              Ops.greater_than(
                Builtins.size(Ops.get_string(disk, "stdout", "")),
                0
              )
            FormatDisks(
              [Builtins.sformat("/dev/%1", Ops.get_string(disk, "stdout", ""))],
              1
            )
            ActivateDisk(channel, diag)
          else
            Popup.Error(
              Builtins.sformat("Couldn't find device for %1 channel", channel)
            )
          end
        end
      elsif ret == 7
        # when return code is 7, set DASD offline
        # https://bugzilla.novell.com/show_bug.cgi?id=561876#c9
        DeactivateDisk(channel, diag)
      else
        ReportActivationError(channel, ret)
      end

      @disk_configured = true

      nil
    end


    # Deactivate disk
    # @param [String] channel string Name of the disk to deactivate
    # @param [Boolean] diag boolean Activate DIAG or not
    def DeactivateDisk(channel, diag)
      command = Builtins.sformat(
        "/sbin/dasd_configure '%1' %2 %3",
        channel,
        0,
        diag ? 1 : 0
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


    # Format disks
    # @param [Array<String>] disks_list list<string> List of disks to be formated
    # @param [Fixnum] par integer Number of disks that can be formated in parallel
    def FormatDisks(disks_list, par)
      disks_list = deep_copy(disks_list)
      if Ops.greater_than(par, Builtins.size(disks_list))
        par = Builtins.size(disks_list)
      end

      disks = {}
      disks_cmd = []
      index = -1
      Builtins.foreach(disks_list) do |device|
        index = Ops.add(index, 1)
        Ops.set(disks, index, device)
        disks_cmd = Builtins.add(disks_cmd, Builtins.sformat("-f '%1'", device))
      end
      disks_param = Builtins.mergestring(disks_cmd, " ")
      command = Builtins.sformat(
        "/sbin/dasdfmt -Y -P %1 -b 4096 -y -m 1 %2",
        par,
        disks_param
      )

      Builtins.y2milestone("Running command %1", command)
      contents = VBox(HSpacing(70))
      index = 0
      while Ops.less_than(index, par)
        # progress bar
        contents = Builtins.add(
          contents,
          ProgressBar(
            Id(index),
            Builtins.sformat(_("Formatting %1:"), Ops.get(disks, index, "")),
            100,
            0
          )
        )
        index = Ops.add(index, 1)
      end
      UI.OpenDialog(contents)
      cylinders = {}
      done = {}
      # start formatting on background
      process_id = Convert.to_integer(
        SCR.Execute(path(".process.start_shell"), command)
      )
      Builtins.y2milestone("Process start returned %1", process_id)
      # get the sizes of all disks
      index = 0
      while Ops.less_than(index, Builtins.size(disks))
        Builtins.y2milestone("Running first formatting cycle")
        Builtins.sleep(500)

        if !Convert.to_boolean(SCR.Read(path(".process.running"), process_id))
          UI.CloseDialog
          iret2 = Convert.to_integer(
            SCR.Read(path(".process.status"), process_id)
          )
          # error report, %1 is exit code of the command (integer)
          Report.Error(
            Builtins.sformat(
              _("Disks formatting failed. Exit code: %1."),
              iret2
            )
          )
          return
        end

        while Ops.less_than(index, Builtins.size(disks))
          line = Convert.to_string(
            SCR.Read(path(".process.read_line"), process_id)
          )
          break if line == nil

          siz = Builtins.tointeger(line)
          siz = 999999999 if siz == 0
          Ops.set(cylinders, index, siz)
          index = Ops.add(index, 1)
        end
      end
      Builtins.y2milestone("Sizes of disks: %1", cylinders)
      Builtins.y2milestone("Disks to format: %1", disks)
      last_step = []
      last_rest = ""
      while Convert.to_boolean(SCR.Read(path(".process.running"), process_id))
        Builtins.sleep(1000)
        buffer = Convert.to_string(SCR.Read(path(".process.read"), process_id))
        buffer = Ops.add(last_rest, buffer)
        progress = Builtins.splitstring(buffer, "|")
        this_step = {}
        if Convert.to_boolean(SCR.Read(path(".process.running"), process_id))
          last = Ops.subtract(Builtins.size(progress), 1)
          last_rest = Ops.get(progress, last, "")
          progress = Builtins.remove(progress, last)
        end
        Builtins.foreach(progress) do |d|
          if d != ""
            i = Builtins.tointeger(d)
            Ops.set(this_step, i, Ops.add(Ops.get(this_step, i, 0), 1))
          end
        end
        Builtins.foreach(this_step) do |k, v|
          Ops.set(done, k, Ops.add(Ops.get(done, k, 0), v))
        end
        this_step = Builtins.filter(this_step) do |k, v|
          Ops.less_than(Ops.get(done, k, 0), Ops.get(cylinders, k, 0))
        end
        difference = Ops.subtract(
          Builtins.size(last_step),
          Builtins.size(this_step)
        )
        index = -1
        while Ops.greater_than(difference, 0)
          index = Ops.add(index, 1)
          if !Builtins.haskey(this_step, Ops.get(last_step, index, 0))
            difference = Ops.subtract(difference, 1)
            Ops.set(this_step, Ops.get(last_step, index, 0), 0)
          end
        end
        index = 0
        siz = Builtins.size(this_step)
        Builtins.foreach(this_step) do |k, v|
          UI.ChangeWidget(
            Id(index),
            :Label,
            Builtins.sformat(
              # progress bar, %1 is device name, %2 and %3
              # integers,
              # eg. Formatting /dev/dasda: cylinder 123 of 12334 done
              _("Formatting %1: cylinder %2 of %3 done"),
              Ops.get(disks, k, ""),
              Ops.get(done, k, 0),
              Ops.get(cylinders, k, 0)
            )
          )
          UI.ChangeWidget(
            Id(index),
            :Value,
            Ops.divide(
              Ops.multiply(100, Ops.get(done, k, 0)),
              Ops.get(cylinders, k, 1)
            )
          )
          UI.ChangeWidget(Id(index), :Enabled, true)
          index = Ops.add(index, 1)
        end
        while Ops.less_than(index, par)
          UI.ChangeWidget(Id(index), :Label, "")
          UI.ChangeWidget(Id(index), :Value, 0)
          UI.ChangeWidget(Id(index), :Enabled, false)
          index = Ops.add(index, 1)
        end
      end
      UI.CloseDialog
      iret = Convert.to_integer(SCR.Read(path(".process.status"), process_id))
      if iret != 0
        # error report, %1 is exit code of the command (integer)
        Report.Error(
          Builtins.sformat(_("Disks formatting failed. Exit code: %1."), iret)
        )
      end

      nil
    end

    # Get partitioninfo
    # @param [String] disk string Disk to read info from
    # @return GetPartitionInfo string The info
    def GetPartitionInfo(disk)
      outmap = Convert.to_map(
        SCR.Execute(
          path(".target.bash_output"),
          Builtins.sformat("/sbin/fdasd -p '%1'", disk)
        )
      )

      # if not an eckd-disk it's an fba-disk. fba-disks have only one partition
      if Ops.get_integer(outmap, "exit", 0) != 0
        return Builtins.sformat("%11", disk)
      end

      out = Ops.get_string(outmap, "stdout", "")

      regexp = "^[ \t]*([^ \t]+)[ \t]+([0-9]+)[ \t]+([0-9]+)[ \t]+([0-9]+)[ \t]+([^ \t]+)[ \t]+([^ \t]+([ \t]+[^ \t]+))*[ \t]*$"

      l = Builtins.splitstring(out, "\n")
      l = Builtins.filter(l) { |s| Builtins.regexpmatch(s, regexp) }
      l = Builtins.maplist(l) do |s|
        tokens = Builtins.regexptokenize(s, regexp)
        Builtins.sformat(
          "%1 (%2)",
          Ops.get_string(tokens, 0, ""),
          Ops.get_string(tokens, 5, "")
        )
      end
      Builtins.mergestring(l, ", ")
    end

    publish :variable => :devices, :type => "map <integer, map <string, any>>"
    publish :variable => :filter_min, :type => "string"
    publish :variable => :filter_max, :type => "string"
    publish :variable => :diag, :type => "map <string, boolean>"
    publish :function => :ActivateDisk, :type => "void (string, boolean)"
    publish :function => :DeactivateDisk, :type => "void (string, boolean)"
    publish :function => :ProbeDisks, :type => "void ()"
    publish :function => :FormatDisks, :type => "void (list <string>, integer)"
    publish :function => :GetPartitionInfo, :type => "string (string)"
    publish :function => :GetModified, :type => "boolean ()"
    publish :variable => :proposal_valid, :type => "boolean"
    publish :function => :SetModified, :type => "void (boolean)"
    publish :function => :Available, :type => "boolean ()"
    publish :function => :IsValidChannel, :type => "boolean (string)"
    publish :function => :FormatChannel, :type => "string (string)"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
    publish :function => :Import, :type => "boolean (map)"
    publish :function => :Export, :type => "map <string, list> ()"
    publish :function => :GetDevices, :type => "map <integer, map <string, any>> ()"
    publish :function => :GetFilteredDevices, :type => "map <integer, map <string, any>> ()"
    publish :function => :AddDevice, :type => "void (map <string, any>)"
    publish :function => :RemoveDevice, :type => "void (integer)"
    publish :function => :GetDeviceIndex, :type => "integer (string)"
    publish :function => :Summary, :type => "list <string> ()"
    publish :function => :AutoPackages, :type => "map ()"
    publish :function => :IsAvailable, :type => "boolean ()"
  end

  DASDController = DASDControllerClass.new
  DASDController.main
end
