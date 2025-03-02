#include <customdrones>

methodmap ABanshee < ADrone
{
	public void SetBoostL(FObject model) { this.SetArray("Banshee.BoostTrailL", model, sizeof FObject); }
	public FObject GetBoostL()
	{
		FObject model;
		this.GetArray("Banshee.BoostTrailL", model, sizeof FObject);

		return model;
	}

	public void SetBoostR(FObject model) { this.SetArray("Banshee.BoostTrailR", model, sizeof FObject); }
	public FObject GetBoostR()
	{
		FObject model;
		this.GetArray("Banshee.BoostTrailR", model, sizeof FObject);

		return model;
	}

	public void SetContrailL(FObject model) { this.SetArray("Banshee.ContrailL", model, sizeof FObject); }
	public FObject GetContrailL()
	{
		FObject model;
		this.GetArray("Banshee.ContrailL", model, sizeof FObject);

		return model;
	}

	public void SetContrailR(FObject model) { this.SetArray("Banshee.ContrailR", model, sizeof FObject); }
	public FObject GetContrailR()
	{
		FObject model;
		this.GetArray("Banshee.ContrailR", model, sizeof FObject);

		return model;
	}

	property float BoostRender
	{
		public get() { return this.GetObjectPropFloat("Banshee.BoostTrailTransparency"); }
		public set(float value) { this.SetObjectPropFloat("Banshee.BoostTrailTransparency", value); }
	}

	property float ContrailRender
	{
		public get() { return this.GetObjectPropFloat("Banshee.ContrailTransparency"); }
		public set(float value) { this.SetObjectPropFloat("Banshee.ContrailTransparency", value); }
	}

	property float BoostSpeed
	{
		public get() { return this.GetObjectPropFloat("Banshee.BoostSpeed"); }
		public set(float value) { this.SetObjectPropFloat("Banshee.BoostSpeed", value); }
	}

	property float BaseSpeed
	{
		public get() { return this.GetObjectPropFloat("Banshee.BaseSpeed"); }
		public set(float value) { this.SetObjectPropFloat("Banshee.BaseSpeed", value); }
	}

	property bool Boosting
	{
		public get() { return this.GetObjectProp("Banshee.IsBoosting"); }
		public set(bool value) { this.SetObjectProp("Banshee.IsBoosting", value); }
	}

	property bool Flying
	{
		public get() { return this.GetObjectProp("Banshee.Flying"); }
		public set(bool value) { this.SetObjectProp("Banshee.Flying", value); }
	}

	public void SetEngineSound(const char[] sound) { this.SetObjectPropString("Banshee.Engine", sound); }
	public void GetEngineSound(char[] sound, int size) { this.GetObjectPropString("Banshee.Engine", sound, size); }
}

methodmap APlasmaCannon < ADroneWeapon
{
	//
}
