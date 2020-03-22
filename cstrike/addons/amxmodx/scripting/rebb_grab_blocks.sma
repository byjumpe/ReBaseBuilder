#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>
#include <re_basebuilder>

const Float:MAX_MOVE_DISTANCE = 768.0;
const Float:MIN_MOVE_DISTANCE = 32.0;
const Float:MIN_DIST_SET = 64.0;

const Float:OBJECT_PUSHPULLRATE     = 4.0;

enum any:POS { Float:X, Float:Y, Float:Z };

enum FORWARDS_LIST {
    FWD_PUSH_PULL,
    FWD_GRAB_ENTITY,
    FWD_GRAB_ENTITY_PRE,
    FWD_GRAB_ENTITY_POST,
    FWD_DROP_ENTITY_PRE,
    FWD_DROP_ENTITY_POST
};

new g_Forward[FORWARDS_LIST];
new g_iResetEnt, g_iLockBlocks, g_BarrierEnt, g_iOwnedEnt[MAX_PLAYERS +1];
new Float:g_fEntDist[MAX_PLAYERS +1];
new Float:g_fOffset1[MAX_PLAYERS +1], Float:g_fOffset2[MAX_PLAYERS +1], Float:g_fOffset3[MAX_PLAYERS +1];

new HookChain:g_hPreThink;

public plugin_precache() {
    register_plugin("[ReBB] Grab Blocks", "0.0.5 Alpha", "ReBB");

    if(!rebb_core_is_running()) {
        rebb_log(PluginPause, "Core of mod is not running! No further work with plugin possible!");
    }

    RegisterGrabForwards();
}

public plugin_init() {
    RegisterHooks();

    bind_pcvar_num(
            create_cvar(
            .name = "rebb_reset_ent",
            .string = "1",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_RESET_ENT")
        ), g_iResetEnt
    );

    g_iLockBlocks = get_cvar_num("rebb_lock_blocks");
    g_BarrierEnt = rebb_get_barrier_ent_index();
}

public rebb_build_start() {
    EnableHookChain(g_hPreThink);
}

public rebb_preparation_start() {
    DisableHookChain(g_hPreThink);
}

public client_disconnected(id) {
    CmdGrabStop(id);
}

public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event) {
    if(!GetHookChainReturn(ATYPE_BOOL)) {
        return;
    }

    DisableHookChain(g_hPreThink);

    new players[MAX_PLAYERS], count;
    get_players(players, count);

    for(new i; i < count; i++) {
        CmdGrabStop(players[i]);
    }
}

public CSGameRules_RestartRound_Pre() {
    if(g_iResetEnt) {
        new szTarget[7];
        for(new iEnt = MaxClients; iEnt < 1024; iEnt++) {
            if(!is_entity(iEnt)) {
                continue;
            }
            
            get_entvar(iEnt, var_targetname, szTarget, charsmax(szTarget));

            if(g_iLockBlocks && BlockLocker(iEnt) && iEnt != g_BarrierEnt && FClassnameIs(iEnt, "func_wall") && !equal(szTarget, "ignore")) {
                UnlockBlock(iEnt);
                set_entvar(iEnt, var_rendermode, kRenderNormal);
                engfunc(EngFunc_SetOrigin, iEnt, Float:{ 0.0, 0.0, 0.0 });
                    
                UnsetLastMover(iEnt);
                UnsetEntMover(iEnt);
            } else if(!BlockLocker(iEnt) && iEnt != g_BarrierEnt && FClassnameIs(iEnt, "func_wall") && !equal(szTarget, "ignore")) {
                set_entvar(iEnt, var_rendermode, kRenderNormal);
                engfunc(EngFunc_SetOrigin, iEnt, Float:{ 0.0, 0.0, 0.0 });
                    
                UnsetLastMover(iEnt);
                UnsetEntMover(iEnt);
            }
        }
    }
}

