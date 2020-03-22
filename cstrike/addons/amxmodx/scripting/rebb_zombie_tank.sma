#include <amxmodx>
#include <re_basebuilder>

// TODO: Change to ML keys
new const ZombieName[] = "ТАНК";
new const ZombieInfo[] = "Много HP";

new const ZombieModel[] = "rebb_tank";
new const ZombieHandModel[] = "v_rebb_tank";

const Float:ZombieHP = 5000.0;
const Float:ZombieSpeed = 260.0;
const Float:ZombieGravity = 1.0;

const ZombieFlags = ADMIN_ALL
const TANK_ARMOR = 100;

new g_Class_Tank;

public rebb_classes_registration_init() {
    register_plugin("[ReBB] Zombie Tank", "0.1.6", "ReBB");

    if(!rebb_core_is_running()) {
        rebb_log(PluginPause, "Core of mod is not running! No further work with plugin possible!");
    }
	// мб для задела вынести установку хп, скорости, гравитации и флагов в отдельные нативы?
	// даст возможность в каких-то случаях менять эти параметры, что есть хорошо
    g_Class_Tank = rebb_register_zombie_class(ZombieName, ZombieInfo, ZombieModel, ZombieHandModel, ZombieHP, ZombieSpeed, ZombieGravity, ZombieFlags);

    switch(g_Class_Tank) {
        case ERR_REG_CLASS__WRONG_PLACE: rebb_log(PluginPause, "Class registration must be implemented in 'rebb_classes_registration_init'!");
        case ERR_REG_CLASS__LACK_OF_RES: rebb_log(PluginPause, "Can't find some resource, see logs for more info!");
    }
}

public plugin_init() {
    RegisterHookChain(RG_CBasePlayer_Spawn, "CBasePlayer_Spawn", true);    
}

public CBasePlayer_Spawn(id) {
    if(!is_user_alive(id) || !is_user_zombie(id)) {
        return HC_CONTINUE;
    }    

    if(rebb_get_player_class_index(id) == g_Class_Tank){
        rg_set_user_armor(id, TANK_ARMOR, ARMOR_VESTHELM);
    }

    return HC_CONTINUE;
}
