#pragma tabsize 4
#pragma compress 1

#include <amxmodx>
#include <cstrike>
#include <fun>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <json>
#include <nvault>

#include <bossmode>
#include <cs_player_models_api>
#include <round_terminator>

#include <account_system>

#define _DEBUG
//#define _ENABLE_WEB_AUTH
#if defined _ENABLE_WEB_AUTH
#include <httpx>
new const KEY[][] = 
{
	"no_amxx_uncompress",
	"8a91f910d8ea016829cb5d21fa",
	"mKkp8e07fRjKl0JQ"
}
new timestamp, retry_time
#endif

//"DeathMsg" = 4
//"" = 3

enum (+= 125)
{
	TASK_SHOWHUD = 3000,
	TASK_RELOAD,
	TASK_NOTICE,
	TASK_NIGHTVISION,
	TASK_ANTIRESPAWN,
	TASK_VIRUS,
	TASK_EXPX2,
	TASK_RESPAWNPLAYER,
	TASK_TEAM,
	TASK_BOSS_SOUND
}

enum
{
	WEP_TYPE_OTHERS = 0,
	WEP_TYPE_PISTOL,
	WEP_TYPE_SHOTGUN,
	WEP_TYPE_SMG,
	WEP_TYPE_RIFLE
}

#define PLUGIN_NAME "魔王"
#define PLUGIN_VERSION "3.0"
#define PLUGIN_AUTHOR "xiaodo"

#define MAX_WEAPONS 128
#define MAX_SKINS 7

#define BOSS_BLOOD_COLOR 241	//魔王血液颜色 (241 : 黄色)
#define MINIMUM_PLAYER 2		//最少需要多少玩家才能开始游戏
#define DEFAULT_BAG_SPACE 10	//默认玩家有多大的背包容量
#define TASKS_NUM 41			//任务数量
#define MAX_TAKE_TASK_NUM 5		//最大同时可接多少任务, 1757行需要修改按键注册

#define MAX_WEP_EXP_MUL 100		//最大武器经验值基于原等级的倍数 (最大经验值=武器当前等级 * 倍数)
#define MAX_EXP_MUL 100			//最大经验值基于原等级的倍数 (最大经验值=玩家当前等级 * 玩家当前等级 * 倍数)
#define MAX_LEVEL 2000			//玩家最大等级限制
#define MAX_WEAPON_LEVEL 200	//武器最大等级限制

#define DAMAGE_PLAYER_EXP 100	//每当伤害满足时，添加的玩家经验值
#define DAMAGE_PLAYER_SP 1		//每当伤害满足时，添加的SP
#define DAMAGE_WEAPON_EXP 1		//每当伤害满足时，添加的武器经验值

#define HUMAN_KILLED_EXP 200	//魔王杀死一名人类所获得的经验值
#define HUMAN_KILLED_SP 1		//魔王杀死一名人类所获得的SP
#define LEADER_KILLED_EXP 1000	//魔王杀死一名LEADER所获得的经验值

#define ITEM_CAN_USE_TIMES 3	//物品可以使用几次

/*
任务系统:
g_doing1[玩家索引][任务槽位] -> 任务索引
g_doing2[玩家索引][任务槽位] -> 已完成的任务目标
g_doing3[玩家索引][任务槽位] -> 剩余任务目标
g_taskdone[玩家索引][任务索引] -> 任务完成且不可再做则为1 反之为0
--------------------------------------------------*/

/*--------------------------------------------------
			函数说明
任务系统:
task_doing(玩家索引, 任务种类, 要增加的完成目标, 要减少的剩余目标, 伤害) -> 增加任务进度
--------------------------------------------------*/
new g_logfile[1000]

new const WEAPONNAMES_SIMPLE[][] = { "", "P228", "", "Scout", "", "XM1014", "", "MAC10", "AUG",
	"", "Dual Elite", "FiveSeven", "UMP45", "SG550", "Galil", "Famas",
	"USP", "Glock-18", "AWP", "MP5", "M249",
	"M3", "M4A1", "TMP", "G3SG1", "", "Deagle",
	"SG552", "AK47", "", "P90"
}
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
	"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
	"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
	"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
	"weapon_ak47", "weapon_knife", "weapon_p90"
}
new const CSW_MAXBPAMMO[] = { -1, 200, -1, 200, 1, 200, 1, 200, 200, 1, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 200, 2, 200, 200, 200, -1, 200, -1, -1 }
new const g_objective_ents[][] = { "func_bomb_target" , "info_bomb_target" , "info_vip_start" , "func_vip_safetyzone" , "func_escapezone" , "hostage_entity" , "monster_scientist" , "func_hostage_rescue" , "info_hostage_rescue"}

enum bag_system { BAG_ITEMNAME[64], BAG_ITEM_USEDMSG[256], BAG_ITEM_MENUTIPS[256], bool:BAG_ITEMCANUSE, bool:BAG_ITEMMUSTALIVE, bool:BAG_ITEMUSELIMIT }
new const g_BagItem[21][bag_system] = 
{
	{"空白", "", "", false, false, false},
	{"香蕉", "您已回复 100 生命值", "回复 100 生命值", true, true, true},
	{"蛋糕", "您已回复 150 生命值", "回复 150 生命值", true, true, true},
	{"紅色蘋果", "您已回复 200 生命值", "回复 200 生命值", true, true, true},
	{"攻擊寶石", "您已获得双倍伤害 (一回合)", "双倍伤害 (一回合)", true, true, true},
	{"速度寶石", "您已获得速度提升 (一回合)", "速度提升 (一回合)", true, true, true},
	{"等级20奖励箱", "您已获得 20000 EXP, 100 SP", "获得 20000 EXP 和 100 SP", true, false, false},
	{"神秘奖励箱", "??????", "????????", true, false, false},
	{"等级40奖励箱", "您已获得 40000 EXP, 速度寶石 x 2 个", "40000 EXP, 速度寶石 x 2 个", true, false, false},
	{"等级60奖励箱", "您已获得 60000 EXP、紅色蘋果 x 5 个", "60000 EXP, 紅色蘋果 x 5 个", true, false, false},
	{"等级80奖励箱", "您已获得 80000 EXP、紅色蘋果 x 10 个", "80000 EXP、紅色蘋果 x 10 个", true, false, false},
	{"等级100奖励箱", "您已获得 100000 EXP、1000 SP", "100000 EXP、1000 SP", true, false, false},
	{"雙倍經驗 (1小時)", "您已使用 雙倍經驗 (1小時)", "經驗雙倍 1 小時", true, false, false},
	{"大薯條", "您已回复 150 生命值", "回复 150 生命值", true, true, true},
	{"大汽水", "您已回复 180 生命值", "回复 180 生命值", true, true, true},
	{"大麥樂雞", "您已回复 100 生命值", "回复 100 生命值", true, true, true},
	{"大脆香雞翼", "您已回复 130 生命值", "回复 130 生命值", true, true, true},
	{"大漢堡", "您已回复 200 生命值", "回复 200 生命值", true, true, true},
	{"SP槍免費卡 (一回合)", "您已获得免費 SP 槍 (一回合)", "免費 SP 槍 (一回合)", true, false, true},
	{"特別槍免費卡 (一回合)", "您已获得免費特別槍 (一回合)", "免費特別槍 (一回合)", true, false, true},
	{"Error: Invalid Help", "", "", false, false, false}
}

new g_MsgSync, g_MsgSync2, g_MsgSync3, g_MsgSync4, g_MsgSync5

/*--------------------------------------------------
				变量说明
背包系统:
g_BagItem[物品索引][BAG_ITEMNAME 物品名 / BAG_ITEM_USEDMSG 使用信息 / BAG_ITEM_MENUTIPS 作用 / bool:BAG_ITEMCANUSE 是否可用 / bool:BAG_ITEMMUSTALIVE 必须存活才可使用] -> 返回对应信息
*/

enum Base_Struct
{
	GunLevel[31], GunXP[31], Weapon, DataLoaded, 
	Level, SP, XP, Coupon, Gash, Combo[2],	//0是當前Combo, 1是所需Combo
	Reload, 
	Virus, Hide, Status, Boss, Leader, RespawnCount
}

enum Bag_Struct
{
	Index[40],
	Amount[40],
	Increase,
	UseLimit,
	bool:SPCard,
	bool:PowerCard,
	bool:AttackGem,
	bool:SpeedGem
}

enum Job_Ability_Struct
{

}

enum PlayerVars
{
	Base[Base_Struct],
	Bag[Bag_Struct]
}

new g_Player[33][PlayerVars]

enum DamageType
{
	Float:ItemDrop, Float:Rank, Float:Skill, Float:Skin, Float:Task[3]
}

enum PlayerVarsFloat
{
	Float:Damage[DamageType]
}

new Float:g_PlayerFloat[33][PlayerVarsFloat]

new g_random, bool:g_require_to_play, g_endround, g_humanwin, g_mode, g_min, g_sec, 
g_bosswin, g_difficult, g_antirespawn, g_startround, g_twoboss, g_bossSpr, g_humanhide, 
limit_addhp[33], g_nvision[33], g_nvisionenabled[33], skilled[33][4], 
exp_x2[33], exp_x2_time[33], g_setspeed[33], timer[33],
g_gboost[33], g_maxplayers, g_keyconfig[33], 
g_critical_knife[33], g_headshoot[33], g_headshot[33], limit_skill[33][4], 
g_job[33], job_skill[33][12], g_skpoint[33], max_hp[33], max_speed[33], max_damage[33], max_jump[33], 

g_WeaponCount, WeaponName[MAX_WEAPONS][64], WeaponSaveName[MAX_WEAPONS][32], WeaponType[MAX_WEAPONS], WeaponCostSP[MAX_WEAPONS], WeaponCostGash[MAX_WEAPONS], WeaponBasedOn[MAX_WEAPONS], WeaponLevel[MAX_WEAPONS], WeaponCommit[MAX_WEAPONS][128],  
g_UnlockedWeapon[33][MAX_WEAPONS], g_SelectedWeapon[33][3], g_SelectedPri[33], g_SelectedSec[33], g_SelectedMelee[33], g_SelectedSkins[33]

//Forward
new g_fwResult, g_fwWeaponBought, g_fwWeaponRemove, g_fwUserToBoss, g_fwUserToHuman;

new g_doing1[33][MAX_TAKE_TASK_NUM], g_doing2[33][MAX_TAKE_TASK_NUM], g_doing3[33][MAX_TAKE_TASK_NUM], g_task_done[33][TASKS_NUM], g_checkhealth[33]
enum task_system { TASK_NAME[64], TASK_HELP[256], TASK_HELP2[256], TASK_LEVEL, TASK_XP, TASK_SP, TASK_CLASS, TASK_DOING3NUM, bool:TASK_REPEAT }
new g_tasklist[TASKS_NUM][task_system] = 
{
	{"", "", "", 0, 0, 0, 0, 0, false},
	{"开关之路", "完全不受到魔王的攻击下^n伤害魔王 100000 血量", "SP枪免费卡（一回合）x 10、80 SP", 20, 0, 80, 1, 100000, true},
	{"收藏家", "伤害魔王并收集魔王之鳞 4 个^n掉落率和物品一样", "40000 经验值、80 SP", 40, 40000, 80, 2, 4, true},
	{"生存专家", "生存 60 个回合", "60000 经验值、30 SP", 60, 60000, 30, 3, 60, true},
	{"嗜血暴君", "在逃亡模式内击杀 50 个人类", "100000 经验值、50 SP", 80, 100000, 50, 4, 50, true},
	{"队长的荣誉", "作为 Leader 存活 5 次", "60000 经验值、50 SP", 100, 60000, 50, 5, 5, true},
	{"夺命双王", "与搭档清场 2 次", "30000 经验值、40 SP", 120, 30000, 40, 6, 2, true},
	{"逃出生天", "在 2/2 逃亡模式时存活 3 次", "30000经验值、60 SP", 140, 30000, 60, 7, 3, true},
	{"人类的希望", "在人类剩余 3 人或以下时存活 10 次", "60000 经验值、100 SP", 160, 60000, 100, 8, 10, true},
	{"魔王的怒啸", "于 2/2 变魔龙前清场 1 次", "50000 经验值、100 SP", 180, 50000, 100, 9, 1, true},
	{"枪枪致命", "连续在 2 回合内造成 150000 伤害", "20000 经验值、150 SP", 200, 20000, 150, 10, 2, true},
	{"生死差一线", "在逃亡模式内以 10 血或以下生存 10 次", "80000 经验值、200 SP", 220, 80000, 200, 11, 10, true},
	{"王者的血祭", "收集 Leader 血液 3 支^n掉落率低", "60000 经验值、300 SP", 240, 60000, 300, 12, 3, true},
	{"最佳拍档", "剩余 2 个人类下合作并生存 5 次", "40000 经验值、500 SP", 260, 40000, 500, 13, 5, true},
	{"运用自如", "1 个回合内以手枪造成 70000 伤害 5 次", "50000 经验值、70 SP", 280, 50000, 70, 14, 5, true},
	{"战无不胜", "胜利 200 次", "40000 经验值、400 SP", 300, 40000, 400, 15, 200, true},
	{"顶级杀手", "作为魔王成功 Combo 20 或以上 5 次", "80000 经验值、500 SP", 320, 80000, 500, 16, 5, true},
	{"团结制胜", "在逃亡模式内以剩余 15 个人类或以上生存^n(包括自己) 7 次", "80000 经验值、600 SP", 340, 80000, 600, 17, 7, true},
	{"血量控制", "魔王血量保持在 50%% 或以上并获胜 3 次", "90000 经验值、700 SP", 360, 90000, 700, 18, 3, true},
	{"绝处逢生", "在只剩自己的情况下生存并胜利 3 次", "100000 经验值、800 SP", 380, 100000, 800, 19, 3, true},
	{"越级挑战", "击杀 400 等级以上的人类 50 名", "150000 经验值、1000 SP", 400, 150000, 1000, 20, 50, true},
	{"到达等级20", "到达等级20", "等级20奖励箱 x1", 20, 0, 0, 21, 0, false},
	{"到达等级40", "到达等级40", "等级40奖励箱 x1", 40, 0, 0, 22, 0, false},
	{"到达等级60", "到达等级60", "等级60奖励箱 x1", 60, 0, 0, 23, 0, false},
	{"到达等级80", "到达等级80", "等级80奖励箱 x1", 80, 0, 0, 24, 0, false},
	{"到达等级100", "到达等级100", "等级100奖励箱 x1", 100, 0, 0, 25, 0, false},
	{"残杀人类计划", "击杀 10 个人类", "2000 经验值、20 SP", 0, 2000, 20, 26, 10, true},
	{"残杀人类计划2", "击杀 30 个人类", "5000 经验值、50 SP", 0, 5000, 50, 26, 30, true},
	{"残杀人类计划3", "击杀 60 个人类", "10000 经验值、100 SP", 0, 10000, 100, 26, 60, true},
	{"残杀人类计划4", "击杀 90 个人类", "15000 经验值、150 SP", 0, 15000, 150, 26, 90, true},
	{"残杀人类计划5", "击杀 150 个人类", "25000 经验值、250 SP", 0, 25000, 250, 26, 150, true},
	{"枪械集成伤害计划", "集成 50000 伤害", "1000 经验值、5 SP", 0, 1000, 5, 27, 50000, true},
	{"枪械集成伤害计划2", "集成 100000 伤害", "1500 经验值、10 SP", 0, 1500, 10, 27, 100000, true},
	{"枪械集成伤害计划3", "集成 170000 伤害", "2000 经验值、15 SP", 0, 2000, 15, 27, 170000, true},
	{"枪械集成伤害计划4", "集成 300000 伤害", "3000 经验值、20 SP", 0, 3000, 20, 27, 300000, true},
	{"枪械集成伤害计划5", "集成 500000 伤害", "3500 经验值、25 SP", 0, 3500, 25, 27, 500000, true},
	{"小刀集成伤害计划", "集成 50000 伤害", "2000 经验值、10 SP", 0, 2000, 10, 28, 50000, true},
	{"小刀集成伤害计划2", "集成 100000 伤害", "3000 经验值、20 SP", 0, 3000, 20, 28, 100000, true},
	{"小刀集成伤害计划3", "集成 170000 伤害", "4000 经验值、30 SP", 0, 4000, 30, 28, 170000, true},
	{"小刀集成伤害计划4", "集成 300000 伤害", "6000 经验值、40 SP", 0, 6000, 40, 28, 300000, true},
	{"小刀集成伤害计划5", "集成 500000 伤害", "7000 经验值、50 SP", 0, 7000, 50, 28, 500000, true}
}

enum skin_system_info { SKIN_HAVE, SKIN_EQUIPED, SKIN_CAPABLE }
enum skin_system { SKIN_MDLNAME[256], SKIN_MDLWITHT, SKIN_NAME[64], SKIN_NAME2[128], SKIN_COST }
new g_skin_info[33][MAX_SKINS][skin_system_info], g_skinlist[MAX_SKINS][skin_system] = {
	{"mcdonald", 0, "麥當勞叔叔", "有横會獲得特殊物品", 100},
	{"scream", 0, "驚聲尖叫", "傷害達到500補回1血", 100},
	{"ezio", 0, "刺客教條", "1.1倍等级&SP加速", 100},
	{"sawer", 0, "奪魂鋸", "增加重刀傷害4000", 100},
	{"miku", 1, "Miku初音ミク", "增加物品使用次數至6次", 100},
	{"blackROckShoter", 0, "BLACK ROCK SHOOTER", "增加1.1倍全部傷害", 100},
	{"azusa", 0, "中野梓", "逃亡速度提升至 280", 100}
}

#define ID_TEAM (taskid - TASK_TEAM)
new g_switchingteam // flag for whenever a player's team change emessage is sent
new Float:g_teams_targettime // for adding delays between Team Change messages
new g_respawning, g_msgTeamInfo
const PDATA_SAFE = 2
const OFFSET_CSTEAMS = 114
// CS Teams
enum
{
	FM_CS_TEAM_UNASSIGNED = 0,
	FM_CS_TEAM_T,
	FM_CS_TEAM_CT,
	FM_CS_TEAM_SPECTATOR
}
new const CS_TEAM_NAMES[][] = { "UNASSIGNED", "TERRORIST", "CT", "SPECTATOR" }

new const g_msgtype[3][] = {"物品", "物品", "物品"}
new const g_statusname[][] = { "良好", "正常", "良好", "不佳", "受伤", "濒死", "速度下降", "中毒", "精密射击", "小刀爆发", "伤害爆发", "隐身" }
new const g_modename[][] = { "对抗", "Leader", "逃亡" }
//const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
//const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

new const g_freewpnname[][] = { "MP5", "P90", "M3", "XM1014", "GALIL", "FAMAS", "AUG", "SG552", "M4A1", "AK47", "AWP", "G3SG1", "SG550", "M249" }
new const g_freewpnitem[][] = { "weapon_mp5navy", "weapon_p90", "weapon_m3", "weapon_xm1014", "weapon_galil", "weapon_famas", "weapon_aug", "weapon_sg552", "weapon_m4a1", "weapon_ak47", "weapon_awp", "weapon_g3sg1", "weapon_sg550", "weapon_m249" }

new leader_model[] = "boss_leader"
new const boss_detected_bgm[7][] = {
	"legend/gm_ambience_x.mp3",
	"legend/N2Boss_Detected2.mp3",
	"legend/proboss1.mp3",
	"legend/proboss2.mp3",
	"legend/proboss4.mp3",
	"legend/proboss5.mp3",
	"legend/prohblv2.mp3"
}
new const g_hunterlj[][] = { "legend/Hunter_LJump1.wav", "legend/Hunter_LJump2.wav" }
new const g_szZombieHit[][] = { "legend/claw_strike1.wav", "legend/claw_strike2.wav", "legend/claw_strike3.wav" }
new const g_szZombieMiss[][] = { "legend/claw_miss1.wav", "legend/claw_miss2.wav" }
new const g_szMonsterPain[][] = { "legend/tyrant_pain01.wav", "legend/tyrant_pain02.wav" }
new const g_szMonsterDie[][] = { "legend/zombi_death_1.wav", "legend/zombi_death_2.wav" }
new const ComboSound[][] = { "legend/combo1.wav", "legend/combo2.wav", "legend/combo3.wav" }
new const g_playerwin[] = "legend/Human_Win.wav"
new const g_zombiewin[][] = { "legend/Zombie_Win1.wav", "legend/Zombie_Win2.wav", "legend/Zombie_Win3.wav" }
new const g_boss_sound[] = "legend/boss_sound.wav"
new const g_speed[] = "legend/Zombie_GBoost.wav"
new const g_Hp[] = "legend/smallmedkit1.wav"

new const boss_model[][] = { "Godv2", "realboss", "skillsboss2" }
new const v_bossknife[][] = { "models/v_god1hand.mdl", "models/v_godv3hand2.mdl", "models/v_skillsboss.mdl" }

new ShopItem[33][5], ShopCost[33][5], ShopType[33][5], ShopNum[33][5], Gave_Sp[33], Check_Key[33], Check_Shop_No[33], Check_Shop_Line[33], Check_Admin_Shop_No[33], AdminShop[33]

new g_exchange[33][5], g_ready[33], g_exchangeNum[33][5], g_exchangeing[33], g_exchangeSp[33], g_exchangeOff[33], 
g_exchangeWpn[33][5], g_exchangeModel[33][5], g_exchangeKnife[33][5], g_exchangeType[33][5], MainName[33][32], 
TargetName[33][32], MainId[33], TargetId[33]

public plugin_init()
{
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)
	register_forward(FM_SetModel, "fw_SetWeapon")
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
	register_forward(FM_GetGameDescription, "fw_GameDescription")
	register_forward(FM_EmitSound, "Forward_EmitSound")
	register_forward(FM_ClientKill, "Forward_ClientKill")

	register_event("CurWeapon", "event_curweapon", "be", "1=1")
	register_event("HLTV", "round_start_pre", "a", "1=0", "2=0")
	register_logevent("round_start_post", 2, "1=Round_Start")
	register_logevent("logevent_round_end", 2, "1=Round_End")

	g_MsgSync = CreateHudSyncObj()
	g_MsgSync2 = CreateHudSyncObj()
	g_MsgSync3 = CreateHudSyncObj()
	g_MsgSync4 = CreateHudSyncObj()
	g_MsgSync5 = CreateHudSyncObj()

	register_clcmd("chooseteam", "clcmd_changeteam")
	register_clcmd("jointeam", "cmd_jointeam")
	register_clcmd("nightvision", "clcmd_nightvision")
	register_clcmd("drop", "clcmd_drop")
	register_clcmd("say /gun", "show_menu_choose")
	
	#if defined _DEBUG
	register_clcmd("say test", "clcmd_test")
	register_clcmd("say test2", "clcmd_test2")
	#endif

	RegisterHam(Ham_Spawn, "player", "Player_Spawn_Post", 1)
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_Killed, "player", "fw_PlayerKilled_Post", 1)
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_Touch, "weaponbox", "fw_TouchWeapon")
	RegisterHam(Ham_Touch, "armoury_entity", "fw_TouchWeapon")
	RegisterHam(Ham_Touch, "weapon_shield", "fw_TouchWeapon")

	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary")
	RegisterHam(Ham_Use, "func_tank", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "fw_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "fw_UseStationary_Post", 1)

	RegisterHam(Ham_BloodColor, "player", "Hook_BloodColor")

	register_message(get_user_msgid("Health"), "message_Health")
	register_message(get_user_msgid("TextMsg"), "msg_textmsg")
	register_message(get_user_msgid("NVGToggle"), "message_NVGToggle")
	g_msgTeamInfo = get_user_msgid("TeamInfo")
	register_message(g_msgTeamInfo, "message_teaminfo")
	register_message(get_user_msgid("StatusIcon"), "Message_StatusIcon")

	RegisterHam(Ham_TraceBleed, "player", "fw_TraceBleed")
	register_message(SVC_TEMPENTITY, "blood_message")
	
	register_menucmd(register_menuid("\r任務進度", 0), 1023, "menu_btaskdata")

	for(new i = 1;i < sizeof WEAPONENTNAMES;i++)
	{
		if (WEAPONENTNAMES[i][0])
		{
			RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "fw_Item_Deploy_Post", 1)
		}
	}

	set_task(0.5, "ShowHud", _, _, _, "b")
	set_task(1.0, "Time", _, _, _, "b")
	set_task(10.0, "lighting_effects", _, _, _, "b")
	set_task(15.0, "check_round_status", _, _, _, "b")

	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET)
	set_msg_block(get_user_msgid("RoundTime"), BLOCK_SET)

	g_fwWeaponBought = CreateMultiForward("bm_weapon_bought", ET_IGNORE, FP_CELL, FP_CELL)
	g_fwWeaponRemove = CreateMultiForward("bm_weapon_remove", ET_IGNORE, FP_CELL)
	g_fwUserToBoss = CreateMultiForward("bm_user_become_boss", ET_CONTINUE, FP_CELL)
	g_fwUserToHuman = CreateMultiForward("bm_user_become_human", ET_CONTINUE, FP_CELL)
	
	#if defined _ENABLE_WEB_AUTH
    HTTPX_Download("tptm.hd.mi.com/gettimestamp", _, "Get_TimeStamp", _, _, REQUEST_GET)
	#endif

	g_maxplayers = get_maxplayers()
}

#if defined _ENABLE_WEB_AUTH
new g_authid
public Get_TimeStamp(Index, Error)
{
    new Data[256];
    while (HTTPX_GetData(Data, charsmax(Data)))
    {
        if (Error != 0)
        {
            set_fail_state("验证失败")
            return
        }
        if(strlen(Data) > 1 && contain(Data, "servertime=") > 0)
        {
            new right[16]
            strtok(Data, "", 0, right, charsmax(right), '=')
            timestamp = str_to_num(right)
            HTTPX_AddPostVar("key", KEY[1]);
            g_authid = HTTPX_Download("---------------", _, "Auth", _, _, REQUEST_POST)
        }
        else
        {
            set_fail_state("验证失败")
            return
        }
    }
}

public HTTPX_Connect_Failed(const DownloadID)
{
	if(DownloadID == g_authid)
	{
    	set_fail_state("验证失败")
    	return
	}
    return
}

public Auth(Index, Error)
{
    new Data[256];
    while (HTTPX_GetData(Data, charsmax(Data)))
    {
        new JSON:object = json_parse(Data)
        if (object == Invalid_JSON || Error != 0)
        {
            set_fail_state("验证失败")
            return
        }
        new md5_web[64], md5_local[34], temp[128]
        json_object_get_string(object, "MD5", md5_web, charsmax(md5_web))
        new ys = timestamp % 3
        new md5tmstamp = (ys == 0 ? timestamp : timestamp-ys)
        format(temp, charsmax(temp), "%s%d%s", KEY[1], md5tmstamp, KEY[2])
        md5(temp, md5_local)
        if(equal(md5_local, md5_web))
        {
            new expires[6]
            json_object_get_string(object, "Expires", expires, charsmax(expires))
            if(equal(expires, "true"))
            {
                set_fail_state("验证过期")
                return
            }
        }
        else
        {
			if (retry_time < 3)
			{
				retry_time++
				set_task(1.2, "reauth")
				return
			}
            set_fail_state("校验不通过!")
            return
        }
    }
}

public reauth()
{
    HTTPX_Download("tptm.hd.mi.com/gettimestamp", _, "Get_TimeStamp", _, _, REQUEST_GET)
}
#endif

public hide_timer(id)
{
	message_begin(MSG_ONE, get_user_msgid("HideWeapon"), _, id)
	write_byte(1<<4)
	message_end()
}

#if defined _DEBUG
public clcmd_test(id)
{
	make_boss(id)
}

public clcmd_test2(id)
{
	g_Player[id][Base][XP]+=50000000
	g_skpoint[id]+=500
	g_Player[id][Base][Gash] += 5000
	add_bag_item2(id, 18, 5)
	add_bag_item2(id, 19, 5)
	g_difficult = 2
}
#endif


public plugin_precache()
{
	register_forward(FM_Spawn, "forward_spawn")
	for (new i;i < sizeof g_hunterlj;i++)
	{
		precache_sound(g_hunterlj[i])
	}
	for (new i;i < sizeof g_zombiewin;i++)
	{
		precache_sound(g_zombiewin[i])
	}
	for (new i;i < sizeof ComboSound;i++)
	{
		precache_sound(ComboSound[i])
	}
	for (new i;i < sizeof g_szZombieHit;i++)
	{
		precache_sound(g_szZombieHit[i])
	}
	for (new i;i < sizeof g_szZombieMiss;i++)
	{
		precache_sound(g_szZombieMiss[i])
	}
	for (new i;i < sizeof g_szMonsterPain;i++)
	{
		precache_sound(g_szMonsterPain[i])
	}
	for (new i;i < sizeof g_szMonsterDie;i++)
	{
		precache_sound(g_szMonsterDie[i])
	}
	for (new i;i < sizeof g_skinlist;i++)
	{
		PrecachePlayerModel(g_skinlist[i][SKIN_MDLNAME], 0)
		if (g_skinlist[i][SKIN_MDLWITHT])
		{
			PrecachePlayerModel(g_skinlist[i][SKIN_MDLNAME], 1)
		}
	}
	for (new i;i < sizeof boss_model;i++)
	{
		PrecachePlayerModel(boss_model[i], 0)
	}
	PrecachePlayerModel(leader_model, 0)
	for (new i;i < sizeof v_bossknife;i++)
	{
		precache_model(v_bossknife[i])
	}
	for (new i;i < sizeof boss_detected_bgm;i++)
	{
		precache_sound(boss_detected_bgm[i])
	}
	precache_sound(g_playerwin)
	precache_sound(g_boss_sound)
	precache_sound(g_speed)
	precache_sound(g_Hp)
	g_bossSpr = precache_model("sprites/boss.spr")
	//disable_buyzone()
}

public plugin_natives()
{
	register_native("bm_get_user_hide", "native_get_user_hide", 1)
	register_native("bm_get_user_level", "native_get_user_level", 1)
	register_native("bm_set_user_level", "native_set_user_level", 1)
	register_native("bm_get_user_sp", "native_get_user_sp", 1)
	register_native("bm_set_user_sp", "native_set_user_sp", 1)
	register_native("bm_get_user_xp", "native_get_user_xp", 1)
	register_native("bm_set_user_xp", "native_set_user_xp", 1)

	register_native("bm_get_user_boss", "native_get_user_boss", 1)
	register_native("bm_set_user_gash", "native_set_user_gash", 1)
	register_native("bm_get_user_gash", "native_get_user_gash", 1)
	register_native("bm_get_mode", "native_get_mode", 1)
	register_native("bm_add_item", "native_add_item", 1)
	register_native("bm_add_item2", "native_add_item2", 1)
	register_native("bm_set_user_weaponid", "native_set_user_weaponid", 1)
	register_native("bm_weapon_register", "native_register_weapon")
	register_native("bm_get_boss_blood_color", "native_get_boss_blood_color", 1)
}

public disable_buyzone()
{
	new ent = find_ent_by_class(-1, "info_map_parameters")
	if (!ent)
	{
		ent = create_entity("info_map_parameters")
	}
	DispatchKeyValue(ent, "buying")
	DispatchSpawn(ent)
}

public PrecachePlayerModel(model[], withT)
{
	new temp[256]
	format(temp, charsmax(temp), "models/player/%s/%s%s.mdl", model, model, withT ? "T" : "")
	precache_model(temp)
}
//--------------------------------------------------------------------------

