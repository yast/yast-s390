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

# File:	modules/IUCVTerminal.ycp
# Package:	Configuration IUCV Terminal Settings
# Summary:	IUCV Terminal settings, input and output functions
# Authors:	Tim Hardeck <thardeck@suse.de>
#
require "yast"

module Yast
  class IUCVTerminalClass < Module
    def main
      textdomain "s390"

      Yast.import "FileUtils"
      Yast.import "Report"
      Yast.import "String"
      Yast.import "Progress"
      Yast.import "Integer"
      Yast.import "Bootloader"

      # Maximal allowed IUCV ttys, 999 is the absolute maximum
      @MAX_IUCV_TTYS = 99

      # Default Emulation for HVC
      @DEFAULT_HVC_EMULATION = "linux"

      # Text field for changing settings of all HVC instances
      @TEXT_INSTANCES_ALL = _("<all>")

      # Text field for not changing the HVC emulation
      @TEXT_EMU_NO_CHANGE = _("<don't change>")

      # List of all possible HVC terminals
      @POSSIBLE_HVC_INSTANCES = [
        @TEXT_INSTANCES_ALL,
        "hvc0",
        "hvc1",
        "hvc2",
        "hvc3",
        "hvc4",
        "hvc5",
        "hvc6",
        "hvc7"
      ]

      # List of all HVC emulations
      @HVC_EMULATIONS = [@TEXT_EMU_NO_CHANGE, "linux", "dumb", "xterm", "vt220"]

      # Data was modified?
      @modified = false

      # Number of IUCV instances
      @iucv_instances = 0

      # First part of the Terminal name (without the counter)
      @iucv_name = "lxterm"

      # Number of HVC instances
      @hvc_instances = 0

      # List of emulations per HVC device (first entry for hvc0, second for
      # hvc1 and so on)
      @hvc_emulations = []

      # Show kernel output on hvc0?
      @show_kernel_out_on_hvc = false

      # Allow only connections from the mentioned Terminal server
      @restrict_hvc_to_srvs = ""

      # Has the bootloader configuration changed?
      @has_bootloader_changed = false
    end

    # Read all settings
    # @return true on success
    def Read
      caption = _("Loading IUCV Terminal Configuration")
      steps = 2

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/3
          _("Check IUCVtty entries"),
          # Progress stage 2/3
          _("Check HVC entries"),
          # Progress stage 3/3
          _("Read kernel parameters")
        ],
        [
          # Progress step 1/3
          _("Checking IUCVtty entries..."),
          # Progress step 2/3
          _("Checking HVC entries..."),
          # Progress step 3/3
          _("Reading kernel parameters..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )


      # Load IUCVtty settings
      Progress.NextStage
      if FileUtils.Exists("/etc/inittab")
        @iucv_instances = 0
        if SCR.Read(path(".etc.inittab.i001")) != nil
          id = ""
          # count the iucvtty instances
          Builtins.foreach(Integer.RangeFrom(1, Ops.add(@MAX_IUCV_TTYS, 1))) do |i|
            id = "i"
            if Ops.less_than(i, 10)
              id = Ops.add(id, "00")
            elsif Ops.less_than(i, 100)
              id = Ops.add(id, "0")
            end
            if SCR.Read(
                Ops.add(path(".etc.inittab"), Ops.add(id, Builtins.tostring(i)))
              ) != nil
              @iucv_instances = Ops.add(@iucv_instances, 1)
            else
              raise Break
            end
          end
          # extract IUCVtty Terminal name
          if Ops.greater_than(@iucv_instances, 0)
            value = Convert.to_string(SCR.Read(path(".etc.inittab") + "i001"))
            # remove the following number
            temp = Builtins.regexptokenize(value, " ([a-z0-9]{1,7})1$")
            @iucv_name = Ops.get(temp, 0, "lxterm")
          end
        end
      end

      # Load HVC settings
      Progress.NextStage
      if FileUtils.Exists("/etc/inittab")
        @hvc_instances = 0
        if SCR.Read(path(".etc.inittab.h0")) != nil
          id = ""
          console2 = nil
          # count the hvc instances
          Builtins.foreach(Integer.RangeFrom(0, 8)) do |i|
            id = "h"
            console2 = Convert.to_string(
              SCR.Read(
                Ops.add(path(".etc.inittab"), Ops.add(id, Builtins.tostring(i)))
              )
            )
            if console2 != nil
              @hvc_instances = Ops.add(@hvc_instances, 1)
              # read emulation
              @hvc_emulations = Convert.convert(
                Builtins.merge(
                  @hvc_emulations,
                  Builtins.regexptokenize(console2, " (.{4,5})$")
                ),
                :from => "list",
                :to   => "list <string>"
              )
            else
              raise Break
            end
          end
        end
      end

      # Extract settings from the kernel parameters
      Progress.NextStage
      old_progress = Progress.set(false)
      Bootloader.Read
      Progress.set(old_progress)

      # load actual boot selection
      actual_boot_section = Bootloader.getDefaultSection

      restrict_hvc_to_srvs_output = Bootloader.getKernelParam(
        actual_boot_section,
        "hvc_iucv_allow"
      )
      if restrict_hvc_to_srvs_output != "false"
        @restrict_hvc_to_srvs = restrict_hvc_to_srvs_output
      end

      console = Bootloader.getKernelParam(actual_boot_section, "console")
      # if console is defined
      if console != "false"
        if console == "hvc0"
          @show_kernel_out_on_hvc = true
        else
          # since it is possible to use more than one console parameter and getKernelParam
          # is only able to read one, cmdline is used as fallback
          parameters = Convert.convert(
            SCR.Read(path(".proc.cmdline")),
            :from => "any",
            :to   => "list <string>"
          )
          Builtins.foreach(parameters) do |parameter|
            if Builtins.regexpmatch(parameter, "console=hvc0")
              @show_kernel_out_on_hvc = true
            end
          end
        end
      end

      Progress.NextStage
      true
    end


    # Write all settings
    # @return true on success
    def Write
      return true if !@modified

      # Inittab write dialog caption
      caption = _("Saving IUCV Terminal Configuration")
      steps = 2

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/4
          _("Write IUCVtty settings"),
          # Progress stage 2/4
          _("Write HVC settings"),
          # Progress stage 3/4
          _("Write kernel parameters"),
          # Progress stage 4/4
          _("Initialize Init")
        ],
        [
          # Progress step 1/4
          _("Writing IUCVtty settings..."),
          # Progress step 2/4
          _("Writing HVC settings..."),
          # Progress step 3/4
          _("Writing kernel parameters..."),
          # Progress step 4/4
          _("Initializing Init..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      # save IUCVtty settings
      Progress.NextStage
      id = ""
      Builtins.foreach(Integer.RangeFrom(1, Ops.add(@MAX_IUCV_TTYS, 1))) do |i|
        id = "i"
        if Ops.less_than(i, 10)
          id = Ops.add(id, "00")
        elsif Ops.less_than(i, 100)
          id = Ops.add(id, "0")
        end
        if Ops.less_or_equal(i, @iucv_instances)
          # the maximum for terminal ids are 8 characters
          SCR.Write(
            Ops.add(path(".etc.inittab"), Ops.add(id, Builtins.tostring(i))),
            Ops.add(
              Ops.add("2345:respawn:/usr/bin/iucvtty ", @iucv_name),
              Builtins.tostring(i)
            )
          )
        else
          # delete all other iucv inittab entries
          SCR.Write(
            Ops.add(path(".etc.inittab"), Ops.add(id, Builtins.tostring(i))),
            nil
          )
        end
      end

      # save HVC settings
      Progress.NextStage
      console = ""
      Builtins.foreach(Integer.RangeFrom(0, 8)) do |i|
        id = "h"
        # hvc starts with zero instead of 1
        if Ops.less_than(i, @hvc_instances)
          # this console was build according to the documentation from 2009 but SP2 seems to have already inittab entries
          # for HVC so using the same syntax
          # console = "2345:respawn:/sbin/agetty -L 9600 hvc" + tostring(i) + " " + hvc_emulations[i]:DEFAULT_HVC_EMULATION;

          console = Ops.add(
            Ops.add(
              Ops.add("2345:respawn:/sbin/ttyrun hvc", Builtins.tostring(i)),
              " /sbin/agetty -L 9600 %t "
            ),
            Ops.get(@hvc_emulations, i, @DEFAULT_HVC_EMULATION)
          )
          SCR.Write(
            Ops.add(path(".etc.inittab"), Ops.add(id, Builtins.tostring(i))),
            console
          )
        else
          # delete all other hvc inittab entries
          SCR.Write(
            Ops.add(path(".etc.inittab"), Ops.add(id, Builtins.tostring(i))),
            nil
          )
        end
      end

      # flush cache
      SCR.Write(path(".etc.inittab"), nil)

      # writing Kernel parameters
      Progress.NextStage
      actual_boot_section = Bootloader.getDefaultSection
      # only change/save the bootloader configuration if it was adjusted
      if @has_bootloader_changed
        # removing empty option
        @restrict_hvc_to_srvs = "false" if @restrict_hvc_to_srvs == ""
        Bootloader.setKernelParam(
          actual_boot_section,
          "hvc_iucv_allow",
          @restrict_hvc_to_srvs
        )

        # this might overwrite other console options but this is mentioned in the help text
        if @show_kernel_out_on_hvc
          Bootloader.setKernelParam(actual_boot_section, "console", "hvc0")
        else
          # remove console entry if there is only one or the last is hvc0
          # otherwise it might not be possible to access it with SetKernelParm
          # make sure not to remove other console tags
          if Bootloader.getKernelParam(actual_boot_section, "console") == "hvc0"
            Bootloader.setKernelParam(actual_boot_section, "console", "false")
          end
        end

        old_progress = Progress.set(false)
        Bootloader.Write
        Progress.set(old_progress)
      end

      # initialize init system
      Progress.NextStage
      cmd = "init q"
      Builtins.y2milestone("Running command %1", cmd)
      output = Convert.to_map(SCR.Execute(path(".target.bash_output"), cmd))
      message = Ops.add(
        Ops.get_string(output, "stdout", ""),
        Ops.get_string(output, "stderr", "")
      )
      Builtins.y2milestone("%1 output: %2", cmd, message)

      Progress.NextStage
      true
    end

    publish :variable => :MAX_IUCV_TTYS, :type => "const integer"
    publish :variable => :DEFAULT_HVC_EMULATION, :type => "const string"
    publish :variable => :TEXT_INSTANCES_ALL, :type => "const string"
    publish :variable => :TEXT_EMU_NO_CHANGE, :type => "const string"
    publish :variable => :POSSIBLE_HVC_INSTANCES, :type => "const list <string>"
    publish :variable => :HVC_EMULATIONS, :type => "const list <string>"
    publish :variable => :modified, :type => "boolean"
    publish :variable => :iucv_instances, :type => "integer"
    publish :variable => :iucv_name, :type => "string"
    publish :variable => :hvc_instances, :type => "integer"
    publish :variable => :hvc_emulations, :type => "list <string>"
    publish :variable => :show_kernel_out_on_hvc, :type => "boolean"
    publish :variable => :restrict_hvc_to_srvs, :type => "string"
    publish :variable => :has_bootloader_changed, :type => "boolean"
    publish :function => :Read, :type => "boolean ()"
    publish :function => :Write, :type => "boolean ()"
  end

  IUCVTerminal = IUCVTerminalClass.new
  IUCVTerminal.main
end
