#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <re_basebuilder>

// Флаг для бана строительства
#define BAN_BUILD             ADMIN_BAN

new Trie:g_tSaveBanBuild;

new const PLUGIN[] = "[ReBB] Lock Blocks";
new const VERSION[] = "0.0.1 Alpha";

public plugin_init() {
    register_plugin(PLUGIN, VERSION, "ReBB");
/*
    if(!rebb_core_is_running()) {
        set_fail_state("Core of mod is not running! No further work with plugin possible!");
    }
*/
    register_clcmd("rebb_ban", "BanBuildCmd", 0, "Ban Build");
    
    g_tSaveBanBuild = TrieCreate();
}

public BanBuildCmd(id){
    if(!access(id, BAN_BUILD)) {
        return PLUGIN_HANDLED;
    }

    new iPlayer, iBody;
    get_user_aiming(id, iPlayer, iBody);

    if(!is_user_connected(iPlayer)){
        return PLUGIN_HANDLED;
    }

    new szAuthIDAdmin[MAX_AUTHID_LENGTH], szAuthID[MAX_AUTHID_LENGTH];
    get_user_authid(id, szAuthIDAdmin, charsmax(szAuthIDAdmin));
    get_user_authid(iPlayer, szAuthID, charsmax(szAuthID));
    
    if(TrieKeyExists(g_tSaveBanBuild, szAuthID)) {
        TrieDeleteKey(g_tSaveBanBuild, szAuthID);
        client_print_color(0, print_team_default, "%L", LANG_PLAYER, "REBB_UNBAN_BUILD", id, iPlayer);
        log_rebb(PLUGIN, fmt("Admin %n [%s] unban to build the %n [%s]", id, szAuthIDAdmin, iPlayer, szAuthID));
    }
    else {
        if(rebb_get_owned_ent(iPlayer)) {
            rebb_grab_stop(iPlayer);
        }
        TrieSetCell(g_tSaveBanBuild, szAuthID, 1);
        client_print_color(0, print_team_default, "%L", LANG_PLAYER, "REBB_BAN_BUILD", id, iPlayer);
        log_rebb(PLUGIN, fmt("Admin %n [%s] ban to build the %n [%s]", id, szAuthIDAdmin, iPlayer, szAuthID));
    }
    return PLUGIN_HANDLED;
}

public rebb_grab_block(id) {
    new szAuthID[MAX_AUTHID_LENGTH];
    get_user_authid(id, szAuthID, charsmax(szAuthID));

    if(TrieKeyExists(g_tSaveBanBuild, szAuthID)) {
        client_print_color(id, print_team_default, "%L", LANG_PLAYER, "REBB_PLAYER_BAN_BUILD");
        return PLUGIN_HANDLED;
    }
    return PLUGIN_CONTINUE;
}

public plugin_end() {
    TrieDestroy(g_tSaveBanBuild);
}
