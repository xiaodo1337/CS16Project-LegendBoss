#include <amxmodx>
#include <engine>
#include <xs>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <bossmode>

#pragma tabsize 4

#define CSW_WEAPON CSW_MP5NAVY
#define WEAPON_NAME "weapon_mp5navy"
#define WEAPON_KEY 109263

new const m_pPlayer = 41
new const m_flNextPrimaryAttack = 46
new const m_flNextSecondaryAttack = 47 // float
new const m_flTimeWeaponIdle = 48 // float
new const m_iClip = 51
new const m_fInReload = 54
new const m_flNextAttack = 83
// CWeaponBox
new const m_rgpPlayerItems2[6] = { 34, 35, 36, 37, 38, 39 } // CBasePlayerItem *

new Weapon_Models[4][] = 
{
	"models/legend/v_coilgun.mdl",
	"models/legend/p_coilgun.mdl",
	"models/legend/w_coilgun.mdl",
	"models/legend/s_coil.mdl"
}

new Weapon_Sounds[4][] =
{
	"weapons/coilgun-1.wav",
	"weapons/coilgun_clipin1.wav",
	"weapons/coilgun_clipin2.wav",
	"weapons/coilgun_clipout.wav"
}

new g_had_coilgun[33], g_coilgun_clip[33], g_old_weapon[33], g_trail_sprid, g_MaxPlayers;

public plugin_init()
{
	register_plugin("CSO Needler", "1.0", "xiaodo")
	register_clcmd("buy_coil1b354v234v", "weapon_buy")
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_SetModel, "fw_SetModel")
	register_touch("nail", "player", "fw_nail_Touch")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")

	RegisterHam(Ham_Item_AddToPlayer, WEAPON_NAME, "fw_Item_AddToPlayer")
	RegisterHam(Ham_Item_PostFrame, WEAPON_NAME, "fw_Item_PostFrame")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_NAME, "fw_Weapon_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "fw_Weapon_Reload_Post", 1)
	g_MaxPlayers = get_maxplayers();
}

public plugin_precache()
{
	for (new i;i<4;i++)
	{
		engfunc(EngFunc_PrecacheModel, Weapon_Models[i])
		engfunc(EngFunc_PrecacheSound, Weapon_Sounds[i])
	}

	g_trail_sprid = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
}

public bm_weapon_remove(id)
{
	g_had_coilgun[id] = 0
}

public weapon_buy(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	drop_weapons(id, 1)
	g_had_coilgun[id] = 1
	static Ent;
	Ent = fm_give_item(id, WEAPON_NAME)
	if (is_valid_ent(Ent))
	{
		cs_set_weapon_ammo(Ent, 100)
	}
	cs_set_user_bpammo(id, CSW_WEAPON, 200)
	update_ammo(id, CSW_WEAPON, 100, 200)
	return PLUGIN_CONTINUE
}

