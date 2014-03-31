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

# File:	include/s390/iucvterminal-server/ui.ycp
# Package:	Configuration IUCV Terminal Server
# Summary:	Dialogs definitions
# Authors:	Tim Hardeck <thardeck@suse.de>
#
module Yast
  module S390IucvterminalServerUiInclude
    def initialize_s390_iucvterminal_server_ui(include_target)
      Yast.import "UI"

      textdomain "s390"

      Yast.import "IUCVTerminalServer"
      Yast.import "Label"
      Yast.import "Popup"
      Yast.import "Wizard"
      Yast.import "Integer"
      Yast.import "String"
      Yast.import "Users"

      Yast.include include_target, "s390/iucvterminal-server/helps.rb"

      # Hspacing value between most dialog fields
      @HSPACING = 0.5

      # Vspacing value between most dialog fields
      @VSPACING = 0.3

      # Text to select all
      @TEXT_ALL = IUCVTerminalServer.TEXT_ALL

      # Text approval
      @TEXT_YES = _("Yes")

      # Text disapproval
      @TEXT_NO = _("No")

      # Text for category user
      @TEXT_USER = _("user")

      # Text for category group
      @TEXT_GROUP = _("group")

      # list of all z/VM IDs
      @zvm_id_list = []

      # z/VM ID widget entries (List with TEXT_ALL element)
      @zvm_id_entries = []

      # Current active tab in the main dialog
      @current_main_tab = :t_zvmids

      # Current active dialog
      @current_dialog = :main_window

      # Is TS-Shell activated?
      @ts_enabled = false

      # TS-Shell  password
      @ts_password = ""

      # TS-Shell home directory
      @ts_home = ""

      # Currently selected TS-Shell user/group entry
      @ts_selected_member = ""

      # File/Regex map per TS-Shell user/groups
      # the key of the first map is the user/group name
      # the key of the second map is the selected radio button symbol
      @ts_member_conf = {}

      # List of audited z/VM IDs during TS-Shell sessions
      # item(id, zvmid, activated)
      @ts_audited_ids = []

      # Temporary storage for TS-Shell group items to be able to undo changes
      @ts_groups_items = []

      # Is IUCVConn activated?
      @ic_enabled = false

      # IUCVConn home directory
      @ic_home = ""

      # IUCVConn password
      @ic_password = ""
    end

    # Get a list of local groups without the default users group
    # @return [Hash] of groups
    def GetGroupsWithoutUsers
      groups = IUCVTerminalServer.GetGroups(true)
      groups = Builtins.remove(groups, "users")
      deep_copy(groups)
    end

    # Generates the IUCVConn users table list
    # @return [Array<Yast::Term>] of items
    def GenerateIcUsersTable
      ic_users = IUCVTerminalServer.GetIcUsersList
      ic_items = []
      Builtins.foreach(ic_users) do |username|
        user = Users.GetUserByName(username, "local")
        ic_items = Builtins.add(
          ic_items,
          Item(
            Id(Ops.get(user, "uid")),
            Ops.get_string(user, "uid", ""),
            Ops.get_string(user, "uidNumber", ""),
            Ops.get_string(user, "homeDirectory", ""),
            Ops.get_string(user, "loginShell", "")
          )
        )
      end
      deep_copy(ic_items)
    end

    # Generates the TS-Shell Authorization table (for users and groups)
    # @return [Array<Yast::Term>] of items
    def GenerateTsMembersTable
      ts_users_groups = []
      Builtins.foreach(@ts_member_conf) do |name, conf|
        if Builtins.regexpmatch(name, "^@")
          # remove the leading @
          groupname = Builtins.substring(name, 1)
          group = Users.GetGroupByName(groupname, "local")

          userlist = Builtins.maplist(Ops.get_map(group, "userlist", {})) do |k, v|
            k
          end
          # filter non ts users
          userlist = Builtins.filter(userlist) do |username|
            Builtins.haskey(@ts_member_conf, username)
          end
          group_members = Builtins.mergestring(userlist, ",")

          ts_users_groups = Builtins.add(
            ts_users_groups,
            Item(
              Id(name),
              @TEXT_GROUP,
              groupname,
              Ops.get_string(group, "gidNumber", ""),
              group_members
            )
          )
        else
          user = Users.GetUserByName(name, "local")
          grouplist = Builtins.maplist(Ops.get_map(user, "grouplist", {})) do |k, v|
            k
          end
          groups = Builtins.mergestring(grouplist, ",")
          ts_users_groups = Builtins.add(
            ts_users_groups,
            Item(
              Id(Ops.get(user, "uid")),
              @TEXT_USER,
              Ops.get(user, "uid"),
              Ops.get(user, "uidNumber"),
              groups,
              Ops.get(user, "homeDirectory")
            )
          )
        end
      end

      deep_copy(ts_users_groups)
    end

    def ZvmIdsDialogContent
      content = HBox(
        HSpacing(@HSPACING),
        VBox(
          VSpacing(@VSPACING),
          MultiLineEdit(
            Id(:zvmids),
            Opt(:notify),
            _("z/&VM IDs (auto-sorted)"),
            Builtins.mergestring(@zvm_id_list, "\n")
          ),
          VSpacing(@VSPACING)
        ),
        HSpacing(@HSPACING)
      )
      deep_copy(content)
    end

    def TsShellDialogContent
      content = HBox(
        HSpacing(@HSPACING),
        VBox(
          VSpacing(@VSPACING),
          Left(
            CheckBox(
              Id(:ts_enabled),
              Opt(:notify),
              _("&Enable TS-Shell"),
              @ts_enabled
            )
          ),
          VSpacing(@VSPACING),
          HBox(
            HWeight(
              13,
              Frame(
                Id(:f_ts_configuration),
                _("Authorization"),
                VBox(
                  VSpacing(@VSPACING),
                  HBox(
                    HSpacing(@HSPACING),
                    HWeight(
                      11,
                      VBox(
                        Table(
                          Id(:ts_users_groups),
                          Opt(:notify, :immediate),
                          Header(
                            # table header
                            _("Type"),
                            # table header
                            _("Name"),
                            # table header
                            _("UID/GID"),
                            # table header
                            _("Groups/Members")
                          ),
                          GenerateTsMembersTable()
                        ),
                        HBox(
                          PushButton(Id(:ts_open_user_dialog), _("&New User")),
                          HSpacing(@HSPACING),
                          PushButton(Id(:ts_delete_user), _("&Delete User")),
                          HSpacing(@HSPACING),
                          PushButton(
                            Id(:ts_open_group_dialog),
                            _("&Manage Groups")
                          ),
                          HStretch()
                        )
                      )
                    ),
                    HSpacing(@HSPACING),
                    HWeight(
                      5,
                      Frame(
                        Id(:f_ts_member_conf),
                        _("Allowed z/VM IDs"),
                        HBox(
                          HSpacing(@HSPACING),
                          RadioButtonGroup(
                            Id(:ts_auth_type),
                            VBox(
                              Heading(
                                Id(:ts_label),
                                Opt(:hstretch),
                                @ts_selected_member
                              ),
                              Left(
                                RadioButton(
                                  Id(:rb_ts_list),
                                  Opt(:notify),
                                  _("&Selection"),
                                  Ops.get(
                                    @ts_member_conf,
                                    [@ts_selected_member, :type]
                                  ) == :rb_ts_list
                                )
                              ),
                              # force min size to make it easier readable in terminals
                              MinWidth(
                                14,
                                MultiSelectionBox(
                                  Id(:ts_auth_ids),
                                  Opt(:notify, :vstretch),
                                  "",
                                  @zvm_id_entries
                                )
                              ),
                              Left(
                                RadioButton(
                                  Id(:rb_ts_regex),
                                  Opt(:notify),
                                  _("&Regex"),
                                  Ops.get(
                                    @ts_member_conf,
                                    [@ts_selected_member, :type]
                                  ) == :rb_ts_regex
                                )
                              ),
                              InputField(
                                Id(:ts_auth_regex),
                                Opt(:notify, :hstretch),
                                "",
                                ""
                              ),
                              Left(
                                RadioButton(
                                  Id(:rb_ts_file),
                                  Opt(:notify),
                                  _("&File"),
                                  Ops.get(
                                    @ts_member_conf,
                                    [@ts_selected_member, :type]
                                  ) == :rb_ts_file
                                )
                              ),
                              HBox(
                                InputField(
                                  Id(:ts_auth_file),
                                  Opt(:notify, :hstretch),
                                  "",
                                  ""
                                ),
                                PushButton(
                                  Id(:ts_auth_file_browse),
                                  _("Bro&wse")
                                )
                              ),
                              VSpacing(@VSPACING)
                            )
                          ),
                          HSpacing(@HSPACING)
                        )
                      )
                    ),
                    HSpacing(@HSPACING)
                  ),
                  VSpacing(@VSPACING)
                )
              )
            ),
            HSpacing(@HSPACING),
            HWeight(
              3,
              VBox(
                VSpacing(@VSPACING),
                # force min size to make it easier readable in terminals
                MinWidth(
                  14,
                  MultiSelectionBox(
                    Id(:ts_audited_ids),
                    Opt(:notify),
                    _("&Audited IDs"),
                    @zvm_id_entries
                  )
                ),
                VSpacing(@VSPACING)
              )
            )
          )
        ),
        HSpacing(@HSPACING)
      )
      deep_copy(content)
    end

    def IucvConnDialogContent
      content = HBox(
        HSpacing(@HSPACING),
        VBox(
          VSpacing(@VSPACING),
          CheckBoxFrame(
            Id(:ic_enabled),
            Opt(:notify),
            _("&Enable IUCVConn on Login"),
            @ic_enabled,
            VBox(
              VSpacing(@VSPACING),
              HBox(
                HSpacing(@HSPACING),
                HWeight(
                  5,
                  Table(
                    Id(:ic_users),
                    Opt(:vstretch),
                    Header(
                      # table header
                      _("Login"),
                      # table header
                      _("UID"),
                      # table header
                      _("Home"),
                      # table header
                      _("Shell")
                    ),
                    GenerateIcUsersTable()
                  )
                ),
                HWeight(
                  2,
                  Frame(
                    _("Settings for new Users"),
                    VBox(
                      Top(
                        Password(
                          Id(:ic_pw1),
                          Opt(:notify, :hstretch),
                          _("&Password"),
                          @ic_password
                        )
                      ),
                      VSpacing(@VSPACING),
                      Top(
                        Password(
                          Id(:ic_pw2),
                          Opt(:notify, :hstretch),
                          _("Co&nfirm Password"),
                          @ic_password
                        )
                      ),
                      VSpacing(
                        Ops.multiply(
                          @VSPACING,
                          Convert.convert(2, :from => "integer", :to => "float")
                        )
                      ),
                      Top(
                        VBox(
                          InputField(
                            Id(:ic_home),
                            Opt(:hstretch),
                            _("&Home Directory"),
                            @ic_home
                          ),
                          PushButton(Id(:ic_browse_home), _("B&rowse"))
                        )
                      ),
                      VStretch(),
                      PushButton(Id(:ic_sync), _("&Sync"))
                    )
                  )
                ),
                HSpacing(@HSPACING)
              ),
              VSpacing(@VSPACING)
            )
          ),
          VSpacing(@VSPACING)
        ),
        HSpacing(@HSPACING)
      )

      deep_copy(content)
    end

    def TsUserDialogContent
      # initialize list with additional groups
      groups = Builtins.maplist(GetGroupsWithoutUsers()) { |name, v| name }

      content = HBox(
        HWeight(
          1,
          VBox(
            VSpacing(1),
            Top(
              InputField(Id(:ts_username), Opt(:hstretch), _("&Username"), "")
            ),
            VSpacing(1),
            Top(
              HBox(
                InputField(
                  Id(:ts_home),
                  Opt(:hstretch),
                  _("&Home Directory"),
                  @ts_home
                ),
                HSpacing(@HSPACING),
                PushButton(Id(:ts_browse_home), _("B&rowse"))
              )
            ),
            VSpacing(1),
            Top(
              Password(Id(:ts_pw1), Opt(:notify, :hstretch), _("&Password"), "")
            ),
            Top(
              Password(
                Id(:ts_pw2),
                Opt(:notify, :hstretch),
                _("Co&nfirm Password"),
                ""
              )
            ),
            Top(
              CheckBox(
                Id(:ts_force_pw_change),
                _("&Force Password Change"),
                false
              )
            )
          )
        ),
        HSpacing(2),
        HWeight(
          1,
          VBox(
            VSpacing(1),
            MultiSelectionBox(
              Id(:ts_additional_groups),
              _("&Additonal Groups"),
              groups
            ),
            VSpacing(1)
          )
        )
      )
      deep_copy(content)
    end

    def TsGroupDialogContent
      content = VBox(
        VSpacing(@VSPACING),
        HBox(
          HSpacing(@HSPACING),
          HWeight(
            4,
            VBox(
              Table(
                Id(:ts_table_add_groups),
                Opt(:notify, :immediate),
                Header(
                  # table header
                  _("Name"),
                  # table header
                  _("TS-Auth"),
                  # table header
                  _("GID"),
                  # table header
                  _("TS-Members")
                ),
                []
              ),
              HBox(
                PushButton(Id(:ts_groups_select), _("&Select or Deselect")),
                HStretch(),
                PushButton(Id(:ts_groups_create), _("C&reate")),
                HSpacing(@HSPACING),
                InputField(Id(:ts_groups_name), _("&New Group"), "")
              )
            )
          ),
          HSpacing(@HSPACING),
          HWeight(
            1,
            MultiSelectionBox(
              Id(:ts_groups_members),
              Opt(:notify),
              _("TS-&Members"),
              IUCVTerminalServer.GetTsUsersList
            )
          ),
          HSpacing(@HSPACING)
        )
      )
      deep_copy(content)
    end

    def MainDialogContent
      # draw active tab
      widgets = nil
      if @current_main_tab == :t_zvmids
        widgets = ZvmIdsDialogContent()
      elsif @current_main_tab == :t_tsshell
        widgets = TsShellDialogContent()
      else
        widgets = IucvConnDialogContent()
      end

      contents = VBox(
        DumbTab(
          Id(:tab),
          [
            Item(Id(:t_zvmids), _("&z/VM IDs")),
            Item(Id(:t_tsshell), _("&TS-Shell")),
            Item(Id(:t_iucvconn), _("&IUCVConn"))
          ],
          ReplacePoint(Id(:tab_content), widgets)
        )
      )
      deep_copy(contents)
    end


    # Initializes the main dialogs (zvmid, ts-shell and iucvconn)
    # @param the symbol of the activated tab
    # @return [void]
    def InitMainDialog(tab)
      # remember current tab
      @current_main_tab = tab
      if tab == :t_zvmids
        UI.ChangeWidget(
          Id(:zvmids),
          :Value,
          Builtins.mergestring(@zvm_id_list, "\n")
        )
      elsif tab == :t_tsshell
        # disable frames if TS-Shell is disabled
        HandleEvent(:ts_enabled)

        if @ts_selected_member != ""
          UI.ChangeWidget(
            Id(:ts_users_groups),
            :CurrentItem,
            @ts_selected_member
          )
        end

        # filter not anymore existing entries after the z/VM ids have been updated
        @ts_audited_ids = Builtins.filter(@ts_audited_ids) do |name|
          Builtins.contains(@zvm_id_entries, name)
        end
        UI.ChangeWidget(Id(:ts_audited_ids), :SelectedItems, @ts_audited_ids)
        # mark all if selected and new entries were inserted
        HandleEvent(:ts_audited_ids)

        HandleEvent(
          Ops.get_symbol(@ts_member_conf, [@ts_selected_member, :type])
        )
        HandleEvent(:ts_users_groups)

        # ts_auth_ids has to be behind ts_users_groups otherwise the selection is gone after a tab change
        HandleEvent(:ts_auth_ids)
      end

      nil
    end

    # Initializes the TS-Shell group dialog for managing groups
    # @return [void]
    def InitTsGroupDialog
      items = []

      group_map = GetGroupsWithoutUsers()

      Builtins.foreach(group_map) do |name, group|
        # show if the group is already used for TS-Authentication
        ts_auth_status = @TEXT_YES
        # groups ids start with @
        if !Builtins.haskey(@ts_member_conf, Ops.add("@", name))
          ts_auth_status = @TEXT_NO
        end
        userlist = Builtins.maplist(Ops.get_map(group, "userlist", {})) do |k, v|
          k
        end
        # filter non ts users
        userlist = Builtins.filter(userlist) do |username|
          Builtins.haskey(@ts_member_conf, username)
        end
        # convert group members to a string separated by comma for the table
        group_members = Builtins.mergestring(userlist, ",")
        items = Builtins.add(
          items,
          Item(
            Id(name),
            name,
            ts_auth_status,
            Ops.get(group, "gidNumber"),
            group_members
          )
        )
      end

      # save items for modification check
      @ts_groups_items = deep_copy(items)

      UI.ChangeWidget(Id(:ts_table_add_groups), :Items, items)
      HandleEvent(:ts_table_add_groups)

      nil
    end


    # Checks the input for the new user and creates it if valid
    # @return true if successful
    def CommitTsUserDialogSettings
      username = Builtins.tolower(
        Convert.to_string(UI.QueryWidget(Id(:ts_username), :Value))
      )
      password = Convert.to_string(UI.QueryWidget(Id(:ts_pw1), :Value))
      home = Convert.to_string(UI.QueryWidget(Id(:ts_home), :Value))
      users = IUCVTerminalServer.GetUsers(false)

      # check and commit password

      ret = true

      if @ts_password == ""
        UI.SetFocus(:ts_pw1)
        Popup.Notify(_("The passwords do not match or are invalid."))
        ret = false
      # check if the user specifcation is valid and if the name does already exist
      elsif !IUCVTerminalServer.CheckUserGroupName(username) ||
          Builtins.haskey(users, username)
        UI.SetFocus(:ts_username)
        Popup.Notify(_("The username is not valid!"))
        ret = false
      elsif !Builtins.regexpmatch(home, "^/")
        UI.SetFocus(:ts_home)
        Popup.Notify(_("A home directory has to be specified!"))
        ret = false
      else
        @ts_home = home

        grouplist = Convert.convert(
          UI.QueryWidget(Id(:ts_additional_groups), :SelectedItems),
          :from => "any",
          :to   => "list <string>"
        )
        groups = Builtins.mergestring(grouplist, ",")
        groupmap = Builtins.listmap(grouplist) { |g| { g => "1" } }

        force_pw_change = Convert.to_boolean(
          UI.QueryWidget(Id(:ts_force_pw_change), :Value)
        )

        new_uid = IUCVTerminalServer.AddTsUser(
          username,
          password,
          home,
          groupmap,
          force_pw_change
        )
        if new_uid != ""
          @ts_member_conf = Builtins.add(
            @ts_member_conf,
            username,
            {
              :type        => :rb_ts_list,
              :rb_ts_list  => [],
              :rb_ts_regex => "",
              :rb_ts_file  => ""
            }
          )
        else
          Popup.Notify(_("Adding the user has failed."))
          ret = false
        end
      end
      ret
    end

    # Extracts the groups and settings from the TsGroupTable items and updates the
    # users and groups settings accordingly
    # @return [void]
    def CommitTsGroupDialogSettings
      items = Convert.convert(
        UI.QueryWidget(Id(:ts_table_add_groups), :Items),
        :from => "any",
        :to   => "list <term>"
      )
      groups = IUCVTerminalServer.GetGroups(true)

      Builtins.foreach(items) do |line|
        is_ts_auth_group = Ops.get_string(line, 2, "") == @TEXT_YES
        groupname = Ops.get_string(line, 1, "")
        userlist = Builtins.splitstring(Ops.get_string(line, 4, ""), ",")
        usermap = Builtins.listmap(userlist) { |k| { k => "1" } }
        # if group doesn't exist create it otherwise edit its userlist
        if !Builtins.haskey(groups, groupname)
          group = { "cn" => groupname, "userlist" => usermap }

          error = Users.AddGroup(group)
          if error == ""
            Users.CommitGroup
          else
            Builtins.y2milestone(
              "Adding the group %1 failed because of: %2",
              groupname,
              error
            )
          end
        else
          if Ops.get_map(groups, [groupname, "userlist"], {}) != usermap
            Users.SelectGroupByName(groupname)
            group = Users.GetCurrentGroup

            # filter all TS-Entries from current user list to remove deselected ones
            non_ts_users_list = Builtins.filter(
              Ops.get_map(group, "userlist", {})
            ) do |username, number|
              !Builtins.haskey(@ts_member_conf, username)
            end
            Ops.set(
              group,
              "userlist",
              Builtins.union(non_ts_users_list, usermap)
            )

            changes = { "userlist" => group["userlist"] || [] }
            error = Users.EditGroup(changes)
            if error == ""
              Users.CommitGroup
            else
              Builtins.y2milestone(
                "Editing the group %1 failed because of: %2",
                groupname,
                error
              )
            end
          end
        end
        # groups start with an @
        identification = Ops.add("@", groupname)
        # check if the group should be added and  was not already used for TS auth
        if !Builtins.haskey(@ts_member_conf, identification)
          if is_ts_auth_group
            group_members = Builtins.mergestring(userlist, ",")
            group = Users.GetGroupByName(groupname, "")
            gid = Ops.get_string(group, "gidNumber", "")

            # add ts_member_conf
            @ts_member_conf = Builtins.add(
              @ts_member_conf,
              identification,
              {
                :type        => :rb_ts_list,
                :rb_ts_list  => [],
                :rb_ts_regex => "",
                :rb_ts_file  => ""
              }
            )
          end
        else
          # delete group entry if disabled
          if !is_ts_auth_group
            i = 0
            @ts_member_conf = Builtins.remove(@ts_member_conf, identification)
          end
        end
      end

      nil
    end


    def DrawMainDialog
      Wizard.SetContentsButtons(
        _("Configure IUCV Terminal Server Settings"),
        MainDialogContent(),
        Ops.get_string(@HELP, "zvmids", ""),
        Label.BackButton,
        Label.OKButton
      )
      Wizard.HideBackButton
      Wizard.SetAbortButton(:abort, Label.CancelButton)

      # change tab selection to active tab
      UI.ChangeWidget(Id(:tab), :CurrentItem, @current_main_tab)

      # update screen
      HandleEvent(@current_main_tab)

      nil
    end

    def DrawTsUserDialog
      Wizard.SetContentsButtons(
        _("New TS-Shell User"),
        TsUserDialogContent(),
        Ops.get_string(@HELP, "ts-user", ""),
        Label.BackButton,
        Label.CreateButton
      )
      Wizard.SetAbortButton(:abort, Label.CancelButton)

      nil
    end

    def DrawTsGroupDialog
      Wizard.SetContentsButtons(
        _("Manage Groups for TS-Authorization"),
        TsGroupDialogContent(),
        Ops.get_string(@HELP, "ts-group", ""),
        Label.BackButton,
        Label.OKButton
      )
      Wizard.SetAbortButton(:abort, Label.CancelButton)

      # initialize dialog
      InitTsGroupDialog()

      nil
    end


    # Updates the TS-Shell Group table widget with new items and tries to keep the current selection
    # @param list<term> of table items
    # @return [void]
    def UpdateTsGroupTable(items)
      items = deep_copy(items)
      # save current table position
      ts_group_table_position = Convert.to_string(
        UI.QueryWidget(Id(:ts_table_add_groups), :CurrentItem)
      )

      UI.ChangeWidget(Id(:ts_table_add_groups), :Items, items)

      # change to the old position if possible
      if ts_group_table_position != nil
        UI.ChangeWidget(
          Id(:ts_table_add_groups),
          :CurrentItem,
          ts_group_table_position
        )
      end

      # update the member selection
      HandleEvent(:ts_table_add_groups)

      nil
    end

    # Extracts the TS-Members of the selected groups from the TS-Shell Group Table entries
    # @return [void] list<string> of group members
    def GetTsGroupTableUserList
      # get table items and position
      items = Convert.convert(
        UI.QueryWidget(Id(:ts_table_add_groups), :Items),
        :from => "any",
        :to   => "list <term>"
      )
      current_group = Convert.to_string(
        UI.QueryWidget(Id(:ts_table_add_groups), :CurrentItem)
      )

      # extract current item
      item = Builtins.find(items) do |entry|
        Ops.get(entry, 0) == Id(current_group)
      end

      # create a list with users
      users = Ops.get_string(item, 4, "")
      users_list = Builtins.splitstring(users, ",")

      deep_copy(users_list)
    end

    # Changes the userlist of the TS-Shell Group entry at the current position
    # @param list<string> of members
    # @return [void]
    def SetTSGroupTableUserList(new_list)
      new_list = deep_copy(new_list)
      # get table items and position
      items = Convert.convert(
        UI.QueryWidget(Id(:ts_table_add_groups), :Items),
        :from => "any",
        :to   => "list <term>"
      )
      current_group = Convert.to_string(
        UI.QueryWidget(Id(:ts_table_add_groups), :CurrentItem)
      )

      i = 0
      Builtins.foreach(items) do |entry|
        if Ops.get_string(entry, 1, "") == current_group
          Ops.set(entry, 4, Builtins.mergestring(new_list, ","))
          Ops.set(items, i, entry)
          raise Break
        end
        i = Ops.add(i, 1)
      end

      UpdateTsGroupTable(items)

      nil
    end


    def CheckPassword(field1, field2)
      pw1 = Convert.to_string(UI.QueryWidget(Id(field1), :Value))
      if pw1 != "" &&
          pw1 == Convert.to_string(UI.QueryWidget(Id(field2), :Value))
        return pw1
      else
        return ""
      end
    end

    # Checks if the user specified z/VM ID list is valid and otherwise shows
    # a popup what's incorrect
    # @return [Boolean] true if the list is valid
    def IsValidZvmIdList
      ret = true
      text = Convert.to_string(UI.QueryWidget(Id(:zvmids), :Value))
      zvmid_list = Builtins.splitstring(text, "\n")

      # determine last entry
      lines = Builtins.size(zvmid_list)
      line = 0
      Builtins.foreach(zvmid_list) do |zvmid|
        line = Ops.add(line, 1)
        # since alnum allows umlauts too the id is checked against the user name specification
        if Builtins.regexpmatch(zvmid, "[^[:alnum:]]") ||
            !IUCVTerminalServer.CheckUserGroupName(zvmid) && zvmid != ""
          Popup.Notify(
            Builtins.sformat(
              _(
                "Wrong z/VM ID \"%1\" in line %2, only letters and numbers are allowed."
              ),
              zvmid,
              line
            )
          )
          ret = false
          raise Break
        elsif Builtins.regexpmatch(zvmid, "^[[:digit:]]")
          Popup.Notify(
            Builtins.sformat(
              _(
                "Wrong z/VM ID \"%1\" in line %2, numbers at the beginning are not allowed."
              ),
              zvmid,
              line
            )
          )
          ret = false
          raise Break
        elsif Builtins.regexpmatch(zvmid, "[[:lower:][:digit:]]{9,}")
          Popup.Notify(
            Builtins.sformat(
              _(
                "Wrong z/VM ID \"%1\" in line %2, more than eight characters are not allowed."
              ),
              zvmid,
              line
            )
          )
          ret = false
          raise Break
        # only the last entry is allowed to be empty
        elsif zvmid == "" && line != lines
          Popup.Notify(
            Builtins.sformat(
              _(
                "Wrong z/VM ID \"%1\" in line %2, at least one letter is required."
              ),
              zvmid,
              line
            )
          )
          ret = false
          raise Break
        end
      end
      ret
    end

    # Checks if IUCVConn users have to be synced and if the required information is provided
    # @return [Boolean] true if the list is already synced or was synced
    def SyncIucvConnUsers
      ret = false

      # check if the ic users list is different since the start
      if @zvm_id_list != IUCVTerminalServer.GetIcUsersList
        # check password
        if @ic_password == ""
          Popup.Notify(
            _(
              "A correctly entered password to sync IUCVConn users is required."
            )
          )
        # check home directory
        elsif !Builtins.regexpmatch(@ic_home, "^/")
          Popup.Notify(_("The specified IUCVConn home directory is invalid."))
        else
          IUCVTerminalServer.ic_home = @ic_home
          IUCVTerminalServer.SyncIucvConnUsers(@zvm_id_list, @ic_password)
          UI.ChangeWidget(Id(:ic_users), :Items, GenerateIcUsersTable())
          ret = true
        end
      else
        ret = true
      end
      ret
    end

    # Updates the MultiSelectionBoxes of z/VM IDs according to user interaction to de/select all at once
    # @param list<string> of previous defined ids and the MultiSelectionBox symbol to get the new id selection
    # @return [Array<String>] of items to select
    def UpdateIdSelections(previous_ids, widget)
      previous_ids = deep_copy(previous_ids)
      ids = Convert.convert(
        UI.QueryWidget(Id(widget), :SelectedItems),
        :from => "any",
        :to   => "list <string>"
      )

      # make sure that only available ids are compared
      previous_ids = Builtins.filter(previous_ids) do |name|
        Builtins.contains(@zvm_id_entries, name)
      end

      if previous_ids != ids
        # check if TEXT_ALL was previously selected
        was_all_selected = Ops.get(previous_ids, 0, "") == @TEXT_ALL
        if was_all_selected
          if Ops.get(ids, 0, "") == @TEXT_ALL
            # remove TEXT_ALL entry if something else is deactivated
            ids = Builtins.remove(ids, 0)
          else
            # if TEXT_ALL was explicitly deactivated disable all
            ids = []
          end
        end

        # activate all if selected
        ids = deep_copy(@zvm_id_entries) if Ops.get(ids, 0) == @TEXT_ALL
        UI.ChangeWidget(Id(widget), :SelectedItems, ids)
      else
        # activate all if selected and no user change was committed
        if Ops.get(ids, 0, "") == @TEXT_ALL
          ids = deep_copy(@zvm_id_entries)
          UI.ChangeWidget(Id(widget), :SelectedItems, ids)
        end
      end
      deep_copy(ids)
    end
    def HandleEvent(widget)
      if widget == :ic_enabled
        @ic_enabled = Convert.to_boolean(
          UI.QueryWidget(Id(:ic_enabled), :Value)
        )
      end

      if widget == :ts_enabled
        @ts_enabled = Convert.to_boolean(
          UI.QueryWidget(Id(:ts_enabled), :Value)
        )
        UI.ChangeWidget(Id(:f_ts_configuration), :Enabled, @ts_enabled)
        UI.ChangeWidget(Id(:ts_audited_ids), :Enabled, @ts_enabled)
      end

      if widget == :rb_ts_list || widget == :rb_ts_regex ||
          widget == :rb_ts_file
        if Builtins.haskey(@ts_member_conf, @ts_selected_member)
          Ops.set(@ts_member_conf, [@ts_selected_member, :type], widget)
        end
        UI.ChangeWidget(Id(:ts_auth_ids), :Enabled, widget == :rb_ts_list)
        UI.ChangeWidget(Id(:ts_auth_regex), :Enabled, widget == :rb_ts_regex)
        UI.ChangeWidget(Id(:ts_auth_file), :Enabled, widget == :rb_ts_file)
        UI.ChangeWidget(
          Id(:ts_auth_file_browse),
          :Enabled,
          widget == :rb_ts_file
        )
      end

      if widget == :ts_auth_ids
        Ops.set(
          @ts_member_conf,
          [@ts_selected_member, :rb_ts_list],
          UpdateIdSelections(
            Ops.get_list(
              @ts_member_conf,
              [@ts_selected_member, :rb_ts_list],
              []
            ),
            :ts_auth_ids
          )
        )
      end

      if widget == :ts_audited_ids
        @ts_audited_ids = UpdateIdSelections(@ts_audited_ids, :ts_audited_ids)
      end

      if widget == :ts_auth_regex
        Ops.set(
          @ts_member_conf,
          [@ts_selected_member, :rb_ts_regex],
          Convert.to_string(UI.QueryWidget(Id(:ts_auth_regex), :Value))
        )
      end


      if widget == :ts_users_groups
        ts_isnt_empty = Ops.greater_than(
          Builtins.size(GenerateTsMembersTable()),
          0
        )
        if ts_isnt_empty
          @ts_selected_member = Convert.to_string(
            UI.QueryWidget(Id(:ts_users_groups), :CurrentItem)
          )
        else
          @ts_selected_member = ""
        end

        # show the current selected user
        UI.ChangeWidget(Id(:ts_label), :Value, @ts_selected_member)

        # update selected z/VM IDs
        UI.ChangeWidget(
          Id(:ts_auth_ids),
          :SelectedItems,
          Ops.get_list(@ts_member_conf, [@ts_selected_member, :rb_ts_list], [])
        )

        # select the correct radio box (default is `rb_ts_list)
        UI.ChangeWidget(
          Id(:ts_auth_type),
          :CurrentButton,
          Ops.get_symbol(
            @ts_member_conf,
            [@ts_selected_member, :type],
            :rb_ts_list
          )
        )
        # deactivate the other radio box settings
        HandleEvent(
          Ops.get_symbol(
            @ts_member_conf,
            [@ts_selected_member, :type],
            :rb_ts_list
          )
        )

        # update the regex and file fields
        UI.ChangeWidget(
          Id(:ts_auth_regex),
          :Value,
          Ops.get_string(
            @ts_member_conf,
            [@ts_selected_member, :rb_ts_regex],
            ""
          )
        )
        UI.ChangeWidget(
          Id(:ts_auth_file),
          :Value,
          Ops.get_string(
            @ts_member_conf,
            [@ts_selected_member, :rb_ts_file],
            ""
          )
        )

        # disable the delete users button in case of groups and if the table is empty
        UI.ChangeWidget(
          Id(:ts_delete_user),
          :Enabled,
          ts_isnt_empty && Builtins.regexpmatch(@ts_selected_member, "^[^@]")
        )

        #disable the user configuration dialog in case of an empty table
        UI.ChangeWidget(Id(:f_ts_member_conf), :Enabled, ts_isnt_empty)
      end

      if widget == :ts_delete_user
        # remove user from system
        IUCVTerminalServer.DeleteUser(@ts_selected_member)

        # remove user TS-Shell settings
        @ts_member_conf = Builtins.remove(@ts_member_conf, @ts_selected_member)

        # update table
        UI.ChangeWidget(Id(:ts_users_groups), :Items, GenerateTsMembersTable())
        HandleEvent(:ts_users_groups)
      end

      # select file
      if widget == :ts_auth_file_browse
        # set default directory
        file = Ops.get_string(
          @ts_member_conf,
          [@ts_selected_member, :rb_ts_file],
          "/"
        )
        file = UI.AskForExistingFile(file, "", "Select a file with z/VM IDs")
        if file != nil
          Ops.set(@ts_member_conf, [@ts_selected_member, :rb_ts_file], file)
          UI.ChangeWidget(Id(:ts_auth_file), :Value, file)
        end
      end


      # reset repeated password on change
      UI.ChangeWidget(Id(:ic_pw2), :Value, "") if widget == :ic_pw1

      # check password and update if valid
      @ic_password = CheckPassword(:ic_pw1, :ic_pw2) if widget == :ic_pw2

      # select home directory
      if widget == :ic_browse_home
        # set default directory
        dir = @ic_home != "" ? @ic_home : "/"
        dir = UI.AskForExistingDirectory(dir, "")
        if dir != nil
          @ic_home = dir
          UI.ChangeWidget(Id(:ic_home), :Value, dir)
        end
      end

      SyncIucvConnUsers() if widget == :ic_sync

      # select home directory
      if widget == :ts_browse_home
        # set default directory
        dir = @ts_home != "" ? @ts_home : "/"
        dir = UI.AskForExistingDirectory(dir, "")
        if dir != nil
          @ts_home = dir
          UI.ChangeWidget(Id(:ts_home), :Value, dir)
        end
      end

      if widget == :ts_open_group_dialog
        @current_dialog = widget
        DrawTsGroupDialog()
      end

      if widget == :ts_open_user_dialog
        @current_dialog = widget
        DrawTsUserDialog()
      end

      if widget == :zvmids
        if IsValidZvmIdList()
          # convert to lower case before saving
          zvm_ids_text = Builtins.tolower(
            Convert.to_string(UI.QueryWidget(Id(:zvmids), :Value))
          )
          # remove possible break at the end
          if Builtins.regexpmatch(zvm_ids_text, "\n$")
            zvm_ids_text = Builtins.substring(
              zvm_ids_text,
              0,
              Ops.subtract(Builtins.size(zvm_ids_text), 1)
            )
          end

          id_list = Builtins.splitstring(zvm_ids_text, "\n")
          # remove possible duplicates
          @zvm_id_list = Convert.convert(
            Builtins.union(id_list, id_list),
            :from => "list",
            :to   => "list <string>"
          )
          # sort list
          @zvm_id_list = Builtins.sort(@zvm_id_list)

          # update the zvm_id_entries
          @zvm_id_entries = Convert.convert(
            Builtins.merge([@TEXT_ALL], @zvm_id_list),
            :from => "list",
            :to   => "list <string>"
          )
        else
          # reset list to prevent saving the previous settings
          @zvm_id_list = []
          @zvm_id_entries = [@TEXT_ALL]
        end
      end

      # reset repeated password on change
      UI.ChangeWidget(Id(:ts_pw2), :Value, "") if widget == :ts_pw1

      # check password and update if valid
      @ts_password = CheckPassword(:ts_pw1, :ts_pw2) if widget == :ts_pw2

      # updated group members
      if widget == :ts_table_add_groups
        groups_exist = [] !=
          Convert.convert(
            UI.QueryWidget(Id(:ts_table_add_groups), :Items),
            :from => "any",
            :to   => "list <term>"
          )
        UI.ChangeWidget(Id(:ts_groups_members), :Enabled, groups_exist)
        UI.ChangeWidget(Id(:ts_groups_select), :Enabled, groups_exist)
        if groups_exist
          UI.ChangeWidget(
            Id(:ts_groups_members),
            :SelectedItems,
            GetTsGroupTableUserList()
          )
        end
      end

      if widget == :ts_groups_create
        table_data = Convert.convert(
          UI.QueryWidget(Id(:ts_table_add_groups), :Items),
          :from => "any",
          :to   => "list <term>"
        )
        groupname = Convert.to_string(
          UI.QueryWidget(Id(:ts_groups_name), :Value)
        )

        # gather all groups to check for name overlapses
        groups = IUCVTerminalServer.GetGroups(false)

        # check if the group was already added this session
        is_not_in_list = nil == Builtins.find(table_data) do |line|
          Ops.get(line, 0) == Id(groupname)
        end
        # make sure that that group doesn't already exist and check the specification
        if is_not_in_list && !Builtins.haskey(groups, groupname) &&
            IUCVTerminalServer.CheckUserGroupName(groupname)
          items = Convert.convert(
            UI.QueryWidget(Id(:ts_table_add_groups), :Items),
            :from => "any",
            :to   => "list <term>"
          )

          item = Item(Id(groupname), groupname, @TEXT_YES, "new", "")
          items = Builtins.add(items, item)

          UpdateTsGroupTable(items)
          # update ts member selection
          HandleEvent(:ts_table_add_groups)
        else
          UI.SetFocus(:ts_groups_name)
          Popup.Notify(_("The group name is not valid!"))
        end
      end

      if widget == :ts_groups_select
        items = Convert.convert(
          UI.QueryWidget(Id(:ts_table_add_groups), :Items),
          :from => "any",
          :to   => "list <term>"
        )
        groupname = Convert.to_string(
          UI.QueryWidget(Id(:ts_table_add_groups), :CurrentItem)
        )

        i = 0
        Builtins.foreach(items) do |item|
          if Ops.get_string(item, 1, "") == groupname
            in_list = Ops.get_string(item, 2, "") == @TEXT_YES
            Ops.set(item, 2, in_list ? @TEXT_NO : @TEXT_YES)
            Ops.set(items, i, item)
            raise Break
          end
          i = Ops.add(i, 1)
        end

        UpdateTsGroupTable(items)
      end

      if widget == :ts_groups_members
        user_list = Convert.convert(
          UI.QueryWidget(Id(:ts_groups_members), :SelectedItems),
          :from => "any",
          :to   => "list <string>"
        )
        SetTSGroupTableUserList(user_list)
      end


      # tab handling
      if widget == :t_zvmids
        #SaveSettings( $[ "ID" : widget ] );
        UI.ReplaceWidget(Id(:tab_content), ZvmIdsDialogContent())
        InitMainDialog(widget)
        Wizard.SetHelpText(Ops.get_string(@HELP, "zvmids", ""))
      elsif widget == :t_tsshell || widget == :t_iucvconn
        # deactivate other tabs without  valid z/VM ids
        if Ops.greater_than(Builtins.size(@zvm_id_list), 0)
          if widget == :t_tsshell
            UI.ReplaceWidget(Id(:tab_content), TsShellDialogContent())
            InitMainDialog(widget)
            Wizard.SetHelpText(Ops.get_string(@HELP, "ts", ""))
          elsif widget == :t_iucvconn
            UI.ReplaceWidget(Id(:tab_content), IucvConnDialogContent())
            InitMainDialog(widget)
            Wizard.SetHelpText(Ops.get_string(@HELP, "ic", ""))
          end
        else
          # change tab selection back
          UI.ChangeWidget(Id(:tab), :CurrentItem, :t_zvmids)
          Popup.Notify(
            _("Cannot configure the terminal server without valid z/VM IDs.")
          )
        end
      end

      nil
    end

    # Run the dialog
    # @return [Symbol] last pressed button
    def IUCVTerminalServerDialog
      @zvm_id_list = deep_copy(IUCVTerminalServer.zvm_id_list)
      @ts_home = IUCVTerminalServer.ts_home
      @ts_enabled = IUCVTerminalServer.ts_enabled
      @ts_member_conf = deep_copy(IUCVTerminalServer.ts_member_conf)
      @ts_audited_ids = deep_copy(IUCVTerminalServer.ts_audited_ids)
      @ic_enabled = IUCVTerminalServer.ic_enabled
      @ic_home = IUCVTerminalServer.ic_home

      # initialize z/VM IDs
      @zvm_id_entries = Convert.convert(
        Builtins.merge([@TEXT_ALL], @zvm_id_list),
        :from => "list",
        :to   => "list <string>"
      )

      # initialize screen
      DrawMainDialog()

      ret = nil
      begin
        ret = Convert.to_symbol(UI.UserInput)
        # if ts user/group dialog is active
        if Builtins.contains(
            [:ts_open_user_dialog, :ts_open_group_dialog],
            @current_dialog
          )
          if Builtins.contains([:next, :ok, :finish], ret)
            ret = :again
            success = true
            # check TS-Shell user dialog settings and commit them if valid
            if @current_dialog == :ts_open_user_dialog
              success = CommitTsUserDialogSettings()
            # commit TS-Shell group dialog settings
            elsif @current_dialog == :ts_open_group_dialog
              CommitTsGroupDialogSettings()
            end

            # if successful return to main dialog
            if success
              @current_dialog = :main_window
              DrawMainDialog()
            end
          end

          if Builtins.contains([:abort, :cancel, :back], ret)
            # ask for confirmation if the ts group dialog has changed
            current_items = Convert.convert(
              UI.QueryWidget(Id(:ts_table_add_groups), :Items),
              :from => "any",
              :to   => "list <term>"
            )
            if @current_dialog == :ts_open_group_dialog &&
                @ts_groups_items != current_items &&
                !Popup.ReallyAbort(true)
              ret = :again
              next
            end

            @current_dialog = :main_window
            ret = :again
            DrawMainDialog()
          end
        end

        # run action for current event
        HandleEvent(ret)

        # check for changes on final user actions
        if Builtins.contains([:back, :abort, :cancel, :next, :ok, :finish], ret)
          # check if something was modified
          IUCVTerminalServer.modified = IUCVTerminalServer.zvm_id_list != @zvm_id_list ||
            IUCVTerminalServer.ts_enabled != @ts_enabled ||
            IUCVTerminalServer.ts_home != @ts_home ||
            IUCVTerminalServer.ts_audited_ids != @ts_audited_ids ||
            IUCVTerminalServer.ts_member_conf != @ts_member_conf ||
            IUCVTerminalServer.ic_enabled != @ic_enabled ||
            IUCVTerminalServer.ic_home != @ic_home ||
            Users.Modified

          # if settings were changed don't exit without asking
          if Builtins.contains([:abort, :cancel], ret) &&
              IUCVTerminalServer.modified &&
              !Popup.ReallyAbort(true)
            ret = :again
          end

          if Builtins.contains([:next, :ok, :finish], ret)
            # check for z/VM ID entries
            if Builtins.size(@zvm_id_list) == 0
              Popup.Notify(
                _(
                  "Cannot configure the terminal server without valid z/VM IDs."
                )
              )
              ret = :again
              next
            # don't quit without syncronisation if iucvconn is enabled
            elsif @ic_enabled && !SyncIucvConnUsers()
              ret = :again
              next
            end
          end
        end
      end while !Builtins.contains([:back, :abort, :cancel, :next, :ok, :finish], ret)


      # commit changes
      if IUCVTerminalServer.modified &&
          (ret == :next || ret == :ok || ret == :finish)
        # check if the TS-Shell status has changed
        IUCVTerminalServer.ts_has_status_changed = IUCVTerminalServer.ts_enabled != @ts_enabled

        IUCVTerminalServer.zvm_id_list = deep_copy(@zvm_id_list)
        IUCVTerminalServer.ts_enabled = @ts_enabled
        IUCVTerminalServer.ts_home = @ts_home
        IUCVTerminalServer.ts_audited_ids = deep_copy(@ts_audited_ids)
        IUCVTerminalServer.ts_member_conf = deep_copy(@ts_member_conf)
        IUCVTerminalServer.ic_enabled = @ic_enabled
        IUCVTerminalServer.ic_home = @ic_home

        #remove remaining IUCVConn users if disabled
        if !@ic_enabled && IUCVTerminalServer.GetIcUsersList != []
          IUCVTerminalServer.SyncIucvConnUsers([], "")
        end
      end
      ret
    end

    # The whole sequence
    # @return sequence result
    def IUCVTerminalServerSequence
      ret = nil
      Wizard.CreateDialog
      Wizard.SetDesktopIcon("iucvterminal-server")
      IUCVTerminalServer.Read
      ret = IUCVTerminalServerDialog()
      # only write during
      IUCVTerminalServer.Write if ret == :next || ret == :finish || ret == :ok
      UI.CloseDialog

      ret
    end
  end
end
