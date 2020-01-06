/* TODO: сделать возможность блокировать блоки */
/* TODO: меню оружия для хуманов */
/* TODO: валюту в отдельном плугине и прочую лабудень */

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
#include <engine>
#include <hamsandwich>
#include <reapi>
#include <re_basebuilder>
//#include <xs>

//#define AUTO_CFG                                  // Автосоздание конфига 

new const VERSION[] = "0.1.6 Alpha";

#define MAX_BUFFER_INFO 128

const Float:MAX_MOVE_DISTANCE = 768.0;
const Float:MIN_MOVE_DISTANCE = 32.0;
const Float:MIN_DIST_SET = 64.0;

const Float:OBJECT_PUSHPULLRATE     = 4.0;
const Float:MAX_HOLDTIME            = 20.0;

enum COLOR { R, G, B };
enum any:POS { Float:X, Float:Y, Float:Z };

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
    Float:INFECTION_RESPAWN_DELAY
};

enum any:MULTYPLAY_CVARS {
    MP_BUYTIME,
    MP_ROUNDOVER,
    MP_ITEM_STAYTIME
};

enum FORWARDS_LIST {
    FWD_CLASS_REG_REQUEST,
    FWD_CLASS_REGISTERED,
    FWD_PUSH_PULL,
    FWD_GRAB_ENTITY_PRE,
    FWD_GRAB_ENTITY_POST,
    FWD_DROP_ENTITY_PRE,
    FWD_DROP_ENTITY_POST 
};

new const g_HudColor[COLOR] = { 255, 0, 0 };
new const g_MpCvars[MULTYPLAY_CVARS][] = {
    "mp_buytime",
    "mp_roundover",
    "mp_item_staytime"
};

new g_Pointer[MULTYPLAY_CVARS];
new g_Forward[FORWARDS_LIST];
new g_FwdReturn;

new g_Cvar[CVAR_LIST];

new g_BarrierEnt;

new Float: g_fEntDist[MAX_PLAYERS +1];
new TeamName:g_iTeam[MAX_PLAYERS +1], g_iCountTime, g_iOwnedEnt[MAX_PLAYERS +1], g_iZombieClass[MAX_PLAYERS +1], g_szModel[128];
new bool: g_bFirstSpawn[MAX_PLAYERS +1], bool: g_bRoundEnd, bool: g_bCanBuild;
new Float: g_fOffset1[MAX_PLAYERS +1], Float: g_fOffset2[MAX_PLAYERS +1], Float: g_fOffset3[MAX_PLAYERS +1];

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

#define LockBlock(%1,%2)            (set_entvar(%1, var_iuser1, %2))
#define UnlockBlock(%1)             (set_entvar(%1, var_iuser1, 0))
#define BlockLocker(%1)             (get_entvar(%1, var_iuser1))

#define MovingEnt(%1)               (set_entvar(%1, var_iuser2, 1))
#define UnmovingEnt(%1)             (set_entvar(%1, var_iuser2, 0))
#define IsMovingEnt(%1)             (get_entvar(%1, var_iuser2) == 1)

#define SetEntMover(%1,%2)          (set_entvar(%1, var_iuser3, %2))
#define UnsetEntMover(%1)           (set_entvar(%1, var_iuser3, 0))

#define PlayerTask(%1)              (%1 + TASK_HEALTH)
#define GetPlayerByTaskID(%1)       (%1 - TASK_HEALTH)

#define IsValidTeam(%1)             (TEAM_TERRORIST <= get_member(%1, m_iTeam) <= TEAM_CT)
#define GetCvarDesc(%0)             fmt("%L", LANG_SERVER, %0)

public plugin_precache() {
    RegisterCoreForwards();

    g_ZombieName = ArrayCreate(32, 1);
    g_ZombieInfo = ArrayCreate(32, 1);
    g_ZombieModel = ArrayCreate(64, 1);
    g_ZombieHandModel = ArrayCreate(64, 1);
    g_ZombieHP = ArrayCreate(1, 1);
    g_ZombieSpeed = ArrayCreate(1, 1);
    g_ZombieGravity = ArrayCreate(1, 1);
    g_ZombieFlags = ArrayCreate(1, 1);
    
    g_bCanRegister = true;
    
    ExecuteForward(g_Forward[FWD_CLASS_REG_REQUEST], g_FwdReturn);
    
    if(!g_ClassesCount) {
        set_fail_state("Registered zombie classes not found!");
    }
}

