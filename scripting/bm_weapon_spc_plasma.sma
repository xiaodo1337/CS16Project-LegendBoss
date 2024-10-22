#include <amxmodx>
#include <engine>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <bossmode>

#define PLUGIN "PlasmaGun"
#define VERSION "1.0"
#define AUTHOR "xiaodo"

#pragma tabsize 4

new m_flNextPrimaryAttack = 46
new m_flTimeWeaponIdle = 48 // float
new m_iClip = 51
new m_fInReload = 54
new m_flNextAttack = 83
// CWeaponBox
new m_rgpPlayerItems2[6] = { 34, 35, 36, 37, 38, 39 } // CBasePlayerItem *

// ================= Config =================

// Level 1 Config
#define V_MODEL "models/v_plasmagun2.mdl"
#define P_MODEL "models/p_plasmagun.mdl"
#define W_MODEL "models/w_plasmagun.mdl"

new const WeaponSounds[7][] =
{
	"weapons/plasmagun-1.wav",
	"weapons/plasmagun_exp.wav",
	"weapons/plasmagun_idle.wav",
	"weapons/plasmagun_draw.wav",
	"weapons/plasmagun_clipin1.wav",
	"weapons/plasmagun_clipin2.wav",
	"weapons/plasmagun_clipout.wav"
}

new const WeaponFiles[2][] =
{
	"sprites/plasmaball.spr",
	"sprites/plasmabomb.spr"
}

new const MuzzleFlash[] = "sprites/muzzleflash27.spr"

// Level 2 Config
#define DAMAGE 3500
#define CLIP 9
#define BPAMMO 200
#define SPEED 9.0
#define RECOIL 0.75

#define PLASMA_SPEED 1600.0
#define PLASMA_RADIUS 130.0

// Level 3 Config
#define CSW_PLASMA CSW_AK47
#define weapon_plasma "weapon_ak47"

#define WEAPON_EVENT "events/ak47.sc"
#define WEAPON_ANIMEXT "carbine"
#define WEAPON_OLD_WMODEL "models/w_ak47.mdl"
#define WEAPON_SECRETCODE 194612

#define WEAPONANIM_SHOOT random_num(3, 5)
#define WEAPONANIM_RELOAD 1

#define WEAPONTIME_DRAW 0.75
#define WEAPONTIME_RELOAD 3.5

// Level 4 Config
#define PLASMABALL_CLASSNAME "plasmaball"
// ============== End of Config ==============

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

enum
{
	TEAM_T = 1,
	TEAM_CT
}

// Vars
new g_Had_Plasma, g_WeaponClip[33], Float:g_WeaponRecoil[33][3]
new g_Msg_CurWeapon, g_Msg_AmmoX
new g_MuzzleFlash_SprId, g_PlasmaExp_SprId, g_weapon_event, g_HamBot, g_itemid

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")		
	
	register_think(PLASMABALL_CLASSNAME, "fw_Think_Plasma")
	register_touch(PLASMABALL_CLASSNAME, "*", "fw_Touch_Plasma")
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_plasma, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_plasma, "fw_Weapon_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Item_Deploy, weapon_plasma, "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_plasma, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_plasma, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_plasma, "fw_Weapon_Reload_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, weapon_plasma, "fw_Item_AddToPlayer_Post", 1)

	g_Msg_CurWeapon = get_user_msgid("CurWeapon")
	g_Msg_AmmoX = get_user_msgid("AmmoX")
	
	register_clcmd("admin_get_plasmagun", "Get_Plasma", ADMIN_KICK)
	register_clcmd("weapon_plasmagun", "Hook_WeaponHud")
	g_itemid = bm_weapon_register("神器-幽畫離子槍", "plasmagun", TYPE_SPECIAL, 0, 3000, 1, CSW_PLASMA, "")
}

public bm_weapon_bought(id, itemid)
{
    if (itemid == g_itemid)
    {
        Get_Plasma(id)
    }
}

