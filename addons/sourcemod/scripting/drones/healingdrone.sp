#pragma semicolon 1

#include <drones/modules/healingdrone>

public Plugin MyInfo = {
	name 			= 	"[Custom Drones 2] Healing Drone",
	author 			=	"Ivory",
	description		= 	"Drone follows and heals players",
	version 		= 	"1.0"
};

public void CD2_OnDroneCreated(ADrone drone, const char[] name, KeyValues config)
{
	if (StrEqual(name, "healingdrone"))
	{
		AHealingDrone healer = view_as<AHealingDrone>(drone);
		healer.IsHealer = true;

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
		healer.SetModelEntity(model);
	}
}

public void CD2_OnPlayerEnterDrone(ADrone drone, ADronePlayer player, FDroneSeat seat)
{
	if (seat == GetPilotSeat(drone))
	{
		AHealingDrone healer = CastToHealDrone(drone);
		if (healer)
		{
			FObject model;
			model = healer.GetModelEntity();

			if (model.Valid())
			{
				SetVariantString("CloseUp");
				model.Input("SetAnimation");
			}
		}
	}
}

public void CD2_OnAIControlDrone(ADrone drone, FDroneAI ai, FDroneSeat seat)
{
	if (seat == GetPilotSeat(drone))
	{
		AHealingDrone healer = CastToHealDrone(drone);
		if (healer)
		{
			FObject model;
			model = healer.GetModelEntity();

			if (model.Valid())
			{
				SetVariantString("CloseUp");
				model.Input("SetAnimation");
			}
		}
	}
}

public void CD2_OnDroneRemoved(ADrone drone, const char[] name)
{
	AHealingDrone healer = CastToHealDrone(drone);
	if (healer)
	{
		KillEngine(healer);
	}
}

public void CD2_OnDroneDestroyed(ADrone drone, FObject attacker, float damage, const char[] name)
{
	AHealingDrone healer = CastToHealDrone(drone);
	if (healer)
	{
		KillEngine(healer);
		// Loop through weapons and stop the pulse cannon

		if (healer.Weapons && healer.Weapons.Length > 0)
		{
			for (int i = 0; i < healer.Weapons.Length; i++)
			{
				AMediGun medigun = CastToMedigun(healer.Weapons.Get(i));
				if (cannon && cannon.IsPulseCannon)
				{
					EndFire(cannon);
				}
			}
		}
	}
}

void KillEngine(AHealingDrone healer)
{
	FObject model;
	model = healer.GetModelEntity();

	if (model.Valid())
	{
		SetVariantString("OpenUp");
		model.Input("SetAnimation");
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
