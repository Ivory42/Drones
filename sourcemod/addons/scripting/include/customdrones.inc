#if defined _customdrones_included
 #endinput
#endif
#define _customdrones_included
#define MAXWEAPONS 6
#define MAX_WEAPON_LENGTH 64

#include <sdktools>
#include <entity>

//Projectile types to use for drone weapons. Using a type on the wrong native will use the default settings for that native
enum ProjType
{
	//rockets
	DroneProj_Rocket,	//Default rocket
	DroneProj_Energy,	//Cow mangler rocket
	DroneProj_Sentry,	//Sentry rocket salvo
	
	//Bombs
	DroneProj_Bomb,		//Default bomb, detonates on fuse timer which begins upon spawn
	DroneProj_BombDelayed,	//Fuse timer starts after touching a surface
	DroneProj_BombImpact,	//Bomb detonates upon impact rather than a fuse timer
	
	//misc
	DroneProj_Custom	//Custom projectile type for defining logic within sub plugins
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

enum CDWeaponState
{
	WeaponState_Active,
	WeaponState_Reloading,
	WeaponState_Destroyed,
	WeaponState_Custom
}

///
/// Struct to store all weapon info for specific drone weapons.
/// These can be accessed in a drone's plugin on specific forwards.
/// Do NOT directly access the properties 'weapon' or 'drone'.
///	- Use the methods GetWeapon() and GetDrone() instead.
///

enum struct DroneWeapon
{
	//entity references - DO NOT ACCESS DIRECTLY WITHOUT CONVERTING
	int weapon;
	int drone;
	
	//weapon stats
	int ammo;
	int maxammo;
	float firerate;
	float attackdelay;
	float damage;
	float inaccuracy;
	float reloadtime;
	float reloaddelay;
	
	//weapon state
	CDWeaponState state;
	
	//max pitch and yaw
	float pitch;
	float yaw;
	bool fixed;
	
	//appearance
	char model[PLATFORM_MAX_PATH];
	char name[MAX_WEAPON_LENGTH];
	float offset[3];
	float projoffset[3]; //offset based on weapon offset - this does NOT offset from the drone's world position
	
	//weapon parameters
	void SetName(char[] name)
	{
		FormatEx(this.name, MAX_WEAPON_LENGTH, name);
	}
	void SetModel(char[] model)
	{
		FormatEx(this.model, PLATFORM_MAX_PATH, model);
	}
	void SetOffset(float offset[3], bool proj)
	{
		for (int i = 0; i < 3; i++)
		{
			if (proj)
				this.projoffset[i] = offset[i];
			else
				this.offset[i] = offset[i];
		}
	}
	
	//Weapon functions
	void Spawn() //spawns the weapon and saves its reference
	{
		int wep = CreateEntityByName("prop_dynamic_override");
		float pos[3], rot[3];
		int drone = EntRefToEntIndex(this.drone);
		if (!IsValidEntity(drone)) LogError("Could not spawn drone weapon: Drone entity invalid!");
		
		DispatchKeyValue(wep, "model", this.model);
		GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(drone, Prop_Send, "m_angRotation", rot);
		GetOffsetPos(pos, rot, this.offset, pos);
		TeleportEntity(wep, pos, rot, NULL_VECTOR);
		DispatchSpawn(wep);
		SetVariantString("!activator");
		AcceptEntityInput(wep, "SetParent", drone, wep, 0);
		
		this.weapon = EntIndexToEntRef(wep);
	}
	int GetWeapon() //returns entity being used as this weapon
	{
		return EntRefToEntIndex(this.weapon);
	}
	int GetDrone()
	{
		return EntRefToEntIndex(this.drone);
	}
	void SimulateFire(Action action)
	{
		this.attackdelay = GetGameTime() + this.firerate;
		if (this.ammo == -1)
			return;
			
		switch (action)
		{
			case Plugin_Continue:
			{
				this.ammo--;
				if (this.ammo == 0)
					this.SimulateReload();
			}
		}
	}
	void Simulate() //weapon tick event
	{
		if (this.reloaddelay <= GetGameTime() && this.ammo == 0 && this.state == WeaponState_Reloading)
		{
			this.ammo = this.maxammo;
			this.state = WeaponState_Active;
		}
	}
	void SimulateReload()
	{
		this.ammo = 0;
		this.reloaddelay = GetGameTime() + this.reloadtime;
		this.reloading = true;
	}
	void GetWeaponTransform(float pos[3], float rot[3])	//retrieve this weapon's physical location in the world. Works regardless of whether the weapon has a model or not
	{
		int drone = this.GetDrone();
		if (IsValidEntity(drone))
		{
			GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
			GetEntPropVector(drone, Prop_Send, "m_angRotation", rot);
			GetOffsetPosition(pos, rot, this.offset, pos);
			int weapon = this.GetWeapon();
			if (IsValidEntity(weapon))
			{
				GetEntPropVector(weapon, Prop_Send, "m_angRotation", rot);
			}
		}
	}
	void GetMuzzleTransform(float pos[3], float rot[3])	//retrieve's this weapon's muzzle location in the world.
	{
		this.GetWeaponTransform(pos, rot);
		GetOffsetPosition(pos, rot, this.projoffset, pos);
	}
	bool CanFire(bool force)	//Can this weapon fire
	{
		if (force) //ignore attack delay
			return (this.ammo != 0 && this.state == WeaponState_Active);
		else
		{
			if (this.ammo != 0 && this.attackdelay <= GetGameTime() && this.state == WeaponState_Active)
				return true;
		}
		return false;
	}
	void GetName(char[] buffer, int size)
	{
		FormatEx(buffer, size, this.name);
	}
}

//should probably be a methodmap
enum struct DroneBomb
{
	int bomb;
	int drone;
	int explosion;
	bool touched;
	bool primed;
	bool isBomb;
	float fuseTime;
	float tickTime;
	char damage[8];
	char radius[8];
	ProjType type;
	