public bm_weapon_remove(id)
{
	Remove_Plasma(id)
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	
	new i
	for(i = 0; i < sizeof(WeaponSounds); i++)
		engfunc(EngFunc_PrecacheSound, WeaponSounds[i])
	for(i = 0; i < sizeof(WeaponFiles); i++)
	{
		if(i == 1) g_PlasmaExp_SprId = engfunc(EngFunc_PrecacheModel, WeaponFiles[i])
		else engfunc(EngFunc_PrecacheModel, WeaponFiles[i])
	}
		
	g_MuzzleFlash_SprId = engfunc(EngFunc_PrecacheModel, MuzzleFlash)
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(WEAPON_EVENT, name)) g_weapon_event = get_orig_retval()		
}

public client_putinserver(id)
{
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_RegisterHam", id)
	}
}

public Do_RegisterHam(id)
{
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Player")	
}

public Get_Plasma(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_Had_Plasma, id)
	fm_give_item(id, weapon_plasma)
	
	// Set Weapon
	engclient_cmd(id, weapon_plasma)
	
	replace_weapon_models(id)
	
	set_pdata_string(id, (492) * 4, WEAPON_ANIMEXT, -1 , 20)	
	
	// Set Weapon Base
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_PLASMA)
	if(!is_valid_ent(Ent)) return
	
	cs_set_weapon_ammo(Ent, CLIP)
	cs_set_user_bpammo(id, CSW_PLASMA, BPAMMO)
	
	Update_AmmoHud(id, CSW_PLASMA, CLIP, BPAMMO)
}

public Remove_Plasma(id)
{
	UnSet_BitVar(g_Had_Plasma, id)
}

public Hook_WeaponHud(id)
{
	engclient_cmd(id, weapon_plasma)
	return PLUGIN_HANDLED
}

public Event_NewRound()
{
	remove_entity_name(PLASMABALL_CLASSNAME)
}

public fw_Think_Plasma(Ent)
{
	if(!is_valid_ent(Ent))
		return
		
	static Float:RenderAmt; RenderAmt = entity_get_float(Ent, EV_FL_renderamt)
	
	RenderAmt += 50.0
	RenderAmt = float(clamp(floatround(RenderAmt), 0, 255))
	
	entity_set_float(Ent, EV_FL_renderamt, RenderAmt)
	entity_set_float(Ent, EV_FL_nextthink, get_gametime() + 0.1)
}

public fw_Touch_Plasma(Ent, Id)
{
	if(!is_valid_ent(Ent))
		return
	if(entity_get_int(Ent, EV_INT_movetype) == MOVETYPE_NONE)
		return
		
	// Exp Sprite
	static Float:Origin[3], TE_FLAG
	entity_get_vector(Ent, EV_VEC_origin, Origin)
	
	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_PlasmaExp_SprId)
	write_byte(7)
	write_byte(30)
	write_byte(TE_FLAG)
	message_end()	
	
	// Exp Sound
	emit_sound(Ent, CHAN_BODY, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Damage
	Damage_Plasma(Ent, Id)
	
	// Remove Ent
	entity_set_int(Ent, EV_INT_movetype, MOVETYPE_NONE)
	set_task(0.1, "Remove_PlasmaBall", Ent)
}

public Damage_Plasma(Ent, Id)
{
	static Owner; Owner = entity_get_int(Ent, EV_INT_iuser1)
	static Attacker; 
	if(!is_user_alive(Owner)) 
	{
		Attacker = 0
		return
	} else Attacker = Owner
	
	if(is_user_alive(Id) && cs_get_user_team(Id) != Get_PlasmaTeam(Ent))
		ExecuteHamB(Ham_TakeDamage, Id, 0, Attacker, float(DAMAGE), DMG_ACID)
	
	for(new i = 0; i < get_maxplayers(); i++)
	{
		if(!is_user_alive(i) || fm_get_user_godmode(i))
			continue
		if(entity_range(i, Ent) > PLASMA_RADIUS)
			continue
		if(cs_get_user_team(i) == Get_PlasmaTeam(Ent))
			continue
			
        if (bm_get_mode() != 2) ExecuteHamB(Ham_TakeDamage, i, 0, Attacker, float(DAMAGE), DMG_ACID)
        else ExecuteHamB(Ham_TakeDamage, i, 0, Attacker, float(DAMAGE) * 2.0, DMG_ACID)
        
	    if (random_num(1, 10) >= 5)
	    {
	    	static Float:MyOrigin[3]
			entity_get_vector(Id, EV_VEC_origin, MyOrigin)
	    	hook_ent2(i, MyOrigin, 20.0, 2)
	    }
	}
}

