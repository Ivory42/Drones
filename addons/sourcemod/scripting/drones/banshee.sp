#include <drones/modules/banshee>

public Plugin MyInfo = {
	name 			= 	"[Custom Drones 2] Halo Banshee",
	author 			=	"Ivory",
	description		= 	"Banshee vehicle from Halo: Reach",
	version 		= 	"1.0"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_spawnbanshee", CmdBanshee, ADMFLAG_BAN);
}

Action CmdBanshee(int client, int args)
{
	FDroneAIParams params;
	params = FDroneAIStatics.CreateParamSetFromConfig("banshee");

	params.Behavior = Behavior_Aggressive;

	FTransform spawn;
	spawn.Position = ConstructClient(client).GetEyePosition();
	spawn.Position.Z += 200.0;

	ADrone drone = FDroneStatics.SpawnDroneByConfig("banshee", spawn);
	if (drone)
	{
		FDroneAI ai = FDroneAIStatics.CreateDroneAIController(params);
		if (ai)
		{
			FDroneStatics.AIControlDroneSeat(drone, GetPilotSeat(drone), ai);
		}
	}

	return Plugin_Handled;
}

public void OnMapStart()
{
	PrecacheSound("weapons/custom/plasmarifle/shoot1.mp3");
	PrecacheSound("weapons/custom/plasmarifle/shoot2.mp3");
	PrecacheSound("weapons/custom/plasmarifle/shoot3.mp3");
	PrecacheSound("weapons/cow_mangler_main_shot.wav");
}

public Action CD2_OnWeaponFire(ADrone drone, ADronePlayer gunner, ADroneWeapon weapon, FDroneSeat seat, int& ammo, const char[] name)
{
	if (IsEntityOfType(weapon, "Banshee.FuelrodCannonWeapon"))
	{

	}
	else if (IsEntityOfType(weapon, "Banshee.PlasmaCannonWeapon"))
	{
		char fireSound[64];
		int sound = GetRandomInt(1, 3);
		FormatEx(fireSound, sizeof fireSound, "weapons/custom/plasmarifle/shoot%d.mp3", sound);
		EmitSoundToAll(fireSound, drone.Get());
	}
	return Plugin_Continue;
}

public void CD2_OnDroneCreated(ADrone drone, const char[] name, KeyValues config)
{
	if (StrEqual(name, "banshee"))
	{
		FEntityStatics.SetValidationProperty(drone, "Drone.IsBansheeDrone");
		ABanshee banshee = view_as<ABanshee>(drone);

		banshee.BoostSpeed = config.GetFloat("boost_speed");
		banshee.BaseSpeed = config.GetFloat("speed");
		char sound[64];
		config.GetString("engine_sound", sound, sizeof sound, "misc/null.wav");
		if (strlen(sound) > 3)
		{
			PrecacheSound(sound);
			banshee.SetEngineSound(sound);
		}

		// Set trails
		CreateTrails(banshee);
		FEntityStatics.EnableEntityTick(banshee, OnBansheeTick);
	}
}

public void OnPlayerRunCmdPost(int client, int buttons)
{
	ADronePlayer player = view_as<ADronePlayer>(FEntityStatics.GetClientFromIndex(client));
	if (player && player.InDrone)
	{
		if (IsEntityOfType(player.Drone, "Drone.IsBansheeDrone"))
		{
			ABanshee banshee = view_as<ABanshee>(player.Drone);
			if (buttons & IN_DUCK)
			{
				if (!banshee.Boosting)
				{
					PrecacheSound("weapons/bumper_car_accelerate.wav");
					EmitSoundToAll("weapons/bumper_car_accelerate.wav", banshee.Get(), SNDCHAN_AUTO, 90, _, 1.0);
					banshee.Boosting = true;
					banshee.Acceleration = 24.0;
					banshee.SpeedOverride = banshee.BoostSpeed;
				}
			}
			else if (banshee.Boosting)
			{
				PrecacheSound("weapons/bumper_car_decelerate.wav");
				EmitSoundToAll("weapons/bumper_car_decelerate.wav", banshee.Get(), SNDCHAN_AUTO, 90, _, 1.0);
				banshee.Boosting = false;
				banshee.Acceleration = 8.0;
				banshee.SpeedOverride = 0.0;
			}
		}
	}
}

