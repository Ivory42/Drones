#if defined _customdrones_components_included
 #endinput
#endif
#define _customdrones_components_included

#include <sdktools>
#include <tf2_stocks>
#include "dronetypes.inc"
#include <ilib>

#define MAXATTACHMENTS 12
#define MAXWEAPONS 6
#define MAXSEATS 6

// Component object for drone attachments. If using a physical attachment, this component struct will house the FObject entity reference.
enum struct FComponent
{
	FObject Reference;

	// Max health for this component
	int MaxHealth;

	// Current health for this component
	int Health;

	bool Valid()
	{
		return this.Reference.Valid();
	}

	// Returns the entity index tied to this component
	int Get()
	{
		return this.Reference.Get();
	}

	// Sets this component's pointer reference
	void Set(int entity)
	{
		this.Reference.Set(entity);
	}

	// Sets the owner of this component
	void SetOwner(FObject owner)
	{
		this.Reference.SetOwner(owner);
	}

	// Returns the owner of this component
	FObject GetOwner()
	{
		return this.Reference.GetOwner();
	}

	// Returns the FObject associated with this component
	FObject GetObject()
	{
		return this.Reference;
	}
}

/*
* Struct containing information on a drone's weapon.
* Drones can have up to 6 of these weapons.
*/
enum struct FDroneWeapon
{
	FComponent Component; // Physical component this weapon is tied to

	FObject Parent; /*
					 * Usually the drone this weapon is attached to, however it can theoretically be another component as well.
					 * Cast to either a drone or component to make sure the parent is valid.
	 				 */

	int Ammo; // Ammo loaded

	int MaxAmmo; // Max ammo that can be loaded at once

	float Firerate; // How fast this weapon fires, measured in rounds per second

	FTimer AttackTimer; // Game time when this weapon is ready to fire again

	float Damage; // Damage this weapon should deal

	float ProjSpeed; // How fast the projectile should be fired at, if used

	float Inaccuracy; // Error in angle for this weapon upon consecutive attacks

	float ReloadTime; // How long this weapon reloads for

	FTimer ReloadTimer; // Game time when this weapon should be reloaded

	char Firesound[PLATFORM_MAX_PATH]; // Sound to use for this weapon firing

	EWeaponState State; // weapon state

	EWeaponType Type; // Weapon type

	float MaxPitch; // max pitch this weapon can fire at

	float MaxYaw; // max yaw this weapon can fire at

	bool Fixed; // Whether this weapon model is fixed or rotates

	char Name[MAX_WEAPON_LENGTH]; // Display name for this weapon

	char Plugin[64]; // Plugin name for this weapon

	char PluginWeapon[64]; // Weapon name within custom plugin

	/*
	 * Attachment setings
	 */

	FVector Offset; // Fallback offset to use if this weapon has no attachment point set

	FVector ProjOffset; // Fallback offset to use if this weapon has no muzzle attachment defined

	char MuzzleAttachment[64]; // Name of muzzle attachment for attack origination

	/*
	 * Weapon methods
	 */

	// Returns true if this is a valid weapon
	bool Valid()
	{
		return this.Component.Valid();
	}

	// Returns the entity index of this weapon
	int Get()
	{
		return this.Component.Get();
	}

	// Sets this weapon's pointer reference
	void Set(int entity)
	{
		this.Component.Set(entity);
	}

	// Returns the object this entity is attached to
	FObject GetObject()
	{
		return this.Component.Reference;
	}

	// Returns the component this weapon is tied to
	FComponent GetComponent()
	{
		return this.Component;
	}

	// Returns the parent object of this weapon
	FObject GetParent()
	{
		return this.Parent;
	}

	/*
	 * Called whenever a weapon is fired from a sub plugin.
	 * Handles ammo and initiating reloads on drone weapons
	 * 
	 * @param action     Action to handle ammo management (See OnDroneAttack forward)
	 * @param decrease   Ammo to decrease by if Plugin_Handled is passed
	 */
	void SimulateFire(Action action, int decrease)
	{
		this.AttackTimer.Loop();

		// Never reload if we don't have a clip size
		if (this.Ammo == -1)
			return;

		// Determine how we handle ammo counts - Plugin_Continue decrements ammo by one. Plugin_Handled reduces ammo by the given amount
		switch (action)
		{
			case Plugin_Continue: this.Ammo--;
			case Plugin_Handled: this.Ammo -= decrease;
			default: return;
		}

		if (this.Ammo == 0)
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
			this.ReloadTimer.Set(this.ReloadTime);
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
		if (this.Valid())
			return this.Component.Reference.GetPosition();
		
		// if we don't have a physical entity, return our offset
		return this.Offset;
	}

	// Returns the world position of this weapon
	FVector GetWorldPosition()
	{
		FVector parentPos, position;

		parentPos = this.Parent.GetPosition();

		// We can't get the world position of a parented entity normally, so get the relative position
		position = this.GetRelativePosition();

		// Add our parent position to our relative position to get our world position
		position.Add(parentPos);

		return position;
	}

	FTransform GetMuzzleTransform()
	{
		FTransform muzzle;

		// If we don't have an attachment defined, fallback to getting our position from our projectile offset
		if (!GetAttachmentTransform(this.GetObject(), this.MuzzleAttachment, muzzle))
		{
			FVector origin, offset;

			origin = this.GetWorldPosition();

			offset = this.ProjOffset;

			muzzle.position = origin;
			muzzle.position.Add(offset);
		}

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

	bool Visible; // Is the client in this seat visible

	ESeatType Type; // What type of seat this is, defines what the client occupying this seat can do.

	FVector Offset; // If no attachment position, where this seat is located offset from the vehicle.

	FDroneWeapon Weapon; // If a gunner/pilot seat, the weapon associated with this seat.

	char AttachmentPoint[64]; // Attachment point to use for this seat

	// Returns the client occupying this seat
	FClient GetOccupier()
	{
		return this.Occupier;
	}

	// Returns the weapon associated with this seat
	FDroneWeapon GetWeapon()
	{
		return this.Weapon;
	}

	// Returns the type of seat this is
	ESeatType GetSeatType()
	{
		return this.Type;
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
 * Returns an FComponent reference from the given entity index
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