public Remove_PlasmaBall(Ent)
{
	if(!is_valid_ent(Ent)) return
	engfunc(EngFunc_RemoveEntity, Ent)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(get_user_weapon(id) == CSW_PLASMA && Get_BitVar(g_Had_Plasma, id) && is_user_alive(id) && is_user_connected(id))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_PLASMA || !Get_BitVar(g_Had_Plasma, invoker))
		return FMRES_IGNORED
	if(eventid != g_weapon_event)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	
	return FMRES_SUPERCEDE
}

public fw_SetModel(entity, model[])
{
	if(!is_valid_ent(entity))
		return FMRES_IGNORED
	
	static Classname[32]
	entity_get_string(entity, EV_SZ_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	
	if(equal(model, WEAPON_OLD_WMODEL))
	{
		static weapon; weapon = get_pdata_cbase(entity, m_rgpPlayerItems2[1], 4)
		
		if(!is_valid_ent(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Plasma, iOwner))
		{
			Remove_Plasma(iOwner)
			
			entity_set_int(weapon, EV_INT_impulse, WEAPON_SECRETCODE)
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_PLASMA || !Get_BitVar(g_Had_Plasma, Attacker))
		return HAM_IGNORED
	
	return HAM_SUPERCEDE
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_PLASMA || !Get_BitVar(g_Had_Plasma, Attacker))
		return HAM_IGNORED
		
	return HAM_SUPERCEDE
}

public fw_Weapon_PrimaryAttack(Ent)
{
	if(!is_valid_ent(Ent))
		return
		
	static Id; Id = entity_get_edict(Ent, EV_ENT_owner)
	if(!Get_BitVar(g_Had_Plasma, Id))
		return
	static Ammo; Ammo = cs_get_weapon_ammo(Ent)
	if(Ammo <= 0) return

	// Weapon Shoot
	Set_Weapon_Anim(Id, WEAPONANIM_SHOOT)
	emit_sound(Id, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// MuzzleFlash & Effect
	Make_Muzzleflash(Id)
	
	// Create Plasma Effect
	Create_PlasmaBall(Id)
	
	// Speed & Recoil
	entity_get_vector(Id, EV_VEC_punchangle, g_WeaponRecoil[Id])
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	if(!is_valid_ent(Ent))
		return
		
	static Id; Id = entity_get_edict(Ent, EV_ENT_owner)
	if(!Get_BitVar(g_Had_Plasma, Id))
		return
	static Ammo; Ammo = cs_get_weapon_ammo(Ent)
	if(Ammo <= 0) return
	
	// Speed & Recoil
	set_pdata_float(Ent, m_flNextPrimaryAttack, get_pdata_float(Ent, m_flNextPrimaryAttack, 4) * SPEED, 4)
	
	static Float:Push[3]; entity_get_vector(Id, EV_VEC_punchangle, Push)
	
	xs_vec_sub(Push, g_WeaponRecoil[Id], Push)
	xs_vec_mul_scalar(Push, RECOIL, Push)
	xs_vec_add(Push,  g_WeaponRecoil[Id], Push)

	entity_set_vector(Id, EV_VEC_punchangle, Push)
}

public fw_Item_Deploy_Post(Ent)
{
	if(!is_valid_ent(Ent))
		return
		
	static Id; Id = entity_get_edict(Ent, EV_ENT_owner)
	if(!Get_BitVar(g_Had_Plasma, Id))
		return
		
	replace_weapon_models(Id)
	
	set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXT, -1 , 20)
	
	// Set Draw
	Set_Player_NextAttack(Id, WEAPONTIME_DRAW)
	Set_Weapon_TimeIdle(Id, CSW_PLASMA, WEAPONTIME_DRAW)
}

public fw_Item_PostFrame(Ent)
{
	if(!is_valid_ent(Ent))
		return
		
	static Id; Id = entity_get_edict(Ent, EV_ENT_owner)
	if(!Get_BitVar(g_Had_Plasma, Id))
		return
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(Id, m_flNextAttack, 5)
	static bpammo; bpammo = cs_get_user_bpammo(Id, CSW_PLASMA)
	static iClip; iClip = get_pdata_int(Ent, m_iClip, 4)

	if(get_pdata_int(Ent, m_fInReload, 4) && flNextAttack <= 0.0)
	{
		static temp1; temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(Ent, m_iClip, iClip + temp1, 4)
		cs_set_user_bpammo(Id, CSW_PLASMA, bpammo - temp1)		
		
		set_pdata_int(Ent, m_fInReload, 0, 4)
	}		
}

public fw_Weapon_Reload(Ent)
{
	if(!is_valid_ent(Ent))
		return HAM_IGNORED
		
	static Id; Id = entity_get_edict(Ent, EV_ENT_owner)
	if(!Get_BitVar(g_Had_Plasma, Id))
		return HAM_IGNORED
		
	g_WeaponClip[Id] = -1
	
	static bpammo; bpammo = cs_get_user_bpammo(Id, CSW_PLASMA)
	static iClip; iClip = get_pdata_int(Ent, m_iClip, 4)
	
	if(bpammo <= 0) return HAM_SUPERCEDE
	if(iClip >= CLIP) return HAM_SUPERCEDE
		
	g_WeaponClip[Id] = iClip
	return HAM_IGNORED
}

public fw_Weapon_Reload_Post(Ent)
{
	if(!is_valid_ent(Ent))
		return
		
	static Id; Id = entity_get_edict(Ent, EV_ENT_owner)
	if(!Get_BitVar(g_Had_Plasma, Id))
		return
	if(g_WeaponClip[Id] == -1)
		return
	
	set_pdata_int(Ent, m_iClip, g_WeaponClip[Id], 4)
	set_pdata_int(Ent, m_fInReload, 1, 4)
	
	Set_Weapon_Anim(Id, WEAPONANIM_RELOAD)
	set_pdata_float(Id, m_flNextAttack, WEAPONTIME_RELOAD, 5)
}

public fw_Item_AddToPlayer_Post(Ent, Id)
{
	if(!is_valid_ent(Ent))
		return
		
	if(entity_get_int(Ent, EV_INT_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_Plasma, Id)
		entity_set_int(Ent, EV_INT_impulse, 0)
		
		set_task(0.0, "AddToPlayer_Delay", Id)
	}	
	
	return
}

public AddToPlayer_Delay(Id)
{
	replace_weapon_models(Id)
	
	set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXT, -1 , 20)	
}
		
