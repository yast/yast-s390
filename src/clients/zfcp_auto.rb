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

# File:  clients/controller_auto.ycp
# Package:  Configuration of controller
# Summary:  Client for autoinstallation
# Authors:  Jiri Srain <jsrain@suse.cz>
#
# This is a client for autoinstallation. It takes its arguments,
# goes through the configuration and return the setting.
# Does not do any changes to the configuration.
module Yast
  class ZfcpAutoClient < Client
    def main
      Yast.import "UI"
      textdomain "s390"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("ZFCP auto started")

      Yast.import "ZFCPController"
      Yast.import "HTML"
      Yast.include self, "s390/zfcp/wizards.rb"

      @ret = nil
      @func = ""
      @param = {}

      # Check arguments
      if Ops.greater_than(Builtins.size(WFM.Args), 0) &&
          Ops.is_string?(WFM.Args(0))
        @func = Convert.to_string(WFM.Args(0))
        if Ops.greater_than(Builtins.size(WFM.Args), 1) &&
            Ops.is_map?(WFM.Args(1))
          @param = Convert.to_map(WFM.Args(1))
        end
      end

      Builtins.y2debug("func=%1", @func)
      Builtins.y2debug("param=%1", @param)

      case @func
      when "Summary"
        @ret = HTML.List(ZFCPController.Summary)
      when "Reset"
        ZFCPController.Import({})
        ZFCPController.SetModified(true)
        @ret = {}
      when "Change"
        @ret = ZFCPAutoSequence()
        ZFCPController.SetModified(true)
      when "Import"
        @ret = ZFCPController.Import(@param)
        ZFCPController.SetModified(true)
      when "Export"
        @ret = ZFCPController.Export
        ZFCPController.SetModified(false)
      when "GetModified"
        @ret = ZFCPController.GetModified
      when "SetModified"
        ZFCPController.SetModified(true)
        @ret = true
      when "Packages"
        @ret = ZFCPController.AutoPackages
      when "Read"
        Yast.import "Progress"
        Progress.set(false)
        @ret = ZFCPController.Read
        Progress.set(true)
        ZFCPController.SetModified(true)
      when "Write"
        Yast.import "Progress"
        Progress.set(false)
        @ret = ZFCPController.Write
        Progress.set(true)
      else
        Builtins.y2error("Unknown function: %1", @func)
        @ret = false # Unknown function
      end

      Builtins.y2debug("ret=%1", @ret)
      Builtins.y2milestone("ZFCP auto finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end
  end
end

Yast::ZfcpAutoClient.new.main
