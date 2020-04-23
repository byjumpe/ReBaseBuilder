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
#include <hamsandwich>
#include <time>
#include <re_basebuilder>

new const VERSION[] = "0.11.30 Alpha";
new const CONFIG_NAME[] = "ReBaseBuilder.cfg";

const Float:MAX_HOLDTIME = 20.0;
//Default zomdie parameters
const Float:ZOMBIE_SPEED = 280.0;
const Float:ZOMBIE_HEALTH = 1000.0;
const Float:ZOMBIE_GRAVITY = 1.0;

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

enum any:DATA_LIST {
    TeamName:LAST_TEAM,     // мб просто сетать в геймлибе тиму? и не хранить это в плагине?
    bool:FIRST_SPAWN,
    ZOMBIE_CLASS,
};

enum FORWARDS_LIST {
    FWD_CLASSES_REG_INIT,
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

new g_PlayerInfo[MAX_PLAYERS + 1][DATA_LIST];

new bool:g_ZombiesReleased;
new bool:g_CanRegister;
new bool:g_SwapTeams;
new bool:g_CanBuild;
new bool:g_IsPrepTime;
new bool:g_IsRoundEnded;

new Array:g_ZombieName;
new Array:g_ZombieInfo;
new Array:g_ZombieModel;
new Array:g_ZombieHandModel;
new Array:g_ZombieHP;
new Array:g_ZombieSpeed;
new Array:g_ZombieGravity;
new Array:g_ZombieFlags;

new g_ZombieClassesCount;
new g_CountTime;

new g_BarrierEnt;
new g_SyncHud;
new g_PluginId;

public plugin_precache() {
    g_PluginId = register_plugin("[ReBB] Core", VERSION, "ReBB");

    RegisterCoreForwards();
    RegisterZombieClasses();
}

public plugin_init() {
    register_dictionary("re_basebuilder.txt");

    RegisterHooks();
    RegisterCvars();

    new const menu_cmd[][] = { "say /zm", "say_team /zm" };
    for(new i; i < sizeof menu_cmd; i++) {
        register_clcmd(menu_cmd[i], "Zombie_Menu");
    }

    new const radio_cmd[][] = { "radio1", "radio2", "radio3" };
    for(new i; i < sizeof radio_cmd; i++) {
        register_clcmd(radio_cmd[i], "BlockRadioCmd");
    }

    register_event("Health", "Event_Health", "be", "1>0");
    set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);

    g_SyncHud = CreateHudSyncObj();
    g_BarrierEnt = FindEntity("func_wall", "barrier");

    if(is_nullent(g_BarrierEnt)) {
        rebb_log(PluginPause, "There is no barrier on this map!");
    }
}

public OnConfigsExecuted() {
    set_member_game(m_GameDesc, g_Cvar[GAME_NAME]);
    register_cvar("re_basebuilder", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED);
}

public plugin_cfg() {
    GetCvarsPointers();
    SetCvarsValues();

    new filedir[MAX_BUFFER_LENGTH];
    get_localinfo("amxx_configsdir", filedir, charsmax(filedir));
    format(filedir, charsmax(filedir), "%s/%s/%s", filedir, REBB_MOD_DIR_NAME, CONFIG_NAME);

    if(file_exists(filedir)) {
        server_cmd("exec %s", filedir);
        server_exec();
    } else {
        rebb_log(PluginPause, "Configuration file '%s' not found!", filedir);
    }
}

public client_putinserver(id) {
    if(is_user_bot(id) || is_user_hltv(id)) {
        return PLUGIN_HANDLED;
    }

    set_member(id, m_bIgnoreRadio, true);
    g_PlayerInfo[id][LAST_TEAM] = get_member(id, m_iTeam);

    return PLUGIN_HANDLED;
}

public client_disconnected(id) {
    g_PlayerInfo[id][LAST_TEAM] = TEAM_UNASSIGNED;
    g_PlayerInfo[id][FIRST_SPAWN] = true;
    g_PlayerInfo[id][ZOMBIE_CLASS] = 0;   

    remove_task(id + TASK_RESPAWN);
    remove_task(id + TASK_HEALTH);
}

