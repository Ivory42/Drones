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
		public get() { return view_as<APersistentObject>(this.GetObjectProp("Medigun_CurrentTarget")); }
		public set(APersistentObject value) { this.SetObjectProp("Medigun_CurrentTarget", value); }
	}

	public void SetBeamOrigin(FObject entity) { this.SetObjectPropEnt("Medigun_BeamOrigin", entity); }
	public FObject GetBeamOrigin() { return this.GetObjectPropEnt("Medigun_BeamOrigin"); }

	public void CreateBeamEntity()
	{
		if (!Target)
		{
			return;
		}

		FObject origin;
		origin = this.GetBeamOrigin();

		if (!origin.Valid())
		{
			return;
		}

		FParticleSystem particleOrigin, particleTarget;
		particleOrigin.Reference = this.GetObjectPropEnt("Medigun_ParticleOrigin");
		particleTarget.Reference = this.GetObjectPropEnt("Medigun_ParticleTarget");

		if (particleOrigin.Valid())
		{
			particleOrigin.Kill();
		}
		if (particleTarget.Valid())
		{
			particleTarget.Kill();
		}

		CreateMediBeam(this, particleOrigin);
	}
	public void RemoveBeamEntity()
	{

	}

	public void TryGetTarget()
	{

	}
	public void Disconnect()
	{

	}
}

stock void CreateMediBeam(AMediGun medigun, FParticleSystem beam)
{
	char particleName[64];
	FormatEx(particleName, sizeof particleName, Target.Team == 2 ? "medicgun_beam_red" : "medicgun_beam_blue");

	FTransform spawn; // Get the position of our first muzzle
	spawn.Position = medigun.MuzzlePositions.Get(0).GetPosition();
	spawn.Rotation = medigun.MuzzlePositions.Get(0).GetAngles();
	beam = CreateParticleSystem(particleName, spawn.Position, spawn.Rotation);
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
