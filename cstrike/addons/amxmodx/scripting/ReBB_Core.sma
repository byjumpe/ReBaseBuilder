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

new const VERSION[] = "0.3.11 Alpha";

new const CONFIG_NAME[] = "ReBaseBuilder.cfg";
// List of client commands that open zombie class menu
new const MENU_CMDS[][] = {
    "say /zm",
    "say_team /zm"
};

new const RADIO_CMDS[][] = {
    "radio1",
    "radio2",
    "radio3"
};

#define MAX_CLASS_INFO_LENGTH   32
#define MAX_BUFFER_LENGTH       128

const Float:MAX_HOLDTIME            = 20.0;

enum COLOR { R, G, B };

enum (+= 100) {
    TASK_BUILDTIME = 100,
    TASK_PREPTIME,
    TASK_RESPAWN,
    TASK_HEALTH
};

enum any:CVAR_LIST {
    GAME_NAME[MAX_NAME_LENGTH],
    BUILDING_TIME,
    PREPARATION_TIME,
    Float:ZOMBIE_RESPAWN_DELAY,
    Float:INFECTION_RESPAWN_DELAY,
    BLOCK_DROP_WEAPON,
};

enum any:MULTYPLAY_CVARS {
    MP_BUYTIME,
    MP_ROUNDOVER,
};

enum FORWARDS_LIST {
    FWD_CLASS_REG_REQUEST,
    FWD_CLASS_REGISTERED,
    FWD_BUILD_START,
    FWD_PREPARATION_START,
    FWD_ZOMBIES_RELEASED,
    FWD_INFECTED
};

new const g_HudColor[COLOR] = { 255, 0, 0 };
new const g_MpCvars[MULTYPLAY_CVARS][] = {
    "mp_buytime",
    "mp_roundover",
};

new g_Pointer[MULTYPLAY_CVARS];
new g_Forward[FORWARDS_LIST];

new g_Cvar[CVAR_LIST];

new g_BarrierEnt;

new TeamName:g_iTeam[MAX_PLAYERS +1], g_iCountTime, g_iZombieClass[MAX_PLAYERS +1];
new bool: g_bFirstSpawn[MAX_PLAYERS +1], bool: g_bSwapTeams, bool: g_bCanBuild, bool: g_bPrepTime, bool: g_bRoundEnded;
new bool: g_bZombiesReleased;

new bool:g_bCanRegister;

new Array: g_ZombieName;
new Array: g_ZombieInfo;
new Array: g_ZombieModel;
new Array: g_ZombieHandModel;
new Array: g_ZombieHP;
new Array: g_ZombieSpeed;
new Array: g_ZombieGravity;
new Array: g_ZombieFlags;
new g_ClassesCount;

new g_SyncHud;

new g_msgSendAudio;
new g_hMsgSendAudio;

#define IsValidTeam(%1)             (TEAM_TERRORIST <= get_member(%1, m_iTeam) <= TEAM_CT)

public plugin_precache() {
    register_plugin("[ReAPI] Base Builder", VERSION, "ReBB");

    RegisterCoreForwards();

    // TODO: перевести магические цифры в константы
    g_ZombieName = ArrayCreate(MAX_NAME_LENGTH, 1);
    g_ZombieInfo = ArrayCreate(MAX_CLASS_INFO_LENGTH, 1);
    g_ZombieModel = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1);
    g_ZombieHandModel = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1);
    g_ZombieHP = ArrayCreate(1, 1);
    g_ZombieSpeed = ArrayCreate(1, 1);
    g_ZombieGravity = ArrayCreate(1, 1);
    g_ZombieFlags = ArrayCreate(1, 1);

    g_bCanRegister = true;

    ExecuteForward(g_Forward[FWD_CLASS_REG_REQUEST]);

    if(!g_ClassesCount) {
        set_fail_state("Registered zombie classes not found!");
    }

    new sConfigsDir[PLATFORM_MAX_PATH];
    get_localinfo("amxx_configsdir", sConfigsDir, charsmax(sConfigsDir));
    server_cmd("exec %s/%s/%s", sConfigsDir, REBB_MOD_DIR_NAME, CONFIG_NAME);
    server_exec();
}

