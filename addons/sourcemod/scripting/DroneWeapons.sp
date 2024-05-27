ADroneWeapon SetupWeapon(KeyValues kv, ADrone drone)
{
	if (kv && drone)
	{
		bool nomodel = false;
		char modelname[64], propType[32];
		kv.GetString("model", modelname, sizeof modelname);
		if (strlen(modelname) < 3)
		{
			FormatEx(propType, sizeof propType, "prop_dynamic_override"); // No model being used, it will be invisible
			FormatEx(modelname, sizeof modelname, "models/empty.mdl");
			nomodel = true;
		}
		else
		{
			FormatEx(propType, sizeof propType, "prop_physics_override");
		}

		ADroneWeapon weapon = view_as<ADroneWeapon>(FEntityStatics.CreateEntity(propType));
		weapon.SetKeyValue("model", modelname);

		weapon.Type = GetWeaponType(kv);
		weapon.UsesParent = nomodel;
		weapon.IsDroneWeapon = true;

		FDroneWeaponExtras components;
		components.Parent = drone;
		//SetupMount(kv, weapon, drone, components);
		SetStringValues(weapon, kv);

		char attachment[64], muzzle[64];
		kv.GetString("attachment", attachment, sizeof attachment);
		kv.GetString("muzzle", muzzle, sizeof muzzle);
		FormatEx(components.MuzzleAttachment, sizeof FDroneWeaponExtras::MuzzleAttachment, muzzle);

		FTransform spawn;
		//GetAttachmentTransform(drone.GetObject(), "Gun", spawn);
		spawn.Position = drone.GetPosition();
		spawn.Rotation = drone.GetAngles();
		FEntityStatics.FinishSpawningEntity(weapon, spawn);

		weapon.GetObject().SetParent(drone.GetObject());
		SetVariantString(attachment);
		weapon.GetObject().Input("SetParentAttachment");

		weapon.Ammo = kv.GetNum("ammo_loaded", -1);
		weapon.MaxAmmo = weapon.Ammo;
		weapon.Damage = kv.GetFloat("damage");
		weapon.FireRate = kv.GetFloat("fire_rate");
		weapon.Inaccuracy = kv.GetFloat("inaccuracy");
		weapon.ReloadDelay = kv.GetFloat("reload_time");
		weapon.ReloadTimer = new STimer(weapon.ReloadDelay, false, false, false, -weapon.ReloadDelay);
		weapon.State = WeaponState_Ready;
		weapon.TurnRate = kv.GetFloat("turn_rate");
		weapon.MaxPitch = kv.GetFloat("max_pitch");
		weapon.MaxYaw = kv.GetFloat("max_yaw");
		weapon.Fixed = view_as<bool>(kv.GetNum("fixed"));
		weapon.ProjPerShot = kv.GetNum("bullets_per_shot", 1);

		if (weapon.Type == WeaponType_Projectile)
		{
			ADroneProjectileWeapon projWeapon = view_as<ADroneProjectileWeapon>(weapon);
			SetupProjectileWeapon(projWeapon, kv);
		}

		weapon.SetObjects(components);

		SetupAttachments(weapon);

		char pluginName[64];
		weapon.GetInternalName(pluginName, sizeof pluginName);

		KeyValues config = new KeyValues("Drone");
		KvCopySubkeys(kv, config);

		Call_StartForward(DroneCreatedWeapon);

		Call_PushCell(drone);
		Call_PushCell(weapon);
		Call_PushString(pluginName);
		Call_PushCell(config);

		Call_Finish();

		delete config;

		return weapon;
	}
	return null;
}