public Event_CurWeapon(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	if ((get_user_weapon(id) == CSW_WEAPON && g_old_weapon[id] != CSW_WEAPON) && g_had_coilgun[id])
	{
		entity_set_string(id, EV_SZ_viewmodel, Weapon_Models[0])
		entity_set_string(id, EV_SZ_weaponmodel, Weapon_Models[1])
		set_weapon_anim(id, 4)
		set_weapon_timeidle(id, CSW_WEAPON, 1.0)
		set_player_nextattack(id, 1.0)
	}
	else
	{
		if ((get_user_weapon(id) == CSW_WEAPON && g_old_weapon[id] == CSW_WEAPON) && g_had_coilgun[id])
		{
			static Ent;
			Ent = fm_get_user_weapon_entity(id, CSW_WEAPON)
			if (is_valid_ent(Ent))
			{
				set_pdata_float(Ent, m_flNextPrimaryAttack, get_pdata_float(Ent, m_flNextPrimaryAttack, 4) * 4.0, 4)
			}
		}
	}
	g_old_weapon[id] = get_user_weapon(id)
	return PLUGIN_CONTINUE
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if (is_user_alive(id) && is_user_connected(id) && get_user_weapon(id) == CSW_WEAPON && g_had_coilgun[id])
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
	static Classname[33];
	entity_get_string(entity, EV_SZ_classname, Classname, charsmax(Classname))
	if (!equal(Classname, "weaponbox"))
	{
		return FMRES_IGNORED
	}
	static iOwner;
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	if (equal(model, "models/w_mp5.mdl"))
	{
		static weapon;
		weapon = get_pdata_cbase(entity, m_rgpPlayerItems2[1], 4)
		if (g_had_coilgun[iOwner] && is_valid_ent(weapon))
		{
			g_had_coilgun[iOwner] = 0
			entity_set_int(weapon, EV_INT_impulse, WEAPON_KEY)
			entity_set_model(entity, Weapon_Models[2])
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public fw_nail_Touch(Ent, Id)
{
	if (!is_valid_ent(Ent))
	{
		return HAM_IGNORED
	}
	static ptr, Owner;
	ptr = entity_get_int(Ent, EV_INT_iuser4)
	Owner = entity_get_edict(Ent, EV_ENT_owner)
	if (!is_user_connected(Owner))
	{
		engfunc(EngFunc_RemoveEntity, Ent)
		free_tr2(ptr)
		return PLUGIN_CONTINUE
	}
	if (is_valid_ent(Id))
	{
		fake_take_damage(Owner, Id)
		engfunc(EngFunc_RemoveEntity, Ent)
	}
	else if (entity_get_int(Ent, EV_INT_iuser3))
	{
		static Float:NewVelocity[3], Float:Origin2[3], Float:Angles[3], Float:Origin[3], Smart_Nail;
		Smart_Nail = 1
		if (random_num(0, 1))
		{
			Smart_Nail = 0
		}
		entity_get_vector(Ent, EV_VEC_origin, Origin)
		if (!Smart_Nail) entity_get_vector(Owner, EV_VEC_origin, Origin2)
		else
		{
			static Enemy;
			Enemy = FindClosetEnemy(Ent, 1)
			if (is_user_alive(Enemy)) entity_get_vector(Enemy, EV_VEC_origin, Origin2)
			else entity_get_vector(Owner, EV_VEC_origin, Origin2)
			Smart_Nail = 0
		}
		entity_get_vector(Ent, EV_VEC_angles, Angles)
		get_speed_vector(Origin, Origin2, 1000.0, NewVelocity)
		if (!Smart_Nail)
		{
			NewVelocity[0] += random_float(-500.0, 500.0)
			NewVelocity[1] += random_float(-500.0, 500.0)
			NewVelocity[2] += random_float(-500.0, 500.0)
		}
		Create_Nail(Owner, 0, Origin, Angles, Origin2, NewVelocity);
		entity_set_int(Ent, EV_INT_iuser3, 0)
		engfunc(EngFunc_RemoveEntity, Ent)
	}
	free_tr2(ptr)
	return PLUGIN_CONTINUE
}

public fw_TraceAttack(ent, attacker, Float:Damage, Float:fDir[3], ptr, iDamageType)
{
	if (!is_user_alive(attacker) || get_user_weapon(attacker) != CSW_WEAPON || !g_had_coilgun[attacker])
	{
		return HAM_IGNORED
	}
	Handle_Nail(attacker)
	return HAM_SUPERCEDE
}

public fw_Item_AddToPlayer(ent, id)
{
	if (!is_valid_ent(ent) || !is_user_connected(id))
	{
		return HAM_IGNORED
	}
	if (entity_get_int(ent, EV_INT_impulse) == WEAPON_KEY)
	{
		g_had_coilgun[id] = 1
		entity_set_int(ent, EV_INT_impulse, 0)
		return HAM_HANDLED
	}
	return HAM_IGNORED
}

public fw_Item_PostFrame(ent)
{
	static id;
	id = entity_get_edict(ent, EV_ENT_owner)
	if (!is_user_alive(id) || !g_had_coilgun[id])
	{
		return HAM_IGNORED
	}
	static Float:flNextAttack, bpammo, iClip, fInReload;
	flNextAttack = get_pdata_float(id, m_flNextAttack)
	bpammo = cs_get_user_bpammo(id, CSW_WEAPON)
	iClip = get_pdata_int(ent, m_iClip, 4)
	fInReload = get_pdata_int(ent, m_fInReload, 4)

	if (fInReload && flNextAttack <= 0.0)
	{
		static temp1;
		temp1 = min(100 - iClip, bpammo)
		set_pdata_int(ent, m_iClip, temp1 + iClip, 4)
		cs_set_user_bpammo(id, CSW_WEAPON, bpammo - temp1)
		set_pdata_int(ent, m_fInReload, 0, 4)
	}
	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack_Post(ent)
{
	new id = get_pdata_cbase(ent, m_pPlayer, 4)
	if (!is_user_alive(id) || !is_user_connected(id) || !g_had_coilgun[id])
	{
		return HAM_IGNORED
	}
	if(get_pdata_int(ent, m_iClip, 4) > 0)
	{
		set_weapon_anim(id, 1)
		emit_sound(id, CHAN_WEAPON, Weapon_Sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
	return HAM_IGNORED
}

public fw_Weapon_Reload(ent)
{
	static id;
	id = entity_get_edict(ent, EV_ENT_owner)
	if (!is_user_alive(id) || !g_had_coilgun[id])
	{
		return HAM_IGNORED
	}
	g_coilgun_clip[id] = -1
	static BPAmmo, iClip
	BPAmmo = cs_get_user_bpammo(id, CSW_WEAPON)
	iClip = get_pdata_int(ent, m_iClip, 4)
	if (BPAmmo <= 0 || iClip >= 100)
	{
		return HAM_SUPERCEDE
	}
	g_coilgun_clip[id] = iClip;
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id;
	id = entity_get_edict(ent, EV_ENT_owner)
	if (!is_user_alive(id) || !g_had_coilgun[id])
	{
		return HAM_IGNORED
	}
	if (get_pdata_int(ent, m_fInReload, 4))
	{
		if (g_coilgun_clip[id] == -1)
		{
			return HAM_IGNORED
		}
		set_pdata_int(ent, m_iClip, g_coilgun_clip[id], 4)
		set_weapon_anim(id, 3)
		set_weapon_timeidle(id, CSW_WEAPON, 3.7)
		set_player_nextattack(id, 3.7)
	}
	return HAM_HANDLED
}

public Handle_Nail(id)
{
	static Float:Velocity[3], Float:EndOrigin[3], Float:Angles[3], Float:StartOrigin[3];
	get_position(id, 30.0, 12.5, -10.0, StartOrigin)
	entity_get_vector(id, EV_VEC_angles, Angles)
	fm_get_aim_origin(id, EndOrigin)
	get_speed_vector(StartOrigin, EndOrigin, 1000.0, Velocity)
	Create_Nail(id, 1, StartOrigin, Angles, EndOrigin, Velocity)
}

public Create_Nail(id, Reflect, Float:StartOrigin[3], Float:Angles[3], Float:EndOrigin[3], Float:Velocity[3])
{
	static Nail;
    Nail = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!is_valid_ent(Nail)) return PLUGIN_CONTINUE

	entity_set_int(Nail, EV_INT_movetype, MOVETYPE_FLY)
	entity_set_int(Nail, EV_INT_solid, SOLID_BBOX)
	entity_set_string(Nail, EV_SZ_classname, "nail")
	entity_set_model(Nail, Weapon_Models[3])
	entity_set_vector(Nail, EV_VEC_origin, StartOrigin)
	entity_set_vector(Nail, EV_VEC_angles, Angles)
	entity_set_vector(Nail, EV_VEC_v_angle, Angles)
	entity_set_edict(Nail, EV_ENT_owner, id)
	entity_set_vector(Nail, EV_VEC_velocity, Velocity)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, _, 0)
	write_byte(TE_BEAMFOLLOW)	// write_byte(TE_BEAMFOLLOW)
	write_short(Nail)	// write_short(entity:attachment to follow)
	write_short(g_trail_sprid)	// write_short(sprite index)
	write_byte(2)	// write_byte(life in 0.1's) 
	write_byte(1)	// write_byte(line width in 0.1's) 
	write_byte(210)	// write_byte(red)
	write_byte(210)	// write_byte(green)
	write_byte(210)	// write_byte(blue)
	write_byte(150)	// write_byte(brightness)
	message_end()
	static ptr;
	ptr = create_tr2()
	engfunc(EngFunc_TraceLine, StartOrigin, EndOrigin, id, id, ptr)
	entity_set_int(Nail, EV_INT_iuser3, Reflect)
	entity_set_int(Nail, EV_INT_iuser4, ptr)
	return PLUGIN_CONTINUE
}

public update_ammo(id, CSWID, ammo, bpammo)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSWID)
	write_byte(ammo)
	message_end()
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
	write_byte(1)
	write_byte(bpammo)
	message_end()
	return PLUGIN_CONTINUE
}

stock set_weapon_timeidle(id, CSWID, Float:TimeIdle)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	static weapon
	weapon = fm_get_user_weapon_entity(id, CSWID)
	set_pdata_float(id, m_flNextAttack, TimeIdle)
	if (is_valid_ent(weapon))
	{
		set_pdata_float(weapon, m_flNextPrimaryAttack, TimeIdle, 4)
		set_pdata_float(weapon, m_flNextSecondaryAttack, TimeIdle, 4)
		set_pdata_float(weapon, m_flTimeWeaponIdle, TimeIdle + 1.0, 4)
	}
	return PLUGIN_CONTINUE
}


stock set_player_nextattack(id, Float:nexttime)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	set_pdata_float(id, m_flNextAttack, nexttime)
	return PLUGIN_CONTINUE
}

