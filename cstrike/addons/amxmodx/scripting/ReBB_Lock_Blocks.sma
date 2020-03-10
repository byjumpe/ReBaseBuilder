#pragma semicolon 1

#include <amxmodx>
#include <reapi>
#include <re_basebuilder>

new g_iLockBlocks, g_iMaxLockBlocks, g_iOwnedEntities[MAX_PLAYERS +1], g_BarrierEnt;

new const VERSION[] = "0.0.1 Alpha";

// List of client commands that locked block
new const LOCK_BLOCK_CMDS[][] = {
    "say /lock",
    "say_team /lock"
};

public plugin_precache() {
    register_plugin("[ReBB] Lock Blocks", VERSION, "ReBB");
}

public plugin_init() {
    RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);

    bind_pcvar_num(
            create_cvar(
            .name = "rebb_lock_blocks",
            .string = "1",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_LOCK_BLOCKS")
        ), g_iLockBlocks
    );
    bind_pcvar_num(
            create_cvar(
            .name = "rebb_max_lock_blocks",
            .string = "10",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_MAX_LOCK_BLOCKS")
        ), g_iMaxLockBlocks
    );

    for(new i; i < sizeof(LOCK_BLOCK_CMDS); i++) {
        register_clcmd(LOCK_BLOCK_CMDS[i], "LockBlockCmd");
    }
    g_BarrierEnt = rebb_barrier_ent();
}

public client_disconnected(id) {
    g_iOwnedEntities[id] = 0;
}

public CSGameRules_RestartRound_Pre() {
    arrayset(g_iOwnedEntities, 0, MAX_PLAYERS +1);
}

public LockBlockCmd(id){
    new CanBuild = rebb_is_building_phase();

    if(!CanBuild || IsZombie(id) || !g_iLockBlocks) {
        return PLUGIN_HANDLED;
    }

    new iEnt, iBody, szTarget[7];
    get_user_aiming(id, iEnt, iBody);

    get_entvar(iEnt, var_targetname, szTarget, charsmax(szTarget));

    if(is_nullent(iEnt) || iEnt == g_BarrierEnt || !FClassnameIs(iEnt, "func_wall") || IsMovingEnt(iEnt) || equal(szTarget, "ignore")) {
        return PLUGIN_HANDLED;
    }

    if(!BlockLocker(iEnt) && !IsMovingEnt(iEnt)) {
        if(g_iOwnedEntities[id] < g_iMaxLockBlocks || !g_iMaxLockBlocks) {
            LockBlock(iEnt, id);
            g_iOwnedEntities[id]++;

            client_print_color(id, print_team_default, "%L [ %d / %d ]", LANG_SERVER, "REBB_LOCK_BLOCKS_UP", g_iOwnedEntities[id], g_iMaxLockBlocks);
        }
        else if(g_iOwnedEntities[id] >= g_iMaxLockBlocks) {
            client_print_color(id, print_team_default, "%L", LANG_SERVER, "REBB_LOCK_BLOCKS_MAX", g_iMaxLockBlocks);
        }
    }
    else if(BlockLocker(iEnt)) {
         if(BlockLocker(iEnt) == id) {
            g_iOwnedEntities[BlockLocker(iEnt)]--;

            client_print_color(BlockLocker(iEnt), print_team_default, "%L [ %d / %d ]", LANG_SERVER, "REBB_LOCK_BLOCKS_LOST", g_iOwnedEntities[BlockLocker(iEnt)], g_iMaxLockBlocks);

            UnlockBlock(iEnt);
         }
         else {
            client_print_color(id, print_team_default, "%L", LANG_SERVER, "REBB_LOCK_BLOCKS_FAIL");
         }
    }
    return PLUGIN_HANDLED;
}
