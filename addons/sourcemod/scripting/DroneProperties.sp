#include <customdrones>

/*
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

	return 0;
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
*/

Action OnDroneOverlap(int droneId, int otherId)
{
	// Push players away to prevent them from getting stuck
	FObject droneEnt;
	FClient client;

	droneEnt = ConstructObject(droneId);
	client = ConstructClient(otherId);

	ADrone drone = view_as<ADrone>(FEntityStatics.GetEntity(droneEnt));
	if (drone && GetPilotSeat(drone).Occupied && client.Valid())
	{
		if (drone.Team == view_as<TFTeam>(client.GetTeam()))
		{
			return Plugin_Continue;
		}

		FVector clientPos, dronePos, pushDir;
		clientPos = client.GetPosition();
		clientPos.Z += 60.0;

		dronePos = drone.GetPosition();

		pushDir = Vector_MakeFromPoints(dronePos, clientPos);

		pushDir.Normalize();
		pushDir.Scale(40.0);
		clientPos = client.GetPosition();

		clientPos.Add(pushDir);

		bool ignoreTele = false;
		FHullTrace trace = new FHullTrace(client.GetPosition(), clientPos, ConstructVector(-30.0, -30.0, 0.0), ConstructVector(30.0, 30.0, 95.0), MASK_PLAYERSOLID, DroneCollisionTrace, otherId);
		if (trace.DidHit())
		{
			//char entname[64];
			//trace.GetHitEntity().GetClassname(entname, sizeof entname);
			//PrintCenterTextAll("hit entity %d, do not teleport\n%s", trace.GetHitEntity().Get(), entname);

			delete trace;
			ignoreTele = true;
		}

		pushDir.Normalize();
		pushDir.Scale(200.0);
		
		FVector clientVel;
		clientVel = client.GetVelocity();
		clientVel.Add(pushDir);

		if (ignoreTele)
			TeleportEntity(otherId, NULL_VECTOR, NULL_VECTOR, clientVel.ToFloat());
		else
			TeleportEntity(otherId, clientPos.ToFloat(), NULL_VECTOR, clientVel.ToFloat());
	}
	return Plugin_Continue;
}

bool DroneCollisionTrace(int entityId, int mask, int clientId)
{
	if (entityId == clientId)
	{
		return false;
	}
	if (entityId == 0)
	{
		return true;
	}

	FObject entity;
	entity = ConstructObject(entityId);
	if (entity.Valid())
	{
		// Ignore drones
		ADrone drone = view_as<ADrone>(FEntityStatics.GetEntity(entity));
		if (drone && drone.IsDrone)
		{
			return false;
		}

		// And anything parented to a drone
		if (entity.HasProp(Prop_Send, "m_hMoveParent"))
		{
			drone = view_as<ADrone>(FEntityStatics.GetEntity(entity.GetParent()));
			if (drone && drone.IsDrone)
			{
				return false;
			}
		}

		// Should only be other drones and other types of entities that we dont care about
		if (entity.Cast("prop_physics"))
		{
			return false;
		}

		if (entity.Cast("prop_"))
		{
			return true;
		}

		if (entity.Cast("obj_"))
		{
			return true;
		}

		if (entity.Cast("func_"))
		{
			return true;
		}
	}

	FClient client;
	client = CastToClient(entity);

	if (client.Valid())
	{
		return GetClientTeam(clientId) != client.GetTeam();
	}

	return true;
}

/*
 Drone damage handling
*/

Action OnDroneDamaged(int entity, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	Action result = Plugin_Continue;
	ADrone drone = view_as<ADrone>(FEntityStatics.GetEntity(ConstructObject(entity)));
	if (drone && drone.IsDrone)
	{
		result = DroneTakeDamage(drone, ConstructObject(attacker), ConstructObject(inflictor), damage, ConstructWeapon(weapon), damagetype);
	}

	return result;
}

