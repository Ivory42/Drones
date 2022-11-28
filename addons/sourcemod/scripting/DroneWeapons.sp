GlobalForward DroneCreatedWeapon;
GlobalForward DroneWeaponDestroyed;

FDroneWeapon SetupWeapon(KeyValues kv, FDrone drone)
{
	FDroneWeapon weapon;

	char weaponname[MAX_WEAPON_LENGTH], modelname[PLATFORM_MAX_PATH], firesound[PLATFORM_MAX_PATH];

	// Models and sounds
	kv.GetString("name", weaponname, sizeof weaponname, "INVALID_WEAPON");
	kv.GetString("model", modelname, sizeof modelname);
	kv.GetString("sound", firesound, sizeof firesound);

	// Plugin
	char plugin[64];
	kv.GetString("plugin", plugin, sizeof plugin);
	weapon.Plugin = plugin;

	// Attachment settings
	char parentname[64];
	kv.GetString("parent", parentname, sizeof parentname, "Null");

	if (StrEqual(parentname, "Null", false)) // No parent given, parent to the drone
		weapon.Parent = drone.GetObject();

	char attachname[256];	
	kv.GetString("attachment", attachname, sizeof attachname, "Null");

	char muzzlename[256]; // Attachment point for projectile/bullet spawns
	kv.GetString("muzzle", muzzlename, sizeof muzzlename);

	// TODO - Search through drone attachments to find proper parent if name is given

	// Fallback positions if no attachments are found
	weapon.Offset = Vector_GetFromKV(kv, "offset");
	weapon.ProjOffset = Vector_GetFromKV(kv, "proj_offset");

	weapon.AttachmentPoint = attachname;
	weapon.MuzzleAttachment = muzzlename;

	// Set weapon stats
	weapon.Name = weaponname;
	weapon.Firesound = firesound;
	weapon.MaxAmmo = kv.GetNum("ammo_loaded", 1);
	weapon.Ammo = weapon.MaxAmmo;
	weapon.Inaccuracy = kv.GetFloat("inaccuracy", 0.0);
	weapon.ReloadTime = kv.GetFloat("reload_time", 1.0);
	weapon.Firerate = kv.GetFloat("attack_time");
	weapon.Fixed = view_as<bool>(kv.GetNum("fixed", 1)); // Will not rotate with camera
	weapon.Damage = kv.GetFloat("damage", 1.0);
	weapon.ProjSpeed = kv.GetFloat("speed", 1100.0);
	weapon.Modifier = kv.GetFloat("dmg_mod", 1.0); // Damage modifier when this weapon takes damage (How much extra damage this drone takes when this weapon is hit)

	// Fixed or not fixed
	if (!weapon.Fixed)
	{
		weapon.MaxPitch = kv.GetFloat("max_angle_y", 180.0);
		weapon.MaxYaw = kv.GetFloat("max_angle_x", 180.0);
	}

	// Now let's spawn the weapon only if we have a valid model name
	if (strlen(modelname) > 3)
		SpawnWeaponModel(kv, drone, weapon, modelname);

	Call_StartForward(DroneCreatedWeapon);

	Call_PushArray(drone, sizeof FDrone);
	Call_PushArray(weapon, sizeof FDroneWeapon);
	Call_PushString(weapon.Plugin);
	Call_PushString(drone.Config);

	Call_Finish();

	return weapon;
}

void SpawnWeaponModel(KeyValues kv, FDrone drone, FDroneWeapon weapon, const char[] modelname)
{
	FObject parent;
	parent = weapon.GetParent();

	// Make sure our parent exists before doing anything else
	if (parent.Valid())
	{
		FComponent component;
		component = CreateDeferredComponent("prop_physics_multiplayer"); // Create physics component to use

		FObject entity;
		entity = component.GetObject();

		entity.SetKeyValue("model", modelname);
		
		int health = kv.GetNum("health", 0);
		entity.SetProp(Prop_Data, "m_iHealth", health);
		if (health)
		{
			if (entity.HasProp(Prop_Data, "m_takedamage"))
				entity.SetProp(Prop_Data, "m_takedamage", 1);
		}

		SDKHook(entity.Get(), SDKHook_OnTakeDamage, OnWeaponDamaged);
		
		// Now let's get our spawn transform
		FTransform spawn;
		int id = LookupEntityAttachment(component.Get(), weapon.AttachmentPoint);
		if (id)
			Vector_GetEntityAttachment(component.GetObject(), id, spawn);
		else
		{
			// If we do not have an attachment point, fallback to using this weapons offset
			spawn.position = parent.GetPosition();
			spawn.rotation = parent.GetAngles();

			spawn.position.Add(weapon.Offset);
		}

		entity.Teleport(spawn.position, spawn.rotation, spawn.velocity);

		entity.SetParent(parent);

		// Finish up our spawning
		FinishComponent(component);

		weapon.Component = component;

		// Set this weapon's drone as the attached drone
		int entityId = entity.Get();
		Drone[entityId] = drone;
	}
}

Action OnWeaponDamaged(int weaponId, int& attackerId, int& inflictorId, float& damage, int& damagetype)
{
	FObject weapon;
	weapon.Set(weaponId);

	if (weapon.Valid() && Drone[weaponId].Valid() && Drone[weaponId].Alive)
	{
		int health = weapon.GetHealth();

		FDroneWeapon droneWeapon;
		FindDroneWeapon(weapon, Drone[weaponId].GetObject(), droneWeapon);

		if (droneWeapon.State == WeaponState_Destroyed) // Do not damage if this weapon is already destroyed
			return Plugin_Stop;

		if (droneWeapon.Modifier > 1.0)
			damage *= droneWeapon.Modifier;

		if (health <= 0)
			return Plugin_Stop;

		health -= damage;

		if (health <= 0)
			DestroyWeapon(droneWeapon, Drone[weaponId]);

		DroneTakeDamage(Drone[weaponId], Drone[weaponId].GetObject(), ConstructClient(attackerId), ConstructObject(inflictorId), damage, false, ConstructObject(attackerId));
	}
	return Plugin_Continue;
}

void DestroyWeapon(FDroneWeapon weapon, FDrone drone)
{
	weapon.State = WeaponState_Destroyed;

	weapon.GetObject().Input("ClearParent");

	if (drone.Valid())
	{
		// Deal damage to the drone?
	}

	Call_StartForward(DroneWeaponDestroyed);

	Call_PushArray(drone, sizeof FDrone);
	Call_PushArray(weapon, sizeof FDroneWeapon);
	Call_PushString(weapon.Plugin);
	Call_PushString(drone.Config);

	Call_Finish();
}

/**
 * Finds the drone weapon associated with the given entity object
 * 
 * @param entity     Entity object tied to the weapon
 * @param drone      Drone that owns the weapon being looked for
 * @param buffer	 Buffer to store weapon struct in, by reference
 */
void FindDroneWeapon(FObject entity, FObject drone, FDroneWeapon buffer)
{
	if (entity.Valid() && drone.Valid())
	{
		int entityId = entity.Get();
		int droneId = drone.Get();

		int checkId;
		for (int i = 1; i <= MAXWEAPONS; i++)
		{
			if (DroneWeapons[droneId][i].Valid())
			{
				checkId = DroneWeapons[droneId][i].Get();

				if (checkId == entityId) // Weapon has been found!
				{
					buffer = DroneWeapons[droneId][i];
					break;
				}
			}
		}
	}
}