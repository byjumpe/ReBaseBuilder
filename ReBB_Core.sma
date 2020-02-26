/* TODO: Имя и описание класса нужно будет перевести на МЛ.
        Имя будет использоваться как уникальный строковый
        идентификатор класса в форварде rebb_class_registered() */

/* ============================================================ */
/*
ReBB:

    Jumper (https://dev-cs.ru/members/299/)
    BlackSignature (https://dev-cs.ru/members/1111/)
    d3m37r4 (https://dev-cs.ru/members/64/)

Thx for the tests:

    NoNameNPC (https://dev-cs.ru/members/5792/)

Thx for the mod idea and original code

    Tirant - Creator/Founder/Base Builder God

*/
/* ============================================================ */

#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <reapi>
#include <time>
#include <re_basebuilder>

// Автосоздание конфига
#define AUTO_CFG

new const VERSION[] = "0.3.3 Alpha";

// List of client commands that open zombie class menu
new const MENU_CMDS[][] = {
    "say /zm",
    "say_team /zm"
};

// List of client commands that open select color menu
new const COLOR_MENU_CMDS[][] = {
    "say /color",
    "say_team /color"
};

// List of client commands that locked block
new const LOCK_BLOCK_CMDS[][] = {
    "say /lock",
    "say_team /lock"
};

new const RADIO_CMDS[][] = {
    "radio1",
    "radio2",
    "radio3"
};

#define MAX_BUFFER_INFO 128

const Float:MAX_MOVE_DISTANCE = 768.0;
const Float:MIN_MOVE_DISTANCE = 32.0;
const Float:MIN_DIST_SET = 64.0;

const Float:OBJECT_PUSHPULLRATE     = 4.0;
const Float:MAX_HOLDTIME            = 20.0;

enum COLOR { R, G, B };
enum any:POS { Float:X, Float:Y, Float:Z };

#define IsPlayer(%0) (1 <= %0 <= MaxClients)

enum (+= 100) {
    TASK_BUILDTIME = 100,
    TASK_PREPTIME,
    TASK_MODELSET,
    TASK_RESPAWN,
    TASK_HEALTH,
    TASK_IDLESOUND
};

enum any:CVAR_LIST {
    GAME_NAME[MAX_NAME_LENGTH],
    BUILDING_TIME,
    PREPARATION_TIME,
    Float:ZOMBIE_RESPAWN_DELAY,
    Float:INFECTION_RESPAWN_DELAY,
    BLOCK_DROP_WEAPON,
    RESET_ENT,
    LOCK_BLOCKS,
    MAX_LOCK_BLOCKS,
    SHOW_HUD_MOVERS
};

enum any:MULTYPLAY_CVARS {
    MP_BUYTIME,
    MP_ROUNDOVER,
    MP_BUY_ANYWHERE
    //MP_ITEM_STAYTIME
};

enum any:SOUND_ENUM {
    ZOMBIE_WIN,
    HUMAN_WIN,

    ZOMBIE_RELEASE,

    BLOCK_GRAB,
    BLOCK_DROP
};

enum any:COLOR_ENUM {
    DEFAULT,
    RED,
    PINK,
    ORANGE,
    YELLOW,
    PURPLE,
    INDIGO,
    BLACK,
    GREEN,
    BLUE,
    AQUA,
    LIME,
    GOLD,
    DARK_RED,
    TEAL,
    NAVY,
    ORANGE_RED
};

enum FORWARDS_LIST {
    FWD_CLASS_REG_REQUEST,
    FWD_CLASS_REGISTERED,
    FWD_PUSH_PULL,
    FWD_GRAB_ENTITY_PRE,
    FWD_GRAB_ENTITY_POST,
    FWD_DROP_ENTITY_PRE,
    FWD_DROP_ENTITY_POST,
    FWD_BUILD_START,
    FWD_PREPARATION_START,
    FWD_ZOMBIES_RELEASED
};

new const g_HudColor[COLOR] = { 255, 0, 0 };
new const g_MpCvars[MULTYPLAY_CVARS][] = {
    "mp_buytime",
    "mp_roundover",
    "mp_buy_anywhere"
    //"mp_item_staytime"
};

new g_szSoundName[SOUND_ENUM][] = {
    "zombie_win",
    "human_win",

    "zombie_release",

    "block_grab",
    "block_drop"
};

new Float:g_fBlockColor[COLOR_ENUM][] = {
    { 000.0, 150.0, 000.0 },
    { 255.0, 0.0, 0.0 },
    { 255.0, 20.0, 147.0 },
    { 255.0, 165.0, 0.0 },
    { 255.0, 255.0, 0.0 },
    { 128.0, 0.0, 128.0 },
    { 75.0, 0.0, 130.0 },
    { 0.0, 0.0, 0.0 },
    { 0.0, 128.0, 0.0 },
    { 0.0, 0.0, 255.0 },
    { 0.0, 255.0, 255.0 },
    { 0.0, 255.0, 0.0 },
    { 255.0, 215.0, 0.0 },
    { 139.0, 0.0, 0.0 },
    { 0.0, 128.0, 128.0 },
    { 0.0, 0.0, 128.0 },
    { 255.0, 69.0, 0.0 }
};

new g_szColorName[COLOR_ENUM][] =  {
    "Default",
    "Red",
    "Pink",
    "Orange",
    "Yellow",
    "Purple",
    "Indigo",
    "Black",
    "Green",
    "Blue",
    "Aqua",
    "Lime",
    "Gold",
    "Dark Red",
    "Teal",
    "Navy",
    "Orange Red"
};

new g_Pointer[MULTYPLAY_CVARS];
new g_Forward[FORWARDS_LIST];

