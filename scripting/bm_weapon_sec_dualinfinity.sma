#include <amxmodx>
#include <engine>
#include <xs>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>

#include <bossmode>

#pragma tabsize 4

enum
{
	ANIM_IDLE = 0,
	ANIM_IDLEEMPTY,
	ANIM_SHOOT_LEFT1,
	ANIM_SHOOT_LEFT2,
	ANIM_SHOOT_LEFT3,
	ANIM_SHOOT_LEFT4,
	ANIM_SHOOT_LEFT5,
	ANIM_SHOOT_LEFTLAST,
	ANIM_SHOOT_RIGHT1,
	ANIM_SHOOT_RIGHT2,
	ANIM_SHOOT_RIGHT3,
	ANIM_SHOOT_RIGHT4,
	ANIM_SHOOT_RIGHT5,
	ANIM_SHOOT_RIGHTLAST,
	ANIM_RELOAD,
	ANIM_DRAW,
	ANIM_CHANGE
}

#define CSW_WEAPON CSW_ELITE
#define WEAPON_NAME "weapon_elite"
#define WEAPON_KEY 7123

new m_pPlayer = 41
new m_flTimeWeaponIdle = 48
new m_iClip = 51
new m_fInReload = 54
new m_flNextAttack = 83
// CWeaponBox
new m_rgpPlayerItems2[6] = { 34, 35, 36, 37, 38, 39 } // CBasePlayerItem *

new Fire_Sounds[] = "weapons/infi-1.wav"
new DINFINITY_V_MODEL[] = "models/legend/v_infinity.mdl"
new DINFINITY_V_MODEL2[] = "models/legend/v_infinity_2.mdl"
new DINFINITY_P_MODEL[] = "models/legend/p_infinity.mdl"
new DINFINITY_W_MODEL[] = "models/legend/w_infinity.mdl"

new GUNSHOT_DECALS[5] =
{
	41, 42, 43, 44, 45
}

new cvar_dmg_dinfinity, cvar_clip_dinfinity, cvar_dinfinity_ammo, cvar_recoil2_vertical, cvar_recoil2_horizontal, cvar_recoil1_vertical, cvar_recoil1_horizontal, 
oldweap[33], g_DINFINITY_TmpClip[33], g_has_dinfinity[33], g_itemid, g_mode[33], g_sprblood[2]

public plugin_init()
{
	register_plugin("DInfinity", "1.0", "xiaodo")

	register_event("CurWeapon", "CurrentWeapon", "be", "1=1")
	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")

	RegisterHam(Ham_Item_Deploy, WEAPON_NAME, "Ham_Item_Deploy_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_NAME, "Ham_DINFINITY_AddToPlayer")
	RegisterHam(Ham_Think, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Think, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Think, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Think, "func_tanklaser", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_NAME, "Ham_DINFINITY_PrimaryAttack")
	RegisterHam(Ham_Item_PostFrame, WEAPON_NAME, "DInfinity_ItemPostFrame")
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "DInfinity_Reload")
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "DInfinity_Reload_Post", 1)
	//RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")

	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	cvar_dmg_dinfinity = register_cvar("dinfinity_dmg", "100.0");
	cvar_clip_dinfinity = register_cvar("dinfinity_clip", "40");
	cvar_dinfinity_ammo = register_cvar("dinfinity_ammo", "120");
	cvar_recoil1_vertical = register_cvar("dinfinity_verticalrecoilat1", "200")
	cvar_recoil1_horizontal = register_cvar("dinfinity_horizontalrecoilat1", "50")
	cvar_recoil2_vertical = register_cvar("dinfinity_verticalrecoilat2", "3")
	cvar_recoil2_horizontal = register_cvar("dinfinity_horizontalrecoilat2", "300")
	g_itemid = bm_weapon_register("金蠍雙擊", "", TYPE_PISTOL, 0, 0, 150, CSW_WEAPON, "")
}