Action OnComponentDamaged(int entity, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	Action result = Plugin_Continue;
	AComponent component = view_as<AComponent>(FEntityStatics.GetEntityFromIndex(entity));
	if (component && component.IsComponent)
	{
		if (component.Drone)
		{
			result = DroneTakeDamage(component.Drone, ConstructObject(attacker), ConstructObject(inflictor), damage, ConstructWeapon(weapon), damagetype);
		}
	}

	return result;
}

Action DroneTakeDamage(ADrone drone, FObject attacker, FObject inflictor, float& damage, FWeapon weapon, int &damagetype)
{
	bool sendEvent = true;
	Action action = Plugin_Continue;

	if (!drone.Alive)
	{
		return Plugin_Stop;
	}

	damagetype |= DMG_PREVENT_PHYSICS_FORCE;
	action = Plugin_Changed;

	if (inflictor.Get() == drone.Get()) //significantly reduce damage if the drone damages itself
	{
		if (drone.CanDealSelfDamage)
		{
			damage *= 0.25; //Should probably be a convar
		}
		else
		{
			damage = 0.0;
		}
		action = Plugin_Changed;
		sendEvent = false;
	}

	if (CastToClient(attacker).Valid())
	{
		ADronePlayer player = view_as<ADronePlayer>(FEntityStatics.GetClient(CastToClient(attacker)));
		if (player && player.InDrone && player.GetDrone() == drone)
		{
			if (drone.CanDealSelfDamage)
			{
				damage *= 0.25; //Should probably be a convar
			}
			else
			{
				damage = 0.0;
			}
			sendEvent = false;
			action = Plugin_Changed;
		}
		else if (player.Team == drone.Team)
		{
			return Plugin_Stop;
		}
	}

	float forwardDamage = damage;
	int forwardDmgType = damagetype;
	Action result = Plugin_Continue;
	Call_StartForward(DroneDamaged);

	Call_PushCell(drone);
	Call_PushArray(attacker, sizeof FObject);
	Call_PushArray(inflictor, sizeof FObject);
	Call_PushFloatRef(forwardDamage);
	Call_PushCellRef(forwardDmgType);
	Call_PushCell(weapon.Get());

	Call_Finish(result);

	if (result == Plugin_Changed)
	{
		damage = forwardDamage;
		damagetype = forwardDmgType;
		action = Plugin_Changed;
	}

	if (sendEvent)
	{
		SendDamageEvent(drone, attacker, damage);
	}

	drone.Health -= RoundFloat(damage);
	float healthpercent = float(drone.Health) / float(drone.MaxHealth);
	UpdateDamageComponents(drone, healthpercent);

	if (drone.Health <= 0)
	{
		KillDrone(drone, attacker, inflictor, damage, weapon);
	}

	return action;
}

void UpdateDamageComponents(ADrone drone, float healthpercent)
{
	FComponentArray attachments = drone.GetComponents().Attachments;
	if (attachments)
	{
		// find any damage components
		for (int i = 0; i < attachments.Length; i++)
		{
			AComponent component = attachments.Get(i);
			if (component)
			{
				if (IsEntityOfType(component, "DroneComponent.DamageComponent"))
				{
					float threshold = component.GetObjectPropFloat("DamageComponent.HealthThreshold");
					bool active = component.GetObjectProp("DamageComponent.IsActive");
					if (!active && healthpercent <= threshold)
					{
						if (IsEntityOfType(component, "DroneComponent.ParticleComponent"))
						{
							component.GetObject().Input("Start");
						}
						else if (IsEntityOfType(component, "DroneComponent.SparksComponent"))
						{
							component.GetObject().Input("ToggleSpark");
						}
						else
						{
							component.GetObject().Input("Toggle");
						}

						component.SetObjectProp("DamageComponent.IsActive", true);
					}
				}
			}
		}
	}
}