public CBasePlayer_PreThink(id) {
    if(!is_user_alive(id)) {
        return;
    }

    new button = get_entvar(id, var_button);
    new oldbutton = get_entvar(id, var_oldbuttons);

    if(button & IN_USE && ~oldbutton & IN_USE && !g_iOwnedEnt[id]) {
        CmdGrabMove(id);
    } else if(oldbutton & IN_USE && ~button & IN_USE && g_iOwnedEnt[id]) {
        CmdGrabStop(id);
    }

    if(is_user_zombie(id)) {
        CmdGrabStop(id);
        return;
    }

    if(is_nullent(g_iOwnedEnt[id])) {
        return;
    }

    if(button & IN_ATTACK) {
        g_fEntDist[id] += OBJECT_PUSHPULLRATE;

        if(g_fEntDist[id] > MAX_MOVE_DISTANCE) {
            g_fEntDist[id] = MAX_MOVE_DISTANCE;
            client_print(id, print_center, "%L", LANG_PLAYER, "REBB_MAX_MOVE_DISTANCE");
        } else {
            client_print(id, print_center, "%L", LANG_PLAYER, "REBB_PUSH");
        }

        ExecuteForward(g_Forward[FWD_PUSH_PULL], _, id, g_iOwnedEnt[id], 1);
    } else if (button & IN_ATTACK2) {
        g_fEntDist[id] -= OBJECT_PUSHPULLRATE;

        if(g_fEntDist[id] < MIN_DIST_SET) {
            g_fEntDist[id] = MIN_DIST_SET;
            client_print(id, print_center, "%L", LANG_PLAYER, "REBB_MIN_MOVE_DISTANCE");
        } else {
            client_print(id, print_center, "%L", LANG_PLAYER, "REBB_PULL");
        }

        ExecuteForward(g_Forward[FWD_PUSH_PULL], _, id, g_iOwnedEnt[id], 2);
    }

    new Float:fvarOrigin[POS], Float:fvarViewOfs[POS], Float:fOrigin[POS], Float:fLook[POS], Float:vMoveTo[POS], Float:fLength;

    get_entvar(id, var_origin, fvarOrigin);
    get_entvar(id, var_view_ofs, fvarViewOfs);
    xs_vec_add(fvarOrigin, fvarViewOfs, fOrigin);
    fm_get_aim_origin(id, fLook);

    fLength = get_distance_f(fLook, fOrigin);

    if(fLength == 0.0) {
        fLength = 1.0;
    }

    vMoveTo[X] = (fOrigin[X] + (fLook[X] - fOrigin[X]) * g_fEntDist[id] / fLength) + g_fOffset1[id];
    vMoveTo[Y] = (fOrigin[Y] + (fLook[Y] - fOrigin[Y]) * g_fEntDist[id] / fLength) + g_fOffset2[id];
    vMoveTo[Z] = (fOrigin[Z] + (fLook[Z] - fOrigin[Z]) * g_fEntDist[id] / fLength) + g_fOffset3[id];
    vMoveTo[Z] -= floatfract(vMoveTo[Z]);

    engfunc(EngFunc_SetOrigin, g_iOwnedEnt[id], vMoveTo);
}

