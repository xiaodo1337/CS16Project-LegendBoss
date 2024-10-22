#include <amxmodx>
#include <hamsandwich>
#include <engine>
#include <fakemeta_util>
#include <cstrike>
#include <bossmode>

#pragma tabsize 4

new m_pPlayer = 41
new m_fInReload = 54
new m_flNextAttack = 83
new m_pActiveItem = 373 // CBasePlayerItem *
// CWeaponBox
new m_rgpPlayerItems2[6] = { 34, 35, 36, 37, 38, 39 } // CBasePlayerItem *

#define WEAPON_NAME "weapon_m249"
#define CSW_WEAPON CSW_M249
#define WEAPON_KEY 78116

new g_had_at4cs[33], Float:g_nextaim[33], Float:g_canfire[33], g_zoom[33], g_smoke_id, g_spr_trail, g_spr_exp, cvar_radius, cvar_maxdamage, g_itemid, g_iClip;

new v_model[] = "models/legend/v_at4ex.mdl"
new p_model[] = "models/legend/p_at4ex.mdl"
new w_model[] = "models/legend/w_at4ex.mdl"
new s_model[] = "models/legend/s_rocket.mdl"

new at4cs_sound[5][] =
{
	"weapons/at4-1.wav",
	"weapons/at4_draw.wav",
	"weapons/at4_clipin1.wav",
	"weapons/at4_clipin2.wav",
	"weapons/at4_clipin3.wav"
}

public plugin_init()
{
	register_plugin("AT4CS", "1.0", "xiaodo");

	register_think("at4ex_rocket", "fw_rocket_think")
	register_touch("at4ex_rocket", "*", "fw_rocket_touch")

	register_event("CurWeapon", "event_curweapon", "be", "1=1")
	register_event("HLTV", "event_newround", "a", "1=0", "2=0")

	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_EmitSound, "fw_EmitSound")
    
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_NAME, "fw_AddToPlayer", 1)
	RegisterHam(Ham_Item_PostFrame, WEAPON_NAME, "fw_ItemPostFrame")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_NAME, "fw_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_NAME, "fw_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "fw_WeaponReload")
	RegisterHam(Ham_Weapon_Reload, WEAPON_NAME, "fw_WeaponReload_Post", 1)

	cvar_radius = register_cvar("at4cs_radius", "200.0")
	cvar_maxdamage = register_cvar("at4cs_maxdamage", "6000.0")
	register_clcmd("weapon_at4cs", "hook_weapon")
	g_itemid = bm_weapon_register("究極彗星AT4CS", "at4cs", TYPE_SPECIAL, 0, 500, 1, CSW_WEAPON, "")
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
	g_had_at4cs[id] = 0
    g_zoom[id] = 0
}

public hook_weapon(id)
{
	engclient_cmd(id, WEAPON_NAME)
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, v_model)
	engfunc(EngFunc_PrecacheModel, p_model)
	engfunc(EngFunc_PrecacheModel, w_model)
	engfunc(EngFunc_PrecacheModel, s_model)

	engfunc(EngFunc_PrecacheGeneric, "sprites/weapon_at4cs.txt")
	engfunc(EngFunc_PrecacheModel, "sprites/at4cs.spr")
	g_smoke_id = engfunc(EngFunc_PrecacheModel, "sprites/effects/rainsplash.spr")
	g_spr_trail = engfunc(EngFunc_PrecacheModel, "sprites/xbeam3.spr")
	g_spr_exp = engfunc(EngFunc_PrecacheModel, "sprites/zerogxplode.spr")

	for (new i;i < 5;i++)
	{
		engfunc(EngFunc_PrecacheSound, at4cs_sound[i])
	}
}

public weapon_buy(id)
{
	if (!is_user_alive(id))
	{
		return PLUGIN_CONTINUE
	}
	drop_weapons(id, 1)
	static at4cs;
    at4cs = fm_give_item(id, WEAPON_NAME)
	g_had_at4cs[id] = 1
    g_zoom[id] = 0
	cs_set_weapon_ammo(at4cs, 1)
	cs_set_user_bpammo(id, CSW_WEAPON, 10)
	return PLUGIN_CONTINUE
}

public event_newround()
{
	fm_remove_entity_name("at4ex_rocket")
}

