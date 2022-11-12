#if defined _customdrones_included
 #endinput
#endif
#define _customdrones_included
#define MAX_WEAPON_LENGTH 64
#define MAX_DRONE_LENGTH 32
#define MAXSEATS 10

#include "drones/components.inc"

bool IsDrone[2049];

/*
*   Struct storing information for a drone object
*/

enum struct FDrone
{
	// Entity reference of this drone
	FObject hull;

	// Entity reference of the camera for this drone
	FObject camera;

	// Client currently piloting this drone
	FClient owner;

	// Optional model to use when drone is destroyed
	char destroyedModel[256];

	// Display name of this drone
	char name[64];

	// Camera height for this drone
	float cameraHeight;


	/*
	* Drone stats
	*/

	float health;
	float maxHealth;

	// Max speed this drone can move at
	float maxSpeed;

	// If non-zero, override our max speed with this value
	float speedoverride;

	// How quickly this drone reaches its max speed
	float acceleration;

	// Weapon count
	int weapons;
	int activeWeapon;
	int oldWeapon;
	FTimer weaponChangeTimer;

	// Delay after being destroyed when drone gets removed
	FTimer removeTimer;

	// Logic plugin for basic drone functions
	char plugin[32];

	// Config containing drone's info
	char config[64];

	// Is this drone alive
	bool alive;

	// Whether this drone should rotate towards the camera or not
	bool viewlocked;

	// Is there currently a player piloting this drone
	bool occupied;

	// Returns whether or not this drone's index is valid or not
	bool Valid()
	{
		return this.hull.Valid();
	}

	// Returns the entity index this drone is tied to
	int Get()
	{
		return this.hull.Get();
	}

	FObject GetHull()
	{
		return this.hull();
	}

	// Get the owner of this drone
	FObject GetOwner()
	{
		return this.hull.GetOwner();
	}

	// Set the owner of this drone
	void SetOwner(FObject owner)
	{
		this.hull.SetOwner(owner);
	}

	void PlayerEnterDrone(FClient client)
	{
		this.owner = client;
		SetEntityMoveType(client.Get(), MOVETYPE_NONE);
		this.occudpied = true;
	}
}

///
/// Player struct for organizing owned drones
///

enum struct FPlayer
{
	// Client's current drone
	FDrone Drone;

	bool InDrone;

	bool ValidDrone()
	{
		return this.drone.Valid();
	}
}
FPlayer Player[MAXPLAYERS+1];


/****************************************************************
	NATIVES
****************************************************************/

/**
 * Toggles view lock on the given drone. When disabled, the drone will NOT rotate to the angle the player is aiming.
 *
 * @param drone		Drone to toggle view lock on
 * @return			new view lock value
 */
native bool CD_ToggleViewLocked(int drone);

/**
 * Fire a hitscan attack from a drone's weapon
 *
 * @param owner			Client index who owns the drone
 * @param drone			Drone index firing the attack
 * @param weapon		Weapon object firing this attack
 * @param dmgType		Drone damage type to use for attack
 */
native void CD_FireBullet(int owner, int drone, any weapon[sizeof FDroneWeapon], EDamageType dmgType);

/**
 * Override max speed of the given drone
 *
 * @param drone		Drone index to override speed of
 * @param speed		Speed override
 */
native void CD_OverrideMaxSpeed(int drone, float speed);

/**
 * Fire the current drone's active weapon
 *
 * @param owner		client index owning the drone
 * @param drone		Drone index firing the weapon
 */
native void CD_FireActiveWeapon(int owner, int drone);

/**
 * Deal damage to the given drone
 *
 * @param drone			Drone index to damage
 * @param attacker		Entity index responsible for the damage
 * @param inflictor		Entity index that dealt the damage
 * @param damage		Damage value to deal
 * @param crit			Is this damage critical
 */
native void CD_DroneTakeDamage(int drone, int attacker, int inflictor, float damage, bool crit);

/**
 * Get a copy of a drone's active weapon
 *
 * @param drone		Drone index
 * @param weapon	Struct to store the weapon info in
 *
 * @return		active slot index
 */
native int CD_GetDroneActiveWeapon(int drone, any weapon[sizeof FDroneWeapon]);

/**
 * Get a copy of a drone's weapon in a given slot
 *
 * @param drone		Drone index
 * @param slot		Which slot to get weapon info from
 * @param weapon	Struct to store the weapon info in
 *
 */
native void CD_GetDroneWeapon(int drone, int slot, any weapon[sizeof FDroneWeapon]);

/**
 * Set a drone's active weapon slot
 *
 * @param drone		Drone index
 * @param weapon	weapon index to swap to
 */
native void CD_SetDroneActiveWeapon(int drone, int weapon);

/**
 * Get a drone's current health
 *
 * @param drone		Drone index
 *
 * @return		current health of the drone
 */
native int CD_GetDroneHealth(int drone);

/**
 * Get a drone's max health value
 *
 * @param drone		Drone index
 *
 * @return		max health of the drone
 */
