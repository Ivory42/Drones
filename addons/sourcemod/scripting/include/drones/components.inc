#if defined _customdrones_components_included
 #endinput
#endif
#define _customdrones_components_included

#include <sdktools>
#include <tf2_stocks>
#include "dronetypes.inc"
#include "droneplayer.inc"
#include <objectmanager>

const int MaxWeapons = 4;
const int MaxSeats = 6;

methodmap AComponent < ABaseEntity
{
	property int Modifier // Extra damage this drone takes when this component is hit
	{
		public get() { return this.GetObjectProp("Comp_DamageModTaken"); }
		public set(int mod)	{ this.SetObjectProp("Comp_DamageModTaken", mod); }
	}
}

methodmap FComponentArray < ArrayList
{
	public FComponentArray()
	{
		ArrayList array = new ArrayList();
		return view_as<FComponentArray>(array);
	}
	
	public void ClearArray()
	{
		int length = this.Length;
		if (length > 0)
		{
			for (int i = 0; i < length; i++)
			{
				AComponent component = this.Get(i);
				FEntityStatics.DestroyEntity(component);
			}
		}
	}
}

enum struct FDroneWeaponExtras
{
	FObject Mount; 		// Optional physical mount to use for the weapon. This will rotate with the player's yaw
	FObject Parent; /*
					 * Usually the drone this weapon is attached to, however it can theoretically be another component as well.
					 * Cast to either a drone or component to make sure the parent is valid.
	 				 */

	// Attachments
	FVector Offset; 			// Fallback offset to use if this weapon has no attachment point set
	FVector ProjOffset; 		// Fallback offset to use if this weapon has no muzzle attachment defined
	char AttachmentPoint[256]; 	// Attachment point on parent to attach this weapon to
	char MuzzleAttachment[256]; // Name of muzzle attachment for attack origination
}