stock set_weapon_anim(Player, Sequence)
{
    entity_set_int(Player, EV_INT_weaponanim, Sequence)
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, Player)
	write_byte(Sequence)
	write_byte(entity_get_int(Player, EV_INT_body))
	message_end()
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

stock fake_take_damage(iAttacker, iVictim)
{
	if (iVictim != iAttacker && get_user_team(iVictim) != get_user_team(iAttacker) && !is_user_alive(iVictim) && !is_user_connected(iVictim) && get_user_weapon(iAttacker) == CSW_WEAPON && fm_get_user_godmode(iVictim))
	{
		return PLUGIN_CONTINUE
	}
	ExecuteHamB(Ham_TakeDamage, iVictim, iAttacker, iAttacker, 125.0, DMG_BULLET)
	return PLUGIN_CONTINUE
}

public FindClosetEnemy(ent, can_see)
{
	new Float:maxdistance = 4980.0, indexid, Float:current_dis = maxdistance;
	
	for (new i = 1;i <= g_MaxPlayers;i++)
	{
		if (can_see)
		{
			if (is_user_alive(i) && can_see_fm(ent, i) && entity_range(ent, i) < current_dis)
			{
				current_dis = entity_range(ent, i)
				indexid = i
			}
		}
		else if (is_user_alive(i) && entity_range(ent, i) < current_dis)
		{
			current_dis = entity_range(ent, i)
			indexid = i
		}
	}
	return indexid
}