public plugin_init() {
    register_plugin("[ReAPI] Base Builder", VERSION, "ReBB");

    register_clcmd("say /zm", "Zombie_Menu");
    register_clcmd("say_team /zm", "Zombie_Menu");

    register_message(get_user_msgid("SendAudio"), "Msg_SendAudio");
    register_event("Health", "Event_Health", "be", "1>0");

    RegisterForwards();
    RegisterCvars();

#if defined AUTO_CFG  
    AutoExecConfig(true, "ReBaseBuilder");
#endif

    set_member_game(m_GameDesc, g_Cvar[GAME_NAME]);
    set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);

    g_SyncHud = CreateHudSyncObj();
    g_BarrierEnt = find_ent_by_tname(NULLENT, "barrier");
    //g_BarrierEnt = FindEntity("func_wall", "barrier");

    if(is_nullent(g_BarrierEnt)) {
        set_fail_state("Barrier is not found!");
    }
}

public plugin_cfg() {
    GetCvarsPointers();
    SetCvarsValues();
}

public client_putinserver(id) {

    g_bFirstSpawn[id] = true;
    g_iZombieClass[id] = 0;
    rg_reset_user_model(id, true);
    remove_task(PlayerTask(id));
}

public client_disconnected(id) {
    g_iTeam[id] = TEAM_UNASSIGNED;

    remove_task(id+TASK_RESPAWN);   //обнуляем респавн
    remove_task(PlayerTask(id));
}

public Round_End_Post(WinStatus:status, ScenarioEventEndRound:event) {
    switch(event) {
        case ROUND_CTS_WIN: {
            g_bRoundEnd = true;
            client_print(0, print_center, "ЛЮДИ ПОБЕДИЛИ!");
            //rg_send_audio(0, VOICE_VICTORY[random_num(0, 1)]);
        }
        case ROUND_TERRORISTS_WIN: {
            g_bRoundEnd = true;
            client_print(0, print_center, "ЗОМБИ ПОБЕДИЛИ!");
            //rg_send_audio(0, VOICE_VICTORY[random_num(2, 3)]);
        }
        case ROUND_GAME_OVER: {
            g_bRoundEnd = true;
            rg_update_teamscores(1, 0, true);
            client_print(0, print_center, "ЛЮДИ ПОБЕДИЛИ!");
            //rg_send_audio(0, VOICE_VICTORY[random_num(0, 1)]);
        }
    }
}

public CSGameRules_RestartRound_Pre() {
    if(g_bRoundEnd) {
        new players[MAX_PLAYERS], count;
        get_players_ex(players, count, GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV);

        for(new i, player; i < count; i++) {
            player = players[i];
            // переделать
            if(g_iTeam[player] && IsValidTeam(player)){
                rg_set_user_team(player, g_iTeam[player] == TEAM_TERRORIST ? TEAM_CT : TEAM_TERRORIST); //свапаем тимы, с учётом их прошлых команд
            }
        }

        arrayset(_:g_iTeam, 0, sizeof(g_iTeam));
    }
}

public CSGameRules_RestartRound_Post() {
    remove_task(TASK_RESPAWN);
    remove_task(TASK_BUILDTIME);
    remove_task(TASK_PREPTIME);

    g_bRoundEnd = false;

    //ставим барьер 
    set_entvar(g_BarrierEnt, var_solid, SOLID_BSP);
    set_entvar(g_BarrierEnt, var_rendermode, kRenderTransColor);
    set_entvar(g_BarrierEnt, var_rendercolor, Float:{ 0.0, 0.0, 0.0 });
    set_entvar(g_BarrierEnt, var_renderamt, 150.0);

    set_task_ex(1.0, "BuildTime", TASK_BUILDTIME, .flags = SetTask_RepeatTimes, .repeat = g_Cvar[BUILDING_TIME]);
    g_iCountTime = g_Cvar[BUILDING_TIME] - 1;    
}

public CBasePlayer_DropPlayerItem_Pre(const id) {
    client_printex(id, print_center, "#Weapon_Cannot_Be_Dropped");
    SetHookChainReturn(ATYPE_INTEGER, 1);
    return HC_SUPERCEDE;
}

