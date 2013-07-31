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

# File:	include/s390/iucvterminal/ui.ycp
# Package:	Configuration IUCV Terminal Settings
# Summary:	Dialogs definitions
# Authors:	Tim Hardeck <thardeck@suse.de>
#
module Yast
  module S390IucvterminalUiInclude
    def initialize_s390_iucvterminal_ui(include_target)
      Yast.import "UI"

      textdomain "s390"

      Yast.import "IUCVTerminal"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Integer"

      # Hspacing value between most dialog fields
      @hspacing = Convert.convert(2, :from => "integer", :to => "float")

      # Vspacing value between most dialog fields
      @vspacing = 0.5

      # Text field for changing settings of all HVC instances
      @TEXT_INSTANCES_ALL = IUCVTerminal.TEXT_INSTANCES_ALL

      # Text field for not changing the HVC emulation
      @TEXT_EMU_NO_CHANGE = IUCVTerminal.TEXT_EMU_NO_CHANGE

      # Default HVC emulation
      @DEFAULT_HVC_EMULATION = IUCVTerminal.DEFAULT_HVC_EMULATION

      # Map of HVC terminals and their according emulations
      @hvc_emulations = {}
    end

    # Update the HVC emulation for the "<all> instance" according to the selected
    # emulations.
    # So if all emulations are the same <all> shows this particular emulation
    # otherwise the <don't change> selection is shown to prevent overwriting.
    # @return [void]
    def UpdateHVCEmulation
      previous_emulation = Ops.get_string(
        @hvc_emulations,
        "hvc0",
        @DEFAULT_HVC_EMULATION
      )
      same_emulation = true
      terminal = ""
      # for the number of instances
      Builtins.foreach(
        Integer.RangeFrom(
          0,
          Convert.to_integer(UI.QueryWidget(Id(:hvc_instances), :Value))
        )
      ) do |i|
        terminal = Ops.add("hvc", Builtins.tostring(i))
        if Ops.get_string(@hvc_emulations, terminal, @DEFAULT_HVC_EMULATION) != previous_emulation
          same_emulation = false
        end
        previous_emulation = Ops.get_string(
          @hvc_emulations,
          terminal,
          @DEFAULT_HVC_EMULATION
        )
      end

      if same_emulation
        Ops.set(@hvc_emulations, @TEXT_INSTANCES_ALL, previous_emulation)
      else
        Ops.set(@hvc_emulations, @TEXT_INSTANCES_ALL, @TEXT_EMU_NO_CHANGE)
      end

      # update emulation field if all is selected
      if Convert.to_string(UI.QueryWidget(Id(:hvc_instance), :Value)) == @TEXT_INSTANCES_ALL
        UI.ChangeWidget(
          Id(:hvc_emulation),
          :Value,
          Ops.get_string(
            @hvc_emulations,
            @TEXT_INSTANCES_ALL,
            @TEXT_EMU_NO_CHANGE
          )
        )
      end

      nil
    end

    # Check the "Allowed Terminal Server list" field for validity.
    # @return true for valid inputs
    def IsValidTerminalSrvList
      ret = false

      restrict_hvc_to_srvs = Convert.to_string(
        UI.QueryWidget(Id(:restrict_hvc_to_srvs), :Value)
      )
      if Builtins.regexpmatch(restrict_hvc_to_srvs, "[^[:lower:][:digit:],]")
        Popup.Notify(
          _(
            "Wrong input, only lower case letters, numbers and for separation commas are allowed."
          )
        )
      elsif Builtins.regexpmatch(restrict_hvc_to_srvs, "^,|,,")
        Popup.Notify(_("Comma is only a separator."))
      elsif Builtins.regexpmatch(
          restrict_hvc_to_srvs,
          "[[:lower:][:digit:]]{9,}"
        )
        Popup.Notify(_("z/VM IDs do not allow more than eight characters."))
      else
        ret = true
      end
      ret
    end

    # Check the "IUCV Name" field for validity.
    # @return true for valid inputs
    def IsValidIucvId
      # in case of more than 99 iucv instances only 5 characters would be allowed
      #  because the name is limited to eight chars
      max_length = Ops.less_than(IUCVTerminal.MAX_IUCV_TTYS, 100) ? 6 : 5

      ret = false
      iucv_name = Convert.to_string(UI.QueryWidget(Id(:iucv_name), :Value))

      if Builtins.regexpmatch(iucv_name, "[^[:lower:][:digit:]]")
        Popup.Notify(_("Wrong IUCV ID, only lower case letters are allowed."))
      elsif Builtins.regexpmatch(
          iucv_name,
          Ops.add(
            Ops.add(".{", Builtins.tostring(Ops.add(max_length, 1))),
            ",}"
          )
        )
        Popup.Notify(
          Builtins.sformat(
            _("IUCV IDs cannot be longer than %1 chars."),
            max_length
          )
        )
      else
        ret = true
      end
      ret
    end

    # Check if the HVC emulations differ from  the ones loaded at start.
    # @return true if it has changed
    def HasEmulationChanged
      has_changed = false
      key = ""
      # for hvc instances
      Builtins.foreach(
        Integer.RangeFrom(
          0,
          Convert.to_integer(UI.QueryWidget(Id(:hvc_instances), :Value))
        )
      ) do |i|
        key = Ops.add("hvc", Builtins.tostring(i))
        if Ops.get_string(@hvc_emulations, key, "") !=
            Ops.get(IUCVTerminal.hvc_emulations, i, "")
          has_changed = true
          raise Break
        end
      end
      has_changed
    end

    # Update the screen according to user input.
    # @return [void]
    def UpdateScreen(ret)
      if ret == :hvc
        # enable if restrict access is enabled too
        UI.ChangeWidget(
          Id(:restrict_hvc_to_srvs),
          :Enabled,
          Convert.to_boolean(UI.QueryWidget(Id(:is_hvc_restricted), :Value))
        )
      end

      if ret == :is_hvc_restricted
        UI.ChangeWidget(
          Id(:restrict_hvc_to_srvs),
          :Enabled,
          Convert.to_boolean(UI.QueryWidget(Id(:is_hvc_restricted), :Value))
        )
      end

      if ret == :hvc_instances
        # only show the selected number of instances plus the entry <all>
        number = Ops.add(
          Convert.to_integer(UI.QueryWidget(Id(:hvc_instances), :Value)),
          1
        )
        hvc_instances = Builtins.sublist(
          IUCVTerminal.POSSIBLE_HVC_INSTANCES,
          0,
          number
        )
        UI.ChangeWidget(Id(:hvc_instance), :Items, hvc_instances)

        # make sure not to overwrite the emulation after adding new ones
        UpdateHVCEmulation()
      end

      if ret == :hvc_instance
        instance = Convert.to_string(UI.QueryWidget(Id(:hvc_instance), :Value))
        UI.ChangeWidget(
          Id(:hvc_emulation),
          :Value,
          Ops.get_string(@hvc_emulations, instance, @TEXT_EMU_NO_CHANGE)
        )
      end

      if ret == :hvc_emulation
        instance = Convert.to_string(UI.QueryWidget(Id(:hvc_instance), :Value))
        emulation = Convert.to_string(
          UI.QueryWidget(Id(:hvc_emulation), :Value)
        )

        if emulation != @TEXT_EMU_NO_CHANGE
          if instance == @TEXT_INSTANCES_ALL
            Builtins.foreach(IUCVTerminal.POSSIBLE_HVC_INSTANCES) do |key|
              Ops.set(@hvc_emulations, key, emulation)
            end
          else
            Ops.set(@hvc_emulations, @TEXT_INSTANCES_ALL, @TEXT_EMU_NO_CHANGE)
            Ops.set(
              @hvc_emulations,
              instance,
              Convert.to_string(UI.QueryWidget(Id(:hvc_emulation), :Value))
            )
          end
        end
        UpdateHVCEmulation()
      end

      nil
    end

    # Run the dialog
    # @return [Symbol] EditDumpDialog that was edited
    def TerminalDialog
      caption = "Configure IUCV Terminal Settings"

      help =
        # IUCVTerminal dialog help 1/10
        _("<p><h2>Configure Local Terminal System Settings</h2></p>") +
          # IUCVTerminal dialog help 2/11
          _("<p><b>IUCVtty</b></p>") +
          # IUCVTerminal dialog help 3/11
          _(
            "<p>Several <b>IUCVtty instances</b> can run to provide multiple terminal devices. The instances are distinguished by a terminal ID, which is a combination of the <b>Terminal ID Prefix</b> and the number of the instance.<br>"
          ) +
          # IUCVTerminal dialog help 4/11
          _(
            "For example, if you define ten instances with the prefix &quot;<i>lxterm</i>&quot;, the terminal IDs from <i>lxterm1</i> to <i>lxterm10</i> are available.</p>"
          ) + "<p>&nbsp;</p>" +
          # IUCVTerminal dialog help 5/11
          _("<p><b>HVC</b></p>") +
          # IUCVTerminal dialog help 6/11
          _(
            "<p>The z/VM IUCV HVC device driver is a kernel module and uses device nodes to enable up to eight HVC terminal devices to communicate with getty and login programs.</p>"
          ) +
          # IUCVTerminal dialog help 7/11
          _(
            "<p>With <b>restrict access</b>, allow only connections from certain <b>terminal servers</b>.</p>"
          ) +
          # IUCVTerminal dialog help 8/11
          _(
            "<p>Define the emulation for all instances at once or for each one separately.</p>"
          ) +
          # IUCVTerminal dialog help 9/11
          _(
            "<p>Activate <b>route kernel messages to hvc0</b> to route kernel messages to\nthe hvc0 device instead of ttyS0.<br>"
          ) +
          # IUCVTerminal dialog help 10/11
          _(
            "Should kernel messages still be shown on ttyS0, manually add <b>console=ttyS0</b> to the current boot selection kernel parameter in the <b>YaST bootloader module</b>.</p>"
          ) +
          # IUCVTerminal dialog help 11/11
          _(
            "<h3>Warning: HVC Terminals stay logged on without a manual logout through the shortcut: ctrl _ d</h3>"
          )


      # Dialog content
      content = HBox(
        HSpacing(3),
        VBox(
          VSpacing(Ops.add(@vspacing, 0.5)),
          VBox(
            CheckBoxFrame(
              Id(:iucv),
              _("&IUCVtty"),
              false,
              VBox(
                HBox(
                  HSpacing(@hspacing),
                  InputField(
                    Id(:iucv_name),
                    Opt(:notify, :hstretch),
                    _("Terminal ID &Prefix"),
                    ""
                  ),
                  HSpacing(2),
                  IntField(
                    Id(:iucv_instances),
                    _("I&UCVtty instances"),
                    1,
                    IUCVTerminal.MAX_IUCV_TTYS,
                    1
                  ),
                  HSpacing(@hspacing)
                ),
                VSpacing(@vspacing)
              )
            ),
            VSpacing(Ops.add(@vspacing, 0.5)),
            CheckBoxFrame(
              Id(:hvc),
              Opt(:notify),
              _("HVC"),
              false,
              HBox(
                HSpacing(@hspacing),
                VBox(
                  VSpacing(@vspacing),
                  HBox(
                    IntField(
                      Id(:hvc_instances),
                      Opt(:notify),
                      _("H&VC instances"),
                      1,
                      8,
                      1
                    )
                  ),
                  VSpacing(@vspacing),
                  HBox(
                    CheckBox(
                      Id(:is_hvc_restricted),
                      Opt(:notify),
                      _("Restrict &access to")
                    ),
                    HSpacing(1),
                    InputField(
                      Id(:restrict_hvc_to_srvs),
                      Opt(:notify, :hstretch),
                      _("Allowed Terminal &Servers"),
                      ""
                    )
                  ),
                  VSpacing(@vspacing),
                  HBox(
                    ComboBox(
                      Id(:hvc_instance),
                      Opt(:notify, :hstretch),
                      _("Select I&nstance"),
                      IUCVTerminal.POSSIBLE_HVC_INSTANCES
                    ),
                    HSpacing(1),
                    ComboBox(
                      Id(:hvc_emulation),
                      Opt(:notify, :hstretch),
                      _("Select &Emulation"),
                      IUCVTerminal.HVC_EMULATIONS
                    )
                  ),
                  VSpacing(Ops.add(@vspacing, 0.7)),
                  Left(
                    CheckBox(
                      Id(:show_kernel_out_on_hvc),
                      _("route &kernel messages to hvc0")
                    )
                  ),
                  VSpacing(Ops.add(@vspacing, 0.5))
                ),
                HSpacing(@hspacing)
              )
            )
          ),
          VStretch()
        ),
        HSpacing(3)
      )

      Wizard.SetContentsButtons(
        caption,
        content,
        help,
        Label.BackButton,
        Label.OKButton
      )
      Wizard.HideBackButton
      Wizard.SetAbortButton(:cancel, Label.CancelButton)

      # initialize hvc_emulations with default value
      Builtins.foreach(IUCVTerminal.POSSIBLE_HVC_INSTANCES) do |key|
        @hvc_emulations = Builtins.add(
          @hvc_emulations,
          key,
          @DEFAULT_HVC_EMULATION
        )
      end

      if Ops.greater_than(Builtins.size(IUCVTerminal.hvc_emulations), 0)
        i = 0
        Builtins.foreach(IUCVTerminal.hvc_emulations) do |emulation|
          Ops.set(
            @hvc_emulations,
            Ops.add("hvc", Builtins.tostring(i)),
            emulation
          )
          i = Ops.add(i, 1)
        end
        UpdateHVCEmulation()
      end

      UI.ChangeWidget(
        Id(:show_kernel_out_on_hvc),
        :Value,
        IUCVTerminal.show_kernel_out_on_hvc
      )
      if IUCVTerminal.restrict_hvc_to_srvs != ""
        UI.ChangeWidget(
          Id(:restrict_hvc_to_srvs),
          :Value,
          IUCVTerminal.restrict_hvc_to_srvs
        )
        UI.ChangeWidget(Id(:is_hvc_restricted), :Value, true)
      end

      # initialize screen
      if Ops.greater_than(IUCVTerminal.iucv_instances, 0)
        UI.ChangeWidget(Id(:iucv), :Value, true)
        UI.ChangeWidget(
          Id(:iucv_instances),
          :Value,
          IUCVTerminal.iucv_instances
        )
      end
      if Ops.greater_than(IUCVTerminal.hvc_instances, 0)
        UI.ChangeWidget(Id(:hvc), :Value, true)
        UI.ChangeWidget(Id(:hvc_instances), :Value, IUCVTerminal.hvc_instances)
      end

      if IUCVTerminal.iucv_name != ""
        UI.ChangeWidget(Id(:iucv_name), :Value, IUCVTerminal.iucv_name)
      end

      UpdateScreen(:hvc_instances)
      UpdateScreen(:hvc_instance)
      UpdateScreen(:iucv)
      UpdateScreen(:hvc)

      ret = nil
      begin
        ret = Convert.to_symbol(UI.UserInput)
        UpdateScreen(ret)

        IsValidTerminalSrvList() if ret == :restrict_hvc_to_srvs

        IsValidIucvId() if ret == :iucv_name

        # check for changes on final user actions
        if Builtins.contains([:back, :abort, :cancel, :next, :ok, :finish], ret)
          IUCVTerminal.modified = IUCVTerminal.iucv_instances == 0 &&
            Convert.to_boolean(UI.QueryWidget(Id(:iucv), :Value)) ||
            IUCVTerminal.iucv_instances != 0 &&
              !Convert.to_boolean(UI.QueryWidget(Id(:iucv), :Value)) ||
            IUCVTerminal.iucv_instances != 0 &&
              IUCVTerminal.iucv_instances !=
                Convert.to_integer(UI.QueryWidget(Id(:iucv_instances), :Value)) ||
            IUCVTerminal.iucv_name !=
              Convert.to_string(UI.QueryWidget(Id(:iucv_name), :Value)) ||
            IUCVTerminal.hvc_instances != 0 &&
              IUCVTerminal.hvc_instances !=
                Convert.to_integer(UI.QueryWidget(Id(:hvc_instances), :Value)) ||
            IUCVTerminal.hvc_instances == 0 &&
              Convert.to_boolean(UI.QueryWidget(Id(:hvc), :Value)) ||
            IUCVTerminal.hvc_instances != 0 &&
              !Convert.to_boolean(UI.QueryWidget(Id(:hvc), :Value)) ||
            IUCVTerminal.show_kernel_out_on_hvc !=
              Convert.to_boolean(
                UI.QueryWidget(Id(:show_kernel_out_on_hvc), :Value)
              ) ||
            IUCVTerminal.restrict_hvc_to_srvs !=
              Convert.to_string(
                UI.QueryWidget(Id(:restrict_hvc_to_srvs), :Value)
              ) ||
            IUCVTerminal.restrict_hvc_to_srvs != "" &&
              !Convert.to_boolean(
                UI.QueryWidget(Id(:is_hvc_restricted), :Value)
              ) ||
            HasEmulationChanged() &&
              Convert.to_boolean(UI.QueryWidget(Id(:hvc), :Value))

          # if settings were changed don't exit without asking
          if Builtins.contains([:back, :abort, :cancel], ret) &&
              IUCVTerminal.modified &&
              !Popup.YesNo(_("Really leave without saving?"))
            ret = :again
          end

          if Builtins.contains([:next, :ok, :finish], ret)
            # check iucv id
            iucv_name = Convert.to_string(
              UI.QueryWidget(Id(:iucv_name), :Value)
            )
            if !IsValidIucvId() || iucv_name == ""
              UI.SetFocus(:iucv_name)
              Popup.Notify(_("The IUCV ID is not valid."))
              ret = :again
            end

            # check restrict_hvc_to_srvs and make sure they doesn't end with a comma
            if Convert.to_boolean(
                UI.QueryWidget(Id(:is_hvc_restricted), :Value)
              )
              restrict_hvc_to_srvs = Convert.to_string(
                UI.QueryWidget(Id(:restrict_hvc_to_srvs), :Value)
              )
              if !IsValidTerminalSrvList() || restrict_hvc_to_srvs == "" ||
                  Builtins.regexpmatch(restrict_hvc_to_srvs, ",$")
                UI.SetFocus(:restrict_hvc_to_srvs)
                Popup.Notify(_("The Terminal Servers are not valid."))
                ret = :again
              end
            end
          end
        end
      end while !Builtins.contains([:back, :abort, :cancel, :next, :ok, :finish], ret)


      # commit changes
      if IUCVTerminal.modified && (ret == :next || ret == :ok || ret == :finish)
        # set instances to zero if it is disabled
        current_hvc_instances = Convert.to_boolean(
          UI.QueryWidget(Id(:hvc), :Value)
        ) ?
          Convert.to_integer(UI.QueryWidget(Id(:hvc_instances), :Value)) :
          0
        # no need to provide allowed terminal servers if disabled
        current_restrict_hvc_to_srvs = Convert.to_boolean(
          UI.QueryWidget(Id(:is_hvc_restricted), :Value)
        ) ?
          Convert.to_string(UI.QueryWidget(Id(:restrict_hvc_to_srvs), :Value)) :
          ""
        # check if the bootloader settings need to be adjusted
        IUCVTerminal.has_bootloader_changed = IUCVTerminal.restrict_hvc_to_srvs != current_restrict_hvc_to_srvs ||
          IUCVTerminal.show_kernel_out_on_hvc !=
            Convert.to_boolean(
              UI.QueryWidget(Id(:show_kernel_out_on_hvc), :Value)
            )

        if IUCVTerminal.has_bootloader_changed
          Popup.Notify(
            _("The system has to be rebooted for some changes to take effect.")
          )
        end

        IUCVTerminal.hvc_instances = current_hvc_instances
        # set instances to zero if it is disabled
        IUCVTerminal.iucv_instances = Convert.to_boolean(
          UI.QueryWidget(Id(:iucv), :Value)
        ) ?
          Convert.to_integer(UI.QueryWidget(Id(:iucv_instances), :Value)) :
          0

        IUCVTerminal.iucv_name = Convert.to_string(
          UI.QueryWidget(Id(:iucv_name), :Value)
        )
        IUCVTerminal.restrict_hvc_to_srvs = current_restrict_hvc_to_srvs
        IUCVTerminal.show_kernel_out_on_hvc = Convert.to_boolean(
          UI.QueryWidget(Id(:show_kernel_out_on_hvc), :Value)
        )
        # commit hvc emulations
        if Ops.greater_than(IUCVTerminal.hvc_instances, 0)
          hvc_emulation_list = []
          key = ""
          Builtins.foreach(Integer.RangeFrom(0, IUCVTerminal.hvc_instances)) do |i|
            key = Ops.add("hvc", Builtins.tostring(i))
            hvc_emulation_list = Builtins.add(
              hvc_emulation_list,
              Ops.get_string(@hvc_emulations, key, @DEFAULT_HVC_EMULATION)
            )
          end
          IUCVTerminal.hvc_emulations = deep_copy(hvc_emulation_list)
        end
      end
      ret
    end


    # The whole squence
    # @return sequence result
    def IUCVTerminalSequence
      ret = nil
      Wizard.CreateDialog
      Wizard.SetDesktopIcon("iucvterminal")
      IUCVTerminal.Read
      ret = TerminalDialog()
      # only write during
      IUCVTerminal.Write if ret == :next || ret == :finish || ret == :ok
      UI.CloseDialog


      ret
    end
  end
end
