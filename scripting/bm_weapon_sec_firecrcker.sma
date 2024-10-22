#include <amxmodx>
#include <engine>
#include <xs>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <bossmode>

#pragma tabsize 4

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_DRAW
}

#define CSW_WEAPON CSW_DEAGLE
#define WEAPON_NAME "weapon_deagle"
#define WEAPON_KEY 61721
#define GRENADE_CLASSNAME "grenade2"

#define AMMO 180
#define DAMAGE 2500.0
#define GRENADE_RANGE 200.0

new m_flNextPrimaryAttack = 46
new m_flNextSecondaryAttack = 47
new m_flTimeWeaponIdle = 48
new m_flNextAttack = 83
// CWeaponBox
new m_rgpPlayerItems2[6] = { 34, 35, 36, 37, 38, 39 } // CBasePlayerItem *

new WeaponSounds[8][] =
{
    "weapons/firecracker-1.wav",
    "weapons/firecracker-2.wav",
    "weapons/firecracker_draw.wav",
    "weapons/firecracker_bounce1.wav",
    "weapons/firecracker_bounce2.wav",
    "weapons/firecracker_bounce3.wav",
    "weapons/firecracker-wick.wav",
    "weapons/firecracker_explode.wav"
}
new WeaponResources[3][] =
{
	"sprites/spark1.spr",
    "sprites/muzzleflash18.spr",
	"sprites/mooncake.spr"
}
new g_Had_Firecracker[33], g_SpecialShoot[33], g_Old_Weapon[33], Float:g_LastShoot[33], g_Exp_SprId, g_Exp2_SprId, g_MF_SprId, g_Trail_SprId, g_itemid

public plugin_init()
{
	register_plugin("CSO Shooting Star", "1.0", "xiaodo")

	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")

	register_think(GRENADE_CLASSNAME, "fw_Grenade_Think")
	register_touch(GRENADE_CLASSNAME, "*", "fw_Grenade_Touch")
    
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_NAME, "fw_AddToPlayer")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_NAME, "fw_Item_PrimaryAttack")
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "fw_Weapon_Reload")

	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
    
	g_itemid = bm_weapon_register("星鑽彩砲", "", TYPE_PISTOL, 0, 0, 300, CSW_WEAPON, "")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, "models/legend/v_firecracker.mdl")
	engfunc(EngFunc_PrecacheModel, "models/legend/p_firecracker.mdl")
	engfunc(EngFunc_PrecacheModel, "models/legend/w_firecracker.mdl")
	engfunc(EngFunc_PrecacheModel, "models/legend/shell_firecracker.mdl")
	
    new i;
	for (i = 0;i < sizeof WeaponSounds;i++)
	{
		engfunc(EngFunc_PrecacheSound, WeaponSounds[i])
	}
	
	g_Exp2_SprId = engfunc(EngFunc_PrecacheModel, WeaponResources[0])
	g_MF_SprId = engfunc(EngFunc_PrecacheModel, WeaponResources[1])
	g_Exp_SprId = engfunc(EngFunc_PrecacheModel, WeaponResources[2])
	g_Trail_SprId = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
}

public bm_weapon_remove(id)
{
	g_Had_Firecracker[id] = 0
	g_SpecialShoot[id] = 0
}

public bm_weapon_bought(id, itemid)
{
    if (itemid == g_itemid)
    {
        weapon_buy(id)
    }
}

public weapon_buy(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
    drop_weapons(id, 2)

	g_Had_Firecracker[id] = 1
	g_SpecialShoot[id] = 0
	static Ent;
	Ent = fm_give_item(id, WEAPON_NAME)
	if (is_valid_ent(Ent))
	{
		cs_set_weapon_ammo(Ent, 0)
	}
	cs_set_user_bpammo(id, CSW_WEAPON, 5)

	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
	write_byte(1)
	write_byte(5)
	message_end()

	return PLUGIN_CONTINUE
}

public Remove_Firecracker(id)
{
	g_Had_Firecracker[id] = 0
	g_SpecialShoot[id] = 0
}

