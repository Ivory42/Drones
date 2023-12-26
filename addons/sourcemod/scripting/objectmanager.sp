#include <objectmanager>

static SObjectMap EntityList;
static SObjectMap ClientList;
static ArrayList TickingEntities;

static GlobalForward OnObjectRegistered;
static GlobalForward OnObjectDestroyed;
static GlobalForward OnClientRegistered;
static GlobalForward OnClientRemoved;

static const char EmptyTemplateName[16] = "TEMPLATE_NONE";

public Plugin myinfo =
{
	name = "[TF2] Entity Manager",
	author = "IvoryPal",
	description = "Creates a global list of entities which can be accessed and altered by other plugins.",
	version = "1.0",
	url = "URL"
};


/**************************
 * 
 * 
 * INITIALIZERS
 * 
 * 
 **************************/

public void OnPluginStart()
{
	EntityList = new SObjectMap();
	TickingEntities = new ArrayList();
	ClientList = new SObjectMap();

	OnObjectRegistered = new GlobalForward("EntManager_OnEntityRegistered", ET_Ignore, Param_Any, Param_String);
	OnObjectDestroyed = new GlobalForward("EntManager_OnEntityDestroyed", ET_Ignore, Param_Any);
	OnClientRegistered = new GlobalForward("EntManager_OnClientRegistered", ET_Ignore, Param_Any);
	OnClientRemoved = new GlobalForward("EntManager_OnClientRemoved", ET_Ignore, Param_Any);

	RegAdminCmd("sm_entmanager_dumpentities", CmdDumpEnts, ADMFLAG_BAN);
}

public void OnClientPutInServer(int clientId)
{
	AClient client = new AClient(ConstructClient(clientId));
	RegisterClient(client);
}

public void OnClientDisconnect(int clientId)
{
	AClient client = GetClient(ConstructClient(clientId));
	if (client)
	{
		Call_StartForward(OnClientRemoved);
		Call_PushCell(client);
		Call_Finish();

		RemoveClient(client);

		delete client;
	}
	
}

Action CmdDumpEnts(int client, int args)
{
	char EntList[1024]; // Debug only, doesnt need to fit every entity

	if (ClientList)
	{
		FormatEx(EntList, sizeof EntList, "GLOBAL CLIENT LIST\n--------------------------------------------");
		StringMapSnapshot snapshot = ClientList.Snapshot();

		if (snapshot)
		{
			int length = snapshot.Length;
			ABaseEntity entity;
			char key[128];

			char entTotal[32], entString[32];
			FormatEx(entTotal, sizeof entTotal, "\nTotal clients: %d", length);
			StrCat(EntList, sizeof EntList, entTotal);

			if (length > 0)
			{
				for (int i = 0; i < length; i++)
				{
					snapshot.GetKey(i, key, sizeof key);

					if (ClientList.ContainsKey(key))
					{
						ClientList.GetValue(key, entity);

						FormatEx(entString, sizeof entString, "\nEntity: %d | Handle: %x", entity.Get(), entity);
						StrCat(EntList, sizeof EntList, entString);
					}
				}
			}

			PrintToConsole(client, EntList);
			delete snapshot;
		}
	}
	else
	{
		PrintToConsole(client, "Client list not initialized!");
	}

	if (EntityList)
	{
		FormatEx(EntList, sizeof EntList, "GLOBAL ENTITY LIST\n--------------------------------------------");
		StringMapSnapshot snapshot = EntityList.Snapshot();

		if (snapshot)
		{
			int length = snapshot.Length;
			ABaseEntity entity;
			char key[128];

			char entTotal[32], entString[32];
			FormatEx(entTotal, sizeof entTotal, "\nTotal Entities: %d", length);
			StrCat(EntList, sizeof EntList, entTotal);

			if (length > 0)
			{
				for (int i = 0; i < length; i++)
				{
					snapshot.GetKey(i, key, sizeof key);

					if (EntityList.ContainsKey(key))
					{
						EntityList.GetValue(key, entity);

						FormatEx(entString, sizeof entString, "\nEntity: %d | Handle: %x", entity.Get(), entity);
						StrCat(EntList, sizeof EntList, entString);
					}
				}
			}

			PrintToConsole(client, EntList);
			delete snapshot;
		}
	}
	else
	{
		PrintToConsole(client, "Entity list not initialized!");
	}

	if (TickingEntities)
	{
		FormatEx(EntList, sizeof EntList, "\nTICKING ENTITY LIST\n--------------------------------------------");

		int length = TickingEntities.Length;
		char entTotal[32], entString[32];
		FormatEx(entTotal, sizeof entTotal, "\nTotal Entities: %d", length);
		StrCat(EntList, sizeof EntList, entTotal);
		if (length > 0)
		{
			ABaseEntity entity;

			for (int i = 0; i < length; i++)
			{
				entity = view_as<ABaseEntity>(TickingEntities.Get(i));

				FormatEx(entString, sizeof entString, "\nEntity: %d | Handle: %x", entity.Get(), entity);
				StrCat(EntList, sizeof EntList, entString);
			}
		}

		PrintToConsole(client, EntList);
	}
	else
	{
		PrintToConsole(client, "Ticking list not initialized!");
	}

	return Plugin_Handled;
}

