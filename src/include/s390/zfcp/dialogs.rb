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

# File:	include/controller/dialogs.ycp
# Package:	Configuration of controller
# Summary:	Dialogs definitions
# Authors:	Jiri Srain <jsrain@suse.cz>
#
# $Id$
module Yast
  module S390ZfcpDialogsInclude
    def initialize_s390_zfcp_dialogs(include_target)
      Yast.import "UI"
      textdomain "s390"

      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Sequencer"
      Yast.import "Wizard"
      Yast.import "ZFCPController"

      Yast.include include_target, "s390/zfcp/helps.rb"
    end

    # List ZFCP devices that are currently being selected
    # @return [Array<Fixnum>] list of IDs of selected ZFCP devices
    def ListSelectedZFCP
      selected = Convert.convert(
        UI.QueryWidget(Id(:table), :SelectedItems),
        :from => "any",
        :to   => "list <integer>"
      )
      Builtins.y2milestone("selected %1", selected)
      deep_copy(selected)
    end


    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@ZFCP_HELPS, "read", ""))
      ret = ZFCPController.Read
      ret ? :next : :abort
    end


    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      Wizard.RestoreHelp(Ops.get_string(@ZFCP_HELPS, "write", ""))
      ret = ZFCPController.Write
      ret ? :next : :abort
    end


    # Get the list of items for the table of ZFCP devices
    # @param min_chan integer minimal channel number
    # @param max_chan integer maximal channel number
    # @return a list of terms for the table
    def GetZFCPDiskItems
      devices = ZFCPController.GetFilteredDevices

      items = []

      if Mode.config
        items = Builtins.maplist(devices) do |k, d|
          channel = Ops.get_string(d, ["detail", "controller_id"], "")
          wwpn = Ops.get_string(d, ["detail", "wwpn"], "")
          lun = Ops.get_string(d, ["detail", "fcp_lun"], "")
          Item(Id(k), channel, wwpn, lun)
        end
      else
        items = Builtins.maplist(devices) do |k, d|
          channel = Ops.get_string(d, ["detail", "controller_id"], "")
          wwpn = Ops.get_string(d, ["detail", "wwpn"], "")
          lun = Ops.get_string(d, ["detail", "fcp_lun"], "")
          dev_name = Ops.get_string(d, "dev_name", "")
          Item(Id(k), channel, wwpn, lun, dev_name)
        end
      end

      deep_copy(items)
    end


    # Show the ZFCP-Dialog
    def DisplayZFCPDialog
      # Minimal text for the help
      help = Ops.get_string(@ZFCP_HELPS, "disk_selection", "")

      # Dialog caption
      caption = _("Configured ZFCP Devices")

      header = Empty()

      if Mode.config
        header = Header(
          # table header
          Right(_("Channel ID")),
          # table header
          Right(_("WWPN")),
          # table header
          Right(_("LUN"))
        )
      else
        header = Header(
          # table header
          Right(_("Channel ID")),
          # table header
          Right(_("WWPN")),
          # table header
          Right(_("LUN")),
          # table header
          _("Device")
        )
      end

      # Dialog content
      content = VBox(
        HBox(
          # text entry
          InputField(
            Id(:min_chan),
            Opt(:hstretch),
            _("Mi&nimum Channel ID"),
            ZFCPController.filter_min
          ),
          # text entry
          InputField(
            Id(:max_chan),
            Opt(:hstretch),
            _("Ma&ximum Channel ID"),
            ZFCPController.filter_max
          ),
          VBox(
            Label(""),
            # push button
            PushButton(Id(:filter), _("&Filter"))
          )
        ),
        Table(Id(:table), Opt(:multiSelection), header, []),
        HBox(
          PushButton(Id(:add), Label.AddButton),
          HStretch()
        )
      )

      Wizard.SetContentsButtons(
        caption,
        content,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.HideBackButton
      Wizard.HideNextButton
      Wizard.SetAbortButton(:abort, Label.CancelButton)

      UI.ChangeWidget(Id(:min_chan), :ValidChars, "0123456789abcdefABCDEF.")
      UI.ChangeWidget(Id(:max_chan), :ValidChars, "0123456789abcdefABCDEF.")

      nil
    end


    # Restart the ZFCP-Dialog
    def ReloadZFCPDialog
      items = GetZFCPDiskItems()

      selected = Convert.convert(
        UI.QueryWidget(Id(:table), :SelectedItems),
        :from => "any",
        :to   => "list <integer>"
      )
      UI.ChangeWidget(Id(:table), :Items, items)
      UI.ChangeWidget(Id(:table), :SelectedItems, selected)
      UI.SetFocus(:table)

      nil
    end


    # Show the ZFCP-Dialog
    # @return [Symbol] From the dialog
    def ZFCPDialog
      DisplayZFCPDialog()
      ReloadZFCPDialog()

      ret = nil
      while ret == nil
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :filter
          filter_min = Convert.to_string(UI.QueryWidget(:min_chan, :Value))
          filter_max = Convert.to_string(UI.QueryWidget(:max_chan, :Value))

          if !ZFCPController.IsValidChannel(filter_min) ||
              !ZFCPController.IsValidChannel(filter_max)
            # error popup
            Popup.Error(_("Invalid filter channel IDs."))
            ret = nil
            next
          end

          ZFCPController.filter_min = ZFCPController.FormatChannel(filter_min)
          ZFCPController.filter_max = ZFCPController.FormatChannel(filter_max)

          ReloadZFCPDialog()
          ret = nil
          next
        elsif ret == :table
          ret = nil
          next
        end
      end

      ret
    end


    # Add ZFCP-Dialog
    # @return [Symbol] the dialog
    def AddZFCPDiskDialog
      # Minimal text for the help
      help = Ops.get_string(@ZFCP_HELPS, "disk_add", "")

      # dialog caption
      caption = _("Add New ZFCP Device")

      channels = []
      if Mode.config
        channels = Builtins.maplist(ZFCPController.devices) do |index, d|
          Ops.get_string(d, ["detail", "controller_id"], "")
        end
        channels = Builtins.toset(channels)
      else
        channels = Builtins.maplist(ZFCPController.GetControllers) do |c|
          Ops.get_string(c, "sysfs_bus_id", "")
        end
      end

      content = HBox(
        HStretch(),
        VBox(
          VStretch(),
          # combo box
          ComboBox(
            Id(:channel),
            Opt(:editable, :hstretch),
            _("&Channel ID"),
            channels
          ),
          VStretch()
        ),
        HStretch()
      )

      # Apply the settings
      Wizard.SetContents(caption, content, help, true, true)
      Wizard.RestoreBackButton
      Wizard.RestoreAbortButton
      Wizard.RestoreNextButton
      Wizard.SetNextButton(:next, Label.OKButton)

      UI.ChangeWidget(Id(:channel), :ValidChars, "0123456789abcdefABCDEF.")
      UI.SetFocus(Id(:channel))

      ret = nil
      while ret == nil
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :abort || ret == :cancel
          # yes-no popup
          if !Popup.YesNo(
              _(
                "Really leave the ZFCP device configuration without saving?\nAll changes will be lost."
              )
            )
            ret = nil
          end
        elsif ret == :next
          channel = Convert.to_string(UI.QueryWidget(Id(:channel), :Value))

          if !ZFCPController.IsValidChannel(channel)
            # error popup
            Popup.Error(_("Not a valid channel ID."))
            UI.SetFocus(:channel)
            ret = nil
            next
          end

          channel = ZFCPController.FormatChannel(channel)
          if ZFCPController.GetDeviceIndex(channel) != nil
            # error popup
            Popup.Error(_("Device already exists."))
            ret = nil
            next
          end
        end
      end

      if ret == :next
        channel = Convert.to_string(UI.QueryWidget(Id(:channel), :Value))
        channel = ZFCPController.FormatChannel(channel)

        Ops.set(ZFCPController.previous_settings, "channel", channel)

        if Mode.config
          m = { "controller_id" => channel}

          m = { "detail" => m }

          ZFCPController.AddDevice(m)
        else
          ZFCPController.ActivateDisk(channel)
          WriteDialog()
          ZFCPController.ProbeDisks
        end
      end

      ret
    end

  end
end