public CBasePlayer_Spawn_Post(id) {
    if(g_iTeam[id] == TEAM_UNASSIGNED) {
        g_iTeam[id] = get_member(id, m_iTeam);
    }

    if(!IsAlive(id)) {
        return;
    }
    
    // Переделать по-человечески. в AddItem блокировать все итемы, кроме ножа.
    rg_remove_all_items(id);
    rg_give_item(id, "weapon_knife");
    
    if(IsZombie(id)) {
        if(g_bFirstSpawn[id]) {
            Zombie_Menu(id);
            g_bFirstSpawn[id] = false;
        }
        
        set_entvar(id, var_health, Float:ArrayGetCell(g_ZombieHP, g_iZombieClass[id]));
        // проверить, мб не работает и нужно выставлять скорость через хук resetmaxspeed
        set_entvar(id, var_maxspeed, Float:ArrayGetCell(g_ZombieSpeed, g_iZombieClass[id]));
        set_entvar(id, var_gravity, Float:ArrayGetCell(g_ZombieGravity, g_iZombieClass[id]));

        ArrayGetString(g_ZombieModel, g_iZombieClass[id], g_szModel, charsmax(g_szModel));
        rg_set_user_model(id, g_szModel, true);
    }

    if(IsHuman(id)) {
        rg_reset_maxspeed(id);
        rg_reset_user_model(id, true);
    }
    
    set_task_ex(MAX_HOLDTIME, "taskPlayerHud", PlayerTask(id), .flags = SetTask_Repeat);
}

/*public CSGameRules_OnRoundFreezeEnd() {
    //ставим барьер 
    set_entvar(g_BarrierEnt, var_solid, SOLID_BSP);
    set_entvar(g_BarrierEnt, var_rendermode, kRenderTransColor);
    set_entvar(g_BarrierEnt, var_rendercolor, Float:{ 0.0, 0.0, 0.0 });
    set_entvar(g_BarrierEnt, var_renderamt, 150.0);

    set_task_ex(1.0, "BuildTime", TASK_BUILDTIME, .flags = SetTask_RepeatTimes, .repeat = g_Cvar[BUILDING_TIME]);
    g_iCountTime = g_Cvar[BUILDING_TIME] - 1;
}*/

public CBasePlayer_Killed(iVictim, iKiller) {
    if(!IsConnected(iKiller)) {
        return;
    }

    /* если убийцей является зомби, выводим сообщение о заражение с именем того, кого заразили */
    /* все проверки именно тут, ибо зомби может себя кильнуть, а потом не воскренусть */
    /* а также чтобы люди себя не киляли и не становились зомби */
    if(IsZombie(iKiller) && iVictim != iKiller && rg_get_user_team(iVictim) != rg_get_user_team(iKiller)) {
        client_print(0, print_center, "Инфекция теперь в крови игрока: %n", iVictim);
    }/* если убили зомби, выводим мессагу и запускаем воскрешение */
    if(IsZombie(iVictim)) {
        client_print(iVictim, print_center, "Вы воскреснете через %0.f секунды!", g_Cvar[ZOMBIE_RESPAWN_DELAY]);
        set_task_ex(g_Cvar[ZOMBIE_RESPAWN_DELAY], "Respawn", iVictim+TASK_RESPAWN);
    }/* если убили человека, выводим мессагу и запускаем процесс обращение в зомби и воскрешение */
    else if(g_Cvar[INFECTION_RESPAWN_DELAY]) {
        client_print(iVictim, print_center, "Вас заразили! Вы воскресните через %0.f секунды!", g_Cvar[INFECTION_RESPAWN_DELAY]);
        rg_set_user_team(iVictim, TEAM_TERRORIST);
        IsZombie(iVictim);
        set_task_ex(g_Cvar[INFECTION_RESPAWN_DELAY], "Respawn", iVictim+TASK_RESPAWN);
    }
    if(task_exists(PlayerTask(iVictim))) {
        remove_task(PlayerTask(iVictim));
        ClearSyncHud(iVictim, g_SyncHud);
    }
}

