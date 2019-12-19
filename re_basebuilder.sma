/* TODO: сделать возможность блокировать блоки */
/* TODO: меню оружия для хуманов */
/* TODO: валюту в отдельном плугине и прочую лабудень */

#pragma semicolon 1

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <reapi>
#include <re_basebuilder>

#define LockBlock(%1,%2) (entity_set_int(%1, EV_INT_iuser1, %2))
#define UnlockBlock(%1)  (entity_set_int(%1, EV_INT_iuser1, 0))
#define BlockLocker(%1)  (entity_get_int(%1, EV_INT_iuser1))

#define MovingEnt(%1)   (entity_set_int(%1, EV_INT_iuser2, 1))
#define UnmovingEnt(%1) (entity_set_int(%1, EV_INT_iuser2, 0))
#define IsMovingEnt(%1) (entity_get_int(%1, EV_INT_iuser2) == 1)

#define SetEntMover(%1,%2)  (entity_set_int(%1, EV_INT_iuser3, %2))
#define UnsetEntMover(%1)   (entity_set_int(%1, EV_INT_iuser3, 0))

#define OBJECT_PUSHPULLRATE 4.0

new const VERSION[] = "0.1.1 Alpha";

enum (+= 5000){
	
	TASK_BUILDTIME = 10000,
	TASK_PREPTIME,
	TASK_MODELSET,
	TASK_RESPAWN,
	TASK_HEALTH,
	TASK_IDLESOUND
};

new TeamName:g_iTeam[MAX_PLAYERS +1], g_iBuildTime, g_iPrepTime, g_iCountTime, Float: g_fZombieTime, 
	Float: g_fInfectTime, g_szGameName[32], g_iEntBarrier, g_iOwnedEnt[MAX_PLAYERS +1];

new bool: g_bFirstSpawn[MAX_PLAYERS +1], bool: g_bRoundEnd, bool: g_bCanBuild;

new Float: g_fOffset1[MAX_PLAYERS +1], Float: g_fOffset2[MAX_PLAYERS +1], Float: g_fOffset3[MAX_PLAYERS +1], 
	Float: g_fEntMinDist, Float: g_fEntSetDist, Float: g_fEntMaxDist, Float: g_fEntDist[MAX_PLAYERS +1];

new g_fwPushPull, g_fwGrabEnt_Pre, g_fwGrabEnt_Post, g_fwDropEnt_Pre, g_fwDropEnt_Post, g_fwDummyResult;

new g_iZombieCount;
new Array: g_ZombieName,
	Array: g_ZombieInfo,
	Array: g_ZombieModel,
	Array: g_ZombieHandModel,
	Array: g_ZombieHP,
	Array: g_ZombieSpeed,
	Array: g_ZombieGravity,
	Array: g_ZombieKnockback,
	Array: g_ZombieFlags,
	Array: g_ZombiePrice;

public plugin_init(){
	
	register_plugin("[ReAPI] Base Builder", VERSION, "Jumper");
	register_cvar("re_basebuilder", VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED);
	
	register_clcmd("+grab",	"CmdGrabMove");
	register_clcmd("-grab",	"CmdGrabStop");
	
	set_cvar_num("mp_buytime", 0);//блокировка покупки
	set_cvar_num("mp_roundover", 1);//завершаем раунд, даже если нет цели на карте, чтобы давать очки людям, за то что продержались
	
	g_iEntBarrier = find_ent_by_tname(-1, "barrier");
	
	register_message(get_user_msgid("SendAudio"), "Msg_SendAudio");
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);//трупы изчезают
	
	register_forward(FM_CmdStart, "fw_CmdStart");

	g_fwPushPull = CreateMultiForward("bb_block_pushpull", ET_IGNORE, FP_CELL, FP_CELL, FP_CELL);
	g_fwGrabEnt_Pre = CreateMultiForward("bb_grab_pre", ET_IGNORE, FP_CELL, FP_CELL);
	g_fwGrabEnt_Post = CreateMultiForward("bb_grab_post", ET_IGNORE, FP_CELL, FP_CELL);
	g_fwDropEnt_Pre = CreateMultiForward("bb_drop_pre", ET_IGNORE, FP_CELL, FP_CELL);
	g_fwDropEnt_Post = CreateMultiForward("bb_drop_post", ET_IGNORE, FP_CELL, FP_CELL);
	
	RegisterHookChain(RG_RoundEnd, "RG_Round_End", true);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Post", true);
	RegisterHookChain(RG_CBasePlayer_DropPlayerItem, "CBasePlayer_DropPlayerItem_Pre", false);
	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true);
	RegisterHookChain(RG_CSGameRules_OnRoundFreezeEnd, "CSGameRules_OnRoundFreezeEnd", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "CBasePlayer_Killed", true);
	RegisterHookChain(RG_CBasePlayer_PreThink, "CBasePlayer_PreThink");
	RegisterHookChain(RG_CSGameRules_DeadPlayerWeapons, "CSGameRules_DeadPlayerWeapons", false);
	//RegisterHookChain(RG_CBasePlayer_SetClientUserInfoModel, "CBasePlayer_SetClientUserInfoModel", false);
}

