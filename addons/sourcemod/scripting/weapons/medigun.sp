#include <drones/modules/weapons/medigun>

public void CD2_OnWeaponRemoved(ADroneWeapon weapon, const char[] name)
{
	AMediGun medigun = CastToMedigun(weapon);
	if (medigun)
	{
		medigun.Disconnect();
	}
}

public void CD2_OnWeaponCreated(ADrone drone, ADroneWeapon weapon, const char[] name, KeyValues config)
{
	if (StrEqual(name, "drone_medigun"))
	{
		AMediGun medigun = view_as<AMediGun>(weapon);
		medigun.IsMediGun = true;
		medigun.Target = null;
		medigun.BeamRange = config.GetFloat("beam_range", 200.0);
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
			// Find a target in front of us
			FVector aimPos;
			if (!gunner)
			{
				FDroneAI controller = FDroneAIStatics.GetSeatController(seat);
				if (controller)
				{
					aimPos = GetDroneAimPosition(drone, controller.GetViewAngle(), medigun.BeamRange);
				}
			}
			else
			{
				aimPos = GetDroneAimPosition(drone, gunner.GetEyeAngles(), medigun.BeamRange);
			}

			FRayTraceSingle trace = new FRayTraceSingle(weapon.GetPosition(), aimPos, MASK_SHOT, DroneWeaponTrace, drone);
			//trace.DebugTrace(2.0);
			if (trace.DidHit())
			{
				FClient client;
				client = CastToClient(trace.GetHitEntity());
				if (client.Valid())
				{
					if (client.GetTeam() == view_as<int>(drone.Team))
					{
						medigun.Target = FEntityStatics.GetClient(client);
						medigun.CreateBeamEntity();
					}
				}
			}
			delete trace;
		}
	}
	return Plugin_Stop;
}