// перенести в player_move или наоборот всё закинуть в пресинк
public CBasePlayer_PreThink(id) {
    if(!IsAlive(id)) {
        CmdGrabStop(id);
        return;
    }

    if(!g_iOwnedEnt[id] || !is_entity(g_iOwnedEnt[id])) {
        return;
    }

    new iButton = get_entvar(id, var_button);
    if(iButton & IN_ATTACK) {
        g_fEntDist[id] += OBJECT_PUSHPULLRATE;

        if(g_fEntDist[id] > MAX_MOVE_DISTANCE) {
            g_fEntDist[id] = MAX_MOVE_DISTANCE;
            client_print(id, print_center, "Достигнута максимальная дистанция");
        } else {
            client_print(id, print_center, "Отталкиваем...");
        }

        ExecuteForward(g_Forward[FWD_PUSH_PULL], g_FwdReturn, id, g_iOwnedEnt[id], 1);
    } else if (iButton & IN_ATTACK2) {
        g_fEntDist[id] -= OBJECT_PUSHPULLRATE;

        if(g_fEntDist[id] < MIN_DIST_SET) {
            g_fEntDist[id] = MIN_DIST_SET;
            client_print(id, print_center, "Достигнута минимальная дистанция");
        } else {
            client_print(id, print_center, "Притягиваем...");
        }

        ExecuteForward(g_Forward[FWD_PUSH_PULL], g_FwdReturn, id, g_iOwnedEnt[id], 2);
    }

    new iOrigin[POS], iLook[POS], Float:fOrigin[POS], Float:fLook[POS], Float:vMoveTo[POS], Float:fLength;

    get_user_origin(id, iOrigin, Origin_Eyes);
    IVecFVec(iOrigin, fOrigin);
    get_user_origin(id, iLook, Origin_AimEndEyes);
    IVecFVec(iLook, fLook);

    fLength = get_distance_f(fLook, fOrigin);

    if(fLength == 0.0) {
        fLength = 1.0;
    }

    vMoveTo[X] = (fOrigin[X] + (fLook[X] - fOrigin[X]) * g_fEntDist[id] / fLength) + g_fOffset1[id];
    vMoveTo[Y] = (fOrigin[Y] + (fLook[Y] - fOrigin[Y]) * g_fEntDist[id] / fLength) + g_fOffset2[id];
    vMoveTo[Z] = (fOrigin[Z] + (fLook[Z] - fOrigin[Z]) * g_fEntDist[id] / fLength) + g_fOffset3[id];
    vMoveTo[Z] -= floatfract(vMoveTo[Z]);

    entity_set_origin(g_iOwnedEnt[id], vMoveTo);
}

public PM_Move_Pre(id) {
    if(!IsAlive(id)) {
        return HC_CONTINUE;
    }

    new buttom = get_entvar(id, var_button);
    new oldbutton = get_entvar(id, var_oldbuttons);

    if(buttom & IN_USE && ~oldbutton & IN_USE && !g_iOwnedEnt[id]) {
        CmdGrabMove(id);
    } else if(oldbutton & IN_USE && ~buttom & IN_USE && g_iOwnedEnt[id]) {
        CmdGrabStop(id);
    }

    return HC_CONTINUE;
}

public Ham_Item_Deploy_Post(weapon) {
    new id = get_member(weapon, m_pPlayer);
    if(!IsConnected(id)) {
        return HAM_IGNORED;
    }

    if(IsZombie(id)) {
        new szHandmodel[64];
        ArrayGetString(g_ZombieHandModel, g_iZombieClass[id], szHandmodel, charsmax(szHandmodel));
        format(szHandmodel, sizeof(szHandmodel), "models/zombie_hand/%s.mdl", szHandmodel);
        set_entvar(id, var_viewmodel, szHandmodel);
        set_entvar(id, var_weaponmodel, "");
    }

    return HAM_IGNORED;
}

