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

# File:	clients/dump.ycp
# Package:	Creation of s390 dump devices
# Summary:	Main file
# Authors:	Tim Hardeck <thardeck@suse.de>
#
# Main file for s390 dump devices creation. Uses all other files.
module Yast
  class DumpClient < Client
    def main
      Yast.import "UI"

      #**
      # <h3>Creation of s390 dump devices</h3>

      textdomain "s390"

      # The main ()
      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("Dump module started")

      Yast.import "CommandLine"
      Yast.include self, "s390/dump/ui.rb"

      @cmdline_description = {
        "id"         => "dumpdevices",
        # Command line help text for the Xcontroller module
        "help"       => _(
          "Creation of S/390 dump devices"
        ),
        "guihandler" => fun_ref(method(:DumpSequence), "symbol ()"),
        "actions" =>
          # FIXME TODO: fill the functionality description here
          {},
        "options" =>
          # FIXME TODO: fill the option descriptions here
          {},
        "mapping" =>
          # FIXME TODO: fill the mappings of actions and options here
          {}
      }


      # main ui function
      @ret = CommandLine.Run(@cmdline_description)

      #ret = DumpSequence ();
      Builtins.y2debug("ret=%1", @ret)

      # Finish
      Builtins.y2milestone("Dump module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret) 

      # EOF
    end
  end
end

Yast::DumpClient.new.main
