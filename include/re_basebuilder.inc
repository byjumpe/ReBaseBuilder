#if defined _re_basebuilder_included
  #endinput
#endif
#define _re_basebuilder_included

/**
 * Called in plugin_precache() to request zombie classes registration.
 *
 * @note	All classess should registers in this forward
 *
 * @noreturn
 */
forward rebb_class_reg_request();

/**
 * Registers a custom class which will be added to the zombie classes menu of ReBB.
 *
 * Note: The returned zombie class ID can be later used to identify
 * the class when calling the bb_get_user_zombie_class() natives.
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
 * @return				An internal zombie class ID, or -1 on failure.
 */

native rebb_register_zombie_class(const szName[], const szInfo[], const szModel[], const szHandmodel[], Float:fHealth, Float:fSpeed, Float:fGravity, flags = ADMIN_ALL);

/**
 * Returns a player's current zombie class ID.
 *
 * @param id		Player index.
 * @return			Internal zombie class ID, or -1 if not yet chosen.
 */

native rebb_register_zombie_class(id);

//игрок жив?
stock bool: IsAlive(const id){

	return bool: is_user_alive(id);
}
//игрок зомби?
stock bool: IsZombie(const id){

	return bool: (get_member(id, m_iTeam) == TEAM_TERRORIST);
}
//игрок человек?
stock bool: IsHuman(const id){

	return bool: (get_member(id, m_iTeam) == TEAM_CT);
}

stock bool: IsConnected(const id){

	return bool: is_user_connected(id);
}

stock TeamName:rg_get_user_team(const id){

	return TeamName:get_member(id, m_iTeam);
}