void SetupAttachments(ADroneWeapon weapon)
{
	weapon.MuzzlePositions = new ArrayList();

	FObject muzzle;
	int length = weapon.GetMuzzleCount();

	//char name[64];
	//weapon.GetDisplayName(name, sizeof name);
	//PrintToChatAll("Muzzle count on weapon %s found: %d", name, length);

	FTransform attach;
	if (length > 1)
	{
		for (int i = 0; i < length; i++)
		{
			if (weapon.GetMuzzleTransform(attach))
			{
				//PrintToChatAll("Found muzzle %d", i);
				muzzle = FGameplayStatics.CreateObject("info_target");
				muzzle.Teleport(attach.Position, attach.Rotation, ConstructVector());
				if (weapon.UsesParent)
				{
					muzzle.SetParent(weapon.GetParent().GetObject());
				}
				else
				{
					muzzle.SetParent(weapon.GetReceiver());
				}

				weapon.MuzzlePositions.Push(muzzle.Reference);
			}
		}
	}
	else
	{
		if (weapon.GetMuzzleTransform(attach))
		{
			//PrintToChatAll("Found only one muzzle");
			muzzle = FGameplayStatics.CreateObject("info_target");
			muzzle.Teleport(attach.Position, attach.Rotation, ConstructVector());
			if (weapon.UsesParent)
			{
				muzzle.SetParent(weapon.GetParent().GetObject());
			}
			else
			{
				muzzle.SetParent(weapon.GetReceiver());
			}

			weapon.MuzzlePositions.Push(muzzle.Reference);
		}
	}
}

//void SetupMount(KeyValues kv, ADroneWeapon weapon, ADrone drone)
//{
	//
//}

void SetupProjectileWeapon(ADroneProjectileWeapon weapon, KeyValues kv)
{
	weapon.ProjectileSpeed = kv.GetFloat("speed", 1100.0);
	weapon.ProjType = view_as<EProjType>(kv.GetNum("proj_type"));
}

void SetStringValues(ADroneWeapon weapon, KeyValues kv)
{
	char bufferString[64];

	kv.GetString("name", bufferString, sizeof bufferString);
	weapon.SetDisplayName(bufferString);

	kv.GetString("plugin_name", bufferString, sizeof bufferString);
	weapon.SetInternalName(bufferString);

	kv.GetString("sound", bufferString, sizeof bufferString);
	weapon.SetFireSound(bufferString);
}

void DroneFireGun(ADrone drone, ADroneWeapon weapon, ADronePlayer player)
{
	FVector start, end;
	start = GetCameraOffset(drone);
	end = GetDroneAimPosition(drone, player.GetEyeAngles());

	// Now fire our bullets
	int bullets = weapon.ProjPerShot;
	FTransform muzzle;
	for (int i = 0; i < bullets; i++)
	{
		if (weapon.GetNextMuzzleTransform(muzzle))
		{
			FVector velocity;
			velocity = drone.GetVelocity();
			velocity.Scale(0.1);
			muzzle.Position.Add(velocity);

			start = muzzle.Position;
		}

		FVector direction;
		FRotator angle;
		direction = Vector_Subtract(end, start);
		angle = Vector_GetAngles(direction);

		angle.Pitch += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);
		angle.Yaw += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);

		direction = angle.GetForwardVector();
		direction.Scale(8000.0);
		direction.Add(start);

		FRayTraceSingle trace = new FRayTraceSingle(start, direction, MASK_SHOT, DroneWeaponTrace, drone);
		//trace.DebugTrace();
		if (trace.DidHit())
		{
			FObject hitEnt;
			hitEnt = trace.GetHitEntity();
			if (hitEnt.Valid())
			{
				SDKHooks_TakeDamage(hitEnt.Get(), drone.Get(), player.Get(), weapon.Damage);
			}
		}
		end = trace.GetEndPosition();
		delete trace;

		CreateTracer(start, end);
	}
}

