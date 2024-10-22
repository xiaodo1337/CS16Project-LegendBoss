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
	Animation_IdleA = 0,
	Animation_IdleB,
	Animation_ShootA,
	Animation_ShootB,
	Animation_Reload,
	Animation_Draw,
	Animation_ChangeA,
	Animation_ChangeB,
	Animation_ReloadB
}

#define CSW_WEAPON CSW_DEAGLE
#define WEAPON_NAME "weapon_deagle"
#define WEAPON_KEY 8612

new m_pPlayer = 41
new m_flNextPrimaryAttack = 46
new m_flTimeWeaponIdle = 48
new m_iClip = 51
new m_fInReload = 54
new m_flNextAttack = 83
// CWeaponBox
new m_rgpPlayerItems2[6] = { 34, 35, 36, 37, 38, 39 } // CBasePlayerItem *

new Fire_Sounds[2][] =
{
	"weapons/balrog1-1.wav",
	"weapons/balrog1-2.wav"
}
new b1_V_MODEL[] = "models/legend/v_balrog1v2.mdl"
new b1_P_MODEL[] = "models/legend/p_balrog1v3.mdl"
new b1_W_MODEL[] = "models/legend/w_balrog1v3.mdl"

new GUNSHOT_DECALS[5] =
{
	41, 42, 43, 44, 45
}

new cvar_recoil_b1, cvar_clip_b1, cvar_spd_b1, cvar_b1_ammo, cvar_dmg_exp, g_iClip, 
Float:cl_pushangle[33][3], g_has_b1[33], g_clip_ammo[33], oldweap[33], g_b1_TmpClip[33], gMode[33], sExplo, g_itemid

public plugin_init()
{
	register_plugin("Balrog-I", "1.0", "xiaodo")
	register_event("CurWeapon", "CurrentWeapon", "be", "1=1")

	RegisterHam(Ham_Item_AddToPlayer, WEAPON_NAME, "Ham_b1_AddToPlayer")
	RegisterHam(Ham_Item_PostFrame, WEAPON_NAME, "Ham_b1_ItemPostFrame")
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_NAME, "Ham_b1_Idle")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_NAME, "Ham_b1_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_NAME, "Ham_b1_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "Ham_b1_Reload")
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "Ham_b1_Reload_Post", 1)
	RegisterHam(Ham_TraceAttack, "worldspawn", "Ham_TraceAttack_Post", 1)
	RegisterHam(Ham_TraceAttack, "func_breakable", "Ham_TraceAttack_Post", 1)
	RegisterHam(Ham_TraceAttack, "func_wall", "Ham_TraceAttack_Post", 1)
	RegisterHam(Ham_TraceAttack, "func_door", "Ham_TraceAttack_Post", 1)
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "Ham_TraceAttack_Post", 1)
	RegisterHam(Ham_TraceAttack, "func_plat", "Ham_TraceAttack_Post", 1)
	RegisterHam(Ham_TraceAttack, "func_rotating", "Ham_TraceAttack_Post", 1)

	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	cvar_dmg_exp = register_cvar("b1_dmg_exp", "1000.0")
	cvar_recoil_b1 = register_cvar("b1_recoil", "1.0")
	cvar_clip_b1 = register_cvar("b1_clip", "20")
	cvar_spd_b1 = register_cvar("b1_spd", "0.7")
	cvar_b1_ammo = register_cvar("b1_ammo", "100")
	
	g_itemid = bm_weapon_register("獵魔者", "", TYPE_PISTOL, 0, 0, 1, CSW_WEAPON, "")
}

public plugin_precache()
{
	precache_model(b1_V_MODEL)
	precache_model(b1_P_MODEL)
	precache_model(b1_W_MODEL)
	
	for (new i;i < 2;i++)
	{
		precache_sound(Fire_Sounds[i])
	}
	precache_sound("weapons/balrog1_changea.wav")
	precache_sound("weapons/balrog1_changeb.wav")
	precache_sound("weapons/balrog1_draw.wav")
	precache_sound("weapons/balrog1_reload.wav")
	precache_sound("weapons/balrog1_reloadb.wav")
	sExplo = precache_model("sprites/balrogcritical.spr")
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
	g_has_b1[id] = 0
}

