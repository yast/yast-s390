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

# File:	include/s390/dump/ui.ycp
# Package:	Creation of s390 dump devices
# Summary:	Dialogs definitions
# Authors:	Tim Hardeck <thardeck@suse.de>
#
module Yast
  module S390DumpUiInclude
    def initialize_s390_dump_ui(_include_target)
      Yast.import "UI"

      textdomain "s390"

      Yast.import "Dump"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"

      # Defines the default active device selection (`dasd, `zfcp)
      @type = :zfcp
    end

    # Run the dialog for Dump
    # @param what symbol a
    # @return [Symbol] EditDumpDialog that was edited
    def DumpDialog
      caption = _("Create Dump Device")
      help =
        # Dump dialog help 1/8
        _(
          "<p><b>Prepare one or more volumes for use as S/390 dump device.</b></p>"
        ) +
        # Dump dialog help 2/8
        _(
          "<p>Supported devices are ECKD DASD and ZFCP disks, while multi-volumes are limited to DASD.<br>"
        ) +
        # Dump dialog help 3/8
        _(
          "Only whole disks can be used, no partitions. If the device is incompatibly\n" \
            "formatted or partitioned, activate the checkbox <b>Force overwrite of disk</b>.</p>"
        ) +
        # Dump dialog help 4/8
        _(
          "<p>To use DASD and ZFCP devices activate them in the respective YaST DASD or ZFCP dialog.<br>"
        ) +
        # Dump dialog help 5/8
        _(
          "Devices which are in use or have mounted partitions will not be shown.</p>"
        ) +
        # Dump dialog help 6/8
        _(
          "<p><b>dumpdevice</b> after a disk indicates that it is a usable dump\ndevice. " \
            "Multi-volume dump devices are indicated by a list of DASD IDs.</p>"
        ) +
        # Dump dialog help 7/8
        _("<p>ZFCP columns: Device, Size, ID, WWPN, LUN, Dump<br>") +
        # Dump dialog help 8/8
        _("DASD columns: Device, Size, ID, Dump</p>")

      dasd_disks = deep_copy(Dump.dasd_disks)
      zfcp_disks = deep_copy(Dump.zfcp_disks)

      # Dialog content
      content = HBox(
        VBox(
          RadioButtonGroup(
            Id(:disk),
            VBox(
              Frame(
                "",
                VBox(
                  Left(
                    RadioButton(
                      Id(:zfcp),
                      Opt(:notify),
                      _("&ZFCP"),
                      @type == :zfcp
                    )
                  ),
                  ComboBox(Id(:zfcp_disks), Opt(:hstretch), "", zfcp_disks)
                )
              ),
              VSpacing(0.3),
              Frame(
                "",
                VBox(
                  Left(
                    RadioButton(
                      Id(:dasd),
                      Opt(:notify),
                      _("&DASD"),
                      @type == :dasd
                    )
                  ),
                  MultiSelectionBox(Id(:dasd_disks), "", dasd_disks)
                )
              )
            )
          ),
          VSpacing(0.3),
          Left(
            CheckBox(Id(:force), Opt(:notify), _("&Force overwrite of disk"))
          )
        )
      )

      # Apply the settings
      Wizard.SetContentsButtons(
        caption,
        content,
        help,
        Label.BackButton,
        Label.CreateButton
      )
      Wizard.HideBackButton
      Wizard.SetAbortButton(:cancel, Label.CancelButton)

      UI.ChangeWidget(Id(:dasd_disks), :Enabled, @type == :dasd)
      UI.ChangeWidget(Id(:zfcp_disks), :Enabled, @type == :zfcp)

      force = false
      ret = nil
      loop do
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :force
          force = Convert.to_boolean(UI.QueryWidget(Id(:force), :Value))
        end

        # disable inactive area
        if ret == :dasd || ret == :zfcp
          UI.ChangeWidget(Id(:dasd_disks), :Enabled, ret == :dasd)
          UI.ChangeWidget(Id(:zfcp_disks), :Enabled, ret == :zfcp)
        end

        if Builtins.contains([:create, :ok, :next, :finish], ret)
          device = ""
          @type = Convert.to_symbol(UI.QueryWidget(Id(:disk), :CurrentButton))

          # gather selected device[s]
          entries = []
          if @type == :zfcp
            dev_line = Convert.to_string(
              UI.QueryWidget(Id(:zfcp_disks), :Value)
            )
            entries = Builtins.splitstring(dev_line, "\t")
            device = Ops.get(entries, 0, "") # dasd
          else
            selected_items = Convert.convert(
              UI.QueryWidget(Id(:dasd_disks), :SelectedItems),
              from: "any",
              to:   "list <string>"
            )
            Builtins.foreach(selected_items) do |device_line|
              entries = Builtins.splitstring(device_line, "\t")
              # prevent leading space
              device = if device != ""
                Ops.add(Ops.add(device, " "), Ops.get(entries, 0, ""))
              else
                Ops.get(entries, 0, "")
              end
            end
          end

          if Builtins.size(device) == 0
            Popup.Notify(_("You haven't selected any device."))
          elsif !force ||
            # warn only in case of force
              Popup.YesNo(
                Builtins.sformat(
                  _(
                    "The disk %1 will be formatted as a dump device. All data on " \
                      "this device will be lost! Continue?"
                  ),
                  device
                )
              )

            success = Dump.FormatDisk(device, force)
            # don't quit in case of failures, error messages are reported by FormatDisk()
            ret = if success &&
                !Popup.YesNo(
                  _("Operation successful. Initialize another dump device?")
                )
              :cancel
            else
              # reinitialize devices
              :again
            end

            # reset screen after dump progress bar
            Wizard.SetContentsButtons(
              caption,
              VBox(),
              help,
              Label.BackButton,
              Label.CreateButton
            )
          end
        end

        break if Builtins.contains([:abort, :cancel, :again], ret)
      end
      ret
    end

    # The whole squence
    # @return sequence result
    def DumpSequence
      # reset dialog if required
      Wizard.CreateDialog
      Wizard.SetDesktopIcon("dump")
      loop do
        Dump.Read
        break if DumpDialog() != :again
      end
      UI.CloseDialog

      ret
    end
  end
end
