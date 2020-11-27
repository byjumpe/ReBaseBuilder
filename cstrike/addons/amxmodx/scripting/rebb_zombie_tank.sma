#include <amxmodx>
#include <re_basebuilder>

// TODO: Change to ML keys
new const ZombieName[]      = "ТАНК";
new const ZombieInfo[]      = "Много HP";

new const ZombieModel[]     = "rebb_tank";
new const ZombieHandModel[] = "v_rebb_tank";

const Float:ZombieHP        = 5000.0;
const Float:ZombieSpeed     = 260.0;
const Float:ZombieGravity   = 1.0;

const ZombieFlags = ADMIN_ALL

new g_Class_Tank;

public plugin_precache() {
    precache_zombie_model(ZombieModel);
    precache_zombie_handlmodel(ZombieHandModel);
}

public rebb_classes_registration_init() {
    register_plugin("[ReBB] Zombie Tank", "0.2.0", "ReBB");

    if(!rebb_core_is_running()) {
        rebb_log(PluginPause, "Core of mod is not running! No further work with plugin possible!");
    }

    g_Class_Tank = rebb_register_zombie_class(ZombieName, ZombieInfo, ZombieFlags);

    switch(g_Class_Tank) {
        case ERR_REG_CLASS__WRONG_PLACE: rebb_log(PluginPause, "Class registration must be implemented in 'rebb_classes_registration_init'!");
        case ERR_REG_CLASS__LACK_OF_RES: rebb_log(PluginPause, "Can't find some resource, see logs for more info!");
    }
}

public rebb_class_registered(iRegClassId, const szName[]) {
    if(iRegClassId == g_Class_Tank) {
        rebb_set_zombie_model(g_Class_Tank, ZombieModel);
        rebb_set_zombie_handmodel(g_Class_Tank, ZombieHandModel);
        rebb_set_zombie_health(g_Class_Tank, ZombieHP);
        rebb_set_zombie_speed(g_Class_Tank, ZombieSpeed);
        rebb_set_zombie_gravity(g_Class_Tank, ZombieGravity);
    }
}
