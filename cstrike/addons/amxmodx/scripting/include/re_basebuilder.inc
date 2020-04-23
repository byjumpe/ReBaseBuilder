#if defined _re_basebuilder_included
  #endinput
#endif
#define _re_basebuilder_included

#include <reapi>


/**
 * Error codes
 */
#define INVALID_ZOMBIE_CLASS                -1
#define ERR_REG_CLASS__WRONG_PLACE            -2
#define ERR_REG_CLASS__LACK_OF_RES          -3


/**
 * Basic constants
 */
#define MAX_BUFFER_LENGTH                   128
#define MAX_CLASS_INFO_LENGTH               32

/**
* States info types for use with rebb_log()
*/
enum StateSet {
    PluginStateIgnore = 0,      // Do nothing
    PluginPause                 // Pauses the current plugin
};


/**
 * Macros to check player team
 */
#define ROUND_ZOMBIES_WIN                   ROUND_TERRORISTS_WIN
#define ROUND_HUMANS_WIN                    ROUND_CTS_WIN
 
#define TEAM_ZOMBIE                         (any:TEAM_TERRORIST)
#define TEAM_HUMANS                         (any:TEAM_CT)

#define is_user_zombie(%0)                  (get_member(%0, m_iTeam) == TEAM_ZOMBIE)
#define is_user_human(%0)                   (get_member(%0, m_iTeam) == TEAM_HUMANS)
#define is_valid_team(%1)                   (TEAM_ZOMBIE <= get_member(%1, m_iTeam) <= TEAM_HUMANS)


/**
 * Misc macros
 */
#define GetCvarDesc(%0)                     fmt("%L", LANG_SERVER, %0)

#define LockBlock(%1,%2)                    (set_entvar(%1, var_iuser1, %2))
#define UnlockBlock(%1)                     (set_entvar(%1, var_iuser1, 0))
#define BlockLocker(%1)                     (get_entvar(%1, var_iuser1))

#define MovingEnt(%1)                       (set_entvar(%1, var_iuser2, 1))
#define UnmovingEnt(%1)                     (set_entvar(%1, var_iuser2, 0))
#define IsMovingEnt(%1)                     (get_entvar(%1, var_iuser2) == 1)

#define SetEntMover(%1,%2)                  (set_entvar(%1, var_iuser3, %2))
#define UnsetEntMover(%1)                   (set_entvar(%1, var_iuser3, 0))
#define GetEntMover(%1)                     (get_entvar(%1, var_iuser3))

#define SetLastMover(%1,%2)                 (set_entvar(%1, var_iuser4, %2))
#define UnsetLastMover(%1)                  (set_entvar(%1, var_iuser4, 0))
#define GetLastMover(%1)                    (get_entvar(%1, var_iuser4))

/**
 * Forwards
 */
 
/**
 * Called when resources are precache, when zombie class registration is available.
 *
 * @note    All classess should registers not early than in this forward.
 *
 * @noreturn
 */
forward rebb_classes_registration_init();

/**
 * Called to announce zombie class registration.
 *
 * @param iRegClassId       Class registration index.
 * @param szName            Class name.
 *
 * @noreturn
 */
forward rebb_class_registered(iRegClassId, const szName[]);

/**
 * Called after build phase was started.
 *
 * @param iBuildTime        Build time (can be 0).
 *
 * @noreturn
 */
forward rebb_build_start(iBuildTime);

/**
 * Called after preparation phase was started.
 *
 * @param iPrepTime         Preparation time (can be 0).
 *
 * @noreturn
 */
forward rebb_preparation_start(iPrepTime);

/**
 * Called after barier was removed (zombies are released).
 *
 * @noreturn
 */
forward rebb_zombies_released();

/**
 * Called before properties have been set for the selected block.
 *
 * @param id                ID of the mover.
 * @param iEnt              ID of the entity being moved.
 *
 * @noreturn
 */
forward rebb_grab_block(id);

/**
 * Called before properties have been set for the selected block.
 *
 * @param id                ID of the mover.
 * @param iEnt              ID of the entity being moved.
 *
 * @noreturn
 */
forward rebb_grab_pre(id, iEnt);

/**
 * Called after properties have been set for the selected block.
 *
 * @param id                ID of the mover.
 * @param iEnt              ID of the entity being moved.
 *
 * @noreturn
 */
forward rebb_grab_post(id, iEnt);

/**
 * Called before properties have been set for the released block.
 *
 * @param id                ID of the mover.
 * @param iEnt              ID of the entity being moved.
 *
 * @noreturn
 */
forward rebb_drop_pre(id, iEnt);

/**
 * Called after properties have been set for the released block.
 *
 * @param id                ID of the mover.
 * @param iEnt              ID of the entity being moved.
 *
 * @noreturn
 */
forward rebb_drop_post(id, iEnt);

/**
 * Сalled when the Builder has been infected.
 *
 * @noreturn
 */
forward rebb_infected();


/**
 * Natives
 */
 
/**
 * Checks to is running a Core of Base Builder.
 *
 * @return                  Returns true if plugin is running or has a debug status, otherwise will return false.
 */
native rebb_core_is_running();