new g_Cvar[CVAR_LIST];
new g_iColorOwner[MAX_PLAYERS +1];

new g_BarrierEnt;

new Float: g_fEntDist[MAX_PLAYERS +1];
new TeamName:g_iTeam[MAX_PLAYERS +1], g_iCountTime, g_iOwnedEnt[MAX_PLAYERS +1], g_iZombieClass[MAX_PLAYERS +1], g_iPlayerColor[MAX_PLAYERS +1], g_iOwnedEntities[MAX_PLAYERS +1];
new bool: g_bFirstSpawn[MAX_PLAYERS +1], bool: g_bSwapTeams, bool: g_bCanBuild, bool: g_bPrepTime, bool: g_bRoundEnded;
new bool: g_bZombiesReleased;
new Float: g_fOffset1[MAX_PLAYERS +1], Float: g_fOffset2[MAX_PLAYERS +1], Float: g_fOffset3[MAX_PLAYERS +1];

new g_szSound[SOUND_ENUM][PLATFORM_MAX_PATH];

new bool:g_bCanRegister;
new g_FWShowHudMovers;

new Array: g_ZombieName;
new Array: g_ZombieInfo;
new Array: g_ZombieModel;
new Array: g_ZombieHandModel;
new Array: g_ZombieHP;
new Array: g_ZombieSpeed;
new Array: g_ZombieGravity;
new Array: g_ZombieFlags;
new g_ClassesCount;

new g_SyncHud, g_HudShowMovers;

new g_msgSendAudio;
new g_hMsgSendAudio;

new HookChain: g_hPreThink;

#define LockBlock(%1,%2)            (set_entvar(%1, var_iuser1, %2))
#define UnlockBlock(%1)             (set_entvar(%1, var_iuser1, 0))
#define BlockLocker(%1)             (get_entvar(%1, var_iuser1))

#define MovingEnt(%1)               (set_entvar(%1, var_iuser2, 1))
#define UnmovingEnt(%1)             (set_entvar(%1, var_iuser2, 0))
#define IsMovingEnt(%1)             (get_entvar(%1, var_iuser2) == 1)

#define SetEntMover(%1,%2)          (set_entvar(%1, var_iuser3, %2))
#define UnsetEntMover(%1)           (set_entvar(%1, var_iuser3, 0))
#define GetEntMover(%1)           (get_entvar(%1, var_iuser3))

#define SetLastMover(%1,%2)         (set_entvar(%1, var_iuser4, %2))
#define UnsetLastMover(%1)          (set_entvar(%1, var_iuser4, 0))
#define GetLastMover(%1)            (get_entvar(%1, var_iuser4))

#define IsValidTeam(%1)             (TEAM_TERRORIST <= get_member(%1, m_iTeam) <= TEAM_CT)
#define GetCvarDesc(%0)             fmt("%L", LANG_SERVER, %0)

public plugin_precache() {
    register_plugin("[ReAPI] Base Builder", VERSION, "ReBB");

    RegisterCoreForwards();

    // TODO: перевести магические цифры в константы
    g_ZombieName = ArrayCreate(32, 1);
    g_ZombieInfo = ArrayCreate(32, 1);
    g_ZombieModel = ArrayCreate(64, 1);
    g_ZombieHandModel = ArrayCreate(64, 1);
    g_ZombieHP = ArrayCreate(1, 1);
    g_ZombieSpeed = ArrayCreate(1, 1);
    g_ZombieGravity = ArrayCreate(1, 1);
    g_ZombieFlags = ArrayCreate(1, 1);

    g_bCanRegister = true;

    ExecuteForward(g_Forward[FWD_CLASS_REG_REQUEST]);

    if(!g_ClassesCount) {
        set_fail_state("Registered zombie classes not found!");
    }

    for(new i; i < SOUND_ENUM; i++){

        formatex(g_szSound[i], charsmax(g_szSound[]), "re_basebuilder/%s.wav", g_szSoundName[i]);
        precache_sound(g_szSound[i]);
    }
}

public plugin_init() {
    register_dictionary("re_basebuilder.txt");

    RegisterHooks();
    RegisterCvars();

#if defined AUTO_CFG
    AutoExecConfig(true, "ReBaseBuilder");
#endif

    for(new i; i < sizeof(MENU_CMDS); i++) {
        register_clcmd(MENU_CMDS[i], "Zombie_Menu");
    }
    for(new i; i < sizeof(COLOR_MENU_CMDS); i++) {
        register_clcmd(COLOR_MENU_CMDS[i], "Color_Menu");
    }
    for(new i; i < sizeof(LOCK_BLOCK_CMDS); i++) {
        register_clcmd(LOCK_BLOCK_CMDS[i], "LockBlockCmd");
    }
    new const szBlockCallBack[] = "BlockRadioCmd";
    for(new i; i < sizeof(RADIO_CMDS); i++) {
            register_clcmd(RADIO_CMDS[i], szBlockCallBack);
    }

    g_msgSendAudio = get_user_msgid("SendAudio");

    register_event("Health", "Event_Health", "be", "1>0");
    set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);

    g_SyncHud = CreateHudSyncObj();
    g_HudShowMovers = CreateHudSyncObj();
    g_BarrierEnt = FindEntity("func_wall", "barrier");

    if(!g_BarrierEnt) {
        set_fail_state("There is no barrier on this map!");
    }
}

public OnConfigsExecuted() {
    set_member_game(m_GameDesc, g_Cvar[GAME_NAME]);
    register_cvar("re_basebuilder", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED);
}

public plugin_cfg() {
    GetCvarsPointers();
    SetCvarsValues();
}

public client_putinserver(id) {
    if(!is_user_bot(id)) {
        set_member(id, m_bIgnoreRadio, true);
    }
}