void DroneFireRocket(ADrone drone, ADroneProjectileWeapon weapon, ADronePlayer player)
{
	FVector start, end;
	start = GetCameraOffset(drone);
	end = GetDroneAimPosition(drone, player.GetEyeAngles());

	// Now fire our rockets
	int rockets = weapon.ProjPerShot;
	FTransform muzzle;
	for (int i = 0; i < rockets; i++)
	{
		if (weapon.GetNextMuzzleTransform(muzzle))
		{
			/*
			FVector velocity;
			velocity = drone.GetVelocity();
			velocity.Scale(0.075);
			muzzle.Position.Add(velocity);
			*/
			start = muzzle.Position;
		}

		FVector direction;
		FRotator angle;
		direction = Vector_Subtract(end, start);
		angle = Vector_GetAngles(direction);

		angle.Pitch += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);
		angle.Yaw += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);

		URocket rocket = URocket();
		rocket.Damage = weapon.Damage;
		rocket.Team = player.GetClient().GetTeam();
		FGameplayStatics.FinishSpawn(rocket.GetObject(), muzzle);

		rocket.SetOwner(player.GetObject());

		rocket.FireProjectile(angle, weapon.ProjectileSpeed);
	}
}

FVector GetDroneAimPosition(ADrone drone, FRotator rotation)
{
	FVector start, direction, end;
	start = GetCameraOffset(drone);

	direction = rotation.GetForwardVector();
	direction.Scale(8000.0);
	direction.Add(start);

	FRayTraceSingle trace = new FRayTraceSingle(start, direction, MASK_SHOT, DroneWeaponTrace, drone);
	end = trace.GetEndPosition(); // Surface we are aiming at
	delete trace;

	return end;
}

FVector GetCameraOffset(ADrone drone)
{
	float cameraHeight = drone.CameraHeight;

	FVector start;
	start = FMath.OffsetVector(drone.GetPosition(), drone.GetAngles(), ConstructVector(0.0, 0.0, cameraHeight));

	return start;
}

