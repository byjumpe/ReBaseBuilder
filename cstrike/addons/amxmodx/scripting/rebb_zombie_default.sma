#include <amxmodx>
#include <re_basebuilder>

// TODO: Change to ML keys
new const ZombieName[]      = "Зомби";
new const ZombieInfo[]      = "Обычный";
new const ZombieFlags[]     = "";

new const ZombieModel[]     = "rebb_default";
new const ZombieHandModel[] = "v_rebb_def";

const Float:ZombieHP        = 3000.0;
const Float:ZombieSpeed     = 280.0;
const Float:ZombieGravity   = 1.0;

new g_ClassDefault;

public plugin_precache() {
    precache_zombie_model(ZombieModel);
    precache_zombie_handlmodel(ZombieHandModel);
}

public plugin_init() {
    register_plugin("[ReBB] Zombie Default", "0.1.7", "ReBB");   

    if(!rebb_core_is_running()) {
        set_fail_state("Core of mod is not running! No further work with plugin possible!");
    }

    g_ClassDefault = rebb_register_zombie_class(ZombieName, ZombieInfo, ZombieFlags);
}

public rebb_class_registered(class_index) {
    if(class_index != g_ClassDefault) {
        return;
    }

    rebb_set_zombie_model(class_index, ZombieModel);
    rebb_set_zombie_handmodel(class_index, ZombieHandModel);
    rebb_set_zombie_health(class_index, ZombieHP);
    rebb_set_zombie_speed(class_index, ZombieSpeed);
    rebb_set_zombie_gravity(class_index, ZombieGravity);
}