public Ham_TraceAttack_Post(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	new g_currentweapon = get_user_weapon(iAttacker)
	if (!is_user_alive(iAttacker) || g_currentweapon != CSW_WEAPON || !g_has_b1[iAttacker])
	{
		return HAM_IGNORED
	}
	static Float:flEnd[3]
	get_tr2(ptr, TR_vecEndPos, flEnd)
	if (iEnt)
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
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
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, flEnd[0])
		engfunc(EngFunc_WriteCoord, flEnd[1])
		engfunc(EngFunc_WriteCoord, flEnd[2])
		write_byte(GUNSHOT_DECALS[random_num(0, 4)])
		message_end()
	}
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_GUNSHOTDECAL)
	engfunc(EngFunc_WriteCoord, flEnd[0])
	engfunc(EngFunc_WriteCoord, flEnd[1])
	engfunc(EngFunc_WriteCoord, flEnd[2])
	write_short(iAttacker)
	write_byte(GUNSHOT_DECALS[random_num(0, 4)])
	message_end()
	return HAM_IGNORED
}

public client_putinserver(id)
{
	g_has_b1[id] = 0
}

public client_disconnect(id)
{
	g_has_b1[id] = 0
}

public fw_UpdateClientData_Post(Player, SendWeapons, CD_Handle)
{
	if (get_user_weapon(Player) == CSW_WEAPON && g_has_b1[Player] && is_user_alive(Player) && is_user_connected(Player))
	{
		set_cd(CD_Handle, CD_flNextAttack, 999999.0)
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
	static iOwner
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	if (equal(model, "models/w_deagle.mdl"))
	{
		static wep
		wep = get_pdata_cbase(entity, m_rgpPlayerItems2[2], 4)
		if (g_has_b1[iOwner] && is_valid_ent(wep))
		{
			g_has_b1[iOwner] = 0
			entity_set_int(wep, EV_INT_impulse, WEAPON_KEY)
			entity_set_model(entity, b1_W_MODEL)
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public weapon_buy(id)
{
	drop_weapons(id, 2)
	new iWep2 = fm_give_item(id, WEAPON_NAME)
	if (iWep2)	//如果实体创建成功
	{
		cs_set_weapon_ammo(iWep2, get_pcvar_num(cvar_clip_b1))
		cs_set_user_bpammo(id, CSW_WEAPON, get_pcvar_num(cvar_b1_ammo))
		if (get_user_weapon(id) == CSW_WEAPON)
		{
			UTIL_PlayWeaponAnimation(id, Animation_Draw)
			set_pdata_float(id, m_flNextAttack, 1.0, 5, 5)
		}
	}
	g_has_b1[id] = 1
}

public Ham_b1_AddToPlayer(wep_ent, id)
{
	if (!is_valid_ent(wep_ent) || !is_user_connected(id))
	{
		return HAM_IGNORED
	}
	if (entity_get_int(wep_ent, EV_INT_impulse) == WEAPON_KEY)
	{
		g_has_b1[id] = 1
		entity_set_int(wep_ent, EV_INT_impulse, 0)
		return HAM_HANDLED
	}
	return HAM_IGNORED
}

public CurrentWeapon(id)
{
	replace_weapon_models(id, read_data(2))
	if (g_has_b1[id] && get_user_weapon(id) == CSW_WEAPON)
	{
		static Float:iSpeed
		iSpeed = get_pcvar_float(cvar_spd_b1)
		static Ent, weapon[32]
		get_weaponname(read_data(2), weapon, charsmax(weapon))
		Ent = find_ent_by_owner(-1, weapon, id)
		if (Ent)
		{
			static Float:Delay
			Delay = get_pdata_float(Ent, m_flNextPrimaryAttack, 4, 5) * iSpeed
			if (Delay > 0.0)
			{
				set_pdata_float(Ent, m_flNextPrimaryAttack, Delay, 4, 5)
			}
		}
	}
	return PLUGIN_CONTINUE
}

replace_weapon_models(id, weaponid)
{
	switch (weaponid)
	{
		case CSW_WEAPON:
		{
			if (g_has_b1[id] && !bm_get_user_boss(id))
			{
				entity_set_string(id, EV_SZ_viewmodel, b1_V_MODEL)
				entity_set_string(id, EV_SZ_weaponmodel, b1_P_MODEL)
				if (oldweap[id] != CSW_WEAPON)
				{
					UTIL_PlayWeaponAnimation(id, Animation_Draw)
					set_pdata_float(id, m_flNextAttack, 1.0, 5, 5)
					gMode[id] = 0
				}
			}
		}
	}
	oldweap[id] = weaponid
}

public Ham_b1_PrimaryAttack(Weapon)
{
	new Player = get_pdata_cbase(Weapon, m_pPlayer, 4, 5)
	if (!g_has_b1[Player])
	{
		return HAM_IGNORED
	}
	entity_get_vector(Player, EV_VEC_punchangle, cl_pushangle[Player])
	g_clip_ammo[Player] = cs_get_weapon_ammo(Weapon)
	g_iClip = cs_get_weapon_ammo(Weapon)
	return HAM_IGNORED
}

public Ham_b1_PrimaryAttack_Post(Weapon)
{
	new Player = get_pdata_cbase(Weapon, m_pPlayer, 4, 5)
	if (!is_user_alive(Player) || cs_get_weapon_ammo(Weapon) >= g_iClip)
	{
		return HAM_IGNORED
	}
	if (g_has_b1[Player])
	{
		if (!g_clip_ammo[Player])
		{
			return HAM_IGNORED
		}
		new Float:push[3];
		entity_get_vector(Player, EV_VEC_punchangle, push)
		xs_vec_sub(push, cl_pushangle[Player], push)
		xs_vec_mul_scalar(push, get_pcvar_float(cvar_recoil_b1), push)
		xs_vec_add(push, cl_pushangle[Player], push)
		entity_set_vector(Player, EV_VEC_punchangle, push)
		if (gMode[Player])
		{
			explode(Player);
			set_pdata_float(Player, m_flNextAttack, 2.59, 5, 5)
		}
		emit_sound(Player, CHAN_WEAPON, Fire_Sounds[gMode[Player]], 1.0, ATTN_NORM, 0, PITCH_NORM)
		UTIL_PlayWeaponAnimation(Player, gMode[Player] ? Animation_ShootB : Animation_ShootA)
		set_pdata_float(Weapon, m_flTimeWeaponIdle, 1.5, 4, 5)
		if (gMode[Player]) gMode[Player] = 0
	}
	return HAM_IGNORED
}

public explode(id)
{
	new Float:originF[3] = 0.0
	fm_get_aim_origin(id, originF)

	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, originF)
	engfunc(EngFunc_WriteCoord, originF[1])
	engfunc(EngFunc_WriteCoord, originF[2])
	write_short(sExplo)
	write_byte(5)
	write_byte(2)
	write_byte(0)
	message_end()

	new victim = FM_NULLENT
	while ((victim = find_ent_in_sphere(victim, originF, 200.0)) != 0)
	{
		if (is_user_alive(victim) && is_user_connected(victim) && bm_get_user_boss(victim))
		{
			if (get_user_weapon(id) == CSW_WEAPON)
			{
				ExecuteHamB(Ham_TakeDamage, victim, id, id, get_pcvar_float(cvar_dmg_exp), 2)
			}
		}
	}
}

UTIL_PlayWeaponAnimation(Player, Sequence)
{
    entity_set_int(Player, EV_INT_weaponanim, Sequence)
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, Player)
	write_byte(Sequence)
	write_byte(entity_get_int(Player, EV_INT_body))
	message_end()
}

public Ham_b1_ItemPostFrame(weapon_entity)
{
	new id = entity_get_edict(weapon_entity, EV_ENT_owner)
	if (!is_user_connected(id) || !g_has_b1[id])
	{
		return HAM_IGNORED
	}
	static iClipExtra;
	iClipExtra = get_pcvar_num(cvar_clip_b1)
	new Float:flNextAttack = get_pdata_float(id, m_flNextAttack)
	new iBpAmmo = cs_get_user_bpammo(id, CSW_WEAPON)
	new iClip = get_pdata_int(weapon_entity, m_iClip, 4)
	new fInReload = get_pdata_int(weapon_entity, m_fInReload, 4)
	if ((!(entity_get_int(id, EV_INT_button) & IN_ATTACK) && entity_get_int(id, EV_INT_button) & IN_ATTACK2) && flNextAttack <= 0.0)
	{
		UTIL_PlayWeaponAnimation(id, gMode[id] ? Animation_ChangeB : Animation_ChangeA)
		set_pdata_float(id, m_flNextAttack, gMode[id] ? 1.3 : 2.1)
		gMode[id] = gMode[id] ? 0 : 1
		set_pdata_float(weapon_entity, m_flTimeWeaponIdle, 1.0, 4)	//防止切换模式动画被闲置动画覆盖
	}
	if (fInReload && flNextAttack <= 0.0)
	{
		new j = min(iClipExtra - iClip, iBpAmmo)
		set_pdata_int(weapon_entity, m_iClip, j + iClip, 4)
		cs_set_user_bpammo(id, CSW_WEAPON, iBpAmmo - j)
		set_pdata_int(weapon_entity, m_fInReload, 0, 4)
	}
	return HAM_IGNORED
}

public Ham_b1_Idle(weapon_entity)
{
	if(!is_valid_ent(weapon_entity)) return HAM_IGNORED
	static id;
	id = get_pdata_cbase(weapon_entity, m_pPlayer, 4)
	if (!g_has_b1[id]) return HAM_IGNORED
	if (get_pdata_float(weapon_entity, m_flTimeWeaponIdle, 4) > 0.0) return HAM_IGNORED	//如果播放闲置动画时间还没完就返回
	
	UTIL_PlayWeaponAnimation(id, gMode[id] ? Animation_IdleB : Animation_IdleA)
	set_pdata_float(weapon_entity, m_flTimeWeaponIdle, 1.7, 4)	//下次播放闲置动画的时间
	return HAM_SUPERCEDE
}

public Ham_b1_Reload(weapon_entity)
{
	new id = entity_get_edict(weapon_entity, EV_ENT_owner)
	if (!is_user_connected(id) || !g_has_b1[id])
	{
		return HAM_IGNORED
	}
	static iClipExtra
	if (g_has_b1[id])
	{
		iClipExtra = get_pcvar_num(cvar_clip_b1)
	}
	g_b1_TmpClip[id] = -1
	new iBpAmmo = cs_get_user_bpammo(id, CSW_WEAPON)
	new iClip = get_pdata_int(weapon_entity, m_iClip, 4, 5)
	if (iBpAmmo < 1 || iClip >= iClipExtra)
	{
		return HAM_SUPERCEDE
	}
	g_b1_TmpClip[id] = iClip
	return HAM_IGNORED
}

public Ham_b1_Reload_Post(weapon_entity)
{
	new id = entity_get_edict(weapon_entity, EV_ENT_owner)
	if (!is_user_connected(id) || !g_has_b1[id] || g_b1_TmpClip[id] == -1)
	{
		return HAM_IGNORED
	}
	
	set_pdata_int(weapon_entity, m_iClip, g_b1_TmpClip[id], 4, 5)
	set_pdata_float(id, m_flNextAttack, gMode[id] ? 3.0 : 2.2, 5, 5)
	set_pdata_int(weapon_entity, m_fInReload, 1, 4, 5)
	UTIL_PlayWeaponAnimation(id, gMode[id] ? Animation_ReloadB : Animation_Reload)
	gMode[id] = 0
	return HAM_IGNORED
}