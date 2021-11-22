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

# File:	modules/Xpram.ycp
# Package:	Configuration of xpram
# Summary:	Xpram settings, input and output functions
# Authors:	Ihno Krumreich <Ihno@suse.de>
#
# $Id$
#
# Representation of the XpRAM configuration.
# Input and output routines.
require "yast"

module Yast
  class XpramClass < Module
    def main
      textdomain "xpram"

      Yast.import "FileUtils"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Service"

      # Data was modified?
      @modified = false

      # Should xpram be really started?
      @force = false

      # Should xpram be started?
      @start = false

      # mountpoint used for xpram
      @mountpoint = ""

      # Filesystem used for the XpRAM
      @fstype = ""
    end

    # Read xpram settings from /etc/sysconfig/xpram
    # @return true when file exists
    def ReadSysconfig
      if FileUtils.Exists("/etc/sysconfig/xpram")
        @mountpoint = Convert.to_string(
          SCR.Read(path(".sysconfig.xpram.XPRAM_MNTPATH"))
        )
        @mountpoint = "" if @mountpoint.nil?

        @fstype = Convert.to_string(
          SCR.Read(path(".sysconfig.xpram.XPRAM_FORCE"))
        )
        @force = @fstype == "yes"

        @fstype = Convert.to_string(
          SCR.Read(path(".sysconfig.xpram.XPRAM_FSTYPE"))
        )
        @fstype = "swap" if @fstype.nil?

        return true
      end
      false
    end

    # Read all xpram settings
    # @return true on success
    def Read
      ReadSysconfig()

      @start = Service.Status("xpram") == 0

      true
    end

    # Write all xpram settings
    # @return true on success
    def Write
      return true if !@modified

      # Xpram read dialog caption
      caption = _("Saving XPRAM Configuration")
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

      SCR.Write(path(".sysconfig.xpram.XPRAM_MNTPATH"), @mountpoint) if @mountpoint != ""
      SCR.Write(path(".sysconfig.xpram.XPRAM_FSTYPE"), @fstype)

      Progress.NextStage

      bret = Service.Stop("xpram")
      Builtins.y2milestone("Service::Stop (xpram) returns %1", bret)
      if !bret
        Report.Error(_("Error stopping xpram. Try \"rcxpram stop\" manually."))
      else
        if @force
          SCR.Write(path(".sysconfig.xpram.XPRAM_FORCE"), "yes")
        else
          SCR.Write(path(".sysconfig.xpram.XPRAM_FORCE"), "no")
        end

        if @start
          SCR.Write(path(".sysconfig.xpram.XPRAM_START"), "yes")
          bret = Service.Enable("xpram")
          Builtins.y2milestone("Service::Enable (xpram) returns %1", bret)
          SCR.Write(path(".sysconfig.xpram"), nil)
          bret = Service.Start("xpram")
          if !bret
            Report.Error(
              _("Error starting xpram. Try \"rcxpram start\" manually.")
            )
          end
          Builtins.y2milestone("Service::Start (xpram) returns %1", bret)
        else
          SCR.Write(path(".sysconfig.xpram.XPRAM_START"), "no")
          Service.Disable("xpram")
        end

        Progress.NextStage
      end
      true
    end

    publish variable: :modified, type: "boolean"
    publish variable: :force, type: "boolean"
    publish variable: :start, type: "boolean"
    publish variable: :mountpoint, type: "string"
    publish variable: :fstype, type: "string"
    publish function: :ReadSysconfig, type: "boolean ()"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
  end

  Xpram = XpramClass.new
  Xpram.main
end