public BuildTime() {

    g_iCountTime--;

    g_bCanBuild = true;

    new iMins = g_iCountTime / 60, iSecs = g_iCountTime % 60;

    if(g_iCountTime >= 0){

        client_print(0, print_center, "До конца стройки: %d:%s%d", iMins, (iSecs < 10 ? "0" : ""), iSecs);
    } else {
        if(g_Cvar[PREPARATION_TIME]) {
            g_bCanBuild = false;
            set_task_ex(1.0, "PrepTime", TASK_PREPTIME, .flags = SetTask_RepeatTimes, .repeat = g_Cvar[PREPARATION_TIME]);
            g_iCountTime = (g_Cvar[PREPARATION_TIME] - 1);

            client_print_color(0, print_team_default, "^4Люди появились, чтобы проверить свои постройки");

            new iPlayers[MAX_PLAYERS], iPlCount;
            get_players_ex(iPlayers, iPlCount, GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV|GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "CT");

            for(new i, iPlayer; i < iPlCount; i++) {
                iPlayer = iPlayers[i];
                CmdGrabStop(iPlayer);//исправляем момент, когда игрок держал блок и его респавнуло с ним на базе
                rg_round_respawn(iPlayer);
            }
        } else{
            Release_Zombies();
        }

        remove_task(TASK_BUILDTIME);
        return PLUGIN_HANDLED;
    }
    return PLUGIN_CONTINUE;
}

