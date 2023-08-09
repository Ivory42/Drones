#if defined _customdrones_components_included
 #endinput
#endif
#define _customdrones_components_included

#include <sdktools>
#include <tf2_stocks>
#include "dronetypes.inc"
#include <ilib>

// Would be nice if const could be used for array sizes...
#define MAXATTACHMENTS 6
#define MAXWEAPONS 6
#define MAXSEATS 6

methodmap AComponent < APersistentObject
{
	public AComponent(FObject entity)
	{
		APersistentObject component = new APersistentObject(entity);
		return view_as<AComponent>(component);
	}

	property int MaxHealth
	{
		public set(int health)
		{
			this.SetValue("MaxHealth", health);
		}
		public get()
		{
			return this.GetObjectProp("MaxHealth");
		}
	}

	property int Health
	{
		public set(int health)
		{
			this.SetValue("Health", health);
		}
		public get()
		{
			return this.GetObjectProp("Health");
		}
	}

	property float Modifier
	{
		public set(float value)
		{
			this.SetObjectPropFloat("DamageModifier", value);
		}
		public get()
		{
			return this.GetObjectPropFloat("DamageModifier");
		}
	}

	// Returns the entity object of the drone this weapon is owned by
	public FObject GetDroneObject()
	{
		return this.GetObjectPropEnt("ParentDrone");
	}
}

/*

*/
methodmap ADroneWeapon < AComponent
{
	public FObject GetMount() { return this.GetObjectPropEnt("Mount"); }

	public FObject GetReceiver() { return this.GetObjectPropEnt("Receiver"); }

	property int Ammo
	{
		public set(int ammo) { this.SetValue("CurrentAmmo", ammo); }
		public get() { return this.GetObjectProp("CurrentAmmo"); }
	}

	property int MaxAmmo
	{
		public set(int ammo) { this.SetValue("MaxAmmo", ammo); }
		public get() { return this.GetObjectProp("MaxAmmo"); }
	}

	property float FireRate // How fast this weapon fires, measured in rounds per second
	{
		public set(float rate) { this.SetObjectPropFloat("FireRate", rate); }
		public get() { return this.GetObjectPropFloat("FireRate"); }
	}

	property STimer NextAttackTimer // Game time when this weapon is ready to fire again
	{
		public set(STimer time) { this.SetValue("NextAttackTimer", time); }
		public get() { return view_as<STimer>(this.GetObjectProp("NextAttackTimer")); }
	}

	property float Damage // Damage this weapon should deal
	{
		public set(float value) { this.SetObjectPropFloat("Damage", value); }
		public get() { treturn this.GetObjectPropFloat("Damage"); }
	}

	property float ProjectileSpeed // How fast the projectile should be fired at, if used
	{
		public set(float speed) { this.SetObjectPropFloat("ProjSpeed", speed); }
		public get() { return this.GetObjectPropFloat("ProjSpeed"); }
	}

	property float Inaccuracy // Error in angle for this weapon upon consecutive attacks
	{
		public set(float value) { this.SetObjectPropFloat("Inaccuracy", value); }
		public get() { this.GetObjectPropFloat("Inaccuracy"); }
	}

	property float ReloadTime // How long this weapon reloads for
	{
		public set(float time)	{ this.SetObjectPropFloat("ReloadTime", time); }
		public get() { this.GetObjectPropFloat("ReloadTime"); }
	}

	property STimer ReloadTimer // Game time when this weapon should be reloaded
	{
		public set(STimer timer) { this.SetValue("ReloadTimer", timer); }
		public get() { return view_as<STimer>(this.GetObjectProp("ReloadTimer")); }
	}

	public void GetFiresound(char[] buffer, int size) { this.GetObjectString("FireSound", buffer, size); }

	property EWeaponState State // weapon state
	{
		public set(EWeaponState state) { this.SetValue("WeaponState", state); }
		public get() { return view_as<EWeaponState>(this.GetObjectProp("WeaponState")); }
	}

	// TODO - convert the rest of this struct to a methodmap

	float TurnRate; // How quickly this weapon rotates

	float MaxPitch; // max pitch this weapon can fire at

	float MaxYaw; // max yaw this weapon can fire at

	bool Fixed; // Whether this weapon model is fixed or rotates

	bool ComplexAngles; // Should the angles on this be distributed between the receiver and mount

	char Name[MAX_WEAPON_LENGTH]; // Display name for this weapon

	char Plugin[64]; // Plugin name for this weapon

	char PluginWeapon[64]; // Weapon name within custom plugin

	/*
	 * Attachment setings
	 */

	FVector Offset; // Fallback offset to use if this weapon has no attachment point set

	FVector ProjOffset; // Fallback offset to use if this weapon has no muzzle attachment defined

	char AttachmentPoint[256]; // Attachment point on parent to attach this weapon to

	char MuzzleAttachment[256]; // Name of muzzle attachment for attack origination

	/*
	 * Weapon methods
	 */

	/*
	 * Called whenever a weapon is fired from a sub plugin.
	 * Handles ammo and initiating reloads on drone weapons
	 * 
	 * @param action     Action to handle ammo management (See OnDroneAttack forward)
	 * @param decrease   Ammo to decrease by if Plugin_Changed is passed
	 */
	public void SimulateFire(Action action, int decrease)
	{
		this.AttackTimer.Loop();

		bool skip = false; // Skip reload check

		// Never reload if we don't have a clip size
		if (this.Ammo == -1)
			return;

		// Determine how we handle ammo counts - Plugin_Continue decrements ammo by one. Plugin_Changed reduces ammo by the given amount
		switch (action)
		{
			case Plugin_Continue: this.Ammo--;
			case Plugin_Changed: this.Ammo -= decrease;
			default: skip = true;
		}

		if (!skip && this.Ammo == 0)
			this.SimulateReload();

		if (strlen(this.Firesound) > 3)
		{
			PrecacheSound(this.Firesound);
			if (this.Valid())
				EmitSoundToAll(this.Firesound, this.Get()); //emit from weapon if physical entity exists
			else
				EmitSoundToAll(this.Firesound, this.GetParent().Get()); //otherwise just emit from the drone
		}
	}
	
	// Weapon tick event. Only used in core weapons plugin, do not call manually.
	void Simulate()
	{
		if (this.ReloadTimer.Expired() && this.Ammo == 0 && this.State == WeaponState_Reloading)
		{
			this.Ammo = this.MaxAmmo;
			this.State = WeaponState_Ready;
		}
	}

	// Reloads this weapon.
	void SimulateReload()
	{
		if (this.Ammo < this.MaxAmmo)
		{
			this.Ammo = 0;
			this.ReloadTimer.Set(this.ReloadTime, false);
			this.State = WeaponState_Reloading;
		}
	}

	/* 
	 * Returns whether or not this weapon can be fired
	 *
	 * @param force     If true, force this weapon to fire as long as it's active and has ammo
	 */
	bool CanFire(bool force)
	{
		if (force) //ignore attack delay
			return (this.Ammo != 0 && this.State == WeaponState_Ready);

		else if (this.Ammo != 0 && this.AttackTimer.Expired() && this.State == WeaponState_Ready)
			return true;

		return false;
	}

	// Retrieves the relative position of this weapon
	FVector GetRelativePosition()
	{
		FVector position;

		position = this.GetReceiver().GetRelativePosition();

		return position;
	}

	// Returns the world position of this weapon
	FVector GetWorldPosition()
	{
		FVector position;

		position = this.GetReceiver().GetPosition();

		return position;
	}

	FTransform GetMuzzleTransform()
	{
		FTransform muzzle;

		// Retrieve the muzzle attachment according to the attachment point
		GetAttachmentTransform(this.GetReceiver(), this.MuzzleAttachment, muzzle);

		return muzzle;
	}
}

