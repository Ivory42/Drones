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
			FormatEx(propType, sizeof propType, "prop_dynamic_override");
		}

		ADroneWeapon weapon = view_as<ADroneWeapon>(CreateComponent(propType));
		weapon.SetKeyValue("model", modelname);

		weapon.Type = GetWeaponType(kv);
		weapon.UsesParent = nomodel;
		weapon.IsDroneWeapon = true;
		weapon.Drone = drone;

		FDroneWeaponExtras components;
		SetStringValues(weapon, kv);
		
		if (SetupMount(kv, drone, components))
		{
			components.Parent = components.Mount;
			weapon.ComplexAngles = true;
		}
		else // If no mount, parent to the drone
		{
			components.Parent = drone;
		}
		components.ProjOffset = Vector_GetFromKV(kv, "proj_offset");

		char attachment[64], muzzle[64];
		kv.GetString("attachment", attachment, sizeof attachment);
		kv.GetString("muzzle", muzzle, sizeof muzzle);
		FormatEx(components.MuzzleAttachment, sizeof FDroneWeaponExtras::MuzzleAttachment, muzzle);

		FTransform spawn;
		spawn.Position = drone.GetPosition();
		spawn.Rotation = drone.GetAngles();
		FEntityStatics.FinishSpawningEntity(weapon, spawn);

		weapon.GetObject().SetParent(components.Parent.GetObject());
		SetVariantString(attachment);
		weapon.GetObject().Input("SetParentAttachment");

		SDKHook(weapon.Get(), SDKHook_OnTakeDamage, OnComponentDamaged);

		weapon.Ammo = kv.GetNum("ammo_loaded", -1);
		if (weapon.Ammo == -1)
		{
			weapon.BottomlessAmmo = true;
		}
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
		weapon.AILeadTargets = view_as<bool>(kv.GetNum("ai_predict_targets", 0));

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

