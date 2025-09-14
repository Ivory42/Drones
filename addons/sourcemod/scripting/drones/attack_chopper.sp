#include <drones/modules/hunterchopper>

public Plugin MyInfo = {
	name 			= 	"[Custom Drones 2] Combine Hunter Chopper",
	author 			=	"Ivory",
	description		= 	"Combine Chopper attack drone",
	version 		= 	"1.0"
};


public Action CD2_OnWeaponFire(ADrone drone, ADronePlayer gunner, ADroneWeapon weapon, FDroneSeat seat, int& ammo, const char[] name)
{
	APulseCannon cannon = view_as<APulseCannon>(weapon);
	if (cannon.IsPulseCannon)
	{
		if (!cannon.Charging && !cannon.Firing)
		{
			char sound[64];
			cannon.GetChargeSound(sound, sizeof sound);
			cannon.Charging = true;

			EmitSoundToAll(sound, weapon.Get(), SNDCHAN_AUTO, 90);

			SDroneStruct data = new SDroneStruct();
			data.Drone = drone;
			data.Player = gunner;
			data.Weapon = cannon;
			data.Seat = seat;
			CreateTimer(cannon.WindupTime, PulseCannonCharge, data, TIMER_FLAG_NO_MAPCHANGE);
		}
		else if (cannon.Firing)
		{
			cannon.Firing = false;
		}

		return Plugin_Handled;
	}
	return Plugin_Continue;
}