public plugin_init() {
    register_dictionary("re_basebuilder.txt");

    RegisterHooks();
    RegisterCvars();

    for(new i; i < sizeof(MENU_CMDS); i++) {
        register_clcmd(MENU_CMDS[i], "Zombie_Menu");
    }
    new const szBlockCallBack[] = "BlockRadioCmd";
    for(new i; i < sizeof(RADIO_CMDS); i++) {
            register_clcmd(RADIO_CMDS[i], szBlockCallBack);
    }

    g_msgSendAudio = get_user_msgid("SendAudio");

    register_event("Health", "Event_Health", "be", "1>0");
    set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);

    g_SyncHud = CreateHudSyncObj();
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

    remove_task(id+TASK_RESPAWN);
    remove_task(id+TASK_HEALTH);
}

public RoundEnd_Pre(WinStatus:status, ScenarioEventEndRound:event) {
    g_hMsgSendAudio = register_message(g_msgSendAudio, "Msg_SendAudio");
}

public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event) {
    unregister_message(g_msgSendAudio, g_hMsgSendAudio);

    g_bRoundEnded = true;
    g_bCanBuild = false;
    g_bPrepTime = false;

    new players[MAX_PLAYERS], count, player;
    get_players(players, count);

    for(new i; i < count; i++) {
        player = players[i];

        remove_task(player+TASK_RESPAWN);
    }

    remove_task(TASK_BUILDTIME);
    remove_task(TASK_PREPTIME);
    switch(event) {
        case ROUND_CTS_WIN: {
            g_bSwapTeams = true;
            client_print(0, print_center, "%L", LANG_PLAYER, "REBB_BUILDERS_WIN");
        }
        case ROUND_TERRORISTS_WIN: {
            g_bSwapTeams = true;
            client_print(0, print_center, "%L", LANG_PLAYER, "REBB_ZOMBIE_WIN");
        }
        case ROUND_GAME_OVER: {
            g_bSwapTeams = true;
            rg_update_teamscores(1, 0, true);
            client_print(0, print_center, "%L", LANG_PLAYER, "REBB_BUILDERS_WIN");
        }
        default: {
            client_print(0, print_center, ""); // clear print_center as we don't print anything else
        }
    }
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

    rebb_grab_stop(id);

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
        if(g_bPrepTime){
            rebb_open_guns_menu(id);
        }
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

    rebb_grab_stop(iVictim);

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
        ExecuteForward(g_Forward[FWD_INFECTED]);

        if(g_Cvar[INFECTION_RESPAWN_DELAY] && !g_bRoundEnded) {
            if(g_Cvar[INFECTION_RESPAWN_DELAY] >= 1.0) {
                client_print(iVictim, print_center, "%L", LANG_PLAYER, "REBB_INFECTION_RESPAWN", g_Cvar[INFECTION_RESPAWN_DELAY]);
            }
            set_task_ex(g_Cvar[INFECTION_RESPAWN_DELAY], "Respawn", iVictim+TASK_RESPAWN);
        }
    }
}

public Ham_Item_Deploy_Post(weapon) {
    new id = get_member(weapon, m_pPlayer);

    if(IsConnected(id) && IsZombie(id)) {
        set_entvar(id, var_viewmodel, fmt("models/zombie_hand/%a.mdl", ArrayGetStringHandle(g_ZombieHandModel, g_iZombieClass[id]))); // TEST
        set_entvar(id, var_weaponmodel, "");
    }
}

