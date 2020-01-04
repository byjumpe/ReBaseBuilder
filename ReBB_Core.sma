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

#define LockBlock(%1,%2) (set_entvar(%1, var_iuser1, %2))
#define UnlockBlock(%1)  (set_entvar(%1, var_iuser1, 0))
#define BlockLocker(%1)  (get_entvar(%1, var_iuser1))

#define MovingEnt(%1)   (set_entvar(%1, var_iuser2, 1))
#define UnmovingEnt(%1) (set_entvar(%1, var_iuser2, 0))
#define IsMovingEnt(%1) (get_entvar(%1, var_iuser2) == 1)

#define SetEntMover(%1,%2)  (set_entvar(%1, var_iuser3, %2))
#define UnsetEntMover(%1)   (set_entvar(%1, var_iuser3, 0))

#define OBJECT_PUSHPULLRATE 4.0

#define PlayerTask(%1)          (%1 + TASK_HEALTH)
#define GetPlayerByTaskID(%1)   (%1 - TASK_HEALTH)

enum Color { R, G, B };

const Float:MAX_HOLDTIME        = 20.0;
new g_iHudColor[Color]          = { 255, 0, 0 };

new const VERSION[] = "0.1.2 Alpha";

enum (+= 100){

	TASK_BUILDTIME = 100,
	TASK_PREPTIME,
	TASK_MODELSET,
	TASK_RESPAWN,
	TASK_HEALTH,
	TASK_IDLESOUND
};

enum _:XYZ { Float:X, Float:Y, Float:Z };

new TeamName:g_iTeam[MAX_PLAYERS +1], g_iBuildTime, g_iPrepTime, g_iCountTime, Float: g_fZombieTime, 
	Float: g_fInfectTime, g_szGameName[32], g_iEntBarrier, g_iOwnedEnt[MAX_PLAYERS +1], g_iZombieClass[MAX_PLAYERS +1],
	g_szModel[128], g_iSyncPlayerHud;

new bool: g_bFirstSpawn[MAX_PLAYERS +1], bool: g_bRoundEnd, bool: g_bCanBuild;

new Float: g_fOffset1[MAX_PLAYERS +1], Float: g_fOffset2[MAX_PLAYERS +1], Float: g_fOffset3[MAX_PLAYERS +1], 
	Float: g_fEntMinDist, Float: g_fEntSetDist, Float: g_fEntMaxDist, Float: g_fEntDist[MAX_PLAYERS +1];

new g_fwPushPull, g_fwGrabEnt_Pre, g_fwGrabEnt_Post, g_fwDropEnt_Pre, g_fwDropEnt_Post, g_fwDummyResult;

enum FORWARDS_ENUM{

	FWD__CLASS_REGISTERED
}

new g_Forwards[FORWARDS_ENUM];

new bool:g_bCanRegister;

new g_iZombieCount;
new Array: g_ZombieName,
	Array: g_ZombieInfo,
	Array: g_ZombieModel,
	Array: g_ZombieHandModel,
	Array: g_ZombieHP,
	Array: g_ZombieSpeed,
	Array: g_ZombieGravity,
	Array: g_ZombieFlags;

#define getCvarDesc(%0) fmt("%L", LANG_SERVER, %0)

