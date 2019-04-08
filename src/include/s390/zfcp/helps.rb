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

# File:	include/controller/helps.ycp
# Package:	Configuration of controller
# Summary:	Help texts of all the dialogs
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
module Yast
  module S390ZfcpHelpsInclude
    def initialize_s390_zfcp_helps(_include_target)
      textdomain "s390"

      # All helps are here
      @ZFCP_HELPS = {
        # Read dialog help 1/2
        "read"           => _(
          "<p><b><big>Initializing ZFCP Device Configuration</big></b><br>\n</p>\n"
        ) +
          # Read dialog help 2/2
          _(
            "<p><b><big>Aborting Initialization:</big></b><br>\nSafely abort " \
              "the configuration utility by pressing <b>Abort</b> now.</p>"
          ),
        # Write dialog help 1/2
        "write"          => _(
          "<p><b><big>Saving ZFCP Device Configuration</big></b><br>\n</p>\n"
        ) +
          # Write dialog help 2/2
          _(
            "<p><b><big>Aborting Saving:</big></b><br>\n" \
              "Abort the save procedure by pressing <b>Abort</b>.\n" \
              "An additional dialog will inform you whether it is safe to do so.</p>\n"
          ),
        # Disk selection dialog help 1/3
        "disk_selection" => _(
          "<p><b><big>Configured ZFCP Devices</big></b><br>\nManage ZFCP devices on your system.</p>\n"
        ) +
          # Disk selection dialog help 2/3
          _("<p>To configure a new ZFCP device, click <b>Add</b>.</p>") +
          # Disk selection dialog help 3/3
          _(
            "<p>To remove a configured ZFCP device, select it and click\n<b>Delete</b>.</p>"
          ) +
          # Disk selection dialog Warning
          _("<h1>Warning</h1>") +
          _(
            "<p>When accessing a ZFCP device\n" \
              "<b>READ</b>/<b>WRITE</b>, make sure that this access is exclusive.\n" \
              "Otherwise there is a potential risk of data corruption.</p>"
          ),
        # Disk add help 1/2
        "disk_add"       => _(
          "<p><b><big>Add New ZFCP Device</big></b><br>\n" \
            "Enter the identifier of the device to add, the\n" \
            "<b>Channel ID</b> of the ZFCP controller, the worldwide port number\n" \
            "(<b>WWPN</b>) and the <b>LUN</b> number.</p>\n"
        ) +
          # Disk add help 2/2, This is HTML, so finally "&lt;devno&gt;" is displayed as "<devno>"
          _(
            "<p>The <b>Channel ID</b> must be entered with lowercase letters in a sysfs conforming\n" \
              "format 0.0.&lt;devno&gt;, such as <tt>0.0.5c51</tt>.</p>\n" \
              "<p>The WWPN must be entered with lowercase letters as a 16-digit hex value, such as\n" \
              "<tt>0x5005076300c40e5a</tt>.</p>\n" \
              "<p>The LUN must be entered with lowercase letters as a 16-digit hex value with\n" \
              "all trailing zeros, such as <tt>0x52ca000000000000</tt>.</p>" \
              "<p>If no WWPN <b>and</b> no LUN have been defined the system is " \
              "trying to use auto LUN scan. Auto LUN scan can be turned off using " \
              "the kernel parameter <tt>allow_lun_scan=0</tt>.</p>"
          ) +
          # Disk selection dialog Warning
          _("<h1>Warning</h1>") +
          _(
            "<p>When accessing a ZFCP device\n" \
              "<b>READ</b>/<b>WRITE</b>, make sure that this access is exclusive.\n" \
              "Otherwise there is a potential risk of data corruption.</p>"
          )
      }
    end
  end
end
