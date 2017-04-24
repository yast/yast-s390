# encoding: utf-8

# Copyright (c) [2012-2014] Novell, Inc.
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

# File:	include/controller/wizards.ycp
# Package:	Configuration of controller
# Summary:	Wizards definitions
# Authors:	Jiri Srain <jsrain@suse.cz>
#
module Yast
  module S390ZfcpWizardsInclude
    def initialize_s390_zfcp_wizards(include_target)
      Yast.import "UI"
      textdomain "s390"

      Yast.import "Sequencer"
      Yast.import "Wizard"

      Yast.include include_target, "s390/zfcp/dialogs.rb"
    end

    # Main dialog
    # @return [Symbol] dialog
    def MainZFCPSequence
      aliases = {
        "main"   => -> { ZFCPDialog() },
        "add"    => -> { AddZFCPDiskDialog() },
        "delete" => -> { DeleteZFCPDiskDialog() }
      }

      sequence = {
        "ws_start" => "main",
        "main"     => {
          abort:  :abort,
          next:   :next,
          add:    "add",
          delete: "delete"
        },
        "add"      => { abort: :abort, next: "main" },
        "delete"   => { abort: :abort, next: "main" }
      }

      Sequencer.Run(aliases, sequence)
    end

    # Whole configuration of controller
    # @return sequence result
    def ZFCPSequence
      aliases = {
        "read"  => [-> { ReadDialog() }, true],
        "main"  => -> { MainZFCPSequence() },
        "write" => [-> { WriteDialog() }, true]
      }

      sequence = {
        "ws_start" => "read",
        "read"     => { abort: :abort, next: "main" },
        "main"     => { abort: :abort, next: "write" },
        "write"    => { abort: :abort, next: :next }
      }

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("zfcp")

      ret = Sequencer.Run(aliases, sequence)

      Wizard.CloseDialog

      ret
    end

    # Whole configuration of controller but without reading and writing.
    # For use with autoinstallation.
    # @return sequence result
    def ZFCPAutoSequence
      # Initialization dialog caption
      caption = _("Controller Configuration")
      # Initialization dialog contents
      contents = Label(_("Initializing..."))

      Wizard.CreateDialog
      Wizard.SetDesktopIcon("zfcp")
      Wizard.SetContentsButtons(
        caption,
        contents,
        "",
        Label.BackButton,
        Label.NextButton
      )

      ret = MainZFCPSequence()

      Wizard.CloseDialog

      ret
    end
  end
end
