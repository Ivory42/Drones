#if defined _customdrones_included
 #endinput
#endif
#define _customdrones_included
#define MAXWEAPONS 6

enum CDMoveType
{
	DroneMove_Hover,
	DroneMove_Fly,
	DroneMove_Ground
};

enum CDDmgType
{
	DmgType_Missile,
	DmgType_Energy,
	DmgType_Plasma
};


/****************************************************************

	NATIVES
	
****************************************************************/


/**
 * Get Drone Active Weapon
 *
 * @param1 drone - Drone ent index
 * 
 * @return Active weapon index from 1 - 6
 */

native int CD_GetDroneActiveWeapon(int drone);

/**
 * Get Current Health of drone
 *
 * @param1 drone - Drone ent index
 * 
 * @return current health of drone
 */

native int CD_GetDroneHealth(int drone);

/**
 * Get Max Health of drone
 *
 * @param1 drone - Drone ent index
 * 
 * @return max health of drone
 */

native int CD_GetDroneMaxHealth(int drone);

/**
 * Spawn a drone by name for a specific client
 *
 * @param1 client - Client index to spawn drone for
 * @param2 drone_name - Name of drone to spawn
 * 
 * @return max health of drone
 */

native void CD_SpawnDroneByName(int client, const char[] drone_name);

/**
 * Sets a weapon's reload state based on a fire delay
 *
 * @param1 drone - Ent index of drone firing
 * @param2 weapon - Weapon # that is firing
 * @param3 delay - How long the weapon should take to reload
 *
 */

native void CD_SetWeaponReloading(int drone, int weapon, float delay);

/****************************************************************

	FORWARDS
	
****************************************************************/

/**
 * Forward called after a drone spawns
 *
 * @param1 drone - Ent index of drone
 * @param2 owner - Client index of owner
 * @param3 plugin_name - Name of plugin defined in config
 */

forward void CD_OnDroneCreated(int drone, int owner, const char[] plugin_name);

/**
 * Forward called after a drone is removed
 *
 * @param1 drone - Ent index of drone
 * @param2 owner - Client index of owner
 * @param3 plugin_name - Name of plugin defined in config
 */

forward void CD_OnDroneRemoved(int drone, int owner, const char[] plugin_name);

/**
 * Forward called after a drone switches weapons
 *
 * @param1 drone - Ent index of drone
 * @param2 owner - Client index of owner
 * @param3 newWeapon - Weapon # that is being switched to
 * @param4 plugin_name - Name of plugin defined in config
 */

forward void CD_OnWeaponChanged(int drone, int owner, int newWeapon, const char[] plugin_name);

/**
 * Forward called after a drone is destroyed but not yet removed
 *
 * @param1 drone - Ent index of drone
 * @param2 owner - Client index of owner
 * @param3 attacker - Client index of attacker
 * @param4 damage - Damage dealt to drone
 * @param5 plugin_name - Name of plugin defined in config
 *
 */

forward Action CD_OnDroneDestroyed(int drone, int owner, int attacker, float damage, const char[] plugin_name);
