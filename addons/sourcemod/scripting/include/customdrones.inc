#if defined _customdrones_included
 #endinput
#endif
#define _customdrones_included
#define MAX_WEAPON_LENGTH 64
#define MAX_DRONE_LENGTH 32

#include "drones/drone.inc"
#include "drones/ai.inc"

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

	property FDroneSeat Seat
	{
		public set(FDroneSeat seat) { this.SetValue("PackedSeat", seat); }
		public get()
		{
			FDroneSeat seat = null;
			this.GetValue("PackedSeat", seat);

			return seat;
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
	* @param seat		Seat firing this weapon
	*/
	public static native void FireBullets(ADronePlayer gunner, ADrone drone, ADroneWeapon weapon, FDroneSeat seat);

	/**
 	* Fire the current drone's active weapon
 	*
	* @param seat	Seat to fire the active weapon for
	*/
	public static native void FireActiveWeapon(FDroneSeat seat);

	/**
	 * Spawns a drone with the given config name
	 * 
	 * @param config		Drone config to spawn
	 * @param spawn			Spawn transform for this drone
	 */
	public static native ADrone SpawnDroneByConfig(char[] config, any spawn[sizeof FTransform]);

	/**
	 * Spawns a controlled drone with the given config and AI
	 * 
	 * @param drone			Drone config to spawn
	 * @param controller	AI controller config to use
	 * @param spawn			Spawn transform for this drone
	 * @note 	This controller will always occupy the pilot seat of the drone
	 */
	public static native ADrone SpawnDroneWithController(char[] drone, char[] controller, any spawn[sizeof FTransform]);

	/**
	 * Occupies a drone seat with an AI controller
	 * 
	 * @param drone			Drone being entered
	 * @param seat			Drone seat to occupy
	 * @param ai			AI controller to occupy the seat with
	 */
	public static native ADrone AIControlDroneSeat(ADrone drone, FDroneSeat seat, FDroneAI ai);
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
 * Forward called after an AI takes control of a drone seat
 *
 * @param drone				Drone being entered
 * @param ai				AI controller assuming control
 * @param seat				Seat being entered
 */
forward void CD2_OnAIControlDrone(ADrone drone, FDroneAI ai, FDroneSeat seat);

/**
 * Forward called after a player exits a drone
 *
 * @param drone		Drone being exited
 * @param client	Player exiting the drone
 * @param seat		Seat player was in
 */
forward void CD2_OnPlayerExitDrone(ADrone drone, ADronePlayer client, FDroneSeat seat);

/**
 * Forward called right before a drone is removed
 *
 * @param drone				Drone being removed
 * @param name				Internal name of the drone
 */
forward void CD2_OnDroneRemoved(ADrone drone, const char[] name);

/**
 * Forward called right before a weapon is removed
 *
 * @param weapon			Weapon being removed
 * @param name				Internal name of the weapon
 */
forward void CD2_OnWeaponRemoved(ADroneWeapon weapon, const char[] name);

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
 * @param attacker			Entity that killed the drone, may be empty
 * @param damage			Damage amount that killed the drone
 * @param name				Internal name of the drone
 *
 */
forward void CD2_OnDroneDestroyed(ADrone drone, FObject attacker, float damage, const char[] name);

/**
 * Forward called when a drone takes damage
 *
 * @param drone				Drone object
 * @param attacker			Entity that damaged the drone, may be empty.
 * @param damage			Damage amount for the drone to receive
 * @param damagetype		Damage bits of the damgae dealt
 *
 * @return Plugin_Changed to update damage and damagetype, otherwise continue normally
 */
forward Action CD2_OnDroneDamaged(ADrone drone, FObject attacker, float &damage, int& damagetype);


/**
 * Forward called after a weapon is fired
 *
 * @param drone				Drone owning this weapon
 * @param gunner			Client that fired this weapon
 * @param weapon			Weapon being fired
 * @param seat				Seat firing this weapon
 * @param ammo				Ammo being consumed upon weapon fire
 * @param name				Internal name for the weapon being fired
 *
 * @return					How to handle ammo consumption: Plugin_Continue expends 1 ammo. Plugin_Changed expends the value ammo was set to. Plugin_Stop/Plugin_Handled will not expend any ammo
 */
forward Action CD2_OnWeaponFire(ADrone drone, ADronePlayer gunner, ADroneWeapon weapon, FDroneSeat seat, int& ammo, const char[] name);

/**
 * Forward called when an AI controlled drone finds a target
 *
 * @param controller 		AI controller controlling this drone
 * @param drone				Drone occupied by the AI
 * @param targetEnemies		If true, this drone is looking for enemies, otherwise it is looking for teammates
 * @param target 			Target that this drone has acquired
 *
 * @return 			How to handle target acquisition: Plugin_Continue keeps the original target. Plugin_Handled or Plugin_Changed will update the target upon completion of this forward.
 */
forward Action CD2_OnAIFindTarget(FDroneAI controller, ADrone drone, bool targetEnemies, APersistentObject& target);

/**
 * Forward called when an AI controlled drone is about to move
 *
 * @param controller 		AI controller controlling this drone
 * @param drone				Drone occupied by the AI
 * @param position 			Position this drone will move to
 *
 * @return 			How to handle movement: Plugin_Continue finds a position normally. Plugin_Changed will force the given move position. Plugin_Handled or Plugin_Stopped will prevent a move position from being found.
 */
forward Action CD2_OnAIGetMovePosition(FDroneAI controller, ADrone drone, FVector position);

/**
 * Forward called upon an AI controller processing a think request
 * 
 * @param controller		AI controller processing request
 * @param drone				Drone being controlled
 */
forward void CD2_OnAITick(FDroneAI controller, ADrone drone);

/**
 * Forward called upon an AI controller attempting to fire a weapon
 * 
 * @param controller		AI controller processing request
 * @param drone				Drone being controlled
 * @param weapon			Weapon being fired
 * 
 * @return Plugin_Continue to allow the weapon to fire, otherwise prevent the weapon from firing
 */
forward Action CD2_OnAIAttack(FDroneAI controller, ADrone drone, ADroneWeapon weapon);


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
	target = FGameplayStatics.CreateObjectDeferred("info_target"); //env_gunfire requres an entity to use as a target

	char targetname[64];

	Format(targetname, sizeof targetname, "target%i", target.Get());

	target.SetKeyValue("targetname", targetname);

	//target.SetModel("models/empty.mdl");

	FGameplayStatics.FinishSpawn(target, ConstructTransform(end, ConstructRotator()));

	FObject tracer;
	tracer = FGameplayStatics.CreateObjectDeferred("env_gunfire"); //create the actual tracer

	tracer.SetKeyValue("target", targetname);
	
	tracer.SetKeyValue("minburstsize", "1");
	tracer.SetKeyValue("maxburstsize", "1");

	tracer.SetKeyValue("minburstdelay", "5.0");
	tracer.SetKeyValue("maxburstdelay", "10.0");

	tracer.SetKeyValue("rateoffire", "1.0");
	tracer.SetKeyValue("collisions", "1");
	tracer.SetKeyValue("spread", "0");

	FGameplayStatics.FinishSpawn(tracer, ConstructTransform(start, ConstructRotator()));

	CreateTimer(0.5, KillBullet, target.GetReference(), TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(0.5, KillBullet, tracer.GetReference(), TIMER_FLAG_NO_MAPCHANGE);
}

Action KillBullet(Handle timer, int reference)
{
	FObject entity;
	entity.SetReference(reference);

	if (entity.Valid())
	{
		if (entity.Cast("prop_physics") || entity.Cast("prop_physics_multiplayer") || entity.Cast("prop_dynamic"))
		{
			PrintToChatAll("Bullet entity mismatched to %d", entity.Get());
		}
		entity.Kill();
	}

	return Plugin_Stop;
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

stock FVector GetDroneAimPosition(ADrone drone, FRotator rotation, float range = 8000.0)
{
	FVector start, direction, end;
	start = GetCameraOffset(drone);

	direction = rotation.GetForwardVector();
	direction.Scale(range);
	direction.Add(start);

	FRayTraceSingle trace = new FRayTraceSingle(start, direction, MASK_SHOT, DroneWeaponTrace, drone);
	end = trace.GetEndPosition(); // Surface we are aiming at
	delete trace;

	return end;
}

stock FVector GetCameraOffset(ADrone drone)
{
	float cameraHeight = drone.CameraHeight;

	FVector start;
	start = FMath.OffsetVector(drone.GetPosition(), drone.GetAngles(), ConstructVector(0.0, 0.0, cameraHeight));

	return start;
}

stock bool DroneWeaponTrace(int entity, int mask, ADrone drone)
{
	if (entity == drone.Get())
		return false;
	
	//Let's ignore anything attached to this drone as well
	if (IsValidEntity(entity) && entity > MaxClients)
	{
		FObject test;
		test = ConstructObject(entity);
		if (test.Valid() && test.HasProp(Prop_Send, "m_hMoveParent"))
		{
			if (test.GetParent().Get() == drone.Get())
			{
				return false;
			}
		}
	}

	if (drone.Pilot && entity == drone.Pilot.Get())
		return false;
	
	// Loop through our seats to make sure we don't hit any passengers
	/*int seats = drone.Seats.Length;
	for (int i = 0; i < seats; i++)
	{
		FDroneSeat seat = drone.Seats.Get(i);
		if (seat && seat.Valid())
		{
			ADronePlayer player = seat.Occupier;
			if (player && entity == player.Get())
			{
				return false;
			}
		}
	}
	*/
	return true;
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