public event_curweapon(id)
{
	if (!is_user_alive(id) || !is_user_connected(id) || !g_had_at4cs[id] || read_data(2) != CSW_WEAPON)
	{
		return PLUGIN_HANDLED
	}
    g_zoom[id] = 0
	entity_set_string(id, EV_SZ_viewmodel, v_model)
	entity_set_string(id, EV_SZ_weaponmodel, p_model)
    new weapon = get_pdata_cbase(id, m_pActiveItem)
    set_pdata_int(weapon, m_fInReload, 0, 4)
	return PLUGIN_CONTINUE
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(get_user_weapon(id) == CSW_WEAPON && g_had_at4cs[id] && is_user_alive(id) && is_user_connected(id))
	{
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001)
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public fw_AddToPlayer(ent, id)
{
	if (!is_valid_ent(ent) || !is_user_alive(id))
	{
		return HAM_IGNORED
	}
	if (entity_get_int(ent, EV_INT_impulse) == WEAPON_KEY)
	{
		g_had_at4cs[id] = 1
		entity_set_int(ent, EV_INT_impulse, 0)
		return HAM_HANDLED
	}
	if (g_had_at4cs[id])
	{
		message_begin(MSG_ONE, get_user_msgid("WeaponList"), _, id)
		write_string("weapon_at4cs")    //string	WeaponName
		write_byte(3)                   //byte	PrimaryAmmoID
		write_byte(1)                   //byte	PrimaryAmmoMaxAmount
		write_byte(-1)                  //byte	SecondaryAmmoID
		write_byte(-1)                  //byte	SecondaryAmmoMaxAmount
		write_byte(0)                   //byte	SlotID
		write_byte(4)                   //byte	NumberInSlot
		write_byte(CSW_WEAPON)          //byte	WeaponID
		write_byte(0)                   //byte	Flags
		message_end()
	}
	return HAM_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if (!is_user_alive(id) || !is_user_connected(id) || get_user_weapon(id) != CSW_WEAPON || !g_had_at4cs[id])
	{
		return FMRES_IGNORED
	}

	static CurButton, Weapon
	CurButton = get_uc(uc_handle, UC_Buttons)
    Weapon = get_pdata_cbase(id, m_pActiveItem)
	new Float:flNextAttack = get_pdata_float(id, m_flNextAttack)
	new fInReload = get_pdata_int(Weapon, m_fInReload, 4)
	if (CurButton & IN_ATTACK2 && entity_get_int(id, EV_INT_oldbuttons) & IN_ATTACK2)
	{
		if (get_gametime() > g_nextaim[id] && flNextAttack <= 0.0 && !fInReload && cs_get_weapon_ammo(Weapon) > 0)
		{
			if (g_zoom[id])
			{
                g_zoom[id] = 0
				cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
			}
			else
			{
                g_zoom[id] = 1
				cs_set_user_zoom(id, CS_SET_FIRST_ZOOM, 1)
			}
			g_nextaim[id] = get_gametime() + 0.5
		}
	}
	//CurButton -= IN_ATTACK
	//set_uc(uc_handle, UC_Buttons, CurButton)
	//CurButton -= IN_RELOAD
	//set_uc(uc_handle, UC_Buttons, CurButton)
	return FMRES_HANDLED
}

public fw_SetModel(ent, model[])
{
	if (!is_valid_ent(ent))
	{
		return FMRES_IGNORED
	}
	static szClassName[33]
	entity_get_string(ent, EV_SZ_classname, szClassName, charsmax(szClassName))
	if (!equal(szClassName, "weaponbox"))
	{
		return FMRES_IGNORED
	}
	static iOwner;
	iOwner = entity_get_edict(ent, EV_ENT_owner)
	if (equal(model, "models/w_m249.mdl"))
	{
		static at4cs;
		at4cs = get_pdata_cbase(ent, m_rgpPlayerItems2[1], 4)
		if (g_had_at4cs[iOwner] && is_valid_ent(at4cs))
		{
			entity_set_int(at4cs, EV_INT_impulse, WEAPON_KEY)
			g_had_at4cs[iOwner] = 0
			entity_set_model(ent, w_model)
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}


public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flag, pitch)
{
    if (sample[0] == 'w' && sample[8] == 'd' && sample[9] == 'r' && sample[10] == 'y' && get_gametime() < g_canfire[id])
    {
        return FMRES_SUPERCEDE
    }
    return FMRES_IGNORED
}

public fw_ItemPostFrame(ent)
{
	new id = entity_get_edict(ent, EV_ENT_owner)
	if (!is_user_alive(id) || !is_user_connected(id) || !g_had_at4cs[id])
	{
		return HAM_IGNORED
	}
	new Float:flNextAttack = get_pdata_float(id, m_flNextAttack)
	new fInReload = get_pdata_int(ent, m_fInReload, 4)

    if (fInReload && flNextAttack <= 0.0)
    {
	    cs_set_weapon_ammo(ent, 1)
	    cs_set_user_bpammo(id, CSW_WEAPON, cs_get_user_bpammo(id, CSW_WEAPON) - 1)
        set_pdata_int(ent, m_fInReload, 0, 4)
    }
	return HAM_IGNORED
}

public fw_PrimaryAttack(Weapon)
{
	new Player = get_pdata_cbase(Weapon, m_pPlayer, 4)
	if (!is_user_alive(Player) || !is_user_connected(Player) || !g_had_at4cs[Player])
	{
		return HAM_IGNORED
	}
    g_iClip = cs_get_weapon_ammo(Weapon)
    if (g_iClip < 1 && get_gametime() > g_canfire[Player])
    {
        ExecuteHamB(Ham_Weapon_Reload, Weapon)
        return HAM_SUPERCEDE
    }
	return HAM_IGNORED
}

public fw_PrimaryAttack_Post(Weapon)
{
	new Player = get_pdata_cbase(Weapon, m_pPlayer, 4, 5)
	if (!is_user_alive(Player) || !is_user_connected(Player) || !g_had_at4cs[Player])
	{
		return HAM_IGNORED
	}
	if (g_iClip > 0)
	{
		create_rocket(Player)
		emit_sound(Player, CHAN_WEAPON, at4cs_sound[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		set_weapon_anim(Player, random_num(1, 2))
		new Float:Punch_Angles[3]
		Punch_Angles[0] -= 20.0
		entity_set_vector(Player, EV_VEC_punchangle, Punch_Angles)
        g_zoom[Player] = 0
		cs_set_user_zoom(Player, CS_RESET_ZOOM, 1)
        g_canfire[Player] = get_gametime() + 1.0
	}
	return HAM_IGNORED
}

public fw_WeaponReload(ent)     //自动换弹事件
{
	new id = entity_get_edict(ent, EV_ENT_owner)
	if (!is_user_alive(id) || !is_user_connected(id) || !g_had_at4cs[id])
	{
		return HAM_IGNORED
	}
    if (cs_get_user_bpammo(id, CSW_WEAPON) < 1 || cs_get_weapon_ammo(ent) >= 1 || get_gametime() < g_canfire[id])
    {
        return HAM_SUPERCEDE
    }
	return HAM_IGNORED
}

public fw_WeaponReload_Post(ent)     //自动/手动换弹事件
{
	new id = entity_get_edict(ent, EV_ENT_owner)
	if (!is_user_alive(id) || !is_user_connected(id) || !g_had_at4cs[id])
	{
		return HAM_IGNORED
	}
    if (cs_get_weapon_ammo(ent) < 1 && get_gametime() > g_canfire[id])
    {
        g_zoom[id] = 0
		cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
        set_pdata_float(id, m_flNextAttack, 4.0)
        set_pdata_int(ent, m_fInReload, 1, 4)
	    set_weapon_anim(id, 3)
    }
	return HAM_IGNORED
}

public create_rocket(id)
{
	new ent, Float:Origin[3], Float:Angles[3], Float:Velocity[3]
	ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	engfunc(EngFunc_GetAttachment, id, 0, Origin, Angles)
	entity_set_vector(ent, EV_VEC_origin, Origin)
	entity_get_vector(id, EV_VEC_angles, Angles)
	entity_set_vector(ent, EV_VEC_angles, Angles)
	entity_set_int(ent, EV_INT_solid, SOLID_BBOX)
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY)
	entity_set_string(ent, EV_SZ_classname, "at4ex_rocket")
	entity_set_edict(ent, EV_ENT_owner, id)
	engfunc(EngFunc_SetModel, ent, s_model)

	new Float:size[2][3] = {{-1.0, -1.0, -1.0}, {1.0, 1.0, 1.0}}
	entity_set_vector(ent, EV_VEC_mins, size[0])
	entity_set_vector(ent, EV_VEC_maxs, size[1])

	velocity_by_aim(id, 1750, Velocity)
	entity_set_vector(ent, EV_VEC_velocity, Velocity)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(ent)
	write_short(g_spr_trail)
	write_byte(25)
	write_byte(2)
	write_byte(255)
	write_byte(255)
	write_byte(255)
	write_byte(200)
	message_end()

	entity_set_int(ent, EV_INT_iuser4, 0)
	entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.1)
}

public fw_rocket_think(ent)
{
	if (!is_valid_ent(ent)) return PLUGIN_CONTINUE

	static Float:Origin[3]
	entity_get_vector(ent, EV_VEC_origin, Origin)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_SPRITE)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_smoke_id)
	write_byte(2)
	write_byte(200)
	message_end()

	static Victim
	Victim = entity_get_int(ent, EV_INT_iuser4)
	if (Victim)
	{
		if (is_user_alive(Victim))
		{
			static Float:VicOrigin[3];
			entity_get_vector(Victim, EV_VEC_origin, VicOrigin)
			turn_to_target(ent, Origin, Victim, VicOrigin)
			hook_ent(ent, Victim, 700.0)
		}
		entity_set_int(ent, EV_INT_iuser4, 0)
	}
	else
	{
		Victim = FindClosesEnemy(ent);
		if (is_user_alive(Victim)) entity_set_int(ent, EV_INT_iuser4, Victim)
	}
	entity_set_float(ent, EV_FL_nextthink, get_gametime() + 0.07)
    return PLUGIN_CONTINUE
}

