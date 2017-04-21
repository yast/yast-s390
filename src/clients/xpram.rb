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

# File:	clients/xpram.ycp
# Package:	Configuration of xpram
# Summary:	Main file
# Authors:	Ihno Krumreich <Ihno@suse.de>
#
# $Id$
#
# Main file for xpram configuration. Uses all other files.
module Yast
  class XpramClient < Client
    def main
      Yast.import "UI"

      # **
      # <h3>Configuration of xpram</h3>

      textdomain "xpram"

      # The main ()
      Builtins.y2milestone("--------- Xpram module started ---------")

      Yast.import "CommandLine"
      Yast.import "Xpram"

      Yast.include self, "s390/xpram/ui.rb"

      @cmdline_description = {
        "id"         => "xpram",
        # Command line help text for the Xxpram module
        "help"       => _(
          "Configuration of XPRAM"
        ),
        "guihandler" => fun_ref(method(:XpRAMSequence), "symbol ()"),
        "initialize" => fun_ref(Xpram.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Xpram.method(:Write), "boolean ()"),
        "actions"    => {
          "enable"    => {
            "handler" => fun_ref(method(:XpramEnableHandler), "boolean (map)"),
            # command line help text for 'enable' action
            "help"    => _(
              "Enable XPRAM"
            )
          },
          "disable"   => {
            "handler" => fun_ref(method(:XpramDisableHandler), "boolean (map)"),
            # command line help text for 'disable' action
            "help"    => _(
              "Disable XPRAM"
            )
          },
          "configure" => {
            "handler" => fun_ref(
              method(:XpramChangeConfiguration),
              "boolean (map)"
            ),
            # command line help text for 'configure' action
            "help"    => _(
              "Change the XPRAM configuration"
            )
          }
        },
        "options"    => {
          "mountpoint" => {
            # command line help text for the 'mountpoint' option
            "help" => _(
              "Mount point"
            ),
            "type" => "string"
          }
        },
        "mappings"   => {
          "enable"    => ["mountpoint"],
          "disable"   => [],
          "configure" => ["mountpoint"]
        }
      }

      # main ui function
      @ret = CommandLine.Run(@cmdline_description)

      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("--------- Xpram module finished ---------")

      deep_copy(@ret)

      # EOF
    end

    # --------------------------------------------------------------------------
    # --------------------------------- cmd-line handlers

    # Command line handler for changing basic configuration
    # @param [Hash] options  a list of parameters passed as args
    # (currently only "mountpoint" key is expected)
    # @return [Boolean] true on success
    def XpramChangeConfiguration(options)
      options = deep_copy(options)
      mountpoint = Ops.get_string(options, "mountpoint", "")
      if mountpoint != ""
        Xpram.mountpoint = mountpoint
        Xpram.modified = true
        return true
      end
      false
    end

    # Command line handler for enabling XpRAM
    # @param [Hash] options  a list of parameters passed as args
    # @return [Boolean] true on success
    def XpramEnableHandler(options)
      options = deep_copy(options)
      ret = XpramChangeConfiguration(options)
      if !Xpram.start
        Xpram.start = true
        ret = true
        Xpram.modified = true
      end
      ret
    end

    # Command line handler for disabling XpRAM
    # @param [Hash] options  a list of parameters passed as args
    # @return [Boolean] true on success
    def XpramDisableHandler(options)
      if Xpram.start
        Xpram.start = false
        Xpram.modified = true
        return true
      end
      false
    end
  end
end

Yast::XpramClient.new.main
