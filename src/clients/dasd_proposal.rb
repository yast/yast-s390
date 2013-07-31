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

# File:	clients/dasd_proposal.ycp
# Package:	S/390 specific configuration
# Summary:	Proposal function dispatcher
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# Proposal function dispatcher for dasd configuration.
module Yast
  class DasdProposalClient < Client
    def main
      textdomain "s390"

      Yast.import "DASDController"
      Yast.import "Wizard"
      Yast.import "Storage"

      @func = Convert.to_string(WFM.Args(0))
      @param = Convert.to_map(WFM.Args(1))
      @ret = {}

      # Make proposal for installation/configuration...
      if @func == "MakeProposal"
        @summary = DASDController.Summary
        if Builtins.isempty(@summary)
          # text for installation summary
          @summary = [_("No DASD disk detected")]
        end
        # Fill return map
        @ret = {
          "raw_proposal"  => @summary,
          "warning"       => nil,
          "warning_level" => nil
        }
      # Run an interactive workflow
      elsif @func == "AskUser"
        Wizard.CreateDialog
        Storage.ActivateHld(false)
        @sequence = WFM.CallFunction("inst_dasd", [])
        Storage.ReReadTargetMap
        Wizard.CloseDialog

        # Fill return map
        @ret = { "workflow_sequence" => @sequence }
      # Return human readable titles for the proposal
      elsif @func == "Description"
        return nil if !DASDController.IsAvailable
        # Fill return map
        @ret =
          # section name in proposal dialog
          {
            "rich_text_title" => _("DASD"),
            # section name in proposal - menu item
            "menu_title"      => _(
              "&DASD"
            ),
            "id"              => "dasd"
          }
      elsif @func == "Write"
        DASDController.Write
      end

      deep_copy(@ret)
    end
  end
end

Yast::DasdProposalClient.new.main
