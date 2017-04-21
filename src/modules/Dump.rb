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

# File:	modules/Dump.ycp
# Package:	Creation of s390 dump devices
# Summary:	Creating s390 dump devices, input and output functions
# Authors:	Tim Hardeck <thardeck@suse.de>
#
require "yast"

module Yast
  class DumpClass < Module
    def main
      textdomain "s390"

      Yast.import "Report"
      Yast.import "String"
      Yast.import "Progress"

      # DASD devices list of mkdump
      @dasd_disks = []
      # ZFCP devices list of mkdump
      @zfcp_disks = []
    end

    # Get a List of available Disks of type
    # @return [Array<String>] of disks
    def GetAvailableDisks(type)
      device_list = nil
      if type == "dasd" || type == "zfcp"
        cmd = Ops.add("mkdump --list-", type)
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
        device_list = String.NewlineItems(Ops.get_string(output, "stdout", ""))
      end
      deep_copy(device_list)
    end

    def Read
      caption = _("Checking Disks")
      steps = 2

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/2
          _("Checking DASD disks"),
          # Progress stage 2/2
          _("Checking ZFCP disks")
        ],
        [
          # Progress step 1/2
          _("Checking DASD disks..."),
          # Progress step 2/2
          _("Checking ZFCP disks..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      Progress.NextStage
      @dasd_disks = GetAvailableDisks("dasd")

      Progress.NextStage
      @zfcp_disks = GetAvailableDisks("zfcp")

      Progress.NextStage
      @dasd_disks != nil && @zfcp_disks != nil
    end

    # Format a disk as DUMP device
    # @param [String] dev string the disk device node
    # @param [Boolean] force boolean true to append the -f parameter
    # @return [Boolean] true on success
    def FormatDisk(dev, force)
      caption = _("Creating Dump Device")
      steps = 1

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/1
          _("Creating dump device")
        ],
        [
          # Progress step 1/1
          _("Creating dump device. This process might take some minutes."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      Progress.NextStage
      cmd = force ? "/sbin/mkdump --force" : "/sbin/mkdump"
      cmd = Ops.add(Ops.add(cmd, " "), dev)

      Builtins.y2milestone("Running command %1", cmd)
      output = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      ret = Ops.get_integer(output, "exit", 0)
      message = Ops.get_string(output, "stdout", "")
      err_message = Ops.get_string(output, "stderr", "")

      Builtins.y2milestone("mkdump return value: %1", ret)
      Builtins.y2milestone("mkdump message: %1", message) if message != ""
      if err_message != ""
        Builtins.y2milestone("mkdump error message: %1", err_message)
      end

      Progress.NextStage

      if ret != 0
        err = ""
        err = if ret == 11
          # error description
          _("Invalid or unusable disk (fatal).")
        elsif ret == 12
          # error description
          _(
            "Incompatible formatting or partitioning, correct with Force."
          )
        elsif ret == 13
          # error description
          _("Missing support programs.")
        elsif ret == 14
          # error description
          _("Missing or wrong parameters.")
        elsif ret == 15
          # error description
          _("Access problem.")
        else
          # error description, %1 is error code (integer)
          Builtins.sformat(_("Error code from support program: %1."), ret)
        end
        # error report, %1 is device name, %2 error description
        Report.Error(
          Builtins.sformat(_("Cannot create dump device %1:\n%2"), dev, err)
        )
        return false
      end
      true
    end

    publish variable: :dasd_disks, type: "list <string>"
    publish variable: :zfcp_disks, type: "list <string>"
    publish function: :Read, type: "boolean ()"
    publish function: :FormatDisk, type: "boolean (string, boolean)"
  end

  Dump = DumpClass.new
  Dump.main
end