public plugin_init(){

	register_plugin("[ReAPI] Base Builder", VERSION, "ReBB");
	register_cvar("re_basebuilder", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED);

	register_clcmd("+grab",	"CmdGrabMove");
	register_clcmd("-grab",	"CmdGrabStop");
	register_clcmd("say /zm", "Zombie_Menu");
	register_clcmd("say_team /zm", "Zombie_Menu");

	set_cvar_num("mp_buytime", 0);//блокировка покупки
	set_cvar_num("mp_roundover", 1);//завершаем раунд, даже если нет цели на карте, чтобы давать очки людям, за то что продержались

	g_iEntBarrier = find_ent_by_tname(-1, "barrier");
	
	g_iSyncPlayerHud = CreateHudSyncObj();

	register_message(get_user_msgid("SendAudio"), "Msg_SendAudio");
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);//трупы изчезают
	
	register_event("Health", "Event_Health", "be", "1>0");

	g_fwPushPull = CreateMultiForward("bb_block_pushpull", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_fwGrabEnt_Pre = CreateMultiForward("bb_grab_pre", ET_IGNORE, FP_CELL, FP_CELL);
	g_fwGrabEnt_Post = CreateMultiForward("bb_grab_post", ET_IGNORE, FP_CELL, FP_CELL);
	g_fwDropEnt_Pre = CreateMultiForward("bb_drop_pre", ET_IGNORE, FP_CELL, FP_CELL);
	g_fwDropEnt_Post = CreateMultiForward("bb_drop_post", ET_IGNORE, FP_CELL, FP_CELL);

	RegisterHookChain(RG_RoundEnd, "RG_Round_End", true);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", true);
	RegisterHookChain(RG_CBasePlayer_DropPlayerItem, "CBasePlayer_DropPlayerItem_Pre", false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn_Post", true);
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "CSGameRules_OnRoundFreezeEnd", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", true);
	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink");
	RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "CSGameRules_DeadPlayerWeapons", false);
	RegisterHookChain(RG_PM_Move, "PM_Move_Pre", false);
	
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "Ham_Item_Deploy_Post", true);

	RegisterCvars();

	AutoExecConfig(true, "ReBaseBuilder");

	set_member_game(m_GameDesc, g_szGameName);
}

public plugin_precache(){

	g_ZombieName = ArrayCreate(32, 1);
	g_ZombieInfo = ArrayCreate(32, 1);
	g_ZombieModel = ArrayCreate(64, 1);
	g_ZombieHandModel = ArrayCreate(64, 1);
	g_ZombieHP = ArrayCreate(1, 1);
	g_ZombieSpeed = ArrayCreate(1, 1);
	g_ZombieGravity = ArrayCreate(1, 1);
	g_ZombieFlags = ArrayCreate(1, 1);
	
	g_Forwards[FWD__CLASS_REGISTERED] = CreateMultiForward("rebb_class_registered", ET_IGNORE, FP_CELL, FP_STRING);
	
	g_bCanRegister = true;
	
	ExecuteForward(CreateMultiForward("rebb_class_reg_request", ET_IGNORE));
	
	if(!g_iZombieCount){

		set_fail_state("No zombie class registered!");
	}
}

public plugin_cfg(){
}

public client_putinserver(id){

	g_bFirstSpawn[id] = true;
	g_iZombieClass[id] = 0;
	rg_reset_user_model(id, true);
	remove_task(PlayerTask(id));
}

public client_disconnected(id){

	g_iTeam[id] = TEAM_UNASSIGNED;

	remove_task(id+TASK_RESPAWN);//обнуляем респавн
	remove_task(PlayerTask(id));
}

public CBasePlayer_DropPlayerItem_Pre(const id){

	client_printex(id, print_center, "#Weapon_Cannot_Be_Dropped");
	SetHookChainReturn(ATYPE_INTEGER, 1);
	return HC_SUPERCEDE;
}

public CSGameRules_DeadPlayerWeapons(id){

	SetHookChainReturn(ATYPE_INTEGER, GR_PLR_DROP_GUN_NO);//оружия с умерших не дропается, избегаем возможность когда зомби смогут поднять его
	return HC_SUPERCEDE;
}

public CSGameRules_RestartRound_Pre(){

	if(g_bRoundEnd){

		new iPlayers[MAX_PLAYERS], iPlCount;

		get_players_ex(iPlayers, iPlCount, GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV);

		for(new i, iPlayer, TeamName:iTeamToSet; i < iPlCount; i++){

			iPlayer = iPlayers[i];

			if(g_iTeam[iPlayer] && (TEAM_SPECTATOR > rg_get_user_team(iPlayer) > TEAM_UNASSIGNED)){

				iTeamToSet = (g_iTeam[iPlayer] == TEAM_TERRORIST ? TEAM_CT : TEAM_TERRORIST);

				rg_set_user_team(iPlayer, iTeamToSet);//свапаем тимы, с учётом их прошлых команд
			}
		}
		arrayset(_:g_iTeam, 0, sizeof(g_iTeam));
	}
}

