#if defined _customdrones_included
 #endinput
#endif
#define _customdrones_included
#define MAXWEAPONS 6

enum ProjType
{
	DroneProj_Rocket,
	DroneProj_Energy,
	DroneProj_Sentry
};

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

/**
 * Retrieves a float parameter from the given drone config
 *
 * @param1 config - config file to check
 * @param2 key - subkey to retrieve value from
 * @param3 weapon - if non-zero, pull attribute for this weapon index
 *
 */

native float CD_GetParamFloat(const char[] config, const char[] key, int weapon = 0);

/**
 * Retrieves an integer parameter from the given drone config
 *
 * @param1 config - config file to check
 * @param2 key - subkey to retrieve value from
 * @param3 weapon - if non-zero, pull attribute for this weapon index
 *
 */

native int CD_GetParamInteger(const char[] config, const char[] key, int weapon = 0);

/**
 * Spawns a rocket based projectile for drones to fire
 *
 * @param1 owner - Player owning the drone
 * @param2 drone - Drone entity index
 * @param3 projectile - Type of rocket to spawn
 * @param4 damage - Damage of the rocket
 * @param5 speed - Speed of the rocket
 * @param6 overrideX - Forward position to offset rocket by (increase this value if the rocket is colliding with the drone model)
 * @param7 overrideY - Right position to offset rocket by
 * @param8 overrideZ - Up position to offset rocket by
 * @param8 inaccuracy - random variance added to projectile angles
 *
 * @return entity index of spawned rocket
 *
 */

native int CD_SpawnRocket(int owner, int drone, ProjType projectile, float damage, float speed = 1100.0, float overrideX = 60.0, float overrideY = 0.0, float overrideZ = 0.0, float inaccuracy = 0.0);

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

forward void CD_OnDroneCreated(int drone, int owner, const char[] plugin_name, const char[] config);

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

forward void CD_OnDroneDestroyed(int drone, int owner, int attacker, float damage, const char[] plugin_name);

/**
 * Forward called after a drone switches weapons
 *
 * @param1 drone - Ent index of drone
 * @param2 owner - Client index of owner
 * @param3 weapon - Weapon # that is being fired
 * @param4 plugin_name - Name of plugin defined in config
 */

forward void CD_OnDroneAttack(int drone, int owner, int Weapon, const char[] plugin_name);

/*************

STOCKS

*************/

stock void GetForwardPos(float origin[3], float angles[3], float distance, float sideDistance = 0.0, float upDistance = 0.0, float buffer[3])
{
	float dir[3];

	GetAngleVectors(angles, dir, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(dir, distance);
	AddVectors(origin, dir, buffer);

	GetAngleVectors(angles, NULL_VECTOR, dir, NULL_VECTOR);
	NegateVector(dir);
	ScaleVector(dir, sideDistance);
	AddVectors(buffer, dir, buffer);
	
	GetAngleVectors(angles, NULL_VECTOR, NULL_VECTOR, dir);
	ScaleVector(dir, upDistance);
	AddVectors(buffer, dir, buffer);
}
