#if defined _re_basebuilder_included
  #endinput
#endif
#define _re_basebuilder_included

#define ERR_REG_CLASS__WRONG_PLACE -1
#define ERR_REG_CLASS__LACK_OF_RES -2

#define IsConnected(%0) is_user_connected(%0)
#define IsAlive(%0) is_user_alive(%0)
#define IsZombie(%0) (get_member(%0, m_iTeam) == TEAM_TERRORIST)
#define IsHuman(%0) (get_member(%0, m_iTeam) == TEAM_CT)

/**
 * Called in plugin_precache() to request zombie classes registration.
 *
 * @note	All classess should registers not early than in this forward
 *
 * @noreturn
 */
forward rebb_class_reg_request();

/**
 * Called to announce zombie class registration.
 *
 * @param iRegClassId		Class registration index.
 * @param szName			Class name.
 *
 * @noreturn
 */
forward rebb_class_registered(iRegClassId, const szName[]);

/**
 * Called after build phase was started.
 *
 * @param iBuildTime			Build time (can be 0).
 *
 * @noreturn
 */
forward rebb_build_start(iBuildTime);

/**
 * Called after preparation phase was started.
 *
 * @param iPrepTime			Preparation time (can be 0).
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
 * Registers a custom class which will be added to the zombie classes menu of ReBB.
 *
 * @note	The returned zombie class ID can be later used to identify
 * 			the class when calling the bb_get_user_zombie_class() natives.
 *
 * @param szName		Caption to display on the menu.
 * @param szInfo		Brief description of the class.
 * @param szModel		Player model to be used.
 * @param szHandmodel	Claws model to be used.
 * @param fHealth		Initial health points.
 * @param fSpeed		Maximum speed.
 * @param fGravity		Gravity multiplier.
 * @param fKnockback	Empty value.
 * @param flags			Set flag of admin only class, ADMIN_USER is normal players.
 * @param price			Cost of unlocking this class (if credits is enabled).
 * @return				An internal zombie class ID, or ERR_REG_CLASS__* on failure.
 */
native rebb_register_zombie_class(const szName[], const szInfo[], const szModel[], const szHandmodel[], Float:fHealth, Float:fSpeed, Float:fGravity, flags = ADMIN_ALL);

/**
 * Returns a player's current zombie class ID.
 *
 * @param id		Player index.
 * @return			Internal zombie class ID.
 */
native rebb_get_class_id(id);

/**
 * Checks building phase status.
 *
 * @return				1 if building phase is active, false otherwise.
 */
native rebb_is_building_phase();

/**
 * Checks preparation phase status.
 *
 * @return				1 if preparation phase is active, false otherwise.
 */
native rebb_is_preparation_phase();

/**
 * Checks zombies release status.
 *
 * @return				1 if zombies are released, false otherwise.
 */
native rebb_is_zombies_released();

/**
 * Open guns menu.
 *
 * @return				-1 if I can't be opened.
 */
native rebb_open_guns_menu(id);