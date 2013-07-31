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

# File:	clients/controller.ycp
# Package:	Configuration of controller
# Summary:	Main file
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# Main file for controller configuration. Uses all other files.
module Yast
  class ZfcpClient < Client
    def main
      Yast.import "UI"
      textdomain "s390"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("ZFCP module started")

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"

      Yast.import "CommandLine"
      Yast.include self, "s390/zfcp/wizards.rb"

      @cmdline_description = {
        "id"         => "ZFCP",
        # Command line help text for the Xcontroller module
        "help"       => _(
          "Configuration of ZFCP"
        ),
        "guihandler" => fun_ref(method(:ZFCPSequence), "symbol ()"),
        "initialize" => fun_ref(ZFCPController.method(:Read), "boolean ()"),
        "finish"     => fun_ref(ZFCPController.method(:Write), "boolean ()"),
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

      @ret = CommandLine.Run(@cmdline_description)
      Builtins.y2debug("ret=%1", @ret)

      Builtins.y2milestone("ZFCP module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end
  end
end

Yast::ZfcpClient.new.main
