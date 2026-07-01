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

		char targetname[64];
		kv.GetString("weapon_name", targetname, sizeof targetname);
		weapon.GetObject().SetTargetName(targetname);

		GetPropComponentValues(weapon, kv);

		FDroneWeaponExtras components;
		SetStringValues(weapon, kv);
		
		if (SetupMount(kv, drone, components))
		{
			components.Parent = components.Mount;
			weapon.ComplexAngles = true;
			weapon.SetObjectPropEnt("DroneComponent.ParentEntity", components.Parent.GetObject());
		}
		else // If no mount, parent to the drone
		{
			components.Parent = drone;
		}

		// Add this weapon and mount to our attachments
		FDroneComponents droneComps;
		droneComps = drone.GetComponents();
		FComponentArray attachments = droneComps.Attachments
		if (!attachments)
		{
			attachments = new FComponentArray();
			drone.SetComponents(droneComps);
		}

		attachments.Push(weapon);
		if (components.Mount)
		{
			attachments.Push(components.Mount);
		}

		bool muzzlesUseOffset = false;
		char muzzleoffsets[64];
		kv.GetString("proj_offset", muzzleoffsets, sizeof muzzleoffsets);
		if (StrContains(muzzleoffsets, ";") == -1)
		{
			components.ProjOffset = Vector_GetFromKV(kv, "proj_offset");
		}

		char attachment[64], muzzle[64];
		kv.GetString("attachment", attachment, sizeof attachment);
		kv.GetString("muzzle", muzzle, sizeof muzzle);
		if (strlen(muzzle) == 0)
		{
			muzzlesUseOffset = true
		}
		FormatEx(components.MuzzleAttachment, sizeof FDroneWeaponExtras::MuzzleAttachment, muzzle);

		FTransform spawn;
		spawn.Position = drone.GetPosition();
		spawn.Rotation = drone.GetAngles();
		FEntityStatics.FinishSpawningEntity(weapon, spawn);

		weapon.GetObject().SetParent(components.Parent.GetObject());
		SetVariantString(attachment);
		weapon.GetObject().Input("SetParentAttachment");

		FVector modeloffset;
		modeloffset = Vector_GetFromKV(kv, "weapon_offset");
		TeleportEntity(weapon.Get(), modeloffset.ToFloat());

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
		weapon.MaxPitch = kv.GetFloat("max_pitch", -1.0);
		weapon.MinPitch = kv.GetFloat("min_pitch", -1.0);
		weapon.MaxYaw = kv.GetFloat("max_yaw", -1.0);
		weapon.MinYaw = kv.GetFloat("min_yaw", -1.0);
		weapon.MaxFirePitch = kv.GetFloat("max_firepitch", -1.0);
		weapon.MinFirePitch = kv.GetFloat("min_firepitch", -1.0);
		weapon.MaxFireYaw = kv.GetFloat("max_fireyaw", -1.0);
		weapon.MinFireYaw = kv.GetFloat("min_fireyaw", -1.0);
		weapon.Fixed = view_as<bool>(kv.GetNum("fixed"));
		weapon.ProjPerShot = kv.GetNum("bullets_per_shot", 1);
		weapon.AILeadTargets = view_as<bool>(kv.GetNum("ai_predict_targets", 0));
		weapon.HidesReticle = view_as<bool>(kv.GetNum("hide_reticle", 0));

		FRotator defangle;
		defangle = Rotator_GetFromKV(kv, "default_angle");
		weapon.SetDefaultAngle(defangle);

		if (weapon.Type == WeaponType_Projectile || weapon.Type == WeaponType_Custom) // Custom can use projectiles
		{
			ADroneProjectileWeapon projWeapon = view_as<ADroneProjectileWeapon>(weapon);
			SetupProjectileWeapon(projWeapon, kv);
		}

		weapon.SetObjects(components);

		SetupAttachments(weapon, muzzleoffsets, muzzlesUseOffset);

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

		char targetname[64];
		kv.GetString("mount_name", targetname, sizeof targetname);
		mount.GetObject().SetTargetName(targetname);

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

