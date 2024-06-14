#include <drones/modules/weapons/medigun>

public void CD2_OnWeaponRemoved(ADroneWeapon weapon, const char[] name)
{
	AMediGun medigun = CastToMedigun(weapon);
	if (medigun)
	{
		medigun.Disconnect();

		if (medigun.DisplayTimer)
		{
			delete medigun.DisplayTimer;
		}

		if (medigun.HealTick)
		{
			delete medigun.HealTick;
		}
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
		medigun.HealAmount = config.GetFloat("heal_per_tick", 1.0);
		medigun.HealRate = config.GetFloat("heal_rate", 0.08);
		medigun.Overheal = config.GetFloat("overheal_ratio", 1.0);

		medigun.DisplayTimer = new STimer(1.0, false, true, false, 0.0);
		medigun.HealTick = new STimer(medigun.HealRate, false, true, false, 0.0);

		FEntityStatics.EnableEntityTick(medigun, OnMedigunTick, 0.0);
	}
}

public void OnMedigunTick(ABaseEntity entity)
{
	AMediGun medigun = CastToMedigun(entity);
	if (medigun)
	{
		if (medigun.Target)
		{
			if (FGameplayStatics.GetDistanceBetweenObjects(medigun.Target.GetObject(), medigun.GetObject()) > medigun.BeamRange + 50.0)
			{
				medigun.Disconnect();
			}
			
			FDroneSeat seat = medigun.Seat;
			if (seat && medigun.HealTick.Expired())
			{
				AClient owner = null;
				if (seat.AIControlled && seat.AIOccupier) // If this weapon is controlled by an AI, get the AI's owner
				{
					owner = FDroneAIStatics.GetSeatController(medigun.Seat).Owner;
				}
				else if (medigun.Seat.Occupier)
				{
					owner = medigun.Seat.Occupier;
				}
				HealPlayer(medigun.Target, owner, medigun);
			}
		}
	}
}

void HealPlayer(AClient patient, AClient healer, AMediGun medigun)
{
	FClient client;
	client = patient.GetClient();
	client.AddHealth(RoundFloat(medigun.HealAmount), medigun.Overheal); // 20% overheal

	if (patient.Health < patient.MaxHealth)
		medigun.HealingTotal += RoundFloat(medigun.HealAmount);

	if (medigun.DisplayTimer.Expired())
	{
		if (medigun.ShowEvent)
		{
			medigun.DisplayTimer.Loop();
			if (healer)
			{
				Event healing = CreateEvent("player_healed", true);

				//setup components for event
				healing.SetInt("patient", GetClientUserId(patient.Get()));
				healing.SetInt("healer", GetClientUserId(healer.Get()));
				healing.SetInt("amount", medigun.HealingTotal);

				medigun.HealingTotal = 0;

				healing.Fire(false);
			}
		}
		medigun.ShowEvent = (patient.Health < patient.MaxHealth);
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

		return Plugin_Handled;
	}
	return Plugin_Continue;
}