void OnBansheeTick(ABaseEntity entity)
{
	if (IsEntityOfType(entity, "Drone.IsBansheeDrone"))
	{
		ABanshee banshee = view_as<ABanshee>(entity);
		if (banshee.Flying)
		{
			float oldYaw = banshee.LastFrameYaw;
			float newYaw = banshee.CurrentFrameYaw;

			float diff = oldYaw - newYaw;
			if (FloatAbs(diff) >= 0.6 && FloatAbs(diff) <= 80.0)
			{
				//PrintCenterTextAll("Turning: %.1f", diff);
				float alpha = FMath.ClampFloat((FloatAbs(diff) / 2.0) * 255.0, 0.0, 255.0);
				SetContrailAlphas(banshee, RoundFloat(alpha));
				banshee.ContrailRender = alpha;
			}
			else if (banshee.ContrailRender > 0.01)
			{
				banshee.ContrailRender = FMath.ClampFloat((banshee.ContrailRender - 1.2), 0.0, 255.0);
				SetContrailAlphas(banshee, RoundFloat(banshee.ContrailRender));
			}
			else
			{
				SetContrailAlphas(banshee, 0);
			}

			//PrintCenterTextAll("Trail: %.3f", banshee.ContrailRender);

			FVector velocity;
			velocity = banshee.GetVelocity();
			float speed = velocity.Length();
			int alpha = RoundFloat(FMath.ClampFloat((speed / banshee.BoostSpeed) * 230.0, 0.0, 230.0));
			SetBoostAlphas(banshee, alpha);
		}
	}
}

void CreateTrails(ABanshee drone)
{
	char trailColor[64];
	FormatEx(trailColor, sizeof trailColor, "255 255 255");

	float lifetime = 1.4;
	float width = 12.0;
	float end = 0.1;
	// Boost Trails first
	FObject trail;
	trail = CreateTrail(drone, trailColor, lifetime, width, end, "boost_l");
	trail.Input("HideSprite");
	drone.SetBoostL(trail);

	trail = CreateTrail(drone, trailColor, lifetime, width, end, "boost_r");
	trail.Input("HideSprite");
	drone.SetBoostR(trail);

	// Contrails for turning
	lifetime = 0.6;
	width = 4.0;
	trail = CreateTrail(drone, trailColor, lifetime, width, end, "contrail_l");
	trail.Input("HideSprite");
	drone.SetContrailL(trail);

	trail = CreateTrail(drone, trailColor, lifetime, width, end, "contrail_r");
	trail.Input("HideSprite");
	drone.SetContrailR(trail);
}

void ShowTrails(ABanshee banshee, FLinearColor color)
{
	banshee.GetBoostL().Input("ShowSprite");
	SetTrailColor(banshee.GetBoostL(), color);
	banshee.GetBoostR().Input("ShowSprite");
	SetTrailColor(banshee.GetBoostR(), color);

	banshee.GetContrailL().Input("ShowSprite");
	banshee.GetContrailR().Input("ShowSprite");
	
	SetContrailAlphas(banshee, 255);
}

void HideTrails(ABanshee banshee)
{
	banshee.GetBoostL().Input("HideSprite");
	banshee.GetBoostR().Input("HideSprite");
	banshee.GetContrailL().Input("HideSprite");
	banshee.GetContrailR().Input("HideSprite");
}

void SetContrailAlphas(ABanshee banshee, int alpha)
{
	banshee.GetContrailL().SetKeyValueInt("renderamt", alpha);
	banshee.GetContrailL().Spawn();

	banshee.GetContrailR().SetKeyValueInt("renderamt", alpha);
	banshee.GetContrailR().Spawn();
}

void SetBoostAlphas(ABanshee banshee, int alpha)
{
	banshee.GetBoostL().SetKeyValueInt("renderamt", alpha);
	banshee.GetBoostL().Spawn();

	banshee.GetBoostR().SetKeyValueInt("renderamt", alpha);
	banshee.GetBoostR().Spawn();
}

void SetTrailColor(FObject trail, FLinearColor color)
{
	SetVariantFloat(float(color.R));
	trail.Input("ColorRedValue");

	SetVariantFloat(float(color.G));
	trail.Input("ColorGreenValue");

	SetVariantFloat(float(color.B));
	trail.Input("ColorBlueValue");
}

public void CD2_OnWeaponCreated(ADrone drone, ADroneWeapon weapon, const char[] name, KeyValues config)
{
	if (StrEqual(name, "banshee_pcannons"))
	{
		FEntityStatics.SetValidationProperty(weapon, "Banshee.PlasmaCannonWeapon");
	}
	else if (StrEqual(name, "banshee_fuelrod"))
	{
		FEntityStatics.SetValidationProperty(weapon, "Banshee.FuelrodCannonWeapon");
	}
}

public void CD2_OnPlayerEnterDrone(ADrone drone, ADronePlayer player, FDroneSeat seat)
{
	if (seat == GetPilotSeat(drone))
	{
		if (IsEntityOfType(drone, "Drone.IsBansheeDrone"))
		{
			ABanshee banshee = view_as<ABanshee>(drone);
			banshee.Flying = true;
			
			FLinearColor color;
			TFTeam team = player.Team;
			switch (team)
			{
				case TFTeam_Red: color.Set(255, 0, 0, 255);
				case TFTeam_Blue: color.Set(5, 125, 255, 255);
				default: color.Set(255, 100, 150, 255);
			}

			ShowTrails(banshee, color);
		}
	}
}

