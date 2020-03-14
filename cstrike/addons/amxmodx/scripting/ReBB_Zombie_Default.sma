#include <amxmodx>
#include <re_basebuilder>

// TODO: Change to ML keys
new const ZombieName[] = { "Зомби" };
new const ZombieInfo[] = { "Обычный" };

new const ZombieModel[] = { "rebb_default" };
new const ZombieHandModel[] = { "v_rebb_def" };
const Float:ZombieHP = 3000.0;
const Float:ZombieSpeed = 280.0;
const Float:ZombieGravity = 1.0;
const ZombieFlags = ADMIN_ALL;

new g_Class_Default;

public plugin_init() {
    register_plugin("[ReBB] Zombie Default", "0.1.2", "ReBB");
/*
    if(!rebb_core_is_running()) {
        set_fail_state("Core of mod is not running! No further work with plugin possible!");
    }*/
}

public rebb_class_reg_request() {
	g_Class_Default = rebb_register_zombie_class(ZombieName, ZombieInfo, ZombieModel, ZombieHandModel, ZombieHP, ZombieSpeed, ZombieGravity, ZombieFlags);

	switch(g_Class_Default) {
		case ERR_REG_CLASS__WRONG_PLACE: {
			set_fail_state("[ReBB] Move class registration to rebb_class_reg_request()!");
		}
		case ERR_REG_CLASS__LACK_OF_RES: {
			set_fail_state("[ReBB] Can't find some resource, see amxx log for more info");
		}
	}
}