public client_disconnected(id) {
    g_iTeam[id] = TEAM_UNASSIGNED;

    g_bFirstSpawn[id] = true;
    g_iZombieClass[id] = 0;
    g_iPlayerColor[id] = 0;

    remove_task(id+TASK_RESPAWN);
    remove_task(id+TASK_HEALTH);

    g_iOwnedEntities[id] = 0;

    CmdGrabStop(id);

    for(new iEnt = MaxClients; iEnt < 1024; iEnt++) {
        if(is_nullent(iEnt) && g_Cvar[LOCK_BLOCKS] && BlockLocker(iEnt)) {
            
            UnlockBlock(iEnt);
            set_entvar(iEnt, var_rendermode, kRenderNormal);
                
            UnsetLastMover(iEnt);
            UnsetEntMover(iEnt);
        }
    }
}

public RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event) {
    g_hMsgSendAudio = register_message(g_msgSendAudio, "Msg_SendAudio");
}

public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event) {
    unregister_message(g_msgSendAudio, g_hMsgSendAudio);

    if(!GetHookChainReturn(ATYPE_BOOL)) {
        return;
    }

    DisableHookChain(g_hPreThink);

    g_bRoundEnded = true;
    g_bCanBuild = false;
    g_bPrepTime = false;

    new players[MAX_PLAYERS], count, player;
    get_players(players, count);

    for(new i; i < count; i++) {
        player = players[i];

        CmdGrabStop(player);
        remove_task(player+TASK_RESPAWN);
    }

    remove_task(TASK_BUILDTIME);
    remove_task(TASK_PREPTIME);

    switch(event) {
        case ROUND_CTS_WIN: {
            g_bSwapTeams = true;
            client_print(0, print_center, "%L", LANG_PLAYER, "REBB_HUMAN_WIN");
            rg_send_audio(0, g_szSound[HUMAN_WIN]);
        }
        case ROUND_TERRORISTS_WIN: {
            g_bSwapTeams = true;
            client_print(0, print_center, "%L", LANG_PLAYER, "REBB_ZOMBIE_WIN");
            rg_send_audio(0, g_szSound[ZOMBIE_WIN]);
        }
        case ROUND_GAME_OVER: {
            g_bSwapTeams = true;
            rg_update_teamscores(1, 0, true);
            client_print(0, print_center, "%L", LANG_PLAYER, "REBB_HUMAN_WIN");
            rg_send_audio(0, g_szSound[HUMAN_WIN]);
        }
        default: {
            client_print(0, print_center, ""); // clear print_center as we don't print anything else
        }
    }
}

public CSGameRules_RestartRound_Pre() {
    g_bRoundEnded = false;
    g_bZombiesReleased = false;

    set_entvar(g_BarrierEnt, var_solid, SOLID_BSP);
    set_entvar(g_BarrierEnt, var_rendermode, kRenderTransColor);
    set_entvar(g_BarrierEnt, var_rendercolor, Float:{ 0.0, 0.0, 0.0 });
    set_entvar(g_BarrierEnt, var_renderamt, 150.0);
    
    arrayset(g_iOwnedEntities, 0, MAX_PLAYERS +1);
    arrayset(g_iPlayerColor, 0, MAX_PLAYERS +1);
    arrayset(g_iColorOwner, 0, MAX_PLAYERS +1);

    if(g_Cvar[RESET_ENT]) {
        new szClass[10], szTarget[7];
        for(new iEnt = MaxClients; iEnt < 1024; iEnt++) {
            if(is_entity(iEnt)) {
                get_entvar(iEnt, var_classname, szClass, charsmax(szClass));
                get_entvar(iEnt, var_targetname, szTarget, charsmax(szTarget));

                if(g_Cvar[LOCK_BLOCKS] && BlockLocker(iEnt) && iEnt != g_BarrierEnt && equal(szClass, "func_wall") && !equal(szTarget, "ignore")) {
                    UnlockBlock(iEnt);
                    set_entvar(iEnt, var_rendermode, kRenderNormal);
                    engfunc(EngFunc_SetOrigin, iEnt, Float:{ 0.0, 0.0, 0.0 });
                    
                    UnsetLastMover(iEnt);
                    UnsetEntMover(iEnt);
                }
                else if(!BlockLocker(iEnt) && iEnt != g_BarrierEnt && equal(szClass, "func_wall") && !equal(szTarget, "ignore")) {
                    set_entvar(iEnt, var_rendermode, kRenderNormal);
                    engfunc(EngFunc_SetOrigin, iEnt, Float:{ 0.0, 0.0, 0.0 });
                    
                    UnsetLastMover(iEnt);
                    UnsetEntMover(iEnt);
                }
            }
        }
    }
    g_iCountTime = g_Cvar[BUILDING_TIME] + 1;
    set_task_ex(0.1, "BuildTime", TASK_BUILDTIME);
    set_task_ex(1.0, "BuildTime", TASK_BUILDTIME, .flags = SetTask_Repeat);

    if(g_bSwapTeams) {
        g_bSwapTeams = false;

        new players[MAX_PLAYERS], count;
        get_players(players, count);

        for(new i, player; i < count; i++) {
            player = players[i];

            if(g_iTeam[player] != TEAM_UNASSIGNED && IsValidTeam(player)){
                rg_set_user_team(player, g_iTeam[player] == TEAM_TERRORIST ? TEAM_CT : TEAM_TERRORIST);
            }
        }
    }

    arrayset(g_iTeam, TEAM_UNASSIGNED, sizeof(g_iTeam));
}

