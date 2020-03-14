#if defined _re_basebuilder_included
  #endinput
#endif
#define _re_basebuilder_included

#include <reapi>

#define ERR_REG_CLASS__WRONG_PLACE     -1
#define ERR_REG_CLASS__LACK_OF_RES     -2

#define MAX_BUFFER_LENGTH           128
#define MAX_CLASS_INFO_LENGTH       32

#define ROUND_ZOMBIES_WIN           ROUND_TERRORISTS_WIN
#define ROUND_HUMANS_WIN            ROUND_CTS_WIN

#define TEAM_ZOMBIE                 (any:TEAM_TERRORIST)
#define TEAM_HUMANS                 (any:TEAM_CT)

#define is_user_zombie(%0)          (get_member(%0, m_iTeam) == TEAM_ZOMBIE)
#define is_user_human(%0)           (get_member(%0, m_iTeam) == TEAM_HUMANS)
#define is_valid_team(%1)            (TEAM_ZOMBIE <= get_member(%1, m_iTeam) <= TEAM_HUMANS)

#define GetCvarDesc(%0)             fmt("%L", LANG_SERVER, %0)

#define LockBlock(%1,%2)            (set_entvar(%1, var_iuser1, %2))
#define UnlockBlock(%1)             (set_entvar(%1, var_iuser1, 0))
#define BlockLocker(%1)             (get_entvar(%1, var_iuser1))

#define MovingEnt(%1)               (set_entvar(%1, var_iuser2, 1))
#define UnmovingEnt(%1)             (set_entvar(%1, var_iuser2, 0))
#define IsMovingEnt(%1)             (get_entvar(%1, var_iuser2) == 1)

#define SetEntMover(%1,%2)          (set_entvar(%1, var_iuser3, %2))
#define UnsetEntMover(%1)           (set_entvar(%1, var_iuser3, 0))
#define GetEntMover(%1)             (get_entvar(%1, var_iuser3))

#define SetLastMover(%1,%2)         (set_entvar(%1, var_iuser4, %2))
#define UnsetLastMover(%1)          (set_entvar(%1, var_iuser4, 0))
#define GetLastMover(%1)            (get_entvar(%1, var_iuser4))

stock const REBB_MOD_DIR_NAME[MAX_NAME_LENGTH] = "ReBaseBuilder";

/**
 * Called in plugin_precache() to request zombie classes registration.
 *
 * @note    All classess should registers not early than in this forward
 *
 * @noreturn
 */
forward rebb_class_reg_request();

/**
 * Called to announce zombie class registration.
 *
 * @param iRegClassId        Class registration index.
 * @param szName            Class name.
 *
 * @noreturn
 */
forward rebb_class_registered(iRegClassId, const szName[]);

/**
 * Called after build phase was started.
 *
 * @param iBuildTime            Build time (can be 0).
 *
 * @noreturn
 */
forward rebb_build_start(iBuildTime);

/**
 * Called after preparation phase was started.
 *
 * @param iPrepTime            Preparation time (can be 0).
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
 * @param id            ID of the mover.
 * @param iEnt            ID of the entity being moved.
 *
 * @noreturn
 */
forward rebb_grab_block(id);

/**
 * Called before properties have been set for the selected block.
 *
 * @param id            ID of the mover.
 * @param iEnt            ID of the entity being moved.
 *
 * @noreturn
 */
forward rebb_grab_pre(id, iEnt);

/**
 * Called after properties have been set for the selected block.
 *
 * @param id            ID of the mover.
 * @param iEnt            ID of the entity being moved.
 *
 * @noreturn
 */
forward rebb_grab_post(id, iEnt);

/**
 * Called before properties have been set for the released block.
 *
 * @param id            ID of the mover.
 * @param iEnt            ID of the entity being moved.
 *
 * @noreturn
 */
forward rebb_drop_pre(id, iEnt);

/**
 * Called after properties have been set for the released block.
 *
 * @param id            ID of the mover.
 * @param iEnt            ID of the entity being moved.
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
 * Checks to is running a Core of Base Builder.
 *
 * @return                Returns true if plugin is running or has a debug status, otherwise will return false.
 */
native rebb_core_is_running();

/**
 * Registers a custom class which will be added to the zombie classes menu of ReBB.
 *
 * @note    The returned zombie class ID can be later used to identify
 *             the class when calling the bb_get_user_zombie_class() natives.
 *
 * @param szName        Caption to display on the menu.
 * @param szInfo        Brief description of the class.
 * @param szModel        Player model to be used.
 * @param szHandmodel    Claws model to be used.
 * @param fHealth        Initial health points.
 * @param fSpeed        Maximum speed.
 * @param fGravity        Gravity multiplier.
 * @param fKnockback    Empty value.
 * @param flags            Set flag of admin only class, ADMIN_USER is normal players.
 * @return                An internal zombie class ID, or ERR_REG_CLASS__* on failure.
 */
native rebb_register_zombie_class(const szName[], const szInfo[], const szModel[], const szHandmodel[], Float:fHealth, Float:fSpeed, Float:fGravity, flags = ADMIN_ALL);

/**
 * Returns a player's current zombie class ID.
 *
 * @param id        Player index.
 * @return            Internal zombie class ID.
 */
native rebb_get_class_id(id);

/**
 * Checks building phase status.
 *
 * @return                1 if building phase is active, false otherwise.
 */
native rebb_is_building_phase();

/**
 * Checks preparation phase status.
 *
 * @return                1 if preparation phase is active, false otherwise.
 */
native rebb_is_preparation_phase();

/**
 * Checks zombies release status.
 *
 * @return                1 if zombies are released, false otherwise.
 */
native rebb_is_zombies_released();

/**
 * Open guns menu.
 *
 * @return                -1 if I can't be opened.
 */
native rebb_open_guns_menu(id);

/**
 * Grab stop.
 *
 * @return                -1 if User is not connected.
 */
native rebb_grab_stop(id);

/**
 * Barrier.
 *
 * @return                Id barrier ent (g_BarrierEnt).
 */
native rebb_barrier_ent();

/**
 * Owmed Ent.
 *
 * @return                g_iOwnedEnt (g_BarrierEnt).
 */
native rebb_get_owned_ent(id);

stock log_rebb(const plugin_name[], const sLog[]) {
    new FileDate[32], Time[32], File[128], Msg[190];

    new sLogDir[PLATFORM_MAX_PATH];
    get_localinfo("amxx_logs", sLogDir, charsmax(sLogDir));
    formatex(sLogDir, charsmax(sLogDir), "%s/%s", sLogDir, REBB_MOD_DIR_NAME);

    if(!dir_exists(sLogDir)) {
        mkdir(sLogDir);
    }
    get_time("%d.%m.20%y", FileDate, charsmax(FileDate));
    get_time("%H:%M:%S", Time, charsmax(Time));

    formatex(File, charsmax(File), "%s/%s.log", sLogDir, FileDate);
    formatex(Msg, charsmax(Msg), "[%s] [%s] [%s]: %s", FileDate, Time, plugin_name, sLog);

    write_file(File, Msg, -1);
}

