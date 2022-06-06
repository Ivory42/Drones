#if defined _customdrones_included
 #endinput
#endif
#define _customdrones_included
#define MAXWEAPONS 6
#define MAX_WEAPON_LENGTH 64
#define MAX_DRONE_LENGTH 32
#define MAXSEATS 10

#include <sdktools>
#include <entity>

//Projectile types to use for drone weapons. Using a type on the wrong native will use the default settings for that native
enum ProjType
{
	DroneProj_None,
	//rockets
	DroneProj_Rocket,	//Default rocket
	DroneProj_Energy,	//Cow mangler rocket
	DroneProj_Sentry,	//Sentry rocket salvo
	DroneProj_Impact, 	//Rocket which deals impact damage with no explosion

	//Bombs
	DroneProj_Bomb,		//Default bomb, detonates on fuse timer which begins upon spawn
	DroneProj_BombDelayed,	//Fuse timer starts after touching a surface
	DroneProj_BombImpact,	//Bomb detonates upon impact rather than a fuse timer

	//misc
	DroneProj_Custom	//Custom projectile type for defining logic within sub plugins
};

enum CDMoveType
{
	DroneMove_Hover,	//hovering, moves in all directions
	DroneMove_Fly,		//flying, can only move forward
	DroneMove_Ground,	//ground wheeled vehicles, can only steer while moving
	DroneMove_Tracked	//ground tracked vehicles, such as tanks, can steer without moving
};

enum CDDmgType
{
	DmgType_Hitscan,	//hitscan generic damage
	DmgType_Rangeless, 	//hitscan damage with no falloff

	//Custom damage type for plugins
	DmgType_Custom
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
/// Structs for components and players related to drones
/// Each component will act as a pointer to the entity
/// Use component's getter and setters when accessing
///

enum struct Component
{
	int pointer; //ref
	char model[256]; //if using a model for this component
	
	int maxhealth; //optional health value
	int health;
	
	void set(int entity)
	{
		this.pointer = EntIndexToEntRef(entity);
	}
	int get()
	{
		return EntRefToEntIndex(this.pointer);
	}
	bool valid()
	{
		int entity = this.get();
		if (IsValidEntity(entity) && entity > MaxClients)
			return true;
			
		return false;
	}
	
	void clear()
	{
		this.pointer = INVALID_ENT_REFERENCE;
	}
}

enum struct Player
{
	int userid;
	
	int seat; //seat currently being occupied
	
	int get()
	{
		return GetClientOfUserId(this.userid);
	}
	void set(int client)
	{
		this.userid = GetClientUserId(client);
	}
	bool valid()
	{
		int client = this.get();
		if (IsValidClient(client))
			return true;
			
		return false;
	}
	
	void clear()
	{
		this.userid = -1;
	}
}

///
/// Struct to store all weapon info for specific drone weapons.
/// These can be accessed in a drone's plugin on specific forwards.
///

enum struct DroneWeapon
{
	//Components
	Component receiver;
	Component drone;

	//weapon stats
	int ammo;
	int maxammo;
	float firerate;
	float attackdelay;
	float damage;
	float projspeed;
	float inaccuracy;
	float reloadtime;
	float reloaddelay;
	char firesound[PLATFORM_MAX_PATH];

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

