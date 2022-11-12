#include <customdrones>

GlobalForward DroneCreated;
GlobalForward DroneCreatedWeapon;
GlobalForward DroneEntered;
GlobalForward DroneExited;
GlobalForward DroneRemoved;
GlobalForward DroneDestroyed;
GlobalForward DroneChangeWeapon;
GlobalForward DroneAttack;

// Player drone reference
FObject DroneRef[MAXPLAYERS+1];

// Drone information for the given entity
FDrone Drone[2049];

// Weapons tied to drones
FDroneWeapon DroneWeapons[2049][MAXWEAPONS+1];

// Seats tied to drones
FDroneSeat DroneSeats[2049][MAXSEATS+1];

public any Native_ViewLock(Handle plugin, int args)
{
	FComponent drone;
	drone = GetComponentFromEntity(GetNativeCell(1));
	
	if (drone.Valid())
	{
		int droneId = drone.Get();
		if (IsValidDrone(drone.GetObject()))
			Drone[droneId].viewlocked = !Drone[droneId].Viewlocked;
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
	FClient owner;
	FComponent drone;

	owner = ConstructClient(GetNativeCell(1));
	drone = GetComponentFromEntity(GetNativeCell(2));

	if (owner.Valid() && drone.Valid())
	{
		int droneId = drone.Get();

		if (IsValidDrone(drone.GetObject()))
		{
			int slot = Drone[droneId].ActiveWeapon;

			if (DroneWeapons[droneId][slot].CanFire(true))
				FireWeapon(owner, drone, slot, DroneWeapons[droneId][slot]);
		}
	}

	return 0;
}

void FireWeapon(FClient gunner, FComponent droneHull, int slot, FDroneWeapon weapon)
{
	Action result = Plugin_Continue;
	Call_StartForward(DroneAttack);

	int droneId = droneHull.Get();

	Call_PushArray(droneHull, sizeof FComponent);
	Call_PushArray(gunner, sizeof FClient);
	Call_PushArray(weapon, sizeof FDroneWeapon);
	Call_PushCell(slot);
	Call_PushString(weapon.Plugin);
	Call_PushString(Drone[droneId].Plugin);

	Call_Finish(result);

	weapon.SimulateFire(result);
}

public int Native_DroneTakeDamage(Handle plugin, int args)
{
	FObject inflictor;
	FClient attacker;
	FComponent drone;

	drone = GetComponentFromEntity(GetNativeCell(1));
	attacker = ConstructClient(GetNativeCell(2));
	inflictor = ConstructObject(GetNativeCell(3));

	float damage = GetNativeCell(4);

	bool crit = view_as<bool>(GetNativeCell(5));

	if (IsValidDrone(drone.GetObject()))
	{
		int droneId = drone.Get();

		DroneTakeDamage(Drone[droneId], drone, attacker, inflictor, damage, crit);
	}

	return 0;
}

void DroneTakeDamage(FDrone drone, FComponent hull, FClient attacker, FObject inflictor, float &damage, bool crit, FObject weapon)
{
	bool sendEvent = true;

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
	if (Drone.Health <= 0.0)
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
}

public any Native_GetDroneActiveWeapon(Handle plugin, int args)
{
	FComponent drone;
	drone = GetComponentFromEntity(GetNativeCell(1));

	if (IsValidDrone(drone.GetObject()))
	{
		int droneId = drone.Get();
		SetNativeArray(2, DroneWeapons[droneId][Drone[droneId].ActiveWeapon], sizeof FDroneWeapon);
	}

	return 0;
}

public int Native_SetDroneWeapon(Handle plugin, int args)
{
	FComponent drone;
	drone = GetComponentFromEntity(GetNativeCell(1));

	if (IsValidDrone(drone.GetObject()))
	{
		int droneId = drone.Get();

		int slot = GetNativeCell(2);

		Drone[droneId].ActiveWeapon = slot;
	}

	return 0;
}

public int Native_SpawnDroneName(Handle plugin, int args)
{
	FClient client;
	client = ConstructClient(GetNativeCell(1));

	char name[128];
	GetNativeString(2, name, sizeof name);

	CreateDroneByName(client, name);
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
}

public any Native_HitscanAttack(Handle plugin, int args)
{
	FClient owner;
	FComponent drone;

	owner = FClient(GetNativeCell(1));
	drone = GetComponentFromEntity(GetNativeCell(2));

	FDroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof FDroneWeapon);
	
	FTransform spawn;

	spawn = weapon.GetMuzzleTransform(); //get our weapon's muzzle position

	EDamageType dmgType = view_as<EDamageType>(GetNativeCell(4));

	if (owner.Valid() && IsValidDrone(drone.GetObject()))
	{
		int droneId = drone.Get();

		FVector aimPos, aimVec, cameraPos, dronePos;
		FRotator angle, aimAngle, droneAngle;
		
		aimAngle = owner.GetEyeAngles();

		droneAngle = drone.GetAngles();
		dronePos = drone.GetPosition();

		FVector offset;
		offset = FVector(0.0, 0.0, Drone[droneId].cameraHeight);

		cameraPos = GetOffsetPos(dronePos, droneAngle, offset); //Get our camera height relative to our drone's forward vector

		aimPos = GetDroneAimPosition(drone, cameraPos, aimAngle);	//find where the client is aiming at in relation to the drone

		Vector_MakeFromPoints(spawn.position, aimPos, aimVec); // Make a vector between our muzzle and aim position

		Vector_GetAngles(aimVec, angle);

		//TODO - restrict angles at which attacks can be fired

		if (weapon.inaccuracy)
		{
			angle.pitch += GetRandomFloat((weapon.inaccuracy * -1.0), weapon.inaccuracy);
			angle.yaw += GetRandomFloat((weapon.inaccuracy * -1.0), weapon.inaccuracy);
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
						DroneTakeDamage(Drone[hitDroneId], GetComponentFromEntity(victim.Get()), owner, drone.GetObject(), weapon.damage, false, weapon.GetObject());
					}
					else if (victim.Valid())
						SDKHooks_TakeDamage(victim.Get(), owner.Get(), owner.Get(), weapon.Damage, DMG_ENERGYBEAM);
				}
				default:
				{
					float damage = Damage_Hitscan(victim, drone.GetObject(), weapon.Damage);
					if (isDrone)
					{
						int hitDroneId = victim.Get();
						DroneTakeDamage(Drone[hitDroneId], GetComponentFromEntity(victim.Get()), owner, drone.GetObject(), damage, false, weapon.GetObject());
					}
					else
						SDKHooks_TakeDamage(victim.Get(), owner.Get(), owner.Get(), damage, DMG_ENERGYBEAM);
				}
			}
		}
	}
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
	FComponent drone;

	owner = ConstructClient(GetNativeCell(1));
	drone = GetComponentFromEntity(GetNativeCell(2));

	FDroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof FDroneWeapon);
	
	FTransform spawn;

	spawn = weapon.GetMuzzleTransform(); //get our weapon's muzzle position

	EProjType projectile = GetNativeCell(4);

	//PrintToConsole(owner, "Damage: %.1f\nSpeed: %.1f\noffset x: %.1f\noffset y: %.1f\noffset z: %.1f", damage, speed, overrideX, overrideY, overrideZ);

	FVector pos, aimPos, aimVec, camearPos;
	FRotator aimAngle, droneAngle;

	char netname[64], classname[64];

	FRocket rocket;

	if (IsValidDrone(drone.Get()))
	{
		//Get Spawn Position
		aimAngle = owner.GetEyeAngles();
		droneAngle = drone.GetAngles();
		dronePos = drone.GetPosition();

		FVector offset;
		offset = ConstructVector(0.0, 0.0, Drone[droneId].CameraHeight);

		cameraPos = GetOffsetPos(dronePos, droneAngle, offset); //Get our camera height relative to our drone's forward vector

		aimPos = GetDroneAimPosition(drone, cameraPos, aimAngle);	//find where the client is aiming at in relation to the drone

		Vector_MakeFromPoints(spawn.position, aimPos, aimVec);

		Vector_GetAngles(aimVec, angle);

		if (weapon.inaccuracy)
		{
			aimAngle.pitch += GetRandomFloat((weapon.Inaccuracy * -1.0), weapon.Inaccuracy);
			aimAngle.yaw += GetRandomFloat((weapon.Inaccuracy * -1.0), weapon.Inaccuracy);
		}
		
		rocket = CreateDroneRocket(owner, spawn.position, projectile, weapon.projspeed, weapon.damage);

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
			DroneTakeDamage(Drone[victim], GetComponentFromEntity(victim), owner, rocket, damage, false, ConstructObject());
			
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
				FObject drone;
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
///	Drone Bomb Functions
///

public any Native_SpawnBomb(Handle Plugin, int args)
{
	int drone = GetNativeCell(2);
	int owner = GetNativeCell(1);
	DroneWeapon weapon;
	GetNativeArray(3, weapon, sizeof DroneWeapon);
	float pos[3];
	float angle[3];
	weapon.GetMuzzleTransform(pos, angle);
	ProjType projectile = GetNativeCell(4);
	char modelname[256];
	GetNativeString(5, modelname, sizeof modelname);
	float fuse = GetNativeCell(6);
	DroneBomb bombEnt;
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
}

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

public any Native_GetDrone(Handle plugin, int args)
{
	int client = GetNativeCell(1);
	int drone = GetClientDrone(client);
	SetNativeArray(2, DroneInfo[drone], sizeof DroneProp);
}

FVector GetDroneAimPosition(FObject drone, FVector pos, FRotator angle)
{
	// Max range on attacks is 10000 hu
	FVector end;
	end = angle.GetForwardVector();
	end.Scale(10000.0);
	end.Add(pos);

	FVector result;

	RayTrace trace = RayTrace(pos, end, MASK_SHOT, FilterDrone, drone.Get());
	if (trace.DidHit())
		result = trace.GetEndPosition();
	else
		result = end;

	delete trace;

	return result;
}

bool FilterDrone(int entity, int mask, int exclude)
{
	FObject owner = Drone[exclude].GetOwner();
	if (entity == owner.Get())
		return false;
	if (entity == exclude)
		return false;

	return true;
}