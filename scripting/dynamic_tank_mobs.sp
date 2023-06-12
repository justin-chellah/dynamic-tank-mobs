#include <sourcemod>

#define REQUIRE_EXTENSIONS
#include <dhooks>
#include <sourcescramble>

#define GAMEDATA_FILE	"dynamic_tank_mobs"

Address g_addrTheDirector = Address_Null;

int g_nOffset_CDirector_m_mobSpawnTimer = -1;
int g_nOffset_CDirector_m_flMobSpawnSize = -1;
int g_nOffset_CDirector_m_iTankCount = -1;

ConVar z_tank_mob_spawn_min_size = null;
ConVar z_tank_mob_spawn_max_size = null;
ConVar z_tank_mob_spawn_min_interval = null;
ConVar z_tank_mob_spawn_max_interval = null;
ConVar z_tank_mob_bile_spawn_size = null;

int CalcMobSize()
{
	return GetRandomInt( z_tank_mob_spawn_min_size.IntValue, z_tank_mob_spawn_max_size.IntValue );
}

void SpawnMob()
{
	int nMobSize = CalcMobSize();
	StoreToAddress( g_addrTheDirector + view_as< Address >( g_nOffset_CDirector_m_flMobSpawnSize ), float( nMobSize ), NumberType_Int32 );

	float flInterval = GetRandomFloat( z_tank_mob_spawn_min_interval.FloatValue, z_tank_mob_spawn_max_interval.FloatValue );
	StoreToAddress( g_addrTheDirector + view_as< Address >( g_nOffset_CDirector_m_mobSpawnTimer + 4 ), flInterval, NumberType_Int32 );
	StoreToAddress( g_addrTheDirector + view_as< Address >( g_nOffset_CDirector_m_mobSpawnTimer + 8 ), GetGameTime() + flInterval, NumberType_Int32 );
}

bool CDirector_IsTankInPlay()
{
	return LoadFromAddress( g_addrTheDirector + view_as< Address >( g_nOffset_CDirector_m_iTankCount ), NumberType_Int32 );
}

public void Event_tank_spawn( Event hEvent, const char[] szName, bool bDontBroadcast )
{
	if ( CDirector_IsTankInPlay() )
	{
		return;
	}

	SpawnMob();
}

public MRESReturn DDetour_CDirector_GetScriptValueFloat( Address addrTheDirector, DHookReturn hReturn, DHookParam hParams )
{
	if ( CDirector_IsTankInPlay() )
	{
		char szKey[32];
		hParams.GetString( 1, szKey, sizeof( szKey ) );

		int nMobSize = CalcMobSize();

		if ( StrEqual( szKey, "MobMinSize" ) )
		{
			hParams.Set( 2, float( nMobSize ) );

			return MRES_ChangedHandled;
		}

		if ( StrEqual( szKey, "MobSpawnMinTime" ) )
		{
			hParams.Set( 2, z_tank_mob_spawn_min_interval.FloatValue );

			return MRES_ChangedHandled;
		}

		if ( StrEqual( szKey, "MobSpawnMaxTime" ) )
		{
			hParams.Set( 2, z_tank_mob_spawn_max_interval.FloatValue );

			return MRES_ChangedHandled;
		}
	}

	return MRES_Ignored;
}

public MRESReturn DDetour_CDirector_GetScriptValueInt( Address addrTheDirector, DHookReturn hReturn, DHookParam hParams )
{
	char szKey[32];
	hParams.GetString( 1, szKey, sizeof( szKey ) );

	if ( StrEqual( szKey, "ShouldAllowMobsWithTank" ) )
	{
		hParams.Set( 2, true );

		return MRES_ChangedHandled;
	}

	if ( CDirector_IsTankInPlay() )
	{
		if ( StrEqual( szKey, "BileMobSize" ) )
		{			
			hParams.Set( 2, z_tank_mob_bile_spawn_size.IntValue );

			return MRES_ChangedHandled;
		}
	}

	return MRES_Ignored;
}