public Event_CurWeapon(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	static CSWID;
	CSWID = read_data(2);
	if (CSWID == CSW_WEAPON && g_Had_Firecracker[id])
	{
		if (g_Old_Weapon[id] != CSW_WEAPON)
		{
			entity_set_string(id, EV_SZ_viewmodel, "models/legend/v_firecracker.mdl")
			entity_set_string(id, EV_SZ_weaponmodel, "models/legend/p_firecracker.mdl")
			set_weapon_anim(id, 3)
		}
        message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), _, id)
        write_byte(1)
		write_byte(CSW_WEAPON)
		write_byte(-1)
		message_end()
		static Ent
		Ent = fm_get_user_weapon_entity(id, CSW_WEAPON)
		if (is_valid_ent(Ent) && !cs_get_weapon_ammo(Ent))
		{
			cs_set_weapon_ammo(Ent, 0)
		}
	}
	g_Old_Weapon[id] = CSWID
	return PLUGIN_CONTINUE
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if (get_user_weapon(id) == CSW_WEAPON && g_Had_Firecracker[id] && is_user_alive(id) && is_user_connected(id))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public fw_SetModel(entity, model[])
{
	if (!is_valid_ent(entity))
	{
		return FMRES_IGNORED
	}
	static Classname[32]
	entity_get_string(entity, EV_SZ_classname, Classname, charsmax(Classname))
	if (!equal(Classname, "weaponbox"))
	{
		return FMRES_IGNORED
	}
	static iOwner
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	if (equal(model, "models/w_deagle.mdl"))
	{
		static weapon
		weapon = get_pdata_cbase(entity, m_rgpPlayerItems2[2], 4)
		if (g_Had_Firecracker[iOwner] && is_valid_ent(weapon))
		{
			entity_set_int(weapon, EV_INT_impulse, WEAPON_KEY)
			Remove_Firecracker(iOwner)
			engfunc(EngFunc_SetModel, entity, "models/legend/w_firecracker.mdl")
		    return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if (!is_user_alive(id) || get_user_weapon(id) != CSW_WEAPON || !g_Had_Firecracker[id])
	{
		return PLUGIN_CONTINUE
	}
	static CurButton;
	CurButton = get_uc(uc_handle, UC_Buttons)
	if (CurButton & IN_ATTACK && !(entity_get_int(id, EV_INT_oldbuttons) & IN_ATTACK))
	{
		CurButton -= IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		if (get_pdata_float(id, m_flNextAttack) > 0.0 || cs_get_user_bpammo(id, CSW_WEAPON) < 1)
		{
			return PLUGIN_CONTINUE
		}
		g_SpecialShoot[id] = 0
		Handle_Shoot(id)
	}
    
	if (CurButton & IN_ATTACK2 && !(entity_get_int(id, EV_INT_oldbuttons) & IN_ATTACK2))
	{
		if (get_pdata_float(id, m_flNextAttack) > 0.0 || cs_get_user_bpammo(id, CSW_WEAPON) < 1)
		{
			return PLUGIN_CONTINUE
		}
		static Ent
		Ent = fm_get_user_weapon_entity(id, CSW_WEAPON)
		if (is_valid_ent(Ent))
		{
			g_SpecialShoot[id] = 1
			Handle_Shoot(id)
			g_SpecialShoot[id] = 0
		}
	}
	if (CurButton & IN_RELOAD)
	{
		CurButton -= IN_RELOAD
		set_uc(uc_handle, UC_Buttons, CurButton)
	}
	return PLUGIN_CONTINUE
}

public fw_AddToPlayer(wep_ent, id)
{
	if (!is_valid_ent(wep_ent) || !is_user_connected(id))
	{
		return HAM_IGNORED
	}
	if (entity_get_int(wep_ent, EV_INT_impulse) == WEAPON_KEY)
	{
		g_Had_Firecracker[id] = 1
		entity_set_int(wep_ent, EV_INT_impulse, 0);
		return HAM_HANDLED
	}
	return HAM_IGNORED
}

public fw_TraceAttack(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if (!is_user_alive(Attacker) || get_user_weapon(Attacker) != CSW_WEAPON || !g_Had_Firecracker[Attacker])
	{
		return HAM_IGNORED
	}
	return HAM_SUPERCEDE
}

public fw_Item_PrimaryAttack(ent)
{
	if (!is_valid_ent(ent))
	{
		return HAM_IGNORED
	}
	static id;
	id = entity_get_edict(ent, EV_ENT_owner)
	if (!is_user_alive(id) || !g_Had_Firecracker[id])
	{
		return HAM_IGNORED
	}
	static Float:PunchAngles[3]
	PunchAngles[2] = 0.0
	PunchAngles[1] = 0.0
	PunchAngles[0] = 0.0
    entity_set_vector(id, EV_VEC_punchangle, PunchAngles)
	return HAM_HANDLED
}

public fw_Weapon_Reload(ent)
{
	static id;
	id = entity_get_edict(ent, EV_ENT_owner)
	if (is_user_alive(id) && g_Had_Firecracker[id] && get_user_weapon(id) == CSW_WEAPON)
	{
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public fw_Grenade_Think(Ent)
{
	if (!is_valid_ent(Ent))
	{
		return PLUGIN_CONTINUE
	}
	static Float:Origin[3]
	entity_get_vector(Ent, EV_VEC_origin, Origin)
	message_begin(MSG_ALL, SVC_TEMPENTITY)
	write_byte(TE_SPARKS)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	message_end()
    
	if (get_gametime() - 0.75 > entity_get_float(Ent, EV_FL_fuser1))
	{
		emit_sound(Ent, CHAN_BODY, WeaponSounds[6], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		entity_set_float(Ent, EV_FL_fuser1, get_gametime())
	}
	if (get_gametime() - entity_get_float(Ent, EV_FL_fuser2) >= 2.0)
	{
		Grenade_Explosion(Ent)
		return PLUGIN_CONTINUE
	}
	entity_set_float(Ent, EV_FL_nextthink, get_gametime() + 0.1)
	return PLUGIN_CONTINUE
}

public fw_Grenade_Touch(Ent, Id)
{
	if (!is_valid_ent(Ent))
	{
		return PLUGIN_CONTINUE
	}
	static Bounce;
	Bounce = entity_get_int(Ent, EV_INT_iuser1)
	if (Bounce)
	{
		emit_sound(Ent, CHAN_BODY, WeaponSounds[random_num(3, 5)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
	else
	{
		Grenade_Explosion(Ent);
	}
	return PLUGIN_CONTINUE
}

public Grenade_Explosion(Ent)
{
	static TE_FLAG, Float:Origin[3]
	entity_get_vector(Ent, EV_VEC_origin, Origin)
	TE_FLAG = TE_FLAG | TE_EXPLFLAG_NODLIGHTS
	TE_FLAG = TE_FLAG | TE_EXPLFLAG_NOSOUND
	TE_FLAG = TE_FLAG | TE_EXPLFLAG_NOPARTICLES

	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, Origin)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 36.0)
	write_short(g_Exp_SprId)
	write_byte(10)
	write_byte(30)
	write_byte(TE_FLAG)
	message_end()

	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, Origin);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 36.0)
	write_short(g_Exp2_SprId)
	write_byte(10);
	write_byte(30);
	write_byte(TE_FLAG)
	message_end()

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_WORLDDECAL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(random_num(46, 48))
	message_end()

	emit_sound(Ent, CHAN_BODY, WeaponSounds[7], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	Check_RadiusDamage(Ent, entity_get_edict(Ent, EV_ENT_owner))
	engfunc(EngFunc_RemoveEntity, Ent)
}

public Handle_Shoot(id)
{
	if (get_gametime() - 2.5 > g_LastShoot[id])
	{
		g_LastShoot[id] = get_gametime()
		static Ent
		Ent = fm_get_user_weapon_entity(id, CSW_WEAPON)
		if (!is_valid_ent(Ent)) return PLUGIN_CONTINUE

		static Ammo
		Ammo = cs_get_user_bpammo(id, CSW_WEAPON)
		if (Ammo < 1) return PLUGIN_CONTINUE

		Ammo --
		cs_set_user_bpammo(id, CSW_WEAPON, Ammo)
		if (Ammo < 1)
		{
			set_weapon_anim(id, 2)
			engfunc(EngFunc_EmitSound, id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
		else
		{
			set_weapon_anim(id, 1)
			engfunc(EngFunc_EmitSound, id, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
		Make_Muzzleflash(id)
		Make_PunchAngles(id)
		set_weapons_timeidle(id, 2.5)
	    set_pdata_float(id, m_flNextAttack, 2.5)
		Make_Grenade(id, g_SpecialShoot[id])
	}
	return PLUGIN_CONTINUE
}

public Make_Muzzleflash(id)
{
	static TE_FLAG;
	static Float:Origin[3];
	get_position(id, 80.0, 20.0, -10.0, Origin);
	TE_FLAG = TE_FLAG | TE_EXPLFLAG_NODLIGHTS
	TE_FLAG = TE_FLAG | TE_EXPLFLAG_NOSOUND
	TE_FLAG = TE_FLAG | TE_EXPLFLAG_NOPARTICLES
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, Origin, id)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_MF_SprId)
	write_byte(3)
	write_byte(20)
	write_byte(TE_FLAG)
	message_end()
}

public Make_PunchAngles(id)
{
	static Float:PunchAngles[3]
	PunchAngles[0] = random_float(-2.0, 0.0)
	PunchAngles[1] = random_float(-4.0, 1.0)
    entity_set_vector(id, EV_VEC_punchangle, PunchAngles)
}

public Make_Grenade(id, Bounce)
{
	static Ent;
    Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!is_valid_ent(Ent)) return PLUGIN_CONTINUE
	static Float:Angles[3], Float:Origin[3]
	get_position(id, 50.0, 10.0, 0.0, Origin)
	entity_get_vector(id, EV_VEC_angles, Angles)
	entity_set_int(Ent, EV_INT_movetype, MOVETYPE_BOUNCE)
	entity_set_int(Ent, EV_INT_solid, SOLID_BBOX)
	entity_set_float(Ent, EV_FL_nextthink, get_gametime() + 0.1)
	entity_set_string(Ent, EV_SZ_classname, GRENADE_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, "models/legend/shell_firecracker.mdl")
	entity_set_vector(Ent, EV_VEC_origin, Origin)
	entity_set_vector(Ent, EV_VEC_angles, Angles)
	entity_set_edict(Ent, EV_ENT_owner, id)
	entity_set_edict(Ent, EV_ENT_owner, id)
	entity_set_int(Ent, EV_INT_iuser1, Bounce)
	entity_set_float(Ent, EV_FL_fuser2, get_gametime())

	static Float:TargetOrigin[3], Float:Velocity[3]
	fm_get_aim_origin(id, TargetOrigin)
	get_speed_vector(Origin, TargetOrigin, 700.0, Velocity)
	entity_set_vector(Ent, EV_VEC_velocity, Velocity)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(Ent)
	write_short(g_Trail_SprId)
	write_byte(10)
	write_byte(3)
	write_byte(255)
	write_byte(170)
	write_byte(212)
	write_byte(200)
	message_end()
    return PLUGIN_CONTINUE
}

public Check_RadiusDamage(Ent, Id)
{
	if (!is_user_connected(Id))
    {
        remove_entity(Ent)
        return
    }
	
	for(new i = 0;i < get_maxplayers();i++)
	{
		if (!is_user_alive(i) || fm_get_user_godmode(i) || entity_range(Ent, i) > GRENADE_RANGE || !bm_get_user_boss(i))
			continue

		ExecuteHamB(Ham_TakeDamage, i, Id, Id, DAMAGE, DMG_SHOCK)
	}
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	entity_get_vector(id, EV_VEC_origin, vOrigin)
	
	entity_get_vector(id, EV_VEC_view_ofs, vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	entity_get_vector(id, EV_VEC_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle, ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle, ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle, ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}


set_weapon_anim(id, anim)
{
	entity_set_int(id, EV_INT_weaponanim, anim)
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(entity_get_int(id, EV_INT_body))
	message_end()
}

set_weapons_timeidle(id, Float:TimeIdle)
{
	static Ent;
	Ent = fm_get_user_weapon_entity(id, CSW_WEAPON);
	if (!is_valid_ent(Ent))
	{
		return PLUGIN_CONTINUE
	}
	set_pdata_float(Ent, m_flNextPrimaryAttack, TimeIdle, 4, 5)
	set_pdata_float(Ent, m_flNextSecondaryAttack, TimeIdle, 4, 5)
	set_pdata_float(Ent, m_flTimeWeaponIdle, TimeIdle + 1.0, 4, 5)
	return PLUGIN_CONTINUE
}