public plugin_precache(){
	
	g_ZombieName = ArrayCreate(32, 1);
	g_ZombieInfo = ArrayCreate(32, 1);
	g_ZombieModel = ArrayCreate(32, 1);
	g_ZombieHandModel = ArrayCreate(32, 1);
	g_ZombieHP = ArrayCreate(1, 1);
	g_ZombieSpeed = ArrayCreate(1, 1);
	g_ZombieGravity = ArrayCreate(1, 1);
	g_ZombieKnockback = ArrayCreate(1, 1);
	g_ZombieFlags = ArrayCreate(1, 1);
	g_ZombiePrice = ArrayCreate(1, 1);
}

public plugin_cfg(){

	bind_pcvar_string(create_cvar("game_name", "ReBaseBuilder", FCVAR_NONE, fmt("%L", LANG_SERVER, "GAME_NAME")), g_szGameName, charsmax(g_szGameName));
	bind_pcvar_num(create_cvar("build_time", "15", FCVAR_NONE, fmt("%L", LANG_SERVER, "BUILD_TIME")), g_iBuildTime);
	bind_pcvar_num(create_cvar("prep_time", "15", FCVAR_NONE, fmt("%L", LANG_SERVER, "PREP_TIME")), g_iPrepTime);
	bind_pcvar_float(create_cvar("zombie_respawn_delay", "3.0", FCVAR_NONE, fmt("%L", LANG_SERVER, "ZOMBIE_RESPAWN_DELAY")), g_fZombieTime);
	bind_pcvar_float(create_cvar("infection_respawn", "5.0", FCVAR_NONE, fmt("%L", LANG_SERVER, "INFECTION_RESPAWN")), g_fInfectTime);
	bind_pcvar_float(create_cvar("max_move_dist", "768.0", FCVAR_NONE, fmt("%L", LANG_SERVER, "MAX_MOVE_DIST"), .has_min = true, .min_val = 768.0, .has_max = true, .max_val = 768.0), g_fEntMaxDist);
	bind_pcvar_float(create_cvar("min_move_dist", "32.0", FCVAR_NONE, fmt("%L", LANG_SERVER, "MIN_MOVE_DIST"), .has_min = true, .min_val = 32.0, .has_max = true, .max_val = 32.0), g_fEntMinDist);
	bind_pcvar_float(create_cvar("min_dist_set", "64.0", FCVAR_NONE, fmt("%L", LANG_SERVER, "MIN_DIST_SET"), .has_min = true, .min_val = 64.0, .has_max = true, .max_val = 64.0), g_fEntSetDist);

	set_member_game(m_GameDesc, g_szGameName);

	AutoExecConfig(true, "ReBaseBuilder");
}

public client_putinserver(id){

	//
}

