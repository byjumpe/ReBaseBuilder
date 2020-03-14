#pragma semicolon 1

#include <amxmodx>
#include <fakemeta>
#include <re_basebuilder>

new const VERSION[] = "0.0.2 Alpha";

new g_iShowHudMovers, g_FWShowHudMovers, g_HudShowMovers, g_BarrierEnt;

public plugin_init() {
    register_plugin("[ReBB] Hud Movers", VERSION, "ReBB");

    if(!rebb_core_is_running()) {
        set_fail_state("Core of mod is not running! No further work with plugin possible!");
    }

    bind_pcvar_num(
            create_cvar(
            .name = "rebb_show_hud_movers",
            .string = "1",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_SHOW_HUD_MOVERS")
        ), g_iShowHudMovers
    );

    g_HudShowMovers = CreateHudSyncObj();
    g_BarrierEnt = rebb_barrier_ent();
}

public rebb_build_start() {
    if(g_iShowHudMovers && g_FWShowHudMovers == 0) {
        g_FWShowHudMovers = register_forward(FM_TraceLine, "FW_Traceline", 1);
    }
}

public rebb_preparation_start() {
    if(g_FWShowHudMovers != 0) {
        unregister_forward(FM_TraceLine, g_FWShowHudMovers);
    }
}

public FW_Traceline(Float:start[3], Float:end[3], conditions, id, trace) {
    if(!is_user_alive(id) || is_user_zombie(id)) {
        return PLUGIN_HANDLED;
    }

    new iEnt = get_tr2(trace, TR_pHit);
    if(!is_entity(iEnt)) {
        ClearSyncHud(id, g_HudShowMovers);
        return PLUGIN_HANDLED;
    }

    new /*iEnt, */iBody;
    get_user_aiming(id, iEnt, iBody);
        
    new szTarget[7];
    get_entvar(iEnt, var_targetname, szTarget, charsmax(szTarget));
    if(FClassnameIs(iEnt, "func_wall") && !equal(szTarget, "ignore") && iEnt != g_BarrierEnt && g_iShowHudMovers) {
        if(rebb_is_building_phase()) {
            set_hudmessage(0, 50, 255, -1.0, 0.55, 1, 0.01, 3.0, 0.01, 0.01);
            
            if(!BlockLocker(iEnt)) {
                if(GetEntMover(iEnt)) {
                    if(!GetLastMover(iEnt)) {
                        ShowSyncHudMsg(id, g_HudShowMovers, "%L", LANG_PLAYER, "REBB_HUD_GET_MOVER", GetEntMover(iEnt));
                    }
                }
                
                if(GetLastMover(iEnt)) {
                    if(!GetEntMover(iEnt)) {
                        ShowSyncHudMsg(id, g_HudShowMovers, "%L", LANG_PLAYER, "REBB_HUD_GET_LAST_MOVER", GetLastMover(iEnt));
                    }
                }

                if(GetEntMover(iEnt) && GetLastMover(iEnt)) {
                    ShowSyncHudMsg(id, g_HudShowMovers, "%L", LANG_PLAYER, "REBB_HUD_GET_MOVER_AND_LAST_MOVER", GetEntMover(iEnt), GetLastMover(iEnt));
                } else if(!GetEntMover(iEnt) && !GetLastMover(iEnt)) {
                    ShowSyncHudMsg(id, g_HudShowMovers, "%L", LANG_PLAYER, "REBB_HUD_BLOCK_NOT_MOVE");
                }
            } else {
                ShowSyncHudMsg(id, g_HudShowMovers, "%L", LANG_PLAYER, "REBB_HUD_BLOCK_OWNER", BlockLocker(iEnt));
            }
        }
    }

    return PLUGIN_HANDLED;
}