public fw_PlayerPreThink(id)
{
	if (!is_user_alive(id)) return FMRES_IGNORED

	new Float:Bs, Float:SetSpeed = 1.0
	if (g_Player[id][Bag][SpeedGem]) Bs = 40.0
	if (g_setspeed[id]) SetSpeed = 2.0 - 0.1 * job_skill[id][8]		//抵抗速度下降

	if (g_Player[id][Base][Boss])
	{
		if (g_gboost[id])
		{
			entity_set_float(id, EV_FL_maxspeed, 420.0)
			if (g_mode != MODE_ESCAPE) entity_set_float(id, EV_FL_gravity, 0.8)
		}
		else
		{
			entity_set_float(id, EV_FL_maxspeed, 320.0)
			if (g_mode != MODE_ESCAPE) entity_set_float(id, EV_FL_gravity, 0.8)
		}

		if (g_random == 1 && get_user_health(id) <= 20000 && !g_endround)
		{
			new add_hp, map_name[64], connected_player = get_playersnum()
			g_random = 2
			get_mapname(map_name, charsmax(map_name))
			if (equali(map_name, "boss_", strlen("boss_"))) add_hp = connected_player * 68000
			if (g_mode != MODE_ESCAPE) fm_set_user_health(id, g_Player[id][Base][Level] > 250 ? (add_hp + connected_player * 80000) : (add_hp + 250 - g_Player[id][Base][Level] * 4000 + connected_player * 80000))
			else fm_set_user_health(id, 99999999)
			cs_set_player_model(id, boss_model[g_random])
			replace_weapon_models(id)
			set_dhudmessage(255, 20, 20, -1.0, 0.17, 1, 0.0, 5.0, 1.0, 1.0)
			show_dhudmessage(0, "魔王進化為魔龍 !!!!!")
			PlaySound(0, g_szMonsterDie[random_num(0, 1)])
			fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
			fm_set_user_godmode(id, 1)
			set_task(5.0, "remove_levelup", id)
		}
	}
	else
	{
		if (g_mode != MODE_ESCAPE)
		{
			entity_set_float(id, EV_FL_maxspeed, ((250.0 + max_speed[id] + Bs) / SetSpeed))
			entity_set_float(id, EV_FL_gravity, 1.0 - 0.01 * max_jump[id])
		}
		else
		{
			if (g_skin_info[id][6][SKIN_CAPABLE]) entity_set_float(id, EV_FL_maxspeed, 280.0 / SetSpeed)
			else entity_set_float(id, EV_FL_maxspeed, 250.0 / SetSpeed)
		}
	}
	
	if (g_Player[id][Base][Level] >= 20)
	{
		for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
		{
			if (g_tasklist[g_doing1[id][task_id]][TASK_CLASS] == 21)
			{
				task_complete(id, g_doing1[id][task_id])
			}
		}
	}
	if (g_Player[id][Base][Level] >= 40)
	{
		for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
		{
			if (g_tasklist[g_doing1[id][task_id]][TASK_CLASS] == 22)
			{
				task_complete(id, g_doing1[id][task_id]);
			}
		}
	}
	if (g_Player[id][Base][Level] >= 60)
	{
		for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
		{
			if (g_tasklist[g_doing1[id][task_id]][TASK_CLASS] == 23)
			{
				task_complete(id, g_doing1[id][task_id]);
			}
		}
	}
	if (g_Player[id][Base][Level] >= 80)
	{
		for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
		{
			if (g_tasklist[g_doing1[id][task_id]][TASK_CLASS] == 24)
			{
				task_complete(id, g_doing1[id][task_id]);
			}
		}
	}
	if (g_Player[id][Base][Level] >= 100)
	{
		for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
		{
			if (g_tasklist[g_doing1[id][task_id]][TASK_CLASS] == 25)
			{
				task_complete(id, g_doing1[id][task_id]);
			}
		}
	}

	new name[64]
	get_user_name(id, name, charsmax(name))
	if (g_Player[id][Base][XP] >= (g_Player[id][Base][Level] * g_Player[id][Base][Level] * MAX_EXP_MUL) && g_Player[id][Base][Level] < MAX_LEVEL)
	{
		g_Player[id][Base][Level]++
		g_skpoint[id]++
		if (g_Player[id][Base][Level] < 1000)
		{
			g_Player[id][Base][SP] += 50
		}
		set_hudmessage(255, 0, 0, -1.0, 0.17, 1, 3.0, 3.0, 1.0, 0.2, -1)
		ShowSyncHudMsg(id, g_MsgSync2, "Level up!!!!^n你已達到 %d 等級", g_Player[id][Base][Level])
		log_to_file(g_logfile, "名稱: %s 等級: %d 經驗: %d/%d 點數: %d Gash: %d (Level Up)", name, g_Player[id][Base][Level], g_Player[id][Base][XP], g_Player[id][Base][Level] * g_Player[id][Base][Level] * MAX_EXP_MUL, g_Player[id][Base][SP], g_Player[id][Base][Gash])
		if(g_Player[id][Base][Level] == 1000 && !(get_user_flags(id) & ADMIN_RESERVATION))
		{
			server_cmd("amx_addadmin ^"%s^" ^"b^" ^"^" ^"name^"", name)
			server_cmd("amx_reloadadmins")
			colored_print(0, "\x03[系統] 恭喜玩家\x04 %s \x03達到 1000 等級，獲得高玩", name)
		}
		else
		{
			if (g_Player[id][Base][Level] == 1000 && (get_user_flags(id) & ADMIN_RESERVATION))
			{
				g_Player[id][Base][Gash] += 250
				colored_print(0, "\x03[系統] 恭喜玩家\x04 %s \x03達到 1000 等級，獲得 250 Gash", name)
			}
		}
		if (g_Player[id][Base][Level] == 2000 && !(get_user_flags(id) & ADMIN_KICK))
		{
			server_cmd("amx_removeadmin ^"%s^"", name)
			server_cmd("amx_addadmin ^"%s^" ^"bcefjnopqrstu^" ^"^" ^"name^"", name)
			server_cmd("amx_reloadadmins")
			colored_print(0, "\x03[系統] 恭喜玩家\x04 %s \x03達到 2000 等級，獲得VIP", name)
		}
		if (g_Player[id][Base][Level] == 2000 && !(get_user_flags(id) & ADMIN_KICK))
		{
			g_Player[id][Base][Gash] += 500
			colored_print(0, "\x03[系統] 恭喜玩家\x04 %s \x03達到 2000 等級，獲得 500 Gash", name)
		}
	}
	if (get_weapon_type(g_Player[id][Base][Weapon]))
	{
		if (g_Player[id][Base][GunXP][g_Player[id][Base][Weapon]] >= g_Player[id][Base][GunLevel][g_Player[id][Base][Weapon]] * MAX_WEP_EXP_MUL && g_Player[id][Base][GunLevel][g_Player[id][Base][Weapon]] < MAX_WEAPON_LEVEL)
		{
			g_Player[id][Base][GunLevel][g_Player[id][Base][Weapon]]++;
			set_hudmessage(255, 0, 0, -1.0, 0.17, 1, 3.0, 3.0, 1.0, 0.2, -1);
			ShowSyncHudMsg(id, g_MsgSync2, "Level Up !!!^n%s 等級 %d 已達至 !!!", WEAPONNAMES_SIMPLE[g_Player[id][Base][Weapon]], g_Player[id][Base][GunLevel][g_Player[id][Base][Weapon]]);
			log_to_file(g_logfile, "名稱: %s %s 等級: %d %s 經驗: %d/%d (Weapon Level Up)", name, WEAPONNAMES_SIMPLE[g_Player[id][Base][Weapon]], g_Player[id][Base][GunLevel][g_Player[id][Base][Weapon]], WEAPONNAMES_SIMPLE[g_Player[id][Base][Weapon]], g_Player[id][Base][GunXP][g_Player[id][Base][Weapon]], g_Player[id][Base][GunLevel][g_Player[id][Base][Weapon]] * MAX_WEP_EXP_MUL);
		}
	}
	if (g_Player[id][Base][Level] >= MAX_LEVEL)
	{
		g_Player[id][Base][Level] = MAX_LEVEL
		g_Player[id][Base][XP] = (g_Player[id][Base][Level] - 1) * (g_Player[id][Base][Level] - 1) * MAX_EXP_MUL
		return FMRES_IGNORED
	}
	if (g_Player[id][Base][GunLevel][g_Player[id][Base][Weapon]] > MAX_WEAPON_LEVEL)
	{
		g_Player[id][Base][GunLevel][g_Player[id][Base][Weapon]] = MAX_WEAPON_LEVEL
		g_Player[id][Base][GunXP][g_Player[id][Base][Weapon]] = 19900
		return FMRES_IGNORED
	}
	return FMRES_IGNORED
}

public remove_levelup(id)
{
	remove_rendering(id)
	fm_set_user_godmode(id, 0)
}

public fw_GameDescription()
{
	new buffer[64]
	format(buffer, charsmax(buffer), "《%s %s》", PLUGIN_NAME, PLUGIN_VERSION)
	forward_return(FMV_STRING, buffer)
	return FMRES_SUPERCEDE
}

public boss_sound(sound)
{
	if (sound > sizeof boss_detected_bgm)
	{
		sound -= TASK_BOSS_SOUND
	}
	switch(sound)
	{
		case 1 : 
		{
			remove_task(sound + TASK_BOSS_SOUND)
			PlaySound(0, boss_detected_bgm[sound - 1])
			set_task(115.0, "boss_sound", sound + TASK_BOSS_SOUND)
		}
		case 2 : 
		{
			remove_task(sound + TASK_BOSS_SOUND)
			PlaySound(0, boss_detected_bgm[sound - 1])
			set_task(228.0, "boss_sound", sound + TASK_BOSS_SOUND)
		}
		case 3 : 
		{
			remove_task(sound + TASK_BOSS_SOUND)
			PlaySound(0, boss_detected_bgm[sound - 1])
			set_task(245.0, "boss_sound", sound + TASK_BOSS_SOUND)
		}
		case 4 : 
		{
			remove_task(sound + TASK_BOSS_SOUND)
			PlaySound(0, boss_detected_bgm[sound - 1])
			set_task(61.0, "boss_sound", sound + TASK_BOSS_SOUND)
		}
		case 5 : 
		{
			remove_task(sound + TASK_BOSS_SOUND)
			PlaySound(0, boss_detected_bgm[sound - 1])
			set_task(128.0, "boss_sound", sound + TASK_BOSS_SOUND)
		}
		case 6 : 
		{
			remove_task(sound + TASK_BOSS_SOUND)
			PlaySound(0, boss_detected_bgm[sound - 1])
			set_task(294.0, "boss_sound", sound + TASK_BOSS_SOUND)
		}
		case 7 : 
		{
			remove_task(sound + TASK_BOSS_SOUND)
			PlaySound(0, boss_detected_bgm[sound - 1])
			set_task(174.0, "boss_sound", sound + TASK_BOSS_SOUND)
		}
	}
}

public remove_boss_sound_task()
{
	for (new i = 1;i <= sizeof boss_detected_bgm;i++)
	{
		remove_task(i + TASK_BOSS_SOUND)
	}
}

public Forward_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flag, pitch)
{
	if(sample[0] == 'h' && sample[1] == 'o' && sample[2] == 's' && sample[3] == 't' && sample[4] == 'a' && sample[5] == 'g' && sample[6] == 'e')
		return FMRES_SUPERCEDE

	if (!is_user_connected(id)) return FMRES_IGNORED

	if (g_Player[id][Base][Boss])
	{
		if(sample[0] == 'w' && sample[1] == 'e' && sample[8] == 'k' && sample[9] == 'n')
		{
			switch (sample[17])
			{
				case '1', '2', '3', '4', 'b':
				{
					emit_sound(id, CHAN_WEAPON, g_szZombieHit[random_num(0,2)], volume, attn, flag, pitch);
					return FMRES_SUPERCEDE
				}
				case 'l':
				{
					return FMRES_SUPERCEDE
				}
				case 's', 'w':
				{
					emit_sound(id, CHAN_WEAPON, g_szZombieMiss[random_num(0,1)], volume, attn, flag, pitch);
					return FMRES_SUPERCEDE
				}
			}
		}
		if (!g_Player[id][Base][Hide] && ((sample[10] == 'f' && sample[11] == 'a' && sample[12] == 'l' && sample[13] == 'l') || (containi(sample, "bhit") > -1 || containi(sample, "pain") > -1 || containi(sample, "shot") > -1)))
		{
			emit_sound(id, CHAN_VOICE, g_szMonsterPain[random_num(0, 1)], volume, attn, flag, pitch);
			return FMRES_SUPERCEDE
		}
		if (sample[7] == 'd' && ((sample[8] == 'i' && sample[9] == 'e') || sample[12] == '6'))
		{
			emit_sound(id, CHAN_VOICE, g_szMonsterDie[random_num(0, 1)], volume, attn, flag, pitch);
			return FMRES_SUPERCEDE
		}
		if (sample[6] == 'n' && sample[7] == 'v' && sample[8] == 'g') 
			return FMRES_SUPERCEDE
	}
	return FMRES_IGNORED
}

public message_Health(msgid, dest, id)
{
	if (!is_user_alive(id) || g_setspeed[id] || g_Player[id][Base][Virus]) return
	new hp
	hp = get_msg_arg_int(1)
	if (hp >= 200) g_Player[id][Base][Status] = 0
	else
	{
		if (hp > 149) g_Player[id][Base][Status] = 1
		else if (hp > 99) g_Player[id][Base][Status] = 2
		else if (hp > 49) g_Player[id][Base][Status] = 3
		else if (hp > 10) g_Player[id][Base][Status] = 4
		else g_Player[id][Base][Status] = 5
	}
	if (hp > 255 && hp % 256)
	{
		hp++
		set_msg_arg_int(1, 1, hp)
	}
	return
}

public Forward_ClientKill(id)
{
	if (!is_user_alive(id))
		return FMRES_IGNORED
	return FMRES_SUPERCEDE
}

public event_curweapon(id)
{
	if (!is_user_alive(id)) return

	if (g_Player[id][Base][Boss])
	{
		if (get_user_weapon(id) != CSW_KNIFE)
		{
			engclient_cmd(id, "weapon_knife")
			replace_weapon_models(id)
		}
	}

	new weapon_id = read_data(2);
	if (CSW_MAXBPAMMO[weapon_id] > 2)
	{
		if (CSW_MAXBPAMMO[weapon_id] != cs_get_user_bpammo(id, weapon_id))
		{
			cs_set_user_bpammo(id, weapon_id, CSW_MAXBPAMMO[weapon_id])
		}
	}
	return
}

public fw_SetWeapon(entity, model[])
{
	if (!is_valid_ent(entity) || strlen(model) > 8) return FMRES_IGNORED

	new ent_classname[32]
	entity_get_string(entity, EV_SZ_classname, ent_classname, charsmax(ent_classname))
	if (equal(ent_classname, "weaponbox"))
	{
		entity_set_float(entity, EV_FL_nextthink, get_gametime())
		return FMRES_IGNORED
	}
	return FMRES_IGNORED
}

public fw_PlayerKilled_Post(victim, attacker, shouldgib)
{
	if (attacker == 0 && shouldgib == 0)
	{
		if (!g_antirespawn && !g_endround && g_startround && !is_user_alive(victim))
		{
			if(!g_Player[victim][Base][Boss]) make_human(victim)
			else make_boss(victim)
		}
	}
	if (fm_cs_get_user_team(victim) == fm_cs_get_user_team(attacker) || !is_user_connected(attacker))
	{
		return HAM_IGNORED
	}
	new exp = 1, name[64]
	if (exp_x2[attacker]) exp = 2
	get_user_name(attacker, name, charsmax(name))
	if (g_Player[victim][Base][Leader])
	{
		g_Player[victim][Base][Leader] = 0
		g_Player[attacker][Base][XP] += exp * LEADER_KILLED_EXP
		colored_print(0, "\x03[獎勵] 魔王 %s 殺死 Leader，獲得 %d 的 Exp", name, exp * LEADER_KILLED_EXP)
		colored_print(0, "\x03[懲罰] 由於 Leader 死亡，全體減少 100 HP，新手減半")
		
		for (new i=1;i<=g_maxplayers;i++)
		{
			if (fm_cs_get_user_team(i) == FM_CS_TEAM_CT && is_user_alive(i))
			{
				if (get_user_health(i) > g_Player[i][Base][Level] > 200 ? 100 : 50)
				{
					set_user_health(i, get_user_health(i) - g_Player[i][Base][Level] > 200 ? 100 : 50)
				}
				//user_silentkill(i)
			}
		}
		if (random_num(1, 20) == 1)
		{
			task_doing(attacker, 12, 1, 1, 0.0)
		}
	}
	remove_task(victim + TASK_NIGHTVISION)
	set_user_gnvision(victim, 0)
	g_nvision[victim] = 0
	g_nvisionenabled[victim] = 0
	set_task(0.1, "spec_nvision", victim)
	g_Player[attacker][Base][Combo]++
	if (g_Player[attacker][Base][Combo][1] <= g_Player[attacker][Base][Combo][0])
	{
		g_Player[attacker][Base][Combo][1] += 5
		set_hudmessage(255, 0, 0, -1.0, 0.3, 1, 0.0, 5.0, 1.0, 1.0, -1)
		ShowSyncHudMsg(attacker, g_MsgSync2, "YOU ARE KILLED %d HUMAN", g_Player[attacker][Base][Combo])
		colored_print(0, "\x04[Combo] \x03%s 總共擊殺了 %d 人類，獲得 %d 的 Exp 及 %d 的 Sp", name, g_Player[attacker][Base][Combo], exp * g_Player[attacker][Base][Level] * g_Player[attacker][Base][Combo] / 5 * 25, g_Player[attacker][Base][Combo] / 5 * 4)
		g_Player[attacker][Base][XP] += (exp * g_Player[attacker][Base][Level] * g_Player[attacker][Base][Combo] / 5 * 25)
		g_Player[attacker][Base][SP] += (g_Player[attacker][Base][Combo] / 5 * 4)
		PlaySound(attacker, ComboSound[random_num(0, 2)])
	}
	
	if (g_Player[victim][Base][Level] > 400)
	{
		task_doing(attacker, 20, 1, 1, 0.0)
	}
	if (!g_Player[victim][Base][Boss])
	{
		switch (random_num(1, 15))
		{
			case 1:
			{
				add_bag_item(attacker, 1, 1, true, 0)
			}
			case 2:
			{
				add_bag_item(attacker, 2, 1, true, 0)
			}
			case 3:
			{
				add_bag_item(attacker, 3, 1, true, 0)
			}
		}
		g_Player[attacker][Base][XP] += exp * HUMAN_KILLED_EXP
		g_Player[attacker][Base][SP] += HUMAN_KILLED_SP
		set_hudmessage(255, 0, 0, -1.0, 0.77, 1, 0.0, 2.0, 1.0, 1.0, -1)
		ShowSyncHudMsg(attacker, g_MsgSync3, "+ %d Exp^n+ %d Sp", exp * HUMAN_KILLED_EXP, HUMAN_KILLED_SP)
		
		if (g_mode == MODE_ESCAPE)
		{
			task_doing(attacker, 4, 1, 1, 0.0)
		}
		task_doing(attacker, 26, 1, 1, 0.0)
	}
	return HAM_IGNORED
}