	//weapon parameters - deprecated
	void SetName(char[] name)
	{
		FormatEx(this.name, MAX_WEAPON_LENGTH, name);
	}
	void SetModel(char[] model)
	{
		FormatEx(this.model, PLATFORM_MAX_PATH, model);
	}
	void SetFire(char[] firesound)
	{
		FormatEx(this.firesound, PLATFORM_MAX_PATH, firesound);
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
		int drone = this.drone.get();
		if (!IsValidEntity(drone) || drone <= MaxClients) LogError("Could not spawn drone weapon: Drone entity invalid!");

		DispatchKeyValue(wep, "model", this.model);
		GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(drone, Prop_Send, "m_angRotation", rot);
		float offset[3];
		FormatVector(offset, this.offset[0], this.offset[1], this.offset[2]); //sigh..
		GetOffsetPos(pos, rot, offset, pos);
		TeleportEntity(wep, pos, rot, NULL_VECTOR);
		DispatchSpawn(wep);
		SetVariantString("!activator");
		AcceptEntityInput(wep, "SetParent", drone, wep, 0);

		this.receiver.set(wep);
	}
	int GetWeapon() //returns entity being used as this weapon - deprecated
	{
		return EntRefToEntIndex(this.receiver.pointer);
	}
	int GetDrone() //deprecated
	{
		return EntRefToEntIndex(this.drone.pointer);
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
		if (this.ammo < this.maxammo)
		{
			this.ammo = 0;
			this.reloaddelay = GetGameTime() + this.reloadtime;
			this.state = WeaponState_Reloading;
		}
	}
	void GetWeaponTransform(float pos[3], float rot[3])	//retrieve this weapon's physical location in the world. Works regardless of whether the weapon has a model or not
	{
		int drone = this.drone.get();
		if (IsValidEntity(drone) && drone > MaxClients)
		{
			GetEntPropVector(drone, Prop_Data, "m_vecOrigin", pos);
			GetEntPropVector(drone, Prop_Send, "m_angRotation", rot);
			float offset[3];
			FormatVector(offset, this.offset[0], this.offset[1], this.offset[2]); //sigh..
			GetOffsetPos(pos, rot, offset, pos);
			int weapon = this.receiver.get();
			if (IsValidEntity(weapon) && weapon > MaxClients)
			{
				GetEntPropVector(weapon, Prop_Send, "m_angRotation", rot);
			}
		}
	}
	void GetMuzzleTransform(float pos[3], float rot[3])	//retrieve's this weapon's muzzle location in the world.
	{
		this.GetWeaponTransform(pos, rot);
		float offset[3];
		offset = this.projoffset;
		//FormatVector(offset, this.projoffset[0], this.projoffset[1], this.projoffset[2]); //sigh..
		GetOffsetPos(pos, rot, offset, pos);
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

enum struct DroneProp
{
	//Owner and components
	Component hull;
	Player owner;
	Component camera;

	//appearance
	char model[PLATFORM_MAX_PATH];
	char destroyedmodel[PLATFORM_MAX_PATH];
	char name[MAX_DRONE_LENGTH];
	float cameraheight;

	//stats
	float health;
	float maxhealth;
	float speedoverride;
	float maxspeed;
	float acceleration;
	float turnrate;

	//logic
	CDMoveType movetype;
	char plugin[32];
	char config[32];
	bool dead;
	bool viewlocked;
	bool occupied;

	//weapons
	int weapons;
	int activeweapon;
	int oldweapon;
	float changecooldown;

	void clear()
	{
		this.hull.clear();
		this.owner.clear();
		this.camera.clear();
		this.occupied = false;
	}
	void SetConfig(const char[] config)
	{
		FormatEx(this.config, 32, config);
	}
	int GetDrone() //deprecated
	{
		return EntRefToEntIndex(this.hull.pointer);
	}
	int GetOwner() //deprecated
	{
		return GetClientOfUserId(this.owner.userid);
	}
	int GetCamera() //deprecated
	{
		return EntRefToEntIndex(this.camera.pointer);
	}
	int Spawn(KeyValues config, int drone, float pos[3], float angles[3], float vel[3])
	{
		//Establish drone attributes
		config.GetString("name", this.name, MAX_DRONE_LENGTH);
		config.GetString("model", this.model, PLATFORM_MAX_PATH);
		config.GetString("destroyed_model", this.destroyedmodel, PLATFORM_MAX_PATH, this.name);
		this.maxhealth = config.GetFloat("health", 100.0);
		this.maxspeed = config.GetFloat("speed", 300.0);
		this.acceleration = config.GetFloat("acceleration", 5.0);
		this.speedoverride = 0.0;
		this.turnrate = config.GetFloat("turn_rate", 80.0);

		char movetype[64];
		config.GetString("movetype", movetype, sizeof movetype, "drone_hover");
		this.movetype = GetMoveType(movetype);

		config.GetString("plugin", this.plugin, 32, "INVALID_PLUGIN");
		this.cameraheight = config.GetFloat("camera_height", 30.0);

		//drone appearance
		DispatchKeyValue(drone, "model", this.model);
		DispatchKeyValue(drone, "health", "900");

		if(HasEntProp(drone, Prop_Data, "m_takedamage"))
			SetEntProp(drone, Prop_Data, "m_takedamage", 1);
		else
			LogMessage("Tried to spawn a drone with no m_takedamage netprop!");
		this.health = this.maxhealth;
		this.dead = false;

		DispatchSpawn(drone);
		ActivateEntity(drone);
		TeleportEntity(drone, pos, angles, vel);

		this.oldweapon = 1;
		this.activeweapon = this.oldweapon;
		//PrintToChat(client, "Successfully created drone (%s) with owner: %i", drone_name, DroneOwner[hDrone]);

		this.hull.set(drone);
		PrintToChatAll("Drone reference set to entity: %i", drone);
		return drone;
	}
	void PlayerPilot(int client)
	{
		this.owner.set(client);
		SetEntityMoveType(client, MOVETYPE_NONE);
		this.occupied = true;
	}
	void PlayerEnterSeat(int client, const char[] seatname)
	{
		//
	}
}

//To be reworked, does not work for now
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

native void CD_FireBullet(int owner, int drone, any weapon[sizeof DroneWeapon], CDDmgType dmgType, CDWeaponType type);

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
 * @param2 drone - Drone firing the weapon
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

native int CD_SpawnRocket(int owner, int drone, any weapon[sizeof DroneWeapon], ProjType projectile);

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
 * Retrieves the client's drone struct
 *
 * @param1 client - Client index owning the drone
 * @param2 drone - Buffer struct to store the drone into
 *
 */

native float CD_GetClientDrone(int client, any drone[sizeof DroneProp]);

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
 * @param1 drone - Drone object being spawned
 * @param2 plugin_name - Name of plugin defined in config
 * @param3 config - Config for this drone
 */

forward void CD_OnDroneCreated(DroneProp drone, const char[] plugin_name, const char[] config);

/**
 * Forward called after a player enters a drone
 *
 * @param1 drone - Drone object being spawned
 * @param2 client - Client index of player
 * @param3 seat - Seat player is entering
 * @param4 plugin_name - Name of plugin defined in config
 * @param5 config - Config for this drone
 */

forward void CD_OnPlayerEnterDrone(DroneProp drone, int client, int seat, const char[] plugin_name, const char[] config);

/**
 * Forward called after a player exits a drone
 *
 * @param1 drone - Drone object being spawned
 * @param2 client - Client index of player
 * @param3 seat - Seat player was in
 */

forward void CD_OnPlayerExitDrone(DroneProp drone, int client, int seat);

/**
 * Forward called after a drone is removed
 *
 * @param1 drone - Ent index of drone
 * @param2 plugin_name - Name of plugin defined in config
 */

forward void CD_OnDroneRemoved(int drone, const char[] plugin_name);

/**
 * Forward called after a drone switches weapons
 *
 * @param1 drone - Ent index of drone
 * @param2 pilot - Client index of pilot
 * @param3 weapon - Weapon object being switched to
 * @param4 slot - Weapon slot being switched to
 * @param5 plugin_name - Name of plugin defined in config
 */

forward void CD_OnWeaponChanged(int drone, int pilot, DroneWeapon weapon, int slot, const char[] plugin_name);

/**
 * Forward called after a drone is destroyed but not yet removed
 *
 * @param1 drone - Ent index of drone
 * @param2 pilot - Client index of pilot, can be invalid
 * @param3 attacker - Client index of attacker
 * @param4 damage - Damage dealt to drone
 * @param5 plugin_name - Name of plugin defined in config
 *
 */

forward void CD_OnDroneDestroyed(int drone, int pilot, int attacker, float damage, const char[] plugin_name);

/**
 * Forward called after a weapon is fired
 *
 * @param1 drone - Ent index of drone
 * @param2 gunner - Client index of player operating the weapon
 * @param3 weapon - Weapon object that is being fired
 * @param4 slot - Weapon slot being used
 * @param4 plugin_name - Name of plugin defined in config
 */

forward Action CD_OnDroneAttack(int drone, int gunner, DroneWeapon weapon, int slot, const char[] plugin_name);

/*************

STOCKS

*************/

//vectors in structs are annoying, so using this to "format" a vector as needed
stock void FormatVector(float vec[3], float x, float y, float z)
{
	vec[0] = x;
	vec[1] = y;
	vec[2] = z;
}

//converts a string into a CDMoveType
stock CDMoveType GetMoveType(const char[] movetype)
{
	if (StrEqual(movetype, "drone_hover"))
		return DroneMove_Hover;
	else if (StrEqual(movetype, "drone_fly"))
		return DroneMove_Fly;
	else if (StrEqual(movetype, "drone_ground"))
		return DroneMove_Ground;

	return DroneMove_Hover;
}

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

void GetOffsetPos(float origin[3], float angles[3], any offset[3], float buffer[3])
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