public plugin_precache()
{
	precache_model(DINFINITY_V_MODEL)
	precache_model(DINFINITY_P_MODEL)
	precache_model(DINFINITY_V_MODEL2)
	precache_model(DINFINITY_W_MODEL)
	
	precache_sound(Fire_Sounds)
	precache_sound("weapons/infi_clipin.wav")
	precache_sound("weapons/infi_clipout.wav")
	precache_sound("weapons/infi_clipon.wav")
	precache_sound("weapons/infi_draw.wav")
	precache_model("sprites/640hud5.spr")
	g_sprblood[0] = precache_model("sprites/bloodspray.spr")
	g_sprblood[1] = precache_model("sprites/blood.spr")
}

public bm_weapon_bought(id, itemid)
{
	if (itemid == g_itemid)
	{
		weapon_buy(id)
	}
}

public bm_weapon_remove(id)
{
	g_has_dinfinity[id] = 0
}

public fw_UseStationary_Post(entity, caller, activator, use_type)
{
	if (use_type && is_user_connected(caller))
	{
		replace_weapon_models(caller, get_user_weapon(caller))
	}
}

public client_putinserver(id)
{
	g_has_dinfinity[id] = 0
}

public client_disconnect(id)
{
	g_has_dinfinity[id] = 0
}