public fw_TakeDamage(victim, inflictor, attacker, Float:damage, damage_type, handle)
{
	if (g_endround && !g_startround) return HAM_SUPERCEDE
	if (fm_cs_get_user_team(victim) == fm_cs_get_user_team(attacker) || !is_user_connected(attacker))
	{
		return HAM_IGNORED
	}

	new is_attack2 = (entity_get_int(attacker, EV_INT_button) & IN_ATTACK2 && entity_get_int(attacker, EV_INT_oldbuttons) & IN_ATTACK2)
	new Float:damage_multi, Float:User, Float:Dmg = 1.0, Float:Require_Damage
	if (g_Player[attacker][Bag][AttackGem])
	{
		Dmg += 1.0
	}
	if (g_headshot[attacker])
	{
		Dmg += 0.5
	}
	if (g_skin_info[attacker][5][SKIN_CAPABLE])
	{
		Dmg += 0.1
	}
	if (g_skin_info[attacker][2][SKIN_CAPABLE])
	{
		User += 200.0
	}
	if (get_user_flags(attacker) & ADMIN_LEVEL_A)
	{
		User += 400.0
	}
	else
	{
		if (get_user_flags(attacker) & ADMIN_MENU)
		{
			User += 200.0
		}
	}

	if (g_Player[attacker][Base][Boss])
	{
		damage_multi = (1.5 * damage) * (1.0 - (0.04 * job_skill[victim][7])) * (1.0 - (0.04 * job_skill[victim][5]))
		for (new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
		{
			if (g_tasklist[g_doing1[victim][task_id]][TASK_CLASS] == 1)
			{
				g_doing2[victim][task_id] = 0
				g_doing3[victim][task_id] = g_tasklist[g_doing1[victim][task_id]][TASK_DOING3NUM]
			}
		}
	}
	else
	{
		if (g_Player[attacker][Base][Weapon] == CSW_FIVESEVEN)
		{
			damage_multi = (damage + 0.25 * g_Player[attacker][Base][GunLevel][g_Player[attacker][Base][Weapon]] + max_damage[attacker]) * Dmg
		}
		else if (g_Player[attacker][Base][Weapon] == CSW_SCOUT)
		{
			damage_multi = damage * Dmg
		}
		else if (g_Player[attacker][Base][Weapon] == CSW_XM1014)
		{
			damage_multi = (damage + 0.12 * g_Player[attacker][Base][GunLevel][g_Player[attacker][Base][Weapon]] + 0.5 * max_damage[attacker]) * Dmg
		}
		else if (g_Player[attacker][Base][Weapon] == CSW_KNIFE && g_skin_info[attacker][3][SKIN_CAPABLE] && is_attack2)
		{
			damage_multi = (4000.0 + damage + max_damage[attacker]) * Dmg
		}
		else if (get_weapon_type(g_Player[attacker][Base][Weapon]))
		{
			damage_multi = (damage + g_Player[attacker][Base][GunLevel][g_Player[attacker][Base][Weapon]] + max_damage[attacker]) * Dmg
		}
		else damage_multi = (damage + max_damage[attacker]) * Dmg
	}
	new name[64];
	get_user_name(attacker, name, charsmax(name))
	if (damage_multi >= 200000.0 && !equal(name, "kdghrh", 0))
	{
		user_silentkill(attacker);
		colored_print(0, "\x03[系統] %s 因傷害數値出錯被處死", name);
		colored_print(0, "\x03[系統] %s 因傷害數値出錯被處死", name);
		colored_print(0, "\x03[系統] %s 因傷害數値出錯被處死", name);
		colored_print(0, "\x03[系統] %s 因傷害數値出錯被處死", name);
		colored_print(0, "\x03[系統] %s 因傷害數値出錯被處死", name);
		return HAM_IGNORED
	}
	if (get_user_weapon(attacker) == CSW_KNIFE && !g_Player[attacker][Base][Boss])
	{
		if (is_attack2)
		{
			if (g_critical_knife[attacker])
			{
				damage_multi = 3000.0 + 400.0 * job_skill[attacker][3]
			}
		}

		if (job_skill[attacker][11] && random_num(0, 100) <= job_skill[attacker][11] * 12)
		{
			new Float:a[3], Float:b[3], g_push
			if (is_attack2)
			{
				g_push = 30
				entity_get_vector(victim, EV_VEC_origin, a)
				velocity_by_aim(attacker, g_push * 100, b)
				a[0] = b[0]
				a[1] = b[1]
				a[2] *= b[2]
				entity_set_vector(victim, EV_VEC_velocity, a)
			}
		}
	}
	g_PlayerFloat[attacker][Damage][Skin] += damage_multi
	g_PlayerFloat[attacker][Damage][Skill] += damage_multi
	g_PlayerFloat[attacker][Damage][ItemDrop] += damage_multi
	g_PlayerFloat[attacker][Damage][Rank] += damage_multi
	if(!g_Player[attacker][Base][Boss])
	{
		if (g_Player[attacker][Base][Weapon] == CSW_KNIFE)
		{
			g_PlayerFloat[attacker][Damage][Task][2] += damage_multi
		}
		else
		{
			g_PlayerFloat[attacker][Damage][Task][0] += damage_multi
		}
		if (get_weapon_type(g_Player[attacker][Base][Weapon]) == WEP_TYPE_PISTOL)
		{
			g_PlayerFloat[attacker][Damage][Task][1] += damage_multi
		}
	}
	SetHamParamFloat(4, damage_multi)

	if (g_PlayerFloat[attacker][Damage][Skin] >= 500.0 && g_skin_info[attacker][1][SKIN_CAPABLE])
	{
		if (g_mode == MODE_ESCAPE)
		{
			fm_set_user_health(attacker, min(floatround(entity_get_float(attacker, EV_FL_health)) + 1, 100))
		}
		else
		{
			fm_set_user_health(attacker, min(floatround(entity_get_float(attacker, EV_FL_health)) + 1, max_hp[attacker] + 25))
		}
		g_PlayerFloat[attacker][Damage][Skin] -= g_PlayerFloat[attacker][Damage][Skin]
	}
	if (g_PlayerFloat[attacker][Damage][Skill] >= 5000.0 && job_skill[attacker][1] && limit_addhp[attacker] < 150)
	{
		if (g_mode == MODE_ESCAPE)
		{
			fm_set_user_health(attacker, min(floatround(entity_get_float(attacker, EV_FL_health)) + job_skill[attacker][1], 100))
		}
		else
		{
			fm_set_user_health(attacker, min(floatround(entity_get_float(attacker, EV_FL_health)) + job_skill[attacker][1], max_hp[attacker] + 25))
		}
		g_PlayerFloat[attacker][Damage][Skill] -= g_PlayerFloat[attacker][Damage][Skill]
		limit_addhp[attacker] += job_skill[attacker][1]
	}

	if (g_Player[attacker][Base][Level] > 500 || (get_user_flags(attacker) & ADMIN_LEVEL_A || get_user_flags(attacker) & ADMIN_MENU))
	{
		Require_Damage = 3500.0 - User
	}
	else
	{
		if (g_Player[attacker][Base][Level] > 400) Require_Damage = 2500.0 - User
		else if (g_Player[attacker][Base][Level] > 300) Require_Damage = 2000.0 - User
		else if (g_Player[attacker][Base][Level] > 200) Require_Damage = 1500.0 - User
		else Require_Damage = 1000.0 - User
	}
	
	new added;
	while(g_PlayerFloat[attacker][Damage][ItemDrop] >= Require_Damage)
	{
		added++
		g_PlayerFloat[attacker][Damage][ItemDrop] -= Require_Damage
		if (exp_x2[attacker]) g_Player[attacker][Base][XP] += DAMAGE_PLAYER_EXP * 2
		else g_Player[attacker][Base][XP] += DAMAGE_PLAYER_EXP
		g_Player[attacker][Base][SP] += DAMAGE_PLAYER_SP
		if (get_weapon_type(g_Player[attacker][Base][Weapon])) g_Player[attacker][Base][GunXP][g_Player[attacker][Base][Weapon]] += DAMAGE_WEAPON_EXP
		//物品掉落
		if (job_skill[attacker][10])
		{
			switch (random_num(1, 1200))
			{
				case 1:
				{
					add_bag_item(attacker, 1, 1, true, 0)
				}
				case 2:
				{
					add_bag_item(attacker, 2, 1, true, 0)
				}
				case 3:
				{
					add_bag_item(attacker, 3, 1, true, 0)
				}
				case 4:
				{
					task_doing(attacker, 2, 1, true, 0.0)
				}
			}
		}
		else
		{
			switch (random_num(1, 1500))
			{
				case 1:
				{
					add_bag_item(attacker, 1, 1, true, 0)
				}
				case 2:
				{
					add_bag_item(attacker, 2, 1, true, 0)
				}
				case 3:
				{
					add_bag_item(attacker, 3, 1, true, 0)
				}
				case 4:
				{
					task_doing(attacker, 2, 1, true, 0.0)
				}
			}
		}
		switch (random_num(1, 3000))
		{
			case 1..10:
			{
				g_Player[attacker][Base][Coupon] += 1
			}
		}
		if (g_skin_info[attacker][0][SKIN_CAPABLE])
		{
			switch (random_num(1, 1000))
			{
				case 1:
				{
					add_bag_item(attacker, 13, 1, true, 0)
				}
				case 2:
				{
					add_bag_item(attacker, 14, 1, true, 0)
				}
				case 3:
				{
					add_bag_item(attacker, 15, 1, true, 0)
				}
				case 4:
				{
					add_bag_item(attacker, 16, 1, true, 0)
				}
				case 5:
				{
					add_bag_item(attacker, 17, 1, true, 0)
				}
				case 6:
				{
					if (random_num(1, 15) == 1)
					{
						add_bag_item(attacker, 7, 1, true, 0)
					}
				}
				case 7:
				{
					if (random_num(1, 30) == 1)
					{
						add_bag_item(attacker, 4, 1, true, 0)
					}
				}
				case 8:
				{
					if (random_num(1, 15) == 1)
					{
						add_bag_item(attacker, 5, 1, true, 0)
					}
				}
				case 9:
				{
					if (random_num(1, 15) == 1)
					{
						add_bag_item(attacker, 12, 1, true, 0)
					}
				}
			}
		}
	}
	if (added > 0)
	{
		set_hudmessage(255, 0, 0, -1.0, 0.78, 1, 0.0, 2.0, 1.0, 1.0, -1)
		if (get_weapon_type(g_Player[attacker][Base][Weapon]))
		{
			if (exp_x2[attacker]) ShowSyncHudMsg(attacker, g_MsgSync3, "+ %d Exp^n+ %d Sp^n+ %d Weapon Exp", added * (DAMAGE_PLAYER_EXP * 2), added * DAMAGE_PLAYER_SP, added * DAMAGE_WEAPON_EXP)
			else ShowSyncHudMsg(attacker, g_MsgSync3, "+ %d Exp^n+ %d Sp^n+ %d Weapon Exp", added * DAMAGE_PLAYER_EXP, added * DAMAGE_PLAYER_SP, added * DAMAGE_WEAPON_EXP)
		}
		else
		{
			if (exp_x2[attacker]) ShowSyncHudMsg(attacker, g_MsgSync3, "+ %d Exp^n+ %d Sp", added * DAMAGE_PLAYER_EXP, added * DAMAGE_PLAYER_SP)
			else ShowSyncHudMsg(attacker, g_MsgSync3, "+ %d Exp^n+ %d Sp", added * DAMAGE_PLAYER_EXP, added * DAMAGE_PLAYER_SP)
		}
	}
	
	if (g_PlayerFloat[attacker][Damage][Task][0] > 8000.0)
	{
		task_doing(attacker, 27, 0, 0, g_PlayerFloat[attacker][Damage][Task][0])
		task_doing(attacker, 1, 0, 0, g_PlayerFloat[attacker][Damage][Task][0])
		g_PlayerFloat[attacker][Damage][Task][0] -= g_PlayerFloat[attacker][Damage][Task][0]
	}
	if (g_PlayerFloat[attacker][Damage][Task][2] > 8000.0)
	{
		task_doing(attacker, 28, 0, 0, g_PlayerFloat[attacker][Damage][Task][2])
		g_PlayerFloat[attacker][Damage][Task][2] -= g_PlayerFloat[attacker][Damage][Task][2]
	}
	return HAM_IGNORED
}

public fw_TraceAttack(victim, attacker, Float:damage, Float:direction[3], tracehandle, damage_type)
{
	if (g_headshoot[attacker] && !g_Player[attacker][Base][Boss])
	{
		if (get_tr2(tracehandle, TR_iHitgroup) != 1)
		{
			set_tr2(tracehandle, TR_iHitgroup, 1)
		}
	}
	return HAM_IGNORED
}

public fw_TouchWeapon(weapon, id)
{
	if (!is_user_alive(id))
		return HAM_IGNORED
	
	if (g_Player[id][Base][Boss])
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

public fw_UseStationary(entity, caller, activator, use_type)
{
	// Prevent zombies from using stationary guns
	if (use_type == 2 && is_user_connected(caller) && is_user_alive(caller) && g_Player[caller][Base][Boss])
		return HAM_SUPERCEDE;
	
	return HAM_IGNORED;
}

public fw_UseStationary_Post(entity, caller, activator, use_type)
{
	// Someone stopped using a stationary gun
	if (use_type == 0 && is_user_connected(caller) && is_user_alive(caller))
		replace_weapon_models(caller) // replace weapon models (bugfix)
}

public Hook_BloodColor(id)
{
	if (g_Player[id][Base][Boss])
	{
		SetHamReturnInteger(BOSS_BLOOD_COLOR)
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public fw_TraceBleed(this, Float:Damage, Float:Direction[3], trace_handle, damagebits)
{
	if (g_Player[this][Base][Hide] && is_user_alive(this)) return HAM_SUPERCEDE
	return HAM_IGNORED
}

public msg_textmsg(msgid, dest, id)
{
	static txtmsg[25]
	get_msg_arg_string(2, txtmsg, charsmax(txtmsg))
	
	if (equal(txtmsg, "#Game_will_restart_in"))
	{
		logevent_round_end()
	}
	else if (equal(txtmsg, "#CTs_Win") || equal(txtmsg, "#Terrorists_Win"))
	{
		g_endround = 1
		remove_boss_sound_task()
		remove_task(TASK_ANTIRESPAWN)
		StopSound(0)
		if (equal(txtmsg, "#CTs_Win"))
		{
			PlaySound(0, "legend/Human_Win.wav")
			g_humanwin++
			if (g_difficult < 2)
			{
				g_difficult++
			}
			set_msg_arg_string(2, "#CTs_Win")
			set_dhudmessage(0, 255, 0, -1.0, 0.17, 0, 0.0, 6.0, 2.0, 1.0)
			show_dhudmessage(0, "人類勝利")
			for (new i;i<=g_maxplayers;i++)
			{
				if (!g_Player[i][Base][Boss])
				{
					g_Player[i][Base][XP] += 3000
				}
			}
			colored_print(0, "\x03[獎勵] 人類獲得完場勝利，獲得 3000 的 EXP")
		}
		else if (equal(txtmsg, "#Terrorists_Win", 0))
		{
			PlaySound(0, g_zombiewin[random_num(0, 2)])
			g_bosswin++
			g_difficult = 0
			set_msg_arg_string(2, "#Terrorists_Win")
			set_dhudmessage(255, 0, 0, -1.0, 0.17, 0, 0.0, 6.0, 2.0, 1.0)
			show_dhudmessage(0, "魔王勝利")
			for (new i;i<=g_maxplayers;i++)
			{
				if (g_Player[i][Base][Boss])
				{
					g_Player[i][Base][XP] += fnGetCTs() * 1000
				}
			}
			colored_print(0, "\x03[獎勵] 魔王獲得完場勝利，獲得 %d 的 EXP", fnGetCTs() * 1000)
		}
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public message_NVGToggle(msg_id, msg_dest, msg_entity)
{
	return PLUGIN_HANDLED
}

public message_teaminfo(msg_id, msg_dest)
{
	if (msg_dest != MSG_ALL && msg_dest != MSG_BROADCAST) return;
	if (g_switchingteam) return;
	static id;
	id = get_msg_arg_int(1)
	if (!(1 <= id <= g_maxplayers)) return;
	set_task(0.2, "spec_nvision", id)
	static team[2]
	get_msg_arg_string(2, team, charsmax(team))
	if (fnGetAliveBosses() > (g_twoboss ? 2 : 1) && g_startround && !g_endround)
	{
		switch (team[0])
		{
			case 'C': // CT
			{
				remove_task(id+TASK_TEAM)
				fm_cs_set_user_team(id, FM_CS_TEAM_CT)
				set_msg_arg_string(2, "CT")
			}
			case 'T': // Terrorist
			{
				remove_task(id+TASK_TEAM)
				fm_cs_set_user_team(id, FM_CS_TEAM_CT)
				set_msg_arg_string(2, "CT")
			}
		}
	}
}

public Message_StatusIcon(msg_id, msg_dest, msg_entity)
{
	static szBuffer[8]
	get_msg_arg_string(2, szBuffer, charsmax(szBuffer))
	return (!strcmp(szBuffer, "buyzone")) ? PLUGIN_HANDLED : PLUGIN_CONTINUE
}

public blood_message()
{
	new arg1 = get_msg_arg_int(1), Float:origin[2][3]
	if (arg1 == 115 || arg1 == 116 || arg1 == 103)
	{
		origin[0][0] = get_msg_arg_float(2)
		origin[0][1] = get_msg_arg_float(3)
		origin[0][2] = get_msg_arg_float(4)
		for (new i = 1;i <= g_maxplayers;i++)
		{
			if (g_Player[i][Base][Hide] && is_user_alive(i))
			{
				entity_get_vector(i, EV_VEC_origin, origin[1])
				if(get_distance_f(origin[0], origin[1]) < 55.0) return PLUGIN_HANDLED
			}
		}
	}
	return PLUGIN_CONTINUE
}

public clcmd_nightvision(id)
{
	if (g_nvision[id])
	{
		g_nvisionenabled[id] = !g_nvisionenabled[id]
		remove_task(id + TASK_NIGHTVISION)
		if (g_nvisionenabled[id])
		{
			message_begin(MSG_ONE_UNRELIABLE, SVC_LIGHTSTYLE, _, id)
			write_byte(0)
			write_string("Z")
			message_end()
			set_task(0.1, "set_user_nvision", id + TASK_NIGHTVISION)
			if (is_user_alive(id))
			{
				emit_sound(id, CHAN_ITEM, "items/nvg_on.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
		else
		{
			lighting_effects();
			if (is_user_alive(id))
			{
				emit_sound(id, CHAN_ITEM, "items/nvg_off.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		}
	}
	return PLUGIN_HANDLED
}

public show_menu_game(id)
{
	static menuid, temp[256]
	format(temp, charsmax(temp), "\y《%s %s》^n\wQQ 1079114958^n\r注:\y此版本为反编译修复版本^n如发现BUG请向小豆反馈\w", PLUGIN_NAME, PLUGIN_VERSION)
	menuid = menu_create(temp, "menu_game")
	menu_additem(menuid, "\d回復資料")
	menu_additem(menuid, "\w選擇列表")
	menu_additem(menuid, "\w商店列表")
	menu_additem(menuid, "\w我的背包")
	menu_additem(menuid, "\w能力及職業")
	menu_additem(menuid, "\w任務選擇表")
	menu_additem(menuid, "\y轉換列表")
	menu_additem(menuid, "\y商店系統 \d(更新中)")
	menu_additem(menuid, "\r購買須知")
	menu_additem(menuid, "\y交易系統 \d(20等級)")
	menu_additem(menuid, "\r簽到系統")
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_game(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new command[6], item_name[64], access, callback
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	switch (item)
	{
		case 0:
		{
			//show_menu_redata(id)
		}
		case 1:
		{
			if (!is_user_alive(id))
			{
				colored_print(id, "\x04[系統]\x03 你必須生存。")
				return PLUGIN_HANDLED
			}
			if (g_Player[id][Base][Boss])
			{
				colored_print(id, "\x04[系統]\x03 你是魔王不能選擇。")
				return PLUGIN_HANDLED
			}
			show_menu_choose(id)
		}
		case 2:
		{
			//TODO:交易系统
			/*
			if (g_exchangeing[id])
			{
				colored_print(id, "\x04[交易]\x03 你進行交易中，不能使用。")
				return PLUGIN_HANDLED
			}
			*/
			show_menu_choose2(id)
		}
		case 3:
		{
			//TODO:交易系统
			/*
			if (g_exchangeing[id])
			{
				colored_print(id, "\x04[交易]\x03 你進行交易中，不能使用。")
				return PLUGIN_HANDLED
			}
			*/
			show_menu_bag(id)
		}
		case 4:
		{
			show_menu_skill_pt(id)
		}
		case 5:
		{
			show_menu_choose3(id)
		}
		case 6:
		{
			//TODO:交易系统
			/*
			if (g_exchangeing[id])
			{
				colored_print(id, "\x04[交易]\x03 你進行交易中，不能使用。")
				return PLUGIN_HANDLED
			}
			*/
			show_menu_change(id);
		}
		case 7:
		{
			colored_print(id, "\x04[小豆]\x03 : 這個功能還沒寫完 :P 再等等啦")
			//show_menu_playershop(id)
		}
		case 8:
		{
			new motd[1000]
			formatex(motd, charsmax(motd), "請上論壇 legendserver.org 查看")
			show_motd(id, motd, "購買須知")
			show_menu_game(id)
		}
		case 9:
		{
			if (g_Player[id][Base][Level] < 20)
			{
				colored_print(id, "\x04[系統]\x03 等級不足")
				return PLUGIN_HANDLED
			}
			colored_print(id, "\x04[小豆]\x03 : 這個功能還沒寫完 :P 再等等啦")
			//show_menu_trade(id)
		}
		case 10:
		{
			client_cmd(id, "say /etask")
		}
	}
	return PLUGIN_HANDLED
}

public show_menu_choose(id)
{
	static buffer[32], menu[128], menuid
	formatex(menu, charsmax(menu), "\w《選擇列表》")
	menuid = menu_create(menu, "menu_choose")
	menu_additem(menuid, "\w免費槍", buffer)
	menu_additem(menuid, "\w永久槍", buffer)
	menu_additem(menuid, "\w永久人", buffer)
	menu_additem(menuid, "\w特別槍 \y(高玩或以上)", buffer)
	menu_additem(menuid, "\w手槍 \y(1-300等級)", buffer)
	menu_additem(menuid, "\w永久刀", buffer)
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_choose(id, menuid, item)
{
	if (item == MENU_EXIT || g_Player[id][Base][Boss])
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new command[6], item_name[64], access, callback
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	if (!is_user_alive(id))
	{
		colored_print(id, "\x04[系統]\x03 你必须生存。")
		return PLUGIN_HANDLED
	}
	if(g_SelectedPri[id] && (item == 0 || item == 1 || item == 3))
	{
		colored_print(id, "\x04[系統]\x03 你已選擇了槍械。")
		return PLUGIN_HANDLED
	}
	switch (item)
	{
		case 0:
		{
			show_menu_gun(id)
		}
		case 1:
		{
			show_menu_evergun(id)
		}
		case 2:
		{
			show_menu_model(id)
		}
		case 3:
		{
			if (!(get_user_flags(id) & ADMIN_RESERVATION) && !g_Player[id][Bag][PowerCard])
			{
				colored_print(id, "\x04[系統]\x03 你沒有權限進入。")
				return PLUGIN_HANDLED
			}
			show_menu_power(id)
		}
		case 4:
		{
			if (!g_SelectedSec[id]) show_menu_hand(id)
			else colored_print(id, "\x04[系統]\x03 你已選擇了槍械。")
		}
		case 5:
		{
			if (!g_SelectedMelee[id]) show_menu_knife(id)
			else colored_print(id, "\x04[系統]\x03 你已選擇了刀。")
		}
	}
	return PLUGIN_HANDLED
}

public show_menu_gun(id)
{
	new menu[128], menuid, buffer[6], count
	menuid = menu_create("\w《免費槍》", "menu_gun")
	
	if (g_WeaponCount)
	{
		count = 1
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_FREE)
			{
				formatex(menu, charsmax(menu), "\w%s", WeaponName[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
				count++
			}
		}
	}

	for (new item;item < sizeof g_freewpnname;item++)
	{
		formatex(menu, charsmax(menu), "\w%s", g_freewpnname[item])
		buffer[0] = item + count
		buffer[1] = count
		menu_additem(menuid, menu, buffer)
	}

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_gun(id, menuid, item)
{
	new command[6], item_name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]

	if (item == MENU_EXIT || g_Player[id][Base][Boss])
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}

	drop_weapons(id, 1)

	if (command[1] > 0)
	{
		fm_give_item(id, g_freewpnitem[itemid - command[1]])
		colored_print(id, "\x04[選擇]\x03 成功選擇 %s。", g_freewpnname[itemid - command[1]])
	}
	else
	{
		ExecuteForward(g_fwWeaponBought, g_fwResult, id, itemid)
		colored_print(id, "\x04[選擇]\x03 成功選擇 %s。", WeaponName[itemid])
		g_SelectedWeapon[id][0] = itemid
	}
	
	g_SelectedPri[id] = 1
	return PLUGIN_HANDLED
}

public show_menu_evergun(id)
{
	new buffer[6], menu[128], menuid, count
	menuid = menu_create("\w《永久槍械選擇表》", "menu_evergun")
	
	if (!g_WeaponCount)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	else
	{
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_FOREVER && g_UnlockedWeapon[id][item])
			{
				formatex(menu, charsmax(menu), "\w%s", WeaponName[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
				count++
			}
		}
		if (!count)
		{
			buffer[0] = -1
			menu_additem(menuid, "\w无", buffer)
		}
	}

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_evergun(id, menuid, item)
{
	new command[6], item_name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]

	if (item == MENU_EXIT || g_Player[id][Base][Boss] || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}

	drop_weapons(id, 1)
	//client_cmd(id, "%s", g_wpncmd[itemid])
	ExecuteForward(g_fwWeaponBought, g_fwResult, id, itemid)
	colored_print(id, "\x04[購買]\x03 成功選擇 %s。", WeaponName[itemid])
	g_SelectedWeapon[id][0] = itemid
	g_SelectedPri[id] = 1
	return PLUGIN_HANDLED
}

public show_menu_model(id)
{
	new buffer[6], menu[128], menuid, count
	menuid = menu_create("\w《永久人物選擇表》", "menu_model")
	
	for (new skin;skin < sizeof g_skinlist;skin++)
	{
		if (g_skin_info[id][skin][SKIN_HAVE])
		{
			formatex(menu, charsmax(menu), "\w%s\y%s \r%s", g_skinlist[skin][SKIN_NAME], g_skin_info[id][skin][SKIN_EQUIPED] ? "[已选择]" : "", g_skinlist[skin][SKIN_NAME2])
			buffer[0] = skin
			menu_additem(menuid, menu, buffer)
			count++
		}
	}
	if (!count)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_model(id, menuid, item)
{
	new command[6], item_name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]

	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	
	if (g_skin_info[id][itemid][SKIN_EQUIPED])
	{
		g_skin_info[id][itemid][SKIN_EQUIPED] = 0
		colored_print(id, "\x04[系統]\x03 已取消选择该人物。")
	}
	else
	{
		for (new i;i < sizeof g_skinlist;i++)
		{
			g_skin_info[id][i][SKIN_EQUIPED] = 0
		}
		g_skin_info[id][itemid][SKIN_EQUIPED] = 1
		
		colored_print(id, "\x04[選擇]\x03 成功選擇 %s。", g_skinlist[itemid][SKIN_NAME])
		if (!g_SelectedSkins[id] && !g_Player[id][Base][Leader] && !g_Player[id][Base][Boss])
		{
			change_skin(id, itemid)
			g_SelectedSkins[id] = 1
		}
		else colored_print(id, "\x04[系統]\x03 您的人物将在下次重生后生效。")
	}

	return PLUGIN_HANDLED
}

public change_skin(id, skin_id)
{
	cs_set_player_model(id, g_skinlist[skin_id][SKIN_MDLNAME])
	for (new i;i < sizeof g_skinlist;i++)
	{
		g_skin_info[id][i][SKIN_CAPABLE] = 0
	}
	g_skin_info[id][skin_id][SKIN_CAPABLE] = 1
	
	if (g_skin_info[id][4][SKIN_CAPABLE] && g_Player[id][Bag][UseLimit] == ITEM_CAN_USE_TIMES)
	{
		g_Player[id][Bag][UseLimit] = g_Player[id][Bag][UseLimit] + 3;
	}
}

public show_menu_power(id)
{
	new buffer[6], menu[128], menuid, count
	menuid = menu_create("\w《特別槍械選擇表》", "menu_power")
	
	if (!g_WeaponCount)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	else
	{
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_SPECIAL && (g_UnlockedWeapon[id][item] || g_Player[id][Bag][PowerCard]))
			{
				formatex(menu, charsmax(menu), "\w%s", WeaponName[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
				count++
			}
		}
		if (!count)
		{
			buffer[0] = -1
			menu_additem(menuid, "\w无", buffer)
		}
	}

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_power(id, menuid, item)
{
	new command[6], item_name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]

	if (item == MENU_EXIT || g_Player[id][Base][Boss] || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	drop_weapons(id, 1)
	//client_cmd(id, "%s", g_powercmd[itemid])
	ExecuteForward(g_fwWeaponBought, g_fwResult, id, itemid)
	colored_print(id, "\x04[購買]\x03 成功選擇 %s。", WeaponName[itemid])
	g_SelectedWeapon[id][0] = itemid
	g_SelectedPri[id] = 1
	return PLUGIN_HANDLED
}

public show_menu_hand(id)
{
	new buffer[6], menu[128], menuid, count
	menuid = menu_create("\w《手槍選擇表》", "menu_hand")
	
	if (!g_WeaponCount)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	else
	{
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_PISTOL)
			{
				formatex(menu, charsmax(menu), "\w%s \rLevel %i", WeaponName[item], WeaponLevel[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
				count++
			}
		}
		if (!count)
		{
			buffer[0] = -1
			menu_additem(menuid, "\w无", buffer)
		}
	}

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_hand(id, menuid, item)
{
	new command[6], item_name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]

	if (item == MENU_EXIT || g_Player[id][Base][Boss] || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}

	if (g_Player[id][Base][Level] < WeaponLevel[itemid])
	{
		colored_print(id, "\x04[系統]\x03 你的等級不足。");
	}
	else
	{
		drop_weapons(id, 2)
		//client_cmd(id, "%s", g_handcmd[itemid])
		ExecuteForward(g_fwWeaponBought, g_fwResult, id, itemid)
		colored_print(id, "\x04[系統]\x03 成功選擇 %s。", WeaponName[itemid])
		g_SelectedWeapon[id][1] = itemid
		g_SelectedSec[id] = 1
	}
	return PLUGIN_HANDLED
}

public show_menu_knife(id)
{
	new buffer[6], menu[128], menuid, count
	menuid = menu_create("\w《永久刀選擇表》", "menu_knife")
	
	if (!g_WeaponCount)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	else
	{
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_KNIFE && g_UnlockedWeapon[id][item])
			{
				formatex(menu, charsmax(menu), "\w%s", WeaponName[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
				count++
			}
		}
		if (!count)
		{
			buffer[0] = -1
			menu_additem(menuid, "\w无", buffer)
		}
	}

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_knife(id, menuid, item)
{
	new command[6], item_name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]
	if (item == MENU_EXIT || g_Player[id][Base][Boss] || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	//client_cmd(id, "%s", g_knifecmd[itemid]);
	drop_weapons(id, 3)
	fm_give_item(id, "weapon_knife")
	ExecuteForward(g_fwWeaponBought, g_fwResult, id, itemid)
	colored_print(id, "\x04[購買]\x03 成功選擇 %s。", WeaponName[itemid])
	g_SelectedWeapon[id][2] = itemid
	g_SelectedMelee[id] = 1
	return PLUGIN_HANDLED
}

public show_menu_choose3(id)
{
	new menuid
	menuid = menu_create("\y《任務選擇表》", "menu_choose3")
	
	menu_additem(menuid, "\w任務列表")
	menu_additem(menuid, "\w任務進度")

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_choose3(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	switch (item)
	{
		case 0: show_menu_task(id)
		case 1: show_menu_btaskdata(id)
	}
	return PLUGIN_HANDLED
}


show_menu_btaskdata(id)
{
	new szMenuBody[512], text[MAX_TAKE_TASK_NUM][256], keys;
	
	format(szMenuBody, charsmax(szMenuBody), "\r任務進度:^n^n")
	for (new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
	{
		if (g_doing1[id][task_id])
		{
			new Class = g_tasklist[g_doing1[id][task_id]][TASK_CLASS]
			if (Class == 26 || Class == 4 || Class == 20)
			{
				formatex(text[task_id], 255, "\y任务名称: %s^n\w 已擊殺 %d 隻人類，還剩餘 %d 隻人類", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
			}
			if (Class == 27 || Class == 1 || Class == 28)
			{
				formatex(text[task_id], 255, "\y%s^n\w已集成 %d 傷害，還剩餘 %d 傷害", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
			if (Class == 2)
			{
				formatex(text[task_id], 255, "\y%s^n\w已成功收集魔王之鱗 %d 個，還剩餘 %d 個", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
			if (Class == 3 || Class == 5 || Class == 7 || Class == 8 || Class == 11 || Class == 13 || Class == 17 || Class == 19)
			{
				formatex(text[task_id], 255, "\y%s^n\w已成功生存 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
			if (Class == 6)
			{
				formatex(text[task_id], 255, "\y%s^n\w已成功與搭檔清場 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
			if (Class == 9)
			{
				formatex(text[task_id], 255, "\y%s^n\w已成功於 2/2 變魔龍前清場 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
			if (Class == 10)
			{
				formatex(text[task_id], 255, "\y%s^n\w已成功連續 2 回合内造成 150000 傷害 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
			if (Class == 12)
			{
				formatex(text[task_id], 255, "\y%s^n\w已成功收集Leader 血液 %d 支，還剩餘 %d 支", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
			if (Class == 14)
			{
				formatex(text[task_id], 255, "\y%s^n\w已成功 1 個回合内以手槍造成 70000 傷害 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
			if (Class == 15)
			{
				formatex(text[task_id], 255, "\y%s^n\w已成功勝利 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
			if (Class == 16)
			{
				formatex(text[task_id], 255, "\y%s^n\w已成功 Combo 20 或以上 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
			if (Class == 18)
			{
				formatex(text[task_id], 255, "\y%s^n\w已成功血量保持 50% 或以上並勝利 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id]);
			}
		}
		if (!strlen(text[task_id]))
		{
			formatex(text[task_id], 255, "\y未進行任務")
		}
		format(szMenuBody, charsmax(szMenuBody), "%s%s^n", szMenuBody, text[task_id])
	}
	format(szMenuBody, charsmax(szMenuBody), "%s^n\r0. \w返回", szMenuBody)
	keys = (1<<0|1<<1|1<<2|1<<3|1<<4|1<<9)
	show_menu(id, keys, szMenuBody)
	return PLUGIN_HANDLED
}

public menu_btaskdata(id, keys)
{
	if (keys == 9)
	{
		show_menu_choose3(id)
		return PLUGIN_HANDLED
	}
	if (g_doing1[id][keys])
	{
		show_menu_btask(id, g_doing1[id][keys])
	}
	else
	{
		colored_print(id, "\x04[任務]\x03 未進行任務。")
	}
	return PLUGIN_HANDLED
}

show_menu_task(id)
{
	new menuid, menu[128], buffer[32]
	formatex(menu, charsmax(menu), "\w《任務列表》")
	menuid = menu_create(menu, "menu_task")
	new Task_Status[TASKS_NUM][32]
	
	for(new task_id = 1;task_id < TASKS_NUM;task_id++)
	{
		for(new task;task < MAX_TAKE_TASK_NUM;task++)
		{
			if (task_id == g_doing1[id][task])
			{
				formatex(Task_Status[task_id], 31, "\w進行中")
				break
			}
			formatex(Task_Status[task_id], 31, "\d未進行")
		}
	}
	
	for(new task_id = 1;task_id < TASKS_NUM;task_id++)
	{
		if (g_Player[id][Base][Level] >= g_tasklist[task_id][TASK_LEVEL] && !get_user_task(id, task_id) && equal(Task_Status[task_id], "\d未進行"))
		{
			formatex(menu, charsmax(menu), "\r[%s\r] \y%s", Task_Status[task_id], g_tasklist[task_id][TASK_NAME])
			buffer[0] = task_id
			menu_additem(menuid, menu, buffer)
		}
	}
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_task(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new command[6], item_name[64], access, callback
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	show_menu_btask(id, command[0])
	return PLUGIN_HANDLED
}

show_menu_btask(id, itemid)
{
	new menuid, menu[1000], buffer[1000], offbutton, onbutton2, doingtasknum
	formatex(menu, charsmax(menu), "\w任務名稱: \y^n%s^n\w任務內容: \y^n%s^n\w任務獎勵: \y^n%s^n\w需要等級: \y^n%d", g_tasklist[itemid][TASK_NAME], g_tasklist[itemid][TASK_HELP], g_tasklist[itemid][TASK_HELP2], g_tasklist[itemid][TASK_LEVEL])
	menuid = menu_create(menu, "menu_btask")
	buffer[0] = itemid
	buffer[1] = 0
	
	for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
	{
		if (itemid == g_doing1[id][task_id])
		{
			offbutton = 1
			onbutton2 = 1
		}
		if (0 < g_doing1[id][task_id])
		{
			doingtasknum++
			if (doingtasknum == 5)
			{
				offbutton = 1
			}
		}
	}
	if (get_user_task(id, itemid))
	{
		offbutton = 1
	}
	if (!offbutton) menu_additem(menuid, "\w進行", buffer)
	else menu_additem(menuid, "\d進行", buffer)

	if (onbutton2) menu_additem(menuid, "\w放棄 (刪除數據)", buffer)
	else menu_additem(menuid, "\d放棄", buffer)

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_btask(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new command[6], item_name[64], access, callback
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	new itemid = item
	item = command[0]
	new check, check1
	if (itemid)
	{
		if (itemid == 1)
		{
			for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
			{
				if (item == g_doing1[id][task_id])
				{
					g_doing1[id][task_id] = 0
					g_doing2[id][task_id] = 0
					g_doing3[id][task_id] = 0
					colored_print(id, "\x04[任務]\x03 此任務已放棄。")
					show_menu_btaskdata(id)
					break
				}
				if (task_id == 4)
				{
					colored_print(id, "\x04[任務]\x03 此任務沒有進行。")
					show_menu_btaskdata(id)
					return PLUGIN_HANDLED
				}
			}
		}
	}
	else
	{
		if (get_user_task(id, item))
		{
			colored_print(id, "\x04[任務]\x03 此任務已完成。");
			show_menu_task(id);
			return PLUGIN_HANDLED
		}
		if (g_tasklist[item][TASK_LEVEL] > g_Player[id][Base][Level])
		{
			colored_print(id, "\x04[任務]\x03 此任務不能進行，因為你的等級不足。")
			show_menu_task(id)
			return PLUGIN_HANDLED
		}
		
		for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
		{
			if (item == g_doing1[id][task_id])
			{
				colored_print(id, "\x04[任務]\x03 此任務已進行。");
				show_menu_task(id);
				return PLUGIN_HANDLED
			}
			if (g_doing1[id][task_id])
			{
				check1++
				if (check1 >= MAX_TAKE_TASK_NUM)
				{
					colored_print(id, "\x04[任務]\x03 最大可接任務已滿，請先取消任務才能繼續");
					show_menu_task(id);
					return PLUGIN_HANDLED
				}
			}
		}
		
		for (new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
		{
			if (g_doing1[id][task_id] < 1 && !check)
			{
				if (!check)
				{
					check = 1
					g_doing1[id][task_id] = item
					g_doing3[id][task_id] = g_tasklist[item][TASK_DOING3NUM]
					colored_print(id, "\x04[任務]\x03 %s 開始進行。", g_tasklist[g_doing1[id][task_id]][TASK_NAME])
					show_menu_task(id)
				}
			}
		}
	}
	return PLUGIN_HANDLED
}

task_del(id, task)
{
	for(new task_complete;task_complete < TASKS_NUM;task_complete++)
	{
		if(task == g_task_done[id][task_complete])
		{
			g_task_done[id][task_complete] = 0
			return
		}
	}
}

public show_menu_change(id)
{
	static menu[128], menuid
	formatex(menu, charsmax(menu), "\w《轉換列表》^n\y請謹慎轉換")
	menuid = menu_create(menu, "menu_change")
	menu_additem(menuid, "\w100 SP : 1 Gash")
	menu_additem(menuid, "\w1000 SP : 10 Gash")
	menu_additem(menuid, "\w1 Gash : 95 SP")
	menu_additem(menuid, "\w10 Gash : 950 SP")
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public show_menu_choose2(id)
{
	static menuid
	menuid = menu_create("\w《商店列表》", "menu_choose2")
	menu_additem(menuid, "\wSP槍")
	menu_additem(menuid, "\w永久槍")
	menu_additem(menuid, "\w永久人")
	menu_additem(menuid, "\w特別槍 (高玩或以上)")
	menu_additem(menuid, "\w道具店")
	menu_additem(menuid, "\w永久刀")
	menu_additem(menuid, "\w兌換券商店")
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_choose2(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	switch (item)
	{
		case 0:
		{
			if (g_Player[id][Base][Boss]) colored_print(id, "\x04[系統]\x03 你是魔王不能購買 SP 槍。")
			else if (g_SelectedPri[id]) colored_print(id, "\x04[系統]\x03 你己選擇了槍械。")
			else show_menu_spgun(id)
		}
		case 1:
		{
			show_menu_buygun(id)
		}
		case 2:
		{
			show_menu_buymodel(id)
		}
		case 3:
		{
			if (!(get_user_flags(id) & ADMIN_RESERVATION)) colored_print(id, "\x04[系統]\x03 你沒有權限進入。")
			else show_menu_buypower(id)
		}
		case 4:
		{
			show_menu_shop(id)
		}
		case 5:
		{
			show_menu_buyknife(id)
		}
		case 6:
		{
			show_menu_coupon(id)
		}
	}
	return PLUGIN_HANDLED
}

public show_menu_spgun(id)
{
	new buffer[6], menu[128], menuid, count
	menuid = menu_create("\w《SP槍》^n\y請謹慎購買", "menu_spgun")
	
	if (!g_WeaponCount)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	else
	{
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_FOREVER)
			{
				formatex(menu, charsmax(menu), "\w%s \y%d SP", WeaponName[item], g_Player[id][Bag][SPCard] ? 0 : WeaponCostSP[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
				count++
			}
		}
		if (!count)
		{
			buffer[0] = -1
			menu_additem(menuid, "\w无", buffer)
		}
	}
	
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_spgun(id, menuid, item)
{
	static command[6], item_name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]

	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	if (g_Player[id][Base][SP] < WeaponCostSP[itemid] && !g_Player[id][Bag][SPCard])
	{
		colored_print(id, "\x04[購買]\x03 SP 不足");
	}
	else
	{
		drop_weapons(id, 1)
		if (!g_Player[id][Bag][SPCard])
		{
			g_Player[id][Base][SP] -= WeaponCostSP[itemid]
		}
		//client_cmd(id, "%s", g_wpncmd[itemid])
		ExecuteForward(g_fwWeaponBought, g_fwResult, id, itemid)
		g_SelectedWeapon[id][0] = itemid
		g_SelectedPri[id] = 1
		colored_print(id, "\x04[購買]\x03 成功購買 %s。", WeaponName[itemid])
	}
	return PLUGIN_HANDLED
}

public show_menu_buygun(id)
{
	new buffer[6], menu[128], menuid, count
	menuid = menu_create("\w《永久槍》^n\y請謹慎購買", "menu_buygun")

	if (!g_WeaponCount)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	else
	{
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_FOREVER && !g_UnlockedWeapon[id][item])
			{
				count++
				formatex(menu, charsmax(menu), "\w%s \r%d Gash", WeaponName[item], WeaponCostGash[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
			}
		}
		if (!count)
		{
			buffer[0] = -1
			menu_additem(menuid, "\w无", buffer)
		}
	}

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_buygun(id, menuid, item)
{
	static command[6], item_name[64], name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]

	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	get_user_name(id, name, charsmax(name))
	if (g_Player[id][Base][Gash] < WeaponCostGash[itemid])
	{
		colored_print(id, "\x04[購買]\x03 你的 Gash 不足。");
	}
	else
	{
		g_UnlockedWeapon[id][itemid] = 1
		g_Player[id][Base][Gash] -= WeaponCostGash[itemid]
		colored_print(id, "\x04[購買]\x03 成功購買 %s。", WeaponName[itemid]);
		log_to_file(g_logfile, "名稱: %s 槍械: %s (Buy Weapon)", name, WeaponName[itemid]);
	}
	return PLUGIN_HANDLED
}

public show_menu_buymodel(id)
{
	new buffer[6], menu[128], menuid, count
	menuid = menu_create("\w《永久人》^n\y請謹慎購買", "menu_buymodel")

	for (new skin;skin < sizeof g_skinlist;skin++)
	{
		if (!g_skin_info[id][skin][SKIN_HAVE])
		{
			formatex(menu, charsmax(menu), "\w%s \r%d Gash \w%s", g_skinlist[skin][SKIN_NAME], g_skinlist[skin][SKIN_COST], g_skinlist[skin][SKIN_NAME2]);
			buffer[0] = skin
			menu_additem(menuid, menu, buffer)
			count++
		}
	}
	if (!count)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_buymodel(id, menuid, item)
{
	static command[6], item_name[64], name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]

	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	get_user_name(id, name, charsmax(name))
	if (g_Player[id][Base][Gash] < g_skinlist[itemid][SKIN_COST])
	{
		colored_print(id, "\x04[購買]\x03 你的 Gash 不足。")
	}
	else
	{
		g_skin_info[id][itemid][SKIN_HAVE] = 1
		g_Player[id][Base][Gash] -= g_skinlist[itemid][SKIN_COST]
		colored_print(id, "\x04[購買]\x03 成功購買 %s。", g_skinlist[itemid][SKIN_NAME])
		log_to_file(g_logfile, "名稱: %s 人物: %s (Buy Model)", name, g_skinlist[itemid][SKIN_NAME])
	}
	return PLUGIN_HANDLED
}

public show_menu_buypower(id)
{
	new buffer[6], menu[128], menuid, count
	menuid = menu_create("\w《特別槍》^n\y請謹慎購買", "menu_buypower")

	if (!g_WeaponCount)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	else
	{
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_SPECIAL && !g_UnlockedWeapon[id][item])
			{
				formatex(menu, charsmax(menu), "\w%s \r%d Gash", WeaponName[item], WeaponCostGash[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
				count++
			}
		}
		if (!count)
		{
			buffer[0] = -1
			menu_additem(menuid, "\w无", buffer)
		}
	}

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_buypower(id, menuid, item)
{
	new command[6], item_name[64], name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]

	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	get_user_name(id, name, charsmax(name))
	if (g_Player[id][Base][Gash] < WeaponCostGash[itemid])
	{
		colored_print(id, "\x04[購買]\x03 你的 Gash 不足。")
	}
	else
	{
		g_UnlockedWeapon[id][itemid] = 1
		g_Player[id][Base][Gash] -= WeaponCostGash[itemid]
		colored_print(id, "\x04[購買]\x03 成功購買 %s。", WeaponName[itemid]);
		log_to_file(g_logfile, "名稱: %s 槍械: %s (Buy Weapon)", name, WeaponName[itemid]);
	}
	return PLUGIN_HANDLED
}

public Reset_WeaponBuy(id)
{
	arrayset(g_UnlockedWeapon[id], 0, MAX_WEAPONS)

	g_SelectedWeapon[id][0] = -1
	g_SelectedWeapon[id][1] = -1
	g_SelectedWeapon[id][2] = -1

	g_SelectedPri[id] = 0
	g_SelectedSec[id] = 0
	g_SelectedMelee[id] = 0
	
	if(g_WeaponCount)
	{
		for(new wep = 1;wep <= g_WeaponCount;wep++)
		{
			g_UnlockedWeapon[id][wep] = 0
		}
	}
}

public show_menu_shop(id)
{
	new menu[128], menuid
	menuid = menu_create("\w《道具店》", "menu_shop")
	
	menu_additem(menuid, "\w復活 \y2 Gash")
	menu_additem(menuid, "\w強光 \y5 SP")
	formatex(menu, charsmax(menu), "\w隱身 5 秒 \y25 SP \r[%d/3]", g_humanhide)
	menu_additem(menuid, menu)
	formatex(menu, charsmax(menu), "\w背包擴充  \y2000 SP \r[%d/10]", g_Player[id][Bag][Increase])
	menu_additem(menuid, menu)

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_shop(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	switch (item)
	{
		case 0:
		{
			if (g_Player[id][Base][Boss])
			{
				colored_print(id, "\x04[系統]\x03 你是魔王不能復活。")
				return PLUGIN_HANDLED
			}
			if (g_endround)
			{
				colored_print(id, "\x04[購買]\x03 回合已經完結。")
				return PLUGIN_HANDLED
			}
			if (g_Player[id][Base][RespawnCount] > 0)
			{
				colored_print(id, "\x04[購買]\x03 一回合只可用一次。")
				return PLUGIN_HANDLED
			}
			if (g_min < 2)
			{
				colored_print(id, "\x04[購買]\x03 最後二分鐘不能復活。")
				return PLUGIN_HANDLED
			}
			if (g_Player[id][Base][Gash] < 2)
			{
				colored_print(id, "\x04[購買]\x03 你的 Gash 不足。")
				return PLUGIN_HANDLED
			}
			if (is_user_alive(id))
			{
				colored_print(id, "\x04[購買]\x03 必須要死亡。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][Gash] -= 2
			g_Player[id][Base][RespawnCount] = 1
			make_human(id)
			colored_print(id, "\x04[購買]\x03 你成功復活了。")
		}
		case 1:
		{
			if (g_Player[id][Base][Boss])
			{
				colored_print(id, "\x04[系統]\x03 你是魔王不必購買。")
				return PLUGIN_HANDLED
			}
			if (g_endround)
			{
				colored_print(id, "\x04[購買]\x03 回合已經完結。")
				return PLUGIN_HANDLED
			}
			if (g_Player[id][Base][SP] < 5)
			{
				colored_print(id, "\x04[購買]\x03 SP不足!")
				return PLUGIN_HANDLED
			}
			if (!is_user_alive(id))
			{
				colored_print(id, "\x04[購買]\x03 必須要生存。")
				return PLUGIN_HANDLED
			}
			if (g_nvision[id])
			{
				colored_print(id, "\x04[購買]\x03 你已經購買了。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][SP] -= 5
			g_nvision[id] = 1
			g_nvisionenabled[id] = 1
			message_begin(MSG_ONE_UNRELIABLE, SVC_LIGHTSTYLE, _, id)
			write_byte(0)
			write_string("Z")
			message_end()
			remove_task(id + TASK_NIGHTVISION)
			set_task(0.1, "set_user_nvision", id + TASK_NIGHTVISION)
			colored_print(id, "\x04[購買]\x03 成功購買強光")
		}
		case 2:
		{
			if (g_Player[id][Base][Boss])
			{
				colored_print(id, "\x04[系統]\x03 你是魔王不能使用。")
				return PLUGIN_HANDLED
			}
			if (g_endround)
			{
				colored_print(id, "\x04[購買]\x03 回合已經完結。")
				return PLUGIN_HANDLED
			}
			if (!is_user_alive(id))
			{
				colored_print(id, "\x04[購買]\x03 必須要活着。")
				return PLUGIN_HANDLED
			}
			if (g_humanhide)
			{
				if (g_min < 2)
				{
					colored_print(id, "\x04[購買]\x03 最後二分鐘不能使用。")
					return PLUGIN_HANDLED
				}
				if (g_Player[id][Base][SP] < 25)
				{
					colored_print(id, "\x04[購買]\x03 你的 SP 不足。")
					return PLUGIN_HANDLED
				}
				g_Player[id][Base][SP] -= 25
				g_humanhide--
				set_entity_visibility(id, 0)
				g_Player[id][Base][Status] = 11
				g_Player[id][Base][Hide] = 1
				set_task(5.0, "remove_hide", id)
				colored_print(id, "\x04[購買]\x03 你成功使用了隐身。")
			}
			else colored_print(id, "\x04[購買]\x03 資源不足。")
			return PLUGIN_HANDLED
		}
		case 3:
		{
			if (g_Player[id][Bag][Increase] >= 10)
			{
				colored_print(id, "\x04[購買]\x03 不能再買。")
				return PLUGIN_HANDLED
			}
			if (g_Player[id][Base][SP] < 2000)
			{
				colored_print(id, "\x04[購買]\x03 你的 SP 不足。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][SP] -= 2000
			g_Player[id][Bag][Increase] += 1
			colored_print(id, "\x04[購買]\x03 你成功購買了。")
		}
	}
	return PLUGIN_HANDLED
}

public show_menu_buyknife(id)
{
	new buffer[6], menu[128], menuid, count
	menuid = menu_create("\w《永久刀》^n\y請謹慎購買", "menu_buyknife")

	if (!g_WeaponCount)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	else
	{
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_KNIFE && !g_UnlockedWeapon[id][item])
			{
				formatex(menu, charsmax(menu), "\w%s \r%d Gash %s", WeaponName[item], WeaponCostGash[item], WeaponCommit[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
				count++
			}
		}
		if (!count)
		{
			buffer[0] = -1
			menu_additem(menuid, "\w无", buffer)
		}
	}
	
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_buyknife(id, menuid, item)
{
	new command[6], item_name[64], name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]
	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	get_user_name(id, name, charsmax(name))
	
	if (g_Player[id][Base][Gash] < WeaponCostGash[itemid])
	{
		colored_print(id, "\x04[購買]\x03 你的 Gash 不足。")
	}
	else
	{
		g_UnlockedWeapon[id][itemid] = 1
		g_Player[id][Base][Gash] -= WeaponCostGash[itemid]
		colored_print(id, "\x04[購買]\x03 成功購買 %s。", WeaponName[itemid])
		log_to_file(g_logfile, "名稱: %s 槍械: %s (Buy Weapon)", name, WeaponName[itemid])
	}
	return PLUGIN_HANDLED
}

public show_menu_coupon(id)
{
	static menuid
	menuid = menu_create("\w《兌換券商店》^n\r請先檢查背包是否有足夠的位置", "menu_coupon")
	menu_additem(menuid, "\wSP槍免費卡 (一回合) x 5 \y1 兌換券")
	menu_additem(menuid, "\w特別槍免費卡 (一回合) x 3 \y2 兌換券")
	menu_additem(menuid, "\w速度寶石 x 1 \y3 兌換券")
	menu_additem(menuid, "\w攻擊寶石 x 1 \y5 兌換券")
	menu_additem(menuid, "\w雙倍經驗 (1小時) x 1 \y5 兌換券")
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_coupon(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	switch (item)
	{
		case 0:
		{
			if (g_Player[id][Base][Coupon] < 1)
			{
				colored_print(id, "\x04[購買]\x03 你的兌換券不足。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][Coupon] -= 1
			add_exchange_item(id, 18, 5)
			colored_print(id, "\x04[兌換]\x03 你成功兌換SP槍免費卡 (一回合) x 5。");
		}
		case 1:
		{
			if (g_Player[id][Base][Coupon] < 2)
			{
				colored_print(id, "\x04[購買]\x03 你的兌換券不足。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][Coupon] -= 2
			add_exchange_item(id, 19, 3)
			colored_print(id, "\x04[兌換]\x03 你成功兌換特別槍免費卡 (一回合) x 3。")
		}
		case 2:
		{
			if (g_Player[id][Base][Coupon] < 3)
			{
				colored_print(id, "\x04[購買]\x03 你的兌換券不足。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][Coupon] -= 3
			add_exchange_item(id, 5, 1)
			colored_print(id, "\x04[兌換]\x03 你成功兌換速度寶石 x 1。")
		}
		case 3:
		{
			if (g_Player[id][Base][Coupon] < 5)
			{
				colored_print(id, "\x04[購買]\x03 你的兌換券不足。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][Coupon] -= 5
			add_exchange_item(id, 4, 1)
			colored_print(id, "\x04[兌換]\x03 你成功兌換攻擊寶石 x 1。")
		}
		case 4:
		{
			if (g_Player[id][Base][Coupon] < 5)
			{
				colored_print(id, "\x04[購買]\x03 你的兌換券不足。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][Coupon] -= 5
			add_exchange_item(id, 12, 1)
			colored_print(id, "\x04[兌換]\x03 你成功兌換雙倍經驗 (1小時) x 1。")
		}
	}
	return PLUGIN_HANDLED
}

show_menu_bag(id)
{
	static buffer[6], menu[128], menuid
	formatex(menu, charsmax(menu), "\w《物品欄》^n\y你還可以使用 %d 次物品", g_Player[id][Bag][UseLimit])
	menuid = menu_create(menu, "menu_bag")
	for (new item = 0;item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];item++)
	{
		formatex(menu, charsmax(menu), "\w%s \r[%d/5]", g_BagItem[g_Player[id][Bag][Index][item]][BAG_ITEMNAME], g_Player[id][Bag][Amount][item])
		buffer[0] = g_Player[id][Bag][Index][item]
		menu_additem(menuid, menu, buffer)
	}
	buffer[0] = sizeof g_BagItem
	menu_additem(menuid, "\r整理背包 \y10 SP", buffer)
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_bag(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new command[6], item_name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]
	
	if (itemid)
	{
		if (itemid == sizeof(g_BagItem) - 1)
		{
			colored_print(id, "\x04[物品]\x03 選擇錯誤")
			show_menu_bag(id)
			return PLUGIN_HANDLED
		}
		if (itemid == sizeof g_BagItem)
		{
			if (g_Player[id][Base][SP] < 10)
			{
				colored_print(id, "\x04[物品]\x03 SP不足!")
				show_menu_bag(id)
				return PLUGIN_HANDLED
			}
			new item_type[33], num_type[33]
			
			for (new bag_item;bag_item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];bag_item++)
			{
				if (g_Player[id][Bag][Index][bag_item] && g_Player[id][Bag][Index][bag_item] != sizeof(g_BagItem) - 1 && g_Player[id][Bag][Amount][bag_item])
				{
					item_type[id] = g_Player[id][Bag][Index][bag_item]
					num_type[id] = g_Player[id][Bag][Amount][bag_item]
					g_Player[id][Bag][Index][bag_item] = 0
					g_Player[id][Bag][Amount][bag_item] = 0
					add_bag_item(id, item_type[id], num_type[id], false, 0)
				}
			}
			g_Player[id][Base][SP] -= 10
			show_menu_bag(id)
			colored_print(id, "\x04[物品]\x03 重置完成")
			return PLUGIN_HANDLED
		}
		show_menu_beitem(id, itemid)
		return PLUGIN_HANDLED
	}
	colored_print(id, "\x04[物品]\x03 空位不能選擇")
	show_menu_bag(id)
	return PLUGIN_HANDLED
}

show_menu_beitem(id, itemid)
{
	static buffer[6], menu[1000], menuid
	formatex(menu, charsmax(menu), "\w如何處理: \y%s^n\w說明: \y%s", g_BagItem[itemid][BAG_ITEMNAME], g_BagItem[itemid][BAG_ITEM_MENUTIPS])
	menuid = menu_create(menu, "menu_beitem")
	buffer[0] = itemid
	if (((is_user_alive(id) && g_BagItem[itemid][BAG_ITEMCANUSE]) || (!is_user_alive(id) && !g_BagItem[itemid][BAG_ITEMMUSTALIVE])) && !g_Player[id][Base][Boss])
	{
		menu_additem(menuid, "\w使用\r", buffer)
	}
	else
	{
		menu_additem(menuid, "\d使用\r", buffer)
	}
	menu_additem(menuid, "\w扔棄\r", buffer)
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_beitem(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		show_menu_bag(id);
		return PLUGIN_HANDLED
	}
	new command[6], item_name[64], access, callback
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	new itemid = command[0]
	new name[64]
	get_user_name(id, name, charsmax(name))
	if (item)
	{
		colored_print(id, "\x04[物品]\x03 你已扔棄 \x04%s", g_BagItem[itemid][BAG_ITEMNAME])
		log_to_file(g_logfile, "名稱: %s 物品: %s (Deleted Item)", name, g_BagItem[itemid][BAG_ITEMNAME])
		del_item(id, itemid)
	}
	else
	{
		if (g_Player[id][Bag][UseLimit] < 1 && g_BagItem[itemid][BAG_ITEMUSELIMIT])
		{
			colored_print(id, "\x04[物品]\x03 到達限制不能使用物品。")
			return PLUGIN_HANDLED
		}
		if (g_mode == MODE_ESCAPE)
		{
			colored_print(id, "\x04[物品]\x03 逃亡模式不能使用物品。")
			return PLUGIN_HANDLED
		}
		if (!g_BagItem[itemid][BAG_ITEMCANUSE])
		{
			colored_print(id, "\x04[物品]\x03 特別物品不能使用")
			show_menu_beitem(id, itemid)
			return PLUGIN_HANDLED
		}
		if (!is_user_alive(id) && g_BagItem[itemid][BAG_ITEMMUSTALIVE])
		{
			colored_print(id, "\x04[物品]\x03 死亡時不能使用此物品")
			show_menu_beitem(id, itemid)
			return PLUGIN_HANDLED
		}
		if (g_Player[id][Base][Boss])
		{
			colored_print(id, "\x04[物品]\x03 魔王不能使用物品")
			show_menu_beitem(id, itemid)
			return PLUGIN_HANDLED
		}
		use_bag_item(id, itemid)
	}
	return PLUGIN_HANDLED
}


show_menu_skill_pt(id)
{
	static menu[128], menuid
	menuid = menu_create("\w《人類能力表》^n\y請謹慎選擇", "SkillptCommand")
	formatex(menu, charsmax(menu), "\w血量 \r[%d/%d] \w- [血量: \r100 + %d\w] \d1 能力點", max_hp[id], limit_skill[id][0], max_hp[id]);
	menu_additem(menuid, menu)
	formatex(menu, charsmax(menu), "\w速度 \r[%d/%d] \w- [速度: \r250 + %d\w] \d2 能力點", max_speed[id], limit_skill[id][1], max_speed[id]);
	menu_additem(menuid, menu)
	formatex(menu, charsmax(menu), "\w攻擊力 \r[%d/%d] \w- [攻擊力: \r100%% + %d\w] \d4 能力點", max_damage[id], limit_skill[id][2], max_damage[id]);
	menu_additem(menuid, menu)
	formatex(menu, charsmax(menu), "\w跳躍力 \r[%d/%d] \w- [跳躍力: \r800 - %d\w] \d15 能力點", max_jump[id], limit_skill[id][3], max_jump[id] * 16);
	menu_additem(menuid, menu)
	if (!g_job[id])
	{
		formatex(menu, charsmax(menu), "\r請先選擇職業")
	}
	else
	{
		formatex(menu, charsmax(menu), "\w職業技能")
	}
	menu_additem(menuid, menu)
	formatex(menu, charsmax(menu), "\w重置 職業|技能 \y500 SP ")
	menu_additem(menuid, menu)

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public SkillptCommand(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	switch (item)
	{
		case 0:
		{
			if (max_hp[id] >= limit_skill[id][0])
			{
				colored_print(id, "已經是最高等級")
			}
			else
			{
				if (g_skpoint[id] < 1)
				{
					colored_print(id, "你沒有足夠的能力點")
				}
				else
				{
					max_hp[id]++
					g_skpoint[id]--
				}
			}
		}
		case 1:
		{
			if (max_speed[id] >= limit_skill[id][1])
			{
				colored_print(id, "已經是最高等級")
			}
			else
			{
				if (g_skpoint[id] < 2)
				{
					colored_print(id, "你沒有足夠的能力點")
				}
				else
				{
					max_speed[id]++
					g_skpoint[id]-=2
				}
			}
		}
		case 2:
		{
			if (max_damage[id] >= limit_skill[id][2])
			{
				colored_print(id, "已經是最高等級")
			}
			else
			{
				if (g_skpoint[id] < 4)
				{
					colored_print(id, "你沒有足夠的能力點")
				}
				else
				{
					max_damage[id]++
					g_skpoint[id]-=4
				}
			}
		}
		case 3:
		{
			if (max_jump[id] >= limit_skill[id][3])
			{
				colored_print(id, "已經是最高等級")
			}
			else
			{
				if (g_skpoint[id] < 15)
				{
					colored_print(id, "你沒有足夠的能力點")
				}
				else
				{
					max_jump[id]++
					g_skpoint[id]-=15
				}
			}
		}
		case 4:
		{
			show_menu_job(id)
			return PLUGIN_HANDLED
		}
		case 5:
		{
			if (g_Player[id][Base][SP] < 500)
			{
				colored_print(id, "SP不足!")
			}
			else
			{
				if(g_job[id])
				{
					g_skpoint[id] = g_Player[id][Base][Level]
					max_hp[id] -= max_hp[id]
					max_speed[id] -= max_speed[id]
					max_damage[id] -= max_damage[id]
					max_jump[id] -= max_jump[id]
					g_job[id] = 0
					for(new i;i<12;i++)
					{
						job_skill[id][i] = 0
					}
					limit_skill[id][0] = 0
					limit_skill[id][1] = 0
					limit_skill[id][2] = 0
					limit_skill[id][3] = 0
					g_Player[id][Base][SP]-=500
				}
				else
				{
					colored_print(id, "您只能在选择职业后重置!")
				}
			}
		}
	}
	show_menu_skill_pt(id)
	return PLUGIN_HANDLED
}


show_menu_job(id)
{
	static menu[128], menuid
	if (!g_job[id])
	{
		formatex(menu, charsmax(menu), "\w《職業選擇》^n\y請謹慎選擇")
	}
	else
	{
		formatex(menu, charsmax(menu), "\w《職業技能》^n\y請謹慎選擇")
	}
	menuid = menu_create(menu, "job_select")
	if (!g_job[id])
	{
		formatex(menu, charsmax(menu), "\w生存型")
		menu_additem(menuid, menu)
		formatex(menu, charsmax(menu), "\w運動型")
		menu_additem(menuid, menu)
		formatex(menu, charsmax(menu), "\w肌肉型")
		menu_additem(menuid, menu)
		formatex(menu, charsmax(menu), "\w靈活型")
		menu_additem(menuid, menu)
		formatex(menu, charsmax(menu), "\w查看說明")
		menu_additem(menuid, menu)
	}
	else
	{
		if (g_job[id] == 1)
		{
			formatex(menu, charsmax(menu), "\w精密射擊 \r[%d/5] \w- [效果: \r%d秒內傷害完全爆頭\w] \d40 能力點", job_skill[id][0], job_skill[id][0] * 2 + 5) //√
			menu_additem(menuid, menu)
			formatex(menu, charsmax(menu), "\w吸收傷害 \r[%d/5] \w- [效果: \r5000傷害吸收  %d HP[最大吸收150HP]\w] \d30 能力點", job_skill[id][1], job_skill[id][1]) //√
			menu_additem(menuid, menu)
			formatex(menu, charsmax(menu), "\w抵抗中毒 \r[%d/5] \w- [效果: \r中毒效果 - %d％\w] \d30 能力點", job_skill[id][2], job_skill[id][2] * 10) //√
			menu_additem(menuid, menu)
		}
		if (g_job[id] == 2)
		{
			formatex(menu, charsmax(menu), "\w小刀爆發 \r[%d/5] \w- [效果: \r%d秒內小刀重擊力為%d\w] \d40 能力點", job_skill[id][3], job_skill[id][3] + 10, job_skill[id][3] * 400 + 3000) //√
			menu_additem(menuid, menu)
			formatex(menu, charsmax(menu), "\w無聲走路 \r[%d/1] \w- [效果: \r走路無任何聲音發出\w] \d150 能力點", job_skill[id][4], job_skill[id][4]) //√
			menu_additem(menuid, menu)
			formatex(menu, charsmax(menu), "\w傷害降低 \r[%d/5] \w- [效果: \r受到傷害 - %d％\w] \d30 能力點", job_skill[id][5], job_skill[id][5] * 4) //√
			menu_additem(menuid, menu)
		}
		if (g_job[id] == 3)
		{
			formatex(menu, charsmax(menu), "\w傷害爆發 \r[%d/5] \w- [效果: \r%d內傷害 1.5倍 \w] \d40 能力點", job_skill[id][6], job_skill[id][6] * 2 + 10) //√
			menu_additem(menuid, menu)
			formatex(menu, charsmax(menu), "\w傷害降低 \r[%d/5] \w- [效果: \r受到傷害 - %d％\w] \d30 能力點", job_skill[id][7], job_skill[id][7] * 4) //√
			menu_additem(menuid, menu)
			formatex(menu, charsmax(menu), "\w抵抗速度下降 \r[%d/5] \w- [效果: \r速度下降效果 - %d％\w] \d30 能力點", job_skill[id][8], job_skill[id][8] * 10) //√
			menu_additem(menuid, menu)
		}
		if (g_job[id] == 4)
		{
			formatex(menu, charsmax(menu), "\w隱身 \r[%d/5] \w- [效果: \r%d內進入隱身狀態 \w] \d40 能力點", job_skill[id][9], job_skill[id][9] + 5) //√
			menu_additem(menuid, menu)
			formatex(menu, charsmax(menu), "\w物品掉獲率 \r[%d/1] \w- [效果: \r獲得物品機率 + %d ％\w] \d150 能力點", job_skill[id][10], job_skill[id][10] * 20) //√
			menu_additem(menuid, menu)
			formatex(menu, charsmax(menu), "\w小刀擊退 \r[%d/5] \w- [效果: \r%d％機率可以小刀右鍵彈走魔王\w] \d30 能力點", job_skill[id][11], job_skill[id][11] * 12)
			menu_additem(menuid, menu)
		}
	}
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public job_select(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new command[6], item_name[64], access, callback
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	if (!g_job[id])
	{
		switch (item)
		{
			case 0:
			{
				g_job[id] = 1
				limit_skill[id][0] = 100
				limit_skill[id][1] = 20
				limit_skill[id][2] = 20
				limit_skill[id][3] = 5
				g_skpoint[id] = g_Player[id][Base][Level]
				max_hp[id] -= max_hp[id]
				max_speed[id] -= max_speed[id]
				max_damage[id] -= max_damage[id]
				max_jump[id] -= max_jump[id]
			}
			case 1:
			{
				g_job[id] = 2
				limit_skill[id][0] = 60
				limit_skill[id][1] = 40
				limit_skill[id][2] = 20
				limit_skill[id][3] = 5
				g_skpoint[id] = g_Player[id][Base][Level]
				max_hp[id] -= max_hp[id]
				max_speed[id] -= max_speed[id]
				max_damage[id] -= max_damage[id]
				max_jump[id] -= max_jump[id]
			}
			case 2:
			{
				g_job[id] = 3
				limit_skill[id][0] = 60
				limit_skill[id][1] = 20
				limit_skill[id][2] = 40
				limit_skill[id][3] = 5
				g_skpoint[id] = g_Player[id][Base][Level]
				max_hp[id] -= max_hp[id]
				max_speed[id] -= max_speed[id]
				max_damage[id] -= max_damage[id]
				max_jump[id] -= max_jump[id]
			}
			case 3:
			{
				g_job[id] = 4
				limit_skill[id][0] = 60
				limit_skill[id][1] = 20
				limit_skill[id][2] = 20
				limit_skill[id][3] = 15
				g_skpoint[id] = g_Player[id][Base][Level]
				max_hp[id] -= max_hp[id]
				max_speed[id] -= max_speed[id]
				max_damage[id] -= max_damage[id]
				max_jump[id] -= max_jump[id]
			}
			case 4:
			{
				static len, motd[5000]
				len = 0
				len = formatex(motd[len], 4999 - len, "<meta http-equiv='content-type' content='text/html; charset=UTF-8'><body bgcolor=#000000><font color=#FFB000><pre>") + len
				len = formatex(motd[len], 4999 - len, "<center>生存型最大上限</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>血量: 100點 | 速度: 20點 | 傷害: 30點 重力: 8點</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 精密射擊: X秒內所有射擊全部定義為爆頭 [會因等級而增加秒數] </center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 吸收傷害: 5000 傷害 增加 血量 [每生命限加150血]</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 抵抗中毒: 按等級 下降對中毒的影響</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>------------------------------------</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>運動型最大上限</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>血量: 60點 | 速度: 40點 | 傷害: 30點 | 重力: 10點</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 小刀爆發 X秒內增加小刀重擊攻擊力 [會因等級而增加秒數和傷害]</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 無聲走路 走路無無</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 傷害降低 按等級 降低王造成的傷害 </center>") + len
				len = formatex(motd[len], 4999 - len, "<center>------------------------------------</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>肌肉型最大上限</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>血量: 60點 | 速度: 20點 | 傷害: 50點 | 重力: 10點</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 傷害爆發 X秒內傷害1.5倍 [會按等級而增加秒數]</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 抵抗速度下降 按等級 下降速度下降的影響</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 傷害降低 按等級 降低王造成的傷害 </center>") + len
				len = formatex(motd[len], 4999 - len, "<center>------------------------------------</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>靈活型最大上限</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>血量: 60點 | 速度: 20點 | 傷害: 20點 | 重力: 15點</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 隱身 隱身X秒 [按等級而增加秒數]</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 物品掉獲率 增加物品掉獲率 </center>") + len
				len = formatex(motd[len], 4999 - len, "<center>技能: 小刀擊退 按等級增加擊退效果</center>") + len
				len = formatex(motd[len], 4999 - len, "<center>------------------------------------</center>") + len
				show_motd(id, motd, "能力介紹")
			}
		}
	}
	else
	{
		if (g_job[id] == 1)
		{
			switch (item)
			{
				case 0:
				{
					if (job_skill[id][0] >= 5)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 40)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][0] += 1
							g_skpoint[id] -= 40
						}
					}
				}
				case 1:
				{
					if (job_skill[id][1] >= 5)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 30)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][1] += 1
							g_skpoint[id] -= 30
						}
					}
				}
				case 2:
				{
					if (job_skill[id][2] >= 5)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 30)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][2] += 1
							g_skpoint[id] -= 30
						}
					}
				}
			}
		}
		else if (g_job[id] == 2)
		{
			switch (item)
			{
				case 0:
				{
					if (job_skill[id][3] >= 5)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 40)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][3] += 1
							g_skpoint[id] -= 40
						}
					}
				}
				case 1:
				{
					if (job_skill[id][4] >= 1)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 150)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][4] += 1
							g_skpoint[id] -= 150
						}
					}
				}
				case 2:
				{
					if (job_skill[id][5] >= 5)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 30)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][5] += 1
							g_skpoint[id] -= 30
						}
					}
				}
			}
		}
		else if (g_job[id] == 3)
		{
			switch (item)
			{
				case 0:
				{
					if (job_skill[id][6] >= 5)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 40)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][6] += 1
							g_skpoint[id] -= 40
						}
					}
				}
				case 1:
				{
					if (job_skill[id][7] >= 5)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 30)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][7] += 1
							g_skpoint[id] -= 30
						}
					}
				}
				case 2:
				{
					if (job_skill[id][8] >= 5)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 30)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][8] += 1
							g_skpoint[id] -= 30
						}
					}
				}
			}
		}
		else if (g_job[id] == 4)
		{
			switch (item)
			{
				case 0:
				{
					if (job_skill[id][9] >= 5)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 40)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][9] += 1
							g_skpoint[id] -= 40
						}
					}
				}
				case 1:
				{
					if (job_skill[id][10] >= 1)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 150)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][10] += 1
							g_skpoint[id] -= 150
						}
					}
				}
				case 2:
				{
					if (job_skill[id][11] >= 5)
					{
						colored_print(id, "已經是最高等級")
					}
					else
					{
						if (g_skpoint[id] < 30)
						{
							colored_print(id, "你沒有足夠的能力點")
						}
						else
						{
							job_skill[id][11] += 1
							g_skpoint[id] -= 30
						}
					}
				}
			}
		}
	}
	show_menu_job(id)
	return PLUGIN_HANDLED
}

del_item2(id, item, num)
{
	
	for (new bag_item;bag_item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];bag_item++)
	{
		if (num)
		{
			if (item == g_Player[id][Bag][Index][bag_item])
			{
				if (g_Player[id][Bag][Amount][bag_item] < 2)
				{
					g_Player[id][Bag][Index][bag_item] = 0
					g_Player[id][Bag][Amount][bag_item] = 0
					num--
				}
				else
				{
					new check = g_Player[id][Bag][Amount][bag_item][check];
					if (check > num)
					{
						check = num;
					}
					num -= g_Player[id][Bag][Amount][bag_item]
					g_Player[id][Bag][Amount][bag_item] -= check
					if (!g_Player[id][Bag][Amount][bag_item])
					{
						g_Player[id][Bag][Index][bag_item] = 0
					}
				}
			}
		}
		show_menu_bag(id);
		return PLUGIN_CONTINUE
	}
	show_menu_bag(id);
	return PLUGIN_CONTINUE
}

del_item(id, item)
{
	new check;
	
	for (new bag_item;bag_item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];bag_item++)
	{
		if (item == g_Player[id][Bag][Index][bag_item])
		{
			if (g_Player[id][Bag][Amount][bag_item] < 2)
			{
				check = 1;
				g_Player[id][Bag][Index][bag_item] = 0
				g_Player[id][Bag][Amount][bag_item] = 0
				if (check)
				{
					show_menu_bag(id);
				}
				else
				{
					show_menu_beitem(id, item)
				}
				return PLUGIN_CONTINUE
			}
			g_Player[id][Bag][Amount][bag_item]--
			if (check)
			{
				show_menu_bag(id)
			}
			else
			{
				show_menu_beitem(id, item)
			}
			return PLUGIN_CONTINUE
		}
	}
	if (check)
	{
		show_menu_bag(id);
	}
	else
	{
		show_menu_beitem(id, item);
	}
	return PLUGIN_CONTINUE
}

use_bag_item(id, item)
{
	new name[64]
	get_user_name(id, name, charsmax(name))
	switch (item)
	{
		case 0:
		{
			colored_print(id, "\x04[%s]\x03无效的物品", g_msgtype[1])
			return PLUGIN_CONTINUE
		}
		case 1:
		{
			client_cmd(id, "spk %s", g_Hp)
			fm_set_user_health(id, 100)
		}
		case 2:
		{
			client_cmd(id, "spk %s", g_Hp)
			fm_set_user_health(id, 150)
		}
		case 3:
		{
			client_cmd(id, "spk %s", g_Hp)
			fm_set_user_health(id, 200)
		}
		case 4:
		{
			if (g_Player[id][Bag][AttackGem])
			{
				colored_print(id, "\x04[%s]\x03 你已经使用过该物品了！", g_msgtype[1]);
				return PLUGIN_CONTINUE
			}
			else g_Player[id][Bag][AttackGem] = true
		}
		case 5:
		{
			if (g_Player[id][Bag][SpeedGem])
			{
				colored_print(id, "\x04[%s]\x03 你已经使用过该物品了！", g_msgtype[1]);
				return PLUGIN_CONTINUE
			}
			else g_Player[id][Bag][SpeedGem] = true
		}
		case 6:
		{
			g_Player[id][Base][XP] += 20000
			g_Player[id][Base][SP] += 100
			colored_print(0, "\x04[%s]\x03 %s 開啟等級20獎勵箱獲得 20000 經驗值、100 SP", g_msgtype[1], name)
		}
		case 7:
		{
			g_Player[id][Base][XP] += 50000
			g_Player[id][Base][SP] += 1000
			colored_print(0, "\x04[%s]\x03 %s 開啟神祕獎勵箱獲得 ？？？？？？", g_msgtype[0], name)
		}
		case 8:
		{
			g_Player[id][Base][XP] += 40000;
			add_exchange_item(id, 5, 2);
			colored_print(0, "\x04[%s]\x03 %s 開啟等級40獎勵箱獲得 40000 經驗值、速度寶石 x 2 個", g_msgtype[1], name);
		}
		case 9:
		{
			g_Player[id][Base][XP] += 60000;
			add_exchange_item(id, 3, 5);
			colored_print(0, "\x04[%s]\x03 %s 開啟等級60獎勵箱獲得 60000 經驗值、紅色蘋果 x 5 個", g_msgtype[1], name);
		}
		case 10:
		{
			g_Player[id][Base][XP] += 80000;
			add_exchange_item(id, 3, 10)
			colored_print(0, "\x04[%s]\x03 %s 開啟等級80獎勵箱獲得 80000 經驗值、紅色蘋果 x 10 個", g_msgtype[1], name)
		}
		case 11:
		{
			g_Player[id][Base][XP] += 100000
			g_Player[id][Base][SP] += 1000
			colored_print(0, "\x04[%s]\x03 %s 開啟等級100獎勵箱獲得 100000 經驗值、1000 SP", g_msgtype[1], name)
		}
		case 12:
		{
			exp_x2[id] = 1
			exp_x2_time[id] += 3600
			if (!task_exists(id + TASK_EXPX2))
			{
				set_task(1.0, "limit_item", id + TASK_EXPX2)
			}
		}
		case 13:
		{
			client_cmd(id, "spk %s", g_Hp)
			fm_set_user_health(id, 150)
		}
		case 14:
		{
			client_cmd(id, "spk %s", g_Hp)
			fm_set_user_health(id, 180)
		}
		case 15:
		{
			client_cmd(id, "spk %s", g_Hp)
			fm_set_user_health(id, 100)
		}
		case 16:
		{
			client_cmd(id, "spk %s", g_Hp)
			fm_set_user_health(id, 130)
		}
		case 17:
		{
			client_cmd(id, "spk %s", g_Hp)
			fm_set_user_health(id, 200)
		}
		case 18:
		{
			if(g_SelectedPri[id])
			{
				colored_print(id, "\x04[%s]\x03 你己選擇了槍械。", g_msgtype[1])
				return PLUGIN_CONTINUE
			}
			if(g_Player[id][Bag][SPCard])
			{
				colored_print(id, "\x04[%s]\x03 您已经使用过该物品了", g_msgtype[1])
				return PLUGIN_CONTINUE
			}
			g_Player[id][Bag][SPCard] = true
		}
		case 19:
		{
			if(g_SelectedPri[id])
			{
				colored_print(id, "\x04[%s]\x03 你己選擇了槍械。", g_msgtype[1])
				return PLUGIN_CONTINUE
			}
			if(g_Player[id][Bag][PowerCard])
			{
				colored_print(id, "\x04[%s]\x03 您已经使用过该物品了", g_msgtype[1])
				return PLUGIN_CONTINUE
			}
			g_Player[id][Bag][PowerCard] = true
		}
		case sizeof(g_BagItem) - 1:
		{
			colored_print(id, "\x04[%s]\x03无效的物品", g_msgtype[1])
			return PLUGIN_CONTINUE
		}
		default :
		{
			colored_print(id, "\x04[%s]\x03无效的物品", g_msgtype[1])
			return PLUGIN_CONTINUE
		}
	}
	colored_print(id, "\x04[物品]\x03 成功使用此物品，\x04%s", g_BagItem[item][BAG_ITEM_USEDMSG])
	log_to_file(g_logfile, "名稱: %s 物品: %s (Used Item)", name, g_BagItem[item][BAG_ITEMNAME])
	del_item(id, item)
	if (g_BagItem[item][BAG_ITEMUSELIMIT]) g_Player[id][Bag][UseLimit]--
	return PLUGIN_CONTINUE
}

public menu_change(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new name[64]
	get_user_name(id, name, charsmax(name))
	switch (item)
	{
		case 0:
		{
			if (g_Player[id][Base][SP] < 100)
			{
				colored_print(id, "\x04[系統]\x03 你的 SP 不足。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][Gash]++
			g_Player[id][Base][SP] -= 100
			log_to_file(g_logfile, "名稱: %s 轉換: 1 (Change Gash)", name)
		}
		case 1:
		{
			if (g_Player[id][Base][SP] < 1000)
			{
				colored_print(id, "\x04[系統]\x03 你的 SP 不足。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][Gash] += 10
			g_Player[id][Base][SP] -= 1000
			log_to_file(g_logfile, "名稱: %s 轉換: 10 (Change Gash)", name)
		}
		case 2:
		{
			if (g_Player[id][Base][Gash] < 1)
			{
				colored_print(id, "\x04[系統]\x03 你的 Gash 不足。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][SP] += 95
			g_Player[id][Base][Gash]--
			log_to_file(g_logfile, "名稱: %s 轉換: 1 (Change SP)", name)
		}
		case 3:
		{
			if (g_Player[id][Base][Gash] < 10)
			{
				colored_print(id, "\x04[系統]\x03 你的 Gash 不足。")
				return PLUGIN_HANDLED
			}
			g_Player[id][Base][SP] += 950
			g_Player[id][Base][Gash] -= 10
			log_to_file(g_logfile, "名稱: %s 轉換: 10 (Change SP)", name)
		}
	}
	show_menu_change(id)
	return PLUGIN_HANDLED
}

public clcmd_drop(id)
{
	if (!is_user_alive(id)) return PLUGIN_CONTINUE
	
	if (g_Player[id][Base][Boss] && g_random == 2)
	{
		new menuid = menu_create("\y《技能列表》", "menu_drop3")
		menu_additem(menuid, "\w長跳 (333 Reload)")
		menu_additem(menuid, "\w加速 10 秒 (333 Reload)")
		menu_additem(menuid, "\w隱身 10 秒 (333 Reload)")
		menu_additem(menuid, "\w無敵 5 秒 (333 Reload)")
		menu_additem(menuid, "\w超級高跳 (333 Reload)")
		menu_additem(menuid, "\w範圍內的人速度下降 (333 Reload)")
		menu_additem(menuid, "\w範圍內的人中毒 (333 Reload)")
		menu_additem(menuid, "\w範圍內的人彈走 (888 Reload)")
		menu_setprop(menuid, MPROP_BACKNAME, "返回")
		menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
		menu_setprop(menuid, MPROP_EXITNAME, "離開")
		menu_display(id, menuid)
	}
	if (g_Player[id][Base][Boss] && g_random == 1)
	{
		new menuid = menu_create("\y《技能列表》", "menu_drop2")
		menu_additem(menuid, "\w隱身 10 秒 (333 Reload)")
		menu_additem(menuid, "\w加速 10 秒 (333 Reload)")
		menu_additem(menuid, "\w無敵 10 秒 (555 Reload)")
		menu_additem(menuid, "\w超級高跳 (555 Reload)")
		menu_additem(menuid, "\w範圍內的人彈走 (888 Reload)")
		menu_setprop(menuid, MPROP_BACKNAME, "返回")
		menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
		menu_setprop(menuid, MPROP_EXITNAME, "離開")
		menu_display(id, menuid)
	}
	if (g_Player[id][Base][Boss] && !g_random)
	{
		new menuid = menu_create("\y《技能列表》", "menu_drop")
		menu_additem(menuid, "\w長跳 (333 Reload)")
		menu_additem(menuid, "\w加速 10 秒 (333 Reload)")
		menu_additem(menuid, "\w隱身 10 秒 (555 Reload)")
		menu_additem(menuid, "\w超級高跳 (555 Reload)")
		menu_additem(menuid, "\w範圍內的人彈走 (888 Reload)")
		menu_additem(menuid, "\w範圍內的人速度下降 (555 Reload)")
		if (g_difficult)
		{
			if (g_twoboss)
			{
				menu_additem(menuid, "\w範圍內的人中毒 (888 Reload)")
			}
			menu_additem(menuid, "\w範圍內的人中毒 (555 Reload)")
		}
		menu_setprop(menuid, MPROP_BACKNAME, "返回")
		menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
		menu_setprop(menuid, MPROP_EXITNAME, "離開")
		menu_display(id, menuid)
	}
	if (!g_Player[id][Base][Boss])
	{
		new buffer[6], menuid = menu_create("\y《技能列表》", "menu_drop4")
		if (g_job[id] == 1 && !skilled[id][0])
		{
			buffer[0] = 0
			menu_additem(menuid, "\w精密射擊", buffer)
		}
		if (g_job[id] == 2 && !skilled[id][1])
		{
			buffer[0] = 1
			menu_additem(menuid, "\w小刀爆發", buffer)
		}
		if (g_job[id] == 3 && !skilled[id][2])
		{
			buffer[0] = 2
			menu_additem(menuid, "\w傷害爆發", buffer)
		}
		if (g_job[id] == 4 && !skilled[id][3])
		{
			buffer[0] = 3
			menu_additem(menuid, "\w隱身", buffer)
		}
		menu_setprop(menuid, MPROP_BACKNAME, "返回")
		menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
		menu_setprop(menuid, MPROP_EXITNAME, "離開")
		menu_display(id, menuid)
	}
	return PLUGIN_HANDLED
}

public menu_drop(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new name[64]
	get_user_name(id, name, charsmax(name))
	switch (item)
	{
		case 0:
		{
			if (g_Player[id][Base][Reload] >= 333)
			{
				g_Player[id][Base][Reload] -= 333
				fm_set_user_godmode(id, 1)
				fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
				set_task(1.0, "remove_godmode", id)
				new Float:velocity[3]
				velocity_by_aim(id, 1000, velocity)
				velocity[2] = 200.0
				entity_set_vector(id, EV_VEC_velocity, velocity)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用長跳", name)
				PlaySound(0, g_hunterlj[random_num(0, 1)])
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 1:
		{
			if (g_Player[id][Base][Reload] >= 333 && !g_gboost[id])
			{
				g_gboost[id] = 1
				g_Player[id][Base][Reload] -= 333
				set_user_maxspeed(id, 420.0)
				fm_set_rendering(id, kRenderFxGlowShell, 0, 255, 0, kRenderNormal, 25)
				set_task(10.0, "remove_boost", id)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用加速", name)
				PlaySound(0, "legend/Zombie_GBoost.wav")
			}
			else
			{
				if (g_gboost[id])
				{
					set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
					show_dhudmessage(id, "技能使用中")
				}
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 2:
		{
			if (g_Player[id][Base][Reload] >= 555)
			{
				g_Player[id][Base][Reload] -= 555
				fm_set_user_godmode(id, 1)
				fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
				set_task(2.0, "remove_godmode", id)
				set_entity_visibility(id, 0)
				g_Player[id][Base][Hide] = 1
				set_task(10.0, "remove_hide", id)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用隱身", name)
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 3:
		{
			if (g_Player[id][Base][Reload] >= 555)
			{
				g_Player[id][Base][Reload] -= 555
				fm_set_user_godmode(id, 1)
				fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
				set_task(2.0, "remove_godmode", id)
				new Float:velocity[3]
				entity_get_vector(id, EV_VEC_velocity, velocity)
				velocity[2] = 5000.0
				entity_set_vector(id, EV_VEC_velocity, velocity)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用超級高跳", name)
				PlaySound(0, g_hunterlj[random_num(0, 1)])
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 4:
		{
			if (g_Player[id][Base][Reload] >= 888)
			{
				g_Player[id][Base][Reload] -= 888
				boss_skill(id, 500.0, 500, 3)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用範圍內的人彈走", name)
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 5:
		{
			if (g_Player[id][Base][Reload] >= 555)
			{
				g_Player[id][Base][Reload] -= 555
				boss_skill(id, 500.0, 500, 1)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用範圍內的人速度下降", name)
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 6:
		{
			if ((g_twoboss && g_Player[id][Base][Reload] >= 888) || (!g_twoboss && g_Player[id][Base][Reload] >= 555))
			{
				if (g_twoboss)
				{
					g_Player[id][Base][Reload] -= 888
				}
				else
				{
					g_Player[id][Base][Reload] -= 555
				}
				boss_skill(id, 500.0, 500, 2)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用範圍內的人中毒", name)
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
	}
	return PLUGIN_HANDLED
}

public round_start_pre()
{
	//Bug Fix
	set_cvar_num("sv_skycolor_r", 0)
	set_cvar_num("sv_skycolor_g", 0)
	set_cvar_num("sv_skycolor_b", 0)
	set_cvar_num("sv_maxspeed", 999)
	set_cvar_float("mp_freezetime", 0.0)
	set_cvar_float("sv_maxvelocity", 99999.0)
	set_cvar_num("mp_autoteambalance", 0)
	set_cvar_num("mp_limitteams", 0)
}

public round_start_post()
{
	remove_boss_sound_task()
	remove_task(TASK_NOTICE)
	remove_task(TASK_NIGHTVISION)
	remove_task(TASK_ANTIRESPAWN)
	remove_task(TASK_RESPAWNPLAYER)
	g_endround = 0
	g_antirespawn = 0
	g_twoboss = 0
	g_humanhide = 3
	for(new i = 1;i <= g_maxplayers;i++)
	{
		SavePlayerData(i)
		g_Player[i][Base][RespawnCount] = 0
		g_PlayerFloat[i][Damage][Rank] = 0.0
		g_Player[i][Bag][AttackGem] = false
		g_Player[i][Bag][SpeedGem] = false
		g_Player[i][Base][Reload] = 0
	}

	//防止模式出现bug，等待玩家进入游戏
	if(fnGetPlaying() < MINIMUM_PLAYER)
	{
		set_task(1.0, "check_round_status")
		g_require_to_play = true
		return PLUGIN_HANDLED
	}

	if (g_difficult == 2)
	{
		g_random = 1
		g_min = 13
		g_sec = 0
		boss_sound(random_num(3, 7))
	}
	else
	{
		g_min = 8
		g_sec = 0
		g_random = 0
		boss_sound(random_num(1, 2))
	}
	//选取魔王
	//重写

	if (fnGetAliveHumans() > 19 && g_difficult < 2 && g_mode != MODE_ESCAPE)
	{
		g_twoboss = 1
	}

	static id, iBoss, iMaxBoss
	iBoss = 0;
	iMaxBoss = g_twoboss ? 2 : 1;

	// 随机挑选幸运人类变成魔王
	while (iBoss < iMaxBoss)
	{
		id = fnGetRandomAlive(random_num(1, fnGetAlive()))
		// 如果已经是boss了
		if (g_Player[id][Base][Boss])
			continue;

		// 变成魔王
		make_boss(id)
		iBoss++
		if(iBoss >= iMaxBoss) colored_print(0, "\x04[系統]\x03 已經隨機抽取魔王。")
	}

	static iLeader, iMaxLeader;
	iLeader = 0;
	iMaxLeader = (fnGetAliveHumans() > 19 && g_difficult < 2 && g_mode != MODE_ESCAPE) ? 2 : 1;
	//Leader模式分配Leader
	if (g_mode == MODE_LEADER && !g_endround)
	{
		while(iLeader < iMaxLeader)	//人类大于19人 并且难度不为2 并且不为逃亡模式
		{
			id = fnGetRandomAlive(random_num(1, fnGetAlive()))
			// 如果是boss或者leader
			if (g_Player[id][Base][Boss] || g_Player[id][Base][Leader])
				continue;
			
			make_leader(id)
			iLeader++
		}
	}

	// 对抗模式BOSS>2人  			难度2中boss大于1人                				逃亡模式中boss大于1人        			存活人类不足20人,但魔王大于1人
	if (fnGetAliveBosses() > 2 || (fnGetAliveBosses() > 1 && g_difficult == 2) || (fnGetAliveBosses() > 1 && g_mode == MODE_ESCAPE) || (fnGetAliveHumans() < 20 && fnGetAliveBosses() > 1))
	{
		out_boss()
		colored_print(0, "\x04[系統]\x03 已經調走一位魔王。")
	}
	
	for(id = 1;id <= g_maxplayers;id++)
	{
		if(g_Player[id][Base][Boss] || g_Player[id][Base][Leader] || !is_user_alive(id))
			continue;
		
		make_human(id)
	}

	set_task(30.0, "AntiSpawn", TASK_ANTIRESPAWN)
	set_task(60.0, "Notice", TASK_NOTICE, _, _, "b")
	g_startround = 1
	return PLUGIN_CONTINUE
}

public make_leader(id)
{
	new name[64]
	get_user_name(id, name, charsmax(name))
	colored_print(0, "\x04[系統]\x03 %s 成為本局的 Leader", name)
	make_human(id)
	g_Player[id][Base][Leader] = 1
	cs_set_player_model(id, leader_model)
}

public check_round_status()
{
	if(fnGetPlaying() >= MINIMUM_PLAYER && g_require_to_play || (!fnGetAliveBosses() && g_startround && !g_endround))
	{
		TerminateRound(RoundEndType_Draw, TeamWinning_None)
		g_require_to_play = false
		return PLUGIN_CONTINUE
	}
	if(fnGetPlaying() < MINIMUM_PLAYER)
	{
		g_require_to_play = true
		g_startround = 0
		g_endround = 1
		g_min = 0
		g_sec = 0
		client_print(0, print_center, "等待玩家进入游戏...")
		set_task(1.0, "check_round_status")
	}
	return PLUGIN_CONTINUE
}

public reload(taskid)
{
	new id = taskid - TASK_RELOAD
	if((g_endround && !g_startround) || (!g_min && !g_sec))
	{
		remove_task(taskid)
	}
	else
	{
		if(!is_user_alive(id) || !g_Player[id][Base][Boss])
		{
			entity_set_string(id, EV_SZ_viewmodel, "")
			remove_task(taskid)
		}
		if (g_Player[id][Base][Reload] < 888)
		{
			if (g_mode == MODE_ESCAPE) g_Player[id][Base][Reload] += 2
			else g_Player[id][Base][Reload]++
			client_print(id, print_center, "RELOAD 中 (%d/888)", g_Player[id][Base][Reload])
		}
		else
		{
			if (g_Player[id][Base][Reload] >= 888) client_print(id, print_center, "RELOAD 完成")
		}
	}
}

public Player_Spawn_Post(id)
{
	if(!g_respawning && g_startround && fm_cs_get_user_team(id) == FM_CS_TEAM_T)
	{
		make_human(id)
		return HAM_IGNORED
	}
	if (!is_user_alive(id)) return HAM_IGNORED
	if (((g_antirespawn && !g_Player[id][Base][RespawnCount]) || (g_antirespawn && g_Player[id][Base][RespawnCount] > 1)) && g_startround) user_silentkill(id)

	remove_task(id + TASK_VIRUS)
	remove_task(id + TASK_RELOAD)
	remove_task(id + TASK_NIGHTVISION)
	
	fm_strip_user_weapons(id)
	fm_give_item(id, "weapon_knife")
	cs_reset_player_model(id)
	fm_set_rendering(id, kRenderFxNone, 255, 255, 255, kRenderNormal, 16)
	fm_set_user_godmode(id, 0)
	set_user_gnvision(id, 0)
	lighting_effects()

	g_setspeed[id] = 0
	g_Player[id][Base][Virus] = 0
	timer[id] = 0
	g_nvision[id] = 0
	g_nvisionenabled[id] = 0
	g_Player[id][Base][Combo][0] = 0
	g_Player[id][Base][Combo][1] = 5
	g_PlayerFloat[id][Damage][ItemDrop] = 0.0
	g_PlayerFloat[id][Damage][Skin] = 0.0
	g_PlayerFloat[id][Damage][Skill] = 0.0
	g_Player[id][Bag][UseLimit] = ITEM_CAN_USE_TIMES
	g_gboost[id] = 0
	g_Player[id][Base][Hide] = 0

	g_PlayerFloat[id][Damage][Task][1] = 0.0
	g_Player[id][Bag][SPCard] = false
	g_Player[id][Bag][PowerCard] = false
	g_critical_knife[id] = 0
	g_headshoot[id] = 0
	g_headshot[id] = 0
	limit_addhp[id] = 0
	g_keyconfig[id] = 0

	g_Player[id][Base][Leader] = 0
	g_Player[id][Base][Boss] = 0
	g_SelectedPri[id] = 0
	g_SelectedSec[id] = 0
	g_SelectedMelee[id] = 0
	g_SelectedSkins[id] = 0

	//重置人类技能
	for (new i;i < 4;i++)
	{
		skilled[id][i] = 0
	}

	for (new i;i < sizeof g_skinlist;i++)
	{
		if (g_skin_info[id][i][SKIN_EQUIPED] && g_skin_info[id][i][SKIN_HAVE])
		{
			change_skin(id, i)
			break
		}
	}

	if (g_Player[id][Base][RespawnCount] == 1)
	{
		g_Player[id][Base][RespawnCount]++
	}
	if(g_respawning) g_respawning = 0;
	hide_timer(id)

	return HAM_IGNORED
}

public AntiSpawn()
{
	g_antirespawn = 1
}

public Notice()
{
	switch (random_num(1, 14))
	{
		case 1:
		{
			colored_print(0, "\x04[提示]\x03 大部份槍械都可以升級，每 1 等級增加 1 攻擊力")
		}
		case 2:
		{
			colored_print(0, "\x04[提示]\x03 Combo 會隨着玩家等級而增加更多 EXP")
		}
		case 3:
		{
			colored_print(0, "\x04[提示]\x03 輸入 /msg 或 /fun_name 再加上文字，設置你心愛的獨特稱號。")
		}
		case 4:
		{
			colored_print(0, "\x04[提示]\x03 輸入 /lag 開啟客戶端優化選單")
		}
		case 5:
		{
			colored_print(0, "\x04[提示]\x03 RC 26590440")
		}
		case 6:
		{
			colored_print(0, "\x04[提示]\x03 論壇 legendserver.org")
		}
		case 7:
		{
			colored_print(0, "\x04[提示]\x03 如發現犯規情況，不要犹豫請立即上論壇 legendserver.org 舉佈。")
		}
		case 8:
		{
			colored_print(0, "\x04[提示]\x03 想更換地圖？？輸入 rtv 投票更換。")
		}
		case 9:
		{
			colored_print(0, "\x04[IP]\x03 legendserver.org:27015")
		}
		case 10:
		{
			colored_print(0, "\x04[提示]\x03 本服有完善的規則，犯規後果嚴重，切記不要一時衝動導致後悔莫及。")
			colored_print(0, "\x04[提示]\x03 建議大家上論壇 legendserver.org 查看所有伺服器規則及事項 (修正版)。")
		}
	}
}

public logevent_round_end()
{
	g_startround = 0
	g_antirespawn = 0
	
	for(new id = 1;id <= g_maxplayers;id++)
	{
		if(fm_cs_get_user_team(id) != FM_CS_TEAM_SPECTATOR && fm_cs_get_user_team(id) != FM_CS_TEAM_UNASSIGNED)
		{
			if (is_user_alive(id))
			{
				task_doing(id, 3, 1, 1, 0.0)
				task_doing(id, 15, 1, 1, 0.0)
				if (fnGetAliveHumans() == 1 && !g_Player[id][Base][Boss])
				{
					task_doing(id, 19, 1, 1, 0.0)
				}
				if (g_mode == MODE_ESCAPE && fnGetAliveHumans() > 14 && !g_Player[id][Base][Boss])
				{
					task_doing(id, 17, 1, 1, 0.0)
				}
				if (g_mode == MODE_ESCAPE && g_difficult == 2 && !g_Player[id][Base][Boss])
				{
					task_doing(id, 7, 1, 1, 0.0)
				}
				if (fnGetAliveHumans() > 0 && fnGetAliveHumans() < 4 && !g_Player[id][Base][Boss])
				{
					task_doing(id, 8, 1, 1, 0.0)
				}
				if (g_Player[id][Base][Boss] && g_random == 1)
				{
					task_doing(id, 9, 1, 1, 0.0)
				}
				if (g_mode == MODE_ESCAPE && !g_Player[id][Base][Boss] && get_user_health(id) < 11)
				{
					task_doing(id, 11, 1, 1, 0.0)
				}
				if (!g_Player[id][Base][Boss] && fnGetAliveHumans() == 2)
				{
					task_doing(id, 13, 1, 1, 0.0)
				}
				if (g_Player[id][Base][Boss] && get_user_health(id) >= g_checkhealth[id] && g_mode != MODE_ESCAPE)
				{
					task_doing(id, 18, 1, 1, 0.0)
				}
			}
			if (g_Player[id][Base][Boss] && g_mode != MODE_ESCAPE && g_twoboss)
			{
				task_doing(id, 6, 1, 1, 0.0)
			}
			if (g_PlayerFloat[id][Damage][Rank] >= 150000.0)
			{
				task_doing(id, 10, 1, 1, 0.0)
			}
			else
			{
				for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
				{
					if (g_tasklist[g_doing1[id][task_id]][TASK_CLASS] == 10)
					{
						g_doing2[id][task_id] = 0
						g_doing3[id][task_id] = g_tasklist[g_doing1[id][task_id]][TASK_DOING3NUM]
					}
				}
			}
			if (g_PlayerFloat[id][Damage][Task][1] >= 70000.0)
			{
				task_doing(id, 14, 1, 1, 0.0)
			}
			if (g_Player[id][Base][Combo] >= 20)
			{
				task_doing(id, 16, 1, 1, 0.0)
			}
		}
	}
	if (random_num(0, 7) == 7 && g_random)
	{
		g_mode = MODE_ESCAPE
	}
	else if (random_num(0, 5) == 5)
	{
		g_mode = MODE_LEADER
	}
	else
	{
		g_mode = MODE_NORMAL
	}
	g_endround = 1
	
	return PLUGIN_HANDLED
}

StopSound(id)
{
	client_cmd(id, "mp3 stop; stopsound")
}

public make_boss(id)
{
	new add_hp, map_name[32]
	fm_cs_set_user_team(id, FM_CS_TEAM_T)
	g_respawning = 1
	ExecuteHamB(Ham_CS_RoundRespawn, id)
	ExecuteForward(g_fwWeaponRemove, g_fwResult, id)
	set_user_footsteps(id, 0)

	g_Player[id][Base][Boss] = 1
	g_Player[id][Base][Reload] = 0
	colored_print(id, "\x04[系統]\x03 魔王快點姦殺所有人類吧。")
	if (g_mode == MODE_ESCAPE && g_random == 2)
	{
		fm_set_user_health(id, 99999999)
	}
	else
	{
		if (g_mode == MODE_ESCAPE && g_random == 1)
		{
			fm_set_user_health(id, 100000)
		}
		if (fnGetAliveHumans() > 19 && g_difficult < 2 && g_mode != MODE_ESCAPE)
		{
			get_mapname(map_name, 32)
			if (equali(map_name, "boss_", strlen("boss_")))
			{
				add_hp = get_playersnum(0) * 34000
			}
			if (g_Player[id][Base][Level] > 250)
			{
				fm_set_user_health(id, add_hp + get_playersnum(0) * 80000 / 2)
			}
			else
			{
				fm_set_user_health(id, add_hp + 250 - g_Player[id][Base][Level] * 4000 + get_playersnum(0) * 80000 / 2)
			}
			if (g_Player[id][Base][Level] > 250)
			{
				g_checkhealth[id] = add_hp + get_playersnum(0) * 80000 / 2 / 2
			}
			else
			{
				g_checkhealth[id] = add_hp + 250 - g_Player[id][Base][Level] * 4000 + get_playersnum(0) * 80000 / 2 / 2;
			}
		}
		if (g_mode != MODE_ESCAPE)
		{
			new add_hp, map_name[32]
			get_mapname(map_name, 32)
			if (equali(map_name, "boss_", strlen("boss_")))
			{
				add_hp = get_playersnum(0) * 68000;
			}
			if (g_Player[id][Base][Level] > 250)
			{
				fm_set_user_health(id, get_playersnum(0) * 80000);
			}
			else
			{
				fm_set_user_health(id, 250 - g_Player[id][Base][Level] * 4000 + get_playersnum(0) * 80000);
			}
			if (g_Player[id][Base][Level] > 250)
			{
				g_checkhealth[id] = add_hp + get_playersnum(0) * 80000 / 2;
			}
			else
			{
				g_checkhealth[id] = add_hp + 250 - g_Player[id][Base][Level] * 4000 + get_playersnum(0) * 80000 / 2;
			}
		}
	}

	replace_weapon_models(id)
	set_dhudmessage(255, 20, 20, -1.0, 0.17, 1, 0.0, 5.0, 1.0, 1.0)
	show_dhudmessage(id, "你是魔王，按 G 使用技能")
	set_task(0.1, "reload", id + TASK_RELOAD, _, _, "b")
	cs_set_player_model(id, boss_model[g_random])
	g_nvision[id] = 1
	g_nvisionenabled[id] = 1

	message_begin(MSG_ONE_UNRELIABLE, SVC_LIGHTSTYLE, _, id)
	write_byte(0)
	write_string("Z")
	message_end()
	remove_task(id + TASK_NIGHTVISION)

	set_task(0.1, "set_user_nvision", id + TASK_NIGHTVISION)
	ExecuteForward(g_fwUserToBoss, g_fwResult, id)
}

public make_human(id)
{
	fm_cs_set_user_team(id, FM_CS_TEAM_CT)
	g_respawning = 1
	ExecuteHamB(Ham_CS_RoundRespawn, id)
	ExecuteForward(g_fwWeaponRemove, g_fwResult, id)
	if(job_skill[id][4]) set_user_footsteps(id, 1)
	colored_print(id, "\x04[系統]\x03 人類用你身上的槍射死魔王。");
	g_Player[id][Base][Boss] = 0
	show_menu_choose(id)
	if (g_mode != MODE_ESCAPE)
	{
		if (g_Player[id][Base][Level] < 500 || max_hp[id] > 50)
		{
			fm_set_user_health(id, max_hp[id] + floatround(entity_get_float(id, EV_FL_health)))
		}
		fm_set_user_health(id, floatround(entity_get_float(id, EV_FL_health)) + 50)
		colored_print(id, "\x04[系統]\x03 500等級以下新手血量增加 50。")
	}
	new hp = get_user_health(id)
	if (hp == 200) g_Player[id][Base][Status] = 0
	else
	{
		if (hp > 149) g_Player[id][Base][Status] = 1
		else if (hp > 99) g_Player[id][Base][Status] = 2
		else if (hp > 49) g_Player[id][Base][Status] = 3
		else if (hp > 10) g_Player[id][Base][Status] = 4
		else g_Player[id][Base][Status] = 5
	}
	ExecuteForward(g_fwUserToHuman, g_fwResult, id)
}

public out_boss()
{
	while(fnGetAliveBosses() > 1)
	{
		new id = fnGetRandomAlive(random_num(1, fnGetAlive()))
		if(fm_cs_get_user_team(id) == FM_CS_TEAM_CT)
			continue;

		make_human(id)
	}
}

public show_level_hud(taskid)
{
	new id = taskid - TASK_SHOWHUD
	new target = entity_get_int(id, EV_INT_iuser2)
	new InfoMsg[2048]
	if (is_user_alive(id))
	{
		if (get_weapon_type(g_Player[id][Base][Weapon]))
		{
			format(InfoMsg, charsmax(InfoMsg), "HP: %d | SP: %d | Gash: %d | Combo: %d^nLevel: %d | Exp: %d/%d | 能力點數 :%d", get_user_health(id), 
			g_Player[id][Base][SP], g_Player[id][Base][Gash], g_Player[id][Base][Combo], g_Player[id][Base][Level], g_Player[id][Base][XP], g_Player[id][Base][Level] * g_Player[id][Base][Level] * MAX_EXP_MUL, g_skpoint[id])
			format(InfoMsg, charsmax(InfoMsg), "%s^n%s Level: %d | %s Exp: %d/%d^n造成傷害: %f | 狀態: %s | 兌換券: %d", InfoMsg, WEAPONNAMES_SIMPLE[g_Player[id][Base][Weapon]], g_Player[id][Base][GunLevel][g_Player[id][Base][Weapon]], 
			WEAPONNAMES_SIMPLE[g_Player[id][Base][Weapon]], g_Player[id][Base][GunXP][g_Player[id][Base][Weapon]], g_Player[id][Base][GunLevel][g_Player[id][Base][Weapon]] * MAX_WEP_EXP_MUL, g_PlayerFloat[id][Damage][Rank], g_statusname[g_Player[id][Base][Status]], g_Player[id][Base][Coupon])
			set_hudmessage(0, 255, 0, 0.6, 0.75, 0, 6.0, 0.6, 0.0, 0.0, -1)
			ShowSyncHudMsg(id, g_MsgSync, InfoMsg)
		}
		else
		{
			format(InfoMsg, charsmax(InfoMsg), "HP: %d | SP: %d | Gash: %d | Combo: %d^nLevel: %d | Exp: %d/%d | 能力點數 :%d^n造成傷害: %f | 狀態: %s | 兌換券: %d", get_user_health(id), g_Player[id][Base][SP], g_Player[id][Base][Gash], g_Player[id][Base][Combo], g_Player[id][Base][Level], g_Player[id][Base][XP], g_Player[id][Base][Level] * g_Player[id][Base][Level] * MAX_EXP_MUL, g_skpoint[id], 
			g_PlayerFloat[id][Damage][Rank], g_statusname[g_Player[id][Base][Status]], g_Player[id][Base][Coupon])
			set_hudmessage(0, 255, 0, 0.6, 0.75, 0, 6.0, 0.6, 0.0, 0.0, -1)
			ShowSyncHudMsg(id, g_MsgSync, InfoMsg)
		}
	}
	else
	{
		if (is_user_alive(target))
		{
			format(InfoMsg, charsmax(InfoMsg), "HP: %d | SP: %d | Gash: %d | Level: %d^nExp: %d/%d | 能力點數 :%d^n造成傷害: %f | 兌換券: %d", get_user_health(target), g_Player[target][Base][SP], g_Player[target][Base][Gash], g_Player[target][Base][Level], g_Player[target][Base][XP], g_Player[target][Base][Level] * g_Player[target][Base][Level] * MAX_EXP_MUL, g_skpoint[target], g_PlayerFloat[target][Damage][Rank], g_Player[target][Base][Coupon])
			set_hudmessage(200, 250, 0, 0.75, 0.81, 0, 6.0, 0.6, 0.0, 0.0, -1)
			ShowSyncHudMsg(id, g_MsgSync, InfoMsg)
		}
	}
	return PLUGIN_CONTINUE
}

public ShowHud()
{
	set_hudmessage(255, 255, 255, -1.0, 0.0, 0, 0.0, 1.2, 2.0, 1.0, -1);
	ShowSyncHudMsg(0, g_MsgSync4, "模式: %s | 難度: %d/2 | 時間: %d 分鐘 %d 秒", g_modename[g_mode], g_difficult, g_min, g_sec)
	new Float:Top1, Float:Top2, Float:Top3, Top1Name[64], Top2Name[64], Top3Name[64], Top1User, Top2User, Top3User
	
	for(new i = 1;i <= g_maxplayers;i++)
	{
		if (g_PlayerFloat[i][Damage][Rank] > Top1)
		{
			Top1 = g_PlayerFloat[i][Damage][Rank]
			get_user_name(i, Top1Name, charsmax(Top1Name))
			Top1User = 1
		}
	}
	for(new i = 1;i <= g_maxplayers;i++)
	{
		if (g_PlayerFloat[i][Damage][Rank] > Top2 && g_PlayerFloat[i][Damage][Rank] < Top1)
		{
			Top2 = g_PlayerFloat[i][Damage][Rank]
			get_user_name(i, Top2Name, charsmax(Top2Name))
			Top2User = 1
		}
	}
	for(new i = 1;i <= g_maxplayers;i++)
	{
		if (g_PlayerFloat[i][Damage][Rank] > Top3 && g_PlayerFloat[i][Damage][Rank] < Top1 && g_PlayerFloat[i][Damage][Rank] < Top2)
		{
			Top3 = g_PlayerFloat[i][Damage][Rank]
			get_user_name(i, Top3Name, charsmax(Top3Name))
			Top3User = 1
		}
	}
	if (!Top1User)
	{
		formatex(Top1Name, charsmax(Top1Name), "未知")
	}
	if (!Top2User)
	{
		formatex(Top2Name, charsmax(Top2Name), "未知")
	}
	if (!Top3User)
	{
		formatex(Top3Name, charsmax(Top3Name), "未知")
	}
	set_hudmessage(255, 255, 255, 0.85, 0.4, 0, 6.0, 0.6, 0.0, 0.0, -1)
	ShowSyncHudMsg(0, g_MsgSync5, "傷害排名:^n第一名: %s^n傷害: %f^n第二名: %s^n傷害: %f^n第三名: %s^n傷害: %f", Top1Name, Top1, Top2Name, Top2, Top3Name, Top3)
}

public Time()
{
	if(g_require_to_play)
		return PLUGIN_HANDLED
	if (!g_min && !g_sec && !g_endround && g_startround)
	{
		//统计Leader人数
		new leader;
		for(new i = 1;i <= g_maxplayers;i++)
		{
			if (g_Player[i][Base][Leader]) leader++
		}
		
		//时间到，删除魔王Reload
		for(new i = 1;i <= g_maxplayers;i++)
		{
			g_Player[i][Base][Reload] = 0
			remove_task(i + TASK_RELOAD, 0)
		}

		if (g_mode == MODE_ESCAPE) //逃亡模式
		{
			for(new i = 1;i <= g_maxplayers;i++)
			{
				if (fm_cs_get_user_team(i) == FM_CS_TEAM_CT && is_user_alive(i))
				{
					if (g_difficult < 2)
					{
						g_Player[i][Base][SP] += 50
					}
					else g_Player[i][Base][SP] += 100
				}
			}
			if (g_difficult < 2)
			{
				colored_print(0, "\x03[獎勵] 生存的人類獲得完場勝利，獲得 50 的 SP")
			}
			else colored_print(0, "\x03[獎勵] 生存的人類獲得完場勝利，獲得 100 的 SP")
		}

		if (leader && g_mode == MODE_LEADER) //Leader模式
		{
			for(new i = 1;i <= g_maxplayers;i++)
			{
				if (fm_cs_get_user_team(i) == FM_CS_TEAM_CT && is_user_alive(i))
				{
					if (g_difficult < 2) g_Player[i][Base][SP] += 50
					else g_Player[i][Base][SP] += 100
				}
				if (g_Player[i][Base][Leader] && is_user_alive(i))
				{
					task_doing(i, 5, 1, 1, 0.0)
				}
			}
			if (g_difficult < 2)
			{
				colored_print(0, "\x03[獎勵] Leader 成功生存，生存的人類獲得 50 的 SP");
			}
			else colored_print(0, "\x03[獎勵] Leader 成功生存，生存的人類獲得 100 的 SP");
		}

		if (!leader && g_mode == MODE_LEADER) //Leader模式下Leader死亡
		{
			for(new i = 1;i <= g_maxplayers;i++)
			{
				if (fm_cs_get_user_team(i) == FM_CS_TEAM_CT)
				{
					user_silentkill(i)
				}
			}
		}
		
		if ((leader && g_mode == MODE_LEADER) || (g_mode && g_mode == MODE_ESCAPE)) //Leader模式下Leader存活 / 逃亡模式成功生存
		{
			for(new i = 1;i <= g_maxplayers;i++)
			{
				if (g_Player[i][Base][Boss])
				{
					user_silentkill(i) //处死魔王
				}
			}
		}
		if(g_startround && !g_endround) TerminateRound(RoundEndType_TeamExtermination, TeamWinning_Terrorist) //对抗模式时间结束，魔王获胜
		g_endround = 1
		return PLUGIN_HANDLED
	}
	
	if (!g_endround && g_startround)
	{
		if (g_sec)
		{
			g_sec -= 1
			return PLUGIN_HANDLED
		}
		g_min -= 1
		g_sec = 59
	}
	return PLUGIN_HANDLED
}

public fw_Item_Deploy_Post(weapon_ent)
{
	static owner, weaponid;
	owner = fm_cs_get_weapon_ent_owner(weapon_ent)
	weaponid = cs_get_weapon_id(weapon_ent);
	g_Player[owner][Base][Weapon] = weaponid
}

fm_cs_get_weapon_ent_owner(ent)
{
	return get_pdata_cbase(ent, 41, 4)
}

public client_putinserver(id)
{
	/*
	new ip[16], name[64];
	get_user_ip(id, ip, charsmax(ip), 1)
	get_user_name(id, name, charsmax(name))
	if (equal(name, "kdghrh", 0))
	{
		if (!equal(ip, "14.198.190.241", 0))
		{
			new logdata[100];
			formatex(logdata, charsmax(logdata), "IP: %s", ip);
			log_to_file("client.log", logdata);
			server_cmd("kick kdghrh")
		}
	}
	*/
	if (exp_x2[id])
	{
		if (!task_exists(id + TASK_EXPX2))
		{
			set_task(1.0, "limit_item", id + TASK_EXPX2, _, _, "b")
		}
	}

	Reset_PlayerVars(id)
	set_task(0.5, "show_level_hud", id + TASK_SHOWHUD, _, _, "b")
}

public client_disconnect(id)
{
	SavePlayerData(id)
	Reset_PlayerVars(id)

	remove_task(id + TASK_VIRUS)
	remove_task(id + TASK_SHOWHUD)
	remove_task(id + TASK_NIGHTVISION)
	remove_task(id + TASK_RELOAD)
	remove_task(id + TASK_EXPX2)
	
	for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
	{
		if (g_tasklist[g_doing1[id][task_id]][TASK_CLASS] == 10)
		{
			g_doing2[id][task_id] = 0
			g_doing3[id][task_id] = g_tasklist[g_doing1[id][task_id]][TASK_DOING3NUM]
		}
	}
	
	set_task(1.0, "check_round_status")	//检查对局状态
}

public Reset_PlayerVars(id)
{
	for(new i;i < 5;i++)
	{
		ShopItem[id][i] = 0
		ShopCost[id][i] = 0
		ShopType[id][i] = 0
		ShopNum[id][i] = 0
	}
	Gave_Sp[id] = 0;
	Check_Key[id] = 0;
	Check_Shop_No[id] = 0;
	Check_Shop_Line[id] = 0;
	Check_Admin_Shop_No[id] = 0;
	AdminShop[id] = 0;

	for(new skin;skin < sizeof g_skinlist;skin++)
	{
		g_skin_info[id][skin][SKIN_HAVE] = 0
	}
	
	//背包系统
	for(new bag_item;bag_item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];bag_item++)
	{
		g_Player[id][Bag][Index][bag_item] = 0
		g_Player[id][Bag][Amount][bag_item] = 0
	}

	//任务系统
	for (new task_id;task_id < TASKS_NUM;task_id++)
	{
		g_task_done[id][task_id] = 0
	}
	for(new doing;doing < MAX_TAKE_TASK_NUM;doing++)
	{
		g_doing1[id][doing] = 0
		g_doing2[id][doing] = 0
		g_doing3[id][doing] = 0
	}

	for (new wpnid;wpnid < 31;wpnid++)
	{
		g_Player[id][Base][GunLevel][wpnid] = 0
		g_Player[id][Base][GunXP][wpnid] = 0
	}

	g_setspeed[id] = 0
	g_Player[id][Base][Virus] = 0
	timer[id] = 0
	g_Player[id][Base][Leader] = 0
	g_Player[id][Base][Boss] = 0
	g_Player[id][Base][Reload] = 0
	g_Player[id][Base][Level] = 0
	g_Player[id][Base][XP] = 0
	g_Player[id][Base][SP] = 0
	g_Player[id][Base][Gash] = 0
	exp_x2[id] = 0
	exp_x2_time[id] = 0
	//技能系统
	g_skpoint[id] = 0
	g_job[id] = 0
	max_hp[id] = 0
	max_speed[id] = 0
	max_damage[id] = 0
	max_jump[id] = 0
	g_Player[id][Bag][AttackGem] = false
	g_Player[id][Bag][SpeedGem] = false
	g_Player[id][Base][DataLoaded] = false

	Reset_WeaponBuy(id)
	ExecuteForward(g_fwWeaponRemove, g_fwResult, id)
	
	//TODO:交易系统
	/*
	if (g_exchangeing[id])
	{
		new main;
		new target;
		new realid;
		main = MainId[id];
		target = TargetId[id];
		if (id == main)
		{
			realid = target;
		}
		else
		{
			if (id == target)
			{
				realid = main;
			}
		}
		g_ready[main] = 0;
		g_exchangeing[main] = 0;
		g_exchangeSp[main] = 0;
		g_ready[target] = 0;
		g_exchangeing[target] = 0;
		g_exchangeSp[target] = 0;
		while (new host;host < 5;host++)
		{
			g_exchange[main][host] = 0
			g_exchangeNum[main][host] = 0
			g_exchangeType[main][host] = 0
			g_exchangeWpn[main][host] = 0
			g_exchangeModel[main][host] = 0
			g_exchangeKnife[main][host] = 0
			g_exchange[target][host] = 0
			g_exchangeNum[target][host] = 0
			g_exchangeType[target][host] = 0
			g_exchangeWpn[target][host] = 0
			g_exchangeModel[target][host] = 0
			g_exchangeKnife[target][host] = 0
		}
		colored_print(realid, "\x04[交易]\x03 交易失敗，對方已經下線")
		show_menu(realid, 0, 378924, 1, 327292)
	}
	log_to_file(g_logfile, "名稱: %s Gash: %d (Disconnect Gash)", name, g_Player[id][Base][Gash]);
	*/
}

task_doing(id, Class, doing2, doing3, Float:taskdamage)
{
	for(new task_id;task_id < MAX_TAKE_TASK_NUM;task_id++)
	{
		if (Class == g_tasklist[g_doing1[id][task_id]][TASK_CLASS])
		{
			if (g_doing3[id][task_id] < 1)
			{
				task_complete(id, g_doing1[id][task_id])
				return PLUGIN_HANDLED
			}
			if (g_doing3[id][task_id] > 0)
			{
				g_doing2[id][task_id] += doing2
				g_doing3[id][task_id] -= doing3
				if (Class == 26 || Class == 4 || Class == 20)
				{
					colored_print(id, "\x04[%s]\x03 已擊殺 %d 隻人類，還剩餘 %d 隻人類", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
				if (Class == 27 || Class == 1 || Class == 28)
				{
					g_doing3[id][task_id] -= floatround(taskdamage)
					g_doing2[id][task_id] += floatround(taskdamage)
					if (g_doing3[id][task_id] > 0)
					{
						colored_print(id, "\x04[%s]\x03 已集成 %d 傷害，還剩餘 %d 傷害", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
					}
				}
				if (Class == 2)
				{
					colored_print(id, "\x04[%s]\x03 已成功收集魔王之鱗 %d 個，還剩餘 %d 個", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
				if (Class == 3 || Class == 5 || Class == 7 || Class == 8 || Class == 11 || Class == 13 || Class == 17 || Class == 19)
				{
					colored_print(id, "\x04[%s]\x03 已成功生存 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
				if (Class == 6)
				{
					colored_print(id, "\x04[%s]\x03 已成功與搭檔清場 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
				if (Class == 9)
				{
					colored_print(id, "\x04[%s]\x03 已成功於 2/2 變魔龍前清場 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
				if (Class == 10)
				{
					colored_print(id, "\x04[%s]\x03 已成功連續 2 回合内造成 150000 傷害 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
				if (Class == 12)
				{
					colored_print(id, "\x04[%s]\x03 已成功收集Leader 血液 %d 支，還剩餘 %d 支", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
				if (Class == 14)
				{
					colored_print(id, "\x04[%s]\x03 已成功 1 個回合内以手槍造成 70000 傷害 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
				if (Class == 15)
				{
					colored_print(id, "\x04[%s]\x03 已成功勝利 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
				if (Class == 16)
				{
					colored_print(id, "\x04[%s]\x03 已成功 Combo 20 或以上 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
				if (Class == 18)
				{
					colored_print(id, "\x04[%s]\x03 已成功血量保持 50% 或以上並勝利 %d 次，還剩餘 %d 次", g_tasklist[g_doing1[id][task_id]][TASK_NAME], g_doing2[id][task_id], g_doing3[id][task_id])
				}
			}
			if (g_doing3[id][task_id] < 1)
			{
				task_complete(id, g_doing1[id][task_id])
			}
		}
	}
	return PLUGIN_HANDLED
}

task_complete(id, task)
{
	new name[64]
	get_user_name(id, name, charsmax(name))
	if (g_tasklist[task][TASK_CLASS] != 26 && g_tasklist[task][TASK_CLASS] != 27 && g_tasklist[task][TASK_CLASS] != 28)
	{
		if (!g_task_done[id][task] && !g_tasklist[task][TASK_REPEAT])
		{
			g_task_done[id][task] = 1
		}
	}
	colored_print(id, "\x04[任務]\x03 已完成任務 %s，獲得 %s", g_tasklist[task][TASK_NAME], g_tasklist[task][TASK_HELP2])
	log_to_file(g_logfile, "名稱: %s 任務: %s (Completed Task)", name, g_tasklist[task][TASK_NAME])
	g_Player[id][Base][XP] += g_tasklist[task][TASK_XP]
	g_Player[id][Base][SP] += g_tasklist[task][TASK_SP]
	for(new task_complete;task_complete < MAX_TAKE_TASK_NUM;task_complete++)
	{
		if (task == g_doing1[id][task_complete])
		{
			g_doing1[id][task_complete] = 0;
			g_doing2[id][task_complete] = 0;
			g_doing3[id][task_complete] = 0;
			if (g_tasklist[task][TASK_CLASS] == 1)
			{
				add_exchange_item(id, 18, 10);
			}
			if (g_tasklist[task][TASK_CLASS] == 21)
			{
				add_exchange_item(id, 6, 1);
			}
			if (g_tasklist[task][TASK_CLASS] == 22)
			{
				add_exchange_item(id, 8, 1);
			}
			if (g_tasklist[task][TASK_CLASS] == 23)
			{
				add_exchange_item(id, 9, 1);
			}
			if (g_tasklist[task][TASK_CLASS] == 24)
			{
				add_exchange_item(id, 10, 1);
			}
			if (g_tasklist[task][TASK_CLASS] == 25)
			{
				add_exchange_item(id, 11, 1);
			}
			return PLUGIN_CONTINUE
		}
	}
	if (g_tasklist[task][TASK_CLASS] == 1)
	{
		add_exchange_item(id, 18, 10);
	}
	if (g_tasklist[task][TASK_CLASS] == 21)
	{
		add_exchange_item(id, 6, 1);
	}
	if (g_tasklist[task][TASK_CLASS] == 22)
	{
		add_exchange_item(id, 8, 1);
	}
	if (g_tasklist[task][TASK_CLASS] == 23)
	{
		add_exchange_item(id, 9, 1);
	}
	if (g_tasklist[task][TASK_CLASS] == 24)
	{
		add_exchange_item(id, 10, 1);
	}
	if (g_tasklist[task][TASK_CLASS] == 25)
	{
		add_exchange_item(id, 11, 1);
	}
	return PLUGIN_CONTINUE
}

PlaySound(id, sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play sound/%s", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

//获取任务是否已经完成
bool:get_user_task(id, task)
{
	if(g_task_done[id][task]) return true
	return false
}

stock get_weapon_type(weapon_id)
{
	switch (weapon_id)
	{
		case 1, 10, 11, 16, 17, 26: return WEP_TYPE_PISTOL
		case 4, 6, 9, 25, 29, 31, 32: return WEP_TYPE_OTHERS
		case 5, 21: return WEP_TYPE_SHOTGUN
		case 7, 12, 19, 23, 30: return WEP_TYPE_SMG
		default: return WEP_TYPE_RIFLE
	}
	return 1
}

/*
public show_menu_exchange(id)
{
	new main, target;
	main = MainId[id];
	target = TargetId[id];
	if (g_ready[main] == 2 || g_ready[target] == 2 || g_ready[main] == 3 || g_ready[target] == 3 || get_user_status(main) == 6 || get_user_status(target) == 6)
	{
		g_ready[id] = 0
		//show_menu(id, 0, 333464, 1, 327292);
		return PLUGIN_CONTINUE
	}
	new message[32], message2[32], message3[255], message4[255];

	formatex(message, charsmax(message), "%s", !g_ready[main] ? "未確定" : (g_ready[main] == 1 ? "已確定" : "已取消"))
	formatex(message2, charsmax(message2), "%s", !g_ready[target] ? "未確定" : (g_ready[target] == 1 ? "已確定" : "已取消"))

	new menuid, menu[1000], buffer[32];
	formatex(menu, charsmax(menu), "\y%s \w: \y%s\n\w%d \ySP \w: %d \ySP", MainName[id], TargetName[id], g_exchangeSp[main], g_exchangeSp[target]);
	menuid = menu_create(menu, "menu_exchange")
	
	for (new host;host < 5;host++)
	{
		if (!g_exchangeType[main][host]) formatex(message3, charsmax(message3), "\w請加入項目")
		if (g_exchangeType[main][host] == 1) formatex(message3, charsmax(message3), "\w%s \r[%d/5]", g_itemname[g_exchange[main][host]], g_exchangeNum[main][host])
		if (g_exchangeType[main][host] == 2) formatex(message3, charsmax(message3), "\w%s \r[1/1]", g_wpnname[g_exchangeWpn[main][host]])
		if (g_exchangeType[main][host] == 3) formatex(message3, charsmax(message3), "\w%s \r[1/1]", g_modelname[g_exchangeModel[main][host]])
		if (g_exchangeType[main][host] == 4) formatex(message3, charsmax(message3), "\w%s \r[1/1]", g_knifename[g_exchangeKnife[main][host]])

		if (!g_exchangeType[target][host]) formatex(message4, charsmax(message4), "\w請加入項目")
		if (g_exchangeType[target][host] == 1) formatex(message4, charsmax(message4), "\w%s \r[%d/5]", g_itemname[g_exchange[target][host]], g_exchangeNum[target][host])
		if (g_exchangeType[target][host] == 2) formatex(message4, charsmax(message4), "\w%s \r[1/1]", g_wpnname[g_exchangeWpn[target][host]])
		if (g_exchangeType[target][host] == 3) formatex(message4, charsmax(message4), "\w%s \r[1/1]", g_modelname[g_exchangeModel[target][host]])
		if (g_exchangeType[target][host] == 4) formatex(message4, charsmax(message4), "\w%s \r[1/1]", g_knifename[g_exchangeKnife[target][host]])
		formatex(menu, charsmax(menu), "%s \y: %s", message3, message4)
		menu_additem(menuid, menu)
	}
	menu_additem(menuid, "\y加入項目")
	formatex(menu, charsmax(menu), "\y確定交易 | (\w%s: %s %s: %s\y)", MainName[id], message, TargetName[id], message2)
	menu_additem(menuid, menu)
	menu_additem(menuid, "\y取消交易")

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
	return PLUGIN_CONTINUE
}

public menu_exchange(id, menuid, item)
{
	new main, target;
	main = MainId[id];
	target = TargetId[id];
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new name[32];
	get_user_name(id, name, charsmax(name))
	switch (item)
	{
		case 5:
		{
			if (g_ready[main] == 1 || g_ready[target] == 1)
			{
				colored_print(id, "\x04[交易]\x03 有一方確定交易後，無法做出修改。")
				show_menu_exchange(id)
				return PLUGIN_CONTINUE
			}
			if (g_ready[id] == 1)
			{
				colored_print(id, "\x04[交易]\x03 你已經確定交易，等待對方確定交易中")
				show_menu_exchange(id)
				return PLUGIN_CONTINUE
			}
			show_menu_choose4(id)
			return PLUGIN_CONTINUE
		}
		case 6:
		{
			if (g_ready[id] == 1)
			{
				colored_print(id, "\x04[交易]\x03 你已經確定交易，等待對方確定交易中")
				show_menu_exchange(id)
				return PLUGIN_CONTINUE
			}
			g_ready[id] = 1
			if (g_ready[main] == 1 && g_ready[target] == 1)
			{
				for (new host;host < 5;host++)
				{
					if (g_exchangeNum[target][host])
					{
						add_exchange_item(main, g_exchange[target][host], g_exchangeNum[target][host])
						del_reset_bag_item2(target, g_exchange[target][host], g_exchangeNum[target][host])
					}
					if (g_exchangeNum[main][host])
					{
						add_exchange_item(target, g_exchange[main][host], g_exchangeNum[main][host])
						del_reset_bag_item2(main, g_exchange[main][host], g_exchangeNum[main][host])
					}
					if (g_exchangeWpn[main][host])
					{
						log_to_file(g_logfile, "名稱: %s 名稱: %s 槍械: %s (ExChange MainWpn)", MainName[id], TargetName[id], g_wpnname[g_exchangeWpn[main][host]])
						g_UnlockedWeapon[target][g_exchangeWpn[main][host]] = 1
						g_UnlockedWeapon[main][g_exchangeWpn[main][host]] = 0
					}
					if (g_exchangeWpn[target][host])
					{
						log_to_file(g_logfile, "名稱: %s 名稱: %s 槍械: %s (ExChange TargetWpn)", MainName[id], TargetName[id], g_wpnname[g_exchangeWpn[target][host]])
						g_UnlockedWeapon[main][g_exchangeWpn[target][host]] = 1
						g_UnlockedWeapon[target][g_exchangeWpn[target][host]] = 0
					}
					if (g_exchangeModel[main][host])
					{
						log_to_file(g_logfile, "名稱: %s 名稱: %s 人物: %s (ExChange MainModel)", MainName[id], TargetName[id], g_modelname[g_exchangeModel[main][host]])
						g_skin_info[target][g_exchangeModel[main][host]][SKIN_HAVE] = 1
						g_skin_info[main][g_exchangeModel[main][host]][SKIN_HAVE] = 0
						g_skin_info[main][g_exchangeModel[main][host]][SKIN_EQUIPED] = 0
					}
					if (g_exchangeModel[target][host])
					{
						log_to_file(g_logfile, "名稱: %s 名稱: %s 人物: %s (ExChange TargetModel)", MainName[id], TargetName[id], g_modelname[g_exchangeModel[target][host]])
						g_skin_info[main][g_exchangeModel[target][host]][SKIN_HAVE] = 1
						g_skin_info[target][g_exchangeModel[target][host]][SKIN_HAVE] = 0
						g_skin_info[target][g_exchangeModel[target][host]][SKIN_EQUIPED] = 0
					}
					if (g_exchangeKnife[main][host])
					{
						log_to_file(g_logfile, "名稱: %s 名稱: %s 刀: %s (ExChange MainKnife)", MainName[id], TargetName[id], g_knifename[g_exchangeKnife[main][host]]);
						g_UnlockedWeapon[target][g_exchangeKnife[main][host]] = 1
						g_UnlockedWeapon[main][g_exchangeKnife[main][host]] = 0
					}
					if (g_exchangeKnife[target][host])
					{
						log_to_file(g_logfile, "名稱: %s 名稱: %s 刀: %s (ExChange TargetKnife)", MainName[id], TargetName[id], g_knifename[g_exchangeKnife[target][host]]);
						g_UnlockedWeapon[main][g_exchangeKnife[target][host]] = 1
						g_UnlockedWeapon[target][g_exchangeKnife[target][host]] = 0
					}
				}
				if (g_exchangeSp[main])
				{
					PlayerSp[main] -= g_exchangeSp[main]
					g_Player[target][Base][SP] += g_exchangeSp[main]
				}
				if (g_exchangeSp[target])
				{
					g_Player[target][Base][SP] -= g_exchangeSp[target]
					PlayerSp[main] += g_exchangeSp[target]
				}
				log_to_file(g_logfile, "名稱: %s SP: %d 名稱: %s SP: %d (ExChange Success)", MainName[id], g_exchangeSp[main], TargetName[id], g_exchangeSp[target])
				g_ready[main] = 2
				g_ready[target] = 2
				g_exchangeing[main] = 0
				g_exchangeing[target] = 0
				g_exchangeSp[main] = 0
				g_exchangeSp[target] = 0
				for (new host;host < 5;host++)
				{
					g_exchange[target][host] = 0
					g_exchangeNum[target][host] = 0
					g_exchange[main][host] = 0
					g_exchangeNum[main][host] = 0
					g_exchangeWpn[target][host] = 0
					g_exchangeWpn[main][host] = 0
					g_exchangeModel[main][host] = 0
					g_exchangeKnife[main][host] = 0
					g_exchangeModel[target][host] = 0
					g_exchangeKnife[target][host] = 0
					g_exchangeType[target][host] = 0
					g_exchangeType[main][host] = 0
				}
				colored_print(main, "\x04[交易]\x03 交易成功")
				colored_print(target, "\x04[交易]\x03 交易成功")
				show_menu_exchange(main)
				show_menu_exchange(target)
				return PLUGIN_CONTINUE
			}
			colored_print(id, "\x04[交易]\x03 你已確定交易，等待對方確定交易中")
			colored_print(main, "\x04[交易]\x03 %s 已確定交易", name)
			colored_print(target, "\x04[交易]\x03 %s 已確定交易", name)
			show_menu_exchange(main)
			show_menu_exchange(target)
		}
		case 7:
		{
			log_to_file(g_logfile, "名稱: %s 名稱: %s (ExChange Failed)", MainName[id], TargetName[id])
			g_ready[main] = 3
			g_ready[target] = 3
			g_exchangeing[main] = 0
			g_exchangeing[target] = 0
			g_exchangeSp[main] = 0
			g_exchangeSp[target] = 0
			
			for (new host;host < 5;host++)
			{
				g_exchange[target][host] = 0
				g_exchangeNum[target][host] = 0
				g_exchange[main][host] = 0
				g_exchangeNum[main][host] = 0
				g_exchangeWpn[target][host] = 0
				g_exchangeWpn[main][host] = 0
				g_exchangeModel[main][host] = 0
				g_exchangeKnife[main][host] = 0
				g_exchangeModel[target][host] = 0
				g_exchangeKnife[target][host] = 0
				g_exchangeType[target][host] = 0
				g_exchangeType[main][host] = 0
			}
			colored_print(main, "\x04[交易]\x03 %s 已取消交易", name)
			colored_print(target, "\x04[交易]\x03 %s 已取消交易", name)
			show_menu_exchange(main)
			show_menu_exchange(target)
			return PLUGIN_CONTINUE
		}
	}
	show_menu_exchange(id)
	return PLUGIN_CONTINUE
}

public show_menu_choose4(id)
{
	static menuid
	menuid = menu_create("\y項目選擇表", "menu_choose4")
	menu_additem(menuid, "\w加入物品")
	menu_additem(menuid, "\w加入槍械")
	menu_additem(menuid, "\w加入人")
	menu_additem(menuid, "\w加入刀")
	menu_additem(menuid, "\w加入SP")
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_choose4(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	switch (item)
	{
		case 0:
		{
			show_menu_addbag(id)
		}
		case 1:
		{
			show_menu_addgun(id)
		}
		case 2:
		{
			show_menu_addmodel2(id)
		}
		case 3:
		{
			show_menu_addknife(id)
		}
		case 4:
		{
			client_cmd(id, "messagemode legend_sp")
			colored_print(id, "\x04[交易]\x03 請輸入數量")
		}
	}
	return PLUGIN_CONTINUE
}

public show_menu_addmodel2(id)
{
	static buffer[32], menu[128], menuid, count;
	menuid = menu_create("\w永久人物", "menu_addmodel2")
	for (new skin;skin < sizeof g_skinlist;skin++)
	{
		if (g_skin_info[id][skin][SKIN_HAVE])
		{
			formatex(menu, charsmax(menu), "\w%s", g_skinlist[skin][SKIN_NAME])
			buffer[0] = skin
			menu_additem(menuid, menu, buffer)
			count++
		}
	}
	if (!count)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_addmodel2(id, menuid, item)
{
	new main, target;
	main = MainId[id]
	target = TargetId[id]
	new command[6], item_name[64], access, callback, itemid;
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]
	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new name[32];
	get_user_name(id, name, charsmax(name))

	for (new host;host < 5;host++)
	{
		if (g_exchangeModel[id][host] == itemid)
		{
			colored_print(id, "\x04[交易]\x03 你已經加入了這個人物")
			show_menu_addmodel(id)
			return PLUGIN_HANDLED
		}
	}
	new full = 1;
	for (new host;host < 5;host++)
	{
		if (!g_exchangeType[id][host])
		{
			full = 0
			g_exchangeModel[id][host] = itemid
			g_exchangeType[id][host] = 3
			if (full)
			{
				colored_print(id, "\x04[交易]\x03 交易物品已滿")
				show_menu_exchange(id)
				return PLUGIN_HANDLED
			}
			colored_print(id, "\x04[交易]\x03 你已成功加入 %s。", g_skinlist[itemid][SKIN_NAME])
			colored_print(main, "\x04[交易]\x03 %s 已成功加入 %s。", name, g_skinlist[itemid][SKIN_NAME])
			colored_print(target, "\x04[交易]\x03 %s 已成功加入 %s。", name, g_skinlist[itemid][SKIN_NAME])
			show_menu_exchange(main)
			show_menu_exchange(target)
		}
	}
	if (full)
	{
		colored_print(id, "\x04[交易]\x03 交易物品已滿")
		show_menu_exchange(id)
		return PLUGIN_HANDLED
	}
	colored_print(id, "\x04[交易]\x03 你已成功加入 %s。", g_skinlist[itemid][SKIN_NAME])
	colored_print(main, "\x04[交易]\x03 %s 已成功加入 %s。", name, g_skinlist[itemid][SKIN_NAME])
	colored_print(target, "\x04[交易]\x03 %s 已成功加入 %s。", name, g_skinlist[itemid][SKIN_NAME])
	show_menu_exchange(main)
	show_menu_exchange(target)
	show_menu_exchange(id)
	return PLUGIN_HANDLED
}

public show_menu_addknife(id)
{
	static buffer[32], menu[128], menuid, count;
	menuid = menu_create("\w永久刀", "menu_addknife")

	if (!g_WeaponCount)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	else
	{
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_KNIFE && g_UnlockedWeapon[id][item])
			{
				formatex(menu, charsmax(menu), "\w%s", WeaponName[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
				count++
			}
		}
		if (!count)
		{
			buffer[0] = -1
			menu_additem(menuid, "\w无", buffer)
		}
	}

	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_addknife(id, menuid, item)
{
	new main, target;
	main = MainId[id]
	target = TargetId[id]
	new command[6], item_name[64], access, callback, itemid;
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]
	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new name[32];
	get_user_name(id, name, charsmax(name))
	for (new host;host < 5;host++)
	{
		if (g_exchangeKnife[id][host] == itemid)
		{
			colored_print(id, "\x04[交易]\x03 你已經加入了這把刀");
			show_menu_addknife(id);
			return PLUGIN_HANDLED
		}
	}
	new full = 1;
	for (new host;host < 5;host++)
	{
		if (!g_exchangeType[id][host])
		{
			full = 0
			g_exchangeKnife[id][host] = itemid
			g_exchangeType[id][host] = 4
			if (full)
			{
				colored_print(id, "\x04[交易]\x03 交易物品已滿");
				show_menu_exchange(id);
				return PLUGIN_HANDLED
			}
			colored_print(id, "\x04[交易]\x03 你已成功加入 %s。", WeaponName[itemid])
			colored_print(main, "\x04[交易]\x03 %s 已成功加入 %s。", name, WeaponName[itemid])
			colored_print(target, "\x04[交易]\x03 %s 已成功加入 %s。", name, WeaponName[itemid])
			show_menu_exchange(main)
			show_menu_exchange(target)
		}
	}
	if (full)
	{
		colored_print(id, "\x04[交易]\x03 交易物品已滿")
		show_menu_exchange(id)
		return PLUGIN_HANDLED
	}
	colored_print(id, "\x04[交易]\x03 你已成功加入 %s。", WeaponName[itemid])
	colored_print(main, "\x04[交易]\x03 %s 已成功加入 %s。", name, WeaponName[itemid])
	colored_print(target, "\x04[交易]\x03 %s 已成功加入 %s。", name, WeaponName[itemid])
	show_menu_exchange(main)
	show_menu_exchange(target)
	show_menu_exchange(id)
	return PLUGIN_HANDLED
}

public show_menu_addgun(id)
{
	new menuid, menu[128], buffer[32];
	menuid = menu_create("\w永久槍械", "menu_addgun")
	if (!g_WeaponCount)
	{
		buffer[0] = -1
		menu_additem(menuid, "\w无", buffer)
	}
	else
	{
		for (new item = 1;item <= g_WeaponCount;item++)
		{
			if (WeaponType[item] == TYPE_FOREVER && g_UnlockedWeapon[id][item])
			{
				formatex(menu, charsmax(menu), "\w%s", WeaponName[item])
				buffer[0] = item
				menu_additem(menuid, menu, buffer)
				count++
			}
		}
		if (!count)
		{
			buffer[0] = -1
			menu_additem(menuid, "\w无", buffer)
		}
	}
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_addgun(id, menuid, item)
{
	new main, target;
	main = MainId[id]
	target = TargetId[id]
	new command[6], item_name[64], access, callback, itemid;
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	itemid = command[0]
	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new name[32];
	get_user_name(id, name, charsmax(name))
	for (new host;host < 5;host++)
	{
		if (g_exchangeWpn[id][host] == itemid)
		{
			colored_print(id, "\x04[交易]\x03 你已經加入了這把槍械")
			show_menu_addgun(id)
			return PLUGIN_HANDLED
		}
	}
	new full = 1;
	for (new host;host < 5;host++)
	{
		if (!g_exchangeType[id][host])
		{
			full = 0
			g_exchangeWpn[id][host] = itemid
			g_exchangeType[id][host] = 2
			if (full)
			{
				colored_print(id, "\x04[交易]\x03 交易物品已滿")
				show_menu_exchange(id)
				return PLUGIN_HANDLED
			}
			colored_print(id, "\x04[交易]\x03 你已成功加入 %s。", WeaponName[itemid])
			colored_print(main, "\x04[交易]\x03 %s 已成功加入 %s。", name, WeaponName[itemid])
			colored_print(target, "\x04[交易]\x03 %s 已成功加入 %s。", name, WeaponName[itemid])
			show_menu_exchange(main)
			show_menu_exchange(target)
		}
	}
	if (full)
	{
		colored_print(id, "\x04[交易]\x03 交易物品已滿")
		show_menu_exchange(id)
		return PLUGIN_HANDLED
	}
	colored_print(id, "\x04[交易]\x03 你已成功加入 %s。", WeaponName[itemid])
	colored_print(main, "\x04[交易]\x03 %s 已成功加入 %s。", name, WeaponName[itemid])
	colored_print(target, "\x04[交易]\x03 %s 已成功加入 %s。", name, WeaponName[itemid])
	show_menu_exchange(main)
	show_menu_exchange(target)
	show_menu_exchange(id)
	return PLUGIN_HANDLED
}

public addsp(id)
{
	if (!g_exchangeing[id])
	{
		return PLUGIN_HANDLED
	}
	new main, target
	main = MainId[id]
	target = TargetId[id]
	new args[64];
	read_argv(1, args, charsmax(args));
	new check = str_to_num(args);
	if (containi(args, "a") != -1)
	{
		g_exchangeSp[id] = 0
		colored_print(id, "\x04[交易]\x03 含有非法字符")
		show_menu_exchange(id)
		return PLUGIN_HANDLED
	}
	if (!args[0] || check || check > g_Player[id][Base][SP])
	{
		g_exchangeSp[id] = 0
		colored_print(id, "\x04[交易]\x03 無效的數字")
		show_menu_exchange(id)
		return PLUGIN_HANDLED
	}
	new name[32];
	get_user_name(id, name, charsmax(name));
	g_exchangeSp[id] = check;
	colored_print(id, "\x04[交易]\x03 你已成功加入 %d SP", check);
	colored_print(main, "\x04[交易]\x03 %s 已成功加入 %d SP", name, check);
	colored_print(target, "\x04[交易]\x03 %s 已成功加入 %d SP", name, check);
	show_menu_exchange(main);
	show_menu_exchange(target);
	return PLUGIN_HANDLED
}

show_menu_addbag(id)
{
	new menuid, menu[128], buffer[32];
	menuid = menu_create("\y物品欄", "menu_addbag")
	for(new bag_item;bag_item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];bag_item++)
	{
		formatex(menu, charsmax(menu), "\w%s \r[%d/5]", g_itemname[g_Player[id][Bag][Index][item]], g_Player[id][Bag][Amount][item])
		buffer[0] = g_Player[id][Bag][Index][item]
		menu_additem(menuid, menu, buffer)
	}
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_addbag(id, menuid, item)
{
	if (item == -3)
	{
		show_menu_exchange(id);
		return PLUGIN_HANDLED
	}
	new buffer[2];
	new dummy;
	menu_item_getinfo(menuid, item, dummy, buffer, 1, {0}, 0, dummy);
	item = buffer[0];
	if (item)
	{
		if (item == 20)
		{
			colored_print(id, "\x04[交易]\x03 選擇錯誤");
			show_menu_addbag(id);
			return PLUGIN_HANDLED
		}
		for (new host;host < 5;host++)
		{
			if (g_exchange[id][host] == item && g_exchangeNum[id][host])
			{
				colored_print(id, "\x04[交易]\x03 你已經加入了這個物品");
				show_menu_addbag(id);
				return PLUGIN_HANDLED
			}
			if (item == 6 || item == 7 || item == 8 || item == 9 || item == 10 || item == 11)
			{
				colored_print(id, "\x04[交易]\x03 不能加入此物品");
				show_menu_addbag(id);
				return PLUGIN_HANDLED
			}
		}
		new full = 1;
		for (new host;host < 5;host++)
		{
			if (!g_exchangeType[id][host])
			{
				full = 0;
				g_exchange[id][host] = item;
				client_cmd(id, "messagemode legend_num");
				colored_print(id, "\x04[交易]\x03 請輸入數量");
				if (full)
				{
					colored_print(id, "\x04[交易]\x03 交易物品已滿");
					show_menu_exchange(id);
					return PLUGIN_HANDLED
				}
				return PLUGIN_HANDLED
			}
		}
		if (full)
		{
			colored_print(id, "\x04[交易]\x03 交易物品已滿");
			show_menu_exchange(id);
			return PLUGIN_HANDLED
		}
		return PLUGIN_HANDLED
	}
	colored_print(id, "\x04[交易]\x03 空位不能選擇");
	show_menu_addbag(id);
	return PLUGIN_HANDLED
}

public additem(id)
{
	if (!g_exchangeing[id])
	{
		return PLUGIN_HANDLED
	}
	new main;
	new target;
	main = MainId[id];
	target = TargetId[id];
	new num;
	for (new host;host < 5;host++)
	{
		if (g_exchange[id][host])
		{
			num = host;
		}
	}
	new args[64];
	read_argv(1, args, 63);
	new check = str_to_num(args);
	if (containi(args, 345736) != -1)
	{
		g_exchange[id][num] = 0;
		g_exchangeNum[id][num] = 0;
		g_exchangeType[id][num] = 0;
		colored_print(id, "\x04[交易]\x03 含有非法字符");
		show_menu_exchange(id);
		return PLUGIN_HANDLED
	}
	if (!args[0] || check || check > 5 || !check_bag_item(id, g_exchange[id][num], check))
	{
		g_exchange[id][num] = 0;
		g_exchangeNum[id][num] = 0;
		g_exchangeType[id][num] = 0;
		colored_print(id, "\x04[交易]\x03 無效的數字");
		show_menu_exchange(id);
		return PLUGIN_HANDLED
	}
	new message[32];
	formatex(message, 31, "%s", g_itemname[g_exchange[id][num]]);
	new name[32];
	get_user_name(id, name, 31);
	g_exchangeNum[id][num] = check;
	g_exchangeType[id][num] = 1;
	colored_print(id, "\x04[交易]\x03 你已成功加入 %s", g_itemname[g_exchange[id][num]]);
	colored_print(main, "\x04[交易]\x03 %s 已成功加入 %s", name, message);
	colored_print(target, "\x04[交易]\x03 %s 已成功加入 %s", name, message);
	show_menu_exchange(main);
	show_menu_exchange(target);
	return PLUGIN_HANDLED
}

public ReadyMenu(id)
{
	new szMenuBody[501];
	new keys;
	new nLen = format(szMenuBody, 500, "\y對方 \w%s \y想和你進行交易，你是否同意？？\n確定前請先檢查背包是否有足夠的位置\n提高警惕! 提防詐騙!\w", MainName[id])
	nLen = format(szMenuBody[nLen], 500 - nLen, "\n\n確定交易") + nLen
	nLen = format(szMenuBody[nLen], 500 - nLen, "\n取消交易") + nLen
	keys = (1<<0|1<<1)
	show_menu(id, keys, szMenuBody)
	return PLUGIN_HANDLED
}

public ReadyCommand(id, key)
{
	new main = MainId[id]
	switch (key)
	{
		case 0:
		{
			colored_print(id, "\x04[交易]\x03 你已確定交易");
			colored_print(main, "\x04[交易]\x03 對方已確定交易");
			show_menu_exchange(id);
			show_menu_exchange(main);
			g_exchangeing[id] = 1;
			g_exchangeing[main] = 1;
		}
		case 1:
		{
			colored_print(id, "\x04[交易]\x03 你已取消交易");
			colored_print(main, "\x04[交易]\x03 對方已取消交易");
		}
	}
	return PLUGIN_HANDLED
}

public show_menu_trade(id)
{
	new menuid;
	new menu[128];
	new buffer[32];
	formatex(menu, 127, "\w交易系統\n\y在進行交易前，請先檢查背包是否有足夠的位置");
	menuid = menu_create(menu, "menu_trade", 0);
	buffer[0] = 0;
	menu_additem(menuid, "\w有足夠的位置", buffer, 0, -1);
	buffer[0] = 1;
	menu_additem(menuid, "\w交易選單", buffer, 0, -1);
	buffer[0] = 2;
	if (g_exchangeOff[id])
	{
		menu_additem(menuid, "\w開啟交易", buffer, 0, -1);
	}
	else
	{
		menu_additem(menuid, "\w關閉交易", buffer, 0, -1);
	}
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
	return 0;
}

public menu_trade(id, menuid, item)
{
	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new buffer[4];
	new dummy;
	new itemid;
	menu_item_getinfo(menuid, item, dummy, buffer, "", {0}, 0, dummy);
	itemid = buffer[0];
	new main;
	new target;
	main = MainId[id];
	target = TargetId[id];
	switch (itemid)
	{
		case 0:
		{
			if (g_exchangeOff[id])
			{
				colored_print(id, "\x04[交易]\x03 你已經關閉交易，請先開啟交易。");
				return PLUGIN_HANDLED
			}
			show_menu_playerlist(id);
		}
		case 1:
		{
			if (g_exchangeing[id])
			{
				colored_print(id, "\x04[交易]\x03 你已經進行交易中");
				show_menu_exchange(main);
				show_menu_exchange(target);
				return PLUGIN_HANDLED
			}
			colored_print(id, "\x04[交易]\x03 你沒有進行交易");
		}
		case 2:
		{
			if (!g_exchangeOff[id])
			{
				g_exchangeOff[id] = 1;
				colored_print(id, "\x04[交易]\x03 你已關閉交易，你現在不能進行交易。");
			}
			else
			{
				g_exchangeOff[id] = 0;
				colored_print(id, "\x04[交易]\x03 你已開啟交易，你現在可以進行交易。");
			}
		}
	}
	return PLUGIN_HANDLED
}

public show_menu_playerlist(id)
{
	new menuid, menu[128], buffer[32];
	formatex(menu, charsmax(menu), "\w《名單選擇表》");
	menuid = menu_create(menu, "menu_playerlist");
	
	for (new i = 1;i <= g_maxplayers;i++)
	{
		new name[33];
		get_user_name(i, name, charsmax(name))
		if (id != i && !name[0] && !is_user_connected(i) && g_Player[i][Base][Level] < 20 && get_user_status(i) == 6)
		{
		}
		if ()
		{
			new message[32];
			if (g_exchangeOff[i])
			{
				formatex(message, charsmax(message), "\d關閉交易");
			}
			else
			{
				if (g_exchangeing[i])
				{
					formatex(message, charsmax(message), "\r交易中");
				}
				formatex(message, charsmax(message), "\y已準備");
			}
			formatex(menu, charsmax(menu), "\w%s [%s\w]", name, message);
			buffer[0] = i;
			menu_additem(menuid, menu, buffer, 0, -1);
		}
	}
	menu_setprop(menuid, MPROP_BACKNAME, "返回")
	menu_setprop(menuid, MPROP_NEXTNAME, "下頁")
	menu_setprop(menuid, MPROP_EXITNAME, "離開")
	menu_display(id, menuid)
}

public menu_playerlist(id, menuid, item)
{
	if (item == MENU_EXIT || itemid == 255)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new buffer[4];
	new dummy;
	new itemid;
	menu_item_getinfo(menuid, item, dummy, buffer, "", {0}, 0, dummy);
	itemid = buffer[0];
	if (g_exchangeOff[itemid])
	{
		colored_print(id, "\x04[交易]\x03 對方已經關閉交易。");
	}
	else
	{
		if (g_exchangeing[itemid])
		{
			colored_print(id, "\x04[交易]\x03 對方交易中，請稍候");
		}
		new MainName1[32];
		new TargetName1[32];
		get_user_name(id, MainName1, 31);
		get_user_name(itemid, TargetName1, 31);
		formatex(MainName[id], 31, MainName1);
		formatex(TargetName[id], 31, TargetName1);
		formatex(MainName[itemid], 31, MainName1);
		formatex(TargetName[itemid], 31, TargetName1);
		MainId[itemid] = id;
		TargetId[id] = itemid;
		MainId[id] = id;
		TargetId[itemid] = itemid;
		ReadyMenu(itemid);
		colored_print(id, "\x04[交易]\x03 等待對方確定交易中");
		colored_print(itemid, "\x04[交易]\x03 對方想和你進行交易");
	}
	return PLUGIN_HANDLED
}
*/

public SaveLevel(id)
{
	new json_data[1024], name[64]//, qq[64];
	//zp_get_user_qq(id, qq, charsmax(qq));
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()

	json_object_set_number(jObject, "Level", g_Player[id][Base][Level])
	json_object_set_number(jObject, "Xp", g_Player[id][Base][XP])
	json_object_set_number(jObject, "Sp", g_Player[id][Base][SP])
	json_object_set_number(jObject, "Gash", g_Player[id][Base][Gash])
	json_object_set_number(jObject, "Coupon", g_Player[id][Base][Coupon])
	json_object_set_number(jObject, "Bag_Increase", g_Player[id][Bag][Increase])
	json_serial_to_string(jObject, json_data, charsmax(json_data))

	/*暂用名字保存信息
	zp_get_user_qq(id, qq, charsmax(qq))
	nvault_set(nvault_open("Boss_Level"), qq, json_data)
	*/
	nvault_set(nvault_open("Boss_Level"), name, json_data)
	json_free(jObject)
}

public LoadLevel(id)
{
	new json_data[1024], name[64]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_Level"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		g_Player[id][Base][Level] = json_object_get_number(jObject, "Level")
		g_Player[id][Base][XP] = json_object_get_number(jObject, "Xp")
		g_Player[id][Base][SP] = json_object_get_number(jObject, "Sp")
		g_Player[id][Base][Gash] = json_object_get_number(jObject, "Gash")
		g_Player[id][Base][Coupon] = json_object_get_number(jObject, "Coupon")
		g_Player[id][Bag][Increase] = json_object_get_number(jObject, "Bag_Increase")
	}

	if (!g_Player[id][Base][Level])
	{
		g_Player[id][Base][Level] = 1
	}

	json_free(jObject)
}

//pri: 22, 28, 13, 24, 3, 18, 15, 14, 20, 21, 5, 27, 8, 7, 12, 19, 23, 30
//sec: 1, 10, 11, 16, 17, 26
new const wpn_id[] = { 22, 28, 13, 24, 3, 18, 15, 14, 20, 21, 5, 27, 8, 7, 12, 19, 23, 30, 1, 10, 11, 16, 17, 26 }
public SaveGunLevel(id)
{
	new json_data[2048], name[64], temp[32]
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()
	for(new i=0;i<sizeof(wpn_id);i++)
	{
		format(temp, charsmax(temp), "GunLv%d", wpn_id[i])
		json_object_set_number(jObject, temp, g_Player[id][Base][GunLevel][wpn_id[i]])
		format(temp, charsmax(temp), "GunXp%d", wpn_id[i])
		json_object_set_number(jObject, temp, g_Player[id][Base][GunXP][wpn_id[i]])
	}
	json_serial_to_string(jObject, json_data, charsmax(json_data))
	nvault_set(nvault_open("Boss_GunLevel"), name, json_data)
	json_free(jObject)
}

public LoadGunLevel(id)
{
	new json_data[2048], name[64], temp[32]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_GunLevel"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		for(new i=0;i<sizeof(wpn_id);i++)
		{
			format(temp, charsmax(temp), "GunLv%d", wpn_id[i])
			g_Player[id][Base][GunLevel][wpn_id[i]] = json_object_get_number(jObject, temp)
			format(temp, charsmax(temp), "GunXp%d", wpn_id[i])
			g_Player[id][Base][GunXP][wpn_id[i]] = json_object_get_number(jObject, temp)
		}
	}

	//初始化槍械等級
	for(new wpnid = 0;wpnid < 31;wpnid++)
	{
		if (g_Player[id][Base][GunLevel][wpnid] <= 0)
		{
			g_Player[id][Base][GunLevel][wpnid] = 1
		}
	}

	json_free(jObject)
}

public SaveItem(id)
{
	new json_data[2048], name[64], temp[32]
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()
	for(new i=0;i<DEFAULT_BAG_SPACE+g_Player[id][Bag][Increase];i++)
	{
		format(temp, charsmax(temp), "%d_ID", i)
		json_object_set_number(jObject, temp, g_Player[id][Bag][Index][i])
		format(temp, charsmax(temp), "%d_NUM", i)
		json_object_set_number(jObject, temp, g_Player[id][Bag][Amount][i])
	}
	json_serial_to_string(jObject, json_data, charsmax(json_data))
	nvault_set(nvault_open("Boss_Item"), name, json_data)
	json_free(jObject)
}

public LoadItem(id)
{
	new json_data[2048], name[64], temp[32]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_Item"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		for(new i=0;i<DEFAULT_BAG_SPACE+g_Player[id][Bag][Increase];i++)
		{
			format(temp, charsmax(temp), "%d_ID", i)
			g_Player[id][Bag][Index][i] = json_object_get_number(jObject, temp)
			format(temp, charsmax(temp), "%d_NUM", i)
			g_Player[id][Bag][Amount][i] = json_object_get_number(jObject, temp)
		}
	}

	json_free(jObject)
}

public SavePoint(id)
{
	new json_data[512], name[64]
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()
	
	json_object_set_number(jObject, "Skill_Point", g_skpoint[id])
	json_object_set_number(jObject, "Max_HP", max_hp[id])
	json_object_set_number(jObject, "Max_Speed", max_speed[id])
	json_object_set_number(jObject, "Max_Damage", max_damage[id])
	json_object_set_number(jObject, "Max_Jump", max_jump[id])

	json_serial_to_string(jObject, json_data, charsmax(json_data))
	nvault_set(nvault_open("Boss_Point"), name, json_data)
	json_free(jObject)
}

public LoadPoint(id)
{
	new json_data[512], name[64]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_Point"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		g_skpoint[id] = json_object_get_number(jObject, "Skill_Point")
		max_hp[id] = json_object_get_number(jObject, "Max_HP")
		max_speed[id] = json_object_get_number(jObject, "Max_Speed")
		max_damage[id] = json_object_get_number(jObject, "Max_Damage")
		max_jump[id] = json_object_get_number(jObject, "Max_Jump")
	}
	
	json_free(jObject)
}

//new g_doing1[33][MAX_TAKE_TASK_NUM], g_doing2[33][MAX_TAKE_TASK_NUM], g_doing3[33][MAX_TAKE_TASK_NUM], g_task_done[33][TASKS_NUM]

public SaveTask(id)
{
	new json_data[2048], name[64], temp[128]
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()
	
	for(new task_id;task_id<MAX_TAKE_TASK_NUM;task_id++)
	{
		format(temp, charsmax(temp), "Slot%d", task_id)
		json_object_set_number(jObject, temp, g_doing1[id][task_id])
		format(temp, charsmax(temp), "Do%d", task_id)
		json_object_set_number(jObject, temp, g_doing2[id][task_id])
		format(temp, charsmax(temp), "Todo%d", task_id)
		json_object_set_number(jObject, temp, g_doing3[id][task_id])
	}

	for(new task_id = 1;task_id<TASKS_NUM;task_id++)
	{
		format(temp, charsmax(temp), "T_cando%d", task_id)
		json_object_set_number(jObject, temp, g_task_done[id][task_id])
	}

	json_serial_to_string(jObject, json_data, charsmax(json_data))
	nvault_set(nvault_open("Boss_Task"), name, json_data)
	json_free(jObject)
}

public LoadTask(id)
{
	new json_data[2048], name[64], temp[128]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_Task"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		for(new task_id;task_id<MAX_TAKE_TASK_NUM;task_id++)
		{
			format(temp, charsmax(temp), "Slot%d", task_id)
			g_doing1[id][task_id] = json_object_get_number(jObject, temp)
			format(temp, charsmax(temp), "Do%d", task_id)
			g_doing2[id][task_id] = json_object_get_number(jObject, temp)
			format(temp, charsmax(temp), "Todo%d", task_id)
			g_doing3[id][task_id] = json_object_get_number(jObject, temp)
		}

		for(new task_id = 1;task_id<TASKS_NUM;task_id++)
		{
			format(temp, charsmax(temp), "T_cando%d", task_id)
			g_task_done[id][task_id] = json_object_get_number(jObject, temp)
		}
	}
	
	json_free(jObject)
}

public SaveLimit(id)
{
	new json_data[256], name[64]
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()
	
	json_object_set_number(jObject, "Expx2", exp_x2[id])
	json_object_set_number(jObject, "Expx2_Time", exp_x2_time[id])

	json_serial_to_string(jObject, json_data, charsmax(json_data))
	nvault_set(nvault_open("Boss_Limit"), name, json_data)
	json_free(jObject)
}

public LoadLimit(id)
{
	new json_data[256], name[64]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_Limit"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		exp_x2[id] = json_object_get_number(jObject, "Expx2")
		exp_x2_time[id] = json_object_get_number(jObject, "Expx2_Time")
	}
	
	json_free(jObject)
}

public SaveSkill(id)
{
	new json_data[2048], name[64], temp[128]
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()
	
	for (new i;i<12;i++)
	{
		format(temp, charsmax(temp), "Skill%d", i)
		json_object_set_number(jObject, temp, job_skill[id][i])
	}
	for (new i;i<4;i++)
	{
		format(temp, charsmax(temp), "Maxlv%d", i)
		json_object_set_number(jObject, temp, limit_skill[id][i])
	}
	json_object_set_number(jObject, "Job", g_job[id])
	json_object_set_number(jObject, "HPLV", max_hp[id])
	json_object_set_number(jObject, "SpeedLV", max_speed[id])
	json_object_set_number(jObject, "DMGLV", max_damage[id])
	json_object_set_number(jObject, "JumpLV", max_jump[id])

	json_serial_to_string(jObject, json_data, charsmax(json_data))
	nvault_set(nvault_open("Boss_Skill"), name, json_data)
	json_free(jObject)
}

public LoadSkill(id)
{
	new json_data[2048], name[64], temp[128]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_Skill"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		for (new i;i<12;i++)
		{
			format(temp, charsmax(temp), "Skill%d", i)
			job_skill[id][i] = json_object_get_number(jObject, temp)
		}

		for (new i;i<4;i++)
		{
			format(temp, charsmax(temp), "Maxlv%d", i)
			limit_skill[id][i] = json_object_get_number(jObject, temp)
		}

		g_job[id] = json_object_get_number(jObject, "Job")
		max_hp[id] = json_object_get_number(jObject, "HPLV")
		max_speed[id] = json_object_get_number(jObject, "SpeedLV")
		max_damage[id] = json_object_get_number(jObject, "DMGLV")
		max_jump[id] = json_object_get_number(jObject, "JumpLV")
	}
	
	json_free(jObject)
}

public SaveWeapons(id)
{
	new json_data[3072], name[64]
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()
	
	if (g_WeaponCount)
	{
		for (new wep = 1;wep <= g_WeaponCount;wep++)
		{
			if (WeaponType[wep] == TYPE_FOREVER)
			{
				json_object_set_number(jObject, WeaponSaveName[wep], g_UnlockedWeapon[id][wep])
			}
		}
	}

	json_serial_to_string(jObject, json_data, charsmax(json_data))
	nvault_set(nvault_open("Boss_Weapons"), name, json_data)
	json_free(jObject)
}

public LoadWeapons(id)
{
	new json_data[3072], name[64]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_Weapons"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		if (g_WeaponCount)
		{
			for (new wep = 1;wep <= g_WeaponCount;wep++)
			{
				if (WeaponType[wep] == TYPE_FOREVER)
				{
					g_UnlockedWeapon[id][wep] = json_object_get_number(jObject, WeaponSaveName[wep])
				}
			}
		}
	}
	
	json_free(jObject)
}

public SaveHighWeapons(id)
{
	new json_data[3072], name[64]
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()
	
	if (g_WeaponCount)
	{
		for (new wep = 1;wep <= g_WeaponCount;wep++)
		{
			if (WeaponType[wep] == TYPE_SPECIAL)
			{
				json_object_set_number(jObject, WeaponSaveName[wep], g_UnlockedWeapon[id][wep])
			}
		}
	}

	json_serial_to_string(jObject, json_data, charsmax(json_data))
	nvault_set(nvault_open("Boss_HighWeapons"), name, json_data)
	json_free(jObject)
}

public LoadHighWeapons(id)
{
	new json_data[3072], name[64]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_HighWeapons"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		if (g_WeaponCount)
		{
			for (new wep = 1;wep <= g_WeaponCount;wep++)
			{
				if (WeaponType[wep] == TYPE_SPECIAL)
				{
					g_UnlockedWeapon[id][wep] = json_object_get_number(jObject, WeaponSaveName[wep])
				}
			}
		}
	}
	
	json_free(jObject)
}

public SaveKnife(id)
{
	new json_data[3072], name[64]
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()
	
	if (g_WeaponCount)
	{
		for (new wep = 1;wep <= g_WeaponCount;wep++)
		{
			if (WeaponType[wep] == TYPE_KNIFE)
			{
				json_object_set_number(jObject, WeaponSaveName[wep], g_UnlockedWeapon[id][wep])
			}
		}
	}

	json_serial_to_string(jObject, json_data, charsmax(json_data))
	nvault_set(nvault_open("Boss_Knife"), name, json_data)
	json_free(jObject)
}

public LoadKnife(id)
{
	new json_data[3072], name[64]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_Knife"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		if (g_WeaponCount)
		{
			for (new wep = 1;wep <= g_WeaponCount;wep++)
			{
				if (WeaponType[wep] == TYPE_KNIFE)
				{
					g_UnlockedWeapon[id][wep] = json_object_get_number(jObject, WeaponSaveName[wep])
				}
			}
		}
	}
	
	json_free(jObject)
}

public SavePlayerModels(id)
{
	new json_data[3072], name[64], temp[64]
	get_user_name(id, name, charsmax(name))
	new JSON:jObject = json_init_object()
	
	for (new skin;skin < sizeof g_skinlist;skin++)
	{
		json_object_set_number(jObject, g_skinlist[skin][SKIN_NAME], g_skin_info[id][skin][SKIN_HAVE])
		format(temp, charsmax(temp), "%s_Equiped", g_skinlist[skin][SKIN_NAME])
		json_object_set_number(jObject, temp, g_skin_info[id][skin][SKIN_EQUIPED])
	}

	json_serial_to_string(jObject, json_data, charsmax(json_data))
	nvault_set(nvault_open("Boss_PlayerModels"), name, json_data)
	json_free(jObject)
}

public LoadPlayerModels(id)
{
	new json_data[3072], name[64], temp[64]
	get_user_name(id, name, charsmax(name))
	nvault_get(nvault_open("Boss_PlayerModels"), name, json_data, charsmax(json_data))
	new JSON:jObject = json_parse(json_data)

	if(jObject != Invalid_JSON)
	{
		for (new skin;skin < sizeof g_skinlist;skin++)
		{
			g_skin_info[id][skin][SKIN_HAVE] = json_object_get_number(jObject, g_skinlist[skin][SKIN_NAME])
			format(temp, charsmax(temp), "%s_Equiped", g_skinlist[skin][SKIN_NAME])
			g_skin_info[id][skin][SKIN_EQUIPED] = json_object_get_number(jObject, temp)
		}
	}
	
	json_free(jObject)
}

stock colored_print (const id, const input[], any:...)
{
    static count = 1, players[32]
    static msg[255], i
    vformat(msg, charsmax(msg), input, 3)
    
    replace_all(msg, charsmax(msg), "\x04", "^4")
    replace_all(msg, charsmax(msg), "\x03", "^3")
    
    if (id) players[0] = id
        
    else get_players(players, count, "ch")
    
    for (i = 0; i < count; i++)
	{
        if (is_user_connected(players[i]))
        {
            message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i])
            write_byte(players[i])
            write_string(msg)
            message_end()
        }
	}
}

public ac_user_logined(id)
{
	LoadLevel(id)
	LoadGunLevel(id)
	LoadItem(id)
	LoadPoint(id)
	LoadTask(id)
	LoadLimit(id)
	LoadSkill(id)
	LoadKnife(id)
	LoadHighWeapons(id)
	LoadWeapons(id)
	LoadPlayerModels(id)
	g_Player[id][Base][DataLoaded] = true
	colored_print(id, "\x04[系統] \x03登錄成功，資料已成功載入！")
}

public SavePlayerData(id)
{	
	if (is_user_connected(id) && g_Player[id][Base][DataLoaded] && !is_user_bot(id))
	{
		SaveLevel(id);
		SaveGunLevel(id);
		SaveItem(id);
		SavePoint(id);
		SaveTask(id);
		SaveLimit(id);
		SaveHighWeapons(id);
		SaveWeapons(id);
		SavePlayerModels(id);
		SaveKnife(id);
		SaveSkill(id);
		colored_print(id, "\x04[自動保存]\x03 所有的資料已經被保存")
	}
}

public limit_item(taskid)
{
	new id = taskid - TASK_EXPX2
	if (exp_x2[id] > 0)
	{
		if (exp_x2_time[id] < 2)
		{
			colored_print(id, "\x04[系統]\x03 你的\x04 雙倍經驗 (1小時)\x03 時限已到！！")
			exp_x2[id] = 0
			exp_x2_time[id] = 0
			remove_task(id + TASK_EXPX2)
		}
		else exp_x2_time[id]--
	}
}

public set_user_nvision(taskid)
{
	new id = taskid - TASK_NIGHTVISION
	message_begin(MSG_ONE, get_user_msgid("ScreenFade"), _, id)
	write_short(1<<12)
	write_short(0)
	write_short(0)
	write_byte(100)
	write_byte(100)
	write_byte(100)
	write_byte(50)
	message_end()
}

set_user_gnvision(id, toggle)
{
	message_begin(MSG_ONE, get_user_msgid("NVGToggle"), _, id)
	write_byte(toggle)
	message_end()
}

public spec_nvision(id)
{
	if (!is_user_connected(id) || is_user_alive(id)) //TODO:登录系统判断 || get_user_status(id) == 6)
	{
		return PLUGIN_HANDLED
	}
	g_nvision[id] = 1
	g_nvisionenabled[id] = 1
	message_begin(MSG_ONE_UNRELIABLE, SVC_LIGHTSTYLE, _, id)
	write_byte(0)
	write_string("Z")
	message_end()
	set_task(0.1, "set_user_nvision", id + TASK_NIGHTVISION)
	return PLUGIN_HANDLED
}

public lighting_effects()
{
	
	for (new id = 1;g_maxplayers >= id;id++)
	{
		if (is_user_connected(id) && !g_nvisionenabled[id])
		{
			message_begin(MSG_ONE_UNRELIABLE, SVC_LIGHTSTYLE, _, id)
			write_byte(0)
			write_string("e")
			message_end()
		}
	}
}

public cmd_jointeam(id)
{
	if (fm_cs_get_user_team(id) == FM_CS_TEAM_SPECTATOR || fm_cs_get_user_team(id) == FM_CS_TEAM_UNASSIGNED)
	{
		new num[2]
		num_to_str(random_num(1,4), num, charsmax(num))
		engclient_cmd(id, "jointeam", "2", num)
		return PLUGIN_HANDLED
	}
	set_task(0.0, "show_menu_game", id)
	return PLUGIN_HANDLED
}

public clcmd_changeteam(id)
{
	if (fm_cs_get_user_team(id) == FM_CS_TEAM_SPECTATOR || fm_cs_get_user_team(id) == FM_CS_TEAM_UNASSIGNED)
	{
		return PLUGIN_CONTINUE
	}
	if (g_keyconfig[id])
	{
		return PLUGIN_HANDLED
	}
	g_keyconfig[id] = 1
	set_task(0.0, "show_menu_game", id)
	set_task(2.0, "reset_keyconfig", id)
	return PLUGIN_HANDLED
}

public reset_keyconfig(id)
{
	g_keyconfig[id] = 0
}

public forward_spawn(ent)
{
	if (!is_valid_ent(ent)) return FMRES_IGNORED
	new classname[32]
	entity_get_string(ent, EV_SZ_classname, classname, charsmax(classname))
	
	for (new i = 0;i < 9;i++)
	{
		if (equal(classname, g_objective_ents[i]))
		{
			engfunc(EngFunc_RemoveEntity, ent)
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED;
}

public menu_drop4(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new name[64], command[6], item_name[64], access, callback, itemid
	menu_item_getinfo(menuid, item, access, command, sizeof command - 1, item_name, sizeof item_name - 1, callback)
	get_user_name(id, name, charsmax(name))
	itemid = command[0]
	switch (itemid)
	{
		case 0:
		{
			if (skilled[id][0])
			{
				set_dhudmessage(100, 100, 100, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "一回合只能用一次技能")
			}
			else
			{
				g_headshoot[id] = 1
				skilled[id][0] = 1
				g_Player[id][Base][Status] = 8
				fm_set_rendering(id, kRenderFxGlowShell, 250, 250, 0, kRenderNormal, 25)
				set_task(2.0 * job_skill[id][0] + 5.0, "remove_skill", id)
				emit_sound(id, 2, g_speed, 1.0, ATTN_NORM, 0, 50)
			}
		}
		case 1:
		{
			if (skilled[id][1])
			{
				set_dhudmessage(100, 100, 100, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "一回合只能用一次技能")
			}
			else
			{
				g_critical_knife[id] = 1
				skilled[id][1] = 1
				g_Player[id][Base][Status] = 9
				fm_set_rendering(id, kRenderFxGlowShell, 250, 0, 0, kRenderNormal, 25)
				set_task(10.0 + 1.0 * job_skill[id][3], "remove_skill", id)
				emit_sound(id, 2, g_speed, 1.0, ATTN_NORM, 0, 50)
			}
		}
		case 2:
		{
			if (skilled[id][2])
			{
				set_dhudmessage(100, 100, 100, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "一回合只能用一次技能")
			}
			else
			{
				g_headshot[id] = 1
				skilled[id][2] = 1
				g_Player[id][Base][Status] = 10
				fm_set_rendering(id, kRenderFxGlowShell, 0, 255, 0, kRenderNormal, 25)
				set_task(10.0 + 2.0 * job_skill[id][6], "remove_skill", id)
				emit_sound(id, 2, g_speed, 1.0, ATTN_NORM, 0, 50)
			}
		}
		case 3:
		{
			if (skilled[id][3])
			{
				set_dhudmessage(100, 100, 100, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "一回合只能用一次技能")
			}
			else
			{
				skilled[id][3] = 1
				g_Player[id][Base][Status] = 11
				set_entity_visibility(id, 0)
				g_Player[id][Base][Hide] = 1
				set_task(5.0 + 1.0 * job_skill[id][9], "remove_hide", id)
			}
		}
	}
	return PLUGIN_CONTINUE
}

public menu_drop3(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new name[64]
	get_user_name(id, name, charsmax(name))
	switch (item)
	{
		case 0:
		{
			if (g_Player[id][Base][Reload] >= 333)
			{
				g_Player[id][Base][Reload] -= 333
				fm_set_user_godmode(id, 1)
				fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
				set_task(1.0, "remove_godmode", id)
				new Float:velocity[3] = 0.0
				velocity_by_aim(id, 1000, velocity)
				velocity[2] = 200.0
				entity_set_vector(id, EV_VEC_velocity, velocity)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用長跳", name)
				PlaySound(0, g_hunterlj[random_num(0, 1)])
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 1:
		{
			if (g_Player[id][Base][Reload] >= 333 && !g_gboost[id])
			{
				g_gboost[id] = 1
				g_Player[id][Base][Reload] -= 333
				set_user_maxspeed(id, 420.0)
				fm_set_rendering(id, kRenderFxGlowShell, 0, 255, 0, kRenderNormal, 25)
				set_task(10.0, "remove_boost", id)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用加速", name)
				PlaySound(0, "legend/Zombie_GBoost.wav")
			}
			else
			{
				if (g_gboost[id])
				{
					set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
					show_dhudmessage(id, "技能使用中")
				}
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 2:
		{
			if (g_Player[id][Base][Reload] >= 333)
			{
				g_Player[id][Base][Reload] -= 333
				fm_set_user_godmode(id, 1)
				fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
				set_task(2.0, "remove_godmode", id)
				set_entity_visibility(id, 0)
				g_Player[id][Base][Hide] = 1
				set_task(10.0, "remove_hide", id)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用隱身", name)
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 3:
		{
			if (g_Player[id][Base][Reload] >= 333)
			{
				g_Player[id][Base][Reload] -= 333
				fm_set_user_godmode(id, 1)
				fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用無敵", name)
				set_task(5.0, "remove_godmode", id)
				PlaySound(0, "legend/Zombie_GBoost.wav")
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 4:
		{
			if (g_Player[id][Base][Reload] >= 333)
			{
				g_Player[id][Base][Reload] -= 333
				fm_set_user_godmode(id, 1)
				fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
				set_task(2.0, "remove_godmode", id)
				new Float:velocity[3]
				entity_get_vector(id, EV_VEC_velocity, velocity)
				velocity[2] = 5000.0
				entity_set_vector(id, EV_VEC_velocity, velocity)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用超級高跳", name)
				PlaySound(0, g_hunterlj[random_num(0, 1)])
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 5:
		{
			if (g_Player[id][Base][Reload] >= 333)
			{
				g_Player[id][Base][Reload] -= 333
				boss_skill(id, 500.0, 500, 1)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用範圍內的人速度下降", name)
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 6:
		{
			if (g_Player[id][Base][Reload] >= 333)
			{
				g_Player[id][Base][Reload] -= 333
				boss_skill(id, 500.0, 500, 2)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用範圍內的人中毒", name)
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 7:
		{
			if (g_Player[id][Base][Reload] >= 888)
			{
				g_Player[id][Base][Reload] -= 888
				boss_skill(id, 500.0, 500, 3)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用範圍內的人彈走", name)
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
	}
	return PLUGIN_HANDLED
}

public menu_drop2(id, menuid, item)
{
	if (item == MENU_EXIT)
	{
		menu_destroy(menuid)
		return PLUGIN_HANDLED
	}
	new name[64]
	get_user_name(id, name, charsmax(name))
	switch (item)
	{
		case 0:
		{
			if (g_Player[id][Base][Reload] >= 333)
			{
				g_Player[id][Base][Reload] -= 333
				fm_set_user_godmode(id, 1)
				fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
				set_task(2.0, "remove_godmode", id)
				set_entity_visibility(id, 0)
				g_Player[id][Base][Hide] = 1
				set_task(10.0, "remove_hide", id)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用隱身", name)
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 1:
		{
			if (g_Player[id][Base][Reload] >= 333 && !g_gboost[id])
			{
				g_gboost[id] = 1
				g_Player[id][Base][Reload] -= 333
				set_user_maxspeed(id, 420.0)
				fm_set_rendering(id, kRenderFxGlowShell, 0, 255, 0, kRenderNormal, 25)
				set_task(10.0, "remove_boost", id)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用加速", name)
				PlaySound(0, "legend/Zombie_GBoost.wav")
			}
			else
			{
				if (g_gboost[id])
				{
					set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
					show_dhudmessage(id, "技能使用中")
				}
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 2:
		{
			if (g_Player[id][Base][Reload] >= 555)
			{
				g_Player[id][Base][Reload] -= 555
				fm_set_user_godmode(id, 1)
				fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用無敵", name)
				set_task(10.0, "remove_godmode", id)
				PlaySound(0, "legend/Zombie_GBoost.wav")
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 3:
		{
			if (g_Player[id][Base][Reload] >= 555)
			{
				g_Player[id][Base][Reload] -= 555
				fm_set_user_godmode(id, 1)
				fm_set_rendering(id, kRenderFxGlowShell, 255, 0, 0, kRenderNormal, 25)
				set_task(2.0, "remove_godmode", id)
				new Float:velocity[3]
				entity_get_vector(id, EV_VEC_velocity, velocity)
				velocity[2] = 5000.0
				entity_set_vector(id, EV_VEC_velocity, velocity)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用超級高跳", name)
				PlaySound(0, g_hunterlj[random_num(0, 1)])
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
		case 4:
		{
			if (g_Player[id][Base][Reload] >= 888)
			{
				g_Player[id][Base][Reload] -= 888
				boss_skill(id, 500.0, 500, 3)
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(0, "魔王 %s 使用範圍內的人彈走", name)
			}
			else
			{
				set_dhudmessage(200, 250, 0, -1.0, 0.17, 0, 2.0, 2.0, 1.0, 0.2)
				show_dhudmessage(id, "Reload 中")
			}
		}
	}
	return PLUGIN_HANDLED
}

public boss_skill(id, Float:dist, dist2, type)
{
	new origin[3]
	get_user_origin(id, origin)
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_BEAMCYLINDER)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2])
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(dist2 + origin[2])
	write_short(g_bossSpr)
	write_byte(0)
	write_byte(1)
	write_byte(10)
	write_byte(20)
	write_byte(0)
	write_byte(188)
	write_byte(220)
	write_byte(255)
	write_byte(255)
	write_byte(0)
	message_end()

	message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_BEAMCYLINDER)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2])
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(dist2 + origin[2] - 100)
	write_short(g_bossSpr)
	write_byte(0)
	write_byte(1)
	write_byte(10)
	write_byte(20)
	write_byte(0)
	write_byte(188)
	write_byte(220)
	write_byte(255)
	write_byte(255)
	write_byte(0)
	message_end()
	
	message_begin(MSG_PVS, SVC_TEMPENTITY, origin)
	write_byte(TE_BEAMCYLINDER)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2])
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(dist2 + origin[2] - 200)
	write_short(g_bossSpr)
	write_byte(0)
	write_byte(1)
	write_byte(10)
	write_byte(20)
	write_byte(0)
	write_byte(188)
	write_byte(220)
	write_byte(255)
	write_byte(255)
	write_byte(0)
	message_end()
	use_skill(id, dist, type)
}

public use_skill(id, Float:dist, type)
{
	new Float:origin[3] = 0.0, Float:aorigin[3] = 0.0
	entity_get_vector(id, EV_VEC_origin, aorigin)
	
	for (new i = 1;i <= g_maxplayers;i++)
	{
		if(is_user_alive(i) && !g_Player[i][Base][Boss])
		{
			entity_get_vector(i, EV_VEC_origin, origin)
			if (get_distance_f(origin, aorigin) < dist)
			{
				message_begin(MSG_ONE, get_user_msgid("ScreenFade"), _, i)
				write_short(1<<12)
				write_short(0)
				write_short(0)
				write_byte(255)
				write_byte(255)
				write_byte(255)
				write_byte(255)
				message_end()
				if (type == 1)
				{
					g_setspeed[i] = 1
					g_Player[i][Base][Status] = 6
					if (g_random == 2)
					{
						set_task(5.0, "reset_setspeed", i)
					}
					set_task(10.0, "reset_setspeed", i)
				}
				if (type == 2)
				{
					g_Player[i][Base][Virus] = 1
					if (!task_exists(i + TASK_VIRUS))
					{
						set_task(1.0, "virus_hurt", i + TASK_VIRUS)
					}
					g_Player[i][Base][Status] = 7
				}
				if (type == 3)
				{
					user_slap(i, 0, 1)
					user_slap(i, 0, 1)
					user_slap(i, 0, 1)
					user_slap(i, 0, 1)
					user_slap(i, 0, 1)
				}
				screen_shake(i, 4, 2, 10)
				fm_set_rendering(i, kRenderFxGlowShell, 255, 255, 255, kRenderNormal, 25)
				if (g_random == 2)
				{
					set_task(5.0, "remove_rendering", i)
				}
				set_task(10.0, "remove_rendering", i)
			}
		}
	}
}

public virus_hurt(taskid)
{
	new ID_VIRUS = taskid - TASK_VIRUS
	if (!is_user_alive(ID_VIRUS) || !g_Player[ID_VIRUS][Base][Virus] || timer[ID_VIRUS] > 9)
	{
		remove_function(ID_VIRUS)
		g_Player[ID_VIRUS][Base][Virus] = 0
		timer[ID_VIRUS] = 0
		remove_rendering(ID_VIRUS)
		remove_task(ID_VIRUS + TASK_VIRUS)
		return PLUGIN_HANDLED
	}
	fm_set_rendering(ID_VIRUS, kRenderFxGlowShell, 255, 0, 255, kRenderNormal, 25)
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenFade"), _, ID_VIRUS)
	write_short(1<<12)
	write_short(0)
	write_short(0)
	write_byte(255)
	write_byte(150)
	write_byte(250)
	write_byte(70)
	message_end()

	fm_set_user_health(ID_VIRUS, max(1, floatround((entity_get_float(ID_VIRUS, EV_FL_health) - (1.0 - (job_skill[ID_VIRUS][2] * 0.1)) * 10))))

	/*中毒音效
	static sound[64]
	if (!(random_num(1, 3) == 1))
	{
		if (random_num(1, 3) == 2)
		{
		}
	}
	emit_sound(ID_VIRUS, CHAN_VOICE, sound, 1.0, ATTN_NORM, 0, 100)
	*/

	if (g_random == 2) timer[ID_VIRUS] += 2
	else timer[ID_VIRUS] ++

	set_task(1.0, "virus_hurt", ID_VIRUS + TASK_VIRUS)
	return PLUGIN_CONTINUE
}

screen_shake(id, amplitude, duration, frequency)
{
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenShake"), _, id)
	write_short(amplitude * (1<<12))
	write_short(duration * (1<<12))
	write_short(frequency * (1<<12))
	message_end()
}

public remove_rendering(id)
{
	fm_set_rendering(id, kRenderFxNone, 255, 255, 255, kRenderNormal, 16)
}

public remove_skill(id)
{
	remove_rendering(id)
	g_critical_knife[id] = 0
	g_headshoot[id] = 0
	g_headshot[id] = 0
	remove_function(id)
}

public remove_boost(id)
{
	g_gboost[id] = 0
	set_user_maxspeed(id, 320.0)
	remove_rendering(id)
}

public remove_hide(id)
{
	g_Player[id][Base][Hide] = 0
	set_entity_visibility(id, 1)
	remove_function(id)
}

public remove_godmode(id)
{
	fm_set_user_godmode(id, 0)
	remove_rendering(id)
}

public remove_function(id)
{
	new hp = get_user_health(id)
	if (g_headshoot[id]) g_Player[id][Base][Status] = 8
	else if (g_critical_knife[id]) g_Player[id][Base][Status] = 9
	else if (g_headshot[id]) g_Player[id][Base][Status] = 10
	else if (g_Player[id][Base][Hide]) g_Player[id][Base][Status] = 11
	else
	{
		if (hp == 200) g_Player[id][Base][Status] = 0
		else
		{
			if (hp > 149) g_Player[id][Base][Status] = 1
			else if (hp > 99) g_Player[id][Base][Status] = 2
			else if (hp > 49) g_Player[id][Base][Status] = 3
			else if (hp > 10) g_Player[id][Base][Status] = 4
			else g_Player[id][Base][Status] = 5
		}
	}
}

public reset_setspeed(id)
{
	remove_function(id)
	g_setspeed[id] = 0
}

// Get User Team
stock fm_cs_get_user_team(id)
{
	// Prevent server crash if entity's private data not initalized
	if (pev_valid(id) != PDATA_SAFE)
		return FM_CS_TEAM_UNASSIGNED;
	
	return get_pdata_int(id, OFFSET_CSTEAMS);
}

// Set a Player's Team
stock fm_cs_set_user_team(id, team)
{
	// Prevent server crash if entity's private data not initalized
	if (pev_valid(id) != PDATA_SAFE)
		return;
	
	set_pdata_int(id, OFFSET_CSTEAMS, team)
}

// Update Player's Team on all clients (adding needed delays)
stock fm_user_team_update(id)
{
	static Float:current_time
	current_time = get_gametime()
	
	if (current_time - g_teams_targettime >= 0.1)
	{
		server_print("msg 1")
		set_task(0.1, "fm_cs_set_user_team_msg", id+TASK_TEAM)
		g_teams_targettime = current_time + 0.1
	}
	else
	{
		server_print("msg 2")
		set_task((g_teams_targettime + 0.1) - current_time, "fm_cs_set_user_team_msg", id+TASK_TEAM)
		g_teams_targettime = g_teams_targettime + 0.1
	}
}

// Send User Team Message
public fm_cs_set_user_team_msg(taskid)
{
	// Note to self: this next message can now be received by other plugins
	
	// Set the switching team flag
	g_switchingteam = true
	
	// Tell everyone my new team
	emessage_begin(MSG_ALL, g_msgTeamInfo)
	ewrite_byte(ID_TEAM) // player
	ewrite_string(CS_TEAM_NAMES[fm_cs_get_user_team(ID_TEAM)]) // team
	emessage_end()
	
	// Done switching team
	g_switchingteam = false
}

/*
drop_weapons(id, dropwhat)
{
	static weapons[32], num, i, weaponid
	num = 0
	get_user_weapons(id, weapons, num)
	for (i = 0; i < num; i++)
	{
		weaponid = weapons[i]
		
		if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			static wname[32]
			get_weaponname(weaponid, wname, charsmax(wname))
			engclient_cmd(id, "drop", wname)
		}
	}
}
*/

add_exchange_item(id, item, num)
{
	new total_add_num, before_num, add_num = num;
	
	for (new bag_item;bag_item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];bag_item++)
	{
		if (num)
		{
			if ((g_Player[id][Bag][Index][bag_item] == item && g_Player[id][Bag][Index][bag_item]) || (g_Player[id][Bag][Amount][bag_item] < 5 && !g_Player[id][Bag][Index][bag_item]))
			{
				before_num = g_Player[id][Bag][Amount][bag_item]
				g_Player[id][Bag][Amount][bag_item] += num
				if (g_Player[id][Bag][Amount][bag_item] > 5) g_Player[id][Bag][Amount][bag_item] = 5
				total_add_num = g_Player[id][Bag][Amount][bag_item] - before_num
				num -= total_add_num
				g_Player[id][Bag][Index][bag_item] = item
			}
		}
	}
	new name[64]
	get_user_name(id, name, charsmax(name))
	if (!num) log_to_file(g_logfile, "名稱: %s 物品: %s x %d (ExChange Get Item)", name, g_BagItem[item][BAG_ITEMNAME], add_num)
	else log_to_file(g_logfile, "名稱: %s 物品: %s x %d (ExChange Lost Item)", name, g_BagItem[item][BAG_ITEMNAME], num)
}

add_bag_item(id, item, num, bool:enable_message, msg_type)
{
	new total_add_num, before_num, add_num = num, name[64]
	get_user_name(id, name, charsmax(name))
	for (new bag_item;bag_item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];bag_item++)
	{
		if (num)
		{
			if ((g_Player[id][Bag][Index][bag_item] == item && g_Player[id][Bag][Index][bag_item]) || (g_Player[id][Bag][Amount][bag_item] < 5 && !g_Player[id][Bag][Index][bag_item]))
			{
				before_num = g_Player[id][Bag][Amount][bag_item]
				g_Player[id][Bag][Amount][bag_item] += num
				if (g_Player[id][Bag][Amount][bag_item] > 5) g_Player[id][Bag][Amount][bag_item] = 5
				total_add_num = g_Player[id][Bag][Amount][bag_item] - before_num
				num -= total_add_num
				g_Player[id][Bag][Index][bag_item] = item
			}
		}
	}
	if (enable_message)
	{
		if (!num)
		{
			colored_print(0, "\x04[%s]\x03 %s 隨機獲得 \x04%s x %d", g_msgtype[msg_type], name, g_BagItem[item][BAG_ITEMNAME], add_num)
			log_to_file(g_logfile, "名稱: %s 物品: %s x %d (Get Item)", name, g_BagItem[item][BAG_ITEMNAME], add_num)
		}
		else
		{
			colored_print(0, "\x04[%s]\x03 %s 已經裝不下 \x04%s\x03 x %d 了", g_msgtype[msg_type], name, g_BagItem[item][BAG_ITEMNAME], num)
		}
	}
}

public add_bag_item2(id, item, num)
{
	new total_add_num, before_num
	for (new bag_item;bag_item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];bag_item++)
	{
		if (num)
		{
			if ((g_Player[id][Bag][Index][bag_item] == item && g_Player[id][Bag][Index][bag_item]) || (g_Player[id][Bag][Amount][bag_item] < 5 && !g_Player[id][Bag][Index][bag_item]))
			{
				before_num = g_Player[id][Bag][Amount][bag_item]
				g_Player[id][Bag][Amount][bag_item] += num
				if (g_Player[id][Bag][Amount][bag_item] > 5) g_Player[id][Bag][Amount][bag_item] = 5
				total_add_num = g_Player[id][Bag][Amount][bag_item] - before_num
				num -= total_add_num
				g_Player[id][Bag][Index][bag_item] = item
			}
		}
	}
}

public del_reset_bag_item2(id, item, num)
{
	for (new bag_item;bag_item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];bag_item++)
	{
		if (num)
		{
			if (item == g_Player[id][Bag][Index][bag_item])
			{
				if (g_Player[id][Bag][Amount][bag_item] < 2)
				{
					g_Player[id][Bag][Index][bag_item] = 0
					g_Player[id][Bag][Amount][bag_item] = 0
					num--
				}
				else
				{
					new check = g_Player[id][Bag][Amount][bag_item]
					if (check > num) check = num
					num -= check
					g_Player[id][Bag][Amount][bag_item] -= check
					if (!g_Player[id][Bag][Amount][bag_item]) g_Player[id][Bag][Index][bag_item] = 0
				}
			}
		}
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}

public check_bag_item(id, item, num)
{
	if (num > 5) return false
	new check
	for (new bag_item;bag_item < DEFAULT_BAG_SPACE + g_Player[id][Bag][Increase];bag_item++)	//遍历背包
	{
		if (item == g_Player[id][Bag][Index][bag_item])
		{
			check = g_Player[id][Bag][Amount][bag_item]
			if (num >= check)
			{
				return true
			}
		}
	}
	return false
}

public replace_weapon_models(id)
{
	if(is_user_alive(id) && is_user_connected(id) && g_Player[id][Base][Boss])
	{
		entity_set_string(id, EV_SZ_viewmodel, v_bossknife[g_random])
		entity_set_string(id, EV_SZ_weaponmodel, "")
	}
}

// Get Alive -returns alive players number-
fnGetAlive()
{
	static iAlive, id
	iAlive = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (is_user_alive(id))
			iAlive++
	}
	
	return iAlive;
}

// Get Random Alive -returns index of alive player number n -
fnGetRandomAlive(n)
{
	static iAlive, id
	iAlive = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (is_user_alive(id))
			iAlive++
		
		if (iAlive == n)
			return id;
	}
	
	return -1;
}

// Get CTs -returns number of CTs connected-
fnGetCTs()
{
	static iCTs, id
	iCTs = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (is_user_connected(id))
		{			
			if (fm_cs_get_user_team(id) == FM_CS_TEAM_CT && !g_Player[id][Base][Boss])
				iCTs++
		}
	}
	
	return iCTs;
}

// Get Ts -returns number of Ts connected-
fnGetBosses()
{
	static iTs, id
	iTs = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (is_user_connected(id))
		{			
			if (g_Player[id][Base][Boss])
				iTs++
		}
	}
	
	return iTs;
}

// Get Alive CTs -returns number of CTs alive-
fnGetAliveHumans()
{
	static iCTs, id
	iCTs = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (is_user_alive(id) && !g_Player[id][Base][Boss])
		{
			iCTs++
		}
	}
	
	return iCTs;
}

// Get Alive Ts -returns number of Ts alive-
fnGetAliveBosses()
{
	static iTs, id
	iTs = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (is_user_alive(id))
		{			
			if (g_Player[id][Base][Boss])
				iTs++
		}
	}
	
	return iTs;
}

// Get Playing -returns number of users playing-
fnGetPlaying()
{
	static iPlaying, id, team
	iPlaying = 0
	
	for (id = 1; id <= g_maxplayers; id++)
	{
		if (is_user_connected(id))
		{
			team = fm_cs_get_user_team(id)
			
			if (team != FM_CS_TEAM_SPECTATOR && team != FM_CS_TEAM_UNASSIGNED)
				iPlaying++
		}
	}
	
	return iPlaying;
}

public native_get_user_boss(id)
{
	return g_Player[id][Base][Boss]
}

public native_set_user_gash(id, amount)
{
	g_Player[id][Base][Gash] = amount
}

public native_get_user_gash(id, amount)
{
	return g_Player[id][Base][Gash]
}

public native_get_user_hide(id)
{
	return g_Player[id][Base][Hide]
}

public native_get_mode()
{
	return g_mode
}

public native_get_user_level(id)
{
	return g_Player[id][Base][Level]
}

public native_set_user_level(id, amount)
{
	g_Player[id][Base][Level] = amount
}

public native_get_user_sp(id)
{
	return g_Player[id][Base][SP]
}

public native_set_user_sp(id, amount)
{
	g_Player[id][Base][SP] = amount
}

public native_get_user_xp(id)
{
	return g_Player[id][Base][XP]
}

public native_set_user_xp(id, amount)
{
	g_Player[id][Base][XP] = amount
}

public native_add_item(id, itemid, amount)
{
	add_bag_item(id, itemid, amount, true, 2)
}

public native_add_item2(id, itemid, amount)
{
	add_exchange_item(id, itemid, amount)
}

public native_set_user_weaponid(id, amount)
{
	g_Player[id][Base][Weapon] = amount
}

public native_register_weapon(iPlugin, iParams)
{
	g_WeaponCount++
	get_string(1, WeaponName[g_WeaponCount], charsmax(WeaponName[]))
	get_string(2, WeaponSaveName[g_WeaponCount], charsmax(WeaponSaveName[]))
	WeaponType[g_WeaponCount] = get_param(3)
	WeaponCostSP[g_WeaponCount] = get_param(4)
	WeaponCostGash[g_WeaponCount] = get_param(5)
	WeaponLevel[g_WeaponCount] = get_param(6)
	WeaponBasedOn[g_WeaponCount] = get_param(7)
	get_string(8, WeaponCommit[g_WeaponCount], charsmax(WeaponCommit[]))
	return g_WeaponCount
}

public native_get_boss_blood_color()
{
	return BOSS_BLOOD_COLOR
}

stock __dhud_color;
stock __dhud_x;
stock __dhud_y;
stock __dhud_effect;
stock __dhud_fxtime;
stock __dhud_holdtime;
stock __dhud_fadeintime;
stock __dhud_fadeouttime;
stock __dhud_reliable;

stock set_dhudmessage( red = 0, green = 160, blue = 0, Float:x = -1.0, Float:y = 0.65, effects = 2, Float:fxtime = 6.0, Float:holdtime = 3.0, Float:fadeintime = 0.1, Float:fadeouttime = 1.5, bool:reliable = false )
{
    #define clamp_byte(%1)       ( clamp( %1, 0, 255 ) )
    #define pack_color(%1,%2,%3) ( %3 + ( %2 << 8 ) + ( %1 << 16 ) )

    __dhud_color       = pack_color( clamp_byte( red ), clamp_byte( green ), clamp_byte( blue ) );
    __dhud_x           = _:x;
    __dhud_y           = _:y;
    __dhud_effect      = effects;
    __dhud_fxtime      = _:fxtime;
    __dhud_holdtime    = _:holdtime;
    __dhud_fadeintime  = _:fadeintime;
    __dhud_fadeouttime = _:fadeouttime;
    __dhud_reliable    = _:reliable;

    return PLUGIN_HANDLED
}

stock show_dhudmessage( index, const message[], any:... )
{
    new buffer[ 128 ];
    new numArguments = numargs();

    if( numArguments == 2 )
    {
        send_dhudMessage( index, message );
    }
    else if( index || numArguments == 3 )
    {
        vformat( buffer, charsmax( buffer ), message, 3 );
        send_dhudMessage( index, buffer );
    }
    else
    {
        new playersList[ 32 ], numPlayers;
        get_players( playersList, numPlayers, "ch" );

        if( !numPlayers )
        {
            return 0;
        }

        new Array:handleArrayML = ArrayCreate();

        for( new i = 2, j; i < numArguments; i++ )
        {
            if( getarg( i ) == LANG_PLAYER )
            {
                while( ( buffer[ j ] = getarg( i + 1, j++ ) ) ) {}
                j = 0;

                if( GetLangTransKey( buffer ) != TransKey_Bad )
                {
                    ArrayPushCell( handleArrayML, i++ );
                }
            }
        }

        new size = ArraySize( handleArrayML );

        if( !size )
        {
            vformat( buffer, charsmax( buffer ), message, 3 );
            send_dhudMessage( index, buffer );
        }
        else
        {
            for( new i = 0, j; i < numPlayers; i++ )
            {
                index = playersList[ i ];

                for( j = 0; j < size; j++ )
                {
                    setarg( ArrayGetCell( handleArrayML, j ), 0, index );
                }

                vformat( buffer, charsmax( buffer ), message, 3 );
                send_dhudMessage( index, buffer );
            }
        }

        ArrayDestroy( handleArrayML );
    }

    return PLUGIN_HANDLED
}

stock send_dhudMessage( const index, const message[] )
{
    message_begin( __dhud_reliable ? ( index ? MSG_ONE : MSG_ALL ) : ( index ? MSG_ONE_UNRELIABLE : MSG_BROADCAST ), SVC_DIRECTOR, _, index );
    {
        write_byte( strlen( message ) + 31 );
        write_byte( DRC_CMD_MESSAGE );
        write_byte( __dhud_effect );
        write_long( __dhud_color );
        write_long( __dhud_x );
        write_long( __dhud_y );
        write_long( __dhud_fadeintime );
        write_long( __dhud_fadeouttime );
        write_long( __dhud_holdtime );
        write_long( __dhud_fxtime );
        write_string( message );
    }
    message_end();
} 