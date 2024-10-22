#include <amxmodx>
#include <engine>
#include <fun>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <bossmode>

#pragma tabsize 4

#define CSW_WEAPON CSW_AWP
#define WEAPON_NAME "weapon_awp"
#define WEAPON_KEY 67102

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT,
	ANIM_DRAW
}

new m_pPlayer = 41
new m_flNextPrimaryAttack = 46
new m_flNextSecondaryAttack = 47 // float
new m_flTimeWeaponIdle = 48 // float
new m_flNextAttack = 83
new m_rgpPlayerItems2[6] = { 34, 35, 36, 37, 38, 39 } // CBasePlayerItem *

new v_model[] = "models/legend/v_sfsniper2.mdl"
new p_model[] = "models/legend/p_sfsniper.mdl"
new w_model[] = "models/legend/w_sfsniper.mdl"

new weapon_sound[3][] =
{
	"weapons/sfsniper-1.wav",
	"weapons/sfsniper_idle.wav",
	"weapons/sfsniper_draw.wav"
}

new g_had_thunderbolt[33], g_thunderbolt_ammo[33], Float:StartOrigin2[3], Float:EndOrigin2[3], Float:g_thunderbolt_zoomdelay[33], g_old_weapon[33], 
g_smokepuff_id, m_iBlood[2], g_scope_hud, g_Beam_SprId, Float:g_can_laser[33], g_itemid;

public plugin_init()
{
	register_plugin("CSO Thunderbolt", "1.0", "xiaodo")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)

	RegisterHam(Ham_Item_AddToPlayer, WEAPON_NAME, "fw_AddToPlayer")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_NAME, "fw_PrimaryAttack")
	RegisterHam(Ham_Weapon_SecondaryAttack, WEAPON_NAME, "fw_SecondaryAttack_Post", 1)

	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack2")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Post", 1)

	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	g_scope_hud = CreateHudSyncObj()
	g_itemid = bm_weapon_register("神器-準雷", "thunderbolt", TYPE_SPECIAL, 0, 1500, 1, CSW_WEAPON, "")
}

public plugin_precache()
{
	precache_model(v_model)
	precache_model(p_model)
	precache_model(w_model)
	for (new i;i < sizeof(weapon_sound);i++)
	{
		precache_sound(weapon_sound[i])
	}
	g_smokepuff_id = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")
	g_Beam_SprId = precache_model("sprites/laserbeam.spr")
}

public bm_weapon_bought(id, itemid)
{
    if (itemid == g_itemid)
    {
        get_thunderbolt(id)
    }
}

public bm_weapon_remove(id)
{
	g_had_thunderbolt[id] = 0
}