Action PulseCannonCharge(Handle timer, SDroneStruct data)
{
	if (!data)
	{
		return Plugin_Stop;
	}

	APulseCannon cannon = view_as<APulseCannon>(data.Weapon);
	if (cannon && cannon.IsPulseCannon)
	{
		if (!cannon.Charging)
		{
			EndFire(cannon);
			delete data;
			return Plugin_Stop;
		}

		cannon.Charging = false;
		char sound[64];
		cannon.GetDischargeSound(sound, sizeof sound);
		cannon.Firing = true;

		EmitSoundToAll(sound, cannon.Get(), SNDCHAN_AUTO, 120);

		CreateTimer(0.1, PulseCannonFire, data, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}

	return Plugin_Stop;
}

Action PulseCannonFire(Handle timer, SDroneStruct data)
{
	if (!data)
		return Plugin_Stop;

	APulseCannon cannon = view_as<APulseCannon>(data.Weapon);
	if (cannon && cannon.IsPulseCannon)
	{
		if (!cannon.Firing)
		{
			EndFire(cannon);
			data.Weapon = null;
			data.Player = null;
			data.Drone = null;
			data.Seat = null;
			delete data;
			return Plugin_Stop;
		}

		ADrone drone = data.Drone;
		ADronePlayer player = data.Player;
		FDroneStatics.FireBullets(player, drone, cannon, data.Seat);

		cannon.Ammo--;
		if (cannon.Ammo <= 0)
		{
			EndFire(cannon);
			cannon.SimulateReload();
			data.Weapon = null;
			data.Player = null;
			data.Drone = null;
			data.Seat = null;
			delete data;
			return Plugin_Stop;
		}

		return Plugin_Continue;
	}

	return Plugin_Stop;
}

void EndFire(APulseCannon cannon)
{
	char sound[64];
	cannon.GetDischargeSound(sound, sizeof sound);
	StopSound(cannon.Get(), SNDCHAN_AUTO, sound);

	cannon.GetChargeSound(sound, sizeof sound);
	StopSound(cannon.Get(), SNDCHAN_AUTO, sound);

	cannon.Firing = false;
	cannon.Charging = false;
}

public void CD2_OnDroneCreated(ADrone drone, const char[] name, KeyValues config)
{
	if (StrEqual(name, "combinechopper"))
	{
		AHunterChopper chopper = view_as<AHunterChopper>(drone);
		chopper.IsChopper = true;

		char sound[64];
		config.GetString("engine_sound", sound, sizeof sound, "misc/null.wav");
		if (strlen(sound) > 3)
		{
			PrecacheSound(sound);
			chopper.SetEngineSound(sound);
		}

		SetEntityRenderFx(drone.Get(), RENDERFX_FADE_FAST);

		char modelname[256];
		drone.GetComponents().GetModel(modelname, sizeof modelname);

		FObject model;
		model = FGameplayStatics.CreateObjectDeferred("prop_dynamic_override");
		model.SetKeyValue("model", modelname);

		FTransform spawn;
		spawn.Position = drone.GetPosition();
		spawn.Rotation = drone.GetAngles();

		FGameplayStatics.FinishSpawn(model, spawn);

		model.SetParent(drone.GetObject());
		chopper.SetModelEntity(model);
	}
}

public void CD2_OnWeaponCreated(ADrone drone, ADroneWeapon weapon, const char[] name, KeyValues config)
{
	if (StrEqual(name, "combinechopper_gun"))
	{
		APulseCannon cannon = view_as<APulseCannon>(weapon);
		cannon.IsPulseCannon = true;
		cannon.Firing = false;
		cannon.Charging = false;

		cannon.WindupTime = config.GetFloat("attack_windup_time");
		cannon.FireDuration = config.GetFloat("attack_duration");

		char sound[64];
		config.GetString("attack_windup_sound", sound, sizeof sound, "misc/null.wav");
		if (strlen(sound) > 3)
		{
			PrecacheSound(sound);
			cannon.SetChargeSound(sound);
		}

		config.GetString("attack_discharge_sound", sound, sizeof sound, "misc/null.wav");
		if (strlen(sound) > 3)
		{
			PrecacheSound(sound);
			cannon.SetDischargeSound(sound);
		}
	}
}

public void CD2_OnPlayerEnterDrone(ADrone drone, ADronePlayer player, FDroneSeat seat)
{
	if (seat == GetPilotSeat(drone))
	{
		AHunterChopper chopper = view_as<AHunterChopper>(drone);
		if (chopper.IsChopper)
		{
			FObject model;
			model = chopper.GetModelEntity();

			if (model.Valid())
			{
				SetVariantString("idle");
				model.Input("SetAnimation");
			}

			char sound[64];
			chopper.GetEngineSound(sound, sizeof sound);
			EmitSoundToAll(sound, drone.Get(), SNDCHAN_AUTO, 80);
		}
	}
}

public void CD2_OnAIControlDrone(ADrone drone, FDroneAI ai, FDroneSeat seat)
{
	if (seat == GetPilotSeat(drone))
	{
		AHunterChopper chopper = view_as<AHunterChopper>(drone);
		if (chopper.IsChopper)
		{
			FObject model;
			model = chopper.GetModelEntity();

			if (model.Valid())
			{
				SetVariantString("idle");
				model.Input("SetAnimation");
			}

			char sound[64];
			chopper.GetEngineSound(sound, sizeof sound);
			EmitSoundToAll(sound, drone.Get(), SNDCHAN_AUTO, 80);
		}
	}
}

public void CD2_OnDroneRemoved(ADrone drone, const char[] name)
{
	AHunterChopper chopper = view_as<AHunterChopper>(drone);
	if (chopper.IsChopper)
	{
		KillEngine(chopper);
	}
}

public Action CD2_OnDroneDestroyed(ADrone drone, FObject attacker, float damage, const char[] name)
{
	AHunterChopper chopper = view_as<AHunterChopper>(drone);
	if (chopper.IsChopper)
	{
		KillEngine(chopper);
		// Loop through weapons and stop the pulse cannon

		if (chopper.Weapons && chopper.Weapons.Length > 0)
		{
			for (int i = 0; i < chopper.Weapons.Length; i++)
			{
				APulseCannon cannon = view_as<APulseCannon>(chopper.Weapons.Get(i));
				if (cannon && cannon.IsPulseCannon)
				{
					EndFire(cannon);
				}
			}
		}
	}

	return Plugin_Continue;
}

void KillEngine(AHunterChopper chopper)
{
	FObject model;
	model = chopper.GetModelEntity();

	char sound[64];
	chopper.GetEngineSound(sound, sizeof sound);

	StopSound(chopper.Get(), SNDCHAN_AUTO, sound);

	if (model.Valid())
	{
		SetVariantString("reference");
		model.Input("SetAnimation");
	}
}

public void CD2_OnWeaponRemoved(ADroneWeapon weapon, const char[] name)
{
	APulseCannon cannon = view_as<APulseCannon>(weapon);
	if (cannon && cannon.IsPulseCannon)
	{
		EndFire(cannon);
	}
}

public void CD2_OnPlayerExitDrone(ADrone drone, ADronePlayer player, FDroneSeat seat)
{
	if (seat == GetPilotSeat(drone))
	{
		AHunterChopper chopper = view_as<AHunterChopper>(drone);
		if (chopper.IsChopper)
		{
			KillEngine(chopper);
		}
	}
}
