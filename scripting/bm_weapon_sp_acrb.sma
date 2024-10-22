#include <amxmodx>
#include <engine>
#include <xs>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <bossmode>

#pragma tabsize 4

#define CSW_WEAPON CSW_AUG
#define WEAPON_NAME "weapon_aug"
#define WEAPON_KEY 128936

new m_pPlayer = 41
new m_flNextPrimaryAttack = 46
new m_flTimeWeaponIdle = 48 // float
new m_iClip = 51
new m_fInReload = 54
new m_flNextAttack = 83
// CWeaponBox
new m_rgpPlayerItems2[6] = { 34, 35, 36, 37, 38, 39 } // CBasePlayerItem *

new const Fire_Sounds[32] = "weapons/scar.wav"
new const acrb_V_MODEL[64] = "models/legend/v_acrb.mdl"
new const acrb_P_MODEL[64] = "models/legend/p_acrb.mdl"
new const acrb_W_MODEL[64] = "models/legend/w_acrb.mdl"

new GUNSHOT_DECALS[5] = { 41, 42, 43, 44, 45 }, cvar_dmg_acrb, cvar_recoil_acrb, cvar_clip_acrb, 
cvar_acrb_ammo, cvar_spd_acrb, g_has_acrb[33], g_clip_ammo[33], 
Float:cl_pushangle[33][3], g_acrb_TmpClip[33], oldweap[33], g_itemid;

public plugin_init()
{
	register_plugin("Acrb", "1.0", "xiaodo")

	register_message(get_user_msgid("DeathMsg"), "message_DeathMsg")
	register_event("CurWeapon", "CurrentWeapon", "be", "1=1")

	RegisterHam(Ham_Item_AddToPlayer, WEAPON_NAME, "fw_acrb_AddToPlayer")
	RegisterHam(Ham_Item_Deploy, WEAPON_NAME, "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_NAME, "fw_acrb_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_NAME, "fw_acrb_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Item_PostFrame, WEAPON_NAME, "acrb_ItemPostFrame")
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "acrb_Reload")
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "acrb_Reload_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_breakable", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_wall", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_plat", "fw_TraceAttack", 1)
	RegisterHam(Ham_TraceAttack, "func_rotating", "fw_TraceAttack", 1)

	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	cvar_dmg_acrb = register_cvar("acrb_dmg", "2.5")
	cvar_recoil_acrb = register_cvar("acrb_recoil", "1.05")
	cvar_clip_acrb = register_cvar("acrb_clip", "30")
	cvar_spd_acrb = register_cvar("acrb_spd", "1.025")
	cvar_acrb_ammo = register_cvar("acrb_ammo", "90")
	
	g_itemid = bm_weapon_register("雷明登ACR突擊步槍", "acrb", TYPE_FOREVER, 30, 50, 1, CSW_WEAPON, "")
}

public plugin_precache()
{
	precache_model(acrb_V_MODEL)
	precache_model(acrb_P_MODEL)
	precache_model(acrb_W_MODEL)
	
	precache_sound(Fire_Sounds)
	precache_sound("weapons/scar_clipin.wav")
	precache_sound("weapons/scar_clipout.wav")
	precache_sound("weapons/scar_draw.wav")
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
	g_has_acrb[id] = 0
}