public fw_UpdateClientData_Post(Player, SendWeapons, CD_Handle)
{
	if (get_user_weapon(Player) == CSW_WEAPON && g_has_dinfinity[Player] && is_user_alive(Player) && is_user_connected(Player))
	{
		set_cd(CD_Handle, CD_flNextAttack, get_gametime() + 0.01)
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
	static szClassName[33]
	entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
	if (!equal(szClassName, "weaponbox"))
	{
		return FMRES_IGNORED
	}
	static iOwner, name[64]
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	get_user_name(iOwner, name, charsmax(name))
	if (equal(model, "models/w_elite.mdl"))
	{
		new wep = get_pdata_cbase(entity, m_rgpPlayerItems2[2], 4)
		if (g_has_dinfinity[iOwner] && is_valid_ent(wep))
		{
			g_has_dinfinity[iOwner] = 0
			entity_set_int(wep, EV_INT_impulse, WEAPON_KEY)
			entity_set_model(entity, DINFINITY_W_MODEL)
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public weapon_buy(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	drop_weapons(id, 2)
	new iWep2 = fm_give_item(id, WEAPON_NAME)
	if (iWep2 > 0)	//如果实体创建成功
	{
		cs_set_weapon_ammo(iWep2, get_pcvar_num(cvar_clip_dinfinity))
		cs_set_user_bpammo(id, CSW_WEAPON, get_pcvar_num(cvar_dinfinity_ammo))
		if (get_user_weapon(id) == CSW_WEAPON)
		{
			replace_weapon_models(id, CSW_WEAPON)
			UTIL_PlayWeaponAnimation(id, ANIM_DRAW)
			set_pdata_float(id, m_flNextAttack, 1.2)
		}
	}
	g_has_dinfinity[id] = 1
	return PLUGIN_CONTINUE
}

public Ham_DINFINITY_AddToPlayer(wep_ent, id)
{
	if (!is_valid_ent(wep_ent) || !is_user_connected(id))
	{
		return HAM_IGNORED
	}
	if (entity_get_int(wep_ent, EV_INT_impulse) == WEAPON_KEY)
	{
		g_has_dinfinity[id] = 1
		entity_set_int(wep_ent, EV_INT_impulse, 0)
		return HAM_HANDLED
	}
	return HAM_IGNORED
}

public Ham_Item_Deploy_Post(weapon_ent)
{
	if (!is_valid_ent(weapon_ent)) return HAM_IGNORED
	static owner, weaponid
	owner = get_pdata_cbase(weapon_ent, m_pPlayer, 4)
	weaponid = cs_get_weapon_id(weapon_ent)
	replace_weapon_models(owner, weaponid)
	return HAM_IGNORED
}

public CurrentWeapon(id)
{
	replace_weapon_models(id, read_data(2))
}

replace_weapon_models(id, weaponid)
{
	if (weaponid == CSW_WEAPON)
	{
		if (g_has_dinfinity[id] && !bm_get_user_boss(id))
		{
			if (g_mode[id])
			{
				entity_set_string(id, EV_SZ_viewmodel, DINFINITY_V_MODEL2)
				entity_set_string(id, EV_SZ_weaponmodel, DINFINITY_P_MODEL)
			}
			else
			{
				entity_set_string(id, EV_SZ_viewmodel, DINFINITY_V_MODEL)
				entity_set_string(id, EV_SZ_weaponmodel, DINFINITY_P_MODEL)
			}
			if (oldweap[id] != CSW_WEAPON)
			{
				UTIL_PlayWeaponAnimation(id, ANIM_DRAW)
				set_pdata_float(id, m_flNextAttack, 1.2)
			}
		}
	}
	else g_mode[id] = 0
	oldweap[id] = weaponid
}

public Ham_DINFINITY_PrimaryAttack(Weapon)
{
	new Player = get_pdata_cbase(Weapon, m_pPlayer, 4)
	if (!g_has_dinfinity[Player] || !is_user_alive(Player) || bm_get_user_boss(Player))
	{
		return HAM_IGNORED
	}
	new iClip = get_pdata_int(Weapon, m_iClip, 4)
	new Float:flNextAttack = get_pdata_float(Player, m_flNextAttack)
	if (iClip < 1 || flNextAttack > 0.0)
	{
		return HAM_IGNORED
	}
	
	g_mode[Player] = 0
	replace_weapon_models(Player, CSW_WEAPON)
	UTIL_PlayWeaponAnimation(Player, random_num(0, 1) ? random_num(8, 12) : random_num(2, 6))
	make_punchangle(Player)
	make_blood_and_bulletholes(Player)
	set_pdata_float(Player, m_flNextAttack, 0.2)
	set_pdata_int(Weapon, m_iClip, iClip - 1, 4)
	return HAM_SUPERCEDE
}

/*
public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if (attacker != victim && is_user_connected(attacker))
	{
		if (get_user_weapon(attacker) == CSW_WEAPON && g_has_dinfinity[attacker] && !bm_get_user_boss(attacker))
		{
			SetHamParamFloat(4, get_pcvar_float(cvar_dmg_dinfinity))
		}
	}
}
*/

public message_DeathMsg(msg_id, msg_dest, id)
{
	static iVictim, iAttacker, szTruncatedWeapon[33]
	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)

	if (!is_user_connected(iAttacker) || iVictim != iAttacker)
	{
		return PLUGIN_CONTINUE
	}
	g_has_dinfinity[iVictim] = 0
	if (equal(szTruncatedWeapon, "elite") && get_user_weapon(iAttacker) == CSW_WEAPON && g_has_dinfinity[iAttacker])
	{
		set_msg_arg_string(4, "elite")
	}
	return PLUGIN_CONTINUE
}

public DInfinity_ItemPostFrame(weapon_entity)
{
	new id = entity_get_edict(weapon_entity, EV_ENT_owner)
	if (!is_user_connected(id) || !g_has_dinfinity[id] || !is_user_alive(id) || bm_get_user_boss(id))
	{
		return HAM_IGNORED
	}
	new Float:flNextAttack = get_pdata_float(id, m_flNextAttack, 5, 5)
	new iBpAmmo = cs_get_user_bpammo(id, CSW_WEAPON)
	new iClip = get_pdata_int(weapon_entity, m_iClip, 4, 5)
	new fInReload = get_pdata_int(weapon_entity, m_fInReload, 4, 5)
	
	if (fInReload && flNextAttack <= 0.0)
	{
		new j = min(get_pcvar_num(cvar_clip_dinfinity) - iClip, iBpAmmo)
		set_pdata_int(weapon_entity, m_iClip, j + iClip, 4, 5)
		cs_set_user_bpammo(id, CSW_WEAPON, iBpAmmo - j)
		set_pdata_int(weapon_entity, m_fInReload, 0, 4, 5)
	}

	static button, old_button
	button = entity_get_int(id, EV_INT_button)
	old_button = entity_get_int(id, EV_INT_oldbuttons)
	if (button & IN_ATTACK2 && (old_button & IN_ATTACK2) && flNextAttack <= 0.0 && !fInReload && cs_get_weapon_ammo(weapon_entity) > 0)
	{
		if (iClip < 1)
		{
			UTIL_PlayWeaponAnimation(id , random_num(0, 1) ? ANIM_SHOOT_RIGHTLAST : ANIM_SHOOT_LEFTLAST)
			return HAM_IGNORED
		}
		g_mode[id] = 1
		replace_weapon_models(id, CSW_WEAPON)
		set_pdata_float(id, m_flNextAttack, 0.1)
		set_pdata_int(weapon_entity, m_iClip, iClip - 1, 4, 5)
		make_punchangle(id)
		make_blood_and_bulletholes(id)
		UTIL_PlayWeaponAnimation(id, iClip > 2 ? (random_num(0, 1) ? random_num(ANIM_SHOOT_LEFT1, ANIM_SHOOT_LEFT5) : random_num(ANIM_SHOOT_RIGHT1, ANIM_SHOOT_RIGHT5)) : (random_num(0, 1) ? ANIM_SHOOT_RIGHTLAST : ANIM_SHOOT_LEFTLAST))
	}
	return HAM_IGNORED
}

public DInfinity_Reload(weapon_entity)
{
	new id = entity_get_edict(weapon_entity, EV_ENT_owner)
	if (!is_user_connected(id) || !g_has_dinfinity[id])
	{
		return HAM_IGNORED
	}
	g_DINFINITY_TmpClip[id] = -1
	new iClip = get_pdata_int(weapon_entity, m_iClip, 4, 5)
	if (iClip >= get_pcvar_num(cvar_clip_dinfinity))
	{
		return HAM_SUPERCEDE
	}
	g_DINFINITY_TmpClip[id] = iClip
	return HAM_IGNORED
}

public DInfinity_Reload_Post(weapon_entity)
{
	new id = entity_get_edict(weapon_entity, EV_ENT_owner)
	if (!is_user_connected(id) || !g_has_dinfinity[id] || g_DINFINITY_TmpClip[id] == -1)
	{
		return HAM_IGNORED
	}
	
	set_pdata_int(weapon_entity, m_iClip, g_DINFINITY_TmpClip[id], 4, 5)
	set_pdata_float(weapon_entity, m_flTimeWeaponIdle, 4.0, 4)
	set_pdata_float(id, m_flNextAttack, 4.0)
	set_pdata_int(weapon_entity, m_fInReload, 1, 4, 5)
	UTIL_PlayWeaponAnimation(id, ANIM_RELOAD)
	g_mode[id] = 0
	return HAM_IGNORED
}

make_blood_and_bulletholes(id)
{
	new aimOrigin[3], target, body
	get_user_origin(id, aimOrigin, 3)
	get_user_aiming(id, target, body)
	engfunc(EngFunc_EmitSound, id, CHAN_WEAPON, Fire_Sounds, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	static Float:PlrOrigin[3], Float:VecDir[3], Float:VecEnd[3], Float:plrViewAngles[3], Float:VecDst[3], Float:VecSrc[3]
	entity_get_vector(id, EV_VEC_v_angle, plrViewAngles)
	entity_get_vector(id, EV_VEC_origin, PlrOrigin)
	entity_get_vector(id, EV_VEC_view_ofs, VecSrc)
	xs_vec_add(VecSrc, PlrOrigin, VecSrc)
	angle_vector(plrViewAngles, 1, VecDir)
	xs_vec_mul_scalar(VecDir, 8192.0, VecDst)
	xs_vec_add(VecDst, VecSrc, VecDst)
	new hTrace = create_tr2()
	engfunc(EngFunc_TraceLine, VecSrc, VecDst, 0, id, hTrace)
	new hitEnt = get_tr2(hTrace, TR_pHit)
	new hitGroup = get_tr2(hTrace, TR_iHitgroup)
	get_tr2(hTrace, TR_vecEndPos, VecEnd)
	if (is_valid_ent(hitEnt) && is_user_alive(hitEnt) && bm_get_user_boss(hitEnt) && !fm_get_user_godmode(hitEnt))
	{
		new Float:dmg = get_pcvar_float(cvar_dmg_dinfinity);
		if (is_user_connected(hitEnt))
		{
			ExecuteHamB(Ham_TakeDamage, hitEnt, id, id, hitGroup == 1 ? dmg * 2 : dmg, DMG_BULLET)
			ExecuteHamB(Ham_TraceBleed, hitEnt, dmg, VecDir, hTrace, DMG_BULLET)

			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_BLOODSPRITE)
			write_coord(floatround(VecEnd[0]))
			write_coord(floatround(VecEnd[1]))
			write_coord(floatround(VecEnd[2]))
			write_short(g_sprblood[0])
			write_short(g_sprblood[1])
			write_byte(bm_get_boss_blood_color())
			write_byte(hitGroup == 1 ? 15 : 3)
			message_end()
		}
	}
	else
	{
		if (!is_user_connected(target))
		{
			if (target)
			{
				message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
				write_byte(TE_DECAL)
				write_coord(aimOrigin[0])
				write_coord(aimOrigin[1])
				write_coord(aimOrigin[2])
				write_byte(GUNSHOT_DECALS[random_num(0, 4)])
				write_short(target)
				message_end()
			}
			else
			{
				message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
				write_byte(TE_WORLDDECAL)
				write_coord(aimOrigin[0])
				write_coord(aimOrigin[1])
				write_coord(aimOrigin[2])
				write_byte(GUNSHOT_DECALS[random_num(0, 4)])
				message_end()
			}
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_GUNSHOTDECAL)
			write_coord(aimOrigin[0])
			write_coord(aimOrigin[1])
			write_coord(aimOrigin[2])
			write_short(id)
			write_byte(GUNSHOT_DECALS[random_num(0, 4)])
			message_end()
		}
	}
}

public make_punchangle(id)
{
	if (!is_user_alive(id) || bm_get_user_boss(id) || !g_has_dinfinity[id])
	{
		return PLUGIN_CONTINUE
	}
	if (g_mode[id])
	{
		static Float:punchAngle[3];
		punchAngle[0] = float(random_num(get_pcvar_num(cvar_recoil2_vertical) * -1, get_pcvar_num(cvar_recoil2_vertical))) / 100.0
		punchAngle[1] = float(random_num(get_pcvar_num(cvar_recoil2_horizontal) * -1, get_pcvar_num(cvar_recoil2_horizontal))) / 100.0
		punchAngle[2] = 0.0
		entity_set_vector(id, EV_VEC_punchangle, punchAngle)
	}
	else
	{
		static Float:punchAngle[3];
		punchAngle[0] = float(random_num(get_pcvar_num(cvar_recoil1_vertical) * -1, get_pcvar_num(cvar_recoil1_vertical))) / 100.0
		punchAngle[1] = float(random_num(get_pcvar_num(cvar_recoil1_horizontal) * -1, get_pcvar_num(cvar_recoil1_horizontal))) / 100.0
		punchAngle[2] = 0.0
		entity_set_vector(id, EV_VEC_punchangle, punchAngle)
	}
	return PLUGIN_CONTINUE
}

UTIL_PlayWeaponAnimation(Player, Sequence)
{
    entity_set_int(Player, EV_INT_weaponanim, Sequence)
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, Player)
	write_byte(Sequence)
	write_byte(entity_get_int(Player, EV_INT_body))
	message_end()
}