public Create_PlasmaBall(id)
{
	static Float:StartOrigin[3], Float:TargetOrigin[3], Float:MyVelocity[3], Float:VecLength
	
	get_position(id, 48.0, 10.0, -5.0, StartOrigin)
	get_position(id, 1024.0, 0.0, 0.0, TargetOrigin)
	
	entity_get_vector(id, EV_VEC_velocity, MyVelocity)
	VecLength = vector_length(MyVelocity)
	
	if(VecLength) 
	{
		TargetOrigin[0] += random_float(-16.0, 16.0); TargetOrigin[1] += random_float(-16.0, 16.0); TargetOrigin[2] += random_float(-16.0, 16.0)
	} else {
		TargetOrigin[0] += random_float(-8.0, 8.0); TargetOrigin[1] += random_float(-8.0, 8.0); TargetOrigin[2] += random_float(-8.0, 8.0)
	}
	
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
	if(!is_valid_ent(Ent)) return
	
	// Set info for ent
	entity_set_int(Ent, EV_INT_movetype, MOVETYPE_FLY)
	entity_set_int(Ent, EV_INT_rendermode, kRenderTransAdd)
	entity_set_float(Ent, EV_FL_renderamt, 10.0)
	entity_set_int(Ent, EV_INT_iuser1, id)
	entity_set_int(Ent, EV_INT_iuser2, Get_SpecialTeam(id, cs_get_user_team(id)))
	entity_set_float(Ent, EV_FL_fuser1, get_gametime() + 3.0)
	entity_set_float(Ent, EV_FL_scale, random_float(0.1, 0.25))
	entity_set_float(Ent, EV_FL_nextthink, get_gametime() + 0.1)
	
	entity_set_string(Ent, EV_SZ_classname, PLASMABALL_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, WeaponFiles[0])
	entity_set_size(Ent, Float:{-1.0, -1.0, -1.0}, Float:{1.0, 1.0, 1.0})
	entity_set_vector(Ent, EV_VEC_origin, StartOrigin)
	entity_set_float(Ent, EV_FL_gravity, 0.01)
	entity_set_int(Ent, EV_INT_solid, SOLID_TRIGGER)
	entity_set_float(Ent, EV_FL_frame, 0.0)
	
	static Float:Velocity[3]
	get_speed_vector(StartOrigin, TargetOrigin, PLASMA_SPEED, Velocity)
	entity_set_vector(Ent, EV_VEC_velocity, Velocity)
}

