#if defined _customdrones_rocket_included
 #endinput
#endif
#define _customdrones_rocket_included

#include "components.inc"

enum struct FRocket
{
	FComponent Component

	float Speed;

	bool Valid()
	{
		return this.Component.Valid();
	}

	int Get()
	{
		return this.Component.Get();
	}

	// Returns the FObject of this rocket
	FObject GetObject()
	{
		return this.Component.Comp;
	}

	// Returns the component of this rocket
	FComponent GetComponent()
	{
		return this.Component;
	}

	// Launch this rocket at the given angle
	void Fire(FRotator angle)
	{
		FVector vel;
		vel = angle.GetForwardVector();

		vel.Scale(this.Speed);

		FObject rocket;
		rocket = this.GetComponent();

		rocket.SetVelocityRotation(angle, vel);
	}
}

/*
* Creates a rocket and prepares it to be used with a drone
*
* @param owner		Owner of this rocket
* @param pos		Position to spawn this rocket
* @param type		Type of rocket to make
* @param speed		Speed this rocket should travel at
* @param damage		Damage this rocket will deal
*
* @return 			FRocket containing the information of the created rocket
*/
stock FRocket CreateDroneRocket(FClient owner, FVector pos, EProjType type, float speed, float damage)
{
	FRocket rocket;
	switch (type)
	{
		case DroneProj_Energy:
		{
			FormatEx(classname, sizeof classname, "tf_projectile_energy_ball");
			FormatEx(netname, sizeof netname, "CTFProjectile_EnergyBall");
		}
		case DroneProj_Sentry:
		{
			FormatEx(classname, sizeof classname, "tf_projectile_sentryrocket");
			FormatEx(netname, sizeof netname, "CTFProjectile_SentryRocket");
		}
		default:
		{
			FormatEx(classname, sizeof classname, "tf_projectile_rocket");
			FormatEx(netname, sizeof netname, "CTFProjectile_Rocket");
		}
	}

	FComponent component;
	component = CreateNewComponent(classname);

	rocket.Speed = speed;

	int team = owner.GetTeam();

	FObject proj;
	proj = component.GetObject();

	proj.SetOwner(owner.reference);

	proj.Teleport(pos, ConstructRotator(), ConstructVector());

	SetVariantInt(team);
	proj.Input("TeamNum");

	proj.Input("SetTeam");

	if (rocket.Valid())
		SetEntDataFloat(rocket.Get(), FindSendPropInfo(netname, "m_iDeflected") + 4, damage); //Set Damage for rocket

	return rocket;
}