public CBasePlayer_DropPlayerItem_Pre(const id, const pszItemName[]) {
    if(g_Cvar[BLOCK_DROP_WEAPON]) {
        client_printex(id, print_center, "#Weapon_Cannot_Be_Dropped");
        SetHookChainReturn(ATYPE_INTEGER, 0);
        return HC_SUPERCEDE;
    }

    return HC_CONTINUE;
}

public CBasePlayer_HasRestrictItem_Pre(id, ItemID:iItem, ItemRestType:iRestType) {
    if(IsConnected(id) && IsZombie(id)) {
        SetHookChainReturn(ATYPE_BOOL, true);
        return HC_SUPERCEDE;
    }

    return HC_CONTINUE;
}

public CBasePlayer_OnSpawnEquip_Pre(id, bool:bAddDefault, bool:bEquipGame) {
    if(!IsConnected(id)) {
        return HC_CONTINUE;
    }

    CmdGrabStop(id);

    rg_set_user_armor(id, 0, ARMOR_NONE);

    rg_remove_all_items(id);
    rg_give_item(id, "weapon_knife", GT_APPEND);
    return HC_SUPERCEDE;
}

public CBasePlayer_Spawn_Post(id) {
    if(!IsAlive(id)) {
        return;
    }

    remove_task(id+TASK_HEALTH);
    remove_task(id+TASK_RESPAWN);

    if(g_iTeam[id] == TEAM_UNASSIGNED) {
        g_iTeam[id] = get_member(id, m_iTeam);
    }

    if(!IsZombie(id)) {
        rg_reset_user_model(id, true);
    }
    else {
        if(g_bFirstSpawn[id]) {
            Zombie_Menu(id);
            g_bFirstSpawn[id] = false;
        }

        set_entvar(id, var_health, Float:ArrayGetCell(g_ZombieHP, g_iZombieClass[id]));
        set_entvar(id, var_maxspeed, Float:ArrayGetCell(g_ZombieSpeed, g_iZombieClass[id]));
        set_entvar(id, var_gravity, Float:ArrayGetCell(g_ZombieGravity, g_iZombieClass[id]));

        rg_set_user_model(id, fmt("%a", ArrayGetStringHandle(g_ZombieModel, g_iZombieClass[id])), true); // TEST
    }

    set_task_ex(MAX_HOLDTIME, "taskPlayerHud", id+TASK_HEALTH, .flags = SetTask_Repeat);
    //set_task(0.1, "taskPlayerHud", id+TASK_HEALTH); // TEST: in spawn post we got real health value or not?
}

public CBasePlayer_ResetMaxSpeed_Post(id) {
    if(IsAlive(id) && IsZombie(id)) {
        // NOTE: this will break any external speed modificator (like temporary speed bost item in zombie escape)
        set_entvar(id, var_maxspeed, Float:ArrayGetCell(g_ZombieSpeed, g_iZombieClass[id]));
    }
}

public CBasePlayer_Killed_Post(iVictim, iKiller, iGibType) {
    if(!IsConnected(iVictim)) {
        return;
    }

    CmdGrabStop(iVictim);

    if(task_exists(iVictim+TASK_HEALTH)) {
        remove_task(iVictim+TASK_HEALTH);
        ClearSyncHud(iVictim, g_SyncHud);
    }

    if(IsZombie(iVictim)) {
        if(g_Cvar[ZOMBIE_RESPAWN_DELAY] && !g_bRoundEnded) {
            if(g_Cvar[ZOMBIE_RESPAWN_DELAY] >= 1.0) {
                client_print(iVictim, print_center, "%L", LANG_PLAYER, "REBB_ZOMBIE_RESPAWN", g_Cvar[ZOMBIE_RESPAWN_DELAY]);
            }
            set_task_ex(g_Cvar[ZOMBIE_RESPAWN_DELAY], "Respawn", iVictim+TASK_RESPAWN);
        }
    }
    else if(IsPlayer(iKiller) && iVictim != iKiller) {
        client_print(0, print_center, "%L", LANG_PLAYER, "REBB_INFECTION", iVictim);
        rg_set_user_team(iVictim, TEAM_TERRORIST);

        if(g_Cvar[INFECTION_RESPAWN_DELAY] && !g_bRoundEnded) {
            if(g_Cvar[INFECTION_RESPAWN_DELAY] >= 1.0) {
                client_print(iVictim, print_center, "%L", LANG_PLAYER, "REBB_INFECTION_RESPAWN", g_Cvar[INFECTION_RESPAWN_DELAY]);
            }
            set_task_ex(g_Cvar[INFECTION_RESPAWN_DELAY], "Respawn", iVictim+TASK_RESPAWN);
        }
    }
}

