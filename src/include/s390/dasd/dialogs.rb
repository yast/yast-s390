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
  module S390DasdDialogsInclude

    def initialize_s390_dasd_dialogs(include_target)
      Yast.import "UI"
      textdomain "s390"

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

    # List DASD devices that are currently being selected
    # @return [Array<Fixnum>] list of IDs of selected DASD devices
    def ListSelectedDASD
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


    # Get the list of items for the table of DASD devices
    # @param min_chan integer minimal channel number
    # @param max_chan integer maximal channel number
    # @return a list of terms for the table
    def GetDASDDiskItems
      devices = DASDController.GetFilteredDevices

      items = []

      if Mode.config
        items = Builtins.maplist(devices) do |k, d|
          channel = Ops.get_string(d, "channel", "")
          diag = String.YesNo(Ops.get_boolean(d, "diag", false))
          format = String.YesNo(Ops.get_boolean(d, "format", false))
          Item(Id(k), channel, format, diag)
        end
      else
        items = Builtins.maplist(devices) do |k, d|
          active = Ops.get_boolean(d, ["resource", "io", 0, "active"], false)
          channel = Ops.get_string(d, "channel", "")
          access = Builtins.toupper(
            Ops.get_string(d, ["resource", "io", 0, "mode"], "RO")
          )
          diag = String.YesNo(Ops.get(DASDController.diag, channel, false))
          device = Ops.get_string(d, "dev_name", "")
          type = Builtins.toupper(
            Builtins.sformat(
              "%1/%2, %3/%4",
              Builtins.substring(
                Builtins.tohexstring(
                  Ops.bitwise_and(Ops.get_integer(d, "device_id", 0), 65535),
                  4
                ),
                2
              ),
              Builtins.substring(
                Builtins.tohexstring(
                  Ops.get_integer(d, ["detail", "cu_model"], 0),
                  4
                ),
                4
              ),
              Builtins.substring(
                Builtins.tohexstring(
                  Ops.bitwise_and(Ops.get_integer(d, "sub_device_id", 0), 65535),
                  4
                ),
                2
              ),
              Builtins.substring(
                Builtins.tohexstring(
                  Ops.get_integer(d, ["detail", "dev_model"], 0),
                  4
                ),
                4
              )
            )
          )
          formatted = String.YesNo(Ops.get_boolean(d, "formatted", false))
          partition_info = Ops.get_string(d, "partition_info", "--")
          if !active
            type = "--"
            access = "--"
            formatted = "--"
            partition_info = "--"
            device = "--"
          end
          Item(
            Id(k),
            channel,
            device,
            type,
            access,
            diag,
            formatted,
            partition_info
          )
        end
      end

      deep_copy(items)
    end


    def PossibleActions
      if !Mode.config
        return [
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
        return [
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


    def AskNumParallel(max_num_parallel)

      UI.OpenDialog(
        VBox(
          IntField(
            # integer field (count of disks formatted parallel)
            Id(:num_parallel), _("&Parallel Formatted Disks"),
            1, max_num_parallel, max_num_parallel
          ),
          ButtonBox(
            PushButton(Id(:ok), Label.OKButton),
            PushButton(Id(:cancel), Label.CancelButton)
          )
        )
      )

      ret = UI.UserInput()
      num_parallel = UI.QueryWidget(Id(:num_parallel), :Value).to_i

      UI.CloseDialog()

      return ret == :ok ? num_parallel : 0

    end


    def PerformAction(action)
      selected = ListSelectedDASD()
      if Builtins.isempty(selected)
        # error popup message
        Popup.Message(_("No disk selected."))
        return false
      end

      if !Mode.config
        case action
          when :activate, :deactivate
            value = action == :activate
            unformatted_disks = []

            Builtins.foreach(selected) do |id|
              channel = Ops.get_string(
                DASDController.devices,
                [id, "channel"],
                ""
              )
              act_ret = 0
              diag = Ops.get(DASDController.diag, channel, false)
              if value
                act_ret = DASDController.ActivateDisk(channel, diag)
              else
                DASDController.DeactivateDisk(channel, diag)
              end
              if act_ret == 8 # 8 means disk is not formatted
                unformatted_disks << channel
              end
            end
            if unformatted_disks.size > 0
              if unformatted_disks.size == 1
                popup = Builtins.sformat(_("Device %1 is not formatted. Format device now?"), unformatted_disks[0])
              else
                popup = Builtins.sformat(_("There are %1 unformatted devices. Format them now?"), unformatted_disks.size)
              end
              # for autoinst, format unformatted disks later
              if (! Mode.autoinst) && Popup.ContinueCancel(popup)
                devices = unformatted_disks.map do | channel |
                  device = nil
                  cmd = "ls '/sys/bus/ccw/devices/#{channel}/block/' | tr -d '\n'"
                  disk = SCR.Execute(path(".target.bash_output"), cmd)
                  if disk["exit"] == 0 && !disk["stdout"].empty?
                    device = "/dev/#{disk["stdout"]}"
                  else
                    Popup.Error( Builtins.sformat(_("Couldn't find device for channel %1."), channel))
                  end
                  device
                end
                devices.reject! { | d | d.nil? }
                DASDController.FormatDisks(devices, 8) #don't format more than 8 disks in parallel
                unformatted_disks.each do | channel |
                  diag = !!DASDController.diag[channel]
                  DASDController.ActivateDisk(channel, diag)
                end
              end
            end           
            DASDController.ProbeDisks

            return true

          when :diag_off, :diag_on
            value = action == :diag_on

            Builtins.foreach(selected) do |id|
              channel = Ops.get_string(
                DASDController.devices,
                [id, "channel"],
                ""
              )
              active = Ops.get_boolean(
                DASDController.devices,
                [id, "resource", "io", 0, "active"],
                false
              )
              Ops.set(DASDController.diag, channel, value)
              DASDController.ActivateDisk(channel, value) if active
            end
            DASDController.ProbeDisks

            return true

          when :format
            # check if disks are R/W and active
            problem = ""
            Builtins.foreach(selected) do |id|
              active = Ops.get_boolean(
                DASDController.devices,
                [id, "resource", "io", 0, "active"],
                false
              )
              access = Ops.get_string(
                DASDController.devices,
                [id, "resource", "io", 0, "mode"],
                "ro"
              )
              if !active
                # error report, %1 is device identification
                problem = Builtins.sformat(
                  _("Disk %1 is not active."),
                  Ops.get_string(DASDController.devices, [id, "channel"], "")
                )
              elsif access != "rw"
                # error report, %1 is device identification
                problem = Builtins.sformat(
                  _("Disk %1 is not accessible for writing."),
                  Ops.get_string(DASDController.devices, [id, "channel"], "")
                )
              end
            end
            if !Builtins.isempty(problem)
              Popup.Message(problem)
              return false
            end

            num_parallel = [selected.size(), 8].min
            if num_parallel > 1
              num_parallel = AskNumParallel(num_parallel)
            end

            return false if num_parallel == 0

            # final confirmation before formatting the discs
            channels = Builtins.maplist(selected) do |id|
              Ops.get_string(DASDController.devices, [id, "channel"], "")
            end
            channels_str = Builtins.mergestring(channels, ", ")
            if !Popup.AnyQuestionRichText(
                Popup.NoHeadline,
                # popup question
                Builtins.sformat(
                  _(
                    "Formatting these disks destroys all data on them.<br>\n" +
                      "Really format the following disks?<br>\n" +
                      "%1"
                  ),
                  channels_str
                ),
                60,
                20,
                Label.YesButton,
                Label.NoButton,
                :focus_no
              )
              return false
            end

            devices = Builtins.maplist(selected) do |id|
              Ops.get_string(DASDController.devices, [id, "dev_name"], "")
            end
            DASDController.FormatDisks(devices, num_parallel)

            channels.each do |channel|
              diag = DASDController.diag.fetch(channel, false)
              DASDController.ActivateDisk(channel, diag)
            end

            DASDController.ProbeDisks

            return true
        end
      else
        case action
          when :diag_off, :diag_on
            value = action == :diag_on

            Builtins.foreach(selected) do |id|
              Ops.set(DASDController.devices, [id, "diag"], value)
            end

            return true
          when :format_off, :format_on
            value = action == :format_on

            Builtins.foreach(selected) do |id|
              Ops.set(DASDController.devices, [id, "format"], value)
            end

            return true
        end
      end

      false
    end


    # Draw the DASD dialog
    def DisplayDASDDialog
      help_key = Mode.config ? "disk_selection_config" : "disk_selection"

      # Minimal text for the help
      help = Ops.get_string(@DASD_HELPS, help_key, "")

      # Dialog caption
      caption = _("DASD Disk Management")

      header = Empty()

      if Mode.config
        header = Header(
          # table header
          Right(_("Channel ID")),
          # table header
          _("Format"),
          # table header
          _("Use DIAG")
        )
      else
        header = Header(
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
        Mode.config ?
          HBox(
            PushButton(Id(:add), Label.AddButton),
            PushButton(Id(:delete), Label.DeleteButton),
            HStretch(),
            # menu button
            MenuButton(Id(:operation), _("Perform &Action"), PossibleActions())
          ) :
          HBox(
            PushButton(Id(:select_all), _("&Select All")),
            PushButton(Id(:deselect_all), _("&Deselect All")),
            HStretch(),
            # menu button
            MenuButton(Id(:operation), _("Perform &Action"), PossibleActions())
          )
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


    # Run the dialog for DASD disks configuration
    # @return [Symbol] for wizard sequencer
    def DASDDialog
      DisplayDASDDialog()
      ReloadDASDDialog()

      ret = nil
      while ret == nil
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
            UI.QueryWidget(Id(:table), :Items).map { | item | item[0][0] })
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
      while ret == nil
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

          if DASDController.GetDeviceIndex(channel) != nil
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

        d = { "channel" => channel, "format" => format, "diag" => diag }

        DASDController.AddDevice(d)
      end

      ret
    end


    # Run the dialog for deleting DASDs
    # @return [Symbol] from DeleteDASDDiskDialog
    def DeleteDASDDiskDialog
      selected = ListSelectedDASD()
      if Builtins.isempty(selected)
        # error popup message
        Popup.Message(_("No disk selected."))
      else
        Builtins.foreach(selected) { |index| DASDController.RemoveDevice(index) }
      end

      :next
    end

  end
end
