#if defined _customdrones_included
 #endinput
#endif
#define _customdrones_included
#define MAX_WEAPON_LENGTH 64
#define MAX_DRONE_LENGTH 32

#include "drones/drone.inc"

// StringMap wrapped to support drone objects. This can be used like a struct except it can be passed through timers.
methodmap SDroneStruct < StringMap
{
	public SDroneStruct()
	{
		StringMap data = new StringMap();
		return view_as<SDroneStruct>(data);
	}

	property ADrone Drone
	{
		public set(ADrone drone) { this.SetValue("PackedDrone", drone); }
		public get()
		{
			ADrone drone = null;
			this.GetValue("PackedDrone", drone);

			return drone;
		}
	}

	property ADronePlayer Player
	{
		public set(ADronePlayer player) { this.SetValue("PackedPlayer", player); }
		public get()
		{
			ADronePlayer player = null;
			this.GetValue("PackedPlayer", player);

			return player;
		}
	}

	property ADroneWeapon Weapon
	{
		public set(ADroneWeapon weapon) { this.SetValue("PackedWeapon", weapon); }
		public get()
		{
			ADroneWeapon weapon = null;
			this.GetValue("PackedWeapon", weapon);

			return weapon;
		}
	}
}


/****************************************************************
	NATIVES
****************************************************************/

methodmap FDroneStatics
{
	/**
	* Fire a hitscan attack from a drone's weapon
	*
	* @param gunner		Client firing this weapon
	* @param drone		Drone that the weapon is attached to
	* @param weapon		Weapon firing this attack
	*/
	public static native void FireBullets(ADronePlayer gunner, ADrone drone, ADroneWeapon weapon);

	/**
 	* Fire the current drone's active weapon
 	*
	* @param seat	Seat to fire the active weapon for
	*/
	public static native void FireActiveWeapon(FDroneSeat seat);
}
/**
 * Toggles view lock on the given drone. When disabled, the drone will NOT rotate to the angle the player is aiming.
 *
 * @param drone		Drone to toggle view lock on
 * @return			new view lock value
 */
//native bool CD_ToggleViewLocked(int drone);

/**
 * Override max speed of the given drone
 *
 * @param drone		Drone index to override speed of
 * @param speed		Speed override
 */
//native void CD_OverrideMaxSpeed(int drone, float speed);

/**
 * Deal damage to the given drone
 *
 * @param drone			Drone index to damage
 * @param attacker		Entity index responsible for the damage
 * @param inflictor		Entity index that dealt the damage
 * @param damage		Damage value to deal
 * @param crit			Is this damage critical
 */
//native void CD_DroneTakeDamage(int drone, int attacker, int inflictor, float damage, bool crit);

/**
 * Get a copy of a drone's active weapon
 *
 * @param drone		Drone index
 * @param weapon	Struct to store the weapon info in
 *
 * @return		active slot index
 */
//native int CD_GetDroneActiveWeapon(int drone, any weapon[sizeof FDroneWeapon]);

/**
 * Get a copy of a drone's weapon in a given slot
 *
 * @param drone		Drone index
 * @param slot		Which slot to get weapon info from
 * @param weapon	Struct to store the weapon info in
 *
 */
//native void CD_GetDroneWeapon(int drone, int slot, any weapon[sizeof FDroneWeapon]);

/**
 * Set a drone's active weapon slot
 *
 * @param drone		Drone index
 * @param weapon	weapon index to swap to
 */
//native void CD_SetDroneActiveWeapon(int drone, int weapon);

/**
 * Get a drone's current health
 *
 * @param drone		Drone index
 *
 * @return		current health of the drone
 */
//native int CD_GetDroneHealth(int drone);

/**
 * Get a drone's max health value
 *
 * @param drone		Drone index
 *
 * @return		max health of the drone
 */
//native int CD_GetDroneMaxHealth(int drone);

/**
 * Spawns a drone by config name and forces the given client to pilot it
 *
 * @param client		Client index to spawn drone for
 * @param drone_name	Name of drone to spawn
 *
 */
//native void CD_SpawnDroneByName(int client, const char[] drone_name, const float position[3]);

/**
 * Sets a drone weapon's reload state based on a fire delay
 *
 * @param drone			Drone index
 * @param weapon		Slot of weapon being fired
 * @param override		Override reload time if non-zero
 *
 */