public client_disconnected(id){

	g_iTeam[id] = TEAM_UNASSIGNED;
	
	remove_task(id+TASK_RESPAWN);//обнуляем респавн
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
	//g_bFreezePlayers = false;
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

public CBasePlayer_Spawn(id){
	
	if(g_iTeam[id] == TEAM_UNASSIGNED){
	
		g_iTeam[id] = get_member(id, m_iTeam);
	}
	
	if(!IsAlive(id)){
	
		return;
	}
	if(IsZombie(id)){
		
		if(g_bFirstSpawn[id]){
			
			//здесь открытие меню выбора классов
			g_bFirstSpawn[id] = false;
		}
		//rg_remove_items_by_slot(id, C4_SLOT);
		rg_remove_all_items(id); //забираем всё оружие у зомби
		rg_give_item(id, "weapon_knife"); //выдаём зомби нож
	}
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
			//g_bFreezePlayers = true;
			client_print(0, print_center, "ЛЮДИ ПОБЕДИЛИ!");
			//rg_send_audio(0, VOICE_VICTORY[random_num(0, 1)]);
		}
		case ROUND_TERRORISTS_WIN:{
		
			g_bRoundEnd = true;
			//g_bFreezePlayers = true;
			client_print(0, print_center, "ЗОМБИ ПОБЕДИЛИ!");
			//rg_send_audio(0, VOICE_VICTORY[random_num(2, 3)]);
		}
		case ROUND_GAME_OVER:{
		
			g_bRoundEnd = true;
			//g_bFreezePlayers = true;
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
public fw_CmdStart(id, uc_handle, randseed)
{
	if(!IsAlive(id)){
		
		return FMRES_IGNORED;
	}

	new iButton = get_uc(uc_handle, UC_Buttons);
	new iOldButton = pev(id, pev_oldbuttons);

	if(iButton & IN_USE && !(iOldButton & IN_USE) && !g_iOwnedEnt[id]){
		
		client_print_color(0, print_team_default, "^4НАЖАЛ!");
		CmdGrabMove(id);
	}
	else if(iOldButton & IN_USE && !(iButton & IN_USE) && g_iOwnedEnt[id]){
		
		client_print_color(0, print_team_default, "^4ОТПУСТИЛ!");
		CmdGrabStop(id);

	}
	return FMRES_IGNORED;
}

public CmdGrabMove(id){
	
	if (IsZombie(id)){
		
		client_print_color(0, print_team_default, "^4 IsZombie");
		return PLUGIN_HANDLED;
	}

	if(!g_bCanBuild){
		
		client_print_color(0, print_team_default, "^4 g_bCanBuild");
		return PLUGIN_HANDLED;
	}
	
	if (g_iOwnedEnt[id] && IsValidEnt(g_iOwnedEnt[id])){
		
		client_print_color(0, print_team_default, "^4 g_iOwnedEnt IsValidEnt");
		CmdGrabStop(id);
	}
	
	new iEnt, iBody;
	get_user_aiming(id, iEnt, iBody);
	
	if (!IsValidEnt(iEnt) || iEnt == g_iEntBarrier || IsAlive(iEnt) || IsMovingEnt(iEnt)){
		
		client_print_color(0, print_team_default, "^4 423 строка");
		return PLUGIN_HANDLED;
	}

	new szClass[10], szTarget[7];
	entity_get_string(iEnt, EV_SZ_classname, szClass, 9);
	entity_get_string(iEnt, EV_SZ_targetname, szTarget, 6);
	if (!equal(szClass, "func_wall") || equal(szTarget, "ignore")){
		
		client_print_color(0, print_team_default, "^4 !func_wall");
		return PLUGIN_HANDLED;
	}
	
	ExecuteForward(g_fwGrabEnt_Pre, g_fwDummyResult, id, iEnt);

	new Float:fOrigin[3], iAiming[3], Float:fAiming[3];
	
	get_user_origin(id, iAiming, 3);
	IVecFVec(iAiming, fAiming);
	entity_get_vector(iEnt, EV_VEC_origin, fOrigin);

	g_fOffset1[id] = fOrigin[0] - fAiming[0];
	g_fOffset2[id] = fOrigin[1] - fAiming[1];
	g_fOffset3[id] = fOrigin[2] - fAiming[2];
	
	g_fEntDist[id] = get_user_aiming(id, iEnt, iBody);
	client_print_color(0, print_team_default, "^4 %d", g_fEntDist[id]);
		
	if (g_fEntMinDist)
	{
		if (g_fEntDist[id] < g_fEntMinDist)
			g_fEntDist[id] = g_fEntSetDist;
	}
	else if (g_fEntMaxDist)
	{
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
	
	if (!g_iOwnedEnt[id] || !IsValidEnt(g_iOwnedEnt[id])){
		
		return;
	}
	
	new iButton = get_entvar(id, EntVars:var_button);
	
	if (iButton & IN_ATTACK)
	{
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
	
	new iOrigin[3], iLook[3], Float:fOrigin[3], Float:fLook[3], Float:vMoveTo[3], Float:fLength;
	    
	get_user_origin(id, iOrigin, 1);
	IVecFVec(iOrigin, fOrigin);
	get_user_origin(id, iLook, 3);
	IVecFVec(iLook, fLook);
	    
	fLength = get_distance_f(fLook, fOrigin);
	if (fLength == 0.0) fLength = 1.0;

	vMoveTo[0] = (fOrigin[0] + (fLook[0] - fOrigin[0]) * g_fEntDist[id] / fLength) + g_fOffset1[id];
	vMoveTo[1] = (fOrigin[1] + (fLook[1] - fOrigin[1]) * g_fEntDist[id] / fLength) + g_fOffset2[id];
	vMoveTo[2] = (fOrigin[2] + (fLook[2] - fOrigin[2]) * g_fEntDist[id] / fLength) + g_fOffset3[id];
	vMoveTo[2] = float(floatround(vMoveTo[2], floatround_floor));

	entity_set_origin(g_iOwnedEnt[id], vMoveTo);
	
	return;
}
//игрок жив?
stock bool: IsAlive(const id){

	return bool: is_user_alive(id);
}
//игрок зомби?
stock bool: IsZombie(const id){
	
	return bool: (get_member(id, m_iTeam) == TEAM_TERRORIST);
}
//игрок человек?
stock bool: IsHuman(const id){

	return bool: (get_member(id, m_iTeam) == TEAM_CT);
}

stock bool: IsValidEnt(const id){

	return bool: is_valid_ent(id);
}

stock bool: IsConnected(const id){

	return bool: is_user_connected(id);
}

stock TeamName:rg_get_user_team(const id){

	return TeamName:get_member(id, m_iTeam);
}
//фриз
stock rg_set_freeze(const id){

	set_entvar(id, var_maxspeed, 0.1);
	set_member(id, m_bIsDefusing, true);
}

public plugin_natives(){

	register_native("rebb_register_zombie_class", "native_register_zombie_class", 1);
}

public native_register_zombie_class(const szName[], const szInfo[], const szModel[], const szHandmodel[], Float:fHealth, Float:fSpeed, Float:fGravity, Float:fKnockback, flags, price){

	ArrayPushString(g_ZombieName, szName);
	ArrayPushString(g_ZombieInfo, szInfo);
	ArrayPushString(g_ZombieModel, szModel);
	ArrayPushString(g_ZombieHandModel, szHandmodel);
	ArrayPushCell(g_ZombieHP, fHealth);
	ArrayPushCell(g_ZombieSpeed, fSpeed);
	ArrayPushCell(g_ZombieGravity, fGravity);
	ArrayPushCell(g_ZombieKnockback, fKnockback);
	ArrayPushCell(g_ZombieFlags, flags);
	ArrayPushCell(g_ZombiePrice, price);
	
	new szBuffer[32], Float: fBuffer, szZombieModel[128], szZombieHandModel[64];
	
	for(new i; i < ArraySize(g_ZombieName); i++){

		ArrayGetString(g_ZombieName, i, szBuffer, charsmax(szBuffer));
		ArraySetString(g_ZombieName, g_iZombieCount, szBuffer);
		
		ArrayGetString(g_ZombieInfo, i, szBuffer, charsmax(szBuffer));
		ArraySetString(g_ZombieInfo, g_iZombieCount, szBuffer);
		
		ArrayGetString(g_ZombieModel, i, szBuffer, charsmax(szBuffer));
		ArraySetString(g_ZombieModel, g_iZombieCount, szBuffer);
		formatex(szZombieModel, charsmax(szZombieModel), "models/player/%s/%s.mdl", szBuffer, szBuffer);
		precache_model(szZombieModel);
		
		ArrayGetString(g_ZombieHandModel, i, szZombieHandModel, charsmax(szZombieHandModel));
		ArraySetString(g_ZombieHandModel, g_iZombieCount, szBuffer);
		formatex(szZombieHandModel, charsmax(szZombieHandModel), "models/%s.mdl", szBuffer);
		precache_model(szZombieHandModel);
		
		fBuffer = Float: ArrayGetCell(g_ZombieHP, i);
		ArraySetCell(g_ZombieHP, g_iZombieCount, fBuffer);
		
		fBuffer = Float: ArrayGetCell(g_ZombieSpeed, i);
		ArraySetCell(g_ZombieSpeed, g_iZombieCount, fBuffer);
		
		fBuffer = Float: ArrayGetCell(g_ZombieGravity, i);
		ArraySetCell(g_ZombieGravity, g_iZombieCount, fBuffer);
		
		fBuffer = Float: ArrayGetCell(g_ZombieKnockback, i);
		ArraySetCell(g_ZombieKnockback, g_iZombieCount, fBuffer);
		
		fBuffer = Float: ArrayGetCell(g_ZombieFlags, i);
		ArraySetCell(g_ZombieFlags, g_iZombieCount, fBuffer);
		
		fBuffer = Float: ArrayGetCell(g_ZombiePrice, i);
		ArraySetCell(g_ZombiePrice, g_iZombieCount, fBuffer);
	}
	
	g_iZombieCount++;
	
	return g_iZombieCount-1;
}