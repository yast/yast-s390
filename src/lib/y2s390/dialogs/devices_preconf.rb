# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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

require "ui/installation_dialog"
require "yast2/execute"

module Y2S390
  module Dialogs
    # Provides to the user the option to pre-configure devices for the installation
    # process. It also allows to avoid devices auto-configuration for the installed
    # system.
    class DevicesPreconf < ::UI::InstallationDialog
      def initialize
        super

        textdomain "s390"

        @autoconfig = false
      end

      # Saves selected values when user goes next
      #
      # @see #save
      def next_handler
        save

        super
      end

      # Directly loads auto-configuration when user selects the proper button
      #
      # @param input [Symbol]
      def handle_event(input)
        load_autoconfig if input == :load_autoconfig
      end

      # Whether the user selected auto-configuration checkbox
      #
      # @return [Boolean]
      def autoconfig?
        @autoconfig
      end

    private

      def dialog_title
        # TRANSLATORS: Title of the installation step to auto-configure devices.
        _("I/0 Device Auto-configuration")
      end

      def dialog_content
        MarginBox(
          2, 1,
          VBox(
            Label(_("I/O device auto-configuration found.")),
            load_autoconfig_button,
            VSpacing(2),
            Label(_("The button above will only affect the installation process.")),
            autoconfig_checkbox
          )
        )
      end

      def help_text
        # TRANSLATORS: Help text, where %{autoconfig_button} is replaced by the label of
        # the button to load the auto-configuration, %{autoconfig_file} is replaced by a
        # file path (e.g., /tmp/bar), and %{autoconfig_checkbox} is replaced by the label
        # of the checkbox to avoid auto-configuration in the installed system.
        format(
          _(
            "<p><b>%{autoconfig_button}</b>: loads I/O devices auto-configuration " \
            "from %{autoconfig_file}.</p>" \
            "<p><b>%{autoconfig_checkbox}</b>: when unchecked, the auto-configuration " \
            "is not applied again for the installed system.</p>"
          ),
          autoconfig_button:   load_autoconfig_button_label,
          autoconfig_file:     Clients::InstDevicesPreconf::AUTOCONFIG_FILE,
          autoconfig_checkbox: autoconfig_checkbox_label
        )
      end

      def load_autoconfig_button
        PushButton(Id(:load_autoconfig), load_autoconfig_button_label)
      end

      def load_autoconfig_button_label
        # TRANSLATORS: Label of button to load devices auto-configuration.
        _("Load Auto-configuration Now")
      end

      def autoconfig_checkbox(checked: true)
        CheckBox(Id(:autoconfig), autoconfig_checkbox_label, checked)
      end

      def autoconfig_checkbox_label
        # TRANSLATORS: Label of checkbox to disable auto-configuration for the installed system.
        _("Apply Auto-configuration Also To The Installed System")
      end

      # Tries to load auto-configuration
      #
      # An error popup is shown when the command fails, see Yast::Execute#locally.
      def load_autoconfig
        Yast::Execute.locally(
          "chzdev", "--import", "/sys/firmware/sclp_sd/config/data",
          "--force", "--yes", "--no-root-update", "--no-settle", "--active", "--quiet"
        )
      end

      def save
        @autoconfig = widget_value(:autoconfig)
      end

      # Helper to get widget value
      def widget_value(id, attr: :Value)
        Yast::UI.QueryWidget(Id(id), attr)
      end
    end
  end
end