public CBasePlayer_PreThink(id) {
    if(!IsAlive(id)) {
        return;
    }

    new button = get_entvar(id, var_button);
    new oldbutton = get_entvar(id, var_oldbuttons);

    if(button & IN_USE && ~oldbutton & IN_USE && !g_iOwnedEnt[id]) {
        CmdGrabMove(id);
    } else if(oldbutton & IN_USE && ~button & IN_USE && g_iOwnedEnt[id]) {
        CmdGrabStop(id);
    }

    if(!IsAlive(id) || IsZombie(id)) {
        CmdGrabStop(id);
        return;
    }

    if(!g_iOwnedEnt[id] || !is_entity(g_iOwnedEnt[id])) {
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
    if(!g_bCanBuild || IsZombie(id)) {
        return PLUGIN_HANDLED;
    }

    if(g_iOwnedEnt[id] && is_entity(g_iOwnedEnt[id])) {
        CmdGrabStop(id);
    }

    new iEnt, iBody;
    get_user_aiming(id, iEnt, iBody);

    if(is_nullent(iEnt) || iEnt == g_BarrierEnt || !FClassnameIs(iEnt, "func_wall") /*|| IsAlive(iEnt)*/ || IsMovingEnt(iEnt)) {
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
    set_entvar(iEnt, var_rendercolor, g_fBlockColor[g_iPlayerColor[id]]);
    set_entvar(iEnt, var_renderamt, 100.0);

    rg_send_audio(id, g_szSound[BLOCK_GRAB]);

    MovingEnt(iEnt);
    SetEntMover(iEnt, id);
    g_iOwnedEnt[id] = iEnt;

    ExecuteForward(g_Forward[FWD_GRAB_ENTITY_POST], _, id, iEnt);

    return PLUGIN_HANDLED;
}

public CmdGrabStop(id) {
    if(!g_iOwnedEnt[id]) {
        return;
    }

    new iEnt = g_iOwnedEnt[id];

    ExecuteForward(g_Forward[FWD_DROP_ENTITY_PRE], _, id, iEnt);

    if(g_Cvar[LOCK_BLOCKS] && BlockLocker(iEnt)) {
        set_entvar(iEnt, var_rendermode, kRenderTransColor);
        set_entvar(iEnt, var_rendercolor, g_fBlockColor[g_iPlayerColor[id]]);
        set_entvar(iEnt, var_renderamt, 255.0);
    }
    else {
        set_entvar(iEnt, var_rendermode, kRenderNormal);
    }

    rg_send_audio(id, g_szSound[BLOCK_DROP]);

    UnsetEntMover(iEnt);
    SetLastMover(iEnt, id);
    g_iOwnedEnt[id] = 0;
    UnmovingEnt(iEnt);

    ExecuteForward(g_Forward[FWD_DROP_ENTITY_POST], _, id, iEnt);
}

public Ham_Item_Deploy_Post(weapon) {
    new id = get_member(weapon, m_pPlayer);

    if(IsConnected(id) && IsZombie(id)) {
        set_entvar(id, var_viewmodel, fmt("models/zombie_hand/%a.mdl", ArrayGetStringHandle(g_ZombieHandModel, g_iZombieClass[id]))); // TEST
        set_entvar(id, var_weaponmodel, "");
    }
}

public BuildTime() {
    if(!g_bCanBuild) {
        g_bCanBuild = true;
        if(g_Cvar[SHOW_HUD_MOVERS] && g_FWShowHudMovers == 0) {
            g_FWShowHudMovers = register_forward(FM_TraceLine, "FW_Traceline", 1);
        }
        EnableHookChain(g_hPreThink);
        ExecuteForward(g_Forward[FWD_BUILD_START], _, g_iCountTime);
    }

    g_iCountTime--;

    if(g_iCountTime) {
        new iMins = g_iCountTime / SECONDS_IN_MINUTE, iSecs = g_iCountTime % SECONDS_IN_MINUTE;
        client_print(0, print_center, "%L %02d:%02d", LANG_PLAYER, "REBB_BUILD_TIME", iMins, iSecs);
    }
    else {
        g_bCanBuild = false;
        DisableHookChain(g_hPreThink);
        remove_task(TASK_BUILDTIME);
        client_print(0, print_center, ""); // clear print_center

        new players[MAX_PLAYERS], count;
        get_players_ex(players, count, GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "CT");

        for(new i; i < count; i++) {
            CmdGrabStop(players[i]);
        }

        g_bPrepTime = true;

        if(!g_Cvar[PREPARATION_TIME]) {
            ExecuteForward(g_Forward[FWD_PREPARATION_START], _, g_Cvar[PREPARATION_TIME]);
            Release_Zombies();
        }
        else {
            g_iCountTime = g_Cvar[PREPARATION_TIME] + 1;
            set_task_ex(0.1, "PrepTime", TASK_PREPTIME);
            set_task_ex(1.0, "PrepTime", TASK_PREPTIME, .flags = SetTask_Repeat);

            client_print_color(0, print_team_default, "%L", LANG_PLAYER, "REBB_PREP_HUMAN_SPAWN");

            for(new i; i < count; i++) {
                rg_round_respawn(players[i]);
            }

            // after players respawning
            ExecuteForward(g_Forward[FWD_PREPARATION_START], _, g_Cvar[PREPARATION_TIME]);
        }
    }
}

public PrepTime() {
    g_iCountTime--;
    
    if(g_FWShowHudMovers != 0) {
        unregister_forward(FM_TraceLine, g_FWShowHudMovers);
    }
    if(g_iCountTime) {
        new iMins = g_iCountTime / SECONDS_IN_MINUTE, iSecs = g_iCountTime % SECONDS_IN_MINUTE;
        client_print(0, print_center, "%L %02d:%02d", LANG_PLAYER, "REBB_PREP_TIME", iMins, iSecs);
    }
    else {
        remove_task(TASK_PREPTIME);
        Release_Zombies();
    }
}

public Zombie_Menu(id){
    if(g_bZombiesReleased) {
        return PLUGIN_HANDLED;
    }

    new menu = menu_create(fmt("%L", LANG_PLAYER, "REBB_ZOMBIE_MENU"), "Zombie_Menu_Handler");

    for(new i, name[MAX_NAME_LENGTH], info[32], flag; i < g_ClassesCount; i++) {
        ArrayGetString(g_ZombieName, i, name, sizeof(name));
        ArrayGetString(g_ZombieInfo, i, info, sizeof(info));
        flag = ArrayGetCell(g_ZombieFlags, i);
        menu_additem(menu, fmt("\w%s \r%s%s", name, info, flag == ADMIN_ALL ? "" : " \y[VIP]"), .paccess = flag);
    }

    menu_setprop(menu , MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_NEXT"));
    menu_setprop(menu , MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_BACK"));
    menu_setprop(menu , MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_EXIT"));
    menu_display(id, menu, 0);

    return PLUGIN_HANDLED;
}

public Zombie_Menu_Handler(id, menu, item) {
    menu_destroy(menu);

    if(item == MENU_EXIT) {
        return;
    }

    g_iZombieClass[id] = item;

    client_print_color(id, print_team_default, "%L ^4%a", LANG_PLAYER, "REBB_ZOMBIE_PICK", ArrayGetStringHandle(g_ZombieName, item)); // TEST

    if(IsZombie(id) && !g_bZombiesReleased && !g_bRoundEnded && !task_exists(id+TASK_RESPAWN)) {
        rg_round_respawn(id);
    }
}

public Color_Menu(id){
    new menu = menu_create(fmt("%L", LANG_PLAYER, "REBB_COLOR_MENU"), "Color_Menu_Handler");

    for(new i = 1; i < COLOR_ENUM; i++) {
        menu_additem(menu, fmt("\w%s", g_szColorName[i]));
    }

    menu_setprop(menu , MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_NEXT"));
    menu_setprop(menu , MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_BACK"));
    menu_setprop(menu , MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_EXIT"));
    menu_display(id, menu, 0);

    return PLUGIN_HANDLED;
}

public Color_Menu_Handler(id, menu, item) {
    menu_destroy(menu);

    if(item == MENU_EXIT) {
        return;
    }
    
    item++;

    g_iPlayerColor[id] = item;
    client_print_color(id, print_team_default, "%L ^4%s", LANG_PLAYER, "REBB_COLOR_PICK", g_szColorName[item]);
}

public LockBlockCmd(id){

    if(!g_bCanBuild || IsZombie(id) || !g_Cvar[LOCK_BLOCKS]) {
        return PLUGIN_HANDLED;
    }

    new iEnt, iBody;
    get_user_aiming(id, iEnt, iBody);

    if(is_nullent(iEnt) || iEnt == g_BarrierEnt || !FClassnameIs(iEnt, "func_wall") /*|| IsAlive(iEnt)*/ || IsMovingEnt(iEnt)) {
        return PLUGIN_HANDLED;
    }

    new szTarget[7];
    get_entvar(iEnt, var_targetname, szTarget, charsmax(szTarget));

    if(equal(szTarget, "ignore")) {
        return PLUGIN_HANDLED;
    }
    if(!BlockLocker(iEnt) && !IsMovingEnt(iEnt)) {
        if(g_iOwnedEntities[id] < g_Cvar[MAX_LOCK_BLOCKS] || !g_Cvar[MAX_LOCK_BLOCKS]) {
            LockBlock(iEnt, id);
            g_iOwnedEntities[id]++;
            set_entvar(iEnt, var_rendermode, kRenderTransColor);
            set_entvar(iEnt, var_rendercolor, g_fBlockColor[g_iPlayerColor[id]]);
            set_entvar(iEnt, var_renderamt, 255.0);

            client_print_color(id, print_team_default, "%L [ %d / %d ]", LANG_SERVER, "REBB_LOCK_BLOCKS_UP", g_iOwnedEntities[id], g_Cvar[MAX_LOCK_BLOCKS]);
        }
        else if(g_iOwnedEntities[id] >= g_Cvar[MAX_LOCK_BLOCKS]) {
            client_print_color(id, print_team_default, "%L", LANG_SERVER, "REBB_LOCK_BLOCKS_MAX", g_Cvar[MAX_LOCK_BLOCKS]);
        }
    }
    else if(BlockLocker(iEnt)) {
         if(BlockLocker(iEnt) == id) {
            g_iOwnedEntities[BlockLocker(iEnt)]--;
            set_entvar(iEnt, var_rendermode, kRenderNormal);

            client_print_color(BlockLocker(iEnt), print_team_default, "%L [ %d / %d ]", LANG_SERVER, "REBB_LOCK_BLOCKS_LOST", g_iOwnedEntities[BlockLocker(iEnt)], g_Cvar[MAX_LOCK_BLOCKS]);

            UnlockBlock(iEnt);
         }
         else {
            client_print_color(id, print_team_default, "%L", LANG_SERVER, "REBB_LOCK_BLOCKS_FAIL");
         }
    }
    return PLUGIN_HANDLED;
}

public FW_Traceline(Float:start[3], Float:end[3], conditions, id, trace) {
    if(!IsAlive(id)) {
        return PLUGIN_HANDLED;
    }
    
    new iEnt = get_tr2(trace, TR_pHit);

    if(is_entity(iEnt)) {
        new iEnt, iBody;
        get_user_aiming(id, iEnt, iBody);
        
        new szClass[10], szTarget[7];
        get_entvar(iEnt, var_classname, szClass, charsmax(szClass));
        get_entvar(iEnt, var_targetname, szTarget, charsmax(szTarget));
        if(equal(szClass, "func_wall") && !equal(szTarget, "ignore") && iEnt != g_BarrierEnt && g_Cvar[SHOW_HUD_MOVERS]) {
            if(g_bCanBuild) {
                set_hudmessage(0, 50, 255, -1.0, 0.55, 1, 0.01, 3.0, 0.01, 0.01);
                if (!BlockLocker(iEnt)) {
                    if (GetEntMover(iEnt)) {
                        if (!GetLastMover(iEnt)) {
                            ShowSyncHudMsg(id, g_HudShowMovers, "%L", LANG_PLAYER, "REBB_HUD_GET_MOVER", GetEntMover(iEnt));
                        }
                    }
                    if (GetLastMover(iEnt)) {
                        if (!GetEntMover(iEnt)) {
                            ShowSyncHudMsg(id, g_HudShowMovers, "%L", LANG_PLAYER, "REBB_HUD_GET_LAST_MOVER", GetLastMover(iEnt));
                        }
                    }
                    if (GetEntMover(iEnt) && GetLastMover(iEnt)) {
                        ShowSyncHudMsg(id, g_HudShowMovers, "%L", LANG_PLAYER, "REBB_HUD_GET_MOVER_AND_LAST_MOVER", GetEntMover(iEnt), GetLastMover(iEnt));
                    }
                    else if (!GetEntMover(iEnt) && !GetLastMover(iEnt)) {
                        ShowSyncHudMsg(id, g_HudShowMovers, "%L", LANG_PLAYER, "REBB_HUD_BLOCK_NOT_MOVE");
                    }
                }
                else {
                    ShowSyncHudMsg(id, g_HudShowMovers, "%L", LANG_PLAYER, "REBB_HUD_BLOCK_OWNER", BlockLocker(iEnt));
                }
            }
        }
    }
    else {
        ClearSyncHud(id, g_HudShowMovers);
    }

    return PLUGIN_HANDLED;
}

public taskPlayerHud(iTaskId) {
    UpdateHUD(iTaskId - TASK_HEALTH);
}

public Event_Health(id) {
    if(IsConnected(id)) {
        UpdateHUD(id);
    }
}

UpdateHUD(const index) {
    set_hudmessage(g_HudColor[R], g_HudColor[G], g_HudColor[B], 0.02, 0.95, .holdtime = MAX_HOLDTIME, .channel = -1);
    ShowSyncHudMsg(index, g_SyncHud, "[%.0f HP]", Float:get_entvar(index, var_health));
}

public Respawn(id) {
    id-=TASK_RESPAWN;

    if(IsConnected(id) && IsZombie(id)) {
        rg_round_respawn(id);
    }
}

public Msg_SendAudio() {
    new szSound[17];
    get_msg_arg_string(2, szSound, charsmax(szSound));

    if(contain(szSound[7], "terwin") != -1 || contain(szSound[7], "ctwin") != -1 || contain(szSound[7], "rounddraw") != -1) {
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public Release_Zombies() {
    g_bPrepTime = false;
    g_bZombiesReleased = true;

    set_entvar(g_BarrierEnt, var_solid, SOLID_NOT);
    set_entvar(g_BarrierEnt, var_renderamt, 0.0);

    rg_send_audio(0, g_szSound[ZOMBIE_RELEASE]);
    client_print_color(0, print_team_default, "%L", LANG_PLAYER, "REBB_ZOMBIE_RELEASE");

    ExecuteForward(g_Forward[FWD_ZOMBIES_RELEASED]);
}

RegisterHooks() {
    RegisterHookChain(RG_RoundEnd, "RoundEnd_Pre", false);
    RegisterHookChain(RG_RoundEnd, "RoundEnd_Post", true);
    RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
    RegisterHookChain(RG_CBasePlayer_DropPlayerItem, "CBasePlayer_DropPlayerItem_Pre", false);
    RegisterHookChain(RG_CBasePlayer_HasRestrictItem, "CBasePlayer_HasRestrictItem_Pre", false);
    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "CBasePlayer_OnSpawnEquip_Pre", false);
    RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true);
    RegisterHookChain(RG_CBasePlayer_ResetMaxSpeed, "CBasePlayer_ResetMaxSpeed_Post", true);
    RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed_Post", true);
    g_hPreThink = RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink", false);

    RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Item_Deploy_Post", true);
}

RegisterCoreForwards() {
    g_Forward[FWD_CLASS_REG_REQUEST] = CreateMultiForward("rebb_class_reg_request", ET_IGNORE);
    g_Forward[FWD_CLASS_REGISTERED] = CreateMultiForward("rebb_class_registered", ET_IGNORE, FP_CELL, FP_STRING);
    g_Forward[FWD_BUILD_START] = CreateMultiForward("rebb_build_start", ET_IGNORE, FP_CELL);
    g_Forward[FWD_PREPARATION_START] = CreateMultiForward("rebb_preparation_start", ET_IGNORE, FP_CELL);
    g_Forward[FWD_ZOMBIES_RELEASED] = CreateMultiForward("rebb_zombies_released", ET_IGNORE);

    g_Forward[FWD_PUSH_PULL] = CreateMultiForward("bb_block_pushpull", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
    g_Forward[FWD_GRAB_ENTITY_PRE] = CreateMultiForward("bb_grab_pre", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forward[FWD_GRAB_ENTITY_POST] = CreateMultiForward("bb_grab_post", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forward[FWD_DROP_ENTITY_PRE] = CreateMultiForward("bb_drop_pre", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forward[FWD_DROP_ENTITY_POST] = CreateMultiForward("bb_drop_post", ET_IGNORE, FP_CELL, FP_CELL);
}

RegisterCvars() {
    bind_pcvar_string(
        create_cvar(
            .name = "rebb_game_name",
            .string = "ReBaseBuilder",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_GAME_NAME")
        ), g_Cvar[GAME_NAME], charsmax(g_Cvar[GAME_NAME])
    );
    bind_pcvar_num(
        create_cvar(
            .name = "rebb_building_time",
            .string = "90",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_BUILDING_TIME"),
            .has_min = true,
            .min_val = 10.0
        ), g_Cvar[BUILDING_TIME]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "rebb_preparation_time",
            .string = "15",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_PREP_TIME"),
            .has_min = true,
            .min_val = 0.0
        ), g_Cvar[PREPARATION_TIME]
    );
    bind_pcvar_float(
        create_cvar(
            .name = "rebb_zombie_respawn_delay",
            .string = "3.0",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_ZOMBIE_RESPAWN_DELAY"),
            .has_min = true,
            .min_val = 0.0
        ), g_Cvar[ZOMBIE_RESPAWN_DELAY]
    );
    bind_pcvar_float(
        create_cvar(
            .name = "rebb_infection_respawn_delay",
            .string = "5.0",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_INFECTION_RESPAWN_DELAY"),
            .has_min = true,
            .min_val = 0.0
        ), g_Cvar[INFECTION_RESPAWN_DELAY]
    );
    bind_pcvar_num(
            create_cvar(
            .name = "rebb_block_drop_weapon",
            .string = "1",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_BLOCK_DROP_WEAPON")
        ), g_Cvar[BLOCK_DROP_WEAPON]
    );
    bind_pcvar_num(
            create_cvar(
            .name = "rebb_reset_ent",
            .string = "1",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_RESET_ENT")
        ), g_Cvar[RESET_ENT]
    );
    bind_pcvar_num(
            create_cvar(
            .name = "rebb_lock_blocks",
            .string = "1",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_LOCK_BLOCKS")
        ), g_Cvar[LOCK_BLOCKS]
    );
    bind_pcvar_num(
            create_cvar(
            .name = "rebb_max_lock_blocks",
            .string = "10",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_MAX_LOCK_BLOCKS")
        ), g_Cvar[MAX_LOCK_BLOCKS]
    );
    bind_pcvar_num(
            create_cvar(
            .name = "rebb_show_hud_movers",
            .string = "1",
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("REBB_SHOW_HUD_MOVERS")
        ), g_Cvar[SHOW_HUD_MOVERS]
    );
}

GetCvarsPointers() {
    for(new i; i < sizeof g_MpCvars; i++) {
        g_Pointer[i] = get_cvar_pointer(g_MpCvars[i]);
    }
}

SetCvarsValues() {
    set_pcvar_num(g_Pointer[MP_BUYTIME], -1);
    set_pcvar_num(g_Pointer[MP_ROUNDOVER], 1);
    set_pcvar_num(g_Pointer[MP_BUY_ANYWHERE], 3);
    //set_pcvar_num(g_Pointer[MP_ITEM_STAYTIME], 0);
}

public BlockRadioCmd() {
    return PLUGIN_HANDLED_MAIN;
}

FindEntity(const entityname[], const targetname[]) {
    new ent, name[MAX_NAME_LENGTH];
    while((ent = rg_find_ent_by_class(ent, entityname))) {
        get_entvar(ent, var_targetname, name, charsmax(name));
        if(equali(name, targetname)) {
            return ent;
        }
    }

    return NULLENT;
}

public plugin_natives(){
    register_native("rebb_register_zombie_class", "native_register_zombie_class");
    register_native("rebb_get_class_id", "native_zombie_get_class_id");
    register_native("rebb_is_building_phase", "native_is_building_phase");
    register_native("rebb_is_preparation_phase", "native_is_preparation_phase");
    register_native("rebb_is_zombies_released", "native_is_zombies_released");
}

public native_register_zombie_class(iPlugin, iParams) {
    enum { arg_name = 1, arg_info, arg_model, arg_handmodel, arg_health, arg_speed, arg_gravity, arg_flags };

    if(!g_bCanRegister) {
        return ERR_REG_CLASS__WRONG_PLACE;
    }

    new szName[32], szInfo[32], szModel[128], szHandmodel[64], Float:fHealth, Float:fSpeed, Float:fGravity, iFlags;

    get_string(arg_name, szName, sizeof(szName));
    ArrayPushString(g_ZombieName, szName);

    get_string(arg_info, szInfo, sizeof(szInfo));
    ArrayPushString(g_ZombieInfo, szInfo);

    get_string(arg_model, szModel, sizeof(szModel));
    if(!precache_model_ex(g_ZombieModel, szModel, "player")) {
        return ERR_REG_CLASS__LACK_OF_RES;
    }

    get_string(arg_handmodel, szHandmodel, sizeof(szHandmodel));
    if(!precache_model_ex(g_ZombieHandModel, szHandmodel, "zombie_hand")) {
        return ERR_REG_CLASS__LACK_OF_RES;
    }

    fHealth = get_param_f(arg_health);
    ArrayPushCell(g_ZombieHP, fHealth);

    fSpeed = get_param_f(arg_speed);
    ArrayPushCell(g_ZombieSpeed, fSpeed);

    fGravity = get_param_f(arg_gravity);
    ArrayPushCell(g_ZombieGravity, fGravity);

    iFlags = get_param(arg_flags);
    ArrayPushCell(g_ZombieFlags, iFlags);

    ExecuteForward(g_Forward[FWD_CLASS_REGISTERED], _, g_ClassesCount, szName);

    return g_ClassesCount++;
}

bool:precache_model_ex(Array:arr, const model[], const path[]) {
    static buffer[MAX_BUFFER_INFO];
    ArrayPushString(arr, model);

    if(equal(path, "player")) {
        formatex(buffer, sizeof(buffer), "models/%s/%s/%s.mdl", path, model, model);
    }
    else {
        formatex(buffer, sizeof(buffer), "models/%s/%s.mdl", path, model);
    }

    if(!file_exists(buffer)) {
        log_amx("Can't find resource '%s'", buffer);
        return false;
    }

    precache_model(buffer);
    return true;
}

public native_zombie_get_class_id(iPlugin, iParams) {
    enum { player = 1 };
    return g_iZombieClass[ get_param(player) ];
}

public native_is_building_phase(iPlugin, iParams) {
    return _:g_bCanBuild;
}

public native_is_preparation_phase(iPlugin, iParams) {
    return _:g_bPrepTime;
}

public native_is_zombies_released(iPlugin, iParams) {
    return _:g_bZombiesReleased;
}