public PrepTime() {
    g_iCountTime--;

    if(g_iCountTime >= 0) {
        client_print(0, print_center, "До конца подготовки: 0:%s%d", (g_iCountTime < 10 ? "0" : ""), g_iCountTime);
    }/* выпускаем зомби по истечению таймера */
    
    if(g_iCountTime == 0) {
        Release_Zombies();
        remove_task(TASK_PREPTIME);

        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public Zombie_Menu(id){
    new menu = menu_create("Zombie Menu", "Zombie_Menu_Handler");

    for(new i, name[MAX_NAME_LENGTH], info[32], flag; i < g_ClassesCount; i++) {
        ArrayGetString(g_ZombieName, i, name, sizeof(name));
        ArrayGetString(g_ZombieInfo, i, info, sizeof(info));
        flag = ArrayGetCell(g_ZombieFlags, i);
        
        if(flag == ADMIN_ALL) {
            menu_additem(menu, fmt("\w%s \r%s", name, info));
        } else{
            menu_additem(menu, fmt("\w%s \r%s \y%s", name, info, flag == ADMIN_ALL ? "" : "[VIP]"), .paccess = flag);
        }
    }

    menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
    menu_display(id, menu, 0);
    
    return PLUGIN_HANDLED;
}

public Zombie_Menu_Handler(id, menu, item) {
    if(item == MENU_EXIT) {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }
    
    g_iZombieClass[id] = item;

    new name[MAX_NAME_LENGTH];
    ArrayGetString(g_ZombieName, item, name, sizeof(name));
    client_print_color(id, print_team_default, "^1Вы выбрали класс зомби: ^4%s", name);

    if(IsZombie(id)) {
        rg_round_respawn(id);
    }
    
    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

public taskPlayerHud(iTaskId) {
    UpdateHUD(GetPlayerByTaskID(iTaskId));
}

public Event_Health(id) {
    UpdateHUD(id);
}

public Respawn(id) {
    id-=TASK_RESPAWN;

    if (!IsConnected(id)){
        return PLUGIN_HANDLED;
    }/* если зомби, ресаем после смерти */
    if(IsZombie(id)){

        rg_round_respawn(id);
    }
    return PLUGIN_HANDLED;
}

public Msg_SendAudio() {
    static szSound[17];
    get_msg_arg_string(2, szSound, charsmax(szSound));

    if(contain(szSound[7], "terwin") != -1 || contain(szSound[7], "ctwin") != -1 || contain(szSound[7], "rounddraw") != -1) {
        return PLUGIN_HANDLED;
    } 

    return PLUGIN_CONTINUE;
}

public Release_Zombies() {
    g_bCanBuild = false;
    remove_task(TASK_BUILDTIME);
    /* снимаем барьер */
    set_entvar(g_BarrierEnt, var_solid, SOLID_NOT);
    set_entvar(g_BarrierEnt, var_renderamt, 0.0);
    /* страшный звук выхода зомби и анонс */
    //rg_send_audio(0, VOICE_VICTORY[random_num(0, 1)]);
    client_print_color(0, print_team_default, "^4ЗОМБИ ВЫШЛИ НА ОХОТУ!");
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

    if(!is_entity(iEnt) || iEnt == g_BarrierEnt || IsAlive(iEnt) || IsMovingEnt(iEnt)) {
        return PLUGIN_HANDLED;
    }

    new szClass[10], szTarget[7];
    get_entvar(iEnt, var_classname, szClass, charsmax(szClass));
    get_entvar(iEnt, var_targetname, szTarget, charsmax(szTarget));

    if(!equal(szClass, "func_wall") || equal(szTarget, "ignore")) {
        return PLUGIN_HANDLED;
    }

    ExecuteForward(g_Forward[FWD_GRAB_ENTITY_PRE], g_FwdReturn, id, iEnt);

    new Float:fOrigin[POS], iAiming[POS], Float:fAiming[POS];

    get_user_origin(id, iAiming, Origin_AimEndEyes);
    IVecFVec(iAiming, fAiming);

    get_entvar(iEnt, var_origin, fOrigin);
    log_amx("get_entvar(iEnt, var_origin, fOrigin) | fOrigin[X] = %f | fOrigin[Y] = %f | fOrigin[Z] = %f", fOrigin[X], fOrigin[Y], fOrigin[Z]);

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
    set_entvar(iEnt, var_rendercolor, Float:{000.0, 150.0, 000.0});
    set_entvar(iEnt, var_renderamt, 100.0);

    MovingEnt(iEnt);
    SetEntMover(iEnt, id);
    g_iOwnedEnt[id] = iEnt;

    ExecuteForward(g_Forward[FWD_GRAB_ENTITY_POST], g_FwdReturn, id, iEnt);

    return PLUGIN_HANDLED;
}

public CmdGrabStop(id){

    if (!g_iOwnedEnt[id]){

        return PLUGIN_HANDLED;
    }

    new iEnt = g_iOwnedEnt[id];

    ExecuteForward(g_Forward[FWD_DROP_ENTITY_PRE], g_FwdReturn, id, iEnt);

    set_entvar(iEnt, var_rendermode, kRenderNormal);

    UnsetEntMover(iEnt);
    g_iOwnedEnt[id] = 0;
    UnmovingEnt(iEnt);

    ExecuteForward(g_Forward[FWD_DROP_ENTITY_POST], g_FwdReturn, id, iEnt);

    return PLUGIN_HANDLED;
}

public plugin_natives(){
    register_native("rebb_register_zombie_class", "native_register_zombie_class");
    register_native("rebb_get_class_id", "native_zombie_get_class_id");
}

public native_register_zombie_class(iPlugin, iParams) {

    enum { arg_name = 1, arg_info, arg_model, arg_handmodel, arg_health, arg_speed, arg_gravity, arg_flags };
    
    if(!g_bCanRegister){

        return -1;
    }
    new szName[32], szInfo[32], szModel[128], szHandmodel[64], Float:fHealth, Float:fSpeed, Float:fGravity, iFlags;

    get_string(arg_name, szName, sizeof(szName));
    ArrayPushString(g_ZombieName, szName);

    get_string(arg_info, szInfo, sizeof(szInfo));
    ArrayPushString(g_ZombieInfo, szInfo);

    get_string(arg_model, szModel, sizeof(szModel)); 
    precache_model_ex(g_ZombieModel, szModel, "player");

    get_string(arg_handmodel, szHandmodel, sizeof(szHandmodel)); 
    precache_model_ex(g_ZombieHandModel, szHandmodel, "zombie_hand");

    fHealth = get_param_f(arg_health);
    ArrayPushCell(g_ZombieHP, fHealth);

    fSpeed = get_param_f(arg_speed);
    ArrayPushCell(g_ZombieSpeed, fSpeed);

    fGravity = get_param_f(arg_gravity);
    ArrayPushCell(g_ZombieGravity, fGravity);

    iFlags = get_param(arg_flags);
    ArrayPushCell(g_ZombieFlags, iFlags);
    
    // индекс класса в форварде будет отличаться от того, который вернет натив регистрации
    ExecuteForward(g_Forward[FWD_CLASS_REGISTERED], _, g_ClassesCount, szName);

    return g_ClassesCount++;
}

precache_model_ex(Array:arr, const model[], const path[]) {
    new buffer[MAX_BUFFER_INFO];
    ArrayPushString(arr, model);

    if(equal(path, "player")) {
        formatex(buffer, sizeof(buffer), "models/%s/%s/%s.mdl", path, model, model);
    } else{
        formatex(buffer, sizeof(buffer), "models/%s/%s.mdl", path, model);
    }

    precache_model(buffer);
}

public native_zombie_get_class_id(id) return g_iZombieClass[id];

RegisterForwards() {
    RegisterHookChain(RG_RoundEnd, "Round_End_Post", true);
    RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
    RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", true);
    RegisterHookChain(RG_CBasePlayer_DropPlayerItem, "CBasePlayer_DropPlayerItem_Pre", false);
    RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true);
    //RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "CSGameRules_OnRoundFreezeEnd", true);
    RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", true);
    RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink");
    RegisterHookChain(RG_PM_Move, "PM_Move_Pre", false);

    RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Item_Deploy_Post", true);
}

RegisterCoreForwards() {
    g_Forward[FWD_CLASS_REG_REQUEST] = CreateMultiForward("rebb_class_reg_request", ET_IGNORE);
    g_Forward[FWD_CLASS_REGISTERED] = CreateMultiForward("rebb_class_registered", ET_IGNORE, FP_CELL, FP_STRING);
    g_Forward[FWD_PUSH_PULL] = CreateMultiForward("bb_block_pushpull", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
    g_Forward[FWD_GRAB_ENTITY_PRE] = CreateMultiForward("bb_grab_pre", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forward[FWD_GRAB_ENTITY_POST] = CreateMultiForward("bb_grab_post", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forward[FWD_DROP_ENTITY_PRE] = CreateMultiForward("bb_drop_pre", ET_IGNORE, FP_CELL, FP_CELL);
    g_Forward[FWD_DROP_ENTITY_POST] = CreateMultiForward("bb_drop_post", ET_IGNORE, FP_CELL, FP_CELL);
}

RegisterCvars() {
    register_cvar("re_basebuilder", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED);
    bind_pcvar_string(
        create_cvar(
            .name = "rebb_game_name", 
            .string = "ReBaseBuilder", 
            .flags = FCVAR_NONE, 
            .description = GetCvarDesc("GAME_NAME")
        ), g_Cvar[GAME_NAME], charsmax(g_Cvar[GAME_NAME])
    );
    bind_pcvar_num(
        create_cvar(
            .name = "rebb_building_time", 
            .string = "90", 
            .flags = FCVAR_NONE, 
            .description = GetCvarDesc("BUILDING_TIME")
        ), g_Cvar[BUILDING_TIME]
    );
    bind_pcvar_num(
        create_cvar(
            .name = "rebb_preparation_time", 
            .string = "15", 
            .flags = FCVAR_NONE,
            .description = GetCvarDesc("PREP_TIME")
        ), g_Cvar[PREPARATION_TIME]
    );
    bind_pcvar_float(
        create_cvar(
            .name = "rebb_zombie_respawn_delay", 
            .string = "3.0", 
            .flags = FCVAR_NONE, 
            .description = GetCvarDesc("ZOMBIE_RESPAWN_DELAY")
        ), g_Cvar[ZOMBIE_RESPAWN_DELAY]
    );
    bind_pcvar_float(
        create_cvar(
            .name = "rebb_infection_respawn_delay", 
            .string = "5.0", 
            .flags = FCVAR_NONE, 
            .description = GetCvarDesc("INFECTION_RESPAWN_DELAY")
        ), g_Cvar[INFECTION_RESPAWN_DELAY]
    ); 
}

GetCvarsPointers() {    
    for(new i; i < sizeof g_MpCvars; i++) {
        g_Pointer[i] = get_cvar_pointer(g_MpCvars[i]);
    }
}

SetCvarsValues() {
    set_pcvar_float(g_Pointer[MP_BUYTIME], 0.0);
    set_pcvar_num(g_Pointer[MP_ROUNDOVER], 1);
    set_pcvar_num(g_Pointer[MP_ITEM_STAYTIME], 0);
}

UpdateHUD(const index) {
    set_hudmessage(g_HudColor[R], g_HudColor[G], g_HudColor[B], 0.02, 0.95, .holdtime = MAX_HOLDTIME, .channel = next_hudchannel(index));
    ShowSyncHudMsg(index, g_SyncHud, "[%0.f HP]", Float:get_entvar(index, var_health));
}

/*FindEntity(const entityname[], const targetname[]) {
    new ent, name[MAX_NAME_LENGTH];
    while((ent = rg_find_ent_by_class(ent, entityname))) {
        get_entvar(ent, var_targetname, name, charsmax(name));
        if(equali(name, targetname)) {
            return ent;
        }
    }

    return NULLENT;
}*/