#pragma semicolon 1
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <sdktools>
#include <customdrones>

DroneProp ParentDrone[2049];

char AttachmentName[2049][64];

public Plugin MyInfo = {
	name 			= 	"[Custom Drones] Attachments module",
	author 			=	"Ivory",
	description		= 	"Module for handling attachments on drones",
	version 		= 	"1.0.0"
};

public void OnPluginStart()
{
}

///
/// Spawn any attachments for the drone being created
///

public void CD_OnDroneCreated(DroneProp drone, const char[] plugin, const char[] config)
{
	if (!drone.hull.valid())
		return;
		
	KeyValues prefab = KeyValues("Drone");
	char sPath[64];
	BuildPath(Path_SM, sPath, sizeof sPath, "configs/drones/%s.txt", drone_name);

	if (!FileExists(sPath))
	{
		LogMessage("[ATTACHMENT SPAWNS] Could not find drone config %s!", sPath);
		delete prefab;
		return;
	}
	
	prefab.ImportFromFile(sPath);
	
	if (prefab.JumpToKey("attachments"))
	{
		int hull = drone.hull.get();
		for (int index = 0; index != MAXATTACHMENTS; index++)
		{
			if (prefab.GotoNextKey())
			{
				char parent_name[64], attachment_name[64], prop[64], model[64];
				prefab.GetString("parent", parent_name, sizeof parent_name, "drone");
				prefab.GetString("proptype", prop, sizeof prop, "prop_physics_override");
				prefab.GetString("model", model, sizeof model);
				prefab.GetString("attachment_point", attachment_name, "null");
				
				drone.attachments.damage_mod[index] = prefab.GetFloat("damage_mod", 1.0);
				drone.attachments.setHealth(index, prefab.GetFloat("health", 100.0));
				
				int attachment = CreateEntityByName(prop);
				if (attachment < MaxClients)
					continue;

				if (strlen(model) > 3)
					DispatchKeyValue(attachment, "model", model);

				DispatchSpawn(attachment);
				ActivateEntity(attachment);

				Component parent;
				GetParentEntity(parent_name, prefab, parent);

				if (!parent.valid()) //no parent found, use the drone itself
					parent = drone.hull;

				//SetParentAttachment requires a requestframe, so instead of setting up a DataPack we're just going to get the transform of the attachment
				DTransform transform;
				if (GetAttachmentTransform(parent.get(), attachment_name, transform)) //If attachment exists, parent to it
				{
					TeleportEntity(attachment, transform.pos, transform.rot, NULL_VECTOR);
					SetVariantString("!activator");
					AcceptEntityInput(attachment, "SetParent", attachment, parent.get());
				}

				ParentDrone[attachment] = drone;
				drone.attachments.set(attachment, index);
				SDKHook(attachment, SDKHook_OnTakeDamage, OnAttachmentDamaged);
				
				continue;
			}
			break;
		}
		
	}
	delete prefab;
}

Action OnAttachmentDamaged(int attachment, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon)
{
	Action action = DamageAttachment(attachment, ParentDrone[attachment], attacker, inflictor, damage, damagetype);
	return action;
}

Action DamageAttachment(int attachment, DroneProp drone, int attacker, int inflictor, float &damage, int damagetype)
{
	int index = GetAttachmentIndex(AttachmentName[attachment], drone);
	
	if (drone.attachments.destroyed[index])
		return Plugin_Stop;
	
	damage *= drone.attachments.damage_mod[index];
	drone.attachments.health[index] -= damage;
	
	if (drone.attachments.health[index] <= 0.0)
		DestroyAttachment(drone.attachments.get(index), index, drone);
		
	CD_DroneTakeDamage(drone.hull.get(), attacker, inflictor, damage, (damagetype & DMG_CRIT));
	
	return Plugin_Changed;
}

void DestroyAttachment(int attachment, int index, DroneProp drone)
{
	//TODO - create explosion... will probably just make a stock for this
	drone.attachments.destroyed[index] = true;
	
	AcceptEntityInput(attachment, "ClearParent");
	SetEntityKillTimer(attachment, 30.0);
}
