#include <customdrones>

GlobalForward DroneCreated;
GlobalForward DroneEntered;
GlobalForward DroneExited;
GlobalForward DroneRemoved;
GlobalForward DroneDestroyed;
GlobalForward DroneChangeWeapon;
GlobalForward DroneAttack;

bool IsMount[2049];
FObject LinkedReceiver[2049];

FObject DroneRef[MAXPLAYERS+1]; // Player drone reference

FDrone Drone[2049]; // Drone information for the given entity - This can be for drone entities and the entities used as attachments for a drone

FDroneWeapon DroneWeapons[2049][MAXWEAPONS+1]; // Weapons tied to drones

FDroneSeat DroneSeats[2049][MAXSEATS+1]; // Seats tied to drones

FComponent Attachments[2049][MAXATTACHMENTS+1]; // Attachments tied to drones

public any Native_ViewLock(Handle plugin, int args)
{
	FComponent drone;
	drone = GetComponentFromEntity(GetNativeCell(1));

	if (drone.Valid())
	{
		int droneId = drone.Get();
		if (IsValidDrone(drone.GetObject()))
			Drone[droneId].Viewlocked = !Drone[droneId].Viewlocked;
		else
			ThrowNativeError(017, "Entity index %i is not a valid drone", droneId);

		return Drone[droneId].Viewlocked;
	}
	else
		ThrowNativeError(017, "Entity index %i is not valid!", drone.Get());

	return false;
}

public int Native_OverrideMaxSpeed(Handle plugin, int args)
{
	FComponent drone;
	drone = GetComponentFromEntity(GetNativeCell(1));

	float speed = GetNativeCell(2);

	if (drone.Valid())
	{
		int droneId = drone.Get();
		if (IsValidDrone(drone.GetObject()))
			Drone[droneId].SpeedOverride = speed;
		else
		   ThrowNativeError(017, "Entity index %i is not a valid drone", droneId); 
	}
	else
		ThrowNativeError(017, "Entity index %i is not valid!", drone.Get());

	return 0;
}

public int Native_FireWeapon(Handle plugin, int args)
{
	FClient gunner;
	FObject drone;

	gunner = ConstructClient(GetNativeCell(1));
	drone = ConstructObject(GetNativeCell(2));

	if (gunner.Valid() && drone.Valid())
	{
		int droneId = drone.Get();

		if (IsValidDrone(drone))
		{
			int seat = GetPlayerSeat(gunner, DroneSeats[droneId]);

			if (seat)
			{
				int slot = DroneSeats[droneId][seat].ActiveWeapon;

				if (DroneWeapons[droneId][slot].CanFire(true))
					FireWeapon(gunner, drone, slot, DroneWeapons[droneId][slot]);
			}
		}
	}

	return 0;
}

void FireWeapon(FClient gunner, FObject drone, int slot, FDroneWeapon weapon)
{
	Action result = Plugin_Continue;
	Call_StartForward(DroneAttack);

	int droneId = drone.Get();

	int ammoUsed = 1; // Plugin can determine how much ammo is needed for a single shot

	Call_PushArray(drone, sizeof FObject);
	Call_PushArray(gunner, sizeof FClient);
	Call_PushArray(weapon, sizeof FDroneWeapon);
	Call_PushCell(slot);
	Call_PushCellRef(ammoUsed);
	Call_PushString(Drone[droneId].Plugin);

	Call_Finish(result);

	weapon.SimulateFire(result, ammoUsed);
}

public int Native_DroneTakeDamage(Handle plugin, int args)
{
	FObject inflictor;
	FClient attacker;
	FObject drone;

	drone = ConstructObject(GetNativeCell(1));
	attacker = ConstructClient(GetNativeCell(2));
	inflictor = ConstructObject(GetNativeCell(3));

	float damage = GetNativeCell(4);

	bool crit = view_as<bool>(GetNativeCell(5));

	if (IsValidDrone(drone))
	{
		int droneId = drone.Get();

		DroneTakeDamage(Drone[droneId], drone, attacker, inflictor, damage, crit, drone);
	}

	return 0;
}

