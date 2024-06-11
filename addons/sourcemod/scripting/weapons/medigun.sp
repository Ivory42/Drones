#include <drones/modules/weapons/medigun>

public void CD2_OnWeaponRemoved(ADroneWeapon weapon, const char[] name)
{
	APulseCannon cannon = view_as<APulseCannon>(weapon);
	if (cannon && cannon.IsPulseCannon)
	{
		EndFire(cannon);
	}
}

public void CD2_OnWeaponCreated(ADrone drone, ADroneWeapon weapon, const char[] name, KeyValues config)
{
	if (StrEqual(name, "drone_medigun"))
	{
		AMediGun medigun = view_as<AMediGun>(weapon);
		medigun.IsMediGun = true;
		medigun.Target = null;
	}
}

public Action CD2_OnWeaponFire(ADrone drone, ADronePlayer gunner, ADroneWeapon weapon, FDroneSeat seat, int& ammo, const char[] name)
{
	AMediGun medigun = CastToMedigun(weapon);
	if (medigun)
	{
		if (medigun.Target)
		{
			medigun.Disconnect();
		}
		else
		{
			medigun.TryGetTarget();
		}

		return Plugin_Stop;
	}
	return Plugin_Continue;
}