public fw_rocket_touch(rocket, toucher)
{
	if(!is_valid_ent(rocket)) return PLUGIN_CONTINUE
	static owner
	owner = entity_get_edict(rocket, EV_ENT_owner)
	if (is_user_alive(toucher) && toucher == owner)
	{
		return PLUGIN_CONTINUE
	}
	static Float:Origin[3], iVictim;
	entity_get_vector(rocket, EV_VEC_origin, Origin)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_spr_exp)
	write_byte(20)
	write_byte(30)
	write_byte(0)
	message_end()
	iVictim = -1
	while ((iVictim = find_ent_in_sphere(iVictim, Origin, get_pcvar_float(cvar_radius))))
	{
		if (0 < iVictim <= get_maxplayers() && is_user_alive(iVictim) && owner != iVictim && bm_get_user_boss(iVictim) && !fm_get_user_godmode(iVictim))
		{
			ExecuteHamB(Ham_TakeDamage, iVictim, owner, owner, get_pcvar_float(cvar_maxdamage), DMG_BULLET)
		}
	}
	engfunc(EngFunc_RemoveEntity, rocket)
	return PLUGIN_CONTINUE
}

stock set_weapon_anim(id, anim)
{
	entity_set_int(id, EV_INT_weaponanim, anim)
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(entity_get_int(id, EV_INT_body))
	message_end()
}

