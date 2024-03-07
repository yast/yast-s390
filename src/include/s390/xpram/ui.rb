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

# File:  include/xpram/ui.ycp
# Package:  Configuration of xpram
# Summary:  Dialogs definitions
# Authors:  Ihno Krumreich <Ihno@suse.de>
#
# $Id$
module Yast
  module S390XpramUiInclude
    def initialize_s390_xpram_ui(_include_target)
      Yast.import "UI"

      textdomain "xpram"

      Yast.import "Xpram"
      Yast.import "Label"
      Yast.import "Message"
      Yast.import "Package"
      Yast.import "Popup"
      Yast.import "Service"
      Yast.import "Wizard"
    end

    # Dialog for seting up XpRAM
    # @return [Symbol] XpRAMDialog
    def XpRAMDialog
      # For translators: Caption of the dialog
      caption = _("XPRAM Configuration")

      # help text for XPRAM 1/4
      help = _("<p>Here, configure the <b>XPRAM</b> for your computer.</p>") +
        # help text for XPRAM 2/4
        _(
          "<p>This tool currently only supports assigning the entire XPRAM to one partition. " \
          "To have multiple partitions, look at \"Device Drivers, Features and Commands " \
          "November 30, 2004\" for the Linux kernel 2.6 - April 2004 stream.</p>" \
          "<p>In this case disable XPRAM in this module.</p>"
        ) +
        # help text for XPRAM 3/4
        _("<p>Choose the correct mount point for <b>Mount Point</b>.</p>") +
        # help text for XPRAM 4/4
        _("<p>Next, choose the file system to use on the device.</p>")

      start = Xpram.start
      force = Xpram.force
      mountpoint = Xpram.mountpoint
      fstype = Xpram.fstype

      m_points = ["swap", "/home2"]
      f_types = ["ext2", "ext3", "ext4", "swap"]

      con = HBox(
        HSpacing(3),
        VBox(
          VSpacing(2),
          RadioButtonGroup(
            Id(:rd),
            Left(
              HVSquash(
                VBox(
                  Left(
                    RadioButton(
                      Id(:no),
                      Opt(:notify),
                      # radio button label for to not start xpram
                      _("Do No&t Start XPRAM"),
                      !start
                    )
                  ),
                  Left(
                    RadioButton(
                      Id(:yes),
                      Opt(:notify),
                      # radio button label for to start xpram
                      _("&Start XPRAM"),
                      start
                    )
                  )
                )
              )
            )
          ),
          VSpacing(),
          Left(
            CheckBox(
              Id(:force),
              _(
                "Install File System or Swap Although &XPRAM Contains Valid Data"
              ),
              force
            )
          ),
          VSpacing(),
          # frame label
          Frame(
            _("Mount Point"),
            HBox(
              HSpacing(),
              VBox(
                VSpacing(),
                ComboBox(
                  Id(:m_points),
                  Opt(:notify, :hstretch, :editable),
                  # combobox label
                  _("&Mount Point"),
                  m_points
                ),
                #    `VSpacing (0.5),
                #    `Right(
                #        // button label
                #        `PushButton (`id(`test), `opt(`key_F6), _("&Test"))),
                VSpacing(0.5)
              ),
              HSpacing()
            )
          ),
          VSpacing(0.5),
          # frame label
          Frame(
            _("File System Type"),
            HBox(
              HSpacing(),
              VBox(
                VSpacing(0.5),
                ComboBox(
                  Id(:brate),
                  Opt(:notify, :hstretch),
                  # combobox label
                  _("F&ile System to Use:"),
                  f_types
                ),
                VSpacing(0.5)
              ),
              HSpacing()
            )
          ),
          VStretch()
        ),
        HSpacing(3)
      )

      Wizard.SetContentsButtons(
        caption,
        con,
        help,
        Label.BackButton,
        Label.FinishButton
      )

      UI.ChangeWidget(Id(:m_points), :Value, mountpoint)

      #    foreach (symbol widget, [`m_points, `test],{
      #  UI::ChangeWidget (`id (widget), `Enabled, start);
      #    });
      UI.ChangeWidget(Id(:m_points), :Enabled, start)

      UI.ChangeWidget(Id(:brate), :Enabled, start)
      UI.ChangeWidget(Id(:brate), :Value, fstype) if Builtins.contains(f_types, fstype)

      ret = nil
      loop do
        ret = Convert.to_symbol(UI.UserInput)
        mountpoint = Convert.to_string(UI.QueryWidget(Id(:m_points), :Value))
        fstype = Convert.to_string(UI.QueryWidget(Id(:brate), :Value))

        if ret == :yes || ret == :no
          start = ret == :yes
          if start && !Package.InstalledAll(["s390-tools"])
            if Package.InstallAll(["s390-tools"])
              Xpram.ReadSysconfig
              mountpoint = Xpram.mountpoint
              UI.ChangeWidget(Id(:m_points), :Value, mountpoint)
            else
              start = false
              UI.ChangeWidget(Id(:rd), :CurrentButton, :no)
            end
          end
          #      foreach (symbol widget, [`m_points, `test], {
          #    UI::ChangeWidget (`id (widget), `Enabled, start);
          #      });
          UI.ChangeWidget(Id(:m_points), :Enabled, start)
          UI.ChangeWidget(Id(:brate), :Enabled, start)
        end
        #  if (ret == `test)
        #  {
        #      TestPopup (mountpoint);
        #  }
        break if Builtins.contains([:back, :abort, :cancel, :next, :ok], ret)
      end

      if ret == :next &&
          (start != Xpram.start || mountpoint != Xpram.mountpoint ||
            force != Xpram.force ||
            fstype != Xpram.fstype)
        Xpram.modified = true
        Xpram.start = start
        Xpram.mountpoint = mountpoint
        Xpram.fstype = fstype
        Xpram.force = force
      end
      ret
    end

    # Start the main dialog
    # @return [Symbol] XpRAMSequence
    def XpRAMSequence
      Wizard.CreateDialog
      Wizard.SetDesktopIcon("org.opensuse.yast.XPram")

      Xpram.Read

      ret = XpRAMDialog()
      Xpram.Write if ret == :next || ret == :finish

      UI.CloseDialog
      ret
    end
  end
end
