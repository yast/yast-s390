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

# File:	modules/IUCVTerminalServer.ycp
# Package:	Configuration IUCV Terminal Server
# Summary:	IUCV Terminal Server settings, input and output functions
# Authors:	Tim Hardeck <thardeck@suse.de>
#
require "yast"

module Yast
  class IUCVTerminalServerClass < Module
    def main
      textdomain "s390"

      Yast.import "FileUtils"
      Yast.import "Report"
      Yast.import "String"
      Yast.import "Progress"
      Yast.import "Integer"
      Yast.import "Popup"
      Yast.import "Users"

      # Text to select all
      @TEXT_ALL = _("<ALL>")

      # Path of the TS-Shell
      @TSSHELL_SHELL = "/usr/bin/ts-shell"

      # Path of the IUCVConn shell
      @IUCVCONN_SHELL = "/usr/bin/iucvconn_on_login"

      # Data was modified?
      @modified = false

      # List of zvmids
      @zvm_id_list = []

      # Is TS-Shell enabled?
      @ts_enabled = false

      # TS-Shell Home Directory
      @ts_home = "/home/tsshell"

      # List of audited tsshell ids
      @ts_audited_ids = []

      # Did the TS-Shell status change (from off to on or vice versa)
      @ts_has_status_changed = false

      # List/Regex/file map per TS-Shell user/group
      # the key of the first map is the user/group name
      # the key of the second map is the selected radio button symbol
      @ts_member_conf = {}

      # Map of the loaded ts-authorization.conf settings (for saving purposes)
      @ts_authorization_map = {}

      # Is IUCVConn enabled?
      @ic_enabled = false

      # IUCVConn Home Directory
      @ic_home = "/home/iucvconn"
    end

    def CheckUserGroupName(name)
      Builtins.regexpmatch(
        name,
        "^[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_][ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.-]*[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.$-]?$"
      )
    end

    # GetUsers
    # @param [Boolean] local (only local users?)
    # @return [Hash] of users
    def GetUsers(local)
      users = Convert.convert(
        Users.GetUsers("uid", "local"),
        from: "map",
        to: "map <string, map>"
      )
      if !local
        users = Convert.convert(
          Builtins.union(users, Users.GetUsers("uid", "system")),
          from: "map",
          to: "map <string, map>"
        )
      end
      deep_copy(users)
    end

    # GetGroups
    # @param [Boolean] local (only local groups?)
    # @return [Hash] of groups
    def GetGroups(local)
      groups = Convert.convert(
        Users.GetGroups("cn", "local"),
        from: "map",
        to: "map <string, map>"
      )
      if !local
        groups = Convert.convert(
          Builtins.union(groups, Users.GetGroups("cn", "system")),
          from: "map",
          to: "map <string, map>"
        )
      end
      deep_copy(groups)
    end

    # Delete users
    # @param [String] username
    # @return [Boolean] true if deletion was successful
    def DeleteUser(username)
      Users.SelectUserByName(username)
      # don't remove home since we only have one for all
      ret = Users.DeleteUser(false)
      Users.CommitUser
      ret
    end

    # Gather all users which have TS-Shell as their shell
    # @return [Array] of usernames
    def GetTsUsersList
      ts_users = []
      local_users = GetUsers(true)
      Builtins.foreach(local_users) do |username, user|
        if Ops.get(user, "loginShell") == @TSSHELL_SHELL
          ts_users = Builtins.add(ts_users, username)
        end
      end
      deep_copy(ts_users)
    end

    # Gather all users which have TS-Shell as their shell
    # @return [Array] of usernames
    def GetIcUsersList
      ic_users = []
      local_users = GetUsers(true)
      Builtins.foreach(local_users) do |username, user|
        if Ops.get(user, "loginShell") == @IUCVCONN_SHELL
          ic_users = Builtins.add(ic_users, username)
        end
      end
      deep_copy(ic_users)
    end

    # Abstract add a new user function
    # @parm string username, string password, string group_id, string home, string shell,  map<string, string> additional_groups ($[user : "1", user2 : "1" ...]
    # @return the new user id as a string
    def AddUser(username, password, group_id, home, shell, additional_groups, force_pw_change)
      additional_groups = deep_copy(additional_groups)
      new_userid = ""

      # create home directory if it doesn't exist
      create_home = !FileUtils.IsDirectory(home)

      # make sure that the user doesn't already exist
      users = GetUsers(false)

      if !Builtins.haskey(users, username)
        user = {
          "uid"           => username,
          "loginShell"    => shell,
          "homeDirectory" => home,
          "userPassword"  => password,
          "create_home"   => create_home,
          "chown_home"    => false,
          "grouplist"     => additional_groups
        }
        # only change the default group id if defined
        user = Builtins.add(user, "gidNumber", group_id) if group_id != ""
        user = Builtins.add(user, "shadowLastChange", "0") if force_pw_change

        error = Users.AddUser(user)
        # if adding successfull
        if error == ""
          Users.CommitUser

          # get uid of the new user
          user2 = Users.GetUserByName(username, "")
          new_userid = Ops.get_string(user2, "uidNumber", "0")
        else
          Builtins.y2milestone(
            "Adding user %1 failed with the error: %2",
            username,
            error
          )
        end
      else
        Builtins.y2milestone("The user %1 does already exist.", username)
      end
      new_userid
    end

    # Sync z/VM ids with the user accounts
    # @parm list of z/VM ids and the default IC password
    # @return [void]
    def SyncIucvConnUsers(zvmid_list, ic_password)
      zvmid_list = deep_copy(zvmid_list)
      Builtins.y2milestone("Syncing IUCVConn users.")

      ic_users = GetIcUsersList()

      # delete obsolete users
      obsolete_users = Builtins.filter(ic_users) do |user|
        !Builtins.contains(zvmid_list, user)
      end
      Builtins.foreach(obsolete_users) do |user|
        Builtins.y2milestone("Delete obsolete IUCVConn user %1", user)
        DeleteUser(user)
      end

      # add missing users
      users_to_add = Builtins.filter(zvmid_list) do |user|
        !Builtins.contains(ic_users, user)
      end
      Builtins.foreach(users_to_add) do |user|
        Builtins.y2milestone("Add missing IUCVConn user %1", user)
        AddUser(user, ic_password, "", @ic_home, @IUCVCONN_SHELL, {}, false)
      end

      nil
    end

    # Add a new TS-Shell user
    # @parm string username, string password, string home, map<string, string> additional_groups ($[user : "1", user2 : "1" ...]
    # @return the new user id as a string
    def AddTsUser(username, password, home, additional_groups, force_pw_change)
      additional_groups = deep_copy(additional_groups)
      Builtins.y2milestone("Adding TS-Shell user %1.", username)
      # get TS-Shell group id
      group = Users.GetGroupByName("ts-shell", "system")
      group_id = Ops.get_string(group, "gidNumber", "")

      new_uid = AddUser(
        username,
        password,
        group_id,
        home,
        @TSSHELL_SHELL,
        additional_groups,
        force_pw_change
      )

      new_uid
    end

    # Update a configuration entry for TS-Shell users and configured groups
    # @param [String] name of the entry (groups start with an "@"); value
    # @return [void]
    def UpdateTsMemberConfig(name, value)
      # if entry doesn't exist create it
      if !Builtins.haskey(@ts_member_conf, name)
        @ts_member_conf = Builtins.add(
          @ts_member_conf,
          name,
          {
            type: :rb_ts_list,
            rb_ts_list: [],
            rb_ts_regex: "",
            rb_ts_file: ""
          }
        )
      end

      # update entries
      if Builtins.regexpmatch(value, "^list:")
        # remove leading "list:"
        value = Builtins.substring(value, 5)

        loaded_ids = Builtins.splitstring(value, ",")
        # filter unknown z/VM IDs
        loaded_ids = Builtins.filter(loaded_ids) do |name2|
          Builtins.contains(@zvm_id_list, name2)
        end

        Ops.set(@ts_member_conf, [name, :rb_ts_list], loaded_ids)
        Ops.set(@ts_member_conf, [name, :type], :rb_ts_list)
      elsif Builtins.regexpmatch(value, "^regex:")
        value = Builtins.substring(value, 6)
        Ops.set(@ts_member_conf, [name, :rb_ts_regex], value)
        Ops.set(@ts_member_conf, [name, :type], :rb_ts_regex)
      elsif Builtins.regexpmatch(value, "^file:")
        value = Builtins.substring(value, 5)
        Ops.set(@ts_member_conf, [name, :rb_ts_file], value)
        Ops.set(@ts_member_conf, [name, :type], :rb_ts_file)
      end

      nil
    end

    # Read all settings
    # @return true on success
    def Read
      caption = _("Loading IUCV Terminal Server Configuration")
      steps = 2

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/2
          _("Read configuration files"),
          # Progress stage 2/2
          _("Load user/group settings")
        ],
        [
          # Progress step 1/2
          _("Reading configuration files..."),
          # Progress step 2/2
          _("Loading user/group settings..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      Progress.NextStage
      Builtins.y2milestone("Reading user and group entries.")
      old_progress = Progress.set(false)
      # read global user and group entries
      Users.Read
      Progress.set(old_progress)

      # initialize tsshell user list
      ts_users = GetTsUsersList()
      Builtins.foreach(ts_users) do |username|
        UpdateTsMemberConfig(username, "")
      end

      # Load settings
      Progress.NextStage
      filename = "/etc/sysconfig/iucv_terminal_server"
      if FileUtils.Exists(filename)
        Builtins.y2milestone(
          "Reading configuration from sysconfig %1.",
          filename
        )
        zvm_ids = Convert.to_string(
          SCR.Read(path(".sysconfig.iucv_terminal_server.ZVM_IDS"))
        )
        @zvm_id_list = Builtins.splitstring(zvm_ids, " ") if zvm_ids != nil

        @ts_enabled = "true" ==
          Convert.to_string(
            SCR.Read(path(".sysconfig.iucv_terminal_server.ENABLE_TSSHELL"))
          )
        home = Convert.to_string(
          SCR.Read(path(".sysconfig.iucv_terminal_server.TSSHELL_HOME"))
        )
        # use default if not set
        @ts_home = home if home != nil

        @ic_enabled = "true" ==
          Convert.to_string(
            SCR.Read(path(".sysconfig.iucv_terminal_server.ENABLE_IUCVCONN"))
          )
        home = Convert.to_string(
          SCR.Read(path(".sysconfig.iucv_terminal_server.IUCVCONN_HOME"))
        )
        # user default if not set
        @ic_home = home if home != nil
      end

      filename = "/etc/iucvterm/ts-audit-systems.conf"
      if FileUtils.Exists(filename)
        Builtins.y2milestone("Reading configuration from %1.", filename)
        original_ts_audited_ids = Builtins.splitstring(
          Convert.to_string(SCR.Read(path(".target.string"), filename)),
          "\n"
        )
        if Builtins.contains(original_ts_audited_ids, "[*ALL*]")
          # add all if configured
          @ts_audited_ids = Convert.convert(
            Builtins.merge([@TEXT_ALL], @zvm_id_list),
            from: "list",
            to: "list <string>"
          )
        else
          # only add known ids
          @ts_audited_ids = Builtins.filter(original_ts_audited_ids) do |name|
            !Builtins.contains(@zvm_id_list, name)
          end
        end
      end

      filename = "/etc/iucvterm/ts-authorization.conf"
      if FileUtils.Exists(filename)
        Builtins.y2milestone("Reading configuration from %1.", filename)
        # the settings map is globally kept for saving purposes
        @ts_authorization_map = Convert.convert(
          SCR.Read(path(".etc.iucvterm-ts-authorization.all")),
          from: "any",
          to: "map <string, any>"
        )
        ts_auth_list = Ops.get_list(@ts_authorization_map, "value", [])
        Builtins.foreach(ts_auth_list) do |entry|
          name = Ops.get_string(entry, "name", "")
          value = Ops.get_string(entry, "value", "")
          if CheckUserGroupName(name)
            # user entry
            UpdateTsMemberConfig(name, value)
          elsif Builtins.regexpmatch(name, "^@")
            # group entry
            groups = GetGroups(true)
            # remove "@" from the name for the group check
            groupname = Builtins.substring(name, 1)
            if Builtins.haskey(groups, groupname)
              UpdateTsMemberConfig(name, value)
            else
              Builtins.y2milestone(
                "The in %1 mentioned group %2 isn't available on this system.",
                filename,
                groupname
              )
            end
          else
            Builtins.y2milestone(
              "Incompatible configuration entry %1 in file %2",
              name,
              filename
            )
          end
        end
      end
      test = []

      Progress.NextStage
      true
    end

    # Write all settings
    # @return true on success
    def Write
      # no need to write anything if unmodified
      return true if !@modified

      caption = _("Saving IUCV Terminal Server Configuration")
      steps = 2

      Progress.New(
        caption,
        " ",
        steps,
        [
          # Progress stage 1/2
          _("Write configuration files"),
          # Progress stage 2/2
          _("Update user settings")
        ],
        [
          # Progress step 1/2
          _("Writing configuration files..."),
          # Progress step 2/2
          _("Updating user settings..."),
          # Progress finished
          _("Finished")
        ],
        ""
      )

      # save IUCVtty settings
      Progress.NextStage

      Builtins.y2milestone("Writing configuration to sysconfig.")
      # save z/VM IDs separated by spaces
      SCR.Write(
        path(".sysconfig.iucv_terminal_server.ZVM_IDS"),
        Builtins.mergestring(@zvm_id_list, " ")
      )
      SCR.Write(
        path(".sysconfig.iucv_terminal_server.ENABLE_IUCVCONN"),
        Builtins.tostring(@ic_enabled)
      )
      SCR.Write(path(".sysconfig.iucv_terminal_server.IUCVCONN_HOME"), @ic_home)
      SCR.Write(
        path(".sysconfig.iucv_terminal_server.ENABLE_TSSHELL"),
        Builtins.tostring(@ts_enabled)
      )
      SCR.Write(path(".sysconfig.iucv_terminal_server.TSSHELL_HOME"), @ts_home)
      SCR.Write(path(".sysconfig.iucv_terminal_server"), nil)

      filename = "/etc/iucvterm/ts-audit-systems.conf"
      Builtins.y2milestone("Writing configuration to %1.", filename)
      if Ops.get(@ts_audited_ids, 0) == @TEXT_ALL
        SCR.Write(path(".target.string"), filename, "[*ALL*]")
      else
        # save audited IDs separated by breaks
        SCR.Write(
          path(".target.string"),
          filename,
          Builtins.mergestring(@ts_audited_ids, "\n")
        )
      end

      filename = "/etc/iucvterm/ts-authorization.conf"
      Builtins.y2milestone("Writing configuration to %1.", filename)
      # convert the autorization settings to the output format
      ts_auth_values = {}
      Builtins.foreach(@ts_member_conf) do |name, entries|
        value = ""
        type = Ops.get_symbol(entries, :type)
        # Manual selection
        if type == :rb_ts_list
          selected_ids = Ops.get_list(entries, type, [])
          # remove the TEXT_ALL entry because it is not supported by the configuration
          if Ops.get(selected_ids, 0, "") == @TEXT_ALL
            selected_ids = Builtins.remove(selected_ids, 0)
          end
          value = Ops.add("list:", Builtins.mergestring(selected_ids, ","))
        # Regex
        elsif type == :rb_ts_regex
          value = Ops.add("regex:", Ops.get_string(entries, type, ""))
        # File
        elsif type == :rb_ts_file
          value = Ops.add("file:", Ops.get_string(entries, type, ""))
        end
        # ignore empty entries(like "list:" or "regex:")
        if !Builtins.regexpmatch(value, "^[[:lower:]]{4,5}:$")
          ts_auth_values = Builtins.add(ts_auth_values, name, value)
        end
      end

      # update the original configuration file map with the new values
      ts_auth_list = Ops.get_list(@ts_authorization_map, "value", [])
      counter = 0
      Builtins.foreach(ts_auth_list) do |entry|
        name = Ops.get_string(entry, "name", "")
        # update the configuration entry if known otherwise delete it
        if Builtins.haskey(ts_auth_values, name)
          Ops.set(entry, "value", Ops.get(ts_auth_values, name))
          Ops.set(ts_auth_list, counter, entry)
          counter = Ops.add(counter, 1)

          # remove already added ts_auth_values
          ts_auth_values = Builtins.remove(ts_auth_values, name)
        else
          ts_auth_list = Builtins.remove(ts_auth_list, counter)
        end
      end

      # add missing entries
      Builtins.foreach(ts_auth_values) do |name, value|
        new_map = {
          "kind"    => "value",
          "name"    => name,
          "type"    => 0, # value_type
          "comment" => "",
          "value"   => value
        }
        ts_auth_list = Builtins.add(ts_auth_list, new_map)
      end

      # update list of the originally loaded map
      Ops.set(@ts_authorization_map, "value", ts_auth_list)

      # write the updated settings map to file
      SCR.Write(
        path(".etc.iucvterm-ts-authorization.all"),
        @ts_authorization_map
      )
      SCR.Write(path(".etc.iucvterm-ts-authorization"), nil)

      Progress.NextStage
      if Users.Modified
        Builtins.y2milestone("Saving users and groups.")
        # disable Users progress bar
        old_progress = Progress.set(false)
        error = Users.Write
        Progress.set(old_progress)
        if error != ""
          Builtins.y2milestone(
            "Writing user settings failed because of: %1",
            error
          )
          Popup.Notify(error)
        end
      end

      # dis/enable TS-Users if the TS status had changed
      if @ts_has_status_changed
        Builtins.y2milestone("Dis/enabling TS-Shell users.")
        passwd = @ts_enabled ?
          "/usr/bin/passwd -u " : # unlock user
          "/usr/bin/passwd -l " # lock user
        Builtins.foreach(@ts_member_conf) do |name, _entries|
          # groups don't need to be disabled
          if !Builtins.regexpmatch(name, "^@")
            cmd = Ops.add(passwd, name)
            Builtins.y2milestone("Running command %1", cmd)
            output = Convert.to_map(
              SCR.Execute(path(".target.bash_output"), cmd)
            )
            Builtins.y2milestone(
              "Passwd exit code: %1 stdout: %2 stderr: %3",
              Ops.get_integer(output, "exit", 0),
              Ops.get_string(output, "stdout", ""),
              Ops.get_string(output, "stderr", "")
            )
          end
        end
      end

      Progress.NextStage
      true
    end

    publish variable: :TEXT_ALL, type: "const string"
    publish variable: :modified, type: "boolean"
    publish variable: :zvm_id_list, type: "list <string>"
    publish variable: :ts_enabled, type: "boolean"
    publish variable: :ts_home, type: "string"
    publish variable: :ts_audited_ids, type: "list <string>"
    publish variable: :ts_has_status_changed, type: "boolean"
    publish variable: :ts_member_conf, type: "map <string, map <symbol, any>>"
    publish variable: :ic_enabled, type: "boolean"
    publish variable: :ic_home, type: "string"
    publish function: :CheckUserGroupName, type: "boolean (string)"
    publish function: :GetUsers, type: "map <string, map> (boolean)"
    publish function: :GetGroups, type: "map <string, map> (boolean)"
    publish function: :DeleteUser, type: "boolean (string)"
    publish function: :GetTsUsersList, type: "list <string> ()"
    publish function: :GetIcUsersList, type: "list <string> ()"
    publish function: :SyncIucvConnUsers, type: "void (list <string>, string)"
    publish function: :AddTsUser, type: "string (string, string, string, map <string, string>, boolean)"
    publish function: :Read, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
  end

  IUCVTerminalServer = IUCVTerminalServerClass.new
  IUCVTerminalServer.main
end