void DroneTakeDamage(FDrone drone, FObject hull, FClient attacker, FObject inflictor, float &damage, bool crit, FObject weapon)
{
	bool sendEvent = true;

	if (inflictor.Valid())
	{
		//
	}

	if (!drone.Alive)
		return;

	if (attacker.Get() == drone.Owner.Get()) //significantly reduce damage if the drone damages itself
	{
		damage *= 0.25; //Should probably be a convar
		sendEvent = false;
	}

	if (sendEvent)
		SendDamageEvent(drone, attacker, damage, crit);

	drone.Health -= damage;
	if (drone.Health <= 0.0)
	{
		KillDrone(drone, hull, attacker, damage, weapon);
	}
}

void SendDamageEvent(FDrone drone, FClient attacker, float damage, bool crit)
{
	if (attacker.Valid() && drone.Valid())
	{
		int damageamount = RoundFloat(damage);
		int health = RoundFloat(drone.Health);
		Event PropHurt = CreateEvent("npc_hurt", true);

		//setup components for event
		PropHurt.SetInt("entindex", drone.Get());
		PropHurt.SetInt("attacker_player", GetClientUserId(attacker.Get()));
		PropHurt.SetInt("damageamount", damageamount);
		PropHurt.SetInt("health", health - damageamount);
		PropHurt.SetBool("crit", crit);

		PropHurt.Fire(false);
	}
}

public int Native_ValidDrone(Handle plugin, int args)
{
	return IsValidDrone(ConstructObject(GetNativeCell(1)))
}

public int Native_GetDroneHealth(Handle plugin, int args)
{
	FComponent drone;
	drone = GetComponentFromEntity(GetNativeCell(1));

	if (IsValidDrone(drone.GetObject()))
	{
		int droneId = drone.Get();
		return RoundFloat(Drone[droneId].Health);
	}

	return 0;
}

public int Native_GetDroneMaxHealth(Handle plugin, int args)
{
	FComponent drone;
	drone = GetComponentFromEntity(GetNativeCell(1));

	if (IsValidDrone(drone.GetObject()))
	{
		int droneId = drone.Get();
		return RoundFloat(Drone[droneId].MaxHealth);
	}

	return 0;
}

public any Native_GetDroneWeapon(Handle plugin, int args)
{
	FComponent drone;
	drone = GetComponentFromEntity(GetNativeCell(1));

	if (IsValidDrone(drone.GetObject()))
	{
		int droneId = drone.Get();
		int slot = GetNativeCell(2);

		SetNativeArray(3, DroneWeapons[droneId][slot], sizeof FDroneWeapon);
	}

	return 0;
}

public int Native_SpawnDroneName(Handle plugin, int args)
{
	FClient client;
	client = ConstructClient(GetNativeCell(1));

	char name[128];
	GetNativeString(2, name, sizeof name);

	FVector position;

	float sub[3];
	GetNativeArray(3, sub, 3);
	Vector_MakeFromFloat(position, sub);

	FDrone drone;
	drone = CreateDroneByName(client, name, position);

	return drone.Get();
}

public int Native_SetWeaponReload(Handle plugin, int args)
{
	FComponent drone;
	drone = GetComponentFromEntity(GetNativeCell(1));

	if (IsValidDrone(drone.GetObject()))
	{
		int droneId = drone.Get();
		int slot = GetNativeCell(2);
		float delay = GetNativeCell(3);

		if (!delay)
			delay = DroneWeapons[droneId][slot].ReloadTime;

		DroneWeapons[droneId][slot].SimulateReload();
	}

	return 0;
}

