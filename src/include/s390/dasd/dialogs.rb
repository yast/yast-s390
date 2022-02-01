# Copyright (c) [2012-2022] SUSE LLC
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
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "y2s390/dasd_actions"

module Yast
  module S390DasdDialogsInclude
    def initialize_s390_dasd_dialogs(include_target)
      textdomain "s390"

      Yast.import "UI"
      Yast.import "DASDController"
      Yast.import "Label"
      Yast.import "Mode"
      Yast.import "Popup"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Sequencer"
      Yast.import "Wizard"
      Yast.import "String"
      Yast.import "Integer"
      Yast.import "Event"
      Yast.import "ContextMenu"

      Yast.include include_target, "s390/dasd/helps.rb"
    end

    # Returns the ids of currently selected DASD devices
    #
    # @return [Array<Integer>] ids of selected DASD devices
    def ListSelectedDASD
      selected = UI.QueryWidget(Id(:table), :SelectedItems) || []
      log.info("selected #{selected}")
      deep_copy(selected)
    end

    # Read settings dialog
    # @return `abort if aborted and `next otherwise
    def ReadDialog
      Wizard.RestoreHelp(Ops.get_string(@DASD_HELPS, "read", ""))
      ret = DASDController.Read
      ret ? :next : :abort
    end

    # Write settings dialog
    # @return `abort if aborted and `next otherwise
    def WriteDialog
      Wizard.RestoreHelp(Ops.get_string(@DASD_HELPS, "write", ""))
      ret = DASDController.Write
      ret ? :next : :abort
    end

    # Returns needed information for displaying given DASD in the UI
    #
    # @see #GetDASDDiskItems
    #
    # @param dasd [YS390::DASD] a Direct Access Storage Device
    # @return [Array] a collection holding needed information, namely
    def item_elements_for(dasd)
      item_id = Id(dasd.id)
      diag = String.YesNo(Mode.config ? dasd.diag_wanted : dasd.use_diag)
      formatted = String.YesNo(dasd.formatted?)

      return [item_id, dasd.id, d.format, diag] if Mode.config
      return [item_id, dasd.id, "--", "--", "--", diag, "--", "--"] unless dasd.active?

      [
        item_id, dasd.id, dasd.device_path, dasd.device_type,
        dasd.access_type.to_s.upcase, diag, formatted, dasd.partition_info
      ]
    end

    # Returns a list of items for the table of DASD devices
    #
    # @see DASDController.GetFilteredDevices
    #
    # @return [Array<Item>]
    def GetDASDDiskItems
      devices = DASDController.GetFilteredDevices

      devices.map { |d| Item(*item_elements_for(d)) }
    end

    def PossibleActions
      if !Mode.config
        [
          # menu button id
          Item(Id(:activate), _("&Activate")),
          # menu button id
          Item(Id(:deactivate), _("&Deactivate")),
          # menu button id
          Item(Id(:diag_on), _("Set DIAG O&n")),
          # menu button id
          Item(Id(:diag_off), _("Set DIAG O&ff")),
          # menu button id
          Item(Id(:format), _("&Format"))
        ]
      else
        [
          # menu button id
          Item(Id(:diag_on), _("Set DIAG O&n")),
          # menu button id
          Item(Id(:diag_off), _("Set DIAG O&ff")),
          # menu button id
          Item(Id(:format_on), _("Set Format On")),
          # menu button id
          Item(Id(:format_off), _("Set Format Off"))
        ]
      end
    end

    # Returns the Y2S390::DasdAction class for given action
    #
    # @param action [Symbol, String]
    # @return [Y2S390::DasdAction]
    def action_class_for(action)
      name = action.to_s.split("_").map(&:capitalize).join
      "Y2S390::DasdActions::#{name}"
    end

    # Run given action over selected DASD devices
    #
    # @param action [Y2S390::DasdAction] the action to perform
    # @param selected [Y2S390::DasdsCollection] the collection of DASD devices to work with
    def run(action, selected)
      Object.const_get(action_class_for(action)).run(selected)
    end

    def PerformAction(action)
      selected = DASDController.devices.by_ids(ListSelectedDASD())

      if selected.empty?
        # error popup message
        Popup.Message(_("No disk selected."))
        return false
      end

      run(action, selected)
    end

    # Draw the DASD dialog
    def DisplayDASDDialog
      help_key = Mode.config ? "disk_selection_config" : "disk_selection"

      # Minimal text for the help
      help = @DASD_HELPS.fetch(help_key, "")

      # Dialog caption
      caption = _("DASD Disk Management")

      header = if Mode.config
        Header(
          # table header
          Right(_("Channel ID")),
          # table header
          _("Format"),
          # table header
          _("Use DIAG")
        )
      else
        Header(
          # table header
          Right(_("Channel ID")),
          # table header
          _("Device"),
          # table header
          _("Type"),
          # table header
          _("Access Type"),
          # table header
          _("Use DIAG"),
          # table header
          _("Formatted"),
          # table header
          _("Partition Information")
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
            DASDController.filter_min
          ),
          # text entry
          InputField(
            Id(:max_chan),
            Opt(:hstretch),
            _("Ma&ximum Channel ID"),
            DASDController.filter_max
          ),
          VBox(
            Label(""),
            # push button
            PushButton(Id(:filter), _("&Filter"))
          )
        ),
        Table(Id(:table), Opt(:multiSelection, :notifyContextMenu), header, []),
        if Mode.config
          HBox(
            PushButton(Id(:add), Label.AddButton),
            PushButton(Id(:delete), Label.DeleteButton),
            HStretch(),
            # menu button
            MenuButton(Id(:operation), _("Perform &Action"), PossibleActions())
          )
        else
          HBox(
            PushButton(Id(:select_all), _("&Select All")),
            PushButton(Id(:deselect_all), _("&Deselect All")),
            HStretch(),
            # menu button
            MenuButton(Id(:operation), _("Perform &Action"), PossibleActions())
          )
        end
      )

      # Apply the settings
      Wizard.SetContents(caption, content, help, true, true)
      Wizard.HideBackButton
      Wizard.SetAbortButton(:abort, Label.CancelButton)

      UI.ChangeWidget(Id(:min_chan), :ValidChars, "0123456789abcdefABCDEF.")
      UI.ChangeWidget(Id(:max_chan), :ValidChars, "0123456789abcdefABCDEF.")

      nil
    end

    # Redraw the contents of the widgets in the DASD Dialog
    def ReloadDASDDialog
      items = GetDASDDiskItems()

      selected = UI.QueryWidget(Id(:table), :SelectedItems) || []
      UI.ChangeWidget(Id(:table), :Items, items)
      UI.ChangeWidget(Id(:table), :SelectedItems, selected)
      UI.SetFocus(:table)

      nil
    end

    # Run the dialog for DASD disks configuration
    # @return [Symbol] for wizard sequencer
    def DASDDialog
      DisplayDASDDialog()
      ReloadDASDDialog()

      ret = nil
      while ret.nil?
        event = UI.WaitForEvent

        if Event.IsWidgetContextMenuActivated(event) == :table
          action = ContextMenu.Simple(PossibleActions())
          ReloadDASDDialog() if PerformAction(action)

          ret = nil
          next
        end

        ret = Ops.get_symbol(event, "ID")

        if ret == :select_all

          UI.ChangeWidget(Id(:table), :SelectedItems,
            UI.QueryWidget(Id(:table), :Items).map { |item| item[0][0] })
          ret = nil
        elsif ret == :deselect_all
          UI.ChangeWidget(Id(:table), :SelectedItems, [])
          ret = nil
        elsif ret == :filter
          filter_min = Convert.to_string(UI.QueryWidget(:min_chan, :Value))
          filter_max = Convert.to_string(UI.QueryWidget(:max_chan, :Value))

          if !DASDController.IsValidChannel(filter_min) ||
              !DASDController.IsValidChannel(filter_max)
            # error popup
            Popup.Error(_("Invalid filter channel IDs."))
            ret = nil
            next
          end

          DASDController.filter_min = DASDController.FormatChannel(filter_min)
          DASDController.filter_max = DASDController.FormatChannel(filter_max)

          ReloadDASDDialog()
          ret = nil
          next
        elsif ret == :table
          ret = nil
          next
        elsif Builtins.contains(
          [
            :activate,
            :deactivate,
            :diag_on,
            :diag_off,
            :format,
            :format_on,
            :format_off
          ],
          ret
        )
          ReloadDASDDialog() if PerformAction(ret)

          ret = nil
          next
        end
      end

      ret
    end

    # Run the dialog for adding DASDs
    # @return [Symbol] from AddDASDDiskDialog
    def AddDASDDiskDialog
      # Minimal text for the help
      help = Ops.get_string(@DASD_HELPS, "disk_add_config", "")

      # Dialog caption
      caption = _("Add New DASD Disk")

      # Dialog content
      content = HBox(
        HStretch(),
        VBox(
          VStretch(),
          TextEntry(
            Id(:channel),
            Opt(:hstretch),
            # text entry
            _("&Channel ID")
          ),
          VSpacing(2),
          # check box
          Left(CheckBox(Id(:format), _("Format the Disk"))),
          VSpacing(2),
          # check box
          Left(CheckBox(Id(:diag), _("Use &DIAG"))),
          VStretch()
        ),
        HStretch()
      )

      # Apply the settings
      Wizard.SetContents(caption, content, help, true, true)
      Wizard.RestoreBackButton
      Wizard.RestoreAbortButton

      UI.ChangeWidget(Id(:channel), :ValidChars, "0123456789abcdefABCDEF.")

      UI.SetFocus(Id(:channel))

      ret = nil
      while ret.nil?
        ret = Convert.to_symbol(UI.UserInput)

        if ret == :abort || ret == :cancel
          # yes-no popup
          if !Popup.YesNo(
            _(
              "Really leave the DASD disk configuration without saving?\nAll changes will be lost."
            )
          )
            ret = nil
          end
        elsif ret == :next
          channel = Convert.to_string(UI.QueryWidget(Id(:channel), :Value))

          if !DASDController.IsValidChannel(channel)
            # error popup
            Popup.Error(_("Not a valid channel ID."))
            UI.SetFocus(:channel)
            ret = nil
            next
          end

          channel = DASDController.FormatChannel(channel)

          if !DASDController.GetDeviceIndex(channel).nil?
            # error popup
            Popup.Error(_("Device already exists."))
            ret = nil
            next
          end
        end
      end

      if ret == :next
        channel = Convert.to_string(UI.QueryWidget(Id(:channel), :Value))
        format = Convert.to_boolean(UI.QueryWidget(Id(:format), :Value))
        diag = Convert.to_boolean(UI.QueryWidget(Id(:diag), :Value))

        channel = DASDController.FormatChannel(channel)

        dasd_new = Y2S390::Dasd.new(channel).tap do |dasd|
          dasd.format_watend = format
          dasd.diag_wanted = diag
        end

        DASDController.devices.add(dasd_new)
      end

      ret
    end

    # Run the dialog for deleting DASD devices
    #
    # @return [:next]
    def DeleteDASDDiskDialog
      selected = ListSelectedDASD()
      if selected.empty?
        # error popup message
        Popup.Message(_("No disk selected."))
      else
        selected { |id| DASDController.devices.delete(id) }
      end

      :next
    end
  end
end