public CSGameRules_RestartRound_Pre() {
    g_bRoundEnded = false;
    g_bZombiesReleased = false;

    set_entvar(g_BarrierEnt, var_solid, SOLID_BSP);
    set_entvar(g_BarrierEnt, var_rendermode, kRenderTransColor);
    set_entvar(g_BarrierEnt, var_rendercolor, Float:{ 0.0, 0.0, 0.0 });
    set_entvar(g_BarrierEnt, var_renderamt, 150.0);

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

public BuildTime() {
    if(!g_bCanBuild) {
        g_bCanBuild = true;
        ExecuteForward(g_Forward[FWD_BUILD_START], _, g_iCountTime);
    }

    g_iCountTime--;

    if(g_iCountTime) {
        new iMins = g_iCountTime / SECONDS_IN_MINUTE, iSecs = g_iCountTime % SECONDS_IN_MINUTE;
        client_print(0, print_center, "%L %02d:%02d", LANG_PLAYER, "REBB_BUILD_TIME", iMins, iSecs);
    }
    else {
        g_bCanBuild = false;
        remove_task(TASK_BUILDTIME);
        client_print(0, print_center, ""); // clear print_center

        new players[MAX_PLAYERS], count;
        get_players_ex(players, count, GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "CT");

        for(new i; i < count; i++) {
            rebb_grab_stop(players[i]);
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

            client_print_color(0, print_team_default, "%L", LANG_PLAYER, "REBB_PREP_BUILDERS_SPAWN");

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

    if(g_iCountTime) {
        new iMins = g_iCountTime / SECONDS_IN_MINUTE, iSecs = g_iCountTime % SECONDS_IN_MINUTE;
        client_print(0, print_center, "%L %02d:%02d", LANG_PLAYER, "REBB_PREP_TIME", iMins, iSecs);
    }
    else {
        remove_task(TASK_PREPTIME);
        Release_Zombies();
    }
}

public Release_Zombies() {
    g_bPrepTime = false;
    g_bZombiesReleased = true;

    set_entvar(g_BarrierEnt, var_solid, SOLID_NOT);
    set_entvar(g_BarrierEnt, var_renderamt, 0.0);

    client_print_color(0, print_team_default, "%L", LANG_PLAYER, "REBB_ZOMBIE_RELEASE");

    ExecuteForward(g_Forward[FWD_ZOMBIES_RELEASED]);
}

public Zombie_Menu(id){
    if(g_bZombiesReleased) {
        return PLUGIN_HANDLED;
    }

    new menu = menu_create(fmt("%L", LANG_PLAYER, "REBB_ZOMBIE_MENU"), "Zombie_Menu_Handler");

    for(new i, name[MAX_NAME_LENGTH], info[MAX_CLASS_INFO_LENGTH], flag; i < g_ClassesCount; i++) {
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

    RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Item_Deploy_Post", true);
}

RegisterCoreForwards() {
    g_Forward[FWD_CLASS_REG_REQUEST] = CreateMultiForward("rebb_class_reg_request", ET_IGNORE);
    g_Forward[FWD_CLASS_REGISTERED] = CreateMultiForward("rebb_class_registered", ET_IGNORE, FP_CELL, FP_STRING);
    g_Forward[FWD_BUILD_START] = CreateMultiForward("rebb_build_start", ET_IGNORE, FP_CELL);
    g_Forward[FWD_PREPARATION_START] = CreateMultiForward("rebb_preparation_start", ET_IGNORE, FP_CELL);
    g_Forward[FWD_ZOMBIES_RELEASED] = CreateMultiForward("rebb_zombies_released", ET_IGNORE);
    g_Forward[FWD_INFECTED] = CreateMultiForward("rebb_infected", ET_IGNORE);
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

}

GetCvarsPointers() {
    for(new i; i < sizeof g_MpCvars; i++) {
        g_Pointer[i] = get_cvar_pointer(g_MpCvars[i]);
    }
}

SetCvarsValues() {
    set_pcvar_num(g_Pointer[MP_BUYTIME], 0);
    set_pcvar_num(g_Pointer[MP_ROUNDOVER], 1);
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

public plugin_natives() {
    register_native("rebb_register_zombie_class", "native_register_zombie_class");
    register_native("rebb_get_class_id", "native_zombie_get_class_id");
    register_native("rebb_is_building_phase", "native_is_building_phase");
    register_native("rebb_is_preparation_phase", "native_is_preparation_phase");
    register_native("rebb_is_zombies_released", "native_is_zombies_released");
    register_native("rebb_barrier_ent", "native_barrier_ent");
}

public native_register_zombie_class(iPlugin, iParams) {
    enum { arg_name = 1, arg_info, arg_model, arg_handmodel, arg_health, arg_speed, arg_gravity, arg_flags };

    if(!g_bCanRegister) {
        return ERR_REG_CLASS__WRONG_PLACE;
    }

    new szName[MAX_NAME_LENGTH], szInfo[MAX_CLASS_INFO_LENGTH], szModel[MAX_RESOURCE_PATH_LENGTH], szHandmodel[MAX_RESOURCE_PATH_LENGTH];
    new Float:fHealth, Float:fSpeed, Float:fGravity, iFlags;

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
    static buffer[MAX_BUFFER_LENGTH];
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

public native_barrier_ent(iPlugin, iParams) {
    return g_BarrierEnt;
}