public fw_TraceAttack(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	if (!is_user_alive(iAttacker) || get_user_weapon(iAttacker) != CSW_WEAPON || !g_has_acrb[iAttacker])
	{
		return HAM_IGNORED
	}
	static Float:flEnd[3]
	get_tr2(ptr, TR_EndPos, flEnd)
	if (iEnt)
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY, _, 0)
		write_byte(TE_DECAL)
		engfunc(EngFunc_WriteCoord, flEnd[0])
		engfunc(EngFunc_WriteCoord, flEnd[1])
		engfunc(EngFunc_WriteCoord, flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num(0, 4)])
		write_short(iEnt)
		message_end()
	}
	else
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY, _, 0)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, flEnd[0])
		engfunc(EngFunc_WriteCoord, flEnd[1])
		engfunc(EngFunc_WriteCoord, flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num(0, 4)])
		message_end()
	}
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, _, 0)
	write_byte(TE_GUNSHOTDECAL)
	engfunc(EngFunc_WriteCoord, flEnd[0])
	engfunc(EngFunc_WriteCoord, flEnd[1])
	engfunc(EngFunc_WriteCoord, flEnd[2])
	write_short(iAttacker)
	write_byte(GUNSHOT_DECALS[random_num(0, 4)])
	message_end()
	return HAM_IGNORED
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
	static iOwner
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	if (equal(model, "models/w_aug.mdl"))
	{
		static iStoredSVDID
		iStoredSVDID = get_pdata_cbase(entity, m_rgpPlayerItems2[1], 4)
		if (g_has_acrb[iOwner] && is_valid_ent(iStoredSVDID))
		{
			g_has_acrb[iOwner] = 0
			entity_set_int(iStoredSVDID, EV_INT_impulse, WEAPON_KEY)
			entity_set_model(entity, acrb_W_MODEL)
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
	drop_weapons(id, 1)
	new iWep2 = fm_give_item(id, WEAPON_NAME)
	if (iWep2 > 0)
	{
		cs_set_weapon_ammo(iWep2, get_pcvar_num(cvar_clip_acrb))
		cs_set_user_bpammo(id, CSW_WEAPON, get_pcvar_num(cvar_acrb_ammo))
		set_pdata_float(id, m_flNextAttack, 1.0)
		UTIL_PlayWeaponAnimation(id, 3)
	}
	g_has_acrb[id] = 1
	return PLUGIN_CONTINUE
}

public fw_acrb_AddToPlayer(acrb, id)
{
	if (!is_valid_ent(acrb) || !is_user_connected(id))
	{
		return HAM_IGNORED
	}
	if (entity_get_int(acrb, EV_INT_impulse) == WEAPON_KEY)
	{
		g_has_acrb[id] = 1
		entity_set_int(acrb, EV_INT_impulse, 0)
		return HAM_HANDLED
	}
	return HAM_IGNORED
}

public fw_Item_Deploy_Post(weapon_ent)
{
	static owner, weaponid
	owner = get_pdata_cbase(weapon_ent, m_pPlayer, 4)
	weaponid = cs_get_weapon_id(weapon_ent)
	replace_weapon_models(owner, weaponid)
}

public CurrentWeapon(id)
{
	replace_weapon_models(id, read_data(2))
	if (read_data(2) == CSW_WEAPON && !g_has_acrb[id])
	{
		return PLUGIN_CONTINUE
	}
	static Float:iSpeed, Ent, weapon[32];
	if (g_has_acrb[id])
	{
		iSpeed = get_pcvar_float(cvar_spd_acrb);
	}
	get_weaponname(read_data(2), weapon, 31);
	Ent = find_ent_by_owner(-1, weapon, id);
	if (Ent)
	{
		static Float:Delay;
		Delay = get_pdata_float(Ent, m_flNextPrimaryAttack, 4) * iSpeed
		if (Delay > 0.0)
		{
			set_pdata_float(Ent, m_flNextPrimaryAttack, Delay, 4);
		}
	}
	return PLUGIN_CONTINUE
}

replace_weapon_models(id, weaponid)
{
	if (g_has_acrb[id] && weaponid == CSW_WEAPON)
	{
		entity_set_string(id, EV_SZ_viewmodel, acrb_V_MODEL)
		entity_set_string(id, EV_SZ_weaponmodel, acrb_P_MODEL)
		if (oldweap[id] != CSW_WEAPON)
		{
			set_pdata_float(id, m_flNextAttack, 1.0)
			UTIL_PlayWeaponAnimation(id, 3)
		}
	}
	oldweap[id] = weaponid
}

public fw_UpdateClientData_Post(Player, SendWeapons, CD_Handle)
{
	if (is_user_alive(Player) && get_user_weapon(Player) == CSW_WEAPON && g_has_acrb[Player])
	{
        set_cd(CD_Handle, CD_flNextAttack, get_gametime() + 0.001);
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public fw_acrb_PrimaryAttack(Weapon)
{
	new Player = get_pdata_cbase(Weapon, m_pPlayer, 4)
	if (!g_has_acrb[Player])
	{
		return HAM_IGNORED
	}
    entity_get_vector(Player, EV_VEC_punchangle, cl_pushangle[Player])
	g_clip_ammo[Player] = cs_get_weapon_ammo(Weapon)
	return HAM_IGNORED
}

public fw_acrb_PrimaryAttack_Post(Weapon)
{
	new Player = get_pdata_cbase(Weapon, m_pPlayer, 4), szClip, szAmmo;
	get_user_weapon(Player, szClip, szAmmo);
	if (g_has_acrb[Player] && is_user_alive(Player))
	{
		if (!g_clip_ammo[Player])
		{
			return HAM_IGNORED
		}
		new Float:push[3] = 0.0
        entity_get_vector(Player, EV_VEC_punchangle, push)
		xs_vec_sub(push, cl_pushangle[Player], push)
		xs_vec_mul_scalar(push, get_pcvar_float(cvar_recoil_acrb), push)
		xs_vec_add(push, cl_pushangle[Player], push)
        entity_set_vector(Player, EV_VEC_punchangle, push)
		emit_sound(Player, CHAN_WEAPON, Fire_Sounds, VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		UTIL_PlayWeaponAnimation(Player, 1)
	}
	return HAM_IGNORED
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage)
{
	if (attacker != victim && is_user_connected(attacker) && g_has_acrb[attacker] && get_user_weapon(attacker) == CSW_WEAPON)
	{
		SetHamParamFloat(4, damage * get_pcvar_float(cvar_dmg_acrb))
	}
	return HAM_IGNORED
}

public message_DeathMsg(msg_id, msg_dest, id)
{
	static iVictim, iAttacker, szTruncatedWeapon[33]
	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
	if (!is_user_connected(iAttacker) || iVictim != iAttacker || get_user_weapon(iAttacker) != CSW_WEAPON)
	{
		return FMRES_IGNORED
	}
	if (equal(szTruncatedWeapon, "aug") && g_has_acrb[iAttacker])
	{
		set_msg_arg_string(4, "aug")
	}
	return FMRES_IGNORED
}

UTIL_PlayWeaponAnimation(Player, Sequence)
{
    entity_set_int(Player, EV_INT_weaponanim, Sequence)
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, Player)
	write_byte(Sequence)
	write_byte(entity_get_int(Player, EV_INT_body))
	message_end()
}

public acrb_ItemPostFrame(weapon_entity)
{
	new id = entity_get_edict(weapon_entity, EV_ENT_owner)
	if (!is_user_alive(id) || !g_has_acrb[id])
	{
		return HAM_IGNORED
	}
	new Float:flNextAttack = get_pdata_float(id, m_flNextAttack);
	new iBpAmmo = cs_get_user_bpammo(id, CSW_WEAPON);
	new iClip = get_pdata_int(weapon_entity, m_iClip, 4);
	new fInReload = get_pdata_int(weapon_entity, m_fInReload, 4);
	if (fInReload && flNextAttack <= 0.0)
	{
		new j = min(get_pcvar_num(cvar_clip_acrb) - iClip, iBpAmmo);
		set_pdata_int(weapon_entity, m_iClip, j + iClip, 4);
		cs_set_user_bpammo(id, CSW_WEAPON, iBpAmmo - j);
		set_pdata_int(weapon_entity, m_fInReload, 0, 4);
		fInReload = 0;
	}
	return HAM_IGNORED
}

public acrb_Reload(weapon_entity)
{
	new id = entity_get_edict(weapon_entity, EV_ENT_owner)
	if (!is_user_alive(id) || !g_has_acrb[id])
	{
		return HAM_IGNORED
	}
	g_acrb_TmpClip[id] = -1;
	new iBpAmmo = cs_get_user_bpammo(id, CSW_WEAPON);
	new iClip = get_pdata_int(weapon_entity, m_iClip, 4);
	if (get_pcvar_num(cvar_clip_acrb) <= iClip || iBpAmmo <= 0)
	{
		return HAM_SUPERCEDE
	}
	g_acrb_TmpClip[id] = iClip;
	return HAM_IGNORED
}

public acrb_Reload_Post(weapon_entity)
{
	new id = entity_get_edict(weapon_entity, EV_ENT_owner)
	if (!is_user_connected(id) || !g_has_acrb[id] || g_acrb_TmpClip[id] == -1)
	{
		return HAM_IGNORED
	}
	set_pdata_int(weapon_entity, m_iClip, g_acrb_TmpClip[id], 4)
	set_pdata_float(weapon_entity, m_flTimeWeaponIdle, 3.7, 4)
	set_pdata_int(weapon_entity, m_fInReload, 1, 4)
	set_pdata_float(id, m_flNextAttack, 3.7)
	UTIL_PlayWeaponAnimation(id, 2)
	return HAM_IGNORED
}