void SendDamageEvent(ADrone drone, FObject attacker, float damage)
{
	// Only send if the attacker is a client
	if (CastToClient(attacker).Valid() && drone.Valid())
	{
		int damageamount = RoundFloat(damage);
		int health = drone.Health;
		Event PropHurt = CreateEvent("npc_hurt", true);

		//setup components for event
		PropHurt.SetInt("entindex", drone.Get());
		PropHurt.SetInt("attacker_player", GetClientUserId(attacker.Get()));
		PropHurt.SetInt("damageamount", damageamount);
		PropHurt.SetInt("health", health - damageamount);

		PropHurt.Fire(false);
	}
}

/*
 Drone function handling
*/

public Action OnPlayerRunCmd(int clientId, int& buttons)
{
	ADronePlayer client = view_as<ADronePlayer>(FEntityStatics.GetClient(ConstructClient(clientId)));
	if (client.Valid())
	{
		client.Inputs = buttons;

		ADrone drone = null;
		FDroneSeat seat = null;

		if (PlayerAimingAtDrone(client, drone, seat))
		{
			client.SetObjectProp("DroneClient.LookingAtDrone", true);
			char seattype[32];
			switch (seat.Type)
			{
				case Seat_Pilot: FormatEx(seattype, sizeof seattype, "Pilot");
				case Seat_Gunner: FormatEx(seattype, sizeof seattype, "Gunner");
				case Seat_Passenger: FormatEx(seattype, sizeof seattype, "Passenger");
			}

			char dronename[64];
			drone.GetDisplayName(dronename, sizeof dronename);

			char message[128];
			FormatEx(message, sizeof message, "Press '%s' to enter %s seat of %s", "%inspect%", seattype, dronename);
			if (client.GetObjectProp("DroneClient.UsingMinHud"))
			{

			}
			else
			{
				FGameplayStatics.WriteGameText(client.GetClient(), message);
			}
		}
		else if (client.GetObjectProp("DroneClient.LookingAtDrone") && client.GetObjectProp("DroneClient.UsingMinHud"))
		{
			client.SetObjectProp("DroneClient.LookingAtDrone", false);
			PrintCenterText(client.Get(), " ");
		}
	}
	return Plugin_Continue;
}

