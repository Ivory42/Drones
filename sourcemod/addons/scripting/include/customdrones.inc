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

native float CD_GetParamInteger(const char[] config, const char[] key, int weapon = 0);

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

// Spawns a projectile using a rocket as the base for a drone to fire, this projectile will spawn slightly ahead of the drone by default to prevent it from colliding
//  - depending on the size of your drone, you may want to increase overrideX
// override variables will adjust the rocket position relative to the drone's forward vector
stock int CD_SpawnRocket(int owner, int drone, ProjType projectile, float damage, float speed = 1100.0, float overrideX = 60.0, float overrideY = 0.0, float overrideZ = 0.0, float inaccuracy = 0.0)
{
	float pos[3], angle[3], spawnPos[3], velocity[3], aimAngle[3];
	char netname[64], classname[64];
	
	//Get Spawn Position
	GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);				//adjust position based on the physical weapon being used on the drone
	GetEntPropVector(drone, Prop_Data, "m_angRotation", angle);
	GetClientEyeAngles(owner, aimAngle);
	GetForwardPos(pos, angle, overrideX, overrideY, overrideZ, spawnPos);
	
	int rocket;
	CDDmgType dType;
	
	GetAngleVectors(angle, velocity, NULL_VECTOR, NULL_VECTOR);
	
	switch (projectile)
	{
		case DroneProj_Rocket:
		{
			Format(classname, sizeof classname, "tf_projectile_rocket");
			Format(netname, sizeof netname, "CTFProjectile_Rocket");
		}
		case DroneProj_Energy:
		{
			Format(classname, sizeof classname, "tf_projectile_energy_ball");
			Format(netname, sizeof netname, "CTFProjectile_EnergyBall");
		}
		case DroneProj_Sentry:
		{
			Format(classname, sizeof classname, "tf_projectile_sentryrocket");
			Format(netname, sizeof netname, "CTFProjectile_SentryRocket");
		}
	}
	
	rocket = CreateEntityByName(classname);
	ScaleVector(velocity, speed);
	SetEntPropVector(rocket, Prop_Send, "m_vInitialVelocity", velocity);
	int team = GetClientTeam(owner);
	
	//Get where our drone is aiming and direct the rocket towards that angle
	float aimPos[3], aimVec[3];
	CD_GetDroneAimPosition(drone, pos, aimAngle, aimPos);
	MakeVectorFromPoints(pos, aimPos, aimVec);
	GetVectorAngles(aimVec, angle);
	
	if (inaccuracy)
	{
		angle[0] += GetRandomFloat((inaccuracy * -1), inaccuracy);
		angle[1] += GetRandomFloat((inaccuracy * -1), inaccuracy);
	}
	
	//teleport to proper position and then spawn
	SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", owner);
	TeleportEntity(rocket, spawnPos, angle, velocity);
	
	SetVariantInt(team);
	AcceptEntityInput(rocket, "TeamNum", -1, -1, 0);

	SetVariantInt(team);
	AcceptEntityInput(rocket, "SetTeam", -1, -1, 0);
	
	DispatchSpawn(rocket);
	
	SetEntDataFloat(rocket, FindSendPropInfo(netname, "m_iDeflected") + 4, damage); //Set Damage for rocket
	
	return rocket;
}

stock void CD_GetDroneAimPosition(int drone, float pos[3, float angle[3], float buffer[3])
{
	Handle trace = TR_TraceRayFilterEx(pos, angle, MASK_SHOT, RayType_Infinite, FilterDrone, drone);
	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(buffer, trace);
		CloseHandle(trace);
		return;
	}
	CloseHandle(trace);
}

stock bool FilterDrone(int entity, int mask, int exclude)
{
	if (entity == exclude)
		return false;
		
	return true;
}

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
