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
# Main file for controller configuration. Uses all other files.
module Yast
  class DasdClient < Client
    include Yast::Logger

    def main
      Yast.import "UI"
      textdomain "s390"

      log.info "----------------------------------------"
      log.info "DASD module started"

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"

      Yast.import "CommandLine"
      Yast.include self, "s390/dasd/wizards.rb"

      @cmdline_description = {
        "id"         => "DASD",
        # Command line help text for the Xcontroller module
        "help"       => _("Configuration of DASD"),
        "guihandler" => fun_ref(method(:DASDSequence), "symbol ()"),
      }

      @ret = CommandLine.Run(@cmdline_description)
      log.debug "ret=#{@ret}"

      log.info "DASD module finished"
      log.info "----------------------------------------"

      deep_copy(@ret)
    end
  end
end

Yast::DasdClient.new.main
