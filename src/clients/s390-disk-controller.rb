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

# File:  clients/controller.ycp
# Package:  Configuration of controller
# Summary:  Main file
# Authors:  Jiri Srain <jsrain@suse.cz>
#
# $Id$
#
# Main file for controller configuration. Uses all other files.
module Yast
  class S390DiskControllerClient < Client
    def main
      Yast.import "UI"
      textdomain "s390"

      Builtins.y2milestone("----------------------------------------")
      Builtins.y2milestone("S/390 Controller module started")

      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Summary"
      Yast.import "Wizard"
      Yast.import "Label"

      Yast.import "DASDController"
      Yast.import "ZFCPController"

      # popup label
      UI.OpenDialog(Label(_("Detecting Available Controllers")))

      @have_dasd = DASDController.IsAvailable
      @have_zfcp = ZFCPController.IsAvailable

      Builtins.y2milestone(
        "Have DASD: %1, have zFCP: %2",
        @have_dasd,
        @have_zfcp
      )

      UI.CloseDialog

      if @have_dasd && !@have_zfcp
        Builtins.y2milestone("Having DASD-only system")
        return WFM.call("dasd")
      elsif @have_zfcp && !@have_dasd
        Builtins.y2milestone("Having zFCP-only system")
        return WFM.call("zfcp")
      end

      # Initialization dialog caption
      @caption = _("S/390 Disk Controller Configuration")
      # Initialization dialog contents
      @contents = HBox(
        HWeight(999, HStretch()),
        VBox(
          VStretch(),
          HWeight(
            1,
            PushButton(
              Id(:dasd),
              Opt(:hstretch),
              # push button
              _("Configure &DASD Disks")
            )
          ),
          VSpacing(2),
          HWeight(
            1,
            PushButton(
              Id(:zfcp),
              Opt(:hstretch),
              # push button
              _("Configure &ZFCP Disks")
            )
          ),
          VStretch()
        ),
        HWeight(999, HStretch())
      )

      Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("org.opensuse.yast.Disk")
      Wizard.SetContentsButtons(
        @caption,
        @contents,
        "",
        Label.BackButton,
        Label.FinishButton
      )

      Wizard.HideBackButton

      @ret = nil
      while @ret.nil?
        @ret = UI.UserInput
        if @ret == :dasd
          WFM.call("dasd")
          @ret = nil
        elsif @ret == :zfcp
          WFM.call("zfcp")
          @ret = nil
        end
      end

      UI.CloseDialog

      Builtins.y2debug("ret=%1", @ret)

      Builtins.y2milestone("S/390 controller module finished")
      Builtins.y2milestone("----------------------------------------")

      deep_copy(@ret)
    end
  end
end

Yast::S390DiskControllerClient.new.main