public any Native_GetFloatParam(Handle plugin, int args)
{
	float result;

	char config[64], key[64], weapon[64];

	int slot = GetNativeCell(3);

	GetNativeString(1, config, sizeof config);
	GetNativeString(2, key, sizeof key);
	
	// TODO - Store keyvalues in a global array so we don't have to keep creating new ones
	KeyValues drone = new KeyValues("Drone");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.txt", config);
	drone.ImportFromFile(path);

	if (slot)
	{
		drone.JumpToKey("weapons");
		FormatEx(weapon, sizeof weapon, "weapon%i", slot);
		drone.JumpToKey(weapon);
	}
	result = drone.GetFloat(key);
	delete drone;

	return result;
}

public any Native_GetIntParam(Handle plugin, int args)
{
	int result;

	char config[64], key[64], weapon[64];

	int slot = GetNativeCell(3);

	GetNativeString(1, config, sizeof config);
	GetNativeString(2, key, sizeof key);

	KeyValues drone = new KeyValues("Drone");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.txt", config);
	drone.ImportFromFile(path);

	if (slot)
	{
		drone.JumpToKey("weapons");
		FormatEx(weapon, sizeof weapon, "weapon%i", slot);
		drone.JumpToKey(weapon);
	}
	result = drone.GetNum(key);
	delete drone;

	return result;
}

public any Native_GetString(Handle plugin, int args)
{
	char config[64], key[64], weapon[64];

	int slot = GetNativeCell(3);

	GetNativeString(1, config, sizeof config);
	GetNativeString(2, key, sizeof key);

	int size = GetNativeCell(5);
	char[] result = new char[size];

	KeyValues drone = new KeyValues("Drone");
	char path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof path, "configs/drones/%s.txt", config);
	drone.ImportFromFile(path);

	if (slot)
	{
		drone.JumpToKey("weapons");
		FormatEx(weapon, sizeof weapon, "weapon%i", slot);
		drone.JumpToKey(weapon);
	}
	drone.GetString(key, result, size);
	delete drone;

	SetNativeString(4, result, size);

	return 0;
}

public any Native_HitscanAttack(Handle plugin, int args)
{
	FClient owner;
	FObject drone;

	owner = ConstructClient(GetNativeCell(1));
	drone = ConstructObject(GetNativeCell(2));

	FDroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof FDroneWeapon);
	
	FTransform spawn;

	spawn = weapon.GetMuzzleTransform(); //get our weapon's muzzle position

	EDamageType dmgType = view_as<EDamageType>(GetNativeCell(4));

	if (owner.Valid() && IsValidDrone(drone))
	{
		int droneId = drone.Get();

		FVector aimPos, aimVec, cameraPos, dronePos;
		FRotator angle, aimAngle, droneAngle;
		
		aimAngle = owner.GetEyeAngles();

		droneAngle = drone.GetAngles();
		dronePos = drone.GetPosition();

		FVector offset;
		offset = ConstructVector(0.0, 0.0, Drone[droneId].CameraHeight);

		cameraPos = GetOffsetPos(dronePos, droneAngle, offset); //Get our camera height relative to our drone's forward vector

		aimPos = GetDroneAimPosition(drone, cameraPos, aimAngle);	//find where the client is aiming at in relation to the drone

		Vector_MakeFromPoints(spawn.position, aimPos, aimVec); // Make a vector between our muzzle and aim position

		Vector_GetAngles(aimVec, angle);

		//TODO - restrict angles at which attacks can be fired

		if (weapon.Inaccuracy)
		{
			angle.pitch += GetRandomFloat((weapon.Inaccuracy * -1.0), weapon.Inaccuracy);
			angle.yaw += GetRandomFloat((weapon.Inaccuracy * -1.0), weapon.Inaccuracy);
		}



		// Damage our hit entity below and create our tracer effect
		FObject victim;
		bool isDrone = false;

		FVector endPos;

		RayTrace bullet = new RayTrace(spawn.position, aimPos, MASK_SHOT, FilterDroneShoot, drone.Get());
		if (bullet.DidHit())
		{
			victim = bullet.GetHitEntity();
			isDrone = IsValidDrone(victim);
			endPos = bullet.GetEndPosition();
		}
		delete bullet;

		switch (weapon.Type)
		{
			case WeaponType_Gun:
			{
				CreateTracer(spawn.position, endPos);
			}
			case WeaponType_Laser:
			{
				//TODO
			}
		}

		if (victim.Valid())
		{
			switch (dmgType)
			{
				case DamageType_Rangeless: //no damage falloff
				{
					if (isDrone)
					{
						int hitDroneId = victim.Get();
						DroneTakeDamage(Drone[hitDroneId], victim, owner, drone, weapon.Damage, false, weapon.GetReceiver());
					}
					else if (victim.Valid())
						SDKHooks_TakeDamage(victim.Get(), owner.Get(), owner.Get(), weapon.Damage, DMG_ENERGYBEAM);
				}
				default:
				{
					float damage = Damage_Hitscan(victim, drone, weapon.Damage);
					if (isDrone)
					{
						int hitDroneId = victim.Get();
						DroneTakeDamage(Drone[hitDroneId], victim, owner, drone, damage, false, weapon.GetReceiver());
					}
					else
						SDKHooks_TakeDamage(victim.Get(), owner.Get(), owner.Get(), damage, DMG_ENERGYBEAM);
				}
			}
		}
	}

	return 0;
}

