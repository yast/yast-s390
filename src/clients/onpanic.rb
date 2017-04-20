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

# File:	clients/onpanic.ycp
# Package:	Configuration of onpanic
# Summary:	Main file
# Authors:	Tim Hardeck <thardeck@suse.de>
#
# Main file for onpanic configuration. Uses all other files.
module Yast
  class OnpanicClient < Client
    include Yast::Logger

    def main
      Yast.import "UI"

      #**
      # <h3>Configuration of onpanic</h3>

      textdomain "s390"

      # The main ()
      log.info "----------------------------------------"
      log.info "OnPanic module started"

      Yast.import "CommandLine"
      Yast.import "OnPanic"

      Yast.include self, "s390/onpanic/ui.rb"

      @cmdline_description = {
        "id"         => "onpanic",
        # Command line help text for the OnPanic module
        "help"       => _("Configuration of OnPanic"),
        "guihandler" => fun_ref(method(:OnPanicSequence), "symbol ()"),
      }

      # main ui function
      @ret = CommandLine.Run(@cmdline_description)

      log.debug "ret=#{@ret}"

      # Finish
      log.info "OnPanic module finished"
      log.info "----------------------------------------"

      deep_copy(@ret)

      # EOF
    end
  end
end

Yast::OnpanicClient.new.main