//native void CD_SetWeaponReloading(int drone, int weapon, float override = 0.0);

/**
 * Retrieves a float parameter from the given drone config
 *
 * @param config		config file to check
 * @param key			subkey to retrieve value from
 * @param weapon		if non-zero, pull attribute for this specific weapon slot
 *
 * @return 				Float value of drone attribute, or value of a weapon attribute if given a slot
 */
//native float CD_GetParamFloat(const char[] config, const char[] key, int weapon = 0);

/**
 * Retrieves an integer parameter from the given drone config
 *
 * @param config		config file to check
 * @param key			subkey to retrieve value from
 * @param weapon		if non-zero, pull attribute for this specific weapon slot
 *
 * @return 				Integer value of drone attribute, or value of a weapon attribute if given a slot
 */
//native int CD_GetParamInteger(const char[] config, const char[] key, int weapon = 0);

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
//native bool CD_GetParamString(const char[] config, const char[] key, int weapon = 0, char[] buffer, int size);

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
//native int CD_SpawnRocket(int owner, int drone, any weapon[sizeof FDroneWeapon], EProjType projectile);

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
//native bool CD_SpawnDroneBomb(int owner, int drone, any weapon[sizeof FDroneWeapon], EProjType projectile, const char[] modelname, float fuse = 6.0, any bomb[sizeof FDroneBomb]);


/**
 * Retrieves a copy of this client's drone information
 *
 * @param client	Client index owning the drone
 * @param drone		Buffer struct to store the drone into
 *
 */
//native void CD_GetClientDrone(int client, any drone[sizeof FDrone]);

/**
 * Determines whether an entity is a drone
 *
 * @param entity	entity to check
 *
 */
//native bool CD_IsValidDrone(int entity);



/****************************************************************
	FORWARDS
****************************************************************/

/**
 * Forward called after a drone spawns
 *
 * @param drone				Drone that was created
 * @param name				Internal name of the drone
 * @param config			KeyValues associated with the drone
 * @note		The KeyValues are deleted upon the drone finishing creation. If any values are needed, cache them here.
 */
forward void CD2_OnDroneCreated(ADrone drone, const char[] name, KeyValues config);

/**
 * Forward called when a weapon is spawned and attached to a drone
 *
 * @param drone				Drone owning the weapon
 * @param weapon			Weapon that was created
 * @param name				Internal weapon name for plugins
 * @param config			KeyValues associated with the weapon
 * @note		The KeyValues are deleted upon the drone finishing creation. If any values are needed, cache them here.
*/
forward void CD2_OnWeaponCreated(ADrone drone, ADroneWeapon weapon, const char[] name, KeyValues config);

/**
 * Forward called after a player enters a drone
 *
 * @param drone				Drone being entered
 * @param client			Player entering the drone
 * @param seat				Seat being entered
 */
forward void CD2_OnPlayerEnterDrone(ADrone drone, ADronePlayer client, FDroneSeat seat);

/**
 * Forward called after a player exits a drone
 *
 * @param drone		Drone being exited
 * @param client	Player exiting the drone
 * @param seat		Seat player was in
 */
forward void CD2_OnPlayerExitDrone(ADrone drone, ADronePlayer client, FDroneSeat seat);

/**
 * Forward called after a drone is removed
 *
 * @param drone				Drone index being removed
 * @param plugin_name		Name of plugin defined in config
 */
//forward void CD_OnDroneRemoved(int drone, const char[] plugin_name);

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
//forward void CD_OnWeaponChanged(int drone, int pilot, FDroneWeapon weapon, int slot, const char[] weapon_logic, const char[] drone_logic);

/**
 * Forward called after a drone is destroyed but not yet removed
 *
 * @param drone				Drone object
 * @param pilot				Client object piloting the drone, can be null
 * @param attacker			Client object that killed the drone, can be null
 * @param damage			Damage dealt to drone
 * @param plugin_name		Name of plugin defining drone logic
 *
 */
//forward void CD_OnDroneDestroyed(FObject drone, FClient pilot, FClient attacker, float damage, const char[] plugin_name);

/**
 * Forward called after a weapon is fired
 *
 * @param drone				Drone owning this weapon
 * @param gunner			Client that fired this weapon
 * @param weapon			Weapon being fired
 * @param ammo				Ammo being consumed upon weapon fire
 * @param name				Internal name for the weapon being fired
 *
 * @return					How to handle ammo consumption: Plugin_Continue expends 1 ammo. Plugin_Changed expends the value ammo was set to. Plugin_Stop/Plugin_Handled will not expend any ammo
 */
