#include <amxmodx>
#include <re_basebuilder>

// TODO: Change to ML keys
new const ZombieName[] = "Зомби";
new const ZombieInfo[] = "Обычный";

new const ZombieModel[] = "rebb_default";
new const ZombieHandModel[] = "v_rebb_def";

const Float:ZombieHP = 3000.0;
const Float:ZombieSpeed = 280.0;
const Float:ZombieGravity = 1.0;
const ZombieFlags = ADMIN_ALL;

new g_Class_Default;

public rebb_classes_registration_init() {
    register_plugin("[ReBB] Zombie Default", "0.1.6", "ReBB");

    if(!rebb_core_is_running()) {
        set_fail_state("Core of mod is not running! No further work with plugin possible!");
    }

    g_Class_Default = rebb_register_zombie_class(ZombieName, ZombieInfo, ZombieModel, ZombieHandModel, ZombieHP, ZombieSpeed, ZombieGravity, ZombieFlags);

    switch(g_Class_Default) {
        case ERR_REG_CLASS__WRONG_PLACE: rebb_log(PluginPause, "Class registration must be implemented in 'rebb_classes_registration_init'!");
        case ERR_REG_CLASS__LACK_OF_RES: rebb_log(PluginPause, "Can't find some resource, see logs for more info!");
    }
}
