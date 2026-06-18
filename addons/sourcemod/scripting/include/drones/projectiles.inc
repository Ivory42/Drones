#if defined _customdrones_rocket_included
 #endinput
#endif
#define _customdrones_rocket_included

#include "components.inc"

/*
* This include handles the methodmaps for vanilla-based projectiles fire from drones. This includes mostly rockets and pipebombs.
* These projectiles do not have any custom logic and will behave exactly as projectiles in vanilla TF2 behave.
*/

/*
* Map for handling projectiles.
*/
methodmap ABaseDroneProjectile < ABaseEntity
{
	// Damage this projectile will deal. Note: not all projectiles handle damage in the same way, this may not work for all
	property float Damage
	{
		public set(float value)
		{
			// Most projectiles use m_flDamage
			if (this.GetObject().HasProp(Prop_Send, "m_flDamage"))
			{
				this.GetObject().SetPropFloat(Prop_Send, "m_flDamage", value);
			}
			// However, projectiles based on rockets do NOT have a named damage property so we must use an offset
			else
			{
				// This should work for most other projectiles
				int offset = FindSendPropInfo(this.GetClassname(ClassType_Networked), "m_iDeflected") + 4;
				SetEntDataFloat(this.Get(), offset, value);
			}
		}
		public get()
		{
			// Same as before
			if (this.GetObject().HasProp(Prop_Send, "m_flDamage"))
			{
				return this.GetObject().GetPropFloat(Prop_Send, "m_flDamage");
			}
			else
			{
				// This should work for most other projectiles
				int offset = FindSendPropInfo(this.GetClassname(ClassType_Networked), "m_iDeflected") + 4;
				return GetEntDataFloat(this.Get(), offset);
			}
		}
	}

	property int Team
	{
		public set(int value)
		{
			if (this.Valid())
			{
				this.GetObject().SetProp(Prop_Send, "m_iTeamNum", value);
			}
		}
		public get()
		{
			if (this.Valid())
			{
				return this.GetObject().GetProp(Prop_Send, "m_iTeamNum");
			}

			return -1;
		}
	}

	// Used to get the projectile's speed from its velocity. Cannot be set, use ABaseProjectile::FireProjectile() to set velocity
	property float Speed
	{
		public get()
		{
			FVector vel;
			this.GetObject().GetPropVector(Prop_Data, "m_vecVelocity", vel);

			return vel.Length();
		}
	}

	// Whether or not this rocket is critical. Note: Not all projectiles can be critical
	property bool Critical
	{
		public set(bool value)
		{
			if (this.GetObject().HasProp(Prop_Send, "m_bCritical"))
				this.GetObject().SetProp(Prop_Send, "m_bCritical", view_as<int>(value));
		}
		public get()
		{
			if (this.GetObject().HasProp(Prop_Send, "m_bCritical"))
				return view_as<bool>(this.GetObject().GetProp(Prop_Send, "m_bCritical"));

			return false;
		}
	}

	property bool Homing
	{
		public get() { return this.GetObjectProp("DroneProjectile.IsHoming"); }
		public set(bool value) { this.SetObjectProp("DroneProjectile.IsHoming", value); }
	}

	property float HomingVelocity // Speed at which this projectile homes in on targets
	{
		public get() { return this.GetObjectPropFloat("DroneProjectile.HomingVelocity"); }
		public set(float value) { this.SetObjectPropFloat("DroneProjectile.HomingVelocity", value); }
	}

	property float HomingDelay // Delay before this projectile will begin homing
	{
		public get() { return this.GetObjectPropFloat("DroneProjectile.HomingDelay"); }
		public set(float value) { this.SetObjectPropFloat("DroneProjectile.HomingDelay", value); }
	}

	property float HomingMaxAngle // Max homing angle
	{
		public get() { return this.GetObjectPropFloat("DroneProjectile.HomingMaxAngle"); }
		public set(float value) { this.SetObjectPropFloat("DroneProjectile.HomingMaxAngle", value); }
	}

	// The weapon which fired this projectile
	property ADroneProjectileWeapon WeaponLauncher
	{
		public set(ADroneProjectileWeapon launcher) { this.SetObjectProp("DroneProjectile.LaunchingWeapon", launcher); }
		public get() { return this.GetObjectProp("DroneProjectile.LaunchingWeapon"); }
	}

	// Returns the drone which fired this projectile
	public ADrone GetOwningDrone()
	{
		if (this.WeaponLauncher)
		{
			return this.WeaponLauncher.Drone;
		}

		return null;
	}

	/*
	* Fires this projectile in the given direction. This can be used at any time during the projectile's life
	*
	* @param direction		Direction this projectile should fire at, as an angle
	* @param speed			Speed at which this projectile will fire at
	*/
	public void FireProjectile(FRotator direction, float speed)
	{
		if (this.Valid())
		{
			FVector uDir;
			uDir = direction.GetForwardVector(); // Get the unit direction
			uDir.Scale(speed);

			this.GetObject().SetVelocityRotation(direction, uDir); // Fire the projectile
		}
	}
}

methodmap ADroneGrenade < ABaseDroneProjectile
{
	property float FullDamage
	{
		public get()
		{
			int offset = FindSendPropInfo("CTFGrenadePipebombProjectile", "m_bDefensiveBomb")-4;
			return GetEntDataFloat(this.Get(), offset);
		}
		public set(float damage)
		{
			int offset = FindSendPropInfo("CTFGrenadePipebombProjectile", "m_bDefensiveBomb")-4;
			SetEntDataFloat(this.Get(), offset, damage);
		}
	}

	property float BlastRadius
	{
		public get() { return this.GetPropFloat(Prop_Send, "m_DmgRadius"); }
		public set(float value) { this.SetPropFloat(Prop_Send, "m_DmgRadius", value); }
	}
}

stock ABaseDroneProjectile CastDroneRocket(ABaseEntity entity)
{
	if (entity && IsEntityOfType(entity, "DroneComponents.DroneRocketEntity"))
	{
		return view_as<ABaseDroneProjectile>(entity);
	}

	return null;
}

stock ADroneGrenade CastDroneGrenade(ABaseEntity entity)
{
	if (entity && IsEntityOfType(entity, "DroneComponents.DroneGrenadeEntity"))
	{
		return view_as<ADroneGrenade>(entity);
	}

	return null;
}
