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

# File:	modules/OnPanic.ycp
# Package:	Configuration of OnPanic
# Summary:	Configuring OnPanic, input and output functions
# Authors:	Tim Hardeck <thardeck@suse.de>
#
# Representation of the dumpconf configuration.
# Input and output routines.
require "yast"

module Yast
  class OnPanicClass < Module
    def main
      textdomain "s390"

      Yast.import "FileUtils"
      Yast.import "Progress"
      Yast.import "Service"
      Yast.import "String"
      Yast.import "Integer"

      # Maximal allowed rows for VMCMD?
      @VMCMD_MAX_ROWS = 8

      # Maximal allowed characters for VMCMD?
      @VMCMD_MAX_CHARS = 128

      # Data was modified?
      @modified = false

      # Should dumpconf be started?
      @start = false

      # Panic reaction
      @on_panic = ""

      # Delay minutes
      @delay_min = 5

      # VMCMD commands
      @vmcmds = ""

      # Dump Device mkdump line
      @dump_line = ""

      # Dump Devices list of mkdump (no need to run mkdump more than once)
      @dump_devices = nil
    end

    # Get a List of available Dump Devices
    # @return [Array<String>] of disks
    def AvailableDumpDevices
      cmd = "mkdump --list-dump"
      Builtins.y2milestone("Running command %1", cmd)
      output = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      Builtins.y2milestone(
        "Command return code: %1",
        Ops.get_integer(output, "exit", 0)
      )
      Builtins.y2milestone(
        "Command output:\n%1\n%2",
        Ops.get_string(output, "stdout", ""),
        Ops.get_string(output, "stderr", "")
      )
      dev_names = String.NewlineItems(Ops.get_string(output, "stdout", ""))
      deep_copy(dev_names)
    end

    # Converts a MKDump entry to a device parameters map for dumpconf
    # @param mkdump device line
    # @return [Hash] of device parameters
    def ConvertMkdumpToConf(dev_line)
      dev = {}

      entry = Builtins.splitstring(dev_line, "\t")
      is_dasd = Builtins.regexpmatch(
        Ops.get(entry, 0),
        "^/dev/dasd[[:lower:]]+$"
      )
      is_zfcp = Builtins.regexpmatch(Ops.get(entry, 0), "^/dev/sd[[:lower:]]+$")

      if is_dasd
        dev = Builtins.add(dev, "DUMP_TYPE", "ccw")
        dev = Builtins.add(dev, "DEVICE", Ops.get(entry, 2))
      end
      if is_zfcp
        dev = Builtins.add(dev, "DUMP_TYPE", "fcp")
        dev = Builtins.add(dev, "DEVICE", Ops.get(entry, 2))
        dev = Builtins.add(dev, "WWPN", Ops.get(entry, 3))
        dev = Builtins.add(dev, "LUN", Ops.get(entry, 4))
        dev = Builtins.add(dev, "BOOTPROG", "0")
        dev = Builtins.add(dev, "BR_LBA", "0")
      end

      if !is_dasd && !is_zfcp
        Builtins.y2milestone(
          "Incompatible mkdump line in ConvertMkdumpToConf(): \"%1\"",
          dev_line
        )
      end

      deep_copy(dev)
    end

    # Converts device parameters of dumpconf to an mkdump entry
    # @param dumpconf device map
    # @return [String] of a mkdump entry
    def ConvertConfToMkdump(dev)
      dev = deep_copy(dev)
      mkdump = ""

      type = Ops.get_string(dev, "DUMP_TYPE")
      Builtins.foreach(@dump_devices) do |entry|
        line = Builtins.splitstring(entry, "\t")
        if type == "ccw" &&
            Builtins.regexpmatch(Ops.get(line, 0), "^/dev/dasd[[:lower:]]+") &&
            Ops.get(line, 2) == Ops.get(dev, "DEVICE") ||
            # check for fitting zfcp
            type == "fcp" &&
                Builtins.regexpmatch(Ops.get(line, 0), "^/dev/sd[[:lower:]]+") &&
                Ops.get(line, 2) == Ops.get(dev, "DEVICE") &&
                Ops.get(line, 3) == Ops.get(dev, "WWPN") &&
                Ops.get(line, 4) == Ops.get(dev, "LUN") # check for fitting dasd
          mkdump = entry
          Builtins.y2milestone(
            "In /etc/sysconfig/dumpconf configured dump device found: %1",
            mkdump
          )
          raise Break
        end
      end

      if mkdump == ""
        Builtins.y2milestone("Couldn't find the configured dump device.")
      end

      mkdump
    end

    # Read OnPanic settings from /etc/sysconfig/dumpconf
    # @return true when file exists
    def ReadSysconfig
      Builtins.y2milestone("Reading Sysconfig entries")
      if FileUtils.Exists("/etc/sysconfig/dumpconf")
        @on_panic = Convert.to_string(
          SCR.Read(path(".sysconfig.dumpconf.ON_PANIC"))
        )

        @delay_min = Builtins.tointeger(
          Convert.to_string(SCR.Read(path(".sysconfig.dumpconf.DELAY_MINUTES")))
        )
        @delay_min = 5 if Ops.less_than(@delay_min, 0)

        dump_device = {}
        Builtins.foreach(
          ["DUMP_TYPE", "DEVICE", "WWPN", "LUN", "BOOTPROG", "BR_LBA"]
        ) do |type|
          value = Convert.to_string(
            SCR.Read(Ops.add(path(".sysconfig.dumpconf"), type))
          )
          dump_device = Builtins.add(dump_device, type, value) if value != ""
        end
        @dump_line = ConvertConfToMkdump(dump_device)

        config_entry = ""
        Builtins.foreach(Integer.RangeFrom(1, Ops.add(@VMCMD_MAX_ROWS, 1))) do |i|
          config_entry = Convert.to_string(
            SCR.Read(
              Ops.add(
                path(".sysconfig.dumpconf"),
                Ops.add("VMCMD_", Builtins.tostring(i))
              )
            )
          )
          if config_entry != ""
            # prevent leading newline
            @vmcmds = if @vmcmds == ""
              config_entry
            else
              Builtins.mergestring([@vmcmds, config_entry], "\n")
            end
          end
        end

        return true
      end
      false
    end

    # Read all OnPanic settings
    # @return true on success
    def Read
      # Dumpconf read dialog caption
      caption = _("Reading Dumpconf Configuration")
      steps = 2

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/2
          _("Checking dump devices"),
          # Progress stage 2/2
          _("Reading settings")
        ],
        [
          # Progress step 1/2
          _("Checking dump devices..."),
          # Progress step 2/2
          _("Reading the settings..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      Progress.NextStage
      @dump_devices = AvailableDumpDevices()

      Progress.NextStage
      ReadSysconfig()
      @start = Service.Enabled("dumpconf")

      Progress.NextStage

      true
    end

    # Write all OnPanic settings
    # @return true on success
    def Write
      return true if !@modified

      # Dumpconf write dialog caption
      caption = _("Saving Dumpconf Configuration")
      steps = 2

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/2
          _("Write the settings"),
          # Progress stage 2/2
          _("Restart the service")
        ],
        [
          # Progress step 1/2
          _("Writing the settings..."),
          # Progress step 2/2
          _("Restarting service..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      Progress.NextStage
      Builtins.y2milestone("Writing Sysconfig entries")
      SCR.Write(path(".sysconfig.dumpconf.ON_PANIC"), @on_panic)

      SCR.Write(path(".sysconfig.dumpconf.DELAY_MINUTES"), @delay_min)

      dump_device = ConvertMkdumpToConf(@dump_line)
      Builtins.foreach(
        ["DUMP_TYPE", "DEVICE", "WWPN", "LUN", "BOOTPROG", "BR_LBA"]
      ) do |type|
        SCR.Write(
          Ops.add(path(".sysconfig.dumpconf"), type),
          Ops.get_string(dump_device, type, "")
        )
      end

      vmcmd_list = Builtins.splitstring(@vmcmds, "\n")
      Builtins.foreach(Integer.RangeFrom(1, Ops.add(@VMCMD_MAX_ROWS, 1))) do |i|
        SCR.Write(
          Ops.add(
            path(".sysconfig.dumpconf"),
            Ops.add("VMCMD_", Builtins.tostring(i))
          ),
          Ops.get(vmcmd_list, Ops.subtract(i, 1), "")
        )
      end

      SCR.Write(path(".sysconfig.dumpconf"), nil)

      Progress.NextStage
      if @start
        Service.Enable("dumpconf")
        Service.Restart("dumpconf")
      else
        Service.Disable("dumpconf")
        Service.Stop("dumpconf")
      end

      Progress.NextStage
      true
    end

    publish variable: :VMCMD_MAX_ROWS, type: "const integer"
    publish variable: :VMCMD_MAX_CHARS, type: "const integer"
    publish variable: :modified, type: "boolean"
    publish variable: :start, type: "boolean"
    publish variable: :on_panic, type: "string"
    publish variable: :delay_min, type: "integer"
    publish variable: :vmcmds, type: "string"
    publish variable: :dump_line, type: "string"
    publish variable: :dump_devices, type: "list <string>"
    publish function: :ReadSysconfig, type: "boolean ()"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
  end

  OnPanic = OnPanicClass.new
  OnPanic.main
end