public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event) {
    g_IsRoundEnded = true;
    g_CanBuild = false;
    g_IsPrepTime = false;

    new players[MAX_PLAYERS], count, player;
    get_players(players, count);

    for(new i; i < count; i++) {
        player = players[i];

        remove_task(player+TASK_RESPAWN);
    }

    remove_task(TASK_BUILDTIME);
    remove_task(TASK_PREPTIME);

    switch(event) {
        case ROUND_HUMANS_WIN: {
            g_SwapTeams = true;
            client_print(0, print_center, "%L", LANG_PLAYER, "REBB_BUILDERS_WIN");
        }
        case ROUND_ZOMBIES_WIN: {
            g_SwapTeams = true;
            client_print(0, print_center, "%L", LANG_PLAYER, "REBB_ZOMBIE_WIN");
        }
        case ROUND_GAME_OVER: {
            g_SwapTeams = true;
            rg_update_teamscores(1, 0, true);
            client_print(0, print_center, "%L", LANG_PLAYER, "REBB_BUILDERS_WIN");
        }
        default: {
            client_print(0, print_center, ""); // clear print_center as we don't print anything else
        }
    }
}

public CBasePlayer_DropPlayerItem_Pre(const id) {
    if(!g_Cvar[BLOCK_DROP_WEAPON]) {
        return HC_CONTINUE;
    }

    client_printex(id, print_center, "#Weapon_Cannot_Be_Dropped");
    SetHookChainReturn(ATYPE_INTEGER, 0);

    return HC_SUPERCEDE;
}

public CBasePlayer_HasRestrictItem_Pre(const id) {
    if(!is_user_connected(id) || !is_user_zombie(id)) {
        return HC_CONTINUE;
    }
    
    SetHookChainReturn(ATYPE_BOOL, true);
    return HC_SUPERCEDE;
}

public CBasePlayer_OnSpawnEquip_Pre(const id, bool:bAddDefault, bool:bEquipGame) {
    if(!is_user_connected(id)) {
        return HC_CONTINUE;
    }

    rebb_grab_stop(id);
    rg_remove_all_items(id);

    rg_set_user_armor(id, 0, ARMOR_NONE);
    rg_give_item(id, "weapon_knife", GT_APPEND);

    return HC_SUPERCEDE;
}

public CBasePlayer_Spawn_Post(const id) {
    if(!is_user_alive(id)) {
        return HC_CONTINUE;
    }

    remove_task(id + TASK_HEALTH);
    remove_task(id + TASK_RESPAWN);

    // Бредовая идея, ибо тима может быть спектры т.к. это нигде не обработано
    if(g_PlayerInfo[id][LAST_TEAM] == TEAM_UNASSIGNED) {
        g_PlayerInfo[id][LAST_TEAM] = get_member(id, m_iTeam);
    }

    if(g_PlayerInfo[id][LAST_TEAM] != TEAM_ZOMBIE) {
        if(g_IsPrepTime) {
            rebb_open_guns_menu(id);
        }

        rg_reset_user_model(id, true);
    } else {
        if(g_PlayerInfo[id][FIRST_SPAWN]) {
            Zombie_Menu(id);
            g_PlayerInfo[id][FIRST_SPAWN] = false;
        }

        if(ArrayFindValue(g_ZombieHP, g_PlayerInfo[id][ZOMBIE_CLASS]) != -1) {
            set_entvar(id, var_health, Float:ArrayGetCell(g_ZombieHP, g_PlayerInfo[id][ZOMBIE_CLASS]));
        } else {
            set_entvar(id, var_health, ZOMBIE_HEALTH);
        }

        if(ArrayFindValue(g_ZombieGravity, g_PlayerInfo[id][ZOMBIE_CLASS]) != -1) {
            set_entvar(id, var_gravity, Float:ArrayGetCell(g_ZombieGravity, g_PlayerInfo[id][ZOMBIE_CLASS]));
        } else {
            set_entvar(id, var_gravity, ZOMBIE_GRAVITY);
        }

        new zombie_model[MAX_BUFFER_LENGTH];
        ArrayGetString(g_ZombieModel, g_PlayerInfo[id][ZOMBIE_CLASS], zombie_model, charsmax(zombie_model));
        rg_set_user_model(id, zombie_model, true);
    }

    set_task_ex(MAX_HOLDTIME, "taskPlayerHud", id+TASK_HEALTH, .flags = SetTask_Repeat);

    return HC_CONTINUE;
}

