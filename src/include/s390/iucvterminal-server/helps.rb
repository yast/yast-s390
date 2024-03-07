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

# File:  include/s390/iucvterminal-server/helps.ycp
# Package:  Configuration IUCV Terminal Server
# Summary:  Help texts of all the dialogs
# Authors:  Tim Hardeck <thardeck@suse.de>
#
module Yast
  module S390IucvterminalServerHelpsInclude
    def initialize_s390_iucvterminal_server_helps(_include_target)
      textdomain "s390"

      # All helps are here
      # zmvids ts_group ts_user ts ic
      @HELP = {
        # z/VM IDs dialog help 1/1
        "zvmids"   => _(
          "<p><b><big>z/VM IDs</big></b></p>"
        ) +
          _(
            "<p>To configure the IUCV terminal server, specify the z/VM IDs to be used.\n<br>" \
            "They are separated by line breaks.</p>\n"
          ),
        # TS-Shell dialog help 1/5
        "ts"       => _(
          "<p><b><big>TS-Shell</big></b></p>"
        ) +
          _(
            "<p>TS-Shell allows to specify <b>Authorization</b> for every TS-Shell user and group. " \
            "The rights of a group are inherited by its members.</p>"
          ) +
          # TS-Shell dialog help 2/5
          _(
            "<p>Each allowed z/VM ID can be selected manually under <b>Selection</b>, defined by " \
            "a <b>Regex</b> or loaded from a <b>File</b> which contains all allowed z/VM IDs " \
            "separated by line breaks.</p>"
          ) +
          # TS-Shell dialog help 3/5
          _(
            "<p>Click on <b>New User</b> to create new TS-Shell users or <b>Delete\nUser</b> " \
            "to remove users.</p>"
          ) +
          # TS-Shell dialog help 4/5
          _(
            "<p>To add or remove groups from the TS-Shell authorization table or to change\n" \
            "the membership of users, go to <b>Manage Groups</b>.</p>"
          ) +
          # TS-Shell dialog help 5/5
          _(
            "<p>With <b>Audited IDs</b> specify the z/VM IDs from which transcripts should be gathered.</p>"
          ),
        # TS-Shell User creation dialog help 1/3
        "ts-user"  => _(
          "<p><b><big>New TS-Shell User</big></b></p>"
        ) +
          _(
            "<p>To create new TS-Shell user the <b>Username</b>, <b>Home Directory</b> and " \
            "<b>Password</b> has to be provided.\n\t<br>It is also possible to specify " \
            "<b>Additional Groups</b> by selecting them on the right.</p>"
          ) +
          # TS-Shell User creation dialog help 2/3
          _(
            "<p>To ensure that the user changes his password after the first login, activate " \
            "<b>Force Password Change</b>.</p>"
          ) +
          # TS-Shell User creation dialog help 3/3
          _(
            "<p>You can specify the same home directory for every TS-Shell user since no\n" \
            "data will be stored there.</p>"
          ),
        # TS-Shell Managing Groups dialog help 1/5
        "ts-group" => _(
          "<p><b><big>Manage Groups for TS-Authorization</big></b></p>"
        ) +
          _(
            "<p>Define TS-Shell authorizations per group if you want every TS-Shell \n" \
            "member of this groups to inherit the same rights.</p>"
          ) +
          # TS-Shell Managing Groups dialog help 2/5
          _(
            "<p>Existing groups can be added to or removed from the TS-Shell\n" \
            "authorization. Select the groups in the table and click on <b>Select or Deselect</b>. " \
            "The current status is shown in the column <b>TS-Auth</b>.</p>"
          ) +
          # TS-Shell Managing Groups dialog help 3/5
          _(
            "<p>Change TS-Shell members of a selected group in the <b>TS-Members</b>\nselection.</p>"
          ) +
          # TS-Shell Managing Groups dialog help 4/5
          _(
            "<p>New groups could be created by entering the name in the <b>New Group</b> input field " \
            "and confirming with <b>Create</b>.\n\t<br>To delete previously created groups the " \
            "<b>YaST users</b> dialog has to be used.</p>"
          ) +
          # TS-Shell Managing Groups dialog help 5/5
          _(
            "<p>Undo changes in this dialog by clicking the <b>Back</b> button.</p>"
          ),
        # IUCVConn on Login dialog help 1/2
        "ic"       => _(
          "<p><b><big>IUCVConn on Login</big></b></p>"
        ) +
          _(
            "<p>IUCVConn on Login needs one user for every z/VM ID. To create these users " \
            "a <b>password</b> and <b>home directory</b> has to be provided."
          ) +
          # IUCVConn on Login dialog help 2/2
          _(
            "<p>It is possible to sync the users manually by clicking on <b>Sync</b> or just " \
            "confirming the changes with <b>Ok</b> while <b>IUCVConn on Login</b> is enabled. </p>"
          )
      }
      # EOF
    end
  end
end
