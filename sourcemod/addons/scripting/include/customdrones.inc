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
	//damagetypes for custom plugins
	DmgType_Missile,
	DmgType_Energy,
	DmgType_Plasma,
	
	//default damage types used by main plugin
	DmgType_Rangeless, 	//hitscan damage with no falloff
	DmgType_Generic		//hitscan generic damage
};

enum CDWeaponType
{
	CDWeapon_Auto,		//high fire rate weapons
	CDWeapon_SlowFire,	//slow fire weapons
	CDWeapon_Laser		//laser weapons
};

//should probably be a methodmap
enum struct DroneBomb
{
	int bomb;
	int owner;
	int explosion;
	float fuseTime;
	float detPos[3];
	char damage[8];
	char radius[8];
	
	void create(int ownerEnt, const char[] model, float baseDamage, float fuse, float dmgRadius, float pos[3], float angle[3], float vel[3])
	{
		this.bomb = CreateEntityByName("prop_physics_override");
		this.owner = ownerEnt;
		DispatchKeyValue(this.bomb, "Model", model);
		Format(this.damage, 8, "%.1f", baseDamage);
		Format(this.radius, 8, "%.1f", dmgRadius);
		this.fuseTime = fuse;
		TeleportEntity(this.bomb, pos, angle, vel);
		DispatchSpawn(this.bomb);
		ActivateEntity(this.bomb);
	}
	void detonate() //detonate our bomb
	{
		GetEntPropVector(this.bomb, Prop_Data, "m_vecOrigin", detPos);
		AcceptEntityInput(this.bomb, "Kill");
		this.explosion = CreateEntityByName("env_explosion");
		SetEntPropEnt(this.explosion, Prop_Send, "m_hOwnerEntity", this.owner);
		DispatchKeyValue(this.explosion, "iMagnitude", this.damage);
		DispatchKeyValue(this.explosion, "iRadiusOverride", this.radius);
		TeleportEntity(this.explosion, detPos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(this.explosion);
		ActivateEntity(this.explosion);
		AcceptEntityInput(this.explosion, "Explode");
	}
}


/****************************************************************

	NATIVES
	
****************************************************************/

/**
 * Toggles view lock on the given drone. When disabled, the drone will NOT rotate to the angle the player is aiming.
 *
 * @param1 drone - Drone to toggle view lock on
 * @return new view lock value
 */

native bool CD_ToggleViewLocked(int drone);

/**
 * Fire a hitscan attack from a drone's weapon
 *
 * @param1 owner - Client index who owns the drone
 * @param2 drone - Drone firing the attack
 * @param3 damage - Damage to deal on successful hit
 * @param4 origin - Position to fire trace from
 * @param5 forwardAngle - Forward direction of attack to check angle from
 * @param6 overrideX - Forward position to offset trace origin from
 * @param7 overrideY - Side position to offset trace origin from
 * @param8 overrideZ - Vertical position to offset trace origin from
 * @param9 inaccuracy - Variation to add onto trace angle
 * @param10 maxAngle - Maximum angle from forward angle that the attack can angle towards
 * @param11 dmgType - Drone damage type to use for attack | CDDmgType
 * @param12 type - Drone weapon type this bullet is fire from | CDWeaponType
 */

native void CD_FireBullet(int owner, int drone, float damage, const float[] origin, const float[] forwardAngle, float overrideX, float overrideY, float overrideZ, float inaccuracy, const float[] maxAngle, CDDmgType dmgType, CDWeaponType type);

/**
 * Fire the current drone's active weapon
 *
 * @param1 drone - Drone to override speed of
 * @param2 speed - Speed override
 */

native void CD_OverrideMaxSpeed(int drone, float speed);

/**
 * Fire the current drone's active weapon
 *
 * @param1 owner - client owning the drone
 * @param2 drone - Drone to damage
 */

native void CD_FireActiveWeapon(int owner, int drone);


/**
 * Deal damage to the given drone
 *
 * @param1 drone - Drone to damage
 * @param2 attacker - Entity responsible the damage
 * @param3 inflictor - Entity that dealt the damage
 * @param4 damage - Damage to deal
 * @param5 crit - Is this damage critical
 */

native void CD_DroneTakeDamage(int drone, int attacker, int inflictor, float damage, bool crit);

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
 * @param3 override - Override reload time if non-zero
 *
 */

native void CD_SetWeaponReloading(int drone, int weapon, float override = 0.0);

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
 * Retrieves an string parameter from the given drone config
 *
 * @param1 config - config file to check
 * @param2 key - subkey to retrieve value from
 * @param3 weapon - if non-zero, pull attribute for this weapon index
 * @param4 buffer - buffer to store string in
 * @param5 size - buffer size
 *
 * @return true on success
 */

native bool CD_GetParamString(const char[] config, const char[] key, int weapon = 0, char[] buffer, int size);

/**
 * Retrieves the attack sound for the given weapon
 *
 * @param1 config - config file to check
 * @param2 weapon - if non-zero, pull attribute for this weapon index
 * @param3 buffer - buffer to store string in
 * @param4 size - buffer size
 *
 * @return true on success
 */

native bool CD_GetWeaponAttackSound(const char[] config, int weapon = 0, char[] buffer, int size);

/**
 * Spawns a rocket based projectile for drones to fire
 *
 * @param1 owner - Player owning the drone
 * @param2 drone - Drone entity index
 * @param3 pos - Position of entity firing rocket (i.e cannon on a tank) | can be the drone itself if no weapon model exists
 * @param4 angle - Angle to use for offsetting positions
 * @param4 projectile - Type of rocket to spawn
 * @param5 damage - Damage of the rocket
 * @param6 speed - Speed of the rocket
 * @param7 overrideX - Forward position to offset rocket by (increase this value if the rocket is colliding with the drone model)
 * @param8 overrideY - Right position to offset rocket by
 * @param9 overrideZ - Up position to offset rocket by
 * @param10 inaccuracy - random variance added to projectile angles
 *
 * @return entity index of spawned rocket
 *
 */

native int CD_SpawnRocket(int owner, int drone, const float[] pos, const float[] angle, ProjType projectile, float damage, float speed = 1100.0, float overrideX = 60.0, float overrideY = 0.0, float overrideZ = 0.0, float inaccuracy = 0.0);

/**
 * Spawns a physics prop to use as a bomb projectile
 *
 * @param1 drone - Drone firing the projectile
 * @param2 pos - Position of entity firing rocket (i.e cannon on a tank) | can be the drone itself if no weapon model exists
 * @param3 angle - Angle to use for offsetting positions
 * @param4 damage - Damage of the bomb
 * @param5 speed - Speed applied to the bomb
 * @param6 overrideX - Forward position to offset rocket by (increase this value if the rocket is colliding with the drone model)
 * @param7 overrideY - Right position to offset rocket by
 * @param8 overrideZ - Up position to offset rocket by
 * @param9 inaccuracy - random variance added to projectile angles
 * @param10 bomb - buffer to store bomb struct
 *
 * @return true on success
 *
 */

native bool CD_SpawnDroneBomb(int drone, const float[] pos, const float[] angle, float damage, float speed = 0.0, float overrideX = 0.0, float overrideY = 0.0, float overrideZ = 0.0, float inaccuracy = 0.0, any bomb[sizeof BombEnt]);


/**
 * Retrieves the camera height for the given drone
 *
 * @param1 drone - drone entity index
 *
 */

native float CD_GetCameraHeight(int drone);

/**
 * Determines whether an entity is a drone
 *
 * @param1 entity - entity to check
 *
 */
 
native bool CD_IsValidDrone(int entity);

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

forward Action CD_OnDroneAttack(int drone, int owner, int Weapon, const char[] plugin_name);

/*************

STOCKS

*************/

stock void GetForwardPos(float origin[3], const float angles[3], float distance, float sideDistance = 0.0, float upDistance = 0.0, float buffer[3])
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

stock bool IsValidClient(int client)
{
    if (!( 1 <= client <= MaxClients ) || !IsClientInGame(client))
        return false;

    return true;
}