forward Action CD2_OnWeaponFire(ADrone drone, ADronePlayer gunner, ADroneWeapon weapon, int& ammo, const char[] name);



/****************************************************************
	STOCKS
****************************************************************/

//converts a string into a CDMoveType
stock EMoveType GetMoveType(const char[] movetype)
{
	if (StrEqual(movetype, "drone_helo"))
		return MoveType_Helo;
	else if (StrEqual(movetype, "drone_fly"))
		return MoveType_Fly;
	else if (StrEqual(movetype, "drone_hover"))
		return MoveType_Hover;
	else if (StrEqual(movetype, "drone_custom"))
		return MoveType_Custom;

	return MoveType_Hover; // Fallback to hover if not a valid entry
}

stock EWeaponType GetWeaponType(KeyValues kv)
{
	char type[16];
	kv.GetString("weapon_type", type, sizeof type);

	if (StrEqual(type, "gun"))
		return WeaponType_Gun;
	else if (StrEqual(type, "laser"))
		return WeaponType_Laser;
	else if (StrEqual(type, "projectile"))
		return WeaponType_Projectile;
	else if (StrEqual(type, "custom"))
		return WeaponType_Custom;

	return WeaponType_Gun; // Defaults to gun if type is invalid
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

	target.Spawn();

	target.Teleport(end, ConstructRotator(), ConstructVector());

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

	tracer.Spawn();
	tracer.Activate();

	tracer.Teleport(start, ConstructRotator(), ConstructVector());

	target.KillOnDelay(0.5);
	tracer.KillOnDelay(0.5);
}

// Returns the index of the pilot seat for the given drone
stock FDroneSeat GetPilotSeat(ADrone drone)
{
	if (drone && drone.IsDrone)
	{
		int length = drone.Seats.Length;

		FDroneSeat seat = null;
		for (int i = 0; i < length; i++)
		{
			seat = drone.Seats.Get(i);
			if (seat.Type == Seat_Pilot)
				return seat;
		}
	}

	// No pilot seat found
	return null;
}

/**
 * Checks if the given client is in a drone and returns the seat index
 * 
 * @param client     Client to check
 * @param seats		 Array of drone seats to check
 * @return           Return seat type occupied by this client.
 */
/*stock int GetPlayerSeat(FClient client, FDroneSeat[] seats)
{
	int id = client.Get();

	if (Player[id].InDrone)
	{
		for (int i = 0; i < MAXSEATS; i++)
		{
			if (seats[i].Occupied)
			{
				FClient occupy;
				occupy = seats[i].GetOccupier();

				if (occupy.Get() == client.Get())
					return i;
			}
		}
	}

	return 0;
}

// Returns if the player is in a drone or not
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

// Sets the given drone as the client's currently occupied drone
stock void SetClientDrone(FClient client, FDrone drone)
{
	int clientId = client.Get();

	Player[clientId].Drone = drone;
	Player[clientId].InDrone = true;
}

// Clears the drone info for the given client
stock void ClearClientDrone(FClient client)
{
	int clientId = client.Get();

	Player[clientId].Drone.Clear();
	Player[clientId].InDrone = false;
}

// Exits a player from the given drone and frees up the given seat
stock void PlayerExitVehicle(FDrone drone, FDroneSeat seat, FClient client)
{
	if (drone.Valid() && client.Valid())
	{
		seat.Occupied = false;
		seat.Occupier.Clear();

		ClearClientDrone(client);

		SetEntityMoveType(client.Get(), MOVETYPE_WALK);

		switch (seat.Type)
		{
			case Seat_Pilot: drone.Owner.Clear();
		}
	}
}

// Enters a player into a specific seat of the given drone
stock void PlayerEnterVehicle(FDrone drone, FDroneSeat seat, FClient client)
{
	if (drone.Valid() && client.Valid())
	{
		seat.Occupied = true;
		seat.Occupier = client;

		SetClientDrone(client, drone);

		SetEntityMoveType(client.Get(), MOVETYPE_NONE);
		switch (seat.Type)
		{
			case Seat_Pilot: drone.Owner = client;
		}
	}
}
*/