public CmdGrabMove(id) {
    if(!rebb_is_building_phase() || is_user_zombie(id)) {
        return PLUGIN_HANDLED;
    }

    new iReturn;
    ExecuteForward(g_Forward[FWD_GRAB_ENTITY], iReturn, id);
    if(iReturn == PLUGIN_HANDLED) {
        return PLUGIN_HANDLED;
    }

    if(!is_nullent(g_iOwnedEnt[id])) {
        CmdGrabStop(id);
    }

    new iEnt, iBody;
    get_user_aiming(id, iEnt, iBody);

    if(is_nullent(iEnt) || iEnt == g_BarrierEnt || !FClassnameIs(iEnt, "func_wall") || IsMovingEnt(iEnt)) {
        return PLUGIN_HANDLED;
    }

    if (BlockLocker(iEnt) && BlockLocker(iEnt) != id) {
        return PLUGIN_HANDLED;
    }

    new szTarget[7];
    get_entvar(iEnt, var_targetname, szTarget, charsmax(szTarget));

    if(equal(szTarget, "ignore")) {
        return PLUGIN_HANDLED;
    }

    ExecuteForward(g_Forward[FWD_GRAB_ENTITY_PRE], _, id, iEnt);

    new Float:fOrigin[POS], Float:fAiming[POS];

    fm_get_aim_origin(id, fAiming);
    get_entvar(iEnt, var_origin, fOrigin);

    g_fOffset1[id] = fOrigin[X] - fAiming[X];
    g_fOffset2[id] = fOrigin[Y] - fAiming[Y];
    g_fOffset3[id] = fOrigin[Z] - fAiming[Z];

    g_fEntDist[id] = get_user_aiming(id, iEnt, iBody);

    if(g_fEntDist[id] < MIN_MOVE_DISTANCE) {
        g_fEntDist[id] = MIN_DIST_SET;
    }

    if(g_fEntDist[id] > MAX_MOVE_DISTANCE) {
        return PLUGIN_HANDLED;
    }

    set_entvar(iEnt, var_rendermode, kRenderTransColor);
    set_entvar(iEnt, var_rendercolor, Float:{ 000.0, 150.0, 000.0 });
    //set_entvar(iEnt, var_rendercolor, g_fBlockColor[g_iPlayerColor[id]]);
    set_entvar(iEnt, var_renderamt, 100.0);

    MovingEnt(iEnt);
    SetEntMover(iEnt, id);
    g_iOwnedEnt[id] = iEnt;

    ExecuteForward(g_Forward[FWD_GRAB_ENTITY_POST], _, id, iEnt);

    return PLUGIN_HANDLED;
}

public CmdGrabStop(id) {
    if(!g_iOwnedEnt[id]) {
        return PLUGIN_HANDLED;
    }

    // TODO: Добавить проверку на валидность энтити?
    new iEnt = g_iOwnedEnt[id];

    ExecuteForward(g_Forward[FWD_DROP_ENTITY_PRE], _, id, iEnt);

    set_entvar(iEnt, var_rendermode, kRenderNormal);

    UnsetEntMover(iEnt);
    SetLastMover(iEnt, id);
    g_iOwnedEnt[id] = 0;
    UnmovingEnt(iEnt);

    ExecuteForward(g_Forward[FWD_DROP_ENTITY_POST], _, id, iEnt);

    return PLUGIN_HANDLED;
}

RegisterHooks() {
    RegisterHookChain(RG_RoundEnd, "RoundEnd_Post", true);
    RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
    g_hPreThink = RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink", false);
}

RegisterGrabForwards() {
    g_Forward[FWD_PUSH_PULL] = CreateMultiForward("rebb_block_pushpull", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
    g_Forward[FWD_GRAB_ENTITY] = CreateMultiForward("rebb_grab_block", ET_STOP, FP_CELL);
    g_Forward[FWD_GRAB_ENTITY_PRE] = CreateMultiForward("rebb_grab_pre", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forward[FWD_GRAB_ENTITY_POST] = CreateMultiForward("rebb_grab_post", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forward[FWD_DROP_ENTITY_PRE] = CreateMultiForward("rebb_drop_pre", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forward[FWD_DROP_ENTITY_POST] = CreateMultiForward("rebb_drop_post", ET_IGNORE, FP_CELL, FP_CELL);
}

public plugin_natives() {
    register_native("rebb_grab_stop", "native_grab_stop");
}
public native_grab_stop(iPlugin, iParams) {
    new id = get_param(1);
    if(!is_user_connected(id)) {
        return -1;
    }

    return CmdGrabStop(id);
}