bool FilterDroneShoot(int entity, int mask, int drone)
{
	FObject owner, hit;
	owner = Drone[drone].GetOwner();

	hit = ConstructObject(entity);

	FClient player, check;
	
	player = CastToClient(owner);
	check = CastToClient(hit);

	if (player.Valid() && check.Valid())
	{
		if (player.GetTeam() == check.GetTeam()) // ignore teammates
			return false;
	}

	if (entity == drone)
		return false;

	return true;
}

float Damage_Hitscan(FObject victim, FObject drone, float baseDamage)
{
	FVector pos, vicPos;
	float distance;

	//Setup distance between drone and target
	pos = drone.GetPosition();
	vicPos = victim.GetPosition();

	distance = pos.DistanceTo(vicPos);

	float dmgMod = ClampFloat((512.0 / distance), 1.5, 0.528);
	baseDamage *= dmgMod;

	return baseDamage;
}

public any Native_SpawnRocket(Handle Plugin, int args)
{
	FClient owner;
	FObject drone;

	owner = ConstructClient(GetNativeCell(1));
	drone = ConstructObject(GetNativeCell(2));

	FDroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof FDroneWeapon);
	
	FTransform spawn;

	spawn = weapon.GetMuzzleTransform(); //get our weapon's muzzle position

	EProjType projectile = GetNativeCell(4);

	//PrintToConsole(owner, "Damage: %.1f\nSpeed: %.1f\noffset x: %.1f\noffset y: %.1f\noffset z: %.1f", damage, speed, overrideX, overrideY, overrideZ);

	FVector dronePos, aimPos, aimVec, cameraPos;
	FRotator aimAngle, droneAngle;

	FRocket rocket;

	if (IsValidDrone(drone))
	{
		int droneId = drone.Get();
		//Get Spawn Position
		aimAngle = owner.GetEyeAngles();
		droneAngle = drone.GetAngles();
		dronePos = drone.GetPosition();

		FVector offset;
		offset = ConstructVector(0.0, 0.0, Drone[droneId].CameraHeight);

		cameraPos = GetOffsetPos(dronePos, droneAngle, offset); //Get our camera height relative to our drone's forward vector

		aimPos = GetDroneAimPosition(drone, cameraPos, aimAngle);	//find where the client is aiming at in relation to the drone

		Vector_MakeFromPoints(spawn.position, aimPos, aimVec);

		Vector_GetAngles(aimVec, aimAngle);

		if (weapon.Inaccuracy)
		{
			aimAngle.pitch += GetRandomFloat((weapon.Inaccuracy * -1.0), weapon.Inaccuracy);
			aimAngle.yaw += GetRandomFloat((weapon.Inaccuracy * -1.0), weapon.Inaccuracy);
		}
		
		rocket = CreateDroneRocket(owner, spawn.position, projectile, weapon.ProjSpeed, weapon.Damage);

		rocket.Fire(aimAngle);

		if (projectile == DroneProj_Impact)
			SDKHook(rocket.Get(), SDKHook_Touch, OnProjHit);

	}
	
	return rocket.Get();
}