stock bool:can_see_fm(entindex1, entindex2)
{
	if (!entindex1 || !entindex2)
		return false

	if (is_valid_ent(entindex1) && is_valid_ent(entindex1))
	{
		new flags = entity_get_int(entindex1, EV_INT_flags)
		if (flags & EF_NODRAW || flags & FL_NOTARGET)
		{
			return false
		}

		new Float:lookerOrig[3]
		new Float:targetBaseOrig[3]
		new Float:targetOrig[3]
		new Float:temp[3]

		entity_get_vector(entindex1, EV_VEC_origin, lookerOrig)
		entity_get_vector(entindex1, EV_VEC_view_ofs, temp)
		lookerOrig[0] += temp[0]
		lookerOrig[1] += temp[1]
		lookerOrig[2] += temp[2]

		entity_get_vector(entindex1, EV_VEC_origin, targetBaseOrig)
		entity_get_vector(entindex2, EV_VEC_view_ofs, temp)
		targetOrig[0] = targetBaseOrig [0] + temp[0]
		targetOrig[1] = targetBaseOrig [1] + temp[1]
		targetOrig[2] = targetBaseOrig [2] + temp[2]

		engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the had of seen player
		if (get_tr2(0, TraceResult:TR_InOpen) && get_tr2(0, TraceResult:TR_InWater))
		{
			return false
		} 
		else 
		{
			new Float:flFraction
			get_tr2(0, TraceResult:TR_flFraction, flFraction)
			if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
			{
				return true
			}
			else
			{
				targetOrig[0] = targetBaseOrig [0]
				targetOrig[1] = targetBaseOrig [1]
				targetOrig[2] = targetBaseOrig [2]
				engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the body of seen player
				get_tr2(0, TraceResult:TR_flFraction, flFraction)
				if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
				{
					return true
				}
				else
				{
					targetOrig[0] = targetBaseOrig [0]
					targetOrig[1] = targetBaseOrig [1]
					targetOrig[2] = targetBaseOrig [2] - 17.0
					engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the legs of seen player
					get_tr2(0, TraceResult:TR_flFraction, flFraction)
					if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
					{
						return true
					}
				}
			}
		}
	}
	return false
}
