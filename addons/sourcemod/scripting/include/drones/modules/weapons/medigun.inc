#include <customdrones>

methodmap AMediGun < ADroneWeapon
{
	property bool IsMediGun // Is this a medigun
	{
		public get() { return view_as<bool>(this.GetObjectProp("Weapon_IsMedigun")); }
		public set(bool value) { this.SetObjectProp("Weapon_IsMedigun", value); }
	}

	property AClient Target // Target player of this weapon
	{
		public get() { return view_as<AClient>(this.GetObjectProp("Medigun_CurrentTarget")); }
		public set(AClient value) { this.SetObjectProp("Medigun_CurrentTarget", value); }
	}

	property float BeamRange
	{
		public get() { return this.GetObjectPropFloat("Medigun_BeamRange"); }
		public set(float value) { this.SetObjectPropFloat("Medigun_BeamRange", value); }
	}

	property float HealAmount
	{
		public get() { return this.GetObjectPropFloat("Medigun_HealPerTick"); }
		public set(float value) { this.SetObjectPropFloat("Medigun_HealPerTick", value); }
	}

	property float HealRate
	{
		public get() { return this.GetObjectPropFloat("Medigun_HealTickRate"); }
		public set(float value) { this.SetObjectPropFloat("Medigun_HealTickRate", value); }
	}

	property float Overheal
	{
		public get() { return this.GetObjectPropFloat("Medigun_OverhealPercent"); }
		public set(float value) { this.SetObjectPropFloat("Medigun_OverhealPercent", value); }
	}

	property int HealingTotal // How much healing to display on heal events
	{
		public get() { return this.GetObjectProp("Medigun_HealEventTotal"); }
		public set(int value) { this.SetObjectProp("Medigun_HealEventTotal", value); }
	}

	property STimer DisplayTimer
	{
		public get() { return view_as<STimer>(this.GetObjectProp("Medigun_HealDisplayTimer")); }
		public set(STimer value) { this.SetObjectProp("Medigun_HealDisplayTimer", value); }
	}

	property STimer HealTick
	{
		public get() { return view_as<STimer>(this.GetObjectProp("Medigun_HealTickTimer")); }
		public set(STimer value) { this.SetObjectProp("Medigun_HealTickTimer", value); }
	}

	property bool ShowEvent // Is this a medigun
	{
		public get() { return view_as<bool>(this.GetObjectProp("Medigun_ShowHealEvent")); }
		public set(bool value) { this.SetObjectProp("Medigun_ShowHealEvent", value); }
	}

	public void CreateBeamEntity()
	{
		if (!this.Target)
		{
			return;
		}

		FObject particleOrigin;
		FObject particleTarget;
		particleOrigin = this.GetObjectPropEnt("Medigun_ParticleOrigin");
		particleTarget = this.GetObjectPropEnt("Medigun_ParticleTarget");

		if (particleOrigin.Valid())
		{
			particleOrigin.Kill();
		}
		if (particleTarget.Valid())
		{
			particleTarget.Kill();
		}

		CreateMediBeam(this, particleOrigin, particleTarget);
	}
	public void RemoveBeamEntity()
	{
		FObject beam, target;
		beam = this.GetObjectPropEnt("Medigun_ParticleOrigin");
		target = this.GetObjectPropEnt("Medigun_ParticleTarget");

		if (beam.Valid())
		{
			beam.Kill();
		}
		if (target.Valid())
		{
			target.Kill();
		}
	}

	public void Disconnect()
	{
		this.RemoveBeamEntity();

		this.Target = null;
	}
}