public CBasePlayer_ResetMaxSpeed_Post(id) {
    if(!is_user_alive(id)) {
        return HC_CONTINUE;
    }

    if(is_user_zombie(id)) {
        // NOTE: this will break any external speed modificator (like temporary speed bost item in zombie escape)
        if(ArrayFindValue(g_ZombieSpeed, g_PlayerInfo[id][ZOMBIE_CLASS]) != -1) {
            set_entvar(id, var_maxspeed, Float:ArrayGetCell(g_ZombieSpeed, g_PlayerInfo[id][ZOMBIE_CLASS]));
        } else {
            set_entvar(id, var_maxspeed, ZOMBIE_SPEED);
        }
    }

    return HC_CONTINUE;
}

public CBasePlayer_Killed_Post(victim, iKiller, iGibType) {
    if(!is_user_connected(victim)) {
        return HC_CONTINUE;
    }

    rebb_grab_stop(victim);

    remove_task(victim + TASK_HEALTH);
    ClearSyncHud(victim, g_SyncHud);

    new team = get_member(victim, m_iTeam);
    if(team == TEAM_ZOMBIE) {
        if(g_Cvar[ZOMBIE_RESPAWN_DELAY] && !g_IsRoundEnded) {
            if(g_Cvar[ZOMBIE_RESPAWN_DELAY] >= 1.0) {
                client_print(victim, print_center, "%L", LANG_PLAYER, "REBB_ZOMBIE_RESPAWN", g_Cvar[ZOMBIE_RESPAWN_DELAY]);
            }

            set_task_ex(g_Cvar[ZOMBIE_RESPAWN_DELAY], "Respawn", victim + TASK_RESPAWN);
        }
    }

    if(team == TEAM_HUMANS && victim != iKiller) {
        rg_set_user_team(victim, TEAM_TERRORIST);
        client_print(0, print_center, "%L", LANG_PLAYER, "REBB_INFECTION", victim);

        ExecuteForward(g_Forward[FWD_INFECTED]);

        if(g_Cvar[INFECTION_RESPAWN_DELAY] && !g_IsRoundEnded) {
            if(g_Cvar[INFECTION_RESPAWN_DELAY] >= 1.0) {
                client_print(victim, print_center, "%L", LANG_PLAYER, "REBB_INFECTION_RESPAWN", g_Cvar[INFECTION_RESPAWN_DELAY]);
            }

            set_task_ex(g_Cvar[INFECTION_RESPAWN_DELAY], "Respawn", victim + TASK_RESPAWN);
        }
    }

    return HC_CONTINUE;
}

public Ham_Item_Deploy_Post(weapon) {
    new id = get_member(weapon, m_pPlayer);
    if(!is_user_authorized(id) || !is_user_zombie(id)) {
        return HAM_IGNORED;
    }

    new hand_model[MAX_BUFFER_LENGTH];
    ArrayGetString(g_ZombieHandModel, g_PlayerInfo[id][ZOMBIE_CLASS], hand_model, charsmax(hand_model));

    set_entvar(id, var_viewmodel, hand_model);
    set_entvar(id, var_weaponmodel, 0);

    return HAM_IGNORED;
}

public CSGameRules_RestartRound_Pre() {
    g_IsRoundEnded = false;
    g_ZombiesReleased = false;

    set_entvar(g_BarrierEnt, var_solid, SOLID_BSP);
    set_entvar(g_BarrierEnt, var_rendermode, kRenderTransColor);
    set_entvar(g_BarrierEnt, var_rendercolor, Float:{ 0.0, 0.0, 0.0 });
    set_entvar(g_BarrierEnt, var_renderamt, 150.0);

    g_CountTime = g_Cvar[BUILDING_TIME] + 1;
    set_task_ex(0.1, "BuildTime", TASK_BUILDTIME);
    set_task_ex(1.0, "BuildTime", TASK_BUILDTIME, .flags = SetTask_Repeat);

    new players[MAX_PLAYERS], count;
    get_players(players, count);

    if(g_SwapTeams) {
        for(new i, player; i < count; i++) {
            player = players[i];

            if(g_PlayerInfo[player][LAST_TEAM] != TEAM_UNASSIGNED && is_valid_team(player)) {
                rg_set_user_team(player, g_PlayerInfo[player][LAST_TEAM] == TEAM_ZOMBIE ? TEAM_HUMANS : TEAM_ZOMBIE);
            }
        }

        g_SwapTeams = false;
    }

    for(new i; i < count; i++) {
        g_PlayerInfo[players[i]][LAST_TEAM] = TEAM_UNASSIGNED;
    }
}