public void OnPluginStart()
{
	GameData hGameData = new GameData( GAMEDATA_FILE );

	if ( hGameData == null )
	{
		SetFailState( "Unable to load gamedata file \"" ... GAMEDATA_FILE ... "\"" );
	}

#define MEMORY_PATCH_WRAPPER(%0,%1)\
	%1 = MemoryPatch.CreateFromConf( hGameData, %0 );\
	\
	if ( !%1.Validate() )\
	{\
		delete hGameData;\
		\
		SetFailState( "Unable to validate patch for \"" ... %0 ... "\"" );\
	}

	MemoryPatch hSpawnMobConditionPatcher;
	MEMORY_PATCH_WRAPPER( "Spawn mob condition", hSpawnMobConditionPatcher )

	MemoryPatch hBileMobSizeConditionPatcher;
	MEMORY_PATCH_WRAPPER( "BileMobSize condition", hBileMobSizeConditionPatcher )

	hSpawnMobConditionPatcher.Enable();
	hBileMobSizeConditionPatcher.Enable();

	g_addrTheDirector = hGameData.GetAddress( "CDirector" );

	if ( g_addrTheDirector == Address_Null )
	{
		delete hGameData;

		SetFailState( "Unable to find address entry or address in binary for \"CDirector\"" );
	}

#define GET_OFFSET_WRAPPER(%0,%1)\
	%1 = hGameData.GetOffset( %0 );\
	\
	if ( %1 == -1 )\
	{\
		delete hGameData;\
		\
		SetFailState( "Unable to find gamedata offset entry for \"" ... %0 ... "\"" );\
	}

	GET_OFFSET_WRAPPER( "CDirector::m_mobSpawnTimer", g_nOffset_CDirector_m_mobSpawnTimer )
	GET_OFFSET_WRAPPER( "CDirector::m_flMobSpawnSize", g_nOffset_CDirector_m_flMobSpawnSize )
	GET_OFFSET_WRAPPER( "CDirector::m_iTankCount", g_nOffset_CDirector_m_iTankCount )

	DynamicDetour hDDetour_CDirector_GetScriptValueInt = new DynamicDetour( Address_Null, CallConv_THISCALL, ReturnType_Int, ThisPointer_Address );

	if ( !hDDetour_CDirector_GetScriptValueInt.SetFromConf( hGameData, SDKConf_Signature, "CDirector::GetScriptValueInt" ) )
	{
		delete hGameData;

		SetFailState( "Unable to find gamedata signature entry for \"CDirector::GetScriptValueInt\"" );
	}

	hDDetour_CDirector_GetScriptValueInt.AddParam( HookParamType_CharPtr );		// szKey
	hDDetour_CDirector_GetScriptValueInt.AddParam( HookParamType_Int );			// nDefaultValue
	hDDetour_CDirector_GetScriptValueInt.Enable( Hook_Pre, DDetour_CDirector_GetScriptValueInt );

	DynamicDetour hDDetour_CDirector_GetScriptValueFloat = new DynamicDetour( Address_Null, CallConv_THISCALL, ReturnType_Float, ThisPointer_Address );

	if ( !hDDetour_CDirector_GetScriptValueFloat.SetFromConf( hGameData, SDKConf_Signature, "CDirector::GetScriptValueFloat" ) )
	{
		delete hGameData;

		SetFailState( "Unable to find gamedata signature entry for \"CDirector::GetScriptValueFloat\"" );
	}

	delete hGameData;

	hDDetour_CDirector_GetScriptValueFloat.AddParam( HookParamType_CharPtr );		// szKey
	hDDetour_CDirector_GetScriptValueFloat.AddParam( HookParamType_Float );			// flDefaultValue
	hDDetour_CDirector_GetScriptValueFloat.Enable( Hook_Pre, DDetour_CDirector_GetScriptValueFloat );

	z_tank_mob_spawn_min_size = CreateConVar( "z_tank_mob_spawn_min_size", "5" );
	z_tank_mob_spawn_max_size = CreateConVar( "z_tank_mob_spawn_max_size", "10" );
	z_tank_mob_spawn_min_interval = CreateConVar( "z_tank_mob_spawn_min_interval", "10.0" );
	z_tank_mob_spawn_max_interval = CreateConVar( "z_tank_mob_spawn_max_interval", "20.0" );
	z_tank_mob_bile_spawn_size = CreateConVar( "z_tank_mob_bile_spawn_size", "15" );

	HookEvent( "tank_spawn", Event_tank_spawn, EventHookMode_PostNoCopy );
}

public Plugin myinfo =
{
	name = "[L4D/2] Dynamic Tank Mobs",
	author = "Justin \"Sir Jay\" Chellah",
	description = "Spawns small mobs through the AI Director in time intervals to assist the Tank against the survivors",
	version = "1.1.0",
	url = "https://justin-chellah.com"
};