Action OnProjHit(int entity, int victim)
{
	FObject hit, rocket;
	FClient client, owner;

	hit = ConstructObject(victim);
	rocket = ConstructObject(entity);

	client = CastToClient(hit);
	owner = CastToClient(rocket.GetOwner());

	if (!client.Valid()) // Not a client
	{
		if (IsValidDrone(hit)) // Is a drone
		{
			float damage = GetEntDataFloat(entity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4); //get our damage
			DroneTakeDamage(Drone[victim], hit, owner, rocket, damage, false, rocket);
			
			rocket.Kill();

			return Plugin_Handled;
		}

		char classname[64];
		hit.GetClassname(classname, sizeof classname);

		if (victim == 0 || !StrContains(classname, "prop_", false))
		{
			rocket.Kill();

			return Plugin_Handled;
		}

		else if (StrContains(classname, "obj_", false)) //engineer buildings
		{
			float damage = GetEntDataFloat(entity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4); //get our damage

			SDKHooks_TakeDamage(victim, entity, owner.Get(), damage, DMG_ENERGYBEAM);

			rocket.Kill();

			return Plugin_Handled;
		}
		else return Plugin_Continue;
	}
	else // Entity hit is a client
	{
		if (owner.Valid())
		{
			if (owner.GetTeam() != client.GetTeam())
			{
				FDrone drone;
				drone = GetClientDrone(owner);

				FVector pos, vicPos;
				float damage, distance;

				damage = GetEntDataFloat(entity, FindSendPropInfo("CTFProjectile_Rocket", "m_iDeflected") + 4);

				//Setup distance between drone and target
				pos = drone.GetPosition();
				
				vicPos = client.GetPosition();
				distance = pos.DistanceTo(vicPos);

				//Standard rampup and falloff for rockets
				float dmgMod = ClampFloat((512.0 / distance), 1.25, 0.528);
				damage *= dmgMod;
				SDKHooks_TakeDamage(victim, entity, owner.Get(), damage, DMG_ENERGYBEAM);

				rocket.Kill();

				return Plugin_Handled;
			}
		}
		else 
			return Plugin_Handled; // Should allow rockets to pass through teammates without exploding
	}
	
	rocket.Kill();
	return Plugin_Handled;
}

///
///	Drone Bomb Functions - Bombs do not currently work, need to be redone.
///