/*
* Struct holding information on a drone seat.
* Seats do not have models and are not true components, they only hold position information,
* what the occupier of this seat can do, and whether or not the occupier can be seen.
*
* Drones may have up to 6 seats max.
*/
enum struct FDroneSeat
{
	FClient Occupier; // Client occupying this seat.

	bool Occupied; // Whether or not this seat is occupied

	ESeatType Type; // What type of seat this is, defines what the client occupying this seat can do.

	int WeaponIndex[MAXWEAPONS + 1]; // Index of drone weapons to use for this seat, when changing weapons, this seat will cycle through this array of indices

	int ActiveWeapon; // Current weapon active for this seat

	FTimer WeaponChangeTimer; // Delay between weapon changes

	char Attachment[64]; // Attachment point for this seat

	// Returns the client occupying this seat
	FClient GetOccupier()
	{
		return this.Occupier;
	}

	// Returns the active weapon index of this drone
	int GetWeaponIndex()
	{
		return this.ActiveWeapon;
	}

	// Returns the type of seat this is
	ESeatType GetSeatType()
	{
		return this.Type;
	}

	// Returns true if this seat has an active weapon index
	bool HasWeapon()
	{
		if (this.Type == Seat_Passenger) // Passenger seats have no weapons
			return false;

		int index = this.GetWeaponIndex();

		return (index >= 0 && index < MAXSEATS);
	}
}


/*****************************************
		STOCKS

******************************************/

/*
* Quickly creates a new component for usage by a drone. If you need to set parameters before the component is spawned, use CreateDeferredComponent() instead
*
* @param classname		Classname of the entity this component should be created as
* 
* @return				Component struct containing the entity
*/
stock FComponent CreateNewComponent(const char[] classname)
{
	FComponent component;
	component.Reference.Create(classname);

	component.Reference.Spawn();
	return component;
}

/*
* Creates a new component but does not spawn it. Call FinishComponent() when ready to use.
*
* @param classname		Classname of the entity this component should be created as
* 
* @return				Component struct containing the entity
*/
stock FComponent CreateDeferredComponent(const char[] classname)
{
	FComponent component;
	component.Reference.Create(classname);

	return component;
}

// Finishes setup of a deferred component and spawns it
stock void FinishComponent(FComponent component)
{
	FObject reference;
	reference = component.GetObject();

	reference.Spawn();
	reference.Activate();
}

/**
 * Returns an FComponent object reference from the given entity index
 * 
 * @param entityId     Entity index to use as this component's FObject reference
 * @return             FComponent containing a reference to the given entity
 */
stock FComponent GetComponentFromEntity(int entityId)
{
	FComponent component;
	component.Reference = ConstructObject(entityId);

	return component;
}