/**
 * Registers a custom class which will be added to the zombie classes menu of ReBB.
 *
 * @note    The returned zombie class ID can be later used to identify
 *            the class when calling the bb_get_user_zombie_class() natives.
 *
 * @param szName            Caption to display on the menu.
 * @param szInfo            Brief description of the class.
 * @param flags             Set flag of admin only class, ADMIN_USER is normal players.
 * @return                  An internal zombie class ID, or ERR_REG_CLASS__* on failure.
 */
native rebb_register_zombie_class(const szName[], const szInfo[], flags = ADMIN_ALL);

/**
 * Returns a player's current zombie class ID.
 *
 * @note    The returned zombie class ID can be later used to identify
 *
 * @param id                Player index.
 * @return                  Internal zombie class ID.
 */
native rebb_get_player_class_index(id);

/**
 * Sets the zombie model.
 *
 * @param classid           Zombie class index.
 * @param szModel           Zombie model name.
 */
rebb_set_zombie_model(classid, const szModel[]);

/**
 * Sets the model of zombie hands.
 *
 * @param classid           Zombie class index.
 * @param szHandmodel       Hand model name.
 */
rebb_set_zombie_handmodel(classid, const szHandmodel[]);

/**
 * Sets the amount of zombie health.
 *
 * @note    The returned zombie class ID can be later used to identify
 *
 * @param classid           Zombie class index.
 * @param fHealth           Initial health points.
 */
rebb_set_zombie_health(classid, Float:fHealth);

/**
 * Sets the speed of movement of the zombie.
 *
 * @param classid           Zombie class index.
 * @param fSpeed            Maximum speed.
 */
rebb_set_zombie_speed(classid, Float:fSpeed);

/**
 * Sets the zombie's gravity.
 *
 * @param classid           Zombie class index.
 * @param fGravity          Gravity multiplier.
 */
rebb_set_zombie_gravity(classid, Float:fGravity);

/**
 * Checks building phase status.
 *
 * @return                  True if building phase is active, false otherwise.
 */
native rebb_is_building_phase();

/**
 * Checks preparation phase status.
 *
 * @return                  True if preparation phase is active, false otherwise.
 */
native rebb_is_preparation_phase();

/**
 * Checks zombies release status.
 *
 * @return                  True if zombies are released, false otherwise.
 */
native rebb_is_zombies_released();

/**
 * Open guns menu.
 *
 * @return                  -1 if I can't be opened.
 */
native rebb_open_guns_menu(id);

/**
 * Grab stop.
 *
 * @return                  -1 if User is not connected.
 */
native rebb_grab_stop(id);

/**
 * Gets index of barrier entity. On cards designed for mod, most often this is "func_wall" entity with targetname "barrier".
 *
 * @note    If the object is not found on map or is invalid, native will return NULLENT (check basic constants in cssdk_const.inc).
 * 
 * @return                  Entity index.
 */
native rebb_get_barrier_ent_index();

/**
 * Owmed Ent.
 *
 * @return                  g_iOwnedEnt.
 */
native rebb_get_owned_ent(id);


/**
 * Stocks
 */

/**
 * Mod resources directory.
 */
stock const REBB_MOD_DIR_NAME[MAX_NAME_LENGTH] = "ReBaseBuilder";

/**
 * Logs a message to log file.
 *
 * @param pl_state          State of current plugin.
 * @param string            Formatting rules.
 * @param ...               Variable number of formatting parameters.
 */
stock rebb_log(const StateSet:pl_state = PluginStateIgnore, const string[] = "", any:...) {
    static logfile[MAX_BUFFER_LENGTH];
    get_localinfo("amxx_logs", logfile, charsmax(logfile));
    format(logfile, charsmax(logfile), "%s/%s/", logfile, REBB_MOD_DIR_NAME);

    if(!dir_exists(logfile)) {
        mkdir(logfile);
    }

    static time[12];
    get_time("%T", time, charsmax(time));

    static date[12];
    format_time(date, charsmax(date), "%m_%d_%Y");

    static filename[MAX_NAME_LENGTH];
    format(filename, charsmax(filename), "rebb_log__%s.log", date);
    add(logfile, charsmax(logfile), filename);

    static msg[256], buffer[256];
    vformat(msg, charsmax(msg), string, 3);
    format_time(date, charsmax(date), "%m/%d/%Y");

    static plugin_name[MAX_NAME_LENGTH];
    get_plugin(-1, .name = plugin_name, .len2 = charsmax(plugin_name));

    format(buffer, charsmax(buffer), "L %s - %s: %s - %s", date, time, plugin_name, msg);

    server_print(buffer);
    write_file(logfile, buffer);

    if(pl_state == PluginPause) {
        pause("d");
    }
}

/**
 * Precache the zombie model.
 *
 * @param model[]          Model name.
 */
stock precache_zombie_model(const model[]) {
    static buffer[MAX_BUFFER_LENGTH];
    formatex(buffer, charsmax(buffer), "models/player/%s/%s.mdl", model, model);
    precache_model(buffer);
}

/**
 * Precache model of zombie hands.
 *
 * @param model[]          Model name.
 */
stock precache_zombie_handlmodel(const model[]) {
    static buffer[MAX_BUFFER_LENGTH];
    formatex(buffer, charsmax(buffer), "models/zombie_hands/%s.mdl", model);
    precache_model(buffer);
}