stock FindClosesEnemy(entid)
{
	new Float:Dist, Float:maxdistance = 500.0, indexid, owner = entity_get_edict(entid, EV_ENT_owner)
	for(new i=1;i<=get_maxplayers();i++)
	{
		if(is_user_alive(i) && is_valid_ent(i) && can_see_fm(entid, i) && owner != i && cs_get_user_team(owner) != cs_get_user_team(i) && !bm_get_user_hide(i))
		{
			Dist = entity_range(entid, i)
			if(Dist <= maxdistance)
			{
				maxdistance=Dist
				indexid=i
				return indexid
			}
		}	
	}	
	return 0
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

stock turn_to_target(ent, Float:Ent_Origin[3], target, Float:Vic_Origin[3])
{
	if (target)
	{
		new Float:newAngle[3] = 0.0;
		new Float:x = floatsub(Vic_Origin[0], Ent_Origin[0]);
		new Float:z = floatsub(Vic_Origin[1], Ent_Origin[1]);
		new Float:radians = floatatan(z / x, 0)
		entity_get_vector(ent, EV_VEC_angles, newAngle);
		newAngle[1] = radians * (180 / 3.1415926)

		if (Vic_Origin[0] < Ent_Origin[0])
		{
			newAngle[1] -= 180.0
		}
		entity_set_vector(ent, EV_VEC_angles, newAngle);
	}
}

stock hook_ent(ent, victim, Float:speed)
{
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:VicOrigin[3], Float:distance_f;
	entity_get_vector(ent, EV_VEC_origin, EntOrigin)
	entity_get_vector(victim, EV_VEC_origin, VicOrigin)
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	if (distance_f > 10.0)
	{
		new Float:fl_Time = distance_f / speed
		fl_Velocity[0] = (VicOrigin[0] - EntOrigin[0]) / fl_Time
		fl_Velocity[1] = (VicOrigin[1] - EntOrigin[1]) / fl_Time
		fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time
	}
	else
	{
		fl_Velocity[0] = 0.0;
		fl_Velocity[1] = 0.0;
		fl_Velocity[2] = 0.0;
	}
	entity_set_vector(ent, EV_VEC_velocity, fl_Velocity)
}