native int CD_GetDroneMaxHealth(int drone);

/**
 * Spawns a drone by config name and forces the given client to pilot it
 *
 * @param client		Client index to spawn drone for
 * @param drone_name	Name of drone to spawn
 *
 */
native void CD_SpawnDroneByName(int client, const char[] drone_name);

/**
 * Sets a drone weapon's reload state based on a fire delay
 *
 * @param drone			Drone index
 * @param weapon		Slot of weapon being fired
 * @param override		Override reload time if non-zero
 *
 */
native void CD_SetWeaponReloading(int drone, int weapon, float override = 0.0);

/**
 * Retrieves a float parameter from the given drone config
 *
 * @param config		config file to check
 * @param key			subkey to retrieve value from
 * @param weapon		if non-zero, pull attribute for this specific weapon slot
 *
 * @return 				Float value of drone attribute, or value of a weapon attribute if given a slot
 */
native float CD_GetParamFloat(const char[] config, const char[] key, int weapon = 0);

/**
 * Retrieves an integer parameter from the given drone config
 *
 * @param config		config file to check
 * @param key			subkey to retrieve value from
 * @param weapon		if non-zero, pull attribute for this specific weapon slot
 *
 * @return 				Integer value of drone attribute, or value of a weapon attribute if given a slot
 */
native int CD_GetParamInteger(const char[] config, const char[] key, int weapon = 0);

/**
 * Retrieves a string parameter from the given drone config
 *
 * @param config		config file to check
 * @param key			subkey to retrieve value from
 * @param weapon		if non-zero, pull attribute for this specific weapon slot
 * @param buffer		buffer to store string in
 * @param size			buffer size
 *
 * @return true on success
 */
native bool CD_GetParamString(const char[] config, const char[] key, int weapon = 0, char[] buffer, int size);

/**
 * Spawns a rocket based projectile for drones to fire
 *
 * @param owner			Client index owning the drone
 * @param drone			Drone index
 * @param weapon		Weapon object firing the attack
 * @param projectile	Type of rocket to spawn
 *
 * @return				entity index of spawned rocket
 *
 */
native int CD_SpawnRocket(int owner, int drone, any weapon[sizeof FDroneWeapon], EProjType projectile);

/**
 * Spawns a physics prop to use as a bomb projectile - CURRENTLY NOT WORKING
 *
 * @param owner			Client index owning the drone
 * @param drone			Drone firing the projectile
 * @param weapon		Weapon object firing the attack
 * @param projectile	Projectile type to use for this bomb - Determines function of fuse timer
 * @param modelname		Model for bomb to use
 * @param fuse			Fuse time on bomb
 * @param bomb			buffer to store bomb struct
 *
 * @return				true on success
 *
 */
native bool CD_SpawnDroneBomb(int owner, int drone, any weapon[sizeof FDroneWeapon], EProjType projectile, const char[] modelname, float fuse = 6.0, any bomb[sizeof FDroneBomb]);


/**
 * Retrieves a copy of this client's drone information
 *
 * @param client	Client index owning the drone
 * @param drone		Buffer struct to store the drone into
 *
 */
native void CD_GetClientDrone(int client, any drone[sizeof FDrone]);

/**
 * Determines whether an entity is a drone
 *
 * @param entity	entity to check
 *
 */
native bool CD_IsValidDrone(int entity);



/****************************************************************
	FORWARDS
****************************************************************/

/**
 * Forward called after a drone spawns
 *
 * @param drone				Drone object being spawned - by reference
 * @param plugin_name		Name of plugin defined in config
 * @param config			Config for this drone
 */
forward void CD_OnDroneCreated(FDrone drone, const char[] plugin_name, const char[] config);

/**
 * Forward called when a weapon is spawned and attached to a drone
 *
 * @param drone				Drone owning the weapon - by reference
 * @param weapon			Weapon object that was spawned - by reference
 * @param plugin_name		Name of plugin defining this weapon's logic
 * @param config			Config for the owning drone
*/
forward void CD_OnWeaponCreated(FDrone drone, FDroneWeapon weapon, const char[] plugin_name, const char[] config);

/**
 * Forward called after a player enters a drone
 *
 * @param drone				Drone object being entered - by reference
 * @param client			Client index of the player
 * @param seat				Seat player is entering
 * @param plugin_name		Name of plugin defined for this drone
 * @param config			Config for this drone
 */
forward void CD_OnPlayerEnterDrone(FDrone drone, int client, int seat, const char[] plugin_name, const char[] config);

/**
 * Forward called after a player exits a drone
 *
 * @param drone		Drone object being exited - by reference
 * @param client	Client index of player
 * @param seat		Seat player was in
 */
forward void CD_OnPlayerExitDrone(DroneProp drone, int client, int seat);

/**
 * Forward called after a drone is removed
 *
 * @param drone				Drone index being removed
 * @param plugin_name		Name of plugin defined in config
 */
forward void CD_OnDroneRemoved(int drone, const char[] plugin_name);