stock void CreateMediBeam(AMediGun medigun, FObject beam, FObject targetSystem)
{
	char particleName[64];
	FormatEx(particleName, sizeof particleName, medigun.Target.Team == TFTeam_Red ? "medicgun_beam_red" : "medicgun_beam_blue");
	

	// First setup our anchor point for the beam
	targetSystem = FGameplayStatics.CreateObjectDeferred("info_particle_system");

	char targetname[32], controlpoint[32], controlpoint2[32];

	FormatEx(controlpoint, sizeof controlpoint, "target%d", medigun.Target.Get());
	DispatchKeyValue(medigun.Target.Get(), "targetname", controlpoint);
	medigun.Target.SetKeyValue("targetname", controlpoint);

	FormatEx(controlpoint2, sizeof controlpoint2, "tf2particle%d", medigun.Target.Get());
	targetSystem.SetKeyValue("targetname", controlpoint2);
	targetSystem.SetKeyValue("parentname", controlpoint);

	FVector targetPos;
	targetPos = medigun.Target.GetPosition();
	targetPos.Z += 40.0;

	targetSystem.Teleport(targetPos, ConstructRotator(), ConstructVector());
	targetSystem.Spawn();

	//FGameplayStatics.FinishSpawn(targetSystem, ConstructTransform(targetPos, ConstructRotator()));
	targetSystem.SetParent(medigun.Target.GetObject());

	// Now we can setup the beam itself
	FObject origin; // Get the position of our first muzzle
	origin.Reference = medigun.MuzzlePositions.Get(0);

	FormatEx(targetname, sizeof targetname, "origin%d", origin.Get());
	origin.SetKeyValue("targetname", targetname);

	FTransform spawn; 
	spawn.Position = origin.GetPosition();
	spawn.Rotation = origin.GetAngles();
	beam = FGameplayStatics.CreateObjectDeferred("info_particle_system");

	beam.SetKeyValue("targetname", "tf2particle");
	beam.SetKeyValue("parentname", targetname);
	beam.SetKeyValue("effect_name", particleName);
	beam.SetKeyValue("cpoint1", controlpoint2);

	beam.Spawn();
	beam.Teleport(spawn.Position, spawn.Rotation, ConstructVector());
	beam.SetParent(origin);

	beam.Activate();
	beam.Input("start");

	medigun.SetObjectPropEnt("Medigun_ParticleOrigin", beam);
	medigun.SetObjectPropEnt("Medigun_ParticleTarget", targetSystem);
}

// Creates a healbeam between a player and an entity
stock void CreateHealBeamEntity(FClient player, FObject entity, FObject particlebuffer, FObject attachbuffer)
{
	if (!player.Valid())
		return;

	if (!entity.Valid())
		return;

	if (particlebuffer.Valid())
		particlebuffer.Kill();

	if (attachbuffer.Valid())
		attachbuffer.Kill();

	FObject particle;
	FObject particle2;

	particle.Create("info_particle_system");
	particle2.Create("info_particle_system");

	char name[64];
	FormatEx(name, sizeof name, "%s", player.GetTeam() == 2 ? "medicgun_beam_red" : "medicgun_beam_blue");

	char targetname[128];
	FormatEx(targetname, sizeof targetname, "target%i", entity.Get());
	entity.SetKeyValue("targetname", targetname);

	char controlpoint[128];
	FormatEx(controlpoint, sizeof controlpoint, "target%i", player.Get());
	DispatchKeyValue(player.Get(), "targetname", controlpoint);

	char controlpoint2[128];
	FormatEx(controlpoint2, sizeof controlpoint2, "tf2particle%i", player.Get());

	particle2.SetKeyValue("targetname", controlpoint2);
	particle2.SetKeyValue("parentname", controlpoint);

	FVector position;
	position = player.GetPosition();
	position.Z += 40.0;

	particle2.Teleport(position, ConstructRotator(), ConstructVector());

	particle2.Spawn();

	SetVariantString("!activator");
	particle2.Input("SetParent", player.Get());

	//SetVariantString("flag");
	//attach.Input("SetParentAttachment");

	//-----------------------------------------------

	particle.SetKeyValue("targetname", "tf2particle");
	particle.SetKeyValue("parentname", targetname);
	particle.SetKeyValue("effect_name", name);
	particle.SetKeyValue("cpoint1", controlpoint2);

	particle.Spawn();

	FVector spawn;
	spawn = entity.GetPosition();

	particle.Teleport(spawn, ConstructRotator(), ConstructVector());

	SetVariantString("!activator");
	particle.Input("SetParent", entity.Get());

	//SetVariantString("flag");
	//particle.Input("SetParentAttachment");

	particle.Activate();
	particle.Input("start");

	particlebuffer = particle;
	attachbuffer = particle2;
}

stock AMediGun CastToMedigun(ABaseEntity weapon)
{
	AMediGun medigun = null;
	if (weapon && weapon.GetObjectProp("Weapon_IsMedigun"))
	{
		medigun = view_as<AMediGun>(weapon);
	}

	return medigun;
}