	void create(int ownerEnt, const char[] model, float baseDamage, float fuse, float dmgRadius, float pos[3])
	{
		this.bomb = CreateEntityByName("prop_physics_override");
		SetEntPropEnt(this.bomb, Prop_Send, "m_hOwnerEntity", ownerEnt);
		DispatchKeyValue(this.bomb, "Model", model);
		Format(this.damage, 8, "%.1f", baseDamage);
		Format(this.radius, 8, "%.1f", dmgRadius);
		this.fuseTime = fuse;
		TeleportEntity(this.bomb, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(this.bomb);
		ActivateEntity(this.bomb);
		//SetEntityModel(this.bomb, model);
		SetEntProp(this.bomb, Prop_Data, "m_nNextThinkTick", -1);
	}
	void detonate() //detonate our bomb
	{
		float detPos[3];
		GetEntPropVector(this.bomb, Prop_Data, "m_vecOrigin", detPos);
		int ownerPlayer = GetEntPropEnt(this.bomb, Prop_Send, "m_hOwnerEntity");
		AcceptEntityInput(this.bomb, "Kill");
		
		//clear variables
		this.isBomb = false;
		this.touched = false;
		this.primed = false;
		
		//setup explosion
		this.explosion = CreateEntityByName("env_explosion");
		SetEntPropEnt(this.explosion, Prop_Send, "m_hOwnerEntity", ownerPlayer);
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
 * @param3 weapon - Weapon object firing this attack
 * @param4 dmgType - Drone damage type to use for attack | CDDmgType
 * @param5 type - Drone weapon type this bullet is fire from | CDWeaponType
 */

native void CD_FireBullet(int owner, int drone, DroneWeapon weapon, CDDmgType dmgType, CDWeaponType type);

/**
 * Override max speed of the given drone
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
 * @param2 weapon - Struct to store the weapon info in
 * 
 * @return active slot index
 */

native int CD_GetDroneActiveWeapon(int drone, any weapon[sizeof DroneWeapon]);

/**
 * Get Drone Weapon from Slot
 *
 * @param1 drone - Drone ent index
 * @param2 slot - Which slot to get weapon info from
 * @param3 weapon - Struct to store the weapon info in
 * 
 */

native void CD_GetDroneWeapon(int drone, int slot, any weapon[sizeof DroneWeapon]);

/**
 * Set a drone's active weapon
 *
 * @param1 drone - Drone ent index
 * @param2 weapon - weapon index to swap to
 */

native void CD_SetDroneActiveWeapon(int drone, int weapon);

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
 * @param2 weapon - Slot of weapon being fired
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
 * @param3 weapon - Weapon object firing the attack
 * @param4 projectile - Type of rocket to spawn
 * @param5 speed - Speed of the rocket
 *
 * @return entity index of spawned rocket
 *
 */

native int CD_SpawnRocket(int owner, int drone, any weapon[sizeof DroneWeapon], ProjType projectile, float speed = 1100.0);

/**
 * Spawns a physics prop to use as a bomb projectile
 *
 * @param1 owner - Client damage should credited to
 * @param2 drone - Drone firing the projectile
 * @param3 weapon - Weapon object firing the attack
 * @param4 projectile - Projectile type to use for this bomb
 * @param5 modelname - Model for bomb to use
 * @param6 fuse - Fuse time on bomb
 * @param7 bomb - buffer to store bomb struct
 *
 * @return true on success
 *
 */

native bool CD_SpawnDroneBomb(int owner, int drone, any weapon[sizeof DroneWeapon], ProjType projectile, const char[] modelname, float fuse = 6.0, any bomb[sizeof DroneBomb]);


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
 * @param3 newWeapon - Weapon object that is being switched to
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
 * @param3 weapon - Weapon object that is being fired
 * @param4 slot - Weapon slot being used
 * @param4 plugin_name - Name of plugin defined in config
 */

forward Action CD_OnDroneAttack(int drone, int owner, DroneWeapon weapon, int slot, const char[] plugin_name);

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

void GetOffsetPos(float origin[3], float angles[3], float offset[3], float buffer[3])
{
	float dir[3];

	GetAngleVectors(angles, dir, NULL_VECTOR, NULL_VECTOR);
	ScaleVector(dir, offset[0]);
	AddVectors(origin, dir, buffer);

	GetAngleVectors(angles, NULL_VECTOR, dir, NULL_VECTOR);
	NegateVector(dir);
	ScaleVector(dir, offset[1]);
	AddVectors(buffer, dir, buffer);

	GetAngleVectors(angles, NULL_VECTOR, NULL_VECTOR, dir);
	ScaleVector(dir, offset[2]);
	AddVectors(buffer, dir, buffer);
}

stock bool IsValidClient(int client)
{
    if (!( 1 <= client <= MaxClients ) || !IsClientInGame(client))
        return false;

    return true;
}