public Make_Muzzleflash(id)
{
	static Float:Origin[3], TE_FLAG
	get_position(id, 32.0, 6.0, -15.0, Origin)
	
	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, Origin, id)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_MuzzleFlash_SprId)
	write_byte(2)
	write_byte(30)
	write_byte(TE_FLAG)
	message_end()
}

public Update_AmmoHud(id, CSWID, Ammo, BpAmmo)
{
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_CurWeapon, _, id)
	write_byte(1)
	write_byte(CSWID)
	write_byte(Ammo)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_AmmoX, _, id)
	write_byte(10)
	write_byte(BpAmmo)
	message_end()
}

public Get_SpecialTeam(Ent, CsTeams:Team)
{
	if(Team == CS_TEAM_T) return TEAM_T
	else if(Team == CS_TEAM_CT) return TEAM_CT
	
	return 0
}

public CsTeams:Get_PlasmaTeam(Ent)
{
	new iuser2 = entity_get_int(Ent, EV_INT_iuser2)
	if(iuser2 == TEAM_T) return CS_TEAM_T
	else if(iuser2 == TEAM_CT) return CS_TEAM_CT
	
	return CS_TEAM_UNASSIGNED
}

public replace_weapon_models(id)
{
	entity_set_string(id, EV_SZ_viewmodel, V_MODEL)
	entity_set_string(id, EV_SZ_weaponmodel, P_MODEL)
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	static Float:num; num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}

stock Set_Weapon_TimeIdle(id, WeaponId, Float:TimeIdle)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, WeaponId)
	if(!is_valid_ent(Ent)) return
		
	set_pdata_float(Ent, m_flNextPrimaryAttack, TimeIdle, 4)
	set_pdata_float(Ent, 47, TimeIdle, 4)
	set_pdata_float(Ent, m_flTimeWeaponIdle, TimeIdle + 0.5, 4)
}

stock Set_Player_NextAttack(id, Float:nexttime)
{
	set_pdata_float(id, m_flNextAttack, nexttime, 5)
}

stock Set_Weapon_Anim(id, anim)
{
	entity_set_int(id, EV_INT_weaponanim, anim)
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(entity_get_int(id, EV_INT_body))
	message_end()
}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	entity_get_vector(id, EV_VEC_origin, vOrigin)
	entity_get_vector(id, EV_VEC_view_ofs, vUp)
	xs_vec_add(vOrigin, vUp, vOrigin)
	entity_get_vector(id, EV_VEC_v_angle, vAngle)
	
	angle_vector(vAngle, ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle, ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle, ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock hook_ent2(ent, Float:VicOrigin[3], Float:speed, type)
{
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f
	entity_get_vector(ent, EV_VEC_origin, EntOrigin)
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	new Float:fl_Time = distance_f /speed
	if (type == 1)
	{
		fl_Velocity[0] = ((VicOrigin[0] - EntOrigin[0]) / fl_Time * 1.5)
		fl_Velocity[1] = ((VicOrigin[1] - EntOrigin[1]) / fl_Time * 1.5)
		fl_Velocity[2] = (EntOrigin[2] - VicOrigin[2]) / fl_Time
	}
	else
	{
		if (type == 2)
		{
		    fl_Velocity[0] = ((EntOrigin[0] - VicOrigin[0]) / fl_Time * 1.5)
		    fl_Velocity[1] = ((EntOrigin[1] - VicOrigin[1]) / fl_Time * 1.5)
		    fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time
		}
	}
	entity_set_vector(ent, EV_VEC_velocity, fl_Velocity)
}