public void OnEntityDestroyed(int entity)
{
	if (IsValidEdict(entity))
	{
		ABaseEntity actor = GetEntity(ConstructObject(entity));
		if (actor)
		{
			if (actor.CanTick)
			{
				DisableEntityTick(actor);
			}

			Call_StartForward(OnObjectDestroyed);
			Call_PushCell(actor);
			Call_Finish();

			RemoveEntityFromList(actor);

			delete actor;
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("FEntityStatics.CreateEntity", EntNative_CreateEntity);
	CreateNative("FEntityStatics.CreateEntityFromTemplate", EntNative_CreateFromTemplate);
	CreateNative("FEntityStatics.FinishSpawningEntity", EntNative_FinishSpawn);
	CreateNative("FEntityStatics.RegisterEntity", EntNative_RegisterEntity);
	CreateNative("FEntityStatics.RegisterClient", EntNative_RegisterClient);
	CreateNative("FEntityStatics.GetEntity", EntNative_GetEntity);
	CreateNative("FEntityStatics.GetClient", EntNative_GetClient);
	CreateNative("FEntityStatics.DestroyEntity", EntNative_Destroy);
	CreateNative("FEntityStatics.EnableEntityTick", EntNative_EnableTick);
	CreateNative("FEntityStatics.DisableEntityTick", EntNative_DisableTick);
	CreateNative("FEntityStatics.IsValid", EntNative_Valid);
	CreateNative("FEntityStatics.GetConnectedClients", EntNative_GetClients);

	return APLRes_Success;
}

/**************************
 * 
 * 
 * NATIVE FUNCTIONS
 * 
 * 
 **************************/

any EntNative_CreateEntity(Handle plugin, int args)
{
	char classname[256];
	FObject owner;

	GetNativeString(1, classname, sizeof classname);
	GetNativeArray(2, owner, sizeof FObject);

	FObject entity;
	entity = FGameplayStatics.CreateObjectDeferred(classname);

	return CreateBaseEntity(entity, owner);
}

any EntNative_CreateFromTemplate(Handle plugin, int args)
{
	// WIP
	ABaseEntity entity = CreateTemplatedEntity(EmptyTemplateName);

	return entity;
}

any EntNative_FinishSpawn(Handle plugin, int args)
{
	ABaseEntity entity = view_as<ABaseEntity>(GetNativeCell(1));
	
	FTransform spawn;
	GetNativeArray(2, spawn, sizeof FTransform);

	FGameplayStatics.FinishSpawn(entity.GetObject(), spawn);

	RegisterEntity(entity);
	return 0;
}

any EntNative_RegisterEntity(Handle plugin, int args)
{
	FObject entity;
	GetNativeArray(1, entity, sizeof FObject);

	ABaseEntity actor = CreateBaseEntity(entity, ConstructObject(0));

	return RegisterEntity(actor);
}

any EntNative_RegisterClient(Handle plugin, int args)
{
	FClient clientRef;
	GetNativeArray(1, clientRef, sizeof FClient);

	AClient client = new AClient(clientRef);

	return RegisterClient(client);
}

any EntNative_GetEntity(Handle plugin, int args)
{
	FObject entity;
	GetNativeArray(1, entity, sizeof FObject);

	return GetEntity(entity);
}

any EntNative_GetClient(Handle plugin, int args)
{
	FClient clientRef;
	GetNativeArray(1, clientRef, sizeof FClient);

	return GetClient(clientRef);
}

any EntNative_Destroy(Handle plugin, int args)
{
	ABaseEntity actor = GetNativeCell(1);
	if (actor)
	{
		actor.GetObject().Kill();
	}

	return 0;
}

any EntNative_EnableTick(Handle plugin, int args)
{
	ABaseEntity entity = view_as<ABaseEntity>(GetNativeCell(1));
	Function callbackFunc = GetNativeFunction(2);
	float tickrate = GetNativeCell(3);

	FEntityProps props;
	props.TickFunction = callbackFunc;
	props.CallingPlugin = plugin;
	entity.SetCallbackProps(props);

	entity.TickRate = tickrate;

	// Do not hook unregistered entities
	if (!IsEntInList(entity))
	{
		FObjectStatics.RemoveObject(entity);
		return 0;
	}

	if (TickingEntities && !entity.CanTick)
		TickingEntities.Push(entity);

	entity.CanTick = true;

	return 0;
}

any EntNative_DisableTick(Handle plugin, int args)
{
	ABaseEntity entity = view_as<ABaseEntity>(GetNativeCell(1));
	
	DisableEntityTick(entity);

	return 0;
}

any EntNative_Valid(Handle plugin, int args)
{
	ABaseEntity entity = view_as<ABaseEntity>(GetNativeCell(1));

	if (entity)
	{
		return entity.Valid();
	}

	return false;
}

any EntNative_GetClients(Handle plugin, int args)
{
	ArrayList ConnectedClients = new ArrayList();
	if (ClientList)
	{
		StringMapSnapshot snapshot = ClientList.Snapshot();

		if (snapshot)
		{
			int length = snapshot.Length;

			if (length > 0)
			{
				AClient client;
				char key[128];

				for (int i = 0; i < length; i++)
				{
					snapshot.GetKey(i, key, sizeof key);

					if (ClientList.ContainsKey(key))
					{
						ClientList.GetValue(key, client);

						ConnectedClients.Push(client);
					}
				}
			}
			delete snapshot;
		}
	}

	return ConnectedClients;
}

/*
int Native_Test(Handle plugin, int args)
{
	int cell1 = GetNativeCell(1);
	PrintToChatAll("test: Cell 1 = %d", cell1);

	return 0;
}
*/

/**************************
 * 
 * 
 * ENTITY FUNCTIONS
 * 
 * 
 **************************/

void DisableEntityTick(ABaseEntity entity)
{
	if (TickingEntities)
	{
		int index = GetTickingEntityIndex(entity);
		if (index != -1)
		{
			TickingEntities.Erase(index);
		}
	}
	entity.CanTick = false;
}

ABaseEntity GetEntity(FObject entity)
{
	ABaseEntity actor = null;
	if (EntityList.HasKey(entity))
		actor = view_as<ABaseEntity>(EntityList.GetObject(entity));

	return actor;
}

AClient GetClient(FClient clientRef)
{
	AClient client = null;
	if (ClientList.HasKey(clientRef.GetObject()))
		client = view_as<AClient>(ClientList.GetObject(clientRef.GetObject()));

	return client;
}

ABaseEntity RegisterEntity(ABaseEntity entity)
{
	char template[64];
	entity.GetEntityTemplate(template, sizeof template);

	if (EntityList)
	{
		if (!IsEntInList(entity))
			EntityList.SetObjectValue(entity.GetObject(), entity);

		Call_StartForward(OnObjectRegistered);
		Call_PushCell(entity);
		Call_PushString(template);
		Call_Finish();

		return entity;
	}

	// Entity is already registered, remove this extra handle
	delete entity;
	return null;
}

void RegisterClient(AClient client)
{
	if (ClientList)
	{
		// Only set the value if this client is not yet registered
		if (!IsClientInList(client))
			ClientList.SetObjectValue(client.GetObject(), client);

		Call_StartForward(OnClientRegistered);
		Call_PushCell(client);
		Call_Finish();
	}
}

ABaseEntity CreateBaseEntity(FObject base, FObject owner = {})
{
	char template[16];
	FormatEx(template, sizeof template, EmptyTemplateName);
	ABaseEntity entity = new ABaseEntity(base, template);
	entity.SetOwner(owner);

	return entity;
}

ABaseEntity CreateTemplatedEntity(const char[] template)
{
	if (StrEqual(template, EmptyTemplateName))
	{
		return null; // Cannot create an entity with an invalid template
	}

	// WIP
	return null;
}

public void OnGameFrame()
{
	if (TickingEntities)
	{
		int length = TickingEntities.Length;
		ABaseEntity entity;

		if (length < 1)
			return;

		for (int i = 0; i < length; i++)
		{
			// not sure how this is happening but it keeps erroring
			if (i >= length)
				continue;

			entity = view_as<ABaseEntity>(TickingEntities.Get(i));
			if (entity.NextTickTime <= GetGameTime() && IsEntInList(entity))
			{
				entity.NextTickTime = GetGameTime() + entity.TickRate;

				FEntityProps props;
				props = entity.GetCallbackProps();

				if (props.CallingPlugin)
				{
					Call_StartFunction(props.CallingPlugin, props.TickFunction);
					Call_PushCell(entity);

					Call_Finish();
				}
			}
		}
	}
}

/**************************
 * 
 * 
 * HELPER FUNCTIONS
 * 
 * 
 **************************/

bool IsEntInList(ABaseEntity entity)
{
	if (EntityList)
	{
		return EntityList.HasKey(entity.GetObject());
	}

	return false;
}

bool IsClientInList(AClient client)
{
	if (ClientList)
	{
		return ClientList.HasKey(client.GetObject());
	}

	return false;
}

int GetTickingEntityIndex(ABaseEntity entity)
{
	if (TickingEntities)
	{
		int length = TickingEntities.Length;

		for (int i = 0; i < length; i++)
		{
			ABaseEntity test = view_as<ABaseEntity>(TickingEntities.Get(i));

			if (test == entity)
				return i;
		}
	}

	return -1;
}

void RemoveEntityFromList(ABaseEntity entity)
{
	if (EntityList)
	{
		if (EntityList.HasKey(entity.GetObject()))
		{
			EntityList.RemoveObjectValue(entity.GetObject());
		}
	}

	if (TickingEntities)
	{
		int index = GetTickingEntityIndex(entity);
		if (index != -1)
		{
			entity.CanTick = false;
			TickingEntities.Erase(index);
		}
	}
}

void RemoveClient(AClient client)
{
	if (ClientList)
	{
		if (ClientList.HasKey(client.GetObject()))
		{
			ClientList.RemoveObjectValue(client.GetObject());
		}
	}
}