public any Native_SpawnBomb(Handle Plugin, int args)
{
	/*
	FComponent drone;
	drone = GetComponentFromEntity(GetNativeCell(2));

	FClient owner;
	owner = ConstructClient(GetNativeCell(1));

	FDroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof FDroneWeapon);

	FTransform spawn;
	spawn = weapon.GetMuzzleTransform();

	EProjType projectile = GetNativeCell(4);

	char modelname[256];
	GetNativeString(5, modelname, sizeof modelname);

	float fuse = GetNativeCell(6);

	FDroneBomb bombEnt;
	bombEnt.create(owner, modelname, weapon.damage, fuse, 200.0, pos);
	SetEntPropEnt(bombEnt.bomb, Prop_Send, "m_hOwnerEntity", owner);
	bombEnt.type = projectile;
	bombEnt.isBomb = true;
	bombEnt.drone = drone;
	switch (projectile)
	{
		case DroneProj_BombDelayed:
		{
			BombInfo[bombEnt.bomb] = bombEnt;
			SDKHook(bombEnt.bomb, SDKHook_VPhysicsUpdate, BombDelayUpdate);
		}
		case DroneProj_BombImpact:
		{
			BombInfo[bombEnt.bomb] = bombEnt;
			SDKHook(bombEnt.bomb, SDKHook_VPhysicsUpdate, BombImpactUpdate);
		}
		case DroneProj_Custom:
		{
			//Use this type to prevent any default behavior with bombs.
			//Everything can safely be handled within your sub-plugin if using this type.
		}
		default:
		{
			BombInfo[bombEnt.bomb] = bombEnt;
			CreateTimer(bombEnt.fuseTime, DetonateBombTimer, bombEnt.bomb, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	SetNativeArray(7, bombEnt, sizeof bombEnt);
	return IsValidEntity(bombEnt.bomb);
	*/
	return 0;
}

/*
Action DetonateBombTimer(Handle timer, int bomb)
{
	if (IsValidEntity(bomb) && bomb > MaxClients)
	{
		BombInfo[bomb].detonate();
	}
}

Action BombDelayUpdate(int bomb)
{
	if (IsValidEntity(bomb))
	{
		if (BombInfo[bomb].type == DroneProj_BombDelayed)
		{
			if (!BombInfo[bomb].primed && BombCollision(bomb))
			{
				CreateTimer(BombInfo[bomb].fuseTime, DetonateBombTimer, bomb, TIMER_FLAG_NO_MAPCHANGE);
				BombInfo[bomb].primed = true;
				SDKUnhook(bomb, SDKHook_VPhysicsUpdate, BombDelayUpdate);
			}
		}
	}
}

Action BombImpactUpdate(int bomb)
{
	if (IsValidEntity(bomb))
	{
		if (BombInfo[bomb].type == DroneProj_BombImpact)
		{
			if (!BombInfo[bomb].primed && BombCollision(bomb))
			{
				BombInfo[bomb].touched = true;
				BombInfo[bomb].detonate();
			}
		}
	}
}

//SDKHook_Touch does not reliably detect when physics props collide with the world.. so we have to check manually
bool BombCollision(int bomb)
{
	bool result = false;
	if (BombInfo[bomb].isBomb && BombInfo[bomb].tickTime <= GetGameTime())
	{
		BombInfo[bomb].tickTime = GetGameTime() + 0.1;
		float min[3], max[3], pos[3];
		GetEntPropVector(bomb, Prop_Data, "m_vecOrigin", pos);
		GetEntPropVector(bomb, Prop_Send, "m_vecMins", min);
		GetEntPropVector(bomb, Prop_Send, "m_vecMaxs", max);

		Handle hull = TR_TraceHullFilterEx(pos, pos, min, max, MASK_SOLID, BombTraceFilter, bomb);
		if (TR_DidHit(hull))
			result = true;

		CloseHandle(hull);
	}
	return result;
}

bool BombTraceFilter(int entity, int mask, int bomb)
{
	if (BombInfo[bomb].isBomb)
	{
		if (entity == bomb || entity == BombInfo[bomb].drone)
			return false;

		return true;
	}
	return false;
}
*/

public any Native_GetDrone(Handle plugin, int args)
{
	FClient client;
	client = ConstructClient(GetNativeCell(1));

	FDrone drone;
	drone = GetClientDrone(client); // This only gets a copy, but we want to get a reference, so just pull the entity index this way

	if (drone.Valid())
	{
		int droneId = drone.Get();

		SetNativeArray(2, Drone[droneId], sizeof FDrone);
	}

	return 0;
}