void SimulateSeat(FDroneSeat seat, ADrone drone)
{
	if (seat.Occupier && !seat.AIControlled && !drone.Stunned)
	{
		ADronePlayer client = seat.Occupier;

		if (client)
		{
			// Prepare displays for drone pilot
			int droneHp = drone.Health;
			ADroneWeapon activeWeapon = seat.ActiveWeapon;

			int buttons = client.Inputs;

			char ammo[32], hudString[256];
			char weapName[64];
			if (activeWeapon)
			{
				//PrintCenterTextAll("Weapon Handle: %x\nWeapon Entity: %d", activeWeapon, activeWeapon.Get());
				FormatAmmoString(activeWeapon, ammo, sizeof ammo);
				activeWeapon.GetDisplayName(weapName, sizeof weapName);

				activeWeapon.Simulate();
			}

			if (!drone.NoHud) // Do not display hud if this is true
			{
				SetHudTextParams(0.6, -1.0, 0.01, 255, 255, 255, 150);
				FormatEx(hudString, sizeof hudString, "Health: %d\nWeapon: %s\n%s", droneHp, weapName, ammo);
				ShowHudText(client.Get(), -1, hudString); // Need to change to a synchronizer
			}

			// Setup player position to given seat
			FVector position;
			position = FMath.OffsetVector(drone.GetPosition(), drone.GetAngles(), seat.GetSeatPosition());

			TeleportEntity(client.Get(), position.ToFloat(), NULL_VECTOR, {0.0, 0.0, 0.0});

			switch (seat.Type)
			{
				case Seat_Gunner: // handling weapons for this seat
				{
					if (buttons & IN_ATTACK)
					{
						OnDroneAttack(client, activeWeapon, drone, seat);
						buttons &= ~IN_ATTACK; // Prevent player attacking
					}
					if (buttons & IN_ATTACK2)
					{
						CycleNextWeapon(seat);
						buttons &= ~IN_ATTACK2;
					}

					FRotator viewAngles;
					viewAngles = client.GetEyeAngles();

					OnDroneAimChanged(viewAngles, seat, drone);
				}
				case Seat_Pilot: // Mostly movement, can also control specific weapons
				{
					if (buttons & IN_ATTACK)
					{
						OnDroneAttack(client, activeWeapon, drone, seat);
						buttons &= ~IN_ATTACK; // Prevent player attacking
					}
					if (buttons & IN_ATTACK2)
					{
						CycleNextWeapon(seat);
						buttons &= ~IN_ATTACK2;
					}

					if (drone.MoveType != MoveType_Physics_NoMovement)
					{

						// Drone movement - If we have a speed override set, utilize this instead of our max speed
						float maxSpeed = drone.SpeedOverride > 0.0 ? drone.SpeedOverride : drone.MaxSpeed;

						float inputVal = 0.0;
						FVector velocity, speeds;
						GetSmoothedVelocity(drone, velocity);

						// Forward and backward
						if (!drone.DisableForwardMovement)
						{
							if (buttons & IN_FORWARD)
								inputVal = 1.0;
							else if (buttons & IN_BACK) // Forward takes priority
								inputVal = -1.0;

							if (drone.MoveType == MoveType_Fly) // Flying drones cannot fly below a specified speed
							{
								float minspeed = drone.MinSpeed;
								if (velocity.Length() <= minspeed)
								{
									inputVal = 1.0;
								}
							}

							OnDroneMoveForward(drone, inputVal, speeds);
						}

						inputVal = 0.0;

						if (!drone.DisableRightMovement)
						{
							// Left and right
							if (buttons & IN_MOVERIGHT)
								inputVal = 1.0;
							else if (buttons & IN_MOVELEFT) // Right takes priority
								inputVal = -1.0;

							OnDroneMoveRight(drone, inputVal, speeds);
						}

						inputVal = 0.0;

						if (!drone.DisableUpMovement)
						{
							// Up and down
							if (buttons & IN_JUMP)
								inputVal = 1.0;
							else if (buttons & IN_DUCK)
								inputVal = -1.0;

							OnDroneMoveUp(drone, inputVal, speeds);
						}
						
						if (velocity.Length() < maxSpeed)
						{
							velocity.Add(speeds);
						}

						FRotator viewAngles;
						viewAngles = client.GetEyeAngles();
						
						OnDroneAimChanged(viewAngles, seat, drone);

						SimulateDrone(drone, velocity, maxSpeed);
					}
				}
			}

			return;
		}
	}
	else if (seat.AIControlled) // If no client, check for an AI Controller
	{
		FDroneAI ai = FDroneAIStatics.GetSeatController(seat);
		if (ai)
		{
			//PrintToConsoleAll("Simulate seat %x with controller %x", seat, ai);
			SimulateController(ai, seat, drone);
		}
	}
}

// Setup our ammo text for the Drone UI
void FormatAmmoString(ADroneWeapon weapon, char[] buffer, int size)
{
	switch (weapon.State)
	{
		case WeaponState_Reloading: FormatEx(buffer, size, "Reloading...");
		case WeaponState_Ready, WeaponState_Custom:
		{
			if (weapon.BottomlessAmmo)
				FormatEx(buffer, size, ""); // No text if weapon has bottomless ammo
			else
				FormatEx(buffer, size, "Ammo: %d", weapon.Ammo);
		}
	}
}

