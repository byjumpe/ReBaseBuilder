#include <amxmodx>
#include <reapi>
#include <re_basebuilder>

// TODO: Change to ML keys
new const ZombieName[] = { "ТАНК" };
new const ZombieInfo[] = { "Много HP" };

new const ZombieModel[] = { "rebb_tank" };
new const ZombieHandModel[] = { "v_rebb_tank" };
const Float: ZombieHP = 5000.0;
const Float: ZombieSpeed = 260.0;
const Float: ZombieGravity = 1.0;
const ZombieFlags = ADMIN_ALL

const TANK_ARMOR = 100;

new g_Class_Tank;

public rebb_class_reg_request(){

	register_plugin("[ReBB] Zombie Tank", "0.1", "ReBB");

	g_Class_Tank = rebb_register_zombie_class(ZombieName, ZombieInfo, ZombieModel, ZombieHandModel, ZombieHP, ZombieSpeed, ZombieGravity, ZombieFlags);
	
	if(g_Class_Tank == -1) {
		set_fail_state("Wrong registration chain!");
	}
}

public plugin_init(){

	RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true);
}

public CBasePlayer_Spawn(id){
	
	if(!is_user_alive(id)){

		return ;	
	}

	if(IsZombie(id) && rebb_get_class_id(id) == g_Class_Tank){
	
		rg_set_user_armor(id, TANK_ARMOR, ARMOR_VESTHELM);	
	}
}