public BuildTime() {
    if(!g_CanBuild) {
        g_CanBuild = true;
        ExecuteForward(g_Forward[FWD_BUILD_START], _, g_CountTime);
    }

    g_CountTime--;

    if(g_CountTime) {
        new min = g_CountTime / SECONDS_IN_MINUTE;
        new sec = g_CountTime % SECONDS_IN_MINUTE;

        client_print(0, print_center, "%L %02d:%02d", LANG_PLAYER, "REBB_BUILD_TIME", min, sec);
    } else {
        g_CanBuild = false;
        remove_task(TASK_BUILDTIME);
        client_print(0, print_center, ""); // clear print_center

        new players[MAX_PLAYERS], count;
        get_players_ex(players, count, GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "CT");

        for(new i; i < count; i++) {
            rebb_grab_stop(players[i]);
        }

        g_IsPrepTime = true;

        if(!g_Cvar[PREPARATION_TIME]) {
            ExecuteForward(g_Forward[FWD_PREPARATION_START], _, g_Cvar[PREPARATION_TIME]);
            Release_Zombies();
        } else {
            g_CountTime = g_Cvar[PREPARATION_TIME] + 1;

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
    g_CountTime--;

    if(g_CountTime) {
        new min = g_CountTime / SECONDS_IN_MINUTE;
        new sec = g_CountTime % SECONDS_IN_MINUTE;

        client_print(0, print_center, "%L %02d:%02d", LANG_PLAYER, "REBB_PREP_TIME", min, sec);
    } else {
        remove_task(TASK_PREPTIME);
        Release_Zombies();
    }
}

public Release_Zombies() {
    g_IsPrepTime = false;
    g_ZombiesReleased = true;

    set_entvar(g_BarrierEnt, var_solid, SOLID_NOT);
    set_entvar(g_BarrierEnt, var_renderamt, 0.0);

    client_print_color(0, print_team_default, "%L", LANG_PLAYER, "REBB_ZOMBIE_RELEASE");

    ExecuteForward(g_Forward[FWD_ZOMBIES_RELEASED]);
}

public Zombie_Menu(id){
    if(g_ZombiesReleased) {
        return PLUGIN_HANDLED;
    }

    new menu = menu_create(fmt("%L", LANG_PLAYER, "REBB_ZOMBIE_MENU"), "Zombie_Menu_Handler");
    for(new i, name[MAX_NAME_LENGTH], info[MAX_CLASS_INFO_LENGTH], flag; i < g_ZombieClassesCount; i++) {
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

    g_PlayerInfo[id][ZOMBIE_CLASS] = item;

    client_print_color(id, print_team_default, "%L ^4%a", LANG_PLAYER, "REBB_ZOMBIE_PICK", ArrayGetStringHandle(g_ZombieName, item)); // TEST

    if(is_user_zombie(id) && !g_ZombiesReleased && !g_IsRoundEnded && !task_exists(id + TASK_RESPAWN)) {
        rg_round_respawn(id);
    }
}

public taskPlayerHud(taskid) {
    UpdateHUD(taskid - TASK_HEALTH);
}

public Event_Health(id) {
    UpdateHUD(id);
}

UpdateHUD(const index) {
    set_hudmessage(g_HudColor[R], g_HudColor[G], g_HudColor[B], 0.02, 0.95, .holdtime = MAX_HOLDTIME, .channel = -1);
    ShowSyncHudMsg(index, g_SyncHud, "[%.0f HP]", Float:get_entvar(index, var_health));
}

public Respawn(id) {
    id -= TASK_RESPAWN;

    if(is_user_zombie(id)) {
        rg_round_respawn(id);
    }
}

RegisterHooks() {
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
    g_Forward[FWD_CLASSES_REG_INIT] = CreateMultiForward("rebb_classes_registration_init", ET_IGNORE);
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
    for(new i; i < MULTYPLAY_CVARS; i++) {
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
    new ent, tname[MAX_NAME_LENGTH];
    while((ent = rg_find_ent_by_class(ent, entityname))) {
        get_entvar(ent, var_targetname, tname, charsmax(tname));

        if(equali(tname, targetname)) {
            return ent;
        }
    }

    return NULLENT;
}

RegisterZombieClasses() {
    g_ZombieName = ArrayCreate(MAX_NAME_LENGTH, 1);
    g_ZombieInfo = ArrayCreate(MAX_CLASS_INFO_LENGTH, 1);
    g_ZombieModel = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1);
    g_ZombieHandModel = ArrayCreate(MAX_RESOURCE_PATH_LENGTH, 1);
    g_ZombieHP = ArrayCreate(1, 1);
    g_ZombieSpeed = ArrayCreate(1, 1);
    g_ZombieGravity = ArrayCreate(1, 1);
    g_ZombieFlags = ArrayCreate(1, 1);

    g_CanRegister = true;

    ExecuteForward(g_Forward[FWD_CLASSES_REG_INIT]);

    if(!g_ZombieClassesCount) {
        rebb_log(PluginPause, "Registered zombie classes not found!");
    }
}

public plugin_natives() {
    register_native("rebb_core_is_running", "native_core_is_running");
    register_native("rebb_register_zombie_class", "native_register_zombie_class");
    register_native("rebb_get_player_class_index", "native_get_player_class_index");
    register_native("rebb_set_zombie_model", "native_set_zombie_model");
    register_native("rebb_set_zombie_handmodel", "native_set_zombie_handmodel");
    register_native("rebb_set_zombie_health", "native_set_zombie_health");
    register_native("rebb_set_zombie_speed", "native_set_zombie_speed");
    register_native("rebb_set_zombie_gravity", "native_set_zombie_gravity");
    register_native("rebb_is_building_phase", "native_is_building_phase");
    register_native("rebb_is_preparation_phase", "native_is_preparation_phase");
    register_native("rebb_is_zombies_released", "native_is_zombies_released");
    register_native("rebb_get_barrier_ent_index", "native_get_barrier_ent_index");
}

public native_core_is_running(const plugin, const argc) {
    if(g_PluginId == INVALID_PLUGIN_ID) {
        return false;
    }

    new status[2];
    if(get_plugin(g_PluginId, .status = status, .len5 = charsmax(status)) == INVALID_PLUGIN_ID) {
        return false;
    }

    return bool:(status[0] == 'r' || status[0] == 'd');
}

public native_register_zombie_class(const plugin, const argc) {
    enum { arg_name = 1, arg_info, arg_flags };

    if(!g_CanRegister) {
        return ERR_REG_CLASS__WRONG_PLACE;
    }

    if(argc < 8) {
        log_error(AMX_ERR_NATIVE, "Invalid num of arguments (%d)! Expected (%d).", argc, 8);
        return INVALID_ZOMBIE_CLASS;
    }

    new name[MAX_NAME_LENGTH];
    get_string(arg_name, name, sizeof(name));

    if(!strlen(name)) {
        log_error(AMX_ERR_NATIVE, "Name information buffer cannot be empty!");
        return INVALID_ZOMBIE_CLASS;
    }

    ArrayPushString(g_ZombieName, name);

    new class_info[MAX_CLASS_INFO_LENGTH];
    get_string(arg_info, class_info, sizeof(class_info));

    if(!strlen(class_info)) {
        log_error(AMX_ERR_NATIVE, "A brief description of the class cannot be empty!");
        return INVALID_ZOMBIE_CLASS;
    }

    ArrayPushString(g_ZombieInfo, class_info);

    new flags = get_param(arg_flags);
    ArrayPushCell(g_ZombieFlags, flags);

    ExecuteForward(g_Forward[FWD_CLASS_REGISTERED], _, g_ZombieClassesCount, name);

    return g_ZombieClassesCount++;
}

public native_get_player_class_index(const plugin, const argc) {
    enum { arg_player = 1 };

    new player = get_param(arg_player);
    if(!is_user_authorized(player)) {
        log_error(AMX_ERR_NATIVE, "Invalid player (%d).", player);
        return INVALID_ZOMBIE_CLASS;
    }

    return g_PlayerInfo[player][ZOMBIE_CLASS];
}

public native_set_zombie_model(const plugin, const argc) {
    enum { arg_classid = 1, arg_model};

    new classid = get_param(arg_classid);
    if(0 < classid <= g_ZombieClassesCount) {
        log_error(AMX_ERR_NATIVE, "Invalid zombie class id (%d).", classid);
        return INVALID_ZOMBIE_CLASS;
    }

    new model[MAX_RESOURCE_PATH_LENGTH];
    get_string(arg_model, model, sizeof(model));

    static buffer[MAX_BUFFER_LENGTH];
    formatex(buffer, charsmax(buffer), "models/player/%s/%s.mdl", model, model);
    ArrayPushString(g_ZombieModel, model);

    if(!file_exists(buffer)) {
        rebb_log(PluginStateIgnore, "Can't find resource '%s'", buffer);
        return false;
    }
}

public native_set_zombie_handmodel(const plugin, const argc) {
    enum { arg_classid = 1, arg_model};

    new classid = get_param(arg_classid);
    if(0 < classid <= g_ZombieClassesCount) {
        log_error(AMX_ERR_NATIVE, "Invalid zombie class id (%d).", classid);
        return INVALID_ZOMBIE_CLASS;
    }

    new model[MAX_RESOURCE_PATH_LENGTH];
    get_string(arg_model, model, sizeof(model));

    static buffer[MAX_BUFFER_LENGTH];
    formatex(buffer, charsmax(buffer), "models/zombie_hands/%s.mdl", model);
    ArrayPushString(g_ZombieHandModel, buffer);
    
    if(!file_exists(buffer)) {
        rebb_log(PluginStateIgnore, "Can't find resource '%s'", buffer);
        return false;
    }
}

public native_set_zombie_health(const plugin, const argc) {
    enum { arg_classid = 1, arg_health};

    new classid = get_param(arg_classid);
    if(0 < classid <= g_ZombieClassesCount) {
        log_error(AMX_ERR_NATIVE, "Invalid zombie class id (%d).", classid);
        return INVALID_ZOMBIE_CLASS;
    }

    new Float:health = get_param_f(arg_health);
    ArrayPushCell(g_ZombieHP, floatmax(0.0, health));
}

public native_set_zombie_speed(const plugin, const argc) {
    enum { arg_classid = 1, arg_speed};

    new classid = get_param(arg_classid);
    if(0 < classid <= g_ZombieClassesCount) {
        log_error(AMX_ERR_NATIVE, "Invalid zombie class id (%d).", classid);
        return INVALID_ZOMBIE_CLASS;
    }

    new Float:speed = get_param_f(arg_speed);
    ArrayPushCell(g_ZombieSpeed, floatmax(0.0, speed));
}

public native_set_zombie_speed(const plugin, const argc) {
    enum { arg_classid = 1, arg_speed};

    new classid = get_param(arg_classid);
    if(0 < classid <= g_ZombieClassesCount) {
        log_error(AMX_ERR_NATIVE, "Invalid zombie class id (%d).", classid);
        return INVALID_ZOMBIE_CLASS;
    }

    new Float:speed = get_param_f(arg_speed);
    ArrayPushCell(g_ZombieSpeed, floatmax(0.0, speed));
}

public native_set_zombie_gravity(const plugin, const argc) {
    enum { arg_classid = 1, arg_speed};

    new classid = get_param(arg_classid);
    if(0 < classid <= g_ZombieClassesCount) {
        log_error(AMX_ERR_NATIVE, "Invalid zombie class id (%d).", classid);
        return INVALID_ZOMBIE_CLASS;
    }

    new Float:gravity = get_param_f(arg_gravity);
    ArrayPushCell(g_ZombieGravity, floatmax(0.0, gravity));
}

public native_is_building_phase(const plugin, const argc) {
    return bool:g_CanBuild;
}

public native_is_preparation_phase(const plugin, const argc) {
    return bool:g_IsPrepTime;
}

public native_is_zombies_released(const plugin, const argc) {
    return bool:g_ZombiesReleased;
}

public native_get_barrier_ent_index(const plugin, const argc) {
    return g_BarrierEnt;
}
