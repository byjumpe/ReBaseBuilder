#pragma semicolon 1

#include <amxmodx>
#include <re_basebuilder>

#define ACCESS_FLAG     ADMIN_BAN   // Флаг для бана строительства

new Trie:g_BuildBans;

public plugin_precache() {
    register_plugin("[ReBB] Admin", "0.0.3 Alpha", "ReBB");

    if(!rebb_core_is_running()) {
        rebb_log(PluginPause, "Core of mod is not running! No further work with plugin possible!");
    }
}

public plugin_init() {
    register_clcmd("rebb_ban", "BanBuildCmd", ACCESS_FLAG, "Ban Build");
    
    g_BuildBans = TrieCreate();
}

public BanBuildCmd(id, flags) {
    if(~get_user_flags(id) & flags) {
        console_print(id, "* Insufficient permissions to use this command!");
        return PLUGIN_HANDLED;
    }

    new target;
    get_user_aiming(id, target);

    if(!is_user_connected(target)) {
        return PLUGIN_HANDLED;
    }

    new admin_authid[MAX_AUTHID_LENGTH], player_authid[MAX_AUTHID_LENGTH];
    get_user_authid(id, admin_authid, charsmax(admin_authid));
    get_user_authid(target, player_authid, charsmax(player_authid));
    
    if(TrieKeyExists(g_BuildBans, player_authid)) {
        TrieDeleteKey(g_BuildBans, player_authid);
        client_print_color(0, print_team_default, "%L", LANG_PLAYER, "REBB_UNBAN_BUILD", id, target);
        rebb_log(PluginStateIgnore, "Admin %n [%s] unban to build the %n [%s]", id, admin_authid, target, player_authid);
    } else {
        if(rebb_get_owned_ent(target)) {
            rebb_grab_stop(target);
        }

        TrieSetCell(g_BuildBans, player_authid, 1);
        client_print_color(0, print_team_default, "%L", LANG_PLAYER, "REBB_BAN_BUILD", id, target);
        rebb_log(PluginStateIgnore, "Admin %n [%s] ban to build the %n [%s]", id, admin_authid, target, player_authid);
    }

    return PLUGIN_HANDLED;
}

public rebb_grab_block(id) {
    new authid[MAX_AUTHID_LENGTH];
    get_user_authid(id, authid, charsmax(authid));

    if(TrieKeyExists(g_BuildBans, authid)) {
        client_print_color(id, print_team_default, "%L", LANG_PLAYER, "REBB_PLAYER_BAN_BUILD");
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}
