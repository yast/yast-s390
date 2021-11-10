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

# File:	include/controller/helps.ycp
# Package:	Configuration of controller
# Summary:	Help texts of all the dialogs
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
module Yast
  module S390DasdHelpsInclude
    def initialize_s390_dasd_helps(_include_target)
      textdomain "s390"

      # All helps are here
      @DASD_HELPS = {
        # Read dialog help 1/2
        "read"                  => _(
          "<p><b><big>Initializing Controller Configuration</big></b><br>\n</p>\n"
        ) +
          # Read dialog help 2/2
          _(
            "<p><b><big>Aborting Initialization:</big></b><br>\nSafely abort the " \
              "configuration utility by pressing <b>Abort</b> now.</p>"
          ),
        # Write dialog help 1/2
        "write"                 => _(
          "<p><b><big>Saving Controller Configuration</big></b><br>\n</p>\n"
        ) +
          # Write dialog help 2/2
          _(
            "<p><b><big>Aborting Saving:</big></b><br>\n" \
              "Abort the save procedure by pressing <b>Abort</b>.\n" \
              "An additional dialog will inform you whether it is safe to do so.</p>\n"
          ),
        # Disk selection dialog help 1/4
        "disk_selection_config" => _(
          "<p><b><big>Configured DASD Disks</big></b><br>\nIn this dialog, manage DASD " \
            "disks on your system.</p>"
        ) +
          # Disk selection dialog help 2/4
          _(
            "<p>To filter the displayed disks, set the <b>Minimum Channel ID</b> and \n" \
              "the <b>Maximum Channel ID</b> and click <b>Filter</b>.</p>\n"
          ) +
          # Disk selection dialog help 4/4
          _("<p>To configure a new DASD disk, click <b>Add</b>.</p>") +
          # Disk selection dialog help 4/4
          _(
            "<p>To remove a configured DASD disk, select it and click\n<b>Delete</b>.</p>"
          ),
        # Disk selection dialog help 1/4
        "disk_selection"        => _(
          "<p><b><big>Configured DASD Disks</big></b><br>\nIn this dialog, manage DASD disks " \
            "on your system.</p>"
        ) +
          # Disk selection dialog help 2/4
          _(
            "<p>To filter the displayed disks, set the <b>Minimum Channel ID</b> and \n" \
              "the <b>Maximum Channel ID</b> and click <b>Filter</b>.</p>\n"
          ) +
          # Disk selection dialog help 3/4
          _(
            "<p>To perform actions on multiple disks at once, mark these disks. To select " \
              "all displayed disk (possibly after applying a filter), click\n<b>Select All</b> " \
              "or <b>Deselect All</b>.</p>\n"
          ) +
          # Disk selection dialog help 4/4
          _(
            "<p>To perform an action on the selected disks, use <b>Perform Action</b>.\n" \
              "The action will be performed immediately!</p>"
          ),
        # Disk add help 1/3
        "disk_add_config"       => _(
          "<p><b><big>Add New DASD Disk</big></b><br>\n" \
            "To add a disk, enter the <b>Channel ID</b> of the DASD disk as\n" \
            "identifier.</p>"
        ) +
          # Disk add help 1/3
          _(
            "<p>If the disk should be formatted,\nuse <b>Format the Disk</b>.</p>\n"
          ) +
          # Disk add help 3/3
          _("<p>To use DIAG mode, select <b>Use DIAG</b>.</p>\n")
      }
    end
  end
end