bool SetupMount(KeyValues kv, ADrone drone, FDroneWeaponExtras components)
{
	char modelname[64];
	kv.GetString("mount", modelname, sizeof modelname);
	if (strlen(modelname) > 3)
	{
		AComponent mount = CreateComponent("prop_dynamic_override");
		mount.SetKeyValue("model", modelname);

		char attachment[64];
		kv.GetString("mount_attach", attachment, sizeof attachment);

		FTransform spawn;
		spawn.Position = drone.GetPosition();
		spawn.Rotation = drone.GetAngles();
		FEntityStatics.FinishSpawningEntity(mount, spawn);

		mount.GetObject().SetParent(drone.GetObject());
		SetVariantString(attachment);
		mount.GetObject().Input("SetParentAttachment");

		mount.Drone = drone;

		components.Mount = mount;
		SDKHook(mount.Get(), SDKHook_OnTakeDamage, OnComponentDamaged);

		return true;
	}

	return false;
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
		muzzle = FGameplayStatics.CreateObject("info_target");
		if (weapon.GetMuzzleTransform(attach))
		{
			//PrintToChatAll("Found only one muzzle");
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
		else
		{
			// If no attachment found, resort to offset from origin
			//PrintToChatAll("no muzzle found");
			FObject attachEntity;
			attachEntity = weapon.GetReceiver();
			if (weapon.UsesParent)
			{
				AComponent parent = weapon.GetParent();
				attach.Position = FMath.OffsetVector(parent.GetPosition(), parent.GetAngles(), weapon.GetObjects().ProjOffset);
			}
			else
			{
				attach.Position = FMath.OffsetVector(weapon.GetPosition(), weapon.GetAngles(), weapon.GetObjects().ProjOffset);
			}

			muzzle.Teleport(attach.Position, attach.Rotation, ConstructVector());
			muzzle.SetParent(attachEntity);

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
		if (weapon.ComplexAngles)
		{
			start = GetComplexMuzzlePos(drone, weapon);
		}
		else if (weapon.GetNextMuzzleTransform(muzzle))
		{
			/*
			FVector velocity;
			velocity = drone.GetVelocity();
			velocity.Scale(0.1);
			muzzle.Position.Add(velocity);
			*/

			start = muzzle.Position;
			//PrintToChatAll("Fire position = %.1f, %.1f, %.1f", start.X, start.Y, start.Z);
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

		//PrintToChatAll("Aim position = %.1f, %.1f, %.1f", end.X, end.Y, end.Z);

		FRayTraceSingle trace = new FRayTraceSingle(start, direction, MASK_SHOT, DroneWeaponTrace, drone);
		//trace.DebugTrace();
		if (trace.DidHit())
		{
			FObject hitEnt;
			hitEnt = trace.GetHitEntity();
			if (hitEnt.Valid())
			{
				direction.Normalize();
				direction.Scale(100.0);
				SDKHooks_TakeDamage(hitEnt.Get(), drone.Get(), player.Get(), weapon.Damage, DMG_BULLET, -1, direction.ToFloat(), trace.GetEndPosition().ToFloat(), false);
			}
		}
		end = trace.GetEndPosition();
		//PrintToChatAll("End position = %.1f, %.1f, %.1f", end.X, end.Y, end.Z);
		delete trace;

		CreateTracer(start, end);
	}
}

/*
bool FilterIgnoreAll(int entity, int mask, any data)
{
	if (entity > 0)
	{
		return false;
	}

	return true;
}
*/

void DroneFireProjectile(ADrone drone, ADroneProjectileWeapon weapon, EProjType projectile, ADronePlayer player)
{
	FVector start, end;
	start = GetCameraOffset(drone);
	end = GetDroneAimPosition(drone, player.GetEyeAngles());

	// Now fire our projectiles
	int projectiles = weapon.ProjPerShot;
	FTransform muzzle;
	for (int i = 0; i < projectiles; i++)
	{
		if (weapon.ComplexAngles)
		{
			start = GetComplexMuzzlePos(drone, weapon);
		}
		else if (weapon.GetNextMuzzleTransform(muzzle))
		{
			start = muzzle.Position;
		}

		FVector direction;
		FRotator angle;
		direction = Vector_Subtract(end, start);
		angle = Vector_GetAngles(direction);

		angle.Pitch += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);
		angle.Yaw += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);

		FTransform spawn;
		spawn = ConstructTransform(start, angle);

		switch (projectile)
		{
			case DroneProj_Rocket: CreateRocket(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_rocket");
			case DroneProj_Energy: CreateRocket(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_energy_ball");
			case DroneProj_Sentry: CreateRocket(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_sentryrocket");
			case DroneProj_Grenade: CreateGrenade(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle);
			case DroneProj_Impact: CreateRocket(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_rocket", true);
			case DroneProj_Orb: CreateOrb(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle);
			case DroneProj_Laser: CreateLaser(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle);
		}
	}
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
		if (weapon.ComplexAngles)
		{
			start = GetComplexMuzzlePos(drone, weapon);
		}
		else if (weapon.GetNextMuzzleTransform(muzzle))
		{
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

				direction.Normalize();
				direction.Scale(100.0);

				FObject inflictor; // If we have a building attached for replication/bot targeting, set that as the inflictor
				inflictor = drone.GetObjectPropEnt("Drone.TargetComponent")
				if (!inflictor.Valid())
				{
					inflictor = drone.GetObject();
				}
				SDKHooks_TakeDamage(hitEnt.Get(), inflictor.Get(), attacker, weapon.Damage, DMG_BULLET, -1, direction.ToFloat(), trace.GetEndPosition().ToFloat(), false);
			}
		}
		end = trace.GetEndPosition();
		delete trace;

		CreateTracer(start, end);
	}
}

void DroneAIFireProjectile(ADrone drone, ADroneProjectileWeapon weapon, EProjType projectile, FDroneAI ai)
{
	FVector start, end;
	start = GetCameraOffset(drone);
	end = GetDroneAimPosition(drone, ai.GetViewAngle());

	// Now fire our projectiles
	int projectiles = weapon.ProjPerShot;
	FTransform muzzle;
	for (int i = 0; i < projectiles; i++)
	{
		if (weapon.ComplexAngles)
		{
			start = GetComplexMuzzlePos(drone, weapon);
		}
		else if (weapon.GetNextMuzzleTransform(muzzle))
		{
			start = muzzle.Position;
		}

		FVector direction;
		FRotator angle;
		direction = Vector_Subtract(end, start);
		angle = Vector_GetAngles(direction);

		angle.Pitch += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);
		angle.Yaw += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);

		FObject owner;
		if (ai.Owner)
		{
			owner = ai.Owner.GetObject();
		}
		else
		{
			owner = drone.GetObject();
		}

		FTransform spawn;
		spawn = ConstructTransform(start, angle);
		
		switch(projectile)
		{
			case DroneProj_Rocket: CreateRocket(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_rocket");
			case DroneProj_Energy: CreateRocket(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_energy_ball");
			case DroneProj_Sentry: CreateRocket(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_sentryrocket");
			case DroneProj_Grenade: CreateGrenade(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle);
			case DroneProj_Impact: CreateRocket(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_rocket", true);
			case DroneProj_Orb: CreateOrb(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle);
			case DroneProj_Laser: CreateLaser(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle);
		}
	}
}

// Not a perfect solution, but gets an approximate location of where this muzzle SHOULD be. Getting the world position of an entity in a multi-parented hierarchy doesn't seem to work, so doing this instead.
FVector GetComplexMuzzlePos(ADrone drone, ADroneWeapon weapon)
{
	FTransform muzzle;
	muzzle.Position = drone.GetPosition();
	muzzle.Position.Add(weapon.GetMount().GetRelativePosition());
	muzzle.Position.Add(weapon.GetRelativePosition());

	muzzle.Position.Z += weapon.GetObjects().ProjOffset.Z;

	muzzle.Rotation = weapon.GetMount().GetAngles();
	FRotator difference;

	difference.Yaw = muzzle.Rotation.Yaw + drone.GetAngles().Yaw;

	difference.Pitch = weapon.GetAngles().Pitch;

	//PrintCenterTextAll("Mount Yaw: %.1f\nDrone Yaw: %.1f\nDifference: %.1f", muzzle.Rotation.Yaw, drone.GetAngles().Yaw, difference.Yaw);

	FVector offset;
	offset = weapon.GetObjects().ProjOffset;
	offset.Z = 0.0;
	muzzle.Position = FMath.OffsetVector(muzzle.Position, difference, offset);
	return muzzle.Position;
}

void CreateRocket(ADroneProjectileWeapon weapon, FObject owner, FTransform spawn, float damage, int team = 0, FRotator direction, char[] classname, bool impact = false)
{
	ABaseDroneProjectile rocket = view_as<ABaseDroneProjectile>(FEntityStatics.CreateEntity(classname, owner, "DroneComponents.DroneRocketEntity"));
	if (rocket)
	{
		rocket.Damage = damage;
		rocket.Team = team;

		FEntityStatics.FinishSpawningEntity(rocket, spawn);
		rocket.WeaponLauncher = weapon;

		rocket.FireProjectile(direction, weapon.ProjectileSpeed);

		if (impact)
		{
			SDKHook(rocket.Get(), SDKHook_ShouldCollide, OnRocketOverlap);
			SDKHook(rocket.Get(), SDKHook_Touch, OnProjHit);
		}
	}
}

void CreateGrenade(ADroneProjectileWeapon weapon, FObject owner, FTransform spawn, float damage, int team = 0, FRotator direction)
{
	ADroneGrenade grenade = view_as<ADroneGrenade>(FEntityStatics.CreateEntity("tf_projectile_pipe", owner, "DroneComponents.DroneGrenadeEntity"));
	if (grenade)
	{
		grenade.FullDamage = damage;
		grenade.BlastRadius = 146.0;
		grenade.Damage = damage * 0.6; // 60% of impact damage
		grenade.Team = team;

		FEntityStatics.FinishSpawningEntity(grenade, spawn);
		grenade.WeaponLauncher = weapon;

		grenade.FireProjectile(direction, weapon.ProjectileSpeed);
	}
}

void CreateOrb(ADroneProjectileWeapon weapon, FObject owner, FTransform spawn, float damage, int team = 0, FRotator direction)
{
	ABaseDroneProjectile orb = view_as<ABaseDroneProjectile>(FEntityStatics.CreateEntity("tf_projectile_mechanicalarmorb", owner, "DroneComponents.DroneOrbEntity"));
	if (orb)
	{
		orb.Damage = damage;
		orb.Team = team;

		FEntityStatics.FinishSpawningEntity(orb, spawn);
		orb.WeaponLauncher = weapon;

		orb.FireProjectile(direction, weapon.ProjectileSpeed);
	}
}

void CreateLaser(ADroneProjectileWeapon weapon, FObject owner, FTransform spawn, float damage, int team = 0, FRotator direction)
{
	ABaseDroneProjectile laser = view_as<ABaseDroneProjectile>(FEntityStatics.CreateEntity("tf_projectile_energy_ring", owner, "DroneComponents.DroneEnergyRing"));
	if (laser)
	{
		// damage has to be set later
		laser.Team = team;

		laser.SetPropEnt(Prop_Send, "m_hLauncher", ConstructObject(CastToClient(owner).GetSlot(0)));
		laser.SetPropEnt(Prop_Send, "m_hOriginalLauncher", ConstructObject(CastToClient(owner).GetSlot(0)));

		FEntityStatics.FinishSpawningEntity(laser, spawn);
		laser.WeaponLauncher = weapon;
		laser.SetObjectPropFloat("DroneEnergyRing.Damage", damage);

		//SetEntityRenderMode(laser.Get(), RENDER_NORMAL);

		//int particle = GetEffectIndex("drg_pomson_projectile");
		//SetupParticleAttached(particle, laser.GetObject());

		laser.FireProjectile(direction, weapon.ProjectileSpeed);

		SDKHook(laser.Get(), SDKHook_Touch, OnLaserHit);
	}
}

Action OnProjHit(int entity, int victim)
{
	ABaseDroneProjectile rocket = view_as<ABaseDroneProjectile>(FEntityStatics.GetEntityFromIndex(entity));
	FObject hit;
	FClient client;

	hit = ConstructObject(victim);
	client = CastToClient(hit);
	if (!client.Valid()) // Not a client
	{
		if (victim == 0)
		{
			FEntityStatics.DestroyEntity(rocket);
			return Plugin_Handled;
		}
		if (hit.Cast("prop_"))
		{
			SDKHooks_TakeDamage(victim, entity, rocket.GetOwner().Get(), rocket.Damage, DMG_ENERGYBEAM, _, _, _, false);
			FEntityStatics.DestroyEntity(rocket);
			return Plugin_Handled;
		}

		if (hit.Cast("obj_"))
		{
			SDKHooks_TakeDamage(victim, entity, rocket.GetOwner().Get(), rocket.Damage, DMG_ENERGYBEAM, _, _, _, false);
			FEntityStatics.DestroyEntity(rocket);
			return Plugin_Handled;
		}

		return Plugin_Continue;
	}
	else
	{
		float damage = rocket.Damage;
		float distance = FGameplayStatics.GetDistanceBetweenObjects(rocket.GetOwningDrone().GetObject(), hit);
		float dmgMod = FMath.ClampFloat((512.0 / distance), 1.25, 0.528);
		damage *= dmgMod;
		SDKHooks_TakeDamage(victim, entity, rocket.GetOwner().Get(), damage, DMG_ENERGYBEAM, _, _, _, false);
		FEntityStatics.DestroyEntity(rocket);
		return Plugin_Handled;
	}
}

Action OnLaserHit(int entity, int victim)
{
	ABaseDroneProjectile laser = view_as<ABaseDroneProjectile>(FEntityStatics.GetEntityFromIndex(entity));
	FObject hit;
	FClient client;

	float damage = laser.GetObjectPropFloat("DroneEnergyRing.Damage");
	//PrintToChatAll("Damage = %.1f", damage);

	hit = ConstructObject(victim);
	client = CastToClient(hit);
	if (!client.Valid()) // Not a client
	{
		if (victim == 0)
		{
			FEntityStatics.DestroyEntity(laser);
			return Plugin_Handled;
		}
		if (hit.Cast("prop_") || hit.Cast("obj_"))
		{
			SDKHooks_TakeDamage(victim, entity, laser.GetOwner().Get(), damage, DMG_ENERGYBEAM, _, _, _, false);
			FEntityStatics.DestroyEntity(laser);
			return Plugin_Handled;
		}

		return Plugin_Continue;
	}
	else
	{
		SDKHooks_TakeDamage(victim, entity, laser.GetOwner().Get(), damage, DMG_ENERGYBEAM, _, _, _, false);
		FEntityStatics.DestroyEntity(laser);
		return Plugin_Handled;
	}
}

bool OnRocketOverlap(int rocketId, int collision, int mask, bool result)
{
	if (collision == 24)
	{
		return false;
	}

	return true;
}

bool WeaponFiresGrenades(ADroneWeapon weapon)
{
	if (weapon.Type == WeaponType_Projectile)
	{
		ADroneProjectileWeapon projLauncher = view_as<ADroneProjectileWeapon>(weapon);
		if (projLauncher.ProjType == DroneProj_Bomb || projLauncher.ProjType == DroneProj_Grenade)
		{
			return true;
		}
	}

	return false;
}
