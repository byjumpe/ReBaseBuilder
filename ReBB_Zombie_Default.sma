#include <amxmodx>
#include <reapi>
#include <re_basebuilder>

// TODO: Change to ML keys
new const ZombieName[] = { "Зомби" };
new const ZombieInfo[] = { "Обычный" };

new const ZombieModel[] = { "rebb_def" };
new const ZombieHandModel[] = { "v_rebb_def" };
const Float: ZombieHP = 3000.0;
const Float: ZombieSpeed = 280.0;
const Float: ZombieGravity = 1.0;
const ZombieFlags = ADMIN_ALL

new g_Class_Default;

public rebb_class_reg_request(){

	register_plugin("[ReBB] Zombie Default", "0.1", "ReBB");

	rebb_register_zombie_class(ZombieName, ZombieInfo, ZombieModel, ZombieHandModel, ZombieHP, ZombieSpeed, ZombieGravity, ZombieFlags);
	
	if(g_Class_Default == -1){
		
		set_fail_state("[ReBB] Zombie Default: Wrong registration chain!");
	}
}

