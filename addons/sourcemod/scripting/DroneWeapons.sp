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

	weapon.AttachmentPoint = attachname;
	weapon.MuzzleAttachment = muzzlename;

	// Set weapon stats
	weapon.Name = weaponname;
	weapon.Firesound = firesound;
	weapon.MaxAmmo = kv.GetNum("ammo_loaded", 1);
	weapon.Ammo = weapon.MaxAmmo;
	weapon.Inaccuracy = kv.GetFloat("inaccuracy", 0.0);
	weapon.ReloadTime = kv.GetFloat("reload_time", 1.0);
	weapon.FireRate = kv.GetFloat("attack_time");
	weapon.Fixed = view_as<bool>(kv.GetNum("fixed", 1)); // Will not rotate with camera
	weapon.Damage = kv.GetFloat("damage", 1.0);
	weapon.ProjSpeed = kv.GetFloat("speed", 1100.0);
	weapon.Modifier = kv.GetFloat("dmg_mod", 1.0); // Damage modifier when this weapon takes damage (How much extra damage this drone takes when this weapon is hit)
	weapon.TurnRate = kv.GetFloat("turn_rate", 100.0); // rotation speed of weapon

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
		FObject receiver, mount;
		receiver = CreateObjectDeferred("prop_physics_multiplayer"); // Create physics component to use

		// Health value gets shared between mount and receiver if applicable
		int health = kv.GetNum("health", 0);
		weapon.MaxHealth = health;

		// Do we have a mount?
		if (strlen(weapon.MountModel) > 3)
		{
			// Mounts will act as the part of the weapon that can rotate with the player's camera yaw values
			// The receiver itself will rotate to match the player's pitch
			mount = CreateObjectDeferred("prop_dynamic_override");
			mount.SetKeyValue("model", weapon.MountModel);

			// Flags this object as a mount so it can properly share health with the weapon itself
			int mountId = mount.Get();
			IsMount[mountId] = true;
			LinkedReceiver[mountId] = receiver;

			SDKHook(mountId, SDKHook_OnTakeDamage, OnMountDamaged);

			// Player's angles are split between the mount and the receiver to give a proper look to the weapon's angles
			weapon.ComplexAngles = true;
		}

		receiver.SetKeyValue("model", modelname);

		receiver.SetProp(Prop_Data, "m_iHealth", health);
		if (health)
		{
			if (receiver.HasProp(Prop_Data, "m_takedamage"))
				receiver.SetProp(Prop_Data, "m_takedamage", 1);
		}

		SDKHook(receiver.Get(), SDKHook_OnTakeDamage, OnWeaponDamaged);
		
		// Now let's get our spawn transform

		int id;
		FTransform spawn;

		// if we have a mount, let's attach that first
		if (mount.Valid())
		{
			id = LookupEntityAttachment(parent.Get(), weapon.AttachmentPoint);
			if (id)
				Vector_GetEntityAttachment(parent, id, spawn);
			else
				LogError("Error: [Attach Mount] Cannot find attachment point '%s' assigned to this weapon! Make sure the attachment point exists on the parent model!", weapon.AttachmentPont);

			FinishSpawn(mount, spawn);
			mount.SetParent(parent);
			// Our new parent for this weapon's receiver
			parent = mount;
		}
		
		// Now let's attach the receiver
		id = LookupEntityAttachment(parent.Get(), weapon.AttachmentPoint);
		if (id)
			Vector_GetEntityAttachment(parent, id, spawn);
		else
			LogError("Error: [Attach Reciever] No attachment point found with name: %s!\nIf you are using a mount, it MUST have an attachment point with the same name that the mount attaches to on the drone!", weapon.AttachmentPoint);

		// Finish up our spawning
		FinishSpawn(receiver, spawn);

		receiver.SetParent(parent);

		weapon.Mount = mount;
		weapon.Receiver = receiver;

		// Set this weapon's drone as the attached drone
		int entityId = receiver.Get();
		Drone[entityId] = drone;
	}
}

// Whenever the mount takes damage, send that damage over to the weapon itself
Action OnMountDamaged(int mountId, int& attackerId, int& inflictorId, float& damage, int& damagetype)
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

	weapon.GetObject().Input("ClearParent");

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