methodmap ADroneWeapon < AComponent
{
	// Returns the physical prop used as the mount of this weapon.
	public FDroneWeaponExtras GetObjects()
	{
		FDroneWeaponExtras objects;
		this.GetArray("Weapon_ObjProps", objects, sizeof objects);

		return objects;
	}
	public void SetObjects(FDroneWeaponExtras objects) { this.SetArray("Weapon_ObjProps", objects, sizeof objects); }

	// Weapon name used in the drone UI
	public void GetDisplayName(char[] name, int size) { this.GetObjectPropString("Weapon_DisplayName", name, size); }
	public void SetDisplayName(const char[] name) { this.SetObjectPropString("Weapon_DisplayName", name); }

	// Weapon name used by other plugins
	public void GetInternalName(char[] name, int size) { this.GetObjectPropString("Weapon_InternalName", name, size); }
	public void SetInternalName(const char[] name) { this.SetObjectPropString("Weapon_InternalName", name); }

	// Weapon fire sound
	public void GetFireSound(char[] sound, int size) { this.GetObjectPropString("Weapon_FireSound", sound, size); }
	public void SetFireSound(const char[] sound) { this.SetObjectPropString("Weapon_FireSound", sound); }

	property int Ammo // Ammo currently loaded
	{
		public get() { return this.GetObjectProp("Weapon_CurrentAmmo"); }
		public set(int ammo) { this.SetObjectProp("Weapon_CurrentAmmo", ammo); }
	}

	property int MaxAmmo // Max ammo loaded at once
	{
		public get() { return this.GetObjectProp("Weapon_MaxAmmo"); }
		public set(int ammo) { this.SetObjectProp("Weapon_MaxAmmo", ammo); }
	}

	property float FireRate // Weapon's firerate in rounds per second
	{
		public get() { return this.GetObjectPropFloat("Weapon_RateOfFire"); }
		public set(float rof) { this.SetObjectPropFloat("Weapon_RateOfFire", rof); }
	}

	property float Damage // Damage dealt by this weapon
	{
		public get() { return this.GetObjectPropFloat("Weapon_Damage"); }
		public set(float damage) { this.SetObjectPropFloat("Weapon_Damage", damage); }
	}

	property float NextPrimaryAttack // Next gametime value when this weapon can fire again
	{
		public get() { return this.GetObjectPropFloat("Weapon_NextPrimaryAttackTime"); }
		public set(float time) { this.SetObjectPropFloat("Weapon_NextPrimaryAttackTime", time); }
	}

	property float ProjectileSpeed // How fast a projectile from this weapon should be fired, if used
	{
		public get() { return this.GetObjectPropFloat("Weapon_ProjectileSpeed"); }
		public set(float speed) { this.SetObjectPropFloat("Weapon_ProjectileSpeed", speed); }
	}

	property float Inaccuracy // Error in angle for this weapon upon consecutive attacks
	{
		public get() { return this.GetObjectPropFloat("Weapon_SpreadError"); }
		public set(float error) { this.SetObjectPropFloat("Weapon_SpreadError", error); }
	}

	property float ReloadDelay // How long this weapon takes to reload
	{
		public get() { return this.GetObjectPropFloat("Weapon_ReloadTime"); }
		public set(float time) { this.SetObjectPropFloat("Weapon_ReloadTime", time); }
	}

	property STimer ReloadTimer // Timer used for reloading
	{
		public get() { return view_as<STimer>(this.GetObjectProp("Weapon_ReloadTimer")); }
		public set(STimer timer) { this.SetObjectProp("Weapon_ReloadTimer", timer); }
	}

	property EWeaponState State // Current state of this weapon
	{
		public get() { return view_as<EWeaponState>(this.GetObjectProp("Weapon_State")); }
		public set(EWeaponState state) { this.SetObjectProp("Weapon_State", state); }
	}

	property EWeaponType Type // Weapon type. Determines the type of projectile (if applicable) fired by this weapon
	{
		public get() { return view_as<EWeaponType>(this.GetObjectProp("Weapon_Type")); }
		public set(EWeaponType type) { this.SetObjectProp("Weapon_Type", type); }
	}

	property float TurnRate // How quickly this weapon rotates towards the player's view
	{
		public get() { return this.GetObjectPropFloat("Weapon_TurnRate"); }
		public set(float rate) { this.SetObjectPropFloat("Weapon_TurnRate", rate); }
	}

	property float MaxPitch // Max pitch this weapon can aim at (relative to drone)
	{
		public get() { return this.GetObjectPropFloat("Weapon_MaxPitchAngle"); }
		public set(float pitch) { this.SetObjectPropFloat("Weapon_MaxPitchAngle", pitch); }
	}

	property float MaxYaw // Max yaw value this weapon can aim at (relative to drone)
	{
		public get() { return this.GetObjectPropFloat("Weapon_MaxYawAngle"); }
		public set(float yaw) { this.SetObjectPropFloat("Weapon_MaxYawAngle", yaw); }
	}

	property bool Fixed // If true, this weapon will not rotate with the player's view angles
	{
		public get() { return this.GetObjectProp("Weapon_FixedAngles"); }
		public set(bool value) { this.SetObjectProp("Weapon_FixedAngles", value); }
	}

	property bool ComplexAngles // If true, this weapon's angles will be properly distributed between the mount and the weapon model
	{
		public get() { return this.GetObjectProp("Weapon_ComplexAngles"); }
		public set(bool value) { this.SetObjectProp("Weapon_ComplexAngles", value); }
	}

	// Returns the receiver object for this weapon
	public FObject GetReceiver()
	{
		return this.GetObject();
	}

	// Returns the mount of the receiver of this weapon
	public FObject GetMount()
	{
		return this.GetObjects().Mount;
	}

	// Returns the parent object of this weapon
	public FObject GetParent()
	{
		return this.GetObjects().Parent;
	}

	/*
	 * Called whenever a weapon is fired from a sub plugin.
	 * Handles ammo and initiating reloads on drone weapons
	 * 
	 * @param action     Action to handle ammo management (See OnDroneAttack forward)
	 * @param decrease   Ammo to decrease by if Plugin_Changed is passed
	 */
	public void SimulateFire(Action action, int decrease)
	{
		this.NextPrimaryAttack = GetGameTime() + this.FireRate; // Reset firerate

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

		char firesound[64];
		this.GetFireSound(firesound, sizeof firesound);

		if (strlen(firesound) > 3)
		{
			PrecacheSound(firesound);
			if (this.Valid()) // Need to change this check
				EmitSoundToAll(firesound, this.Get()); //emit from weapon if physical entity exists
			else
				EmitSoundToAll(firesound, this.GetParent().Get()); //otherwise just emit from the drone
		}
	}
	
	// Weapon tick event. Only used in core weapons plugin, do not call manually.
	public void Simulate()
	{
		if (this.ReloadTimer.Expired() && this.Ammo == 0 && this.State == WeaponState_Reloading)
		{
			this.Ammo = this.MaxAmmo;
			this.State = WeaponState_Ready;
		}
	}

	// Reloads this weapon.
	public void SimulateReload()
	{
		if (this.Ammo < this.MaxAmmo)
		{
			this.Ammo = 0;
			this.ReloadTimer = new STimer(this.ReloadDelay);
			this.State = WeaponState_Reloading;
		}
	}

	/* 
	 * Returns whether or not this weapon can be fired
	 *
	 * @param force     If true, force this weapon to fire as long as it's active and has ammo
	 */
	public bool CanFire(bool force)
	{
		if (force) //ignore attack delay
			return (this.Ammo != 0 && this.State == WeaponState_Ready);

		else if (this.Ammo != 0 && this.NextPrimaryAttack <= GetGameTime() && this.State == WeaponState_Ready)
			return true;

		return false;
	}

	// Retrieves the relative position of this weapon
	public FVector GetRelativePosition()
	{
		FVector position;

		position = this.GetReceiver().GetRelativePosition();

		return position;
	}

	// Returns the world position of this weapon
	public FVector GetWorldPosition()
	{
		FVector position;

		position = this.GetReceiver().GetPosition();

		return position;
	}

	public FTransform GetMuzzleTransform()
	{
		FTransform muzzle;

		// Retrieve the muzzle attachment according to the attachment point
		GetAttachmentTransform(this.GetReceiver(), this.GetObjects().MuzzleAttachment, muzzle);

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
methodmap FDroneSeat < StringMap
{
	public FDroneSeat()
	{
		StringMap seat = new StringMap();
		seat.SetValue("IsDroneSeat", true);

		return view_as<FDroneSeat>(seat);
	}

	public bool Valid()
	{
		bool valid = false;
		this.GetValue("IsDroneSeat", valid);

		return valid;
	}

	property ADronePlayer Occupier // Client occupying this seat
	{
		public get()
		{
			ADronePlayer client;
			this.GetValue("ClientInSeat", client);

			return client;
		}
		public set(ADronePlayer client) { this.SetValue("ClientInSeat", client); }
	}

	property bool Occupied // Whether or not this seat already has a client occupying it
	{
		public get()
		{
			bool value = false;
			this.GetValue("SeatTaken", value);

			return value;
		}
		public set(bool value) { this.SetValue("SeatTaken", value); }
	}

	property ESeatType Type // What type of seat this is, defines what the client occupying this seat can do.
	{
		public get()
		{
			ESeatType type;
			this.GetValue("SeatType", type);

			return type;
		}
		public set(ESeatType type) { this.SetValue("SeatType", type); }
	}

	property FComponentArray Weapons // Array of weapons this seat has access to use
	{
		public get()
		{
			FComponentArray weapons;
			this.GetValue("ValidWeaponGroup", weapons);

			return weapons;
		}
		public set(FComponentArray weapons) { this.SetValue("ValidWeaponGroup", weapons); }
	}

	property ADroneWeapon ActiveWeapon // Current weapon this seat is using
	{
		public get()
		{
			ADroneWeapon weapon;
			this.GetValue("ActiveWeapon", weapon);

			return weapon;
		}
		public set(ADroneWeapon weapon) { this.SetValue("ActiveWeapon", weapon); }
	}

	property int ActiveWeaponIndex // Current index in the array of weapons being used
	{
		public get()
		{
			int index = -1;
			this.GetValue("WeaponIndex", index);

			return index;
		}
		public set(int index) { this.SetValue("WeaponIndex", index); }
	}

	property float NextSwitchTime // Time when this seat can change weapons again
	{
		public get()
		{
			float time = 0.0;
			this.GetValue("NextSwitchTime", time);

			return time;
		}
		public set(float time) { this.SetValue("NextSwitchTime", time); }
	}

	// Gets the attachment point of this seat on the drone.
	public void GetAttachment(char[] name, int size) { this.GetString("SeatAttachPoint", name, size); }
	public void SetAttachment(const char[] name) { this.SetString("SeatAttachPoint", name); }

	// Returns true if this seat has an active weapon
	public bool HasWeapon()
	{
		if (this.Type == Seat_Passenger) // Passenger seats have no weapons
			return false;

		return (this.ActiveWeapon != null);
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
*
stock FComponent CreateNewComponent(const char[] classname)
{
	FComponent component;
	component.Reference.Create(classname);

	component.Reference.Spawn();
	return component;
}*/

/*
* Creates a new component but does not spawn it. Call FinishComponent() when ready to use.
*
* @param classname		Classname of the entity this component should be created as
* 
* @return				Component struct containing the entity
*
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
}*/

/**
 * Returns an FComponent object reference from the given entity index
 * 
 * @param entityId     Entity index to use as this component's FObject reference
 * @return             FComponent containing a reference to the given entity
 *
stock FComponent GetComponentFromEntity(int entityId)
{
	FComponent component;
	component.Reference = ConstructObject(entityId);

	return component;
}*/