public get_thunderbolt(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	drop_weapons(id, 1)
	g_had_thunderbolt[id] = 1
	g_thunderbolt_ammo[id] = 20
	new weapon_ent = fm_give_item(id, WEAPON_NAME)
	//weapon_ent = fm_find_ent_by_owner(-1, WEAPON_NAME, id);
	if (is_valid_ent(weapon_ent))
	{
		cs_set_weapon_ammo(weapon_ent, 1);
	}
	return PLUGIN_CONTINUE
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if (get_user_weapon(id) == CSW_WEAPON && g_had_thunderbolt[id] && is_user_alive(id) && is_user_connected(id))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public fw_AddToPlayer(ent, id)
{
	if (!is_valid_ent(ent) || !is_user_connected(id))
	{
		return HAM_IGNORED
	}
	if (entity_get_int(ent, EV_INT_impulse) == WEAPON_KEY)
	{
		g_thunderbolt_ammo[id] = entity_get_int(ent, EV_INT_iuser4)
		g_had_thunderbolt[id] = 1
		entity_set_int(ent, EV_INT_impulse, 0)
		return HAM_HANDLED
	}
	return HAM_IGNORED
}

public fw_PrimaryAttack(ent)
{
	new Player = get_pdata_cbase(ent, m_pPlayer, 4)
	if (!is_user_alive(Player) || !is_user_connected(Player) || !g_had_thunderbolt[Player])
	{
		return HAM_IGNORED
	}
	if (get_pdata_float(Player, m_flNextAttack) <= 0 && g_thunderbolt_ammo[Player] > 0)
	{
		set_weapon_anim(Player, ANIM_SHOOT)
		emit_sound(Player, CHAN_WEAPON, weapon_sound[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		update_ammo(Player)
		Stock_Get_Postion(Player, 50.0, 10.0, 5.0, StartOrigin2)
		set_task(0.1, "Create_Laser", Player)
		//static weapon_ent
		//weapon_ent = fm_find_ent_by_owner(-1, WEAPON_NAME, Player)
		//if (is_valid_ent(weapon_ent))
		//{
		//	ExecuteHamB(Ham_Weapon_PrimaryAttack, weapon_ent)
		//}
		set_player_nextattack(Player, CSW_WEAPON, 2.67)
		cs_set_user_zoom(Player, CS_SET_NO_ZOOM, 1)
		set_hudmessage(0, 200, 0, -1.0, -1.0, 0, 0.1, 0.1, 0.1, 0.2, 4)
		ShowSyncHudMsg(Player, g_scope_hud, "")
		return HAM_IGNORED
	}
	return HAM_SUPERCEDE
}

public fw_SecondaryAttack_Post(ent)
{
	new Player = get_pdata_cbase(ent, m_pPlayer, 4)
	if (!is_user_alive(Player) || !is_user_connected(Player) || !g_had_thunderbolt[Player])
	{
		return HAM_IGNORED
	}
	if (cs_get_user_zoom(Player) == CS_SET_SECOND_ZOOM)
	{
		cs_set_user_zoom(Player, CS_SET_NO_ZOOM, 1)
	}
	return HAM_IGNORED
}

public Event_CurWeapon(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	if (get_user_weapon(id) == CSW_WEAPON && g_had_thunderbolt[id])
	{
		entity_set_string(id, EV_SZ_viewmodel, (cs_get_user_zoom(id) == CS_SET_NO_ZOOM) ? v_model : "")
		entity_set_string(id, EV_SZ_weaponmodel, p_model)
		if (g_old_weapon[id] != CSW_WEAPON)
		{
			set_weapon_anim(id, ANIM_DRAW)
		}
		update_ammo(id)
	}
	g_old_weapon[id] = get_user_weapon(id)
	return PLUGIN_CONTINUE
}

public fw_CmdStart(id, uc_handle, seed)
{
	if (!is_user_alive(id) || !is_user_connected(id) || get_user_weapon(id) != CSW_WEAPON || !g_had_thunderbolt[id])
	{
		return FMRES_IGNORED
	}
	if (get_gametime() > g_thunderbolt_zoomdelay[id])
	{
		if (cs_get_user_zoom(id) == CS_SET_FIRST_ZOOM)
		{
			static Target, Body
			get_user_aiming(id, Target, Body, 99999999)
			if (!is_user_alive(Target))
			{
				set_hudmessage(0, 200, 0, -1.0, -1.0, 0, 0.1, 0.1, 0.1, 0.2, 4)
			}
			else
			{
				set_hudmessage(255, 0, 0, -1.0, -1.0, 0, 0.1, 0.1, 0.1, 0.2, 4)
			}
			ShowSyncHudMsg(id, g_scope_hud, "|\n-- + --\n|")
		}
		else
		{
			set_hudmessage(0, 200, 0, -1.0, -1.0, 0, 0.1, 0.1, 0.1, 0.2, 4);
			ShowSyncHudMsg(id, g_scope_hud, "");
		}
		g_thunderbolt_zoomdelay[id] = get_gametime() + 0.1
	}
	return FMRES_HANDLED
}

public Create_Laser(id)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY, _, 0)
	write_byte(TE_BEAMPOINTS)	// write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, StartOrigin2[0])	// write_coord(startposition.x)
	engfunc(EngFunc_WriteCoord, StartOrigin2[1])	// write_coord(startposition.y)
	engfunc(EngFunc_WriteCoord, StartOrigin2[2] - 10.0)	// write_coord(startposition.z)
	engfunc(EngFunc_WriteCoord, EndOrigin2[0])	// write_coord(endposition.x)
	engfunc(EngFunc_WriteCoord, EndOrigin2[1])	// write_coord(endposition.y)
	engfunc(EngFunc_WriteCoord, EndOrigin2[2])	// write_coord(endposition.z)
	write_short(g_Beam_SprId)	// write_short(sprite index) 
	write_byte(0)	// write_byte(starting frame) 
	write_byte(0)	// write_byte(frame rate in 0.1's) 
	write_byte(30)	// write_byte(life in 0.1's) 
	write_byte(25)	// write_byte(line width in 0.1's) 
	write_byte(0)	// write_byte(noise amplitude in 0.01's) 
	write_byte(0)	// write_byte(red)
	write_byte(0)	// write_byte(green)
	write_byte(255)	// write_byte(blue)
	write_byte(255)	// write_byte(brightness)
	write_byte(0)	// write_byte(scroll speed in 0.1's)
	message_end()
}

public fw_SetModel(entity, model[])
{
	if (!is_valid_ent(entity))
	{
		return FMRES_IGNORED
	}
	static Classname[64];
	entity_get_string(entity, EV_SZ_classname, Classname, charsmax(Classname))
	if (!equal(Classname, "weaponbox"))
	{
		return FMRES_IGNORED
	}
	static id
	id = entity_get_edict(entity, EV_ENT_owner)
	if (equal(model, "models/w_awp.mdl"))
	{
		static weapon;
		weapon = get_pdata_cbase(entity, m_rgpPlayerItems2[1], 4)
		//weapon = fm_get_user_weapon_entity(entity, CSW_WEAPON);
		if (g_had_thunderbolt[id] && is_valid_ent(weapon))
		{
			entity_set_int(weapon, EV_INT_impulse, WEAPON_KEY)
			engfunc(EngFunc_SetModel, entity, w_model)
			entity_set_int(weapon, EV_INT_iuser4, g_thunderbolt_ammo[id])
			g_thunderbolt_ammo[id] = 0
			g_had_thunderbolt[id] = 0
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public fw_TraceAttack(ent, attacker, Float:Damage, Float:fDir[3], ptr, iDamageType)
{
	if (!is_user_alive(attacker) || !bm_get_user_boss(ent) || get_user_godmode(ent) || get_user_weapon(attacker) != CSW_WEAPON || !g_had_thunderbolt[attacker])
	{
		return HAM_IGNORED
	}
	static Float:flEnd[3]
	get_tr2(ptr, TR_EndPos, flEnd)
	if (is_user_alive(ent))
	{
		create_blood(flEnd)
	}
	if (bm_get_mode() != MODE_ESCAPE)
	{
		ExecuteHamB(Ham_TakeDamage, ent, attacker, attacker, 7000.0, DMG_BULLET)
	}
	else
	{
		ExecuteHamB(Ham_TakeDamage, ent, attacker, attacker, 7000.0 * 2.0, DMG_BULLET)
	}
	return HAM_HANDLED
}

public fw_TraceAttack_Post(ent, attacker, Float:Damage, Float:fDir[3], ptr, iDamageType)
{
	if (get_user_weapon(attacker) != CSW_WEAPON || !g_had_thunderbolt[attacker] || !is_user_alive(attacker))
	{
		return HAM_IGNORED
	}
	static Float:flEnd[3]
	get_tr2(ptr, TR_EndPos, flEnd)
	EndOrigin2 = flEnd
	return HAM_HANDLED
}

public fw_TraceAttack2(ent, attacker, Float:Damage, Float:fDir[3], ptr, iDamageType)
{
	if (get_user_weapon(attacker) != CSW_WEAPON || !g_had_thunderbolt[attacker] || !is_user_alive(attacker))
	{
		return HAM_IGNORED
	}
	if (get_gametime() > g_can_laser[attacker])
	{
		static Float:flEnd[3]
		get_tr2(ptr, TR_EndPos, flEnd)
		EndOrigin2 = flEnd
		make_bullet(attacker, flEnd)
		fake_smoke(attacker, ptr)
		g_can_laser[attacker] = get_gametime() + 0.1
	}
	return HAM_HANDLED
}

public update_ammo(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	static weapon_ent
	weapon_ent = fm_find_ent_by_owner(-1, WEAPON_NAME, id)
	if (is_valid_ent(weapon_ent))
	{
		cs_set_weapon_ammo(weapon_ent, 1)
	}
	cs_set_user_bpammo(id, CSW_WEAPON, 0)

	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_WEAPON)
	write_byte(-1)
	message_end()

	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
	write_byte(1)
	write_byte(g_thunderbolt_ammo[id])
	message_end()

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

stock make_bullet(id, Float:Origin[3])
{
	new decal = random_num(41, 45);
	static Target, Body;
	get_user_aiming(id, Target, Body, 999999);
	if (is_user_connected(Target))
	{
		return PLUGIN_CONTINUE
	}
	
	for (new i;i < 2;i++)
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		write_byte(TE_WORLDDECAL);
		engfunc(EngFunc_WriteCoord, Origin[0]);
		engfunc(EngFunc_WriteCoord, Origin[1]);
		engfunc(EngFunc_WriteCoord, Origin[2]);
		write_byte(decal);
		message_end();
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
		write_byte(TE_GUNSHOTDECAL);
		engfunc(EngFunc_WriteCoord, Origin[0]);
		engfunc(EngFunc_WriteCoord, Origin[1]);
		engfunc(EngFunc_WriteCoord, Origin[2]);
		write_short(id);
		write_byte(decal);
		message_end();
	}
	return PLUGIN_CONTINUE
}

public fake_smoke(id, trace_result)
{
	static TE_FLAG, Float:vecEnd[3], Float:vecSrc[3];
	get_weapon_attachment(id, vecSrc, 40.0);
	global_get(glb_v_forward, vecEnd);
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd);
	xs_vec_add(vecSrc, vecEnd, vecEnd);
	get_tr2(trace_result, TR_EndPos, vecSrc);
	get_tr2(trace_result, TR_PlaneNormal, vecEnd);
	xs_vec_mul_scalar(vecEnd, 2.5, vecEnd);
	xs_vec_add(vecSrc, vecEnd, vecEnd);
	TE_FLAG = TE_FLAG | TE_EXPLFLAG_NODLIGHTS;
	TE_FLAG = TE_FLAG | TE_EXPLFLAG_NOSOUND;
	TE_FLAG = TE_FLAG | TE_EXPLFLAG_NOPARTICLES;
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord, vecEnd[0]);
	engfunc(EngFunc_WriteCoord, vecEnd[1]);
	engfunc(EngFunc_WriteCoord, vecEnd[2] - 10.0);
	write_short(g_smokepuff_id);
	write_byte(2);
	write_byte(50);
	write_byte(TE_FLAG);
	message_end();
}

stock Stock_Get_Postion(id, Float:forw, Float:right, Float:up, Float:vStart[])
{
	new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	entity_get_vector(id, EV_VEC_origin, vOrigin)
	entity_get_vector(id, EV_VEC_view_ofs, vUp)
	xs_vec_add(vOrigin, vUp, vOrigin)
	entity_get_vector(id, EV_VEC_v_angle, vAngle)
	angle_vector(vAngle, ANGLEVECTOR_FORWARD, vForward)
	angle_vector(vAngle, ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle, ANGLEVECTOR_UP, vUp)
	vStart[0] = (vOrigin[0] + vForward[0] * forw) + (vRight[0] * right) + (vUp[0] * up)
	vStart[1] = (vOrigin[1] + vForward[1] * forw) + (vRight[1] * right) + (vUp[1] * up)
	vStart[2] = (vOrigin[2] + vForward[2] * forw) + (vRight[2] * right) + (vUp[2] * up)
}

get_weapon_attachment(id, Float:output[3], Float:fDis)
{
	new Float:vfEnd[3] = 0.0, viEnd[3], Float:fOrigin[3] = 0.0, Float:fAngle[3] = 0.0, Float:fAttack[3] = 0.0
	get_user_origin(id, viEnd, 3)
	IVecFVec(viEnd, vfEnd)
	entity_get_vector(id, EV_VEC_origin, fOrigin)
	entity_get_vector(id, EV_VEC_view_ofs, fAngle)
	xs_vec_add(fOrigin, fAngle, fOrigin)
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	new Float:fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	xs_vec_add(fOrigin, fAttack, output)
}

stock create_blood(Float:origin[3])
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BLOODSPRITE)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2])
	write_short(m_iBlood[1])
	write_short(m_iBlood[0])
	write_byte(bm_get_boss_blood_color())
	write_byte(5)
	message_end()
}

stock set_player_nextattack(player, weapon_id, Float:NextTime)
{
	if (!is_user_alive(player))
	{
		return PLUGIN_CONTINUE
	}
	static weapon
	weapon = fm_get_user_weapon_entity(player, weapon_id)
	set_pdata_float(player, m_flNextAttack, NextTime)
	if (is_valid_ent(weapon))
	{
		set_pdata_float(weapon, m_flNextPrimaryAttack, NextTime, 4, 5)
		set_pdata_float(weapon, m_flNextSecondaryAttack, NextTime, 4, 5)
		set_pdata_float(weapon, m_flTimeWeaponIdle, NextTime, 4, 5)
	}
	return PLUGIN_CONTINUE
}