void SetupAttachments(ADroneWeapon weapon, const char[] muzzleoffsets, bool useOffsets)
{
	weapon.MuzzlePositions = new ArrayList();

	FObject muzzle;
	char muzzles[64][32];
	int length = 0;
	if (!useOffsets)
	{
		length = weapon.GetMuzzleCount();
	}
	else
	{
		length = ExplodeString(muzzleoffsets, ";", muzzles, sizeof muzzles, sizeof muzzles[]);
		// PrintToChatAll("Muzzles = %s", muzzleoffsets);
	}

	// char name[64];
	// weapon.GetDisplayName(name, sizeof name);
	// PrintToChatAll("Muzzle count on weapon %s found: %d", name, length);

	FTransform attach;
	FVector offset;
	if (length > 1)
	{
		for (int i = 0; i < length; i++)
		{
			if (!useOffsets)
			{
				if (weapon.GetMuzzleTransform(attach))
				{
					muzzle = FGameplayStatics.CreateObject("info_target");
					attach.Position = FMath.OffsetVector(attach.Position, attach.Rotation, weapon.GetObjects().ProjOffset);
					muzzle.Teleport(attach.Position, attach.Rotation, ConstructVector());
				}
			}
			else
			{
				// PrintToChatAll("Using offsets for muzzle");
				muzzle = FGameplayStatics.CreateObject("info_target");
				char vec[3][64];
				ExplodeString(muzzles[i], " ", vec, sizeof vec, sizeof vec[]);
				
				// PrintToChatAll("%s %s %s", vec[0], vec[1], vec[2]);
				offset.X = StringToFloat(vec[0]);
				offset.Y = StringToFloat(vec[1]);
				offset.Z = StringToFloat(vec[2]);

				FObject attachEntity;
				attachEntity = GetWeaponModel(weapon);

				attach.Position = FMath.OffsetVector(attachEntity.GetPosition(), attachEntity.GetAngles(), offset);
				muzzle.Teleport(attach.Position, attach.Rotation, ConstructVector());
			}

			if (muzzle.Valid())
			{
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
			// PrintToChatAll("Found only one muzzle");
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
			// PrintToChatAll("no muzzle found");
			FObject attachEntity;
			attachEntity = GetWeaponModel(weapon);
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

void SetupProjectileWeapon(ADroneProjectileWeapon weapon, KeyValues kv)
{
	weapon.ProjectileSpeed = kv.GetFloat("speed", 1100.0);
	weapon.ProjType = view_as<EProjType>(kv.GetNum("proj_type"));
	weapon.LocksOn = view_as<bool>(kv.GetNum("locks_on", 0));
	FRotator trajOffset;
	trajOffset = Rotator_GetFromKV(kv, "proj_trajectory_offset");
	weapon.SetTrajectoryOffset(trajOffset);
	weapon.FixedTrajectory = view_as<bool>(kv.GetNum("trajectory_uses_weapon", 0));
	weapon.RequiresLockOn = view_as<bool>(kv.GetNum("require_lockon", 0));
	if (weapon.RequiresLockOn)
	{
		weapon.LocksOn = true;
	}

	if (weapon.LocksOn)
	{
		weapon.LockOnTime = kv.GetFloat("lockon_time", 1.0);
		weapon.LockOnFOV = kv.GetFloat("lockon_fov", 10.0);
		weapon.HomingVelocity = kv.GetFloat("homing_velocity", 300.0);
		weapon.HomingDelay = kv.GetFloat("homing_delay", 0.0);
		weapon.HomingMaxAngle = kv.GetFloat("homing_max_angle", 180.0);
		char lockontype[64];
		kv.GetString("lockon_movetype", lockontype, sizeof lockontype, "both");
		weapon.LockOnType = GetWeaponLockOnType(lockontype);
		
		FTimer timer;
		timer = ConstructTimer(0.05, false, true, false);
		weapon.SetTimer("DroneWeapon.LockOnTimer", timer);
		weapon.LockOnProgress = 0.0;

		char sound[64];
		kv.GetString("lockon_tick_sound", sound, sizeof sound, "ui/message_update.wav");
		PrecacheSound(sound);
		weapon.SetLockTickSound(sound);

		kv.GetString("lockon_success_sound", sound, sizeof sound, "ui/killsound_electro.wav");
		PrecacheSound(sound);
		weapon.SetLockSuccessSound(sound);

		kv.GetString("lockon_failure_sound", sound, sizeof sound, "buttons/button2.wav");
		PrecacheSound(sound);
		weapon.SetLockFailureSound(sound);

		ABaseEntity reticle = CreateReticle(weapon.Drone);
		weapon.SetLockReticle(reticle.GetObject());
		reticle.SetObjectProp("DroneSprite.Reticle.Weapon", weapon);
		reticle.SetObjectProp("DroneSprite.Reticle.LockOnReticle", true);
		SDKHook(reticle.Get(), SDKHook_SetTransmit, OnReticleReplicate);
	}
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
	FDroneSeat seat = weapon.Seat;

	FDroneFireParams params;
	params = GetDroneFireParams(drone, weapon, player.GetEyeAngles(), seat);

	start = params.Start;
	end = params.End;

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

void DroneFireProjectile(ADrone drone, ADroneProjectileWeapon weapon, EProjType projectile, ADronePlayer player, bool homing = false)
{
	FVector start, end;
	FDroneSeat seat = weapon.Seat;

	FDroneFireParams params;
	params = GetDroneFireParams(drone, weapon, player.GetEyeAngles(), seat);

	start = params.Start;
	end = params.End;

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
		if (weapon.FixedTrajectory)
		{
			angle = weapon.Drone.GetAngles();
			FRotator offset;
			offset = weapon.GetTrajectoryOffset();
			angle = AddRotators(angle, offset);
		}
		else
		{
			direction = Vector_Subtract(end, start);
			angle = Vector_GetAngles(direction);
		}

		angle.Pitch += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);
		angle.Yaw += GetRandomFloat(-weapon.Inaccuracy, weapon.Inaccuracy);

		FTransform spawn;
		spawn = ConstructTransform(start, angle);

		ABaseDroneProjectile proj = null;
		switch (projectile)
		{
			case DroneProj_Rocket: proj = CreateRocket(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_rocket");
			case DroneProj_MiniRocket: proj = CreateRocket(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_rocket", false, true);
			case DroneProj_Energy: proj = CreateRocket(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_energy_ball");
			case DroneProj_Sentry: proj = CreateRocket(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_sentryrocket");
			case DroneProj_Grenade: proj = CreateGrenade(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle);
			case DroneProj_Cannon: proj = CreateGrenade(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle, true);
			case DroneProj_Impact: proj = CreateRocket(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_rocket", true);
			case DroneProj_Orb: proj = CreateOrb(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle);
			case DroneProj_Laser: proj = CreateLaser(weapon, player.GetObject(), spawn, weapon.Damage, view_as<int>(drone.Team), angle);
		}

		if (proj)
		{
			if (homing)
			{
				FObject target;
				target = weapon.GetObjectPropEnt("DroneWeapon.CurrentHomingTarget");
				proj.SetObjectPropEnt("DroneProjectile.CurrentHomingTarget", target);
				proj.Homing = true;
				proj.HomingVelocity = weapon.HomingVelocity;
				proj.HomingMaxAngle = weapon.HomingMaxAngle;
				proj.HomingDelay = GetGameTime() + weapon.HomingDelay;
				FEntityStatics.EnableEntityTick(proj, OnProjectileHoming);
			}
		}
	}
}

// Temp
FRotator AddRotators(const FRotator rot1, const FRotator rot2)
{
	FRotator result;
	result = rot1;
	result.Pitch += rot2.Pitch;
	result.Yaw += rot2.Yaw;
	result.Roll += rot2.Roll;

	NormalizeAngles(result);

	return result;
}

void OnProjectileHoming(ABaseEntity entity)
{
	ABaseDroneProjectile projectile = view_as<ABaseDroneProjectile>(entity);
	if (projectile && projectile.Homing)
	{
		if (projectile.HomingDelay <= GetGameTime())
		{
			FObject target;
			target = projectile.GetObjectPropEnt("DroneProjectile.CurrentHomingTarget");
			if (target.Valid())
			{
				FVector velocity, projPos, targPos, direction, homing;
				FRotator rotation, targAngle;

				velocity = projectile.GetVelocity();
				projPos = projectile.GetPosition();
				targPos = target.GetPosition();
				targPos.Z += 20.0;

				direction = Vector_MakeFromPoints(projPos, targPos);
				direction.Normalize();
				rotation = projectile.GetAngles();
				targAngle = Vector_GetAngles(direction);
				float fov = FMath.GetAngle(rotation, targAngle);
				if (fov <= projectile.HomingMaxAngle)
				{
					homing = direction;
					homing.Scale(projectile.HomingVelocity);
					float speed = velocity.Length();
					
					velocity.Add(homing);
					rotation = Vector_GetAngles(velocity);
					projectile.FireProjectile(rotation, speed);
				}
			}
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
	FDroneSeat seat = weapon.Seat;
	FDroneFireParams params;
	params = GetDroneFireParams(drone, weapon, ai.GetViewAngle(), seat);

	start = params.Start;
	end = params.End;

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
	FDroneSeat seat = weapon.Seat;
	FDroneFireParams params;
	params = GetDroneFireParams(drone, weapon, ai.GetViewAngle(), seat);

	start = params.Start;
	end = params.End;

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
			case DroneProj_Cannon: CreateGrenade(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle, true);
			case DroneProj_Impact: CreateRocket(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle, "tf_projectile_rocket", true);
			case DroneProj_Orb: CreateOrb(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle);
			case DroneProj_Laser: CreateLaser(weapon, owner, spawn, weapon.Damage, view_as<int>(drone.Team), angle);
		}
	}
}

// Not a perfect solution, but gets an approximate location of where this muzzle SHOULD be. Getting the world position of an entity in a multi-parented hierarchy doesn't seem to work, so doing this instead.
FVector GetComplexMuzzlePos(ADrone drone, ADroneWeapon weapon)
{
	#pragma unused drone
	FTransform muzzle;
	muzzle.Position = weapon.GetPosition();
	muzzle.Rotation = weapon.GetAngles();
	muzzle.Rotation.Yaw = weapon.GetMount().GetAngles().Yaw;

	muzzle.Position = FMath.OffsetVector(muzzle.Position, muzzle.Rotation, weapon.GetObjects().ProjOffset);
	return muzzle.Position;
	/*
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
	*/
}

ABaseDroneProjectile CreateRocket(ADroneProjectileWeapon weapon, FObject owner, FTransform spawn, float damage, int team = 0, FRotator direction, char[] classname, bool impact = false, bool mini = false)
{
	ABaseDroneProjectile rocket = view_as<ABaseDroneProjectile>(FEntityStatics.CreateEntity(classname, owner, "DroneComponents.DroneRocketEntity"));
	if (rocket)
	{
		rocket.Damage = damage;
		rocket.Team = team;

		FEntityStatics.FinishSpawningEntity(rocket, spawn);
		rocket.WeaponLauncher = weapon;

		rocket.FireProjectile(direction, weapon.ProjectileSpeed);

		if (mini)
		{
			rocket.SetObjectProp("DroneRocket.IsMiniRocket", true);
			int modelindex = PrecacheModel("models/items/ar2_grenade.mdl");
			for (int i = 0; i < 4; i++)
			{
				rocket.SetProp(Prop_Send, "m_nModelIndexOverrides", modelindex, i);
			}
			//rocket.AttachParticle("rockettrail_airstrike", ConstructVector());
			FObject trail;
			trail = FGameplayStatics.CreateObjectDeferred("env_spritetrail");

			PrecacheModel("materials/sprites/spotlight.vmt");
			trail.SetKeyValue("spritename", "materials/sprites/spotlight.vmt");
			trail.SetKeyValueInt("renderamt", 255);
			trail.SetKeyValue("rendermode", "1");
			trail.SetKeyValue("lifetime", "1.0");
			trail.SetKeyValue("startwidth", "5.0");
			trail.SetKeyValue("endwidth", "2.0");
			trail.SetKeyValue("rendercolor", "255 255 255");

			//spawn.Position = rocket.GetPosition();
			FGameplayStatics.FinishSpawn(trail, spawn);

			trail.SetParent(rocket.GetObject());
			rocket.SetObjectPropEnt("MiniRocket.Trail", trail);
		}

		if (impact)
		{
			rocket.SetObjectProp("DroneRocket.IsImpactRocket", true);
			ReskinRocket(rocket);
		}

		SDKHook(rocket.Get(), SDKHook_ShouldCollide, OnRocketOverlap);
		SDKHook(rocket.Get(), SDKHook_EndTouchPost, OnRocketEndTouch);
		SDKHook(rocket.Get(), SDKHook_Touch, OnRocketTouch);
	}

	return rocket;
}

void ReskinRocket(ABaseDroneProjectile rocket)
{
	rocket.GetObject().SetModel("models/weapons/w_models/w_baseball.mdl");
	FEntityStatics.SetValidationProperty(rocket, "DroneRocket.ImpactRocket");
	rocket.SetPropFloat(Prop_Send, "m_flModelScale", 0.1);
}

ABaseDroneProjectile CreateGrenade(ADroneProjectileWeapon weapon, FObject owner, FTransform spawn, float damage, int team = 0, FRotator direction, bool cannon = false)
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

		if (cannon) // loose cannon
		{
			grenade.SetProp(Prop_Send, "m_iType", 3);
		}

		grenade.FireProjectile(direction, weapon.ProjectileSpeed);
	}
	
	return grenade;
}

ABaseDroneProjectile CreateOrb(ADroneProjectileWeapon weapon, FObject owner, FTransform spawn, float damage, int team = 0, FRotator direction)
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

	return orb;
}

ABaseDroneProjectile CreateLaser(ADroneProjectileWeapon weapon, FObject owner, FTransform spawn, float damage, int team = 0, FRotator direction)
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

	return laser;
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

Action OnRocketTouch(int entity, int victim)
{
	ABaseDroneProjectile rocket = view_as<ABaseDroneProjectile>(FEntityStatics.GetEntityFromIndex(entity));
	FObject hit;
	FClient client;

	hit = ConstructObject(victim);
	if (victim == rocket.GetOwningDrone().Get()) // Pass through our own drone
	{
		int solid = rocket.GetProp(Prop_Send, "m_nSolidType");
		rocket.SetObjectProp("DroneRocket.OriginalSolid", solid);
		rocket.SetObjectProp("DroneRocket.IgnoreCollision", true);
		rocket.SetProp(Prop_Send, "m_nSolidType", 0);
		SetEntityCollisionGroup(rocket.Get(), 1);
		FObject rocketEnt;
		rocketEnt = rocket.GetObject();
		RequestFrame(RocketHitOwningDronePost, rocketEnt.GetReference());
		return Plugin_Handled;
	}

	if (rocket.GetObjectProp("DroneRocket.IsImpactRocket"))
	{
		client = CastToClient(hit);
		if (!client.Valid()) // Not a client
		{
			if (victim == 0)
			{
				FEntityStatics.DestroyEntity(rocket);
				return Plugin_Handled;
			}
			if ((hit.GetProp(Prop_Send, "m_nSolidType") != 0) && !(hit.GetProp(Prop_Send, "m_usSolidFlags") & 4))
			{
				if (hit.Cast("prop_") || hit.Cast("func_") || hit.Cast("obj_"))
				{
					SDKHooks_TakeDamage(victim, entity, rocket.GetOwner().Get(), rocket.Damage, DMG_ENERGYBEAM, _, _, _, false);
					FEntityStatics.DestroyEntity(rocket);
					return Plugin_Handled;
				}
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

	if (rocket.GetObjectProp("DroneRocket.IsMiniRocket"))
	{
		if ((hit.GetProp(Prop_Send, "m_nSolidType") != 0) && !(hit.GetProp(Prop_Send, "m_usSolidFlags") & 4))
		{
			FObject trail;
			trail = rocket.GetObjectPropEnt("MiniRocket.Trail");
			if (trail.Valid())
			{
				trail.Input("ClearParent");
				trail.KillOnDelay(5.0);
			}
		}
	}

	return Plugin_Continue;
}

void RocketHitOwningDronePost(int ref)
{
	FObject entity;
	entity.SetReference(ref);
	ABaseDroneProjectile rocket = view_as<ABaseDroneProjectile>(FEntityStatics.GetEntity(entity));
	if (rocket)
	{
		float speed = rocket.WeaponLauncher.ProjectileSpeed;
		rocket.FireProjectile(rocket.GetAngles(), speed);
	}
}

void OnRocketEndTouch(int entity, int other)
{
	ABaseDroneProjectile rocket = view_as<ABaseDroneProjectile>(FEntityStatics.GetEntityFromIndex(entity));
	if (rocket)
	{
		rocket.SetObjectProp("DroneRocket.IgnoreCollision", false);
		int solid = rocket.GetObjectProp("DroneRocket.OriginalSolid");
		rocket.SetProp(Prop_Send, "m_nSolidType", solid);
		SetEntityCollisionGroup(rocket.Get(), 24);
	}
}

bool OnRocketOverlap(int rocketId, int collision, int mask, bool result)
{
	if (collision == 24)
	{
		return false;
	}

	ABaseDroneProjectile rocket = view_as<ABaseDroneProjectile>(FEntityStatics.GetEntityFromIndex(rocketId));
	if (rocket)
	{
		if (rocket.GetObjectProp("DroneRocket.IgnoreCollision"))
		{
			return false;
		}
	}

	return result;
}

bool WeaponFiresGrenades(ADroneWeapon weapon)
{
	if (weapon.Type == WeaponType_Projectile)
	{
		ADroneProjectileWeapon projLauncher = view_as<ADroneProjectileWeapon>(weapon);
		switch (projLauncher.ProjType)
		{
			case DroneProj_Bomb, DroneProj_Cannon, DroneProj_Grenade: return true;
		}
	}

	return false;
}

FDroneFireParams GetDroneFireParams(ADrone drone, ADroneWeapon weapon, FRotator desiredAngle, FDroneSeat seat = null)
{
	FDroneFireParams params;

	// Add angle constraints
	FRotator weaponAngle;
	if (weapon.Fixed)
	{
		weaponAngle = drone.GetAngles();
	}
	else
	{
		weaponAngle = weapon.GetAngles();
	}
	
	if (weapon.MaxFirePitch >= 0.0 || weapon.MinFirePitch >= 0.0)
	{
		float maxpitch = weaponAngle.Pitch - weapon.MaxFirePitch;
		float minpitch = weaponAngle.Pitch + weapon.MinFirePitch;

		desiredAngle.Pitch = FMath.ClampFloat(desiredAngle.Pitch, maxpitch, minpitch);
	}
	if (weapon.MaxFireYaw >= 0.0 || weapon.MinFireYaw >= 0.0)
	{
		float maxyaw = weaponAngle.Yaw + weapon.MaxFireYaw;
		float minyaw = weaponAngle.Yaw - weapon.MinFireYaw;
		//PrintToChatAll("Weapon Yaw: %.1f\nAim Yaw: %.1f\nMax Yaw: %.1f\nMin Yaw: %.1f", weaponAngle.Yaw, desiredAngle.Yaw, maxyaw, minyaw);
		desiredAngle.Yaw = FMath.ClampFloat(desiredAngle.Yaw, minyaw, maxyaw);
		//NormalizeAngles(desiredAngle);

		//PrintToChatAll("Clamped Yaw: %.1f", desiredAngle.Yaw);
	}

	NormalizeAngles(desiredAngle);
	params.Angle = desiredAngle;

	if (seat)
	{
		params.Start = FMath.OffsetVector(drone.GetPosition(), drone.GetAngles(), seat.GetCameraOffset());
	}
	else
	{
		params.Start = GetCameraOffset(drone);
	}
	params.End = GetDroneAimPosition(drone, desiredAngle, seat);

	return params;
}

FObject GetWeaponModel(ADroneWeapon weapon)
{
	FObject model;
	model = weapon.GetReceiver();

	if (!model.Valid())
	{
		model = weapon.Drone.GetObject();
	}

	return model;
}
