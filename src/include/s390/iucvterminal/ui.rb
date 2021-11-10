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
    def initialize_s390_iucvterminal_ui(_include_target)
      Yast.import "UI"

      textdomain "s390"

      Yast.import "IUCVTerminal"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Integer"

      # Hspacing value between most dialog fields
      @hspacing = 2

      # Vspacing value between most dialog fields
      @vspacing = 0.5
    end

    # Check the "Allowed Terminal Server list" field for validity.
    # @return true for valid inputs
    def IsValidTerminalSrvList
      ret = false

      restrict_hvc_to_srvs = UI.QueryWidget(Id(:restrict_hvc_to_srvs), :Value)
      if restrict_hvc_to_srvs =~ /[^[[:lower:]][[:digit:]],]/
        Popup.Notify(
          _(
            "Wrong input, only lower case letters, numbers and for separation commas are allowed."
          )
        )
      elsif restrict_hvc_to_srvs =~ /^,|,,/
        Popup.Notify(_("Comma is only a separator."))
      elsif restrict_hvc_to_srvs =~ /[[[:lower:]][[:digit:]]]{9,}/
        Popup.Notify(_("z/VM IDs do not allow more than eight characters."))
      else
        ret = true
      end
      ret
    end

    # Check the "IUCV Name" field for validity.
    # @return true for valid inputs
    def IsValidIucvId
      # Terminal id counting starts with 0
      max_length = 8 - (UI.QueryWidget(Id(:iucv_instances), :Value) - 1).to_s.size

      ret = false
      iucv_name = UI.QueryWidget(Id(:iucv_name), :Value)

      if iucv_name =~ /[^[[:lower:]][[:digit:]]]/
        Popup.Notify(_("Wrong IUCV ID, only lower case letters are allowed."))
      elsif iucv_name.size > max_length
        Popup.Notify(
          Builtins.sformat(
            _("IUCV IDs cannot be longer than %1 chars."),
            8
          )
        )
      else
        ret = true
      end
      ret
    end

    # Update the screen according to user input.
    # @return [void]
    def UpdateScreen(ret)
      if ret == :hvc
        UI.ChangeWidget(
          Id(:restrict_hvc_to_srvs),
          :Enabled,
          UI.QueryWidget(Id(:is_hvc_restricted), :Value)
        )
      end

      if ret == :is_hvc_restricted
        UI.ChangeWidget(
          Id(:restrict_hvc_to_srvs),
          :Enabled,
          UI.QueryWidget(Id(:is_hvc_restricted), :Value)
        )
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
          "<p>Several <b>IUCVtty instances</b> can run to provide multiple terminal devices. " \
            "The instances are distinguished by a terminal ID, which is a combination of " \
            "the <b>Terminal ID Prefix</b> and the number of the instance.<br>"
        ) +
        # IUCVTerminal dialog help 4/11
        _(
          "For example, if you define ten instances with the prefix &quot;<i>lxterm</i>&quot;, " \
            "the terminal IDs from <i>lxterm0</i> to <i>lxterm9</i> are available.</p>"
        ) + "<p>&nbsp;</p>" +
        # IUCVTerminal dialog help 5/11
        _("<p><b>HVC</b></p>") +
        # IUCVTerminal dialog help 6/11
        _(
          "<p>The z/VM IUCV HVC device driver is a kernel module and uses device nodes to " \
            "enable up to eight HVC terminal devices to communicate with getty and login programs.</p>"
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
          "<p>Activate <b>route kernel messages to hvc0</b> to route kernel messages to\n" \
            "the hvc0 device instead of ttyS0.<br>"
        ) +
        # IUCVTerminal dialog help 10/11
        _(
          "Should kernel messages still be shown on ttyS0, manually add <b>console=ttyS0</b> " \
            "to the current boot selection kernel parameter in the <b>YaST bootloader module</b>.</p>"
        ) +
        # IUCVTerminal dialog help 11/11
        _(
          "<h3>Warning: HVC Terminals stay logged on without a manual logout through " \
            "the shortcut: ctrl _ d</h3>"
        )

      # Dialog content
      content = HBox(
        HSpacing(3),
        VBox(
          VSpacing(@vspacing + 0.5),
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
            VSpacing(@vspacing + 0.5),
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
                  VSpacing(@vspacing + 0.7),
                  Left(
                    CheckBox(
                      Id(:show_kernel_out_on_hvc),
                      _("route &kernel messages to hvc0")
                    )
                  ),
                  VSpacing(@vspacing + 0.5)
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
      if IUCVTerminal.iucv_instances > 0
        UI.ChangeWidget(Id(:iucv), :Value, true)
        UI.ChangeWidget(
          Id(:iucv_instances), :Value, IUCVTerminal.iucv_instances
        )
      end
      if IUCVTerminal.hvc_instances > 0
        UI.ChangeWidget(Id(:hvc), :Value, true)
        UI.ChangeWidget(Id(:hvc_instances), :Value, IUCVTerminal.hvc_instances)
      end

      unless IUCVTerminal.iucv_name.empty?
        UI.ChangeWidget(Id(:iucv_name), :Value, IUCVTerminal.iucv_name)
      end

      UpdateScreen(:hvc)

      ret = nil
      loop do
        ret = UI.UserInput
        UpdateScreen(ret)

        IsValidTerminalSrvList() if ret == :restrict_hvc_to_srvs

        IsValidIucvId() if ret == :iucv_name

        # check for changes on final user actions
        if [:back, :abort, :cancel, :next, :ok, :finish].include?(ret)
          IUCVTerminal.modified = IUCVTerminal.iucv_instances == 0 &&
            UI.QueryWidget(Id(:iucv), :Value) ||
            IUCVTerminal.iucv_instances != 0 &&
              !UI.QueryWidget(Id(:iucv), :Value) ||
            IUCVTerminal.iucv_instances != 0 &&
              IUCVTerminal.iucv_instances !=
                UI.QueryWidget(Id(:iucv_instances), :Value) ||
            IUCVTerminal.iucv_name !=
              UI.QueryWidget(Id(:iucv_name), :Value) ||
            IUCVTerminal.hvc_instances != 0 &&
              IUCVTerminal.hvc_instances !=
                UI.QueryWidget(Id(:hvc_instances), :Value) ||
            IUCVTerminal.hvc_instances == 0 &&
              UI.QueryWidget(Id(:hvc), :Value) ||
            IUCVTerminal.hvc_instances != 0 &&
              !UI.QueryWidget(Id(:hvc), :Value) ||
            IUCVTerminal.show_kernel_out_on_hvc !=
              UI.QueryWidget(Id(:show_kernel_out_on_hvc), :Value) ||
            IUCVTerminal.restrict_hvc_to_srvs !=
              UI.QueryWidget(Id(:restrict_hvc_to_srvs), :Value) ||
            IUCVTerminal.restrict_hvc_to_srvs != "" &&
              !UI.QueryWidget(Id(:is_hvc_restricted), :Value)

          # if settings were changed don't exit without asking
          if [:back, :abort, :cancel].include?(ret) &&
              IUCVTerminal.modified &&
              !Popup.YesNo(_("Really leave without saving?"))
            ret = :again
          end

          if [:next, :ok, :finish].include?(ret)
            # check iucv id
            iucv_name = UI.QueryWidget(Id(:iucv_name), :Value)
            if !IsValidIucvId() || iucv_name == ""
              UI.SetFocus(:iucv_name)
              Popup.Notify(_("The IUCV ID is not valid."))
              ret = :again
            end

            # check restrict_hvc_to_srvs and make sure they doesn't end with a comma
            if UI.QueryWidget(Id(:is_hvc_restricted), :Value)
              restrict_hvc_to_srvs = UI.QueryWidget(Id(:restrict_hvc_to_srvs), :Value)
              if !IsValidTerminalSrvList() || restrict_hvc_to_srvs == "" ||
                  restrict_hvc_to_srvs =~ /,$/
                UI.SetFocus(:restrict_hvc_to_srvs)
                Popup.Notify(_("The Terminal Servers are not valid."))
                ret = :again
              end
            end
          end
        end

        break if [:back, :abort, :cancel, :next, :ok, :finish].include?(ret)
      end

      # commit changes
      if IUCVTerminal.modified && [:next, :ok, :finish].include?(ret)
        # set instances to zero if it is disabled
        current_hvc_instances = if UI.QueryWidget(Id(:hvc), :Value)
          UI.QueryWidget(Id(:hvc_instances), :Value)
        else
          0
        end
        # no need to provide allowed terminal servers if disabled
        current_restrict_hvc_to_srvs = if UI.QueryWidget(Id(:is_hvc_restricted), :Value)
          UI.QueryWidget(Id(:restrict_hvc_to_srvs), :Value)
        else
          ""
        end
        # check if the bootloader settings need to be adjusted
        IUCVTerminal.has_bootloader_changed =
          IUCVTerminal.restrict_hvc_to_srvs != current_restrict_hvc_to_srvs ||
          IUCVTerminal.show_kernel_out_on_hvc != UI.QueryWidget(Id(:show_kernel_out_on_hvc), :Value)

        if IUCVTerminal.has_bootloader_changed
          Popup.Notify(
            _("The system has to be rebooted for some changes to take effect.")
          )
        end

        IUCVTerminal.hvc_instances = current_hvc_instances
        # set instances to zero if it is disabled
        IUCVTerminal.iucv_instances = if UI.QueryWidget(Id(:iucv), :Value)
          UI.QueryWidget(Id(:iucv_instances), :Value)
        else
          0
        end

        IUCVTerminal.iucv_name = UI.QueryWidget(Id(:iucv_name), :Value)
        IUCVTerminal.restrict_hvc_to_srvs = current_restrict_hvc_to_srvs
        IUCVTerminal.show_kernel_out_on_hvc = UI.QueryWidget(Id(:show_kernel_out_on_hvc), :Value)
      end
      ret
    end

    # The whole squence
    # @return sequence result
    def IUCVTerminalSequence
      Wizard.CreateDialog
      Wizard.SetDesktopIcon("org.opensuse.yast.IUCVTerminal")
      IUCVTerminal.Read
      IUCVTerminal.Write if [:next, :ok, :finish].include?(TerminalDialog())
      UI.CloseDialog
    end
  end
end