bool DroneWeaponTrace(int entity, int mask, ADrone drone)
{
	if (entity == drone.Get())
		return false;

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

// Whenever the mount takes damage, send that damage over to the weapon itself
/*Action OnMountDamaged(int mountId, int& attackerId, int& inflictorId, float& damage, int& damagetype)
{
	FObject mount;
	mount = ConstructObject(mountId);

	if (mount.Valid())
	{
		// Get our weapon to decide how to damage the drone
		if (LinkedReceiver[mountId].Valid())
		{
			int weaponId = LinkedReceiver[mountId].Get();

			if (Drone[weaponId].Valid())
			{
				FDroneWeapon weapon;
				FindDroneWeapon(ConstructObject(weaponId), Drone[weaponId].GetObject(), weapon);

				// Go straight to damaging the drone if the weapon is already destroyed
				if (weapon.State == WeaponState_Destroyed)
				{
					DroneTakeDamage(Drone[weaponId], Drone[weaponId].GetObject(), ConstructClient(attackerId), ConstructObject(inflictorId), damage, false, ConstructObject(attackerId))
				}
				else // Otherwise send the damage directly to the weapon
				{
					OnWeaponDamaged(weaponId, attackerId, inflictorId, damage, damagetype);
				}
			}
		}
	}

	return Plugin_Continue;
}

Action OnWeaponDamaged(int weaponId, int& attackerId, int& inflictorId, float& damage, int& damagetype)
{
	FObject weapon;
	weapon = ConstructObject(weaponId);

	if (weapon.Valid() && Drone[weaponId].Valid() && Drone[weaponId].Alive)
	{
		int health = weapon.GetHealth();

		if (health <= 0)
			return Plugin_Stop;

		// Get our actual weapon object
		FDroneWeapon droneWeapon;
		FindDroneWeapon(weapon, Drone[weaponId].GetObject(), droneWeapon);

		if (droneWeapon.State == WeaponState_Destroyed) // Do not damage if this weapon is already destroyed
			return Plugin_Stop;

		damage *= droneWeapon.Modifier;

		health -= RoundFloat(damage);

		if (health <= 0)
			DestroyWeapon(droneWeapon, Drone[weaponId]);

		DroneTakeDamage(Drone[weaponId], Drone[weaponId].GetObject(), ConstructClient(attackerId), ConstructObject(inflictorId), damage, false, ConstructObject(attackerId));
	}
	return Plugin_Continue;
}

void DestroyWeapon(FDroneWeapon weapon, FDrone drone)
{
	weapon.State = WeaponState_Destroyed;

	weapon.GetReceiver().Input("ClearParent");

	if (drone.Valid())
	{
		// Deal damage to the drone?
	}

	// Need to add some explosion effects and stuffs

	Call_StartForward(DroneWeaponDestroyed);

	Call_PushArray(drone, sizeof FDrone);
	Call_PushArray(weapon, sizeof FDroneWeapon);
	Call_PushString(weapon.Plugin);
	Call_PushString(drone.Config);

	Call_Finish();
}
*/


// AI Controller Functions
void DroneAIFireGun(ADrone drone, ADroneWeapon weapon, FDroneAI ai)
{
	FVector start, end;
	start = GetCameraOffset(drone);
	end = GetDroneAimPosition(drone, ai.GetViewAngle());

	// Now fire our bullets
	int bullets = weapon.ProjPerShot;
	FTransform muzzle;
	for (int i = 0; i < bullets; i++)
	{
		if (weapon.GetNextMuzzleTransform(muzzle))
		{
			FVector velocity;
			velocity = drone.GetVelocity();
			velocity.Scale(0.1);
			muzzle.Position.Add(velocity);

			start = muzzle.Position;
		}

		FVector direction;
		FRotator angle;
		direction = Vector_Subtract(end, start);
		angle = Vector_GetAngles(direction);

		angle.Pitch += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);
		angle.Yaw += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);

		direction = angle.GetForwardVector();
		direction.Scale(8000.0);
		direction.Add(start);

		FRayTraceSingle trace = new FRayTraceSingle(start, direction, MASK_SHOT, DroneWeaponTrace, drone);
		//trace.DebugTrace();
		if (trace.DidHit())
		{
			FObject hitEnt;
			hitEnt = trace.GetHitEntity();
			if (hitEnt.Valid())
			{
				int attacker = drone.Get();
				// Check for an owner
				AClient owner = ai.Owner;
				if (owner)
					attacker = owner.Get();
				SDKHooks_TakeDamage(hitEnt.Get(), drone.Get(), attacker, weapon.Damage);
			}
		}
		end = trace.GetEndPosition();
		delete trace;

		CreateTracer(start, end);
	}
}

void DroneAIFireRocket(ADrone drone, ADroneProjectileWeapon weapon, FDroneAI ai)
{
	FVector start, end;
	start = GetCameraOffset(drone);
	end = GetDroneAimPosition(drone, ai.GetViewAngle());

	// Now fire our rockets
	int rockets = weapon.ProjPerShot;
	FTransform muzzle;
	for (int i = 0; i < rockets; i++)
	{
		if (weapon.GetNextMuzzleTransform(muzzle))
		{
			/*
			FVector velocity;
			velocity = drone.GetVelocity();
			velocity.Scale(0.075);
			muzzle.Position.Add(velocity);
			*/
			start = muzzle.Position;
		}

		FVector direction;
		FRotator angle;
		direction = Vector_Subtract(end, start);
		angle = Vector_GetAngles(direction);

		angle.Pitch += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);
		angle.Yaw += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);

		URocket rocket = URocket();
		rocket.Damage = weapon.Damage;
		rocket.Team = view_as<int>(drone.Team);
		FGameplayStatics.FinishSpawn(rocket.GetObject(), muzzle);

		FObject owner;
		if (ai.Owner)
		{
			owner = ai.Owner.GetObject();
		}
		else
		{
			owner = drone.GetObject();
		}
		rocket.SetOwner(owner);

		rocket.FireProjectile(angle, weapon.ProjectileSpeed);
	}
}