FVector GetDroneAimPosition(FObject drone, FVector pos, FRotator angle)
{
	// Max range on attacks is 10000 hu
	FVector end;
	end = angle.GetForwardVector();
	end.Scale(10000.0);
	end.Add(pos);

	FVector result;

	RayTrace trace = new RayTrace(pos, end, MASK_SHOT, FilterDrone, drone.Get());
	if (trace.DidHit())
		result = trace.GetEndPosition();
	else
		result = end;

	delete trace;

	return result;
}

bool FilterDrone(int entity, int mask, int exclude)
{
	FObject owner;
	owner = Drone[exclude].GetOwner();

	if (entity == owner.Get())
		return false;
	if (entity == exclude)
		return false;

	return true;
}

public Action OnPlayerRunCmd(int clientId, int& buttons)
{
	FClient client;
	client = ConstructClient(clientId);

	if (PlayerInDrone(client))
	{
		// We can safely get a copy of this drone since we won't be modifying anything and only reading from it
		FDrone drone;
		drone = GetClientDrone(client);

		if (!drone.Valid() || !drone.Alive)
			return Plugin_Continue;

		int droneId = drone.Get();

		// Prepare displays for drone pilot
		int droneHp = RoundFloat(drone.Health);
		//int activeWeapon = drone.ActiveWeapon;
		char weaponName[MAX_WEAPON_LENGTH], ammo[32];
		//float maxSpeed = drone.

		FDroneSeat seat;
		int seatIndex = GetPlayerSeat(client, DroneSeats[droneId]);

		seat = DroneSeats[droneId][seatIndex];

		switch (seat.Type)
		{
			case Seat_Gunner: // handling weapons for this seat
			{
				if (buttons & IN_ATTACK)
				{
					OnDroneAttack(client, DroneSeats[droneId][seatIndex], drone); // We have to pass a reference of the actual seat struct and not the created copy
					buttons &= ~IN_ATTACK; // Remove the attack flag
				}
				if (buttons & IN_ATTACK2)
				{
					CycleNextWeapon(client, DroneSeats[droneId][seatIndex], drone);
					buttons &= ~IN_ATTACK2;
				}

				OnDroneAimChanged(client, DroneSeats[droneId][seatIndex], drone);
			}
			case Seat_Pilot: // Mostly movement, can also control specific weapons
			{
				if (buttons & IN_ATTACK)
				{
					OnDroneAttack(client, DroneSeats[droneId][seatIndex], drone);
					buttons &= ~IN_ATTACK; // Remove the attack flag
				}
				if (buttons & IN_ATTACK2)
				{
					CycleNextWeapon(client, DroneSeats[droneId][seatIndex], drone);
					buttons &= ~IN_ATTACK2;
				}

				OnDroneAimChanged(client, DroneSeats[droneId][seatIndex], drone);

				// Drone movement

				float inputVal = 0.0;
				FVector velocity;

				// Forward and backward
				if (buttons & IN_FORWARD)
					inputVal = 1.0;
				if (buttons & IN_BACK)
					inputVal = -1.0;
				else
					inputVal = 0.0;

				OnDroneMoveForward(drone, inputVal, velocity);

				// Left and right
				if (buttons & IN_RIGHT)
					inputVal = 1.0;
				if (buttons & IN_LEFT)
					inputVal = -1.0;
				else
					inputVal = 0.0;

				OnDroneMoveRight(drone, inputVal, velocity);

				// Up and down
				if (buttons & IN_JUMP)
					inputVal = 1.0;
				if (buttons & IN_DUCK)
					inputVal = -1.0;
				else
					inputVal = 0.0;

				OnDroneMoveUp(drone, inputVal, velocity);

				SimulateDrone(drone, velocity);
			}
		}
	}

	return Plugin_Continue;
}

// All passive actions for drones while idling
void SimulateDrone(FDrone drone, FVector velocity)
{
	// Drones will passively counteract gravity
	FVector grav;

	grav.z = 12.0;

	velocity.Add(grav);

	drone.GetObject().Teleport(drone.GetPosition(), drone.GetAngles(), velocity);
}