public void CD2_OnAIControlDrone(ADrone drone, FDroneAI ai, FDroneSeat seat)
{
	if (seat == GetPilotSeat(drone))
	{
		if (IsEntityOfType(drone, "Drone.IsBansheeDrone"))
		{
			ABanshee banshee = view_as<ABanshee>(drone);
			banshee.Flying = true;
			
			FLinearColor color;
			//TFTeam team = player.Team; will do this later
			TFTeam team = TFTeam_Unassigned;
			switch (team)
			{
				case TFTeam_Red: color.Set(255, 0, 0, 255);
				case TFTeam_Blue: color.Set(5, 125, 255, 255);
				default: color.Set(255, 100, 150, 255);
			}

			ShowTrails(banshee, color);
		}
	}
}

public void CD2_OnDroneRemoved(ADrone drone, const char[] name)
{
	if (IsEntityOfType(drone, "Drone.IsBansheeDrone"))
	{
		RemoveTrails(view_as<ABanshee>(drone));
	}
}

public void CD2_OnDroneDestroyed(ADrone drone, FObject attacker, float damage, const char[] name)
{
	if (IsEntityOfType(drone, "Drone.IsBansheeDrone"))
	{
		RemoveTrails(view_as<ABanshee>(drone));
	}
}

/*
void KillEngine(ABanshee banshee)
{
	char sound[64];
	banshee.GetEngineSound(sound, sizeof sound);

	StopSound(banshee.Get(), SNDCHAN_AUTO, sound);
}
*/

public void CD2_OnPlayerExitDrone(ADrone drone, ADronePlayer player, FDroneSeat seat)
{
	if (seat == GetPilotSeat(drone))
	{
		if (IsEntityOfType(drone, "Drone.IsBansheeDrone"))
		{
			ABanshee banshee = view_as<ABanshee>(drone);
			banshee.Flying = false;
			HideTrails(banshee);
		}
	}
}

public void EntManager_OnEntityRegistered(ABaseEntity entity)
{
	ABaseDroneProjectile rocket = CastDroneRocket(entity);
	if (rocket)
	{
		PrintToChatAll("Found drone rocket");
		RequestFrame(DroneRocketPost, rocket);
	}
}

void DroneRocketPost(ABaseDroneProjectile rocket)
{
	ADroneProjectileWeapon launcher = rocket.WeaponLauncher;
	if (launcher)
	{
		char weaponname[64];
		launcher.GetInternalName(weaponname, sizeof weaponname);
		PrintToChatAll("Launcher: %s", weaponname);
		
		if (StrEqual(weaponname, "banshee_pcannons"))
		{
			PrintToChatAll("Reskinning");
			ReskinRocket(rocket);
		}
	}
}

void ReskinRocket(ABaseEntity rocket)
{
	FEntityStatics.SetValidationProperty(rocket, "DroneRocket.HowitzerRocket");
	rocket.GetObject().SetModel("models/weapons/w_models/w_baseball.mdl");
	rocket.SetPropFloat(Prop_Send, "m_flModelScale", 0.1);
	rocket.GetObject().AttachParticle("drg_cow_rockettrail_fire_blue", ConstructVector());
}

void RemoveTrails(ABanshee banshee)
{
	if (banshee.GetBoostL().Valid())
	{
		banshee.GetBoostL().Kill();
	}
	if (banshee.GetBoostR().Valid())
	{
		banshee.GetBoostR().Kill();
	}
	if (banshee.GetContrailL().Valid())
	{
		banshee.GetContrailL().Kill();
	}
	if (banshee.GetContrailR().Valid())
	{
		banshee.GetContrailR().Kill();
	}
}

FObject CreateTrail(ADrone drone, char[] color, float lifetime, float startWidth, float endWidth, char[] attach)
{
	char life[8], swidth[8], ewidth[8];
	FloatToString(lifetime, life, sizeof life);
	FloatToString(startWidth, swidth, sizeof swidth);
	FloatToString(endWidth, ewidth, sizeof ewidth);

	FObject trail;
	trail = FGameplayStatics.CreateObject("env_spritetrail");
	trail.SetKeyValue("renderamt", "255");
	trail.SetKeyValue("rendermode", "1");
	trail.SetKeyValue("spritename", "materials/sprites/spotlight.vmt");
	trail.SetKeyValue("lifetime", life);
	trail.SetKeyValue("startwidth", swidth);
	trail.SetKeyValue("endwidth", ewidth);
	trail.SetKeyValue("rendercolor", color);

	FGameplayStatics.FinishSpawn(trail, ConstructTransform(ConstructVector(), ConstructRotator()));

	FTransform transform;
	if (GetAttachmentTransform(drone.GetObject(), attach, transform))
	{
		//PrintToChatAll("Found transform for: %s", attach);
		trail.Teleport(transform.Position, transform.Rotation, ConstructVector());
	}

	trail.SetParent(drone.GetObject());
	SetVariantString(attach);
	trail.Input("SetParentAttachment");
	trail.Input("showsprite");

	return trail;
}