/**
 * Forward called after a drone switches weapons
 *
 * @param drone				Drone index
 * @param pilot				Client index of owning player
 * @param weapon			Weapon object being switched to
 * @param slot				Weapon slot being switched to
 * @param weapon_logic		Name of plugin defining weapon logic
 * @param drone_logic		Name of plugin defining drone logic
 */
forward void CD_OnWeaponChanged(int drone, int pilot, DroneWeapon weapon, int slot, const char[] weapon_logic, const char[] drone_logic);

/**
 * Forward called after a drone is destroyed but not yet removed
 *
 * @param drone				Drone Index
 * @param pilot				Client index of pilot, can be invalid
 * @param attacker			Client index of attacker
 * @param damage			Damage dealt to drone
 * @param plugin_name		Name of plugin defining drone logic
 *
 */
forward void CD_OnDroneDestroyed(int drone, int pilot, int attacker, float damage, const char[] plugin_name);

/**
 * Forward called after a weapon is fired
 *
 * @param drone				Drone index
 * @param gunner			Client index of player operating the weapon
 * @param weapon			Weapon object that is being fired
 * @param slot				Weapon slot being used
 * @param weapon_logic		Name of plugin defining weapon logic
 * @param drone_logic		Name of plugin defining drone logic
 *
 * @return					How to handle ammo consumption: Anything above Plugin_Continue will not consume ammo
 */
forward Action CD_OnDroneAttack(int drone, int gunner, FDroneWeapon weapon, int slot, const char[] weapon_logic, const char[] drone_logic);



/****************************************************************
	STOCKS
****************************************************************/

//converts a string into a CDMoveType
stock EMoveType GetMoveType(const char[] movetype)
{
	if (StrEqual(movetype, "drone_hover"))
		return MoveType_Hover;
	else if (StrEqual(movetype, "drone_fly"))
		return MoveType_Fly;
	else if (StrEqual(movetype, "drone_ground"))
		return MoveType_Ground;
	else if (StrEqual(movetype, "drone_custom"))
		return MoveType_Custom;

	return MoveType_Hover; // Fallback to hover if not a valid entry
}

/*
*	Get a position offset from the given origin relative to the given angle
*
* @param origin		Starting position to check offset on
* @param angles		Angle to dictate how the offset is calculated
* @param offset		Vector to offset the given origin by in respect to the given angle
*/

stock FVector GetOffsetPos(const FVector origin, const FRotator angles, const FVector offset)
{
	FVector direction, result;
	result = origin;

	direction = angles.GetForwardVector();
	direction.Scale(offset.x);
	result.Add(direction);

	direction = angles.GetRightVector();
	direction.Negate();
	direction.Scale(offset.y);
	result.Add(direction);

	direction = angles.GetUpVector();
	direction.Scale(offset.z);
	result.Add(direction);

	return result;
}

/*
* Create a visual bullet tracer between two positions. The spawned entities are automatically removed
*
* @param start		Origin of the bullet tracer
* @param end		Position where the bullet will travel to
*
*/
stock void CreateTracer(FVector start, FVector end)
{
	FObject target;
	target.Create("prop_dynamic_override"); //env_gunfire requres an entity to use as a target

	char targetname[64];

	Format(targetname, sizeof targetname, "target%i", target.Get());

	target.SetKeyValue("targetname", targetname);

	target.SetModel("models/empty.mdl");

	target.Teleport(end, FRotator(), FVector());
	target.Spawn();

	FObject tracer;
	tracer.Create("env_gunfire"); //create the actual tracer

	tracer.SetKeyValue("target", targetname);
	
	tracer.SetKeyValue("minburstsize", "1");
	tracer.SetKeyValue("maxburstsize", "1");

	tracer.SetKeyValue("minburstdelay", "5.0");
	tracer.SetKeyValue("maxburstdelay", "10.0");

	tracer.SetKeyValue("rateoffire", "1.0");
	tracer.SetKeyValue("collisions", "1");
	tracer.SetKeyValue("spread", "0");

	tracer.Teleport(start, FRotator(), FVector());

	tracer.Spawn();
	tracer.Activate();

	TeleportEntity(tracer, start, NULL_VECTOR, NULL_VECTOR);

	target.KillOnDelay(0.5);
	trace.KillOnDelay(0.5);
}

// Returns the current drone being piloted by this player
stock FObject GetClientDrone(FClient client)
{
	FObject drone;
	if (client.Valid())
	{
		int clientId = client.Get();

		FObject check;
		check = Player[clientId].GetDrone();

		if (IsValidDrone(check))
			drone = check;
	}

	return drone;
}

// Checks if the given client is in a drone or not
stock bool PlayerInDrone(FClient client)
{
	int id = client.Get();

	return Player[id].InDrone;
}

// Returns true if the given FObject is a drone
stock bool IsValidDrone(FObject entity)
{
	if (entity.Valid())
	{
		int id = entity.Get();

		return IsDrone[id];
	}
	return false;
}