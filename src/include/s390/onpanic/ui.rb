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

# File:  include/s390/onpanic/ui.ycp
# Package:  Configuration of OnPanic
# Summary:  Dialogs definitions
# Authors:  Tim Hardeck <thardeck@suse.de>
#
module Yast
  module S390OnpanicUiInclude
    KDUMP_SERVICE_NAME = "kdump".freeze

    def initialize_s390_onpanic_ui(_include_target)
      Yast.import "UI"

      textdomain "s390"

      Yast.import "OnPanic"
      Yast.import "Label"
      Yast.import "Message"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Service"

      # Should dumpconf be started?
      @start = false
    end

    # Update the screen according to user input
    # @param return symbol
    # @return [void]
    def UpdateScreen(ret)
      @start = ret == :yes if ret == :yes || ret == :no

      if ret == :vmcmd
        vmcmds = Convert.to_string(UI.QueryWidget(Id(:vmcmd), :Value))
        vmcmd_list = Builtins.splitstring(vmcmds, "\n")

        # only five lines are allowed, remove every additional line
        if Ops.greater_than(Builtins.size(vmcmd_list), OnPanic.VMCMD_MAX_ROWS)
          vmcmd_list = Builtins.sublist(vmcmd_list, 0, OnPanic.VMCMD_MAX_ROWS)
          vmcmds = Builtins.mergestring(vmcmd_list, "\n")
          UI.ChangeWidget(Id(:vmcmd), :Value, vmcmds)
          Popup.Notify(
            Builtins.sformat(
              _("Only %1 lines are allowed for VMCMD."),
              OnPanic.VMCMD_MAX_ROWS
            )
          )
        end

        # allow max chars + newlines
        vmcmd_max_chars = Ops.subtract(
          Ops.add(OnPanic.VMCMD_MAX_CHARS, Builtins.size(vmcmd_list)),
          1
        )
        UI.ChangeWidget(:vmcmd, :InputMaxLength, vmcmd_max_chars)
      end

      if @start
        UI.ChangeWidget(Id(:rd), :CurrentButton, :yes)
        UI.ChangeWidget(Id(:onpanic), :Enabled, true)
        UI.ChangeWidget(Id(:delayminutes), :Enabled, true)

        # dis/enable widgets according to `onpanic selection
        on_panic = Convert.to_string(UI.QueryWidget(Id(:onpanic), :Value))
        UI.ChangeWidget(
          Id(:dumpdevice),
          :Enabled,
          on_panic == "dump" || on_panic == "dump_reipl"
        )
        UI.ChangeWidget(Id(:vmcmd), :Enabled, on_panic == "vmcmd")
      else
        # disable all widgets except of "enable dumpconf"
        UI.ChangeWidget(Id(:rd), :CurrentButton, :no)
        Builtins.foreach([:onpanic, :dumpdevice, :vmcmd, :delayminutes]) do |widget|
          UI.ChangeWidget(Id(widget), :Enabled, false)
        end
      end

      nil
    end

    # Dialog for seting up OnPanic
    def OnPanicDialog
      # On Panic Actions
      actions = ["stop", "dump", "reipl", "dump_reipl", "vmcmd"]
      # Mkdump list of dump devices
      dump_devices = deep_copy(OnPanic.dump_devices)

      # For translators: Caption of the dialog
      caption = _("On Panic Configuration")
      help = Ops.add(
        # OnPanic dialog help 1/11
        _(
          "<p><b>Configure the actions to be taken if a kernel panic occurs</b></p>"
        ) +
          # OnPanic dialog help 2/11
          _(
            "<p>The <b>Dumpconf</b> daemon needs to be enabled to influence the behavior " \
            "during kernel panics.</p>"
          ) +
          # OnPanic dialog help 3/11
          _("<p>The following <b>Panic Actions</b> are possible:<br>") +
          # OnPanic dialog help 4/11
          _("<b>stop</b> Stop Linux (default).<br>") +
          # OnPanic dialog help 5/11
          _("<b>dump</b> Dump Linux and stop system.<br>") +
          # OnPanic dialog help 6/11
          _("<b>reipl</b> Reboot Linux.<br>") +
          # OnPanic dialog help 7/11
          _(
            "<b>dump_reipl</b> Dump Linux and reboot system. This option is only " \
            "available\non LPAR with z9(r) machines and later and on z/VMversion 5.3 and later.<br>"
          ) +
          # OnPanic dialog help 8/11
          _("<b>vmcmd</b> Execute specified CP commands and stop system.</p>") +
          # OnPanic dialog help 9/11
          _(
            "<p>The time defined in <b>Delay Minutes</b> defers activating the specified " \
            "panic action for a newly started system to prevent loops. If the system " \
            "crashes before the time has elapsed the default action (stop) is performed.</p>"
          ) +
          # OnPanic dialog help 10/11
          _(
            "<p>The device for dumping the memory can be set with <b>Dump Device</b>. If no " \
            "device is shown you have to create one with the <b>YaST Dump Devices</b> dialog.</p>"
          ),
        # OnPanic dialog help 11/11
        Builtins.sformat(
          _(
            "<p>With <b>VMCMD</b> specify CP commands to be executed before the Linux " \
            "system is stopped. Only %1 lines and a total of %2 chars are allowed.</p>"
          ),
          OnPanic.VMCMD_MAX_ROWS,
          OnPanic.VMCMD_MAX_CHARS
        )
      )

      content = HBox(
        HSpacing(3),
        VBox(
          VSpacing(2),
          VSquash(
            HBox(
              RadioButtonGroup(
                Id(:rd),
                HSquash(
                  VBox(
                    Left(
                      RadioButton(
                        Id(:no),
                        Opt(:notify),
                        # radio button label
                        _("Do No&t Start Dumpconf"),
                        !@start
                      )
                    ),
                    Left(
                      RadioButton(
                        Id(:yes),
                        Opt(:notify),
                        # radio button label
                        _("&Start Dumpconf"),
                        @start
                      )
                    )
                  )
                )
              ),
              HSpacing(5),
              VCenter(
                HBox(
                  ComboBox(
                    Id(:onpanic),
                    Opt(:notify, :hstretch),
                    # combobox label
                    _("&Panic Action"),
                    actions
                  ),
                  IntField(Id(:delayminutes), _("Delay &Minutes"), 0, 300, 5)
                )
              )
            )
          ),
          VSpacing(),
          ComboBox(
            Id(:dumpdevice),
            Opt(:hstretch),
            # combobox label
            _("&Dump Device"),
            dump_devices
          ),
          VSpacing(),
          MultiLineEdit(Id(:vmcmd), Opt(:notify), _("&VMCMD"), ""),
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

      # set configuration settings if available
      @start = OnPanic.start
      # initialize fields
      UI.ChangeWidget(Id(:onpanic), :Value, OnPanic.on_panic)
      UI.ChangeWidget(Id(:delayminutes), :Value, OnPanic.delay_min)
      UI.ChangeWidget(Id(:vmcmd), :Value, OnPanic.vmcmds)
      UI.ChangeWidget(Id(:dumpdevice), :Value, OnPanic.dump_line)
      # limit the vmcmd size
      UI.ChangeWidget(:vmcmd, :InputMaxLength, OnPanic.VMCMD_MAX_CHARS)

      ret = nil
      UpdateScreen(ret)
      loop do
        ret = Convert.to_symbol(UI.UserInput)
        UpdateScreen(ret)

        # check for changes on final user actions
        if Builtins.contains([:back, :abort, :cancel, :next, :ok, :finish], ret)
          OnPanic.modified = OnPanic.start != @start ||
            OnPanic.on_panic !=
              Convert.to_string(UI.QueryWidget(Id(:onpanic), :Value)) ||
            OnPanic.delay_min !=
              Convert.to_integer(UI.QueryWidget(Id(:delayminutes), :Value)) ||
            OnPanic.vmcmds !=
              Convert.to_string(UI.QueryWidget(Id(:vmcmd), :Value)) ||
            OnPanic.dump_line !=
              Convert.to_string(UI.QueryWidget(Id(:dumpdevice), :Value))

          # if settings were changed don't exit without asking
          if Builtins.contains([:back, :abort, :cancel], ret) &&
              OnPanic.modified &&
              !Popup.ReallyAbort(true)
            ret = :again
          end

          # check misconfigurations
          if Builtins.contains([:next, :ok, :finish], ret) && @start
            # don't allow dumps if no device is available
            if Builtins.regexpmatch(
              Convert.to_string(UI.QueryWidget(Id(:onpanic), :Value)),
              "^dump"
            ) &&
                Convert.to_string(UI.QueryWidget(Id(:dumpdevice), :Value)) == ""
              Popup.Notify(
                _(
                  "It is not possible to enable the dump process without a dump device."
                )
              )
              ret = :again
            end

            # don't allow vmcmd without at least one command
            if Convert.to_string(UI.QueryWidget(Id(:onpanic), :Value)) == "vmcmd" &&
                !Builtins.regexpmatch(
                  Convert.to_string(UI.QueryWidget(Id(:vmcmd), :Value)),
                  "[[:alpha:]]{2,}"
                )
              Popup.Notify(
                _(
                  "It is not possible to use vmcmd  without defining at least one command."
                )
              )
              ret = :again
            end
          end
        end

        break if Builtins.contains([:back, :abort, :cancel, :next, :ok], ret)
      end

      # commit changes
      if OnPanic.modified && (ret == :next || ret == :ok || ret == :finish)
        OnPanic.start = @start
        OnPanic.on_panic = Convert.to_string(
          UI.QueryWidget(Id(:onpanic), :Value)
        )
        OnPanic.delay_min = Convert.to_integer(
          UI.QueryWidget(Id(:delayminutes), :Value)
        )
        OnPanic.vmcmds = Convert.to_string(UI.QueryWidget(Id(:vmcmd), :Value))
        OnPanic.dump_line = Convert.to_string(
          UI.QueryWidget(Id(:dumpdevice), :Value)
        )
      end

      ret
    end

    # Check if kdump is enabled. If yes, ask the user to disable it
    # because it conflicts with OnPanic
    def check_kdump
      if OnPanic.start &&
          (Service.Enabled(KDUMP_SERVICE_NAME) || Service.Active(KDUMP_SERVICE_NAME)) && Yast::Popup.YesNo(
          # TRANSLATORS: %{s1},%{s2} are the service names
          format(_(
                   "The service %{s1} is active and will conflict with dumpconf.\n" \
                   "Would you like to disable %{s2}? \n"
                 ), s1: KDUMP_SERVICE_NAME, s2: KDUMP_SERVICE_NAME)
        )
        Service.Disable(KDUMP_SERVICE_NAME)
        Service.Stop(KDUMP_SERVICE_NAME) if Service.active?(KDUMP_SERVICE_NAME)
      end
    end

    # The whole sequence
    def OnPanicSequence
      Wizard.CreateDialog
      Wizard.SetDesktopIcon("org.opensuse.yast.OnPanic")

      OnPanic.Read

      ret = OnPanicDialog()
      if [:next, :finish, :ok].include?(ret)
        check_kdump
        OnPanic.Write
      end

      UI.CloseDialog
      ret
    end
  end
end