public CSGameRules_RestartRound_Post(){

	remove_task(TASK_RESPAWN);
	remove_task(TASK_BUILDTIME);
	remove_task(TASK_PREPTIME);

	g_bRoundEnd = false;
}

public CSGameRules_OnRoundFreezeEnd(){
	/* ставим барьер */
	set_entvar(g_iEntBarrier, var_solid, SOLID_BSP);
	set_entvar(g_iEntBarrier, var_rendermode, kRenderTransColor);
	set_entvar(g_iEntBarrier, var_rendercolor, Float:{ 0.0, 0.0, 0.0 });
	set_entvar(g_iEntBarrier, var_renderamt, 150.0);

	set_task_ex(1.0, "BuildTime", TASK_BUILDTIME, .flags = SetTask_RepeatTimes, .repeat = g_iBuildTime);
	g_iCountTime = (g_iBuildTime-1);
}

public BuildTime(){

	g_iCountTime--;

	g_bCanBuild = true;

	new iMins = g_iCountTime / 60, iSecs = g_iCountTime % 60;

	if(g_iCountTime >= 0){

		client_print(0, print_center, "До конца стройки: %d:%s%d", iMins, (iSecs < 10 ? "0" : ""), iSecs);
	}
	else{

		if(g_iPrepTime){

			g_bCanBuild = false;
			set_task_ex(1.0, "PrepTime", TASK_PREPTIME, .flags = SetTask_RepeatTimes, .repeat = g_iPrepTime);
			g_iCountTime = (g_iPrepTime-1);

			client_print_color(0, print_team_default, "^4Люди появились, чтобы проверить свои постройки");

			new iPlayers[MAX_PLAYERS], iPlCount;

			get_players_ex(iPlayers, iPlCount, GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV|GetPlayers_ExcludeDead|GetPlayers_MatchTeam, "CT");

			for(new i, iPlayer; i < iPlCount; i++){

				iPlayer = iPlayers[i];
				CmdGrabStop(iPlayer);//исправляем момент, когда игрок держал блок и его респавнуло с ним на базе
				rg_round_respawn(iPlayer);
			}
		}	
		else{

			Release_Zombies();
		}
		remove_task(TASK_BUILDTIME);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public PrepTime(){

	g_iCountTime--;

	if(g_iCountTime >= 0){

		client_print(0, print_center, "До конца подготовки: 0:%s%d", (g_iCountTime < 10 ? "0" : ""), g_iCountTime);
	}/* выпускаем зомби по истечению таймера */
	if (g_iCountTime == 0){

		Release_Zombies();
		remove_task(TASK_PREPTIME);
		return PLUGIN_HANDLED;
	}
	return PLUGIN_CONTINUE;
}

public Zombie_Menu(id){

	new iMenu = menu_create("Zombie Menu", "Zombie_Menu_Handler");

	new szName[32], szInfo[32], iFlag;
	for(new i = 0; i < g_iZombieCount; i++){

		ArrayGetString(g_ZombieName, i, szName, sizeof(szName));
		ArrayGetString(g_ZombieInfo, i, szInfo, sizeof(szInfo));
		iFlag = ArrayGetCell(g_ZombieFlags, i);
		
		if(iFlag == ADMIN_ALL){

			menu_additem(iMenu, fmt("\w%s \r%s", szName, szInfo));
		}
		else{

			menu_additem(iMenu, fmt("\w%s \r%s \y%s", szName, szInfo, iFlag == ADMIN_ALL ? "" : "[VIP]"), .paccess = iFlag);
		}
	}
	menu_setprop(iMenu, MPROP_EXIT, MEXIT_ALL);
	menu_display(id, iMenu, 0);
	
	return PLUGIN_HANDLED;
}

public Zombie_Menu_Handler(id, menu, item){

	if(item == MENU_EXIT){

		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	g_iZombieClass[id] = item;

	new szName[32];
	ArrayGetString(g_ZombieName, item, szName, sizeof(szName));
	client_print_color(id, print_team_default, "^1Вы выбрали класс зомби: ^4%s", szName);

	if(IsZombie(id)){
		
		rg_round_respawn(id);
	}
	
	menu_destroy(menu);
	
	return PLUGIN_HANDLED;
}

public CBasePlayer_Spawn_Post(id){

	if(g_iTeam[id] == TEAM_UNASSIGNED){

		g_iTeam[id] = get_member(id, m_iTeam);
	}

	if(!IsAlive(id)){

		return;
	}
	
	rg_remove_all_items(id);
	rg_give_item(id, "weapon_knife");
	
	if(IsZombie(id)){

		if(g_bFirstSpawn[id]){

			Zombie_Menu(id);
			g_bFirstSpawn[id] = false;
		}
		
		set_entvar(id, var_health, Float:ArrayGetCell(g_ZombieHP, g_iZombieClass[id]));
		set_entvar(id, var_maxspeed, Float:ArrayGetCell(g_ZombieSpeed, g_iZombieClass[id]));
		set_entvar(id, var_gravity, Float:ArrayGetCell(g_ZombieGravity, g_iZombieClass[id]));

		ArrayGetString(g_ZombieModel, g_iZombieClass[id], g_szModel, charsmax(g_szModel));
		rg_set_user_model(id, g_szModel, true);
	}
	if(IsHuman(id)){
	
		rg_reset_maxspeed(id);
		rg_reset_user_model(id, true);
	}
	set_task_ex(MAX_HOLDTIME, "taskPlayerHud", PlayerTask(id), .flags = SetTask_Repeat);
}

public Ham_Item_Deploy_Post(weapon){

	new id = get_member(weapon, m_pPlayer);

	if(!IsConnected(id)){

		return HAM_IGNORED;
	}

	if(IsZombie(id)){

		new szHandmodel[64];
		ArrayGetString(g_ZombieHandModel, g_iZombieClass[id], szHandmodel, charsmax(szHandmodel));
		format(szHandmodel, sizeof(szHandmodel), "models/zombie_hand/%s.mdl", szHandmodel);
		set_entvar(id, var_viewmodel, szHandmodel);
		set_entvar(id, var_weaponmodel, "");
	}
	return HAM_IGNORED;
}

public taskPlayerHud(iTaskId){

	UpdateHUD(GetPlayerByTaskID(iTaskId));
}

public Event_Health(id){

	UpdateHUD(id);
}

UpdateHUD(pPlayer){

	set_hudmessage(g_iHudColor[R], g_iHudColor[G], g_iHudColor[B], 0.02, 0.95, .holdtime = MAX_HOLDTIME, .channel = next_hudchannel(pPlayer));
	ShowSyncHudMsg(pPlayer, g_iSyncPlayerHud, "[%0.f HP]", Float:get_entvar(pPlayer, var_health));
}

public CBasePlayer_Killed(iVictim, iKiller){

	if(!IsConnected(iKiller)) return;

	/* если убийцей является зомби, выводим сообщение о заражение с именем того, кого заразили */
	/* все проверки именно тут, ибо зомби может себя кильнуть, а потом не воскренусть */
	/* а также чтобы люди себя не киляли и не становились зомби */
	if(IsZombie(iKiller) && iVictim != iKiller && rg_get_user_team(iVictim) != rg_get_user_team(iKiller)){

		client_print(0, print_center, "Инфекция теперь в крови игрока: %n", iVictim);
	}/* если убили зомби, выводим мессагу и запускаем воскрешение */
	if(IsZombie(iVictim)){

		client_print(iVictim, print_center, "Вы воскресните через %0.f секунды!", g_fZombieTime);
		set_task_ex(g_fZombieTime, "Respawn", iVictim+TASK_RESPAWN);
	}/* если убили человека, выводим мессагу и запускаем процесс обращение в зомби и воскрешение */
	else if(g_fInfectTime){

		client_print(iVictim, print_center, "Вас заразили! Вы воскресните через %0.f секунды!", g_fInfectTime);
		rg_set_user_team(iVictim, TEAM_TERRORIST);
		IsZombie(iVictim);
		set_task_ex(g_fInfectTime, "Respawn", iVictim+TASK_RESPAWN);
	}
	if(task_exists(PlayerTask(iVictim))){

		remove_task(PlayerTask(iVictim));
		ClearSyncHud(iVictim, g_iSyncPlayerHud);
	}
}

public Respawn(id){

	id-=TASK_RESPAWN;

	if (!IsConnected(id)){

		return PLUGIN_HANDLED;
	}/* если зомби, ресаем после смерти */
	if(IsZombie(id)){

		rg_round_respawn(id);
	}
	return PLUGIN_HANDLED;
}

public RG_Round_End(WinStatus:status, ScenarioEventEndRound:event){

	switch(event){

		case ROUND_CTS_WIN:{

			g_bRoundEnd = true;
			client_print(0, print_center, "ЛЮДИ ПОБЕДИЛИ!");
			//rg_send_audio(0, VOICE_VICTORY[random_num(0, 1)]);
		}
		case ROUND_TERRORISTS_WIN:{

			g_bRoundEnd = true;
			client_print(0, print_center, "ЗОМБИ ПОБЕДИЛИ!");
			//rg_send_audio(0, VOICE_VICTORY[random_num(2, 3)]);
		}
		case ROUND_GAME_OVER:{

			g_bRoundEnd = true;
			rg_update_teamscores(1, 0, true);
			client_print(0, print_center, "ЛЮДИ ПОБЕДИЛИ!");
			//rg_send_audio(0, VOICE_VICTORY[random_num(0, 1)]);
		}
	}
}

public Msg_SendAudio(){

	static szSound[17];
	get_msg_arg_string(2, szSound, charsmax(szSound));

	if(contain(szSound[7], "terwin") != -1 || contain(szSound[7], "ctwin") != -1 || contain(szSound[7], "rounddraw") != -1){

		return PLUGIN_HANDLED;
	} 
	return PLUGIN_CONTINUE;
}

public Release_Zombies(){

	g_bCanBuild = false;
	remove_task(TASK_BUILDTIME);
	/* снимаем барьер */
	set_entvar(g_iEntBarrier, var_solid, SOLID_NOT);
	set_entvar(g_iEntBarrier, var_renderamt, 0.0);
	/* страшный звук выхода зомби и анонс */
	//rg_send_audio(0, VOICE_VICTORY[random_num(0, 1)]);
	client_print_color(0, print_team_default, "^4ЗОМБИ ВЫШЛИ НА ОХОТУ!");
}

public PM_Move_Pre(id){

	if(!IsAlive(id)){

		return HC_CONTINUE;
	}

	new iButton = get_entvar(id, var_button);
	new iOldButton = get_entvar(id, var_oldbuttons);

	if(iButton & IN_USE && !(iOldButton & IN_USE) && !g_iOwnedEnt[id]){

		CmdGrabMove(id);
	}
	else if(iOldButton & IN_USE && !(iButton & IN_USE) && g_iOwnedEnt[id]){

		CmdGrabStop(id);
	}
	return HC_CONTINUE;
}

public CmdGrabMove(id){
	
	if (IsZombie(id)){

		return PLUGIN_HANDLED;
	}

	if(!g_bCanBuild){

		return PLUGIN_HANDLED;
	}

	if (g_iOwnedEnt[id] && is_valid_ent(g_iOwnedEnt[id])){

		CmdGrabStop(id);
	}

	new iEnt, iBody;
	get_user_aiming(id, iEnt, iBody);

	if (!is_valid_ent(iEnt) || iEnt == g_iEntBarrier || IsAlive(iEnt) || IsMovingEnt(iEnt)){

		return PLUGIN_HANDLED;
	}

	new szClass[10], szTarget[7];
	get_entvar(iEnt, var_classname, szClass, 9);
	get_entvar(iEnt, var_targetname, szTarget, 6);

	if (!equal(szClass, "func_wall") || equal(szTarget, "ignore")){

		return PLUGIN_HANDLED;
	}

	ExecuteForward(g_fwGrabEnt_Pre, g_fwDummyResult, id, iEnt);

	new Float:fOrigin[XYZ], iAiming[XYZ], Float:fAiming[XYZ];

	get_user_origin(id, iAiming, 3);
	IVecFVec(iAiming, fAiming);
	get_entvar(iEnt, var_origin, fOrigin);

	g_fOffset1[id] = fOrigin[X] - fAiming[X];
	g_fOffset2[id] = fOrigin[Y] - fAiming[Y];
	g_fOffset3[id] = fOrigin[Z] - fAiming[Z];

	g_fEntDist[id] = get_user_aiming(id, iEnt, iBody);

	if (g_fEntMinDist){

		if (g_fEntDist[id] < g_fEntMinDist){

			g_fEntDist[id] = g_fEntSetDist;
		}
	}
	else if (g_fEntMaxDist){

		if (g_fEntDist[id] > g_fEntMaxDist){

			return PLUGIN_HANDLED;
		}
	}

	set_entvar(iEnt, var_rendermode, kRenderTransColor);
	set_entvar(iEnt, var_rendercolor, Float:{000.0, 150.0, 000.0});
	set_entvar(iEnt, var_renderamt, 100.0);

	MovingEnt(iEnt);
	SetEntMover(iEnt, id);
	g_iOwnedEnt[id] = iEnt;

	ExecuteForward(g_fwGrabEnt_Post, g_fwDummyResult, id, iEnt);

	return PLUGIN_HANDLED;
}

public CmdGrabStop(id){

	if (!g_iOwnedEnt[id]){

		return PLUGIN_HANDLED;
	}

	new iEnt = g_iOwnedEnt[id];

	ExecuteForward(g_fwDropEnt_Pre, g_fwDummyResult, id, iEnt);

	set_entvar(iEnt, var_rendermode, kRenderNormal);

	UnsetEntMover(iEnt);
	g_iOwnedEnt[id] = 0;
	UnmovingEnt(iEnt);

	ExecuteForward(g_fwDropEnt_Post, g_fwDummyResult, id, iEnt);

	return PLUGIN_HANDLED;
}

public CBasePlayer_PreThink(id){

	if (!IsAlive(id)){

		CmdGrabStop(id);
		return;
	}

	if (!g_iOwnedEnt[id] || !is_valid_ent(g_iOwnedEnt[id])){

		return;
	}

	new iButton = get_entvar(id, var_button);

	if (iButton & IN_ATTACK){

		g_fEntDist[id] += OBJECT_PUSHPULLRATE;

		if (g_fEntDist[id] > g_fEntMaxDist){

			g_fEntDist[id] = g_fEntMaxDist;
			client_print(id, print_center, "Достигнута максимальная дистанция");
		}
		else{

			client_print(id, print_center, "Отталкиваем...");
		}
		ExecuteForward(g_fwPushPull, g_fwDummyResult, id, g_iOwnedEnt[id], 1);
	}
	else if (iButton & IN_ATTACK2){

		g_fEntDist[id] -= OBJECT_PUSHPULLRATE;

		if (g_fEntDist[id] < g_fEntSetDist){

			g_fEntDist[id] = g_fEntSetDist;
			client_print(id, print_center, "Достигнута минимальная дистанция");
		}
		else{

			client_print(id, print_center, "Притягиваем...");
		}
		ExecuteForward(g_fwPushPull, g_fwDummyResult, id, g_iOwnedEnt[id], 2);
	}

	new iOrigin[XYZ], iLook[XYZ], Float:fOrigin[XYZ], Float:fLook[XYZ], Float:vMoveTo[XYZ], Float:fLength;

	get_user_origin(id, iOrigin, 1);
	IVecFVec(iOrigin, fOrigin);
	get_user_origin(id, iLook, 3);
	IVecFVec(iLook, fLook);

	fLength = get_distance_f(fLook, fOrigin);

	if (fLength == 0.0) fLength = 1.0;

	vMoveTo[X] = (fOrigin[X] + (fLook[X] - fOrigin[X]) * g_fEntDist[id] / fLength) + g_fOffset1[id];
	vMoveTo[Y] = (fOrigin[Y] + (fLook[Y] - fOrigin[Y]) * g_fEntDist[id] / fLength) + g_fOffset2[id];
	vMoveTo[Z] = (fOrigin[Z] + (fLook[Z] - fOrigin[Z]) * g_fEntDist[id] / fLength) + g_fOffset3[id];
	vMoveTo[Z] -= floatfract(vMoveTo[Z]);

	entity_set_origin(g_iOwnedEnt[id], vMoveTo);
}


public plugin_natives(){

	register_native("rebb_register_zombie_class", "native_register_zombie_class");
	register_native("rebb_get_class_id", "native_zombie_get_class_id");
}

public native_register_zombie_class(iPlugin, iParams){

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
	_precache_model(g_ZombieModel, szModel, "player");

	get_string(arg_handmodel, szHandmodel, sizeof(szHandmodel)); 
	_precache_model(g_ZombieHandModel, szHandmodel, "zombie_hand");

	fHealth = get_param_f(arg_health);
	ArrayPushCell(g_ZombieHP, fHealth);

	fSpeed = get_param_f(arg_speed);
	ArrayPushCell(g_ZombieSpeed, fSpeed);

	fGravity = get_param_f(arg_gravity);
	ArrayPushCell(g_ZombieGravity, fGravity);

	iFlags = get_param(arg_flags);
	ArrayPushCell(g_ZombieFlags, iFlags);
	
	ExecuteForward(g_Forwards[FWD__CLASS_REGISTERED], _, g_iZombieCount, szName);

	return g_iZombieCount++;
}

public _precache_model(Array:arr, const model[], const path[]){

	static szBuffer[128];

	ArrayPushString(arr, model);
	if(equal(path, "player")){

		formatex(szBuffer, sizeof(szBuffer), "models/%s/%s/%s.mdl", path, model, model);
	}
	else{

		formatex(szBuffer, sizeof(szBuffer), "models/%s/%s.mdl", path, model);
	}
	precache_model(szBuffer);
}

public native_zombie_get_class_id(id) return g_iZombieClass[id];

RegisterCvars() {
	bind_pcvar_string(
		create_cvar(
			.name = "game_name", 
			.string = "ReBaseBuilder", 
			.flags = FCVAR_NONE, 
			.description = getCvarDesc("GAME_NAME")
		), g_szGameName, charsmax(g_szGameName)
	);
	bind_pcvar_num(
		create_cvar(
			.name = "build_time", 
			.string = "15", 
			.flags = FCVAR_NONE, 
			.description = getCvarDesc("BUILD_TIME")
		), g_iBuildTime
	);
	bind_pcvar_num(
		create_cvar(
			.name = "prep_time", 
			.string = "15", 
			.flags = FCVAR_NONE, 
			.description = getCvarDesc("PREP_TIME")
		), g_iPrepTime
	);
	bind_pcvar_float(
		create_cvar(
			.name = "zombie_respawn_delay", 
			.string = "3.0", 
			.flags = FCVAR_NONE, 
			.description = getCvarDesc("ZOMBIE_RESPAWN_DELAY")
		), g_fZombieTime
	);
	bind_pcvar_float(
		create_cvar(
			.name = "infection_respawn", 
			.string = "5.0", 
			.flags = FCVAR_NONE, 
			.description = getCvarDesc("INFECTION_RESPAWN")
		), g_fInfectTime
	);
	bind_pcvar_float(
		create_cvar(
			.name = "max_move_dist", 
			.string = "768.0", 
			.flags = FCVAR_NONE, 
			.description = getCvarDesc("MAX_MOVE_DIST"), 
			.has_min = true, 
			.min_val = 768.0, 
			.has_max = true, 
			.max_val = 768.0
		), g_fEntMaxDist
	);
	bind_pcvar_float(
		create_cvar(
			.name = "min_move_dist", 
			.string = "32.0", 
			.flags = FCVAR_NONE, 
			.description = getCvarDesc("MIN_MOVE_DIST"), 
			.has_min = true, 
			.min_val = 32.0, 
			.has_max = true, 
			.max_val = 32.0
		), g_fEntMinDist
	);
	bind_pcvar_float(
		create_cvar(
			.name = "min_dist_set", 
			.string = "64.0", 
			.flags = FCVAR_NONE, 
			.description = getCvarDesc("MIN_DIST_SET"), 
			.has_min = true, 
			.min_val = 64.0, 
			.has_max = true, 
			.max_val = 64.0
		), g_fEntSetDist
	); 
}