// All passive actions for drones while idling
void SimulateDrone(ADrone drone, FVector velocity, float maxSpeed, bool legacy = false)
{
	if (!drone.Stunned)
	{
		// Clamp drone overall speed.
		//velocity.X = FMath.ClampFloat(velocity.X, -1.0 * maxSpeed, maxSpeed);
		//velocity.Y = FMath.ClampFloat(velocity.Y, -1.0 * maxSpeed, maxSpeed);

		// Passive braking
		float braking = drone.Deceleration;
		velocity.Scale(braking);

		FVector xyvel;
		xyvel = velocity;
		xyvel.Z = 0.0;
		if (xyvel.Length() >= maxSpeed)
		{
			float xyspeed = xyvel.Length();
			float mod = maxSpeed / xyspeed;
			xyvel.Scale(mod);
			velocity.X = xyvel.X;
			velocity.Y = xyvel.Y;
		}

		// Drones will passively counteract gravity; hover drones will only do this when close to the ground
		if (drone.MoveType == MoveType_Hover)
		{
			float distance = GetDistanceToGround(drone);
			float maxheight = drone.HoverMaxHeight;

			if (distance <= maxheight)
			{
				float minforce = 0.5;
				float force = minforce;
				float maxforce = drone.HoverIntensity;
				float percentage = 1.0 - (distance / maxheight);
				force = (percentage * (maxforce - minforce)) + minforce;
				velocity.Z += force;
			}
			else
			{
				FVector curVel;
				GetSmoothedVelocity(drone, curVel);
				velocity.Z = curVel.Z;
			}
		}
		else
		{
			//velocity.Z = FMath.ClampFloat(velocity.Z, -1.0 * maxSpeed, maxSpeed);
			velocity.Z += 12.0;
		}

		if (!legacy && GetFeatureStatus(FeatureType_Native, "Phys_SetVelocity") == FeatureStatus_Available)
		{
			//PrintCenterTextAll("PHYS");
			FVector angvel;
			angvel = drone.GetPropVector(Prop_Data, "m_vecAngVelocity");
			Phys_SetVelocity(drone.Get(), velocity.ToFloat(), angvel.ToFloat(), true);
		}
		else
		{
			//PrintCenterTextAll("DEFAULT");
			TeleportEntity(drone.Get(), NULL_VECTOR, NULL_VECTOR, velocity.ToFloat());
		}
	}
	else if (drone.StunnedUntilTime <= GetGameTime())
	{
		drone.Stunned = false;
	}
}

/*
bool InclineTooSteep(ADrone drone)
{
	FRotator rotation;
	rotation = drone.GetCurrentIncline();

	if (rotation.Pitch >= drone.HoverMaxIncline || rotation.Roll >= drone.HoverMaxIncline)
	{
		return true;
	}

	return false;
}
*/

float GetDistanceToGround(ADrone drone)
{
	float distance = 1.0;
	FVector start, end;
	start = drone.GetPosition();
	end = start;
	end.Z -= 3000.0;

	FVector mins, maxs;
	mins = drone.GetComponents().MinBounds;
	maxs = drone.GetComponents().MaxBounds;
	mins.Z = 0.0;
	FHullTrace trace = new FHullTrace(start, end, mins, maxs, MASK_SHOT_HULL, DroneMovementTrace, drone);
	end = trace.GetEndPosition();
	delete trace;

	distance = start.DistanceTo(end);

	return distance;
}

/*
bool CollisionImminent(ADrone drone, FVector velocity, FVector normal)
{
	FVector position, checkPos;
	position = drone.GetPosition();
	checkPos = velocity;
	checkPos.Scale(0.01); // about 10ms ahead
	checkPos.Add(position);

	FVector mins, maxs;
	mins = drone.GetComponents().MinBounds;
	maxs = drone.GetComponents().MaxBounds;

	//mins = ConstructVector(-20.0, -20.0, -20.0);
	//maxs = ConstructVector(20.0, 20.0, 20.0);

	FHullTrace trace = new FHullTrace(position, checkPos, mins, maxs, MASK_SHOT, DroneMovementTrace, drone);
	if (trace.DidHit()) // There is something in our way, let's move backwards
	{
		delete trace;
		normal = trace.GetNormalVector();
		return true;
	}
	delete trace;

	return false;
}
*/