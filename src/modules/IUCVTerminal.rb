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

# File:  modules/IUCVTerminal.ycp
# Package:  Configuration IUCV Terminal Settings
# Summary:  IUCV Terminal settings, input and output functions
# Authors:  Tim Hardeck <thardeck@suse.de>
#
require "yast"

module Yast
  import "Service"
  class IUCVTerminalClass < Module
    def main
      textdomain "s390"

      Yast.import "FileUtils"
      Yast.import "Report"
      Yast.import "String"
      Yast.import "Progress"
      Yast.import "Integer"
      Yast.import "Bootloader"
      Yast.import "Service"

      # Maximal allowed IUCV ttys
      @MAX_IUCV_TTYS = 999

      # Maximal allowed HVC ttys (there are only 8 hvc devices)
      @MAX_HVC_TTYS = 8

      # Systemd service template prefix
      @HVC_PREFIX = "serial-getty"
      @IUCV_PREFIX = "iucvtty"

      # Data was modified?
      @modified = false

      # Number of IUCV instances
      @iucv_instances = 0

      # First part of the Terminal name (without the counter)
      @iucv_name = "lxterm"

      # Number of HVC instances
      @hvc_instances = 0

      # Show kernel output on hvc0?
      @show_kernel_out_on_hvc = false

      # Allow only connections from the mentioned Terminal server
      @restrict_hvc_to_srvs = ""

      # Has the bootloader configuration changed?
      @has_bootloader_changed = false

      # getty.target.wants directory
      @getty_conf_dir = "/etc/systemd/system/getty.target.wants/"
    end

    def tty_entries(prefix)
      Dir.entries(@getty_conf_dir).select { |e| e =~ /^#{prefix}@.+\.service$/ }
    end

    def get_tty_num(prefix)
      tty_entries(prefix).count
    end

    def get_iucv_num
      get_tty_num(@IUCV_PREFIX)
    end

    def get_hvc_num
      get_tty_num(@HVC_PREFIX)
    end

    def get_iucv_name
      entry = tty_entries(@IUCV_PREFIX).min
      if entry
        match = entry.scan(/^#{@IUCV_PREFIX}@(.+)0\.service$/).first
        name = match.first if match
      end
      name || @iucv_name
    end

    def setup_iucv(target_num)
      target_num = @MAX_IUCV_TTYS if target_num > @MAX_IUCV_TTYS
      current_name = get_iucv_name

      # make sure to remove the old entries if the terminal name has changed
      setup_tty_instances(0, @IUCV_PREFIX, current_name) if current_name != @iucv_name
      setup_tty_instances(target_num, @IUCV_PREFIX, @iucv_name)
    end

    def setup_hvc(target_num)
      target_num = @MAX_HVC_TTYS if target_num > @MAX_HVC_TTYS
      setup_tty_instances(target_num, @HVC_PREFIX, "hvc")
    end

    def setup_tty_instances(target_num, prefix, name)
      existing_num = get_tty_num(prefix) - 1
      target_num -= 1
      return if existing_num == target_num

      if target_num > existing_num
        ((existing_num + 1)..target_num).each do |i|
          service_name = "#{prefix}@#{name}#{i}.service"
          SCR.Execute(path(".target.bash"), "systemctl enable #{service_name}")
          SCR.Execute(path(".target.bash"), "systemctl start #{service_name}")
        end
      else
        existing_num.downto(target_num + 1) do |index|
          service_name = "#{prefix}@#{name}#{index}.service"
          SCR.Execute(path(".target.bash"), "systemctl disable #{service_name}")
          SCR.Execute(path(".target.bash"), "systemctl stop #{service_name}")
        end
      end
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
      @iucv_instances = get_iucv_num
      @iucv_name = get_iucv_name

      # Load HVC settings
      Progress.NextStage
      @hvc_instances = get_hvc_num

      # Extract settings from the kernel parameters
      Progress.NextStage
      old_progress = Progress.set(false)
      Bootloader.Read
      Progress.set(old_progress)

      restrict_hvc_to_srvs_output = Bootloader.kernel_param(:common, "hvc_iucv_allow")
      @restrict_hvc_to_srvs = restrict_hvc_to_srvs_output if restrict_hvc_to_srvs_output != :missing

      console = Bootloader.kernel_param(:common, "console")
      # if console is defined
      if console != :missing
        if console == "hvc0"
          @show_kernel_out_on_hvc = true
        else
          # since it is possible to use more than one console parameter and kernel_param
          # is only able to read one, cmdline is used as fallback
          parameters = Convert.convert(
            SCR.Read(path(".proc.cmdline")),
            from: "any",
            to:   "list <string>"
          )
          Builtins.foreach(parameters) do |parameter|
            @show_kernel_out_on_hvc = true if Builtins.regexpmatch(parameter, "console=hvc0")
          end
        end
      end

      Progress.NextStage
      true
    end

    # Write all settings
    # @return true on success
    def Write
      return true unless @modified

      # Inittab write dialog caption
      caption = _("Saving IUCV Terminal Configuration")
      steps = 3

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
          _("Write kernel parameters")
        ],
        [
          # Progress step 1/4
          _("Writing IUCVtty settings..."),
          # Progress step 2/4
          _("Writing HVC settings..."),
          # Progress step 3/4
          _("Writing kernel parameters..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      # save IUCVtty settings
      Progress.NextStage
      setup_iucv(@iucv_instances)

      # save HVC settings
      Progress.NextStage
      setup_hvc(@hvc_instances)

      # writing Kernel parameters
      Progress.NextStage
      # only change/save the bootloader configuration if it was adjusted
      if @has_bootloader_changed
        # removing empty option
        @restrict_hvc_to_srvs = :missing if @restrict_hvc_to_srvs == ""
        Bootloader.modify_kernel_params("hvc_iucv_allow" => @restrict_hvc_to_srvs)

        # this might overwrite other console options but this is mentioned in the help text
        if @show_kernel_out_on_hvc
          Bootloader.modify_kernel_params("console" => "hvc0")
        elsif Bootloader.kernel_param(:common, "console") == "hvc0"
          # remove console entry if there is only one or the last is hvc0
          # otherwise it might not be possible to access it with SetKernelParm
          # make sure not to remove other console tags
          Bootloader.modify_kernel_params("console" => :missing)
        end

        old_progress = Progress.set(false)
        Bootloader.Write
        Progress.set(old_progress)
      end

      Progress.NextStage
      true
    end

    publish variable: :MAX_IUCV_TTYS, type: "const integer"
    publish variable: :modified, type: "boolean"
    publish variable: :iucv_instances, type: "integer"
    publish variable: :iucv_name, type: "string"
    publish variable: :hvc_instances, type: "integer"
    publish variable: :show_kernel_out_on_hvc, type: "boolean"
    publish variable: :restrict_hvc_to_srvs, type: "string"
    publish variable: :has_bootloader_changed, type: "boolean"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
  end

  IUCVTerminal = IUCVTerminalClass.new
  IUCVTerminal.main
end
