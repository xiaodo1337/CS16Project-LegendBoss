#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <sqlx>

#pragma tabsize 4

const MAX_STATS_SAVED = 64

// MySQL库数据连接信息
new Host[]     = "localhost"
new User[]    = "root"
new Pass[]     = "123456"
new Db[]     = "test"

new Handle:g_SqlTuple
new g_Error[512]
new g_fwLogined, g_fwDummyResult;
new typedpass[32];
new bool:g_logined[33], bool:g_registered[33], bool:g_registering[33], g_wrongtimes[33], g_kicktimes[33], g_flags[33][32];
new g_screenfade;
new g_countdown[33];
new g_userpassword[33][64], g_user_banned[33], g_user_ban_timeout[33][16];

// Temporary Database vars (used to restore players stats in case they get disconnected)
new g_playername[33][64] // player's name
new db_name[MAX_STATS_SAVED][64] // player name
new db_kicktimes[MAX_STATS_SAVED] // ammo pack count
new db_slot_i // additional saved slots counter (should start on maxplayers+1)

public plugin_init()
{
	register_plugin("Account System", "1.0", "xiaodo");
	register_message(get_user_msgid("ShowMenu"), "message_show_menu");
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu");
	register_clcmd("say", "RegisterLogin")
	g_screenfade = get_user_msgid("ScreenFade")
	register_forward(FM_ClientUserInfoChanged, "ClientInfoChanged")
	g_fwLogined = CreateMultiForward("ac_user_logined", ET_IGNORE, FP_CELL)
	Init_Mysql();
}

public Init_Mysql()
{
	g_SqlTuple = SQL_MakeDbTuple(Host,User,Pass,Db)
   
    // 连接数据库
	new ErrorCode, Handle:SQLConnection = SQL_Connect(g_SqlTuple, ErrorCode, g_Error, charsmax(g_Error))
	if(SQLConnection == Empty_Handle)
		set_fail_state(g_Error) // 停止插件并报错
       
	new Handle:Queries
    // 现在必须准备查询
    new szTemp[512]
	format(szTemp, charsmax(szTemp), "CREATE TABLE IF NOT EXISTS `bm_register_system` ( ")
	strcat(szTemp, "`id` int(10) NOT NULL AUTO_INCREMENT, ", charsmax(szTemp))
	strcat(szTemp, "`username` varchar(32) NOT NULL DEFAULT '', ", charsmax(szTemp))
	strcat(szTemp, "`password` varchar(64) NOT NULL DEFAULT '', ", charsmax(szTemp))
	strcat(szTemp, "`banned` int(4) unsigned NOT NULL DEFAULT '0', ", charsmax(szTemp))
	strcat(szTemp, "`ban_timeout` char(16) NOT NULL DEFAULT '0', ", charsmax(szTemp))
	strcat(szTemp, "PRIMARY KEY (`id`) ) ENGINE=MyISAM AUTO_INCREMENT=1 CHARACTER SET = utf8 COLLATE = utf8_general_ci;", charsmax(szTemp))
	Queries = SQL_PrepareQuery(SQLConnection, szTemp)

	if(!SQL_Execute(Queries))
    {
        SQL_QueryError(Queries,g_Error,charsmax(g_Error))
        set_fail_state(g_Error)
    }
    
	SQL_FreeHandle(Queries)
	SQL_FreeHandle(SQLConnection)   
}

public Load_MySql(id)
{
	if(g_SqlTuple == Empty_Handle)
	{
		set_task(0.5, "Load_MySql", id)
	}
	else
	{
    	new szName[64], szTemp[512], Data[1]
    	get_user_name(id, szName, charsmax(szName))
    	Data[0] = id
    	format(szTemp,charsmax(szTemp),"SELECT `password`, `banned`, `ban_timeout` FROM bm_register_system WHERE username='%s';", szName)
    	SQL_ThreadQuery(g_SqlTuple, "register_client", szTemp, Data, sizeof(Data))
	}
}

public register_client(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
    if(FailState == TQUERY_QUERY_FAILED)
    {
        log_amx("Query Failed due to Query Command.  [%d] %s", Errcode, Error)
    	return PLUGIN_HANDLED
    }
    if(FailState == TQUERY_CONNECT_FAILED)
    {
        log_amx("Could not connect to SQL database.  [%d] %s", Errcode, Error)
    	return PLUGIN_HANDLED
    }

    new id
    id = Data[0]
    
    if(SQL_NumResults(Query) > 0)
    {
        // 如果有结果
		g_registered[id] = true
        SQL_ReadResult(Query, 0, g_userpassword[id], charsmax(g_userpassword[]))
        g_user_banned[id] = SQL_ReadResult(Query, 1)
        SQL_ReadResult(Query, 2, g_user_ban_timeout[id], charsmax(g_user_ban_timeout[]))
    }
	check_user(id)
	return PLUGIN_CONTINUE
}

public message_show_menu(msgid, dest, id)
{
	if (!g_logined[id])
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

public message_vgui_menu(msgid, dest, id)
{
	if (!g_logined[id])
		return PLUGIN_HANDLED;
	return PLUGIN_CONTINUE;
}

public client_putinserver(id)
{
	new szAuthID[64]
	remove_task(id)
	set_status(id)
	get_user_authid(id, szAuthID, charsmax(szAuthID))
	get_user_name(id, g_playername[id], charsmax(g_playername[]))
	get_flags(get_user_flags(id), g_flags[id], charsmax(g_flags[]))
	remove_user_flags(id, read_flags(g_flags[id])) //禁用用户权限
	set_user_flags(id, read_flags("z"))
	load_stats(id)
	if(g_kicktimes[id] >= 3)
	{
		g_kicktimes[id] = 0
		save_stats(id)
		client_cmd(id, "clear")
		server_cmd("kick #%d ^"您在短时间内尝试了过多次密码！请等5分钟后再试！^";wait;banid 5 %s;wait;writeid", get_user_userid(id), szAuthID)
		return PLUGIN_CONTINUE;
	}
	Load_MySql(id)
	return PLUGIN_CONTINUE;
}

public check_user(id)
{
	if(!g_logined[id])
	{
		if(g_registered[id])
		{
			g_countdown[id] = 30;
		}
		else
		{
			g_countdown[id] = 60;
		}
		g_logined[id] = false;
		g_wrongtimes[id] = 0;
		set_task(1.0, "client_cue", id, _, _, "b");
	}
}

public client_disconnect(id)
{
	remove_task(id)
	set_status(id)
}

public set_status(id)
{
	g_registered[id] = false
	g_logined[id] = false
	g_wrongtimes[id] = 0
	g_countdown[id] = 30
	g_kicktimes[id] = 0
	g_user_banned[id] = 0
	format(g_user_ban_timeout[id], charsmax(g_user_ban_timeout[]), "")
}

public show_confim_pwd_menu(id, const pwd[])
{
	new buffer[256]
	format(buffer, charsmax(buffer), "你確定要 %s 作為你以後的登入密碼嗎？", pwd)
	new menu = menu_create(buffer, "confim_pwd_menu")
	menu_additem(menu, "\r確定，我要使用這個註冊密碼", pwd)
	menu_additem(menu, "\r否，我再考慮一下", "")
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER)
	menu_display(id, menu, 0)
	return PLUGIN_HANDLED;
}

public confim_pwd_menu(id, menu, item)
{
    if(item == MENU_EXIT)
    {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

	new buffer[128], data[2], command[32], name[32], uname[32], access, callback;
	menu_item_getinfo(menu, item, access, command, charsmax(command), name, charsmax(name), callback);
	get_user_name(id, uname, charsmax(uname))

    if(g_logined[id] || g_registered[id])
    {
		menu_destroy(menu);
   		return PLUGIN_HANDLED;
   	}

	if(item == 0)
	{
		if(!g_registering[id])
		{
			g_registering[id] = true
			data[0] = id
			format(buffer, charsmax(buffer), "INSERT INTO `bm_register_system` (`username` , `password`) VALUES ('%s', '%s');", uname, command)
			SQL_ThreadQuery(g_SqlTuple, "user_register", buffer, data, sizeof(data))
			colored_print(id, "\x04[注冊系統] \x03賬號正在注冊中，您的密碼：\x04%s", command)
			colored_print(id, "\x04[注冊系統] \x03賬號正在注冊中，您的密碼：\x04%s", command)
			colored_print(id, "\x04[注冊系統] \x03賬號正在注冊中，您的密碼：\x04%s", command)
		}
		else
		{
			colored_print(id, "\x04[注冊系統] \x03賬號注冊中，请不要反復注冊！")
		}
	}

    menu_destroy(menu);
    return PLUGIN_HANDLED;
}

public user_register(FailState,Handle:Query,Error[],Errcode,Data[],DataSize)
{
    new id
    id = Data[0]
	g_registering[id] = false
    if(FailState == TQUERY_QUERY_FAILED)
    {
		g_logined[id] = false
		g_registered[id] = false
        log_amx("Query Failed due to Query Command.  [%d] %s", Errcode, Error)
    	return PLUGIN_HANDLED
    }
    if(FailState == TQUERY_CONNECT_FAILED)
    {
		g_logined[id] = false
		g_registered[id] = false
        log_amx("Could not connect to SQL database.  [%d] %s", Errcode, Error)
    	return PLUGIN_HANDLED
    }
	
	g_logined[id] = true
	g_registered[id] = true
	colored_print(id, "\x04[註冊系統] \x03賬號註冊成功！")
	return PLUGIN_CONTINUE
}

public client_cue(id)
{
	if (g_logined[id])
	{
		remove_task(id);
		g_kicktimes[id] = 0
		save_stats(id)
		if(!(read_flags(g_flags[id]) & ADMIN_USER)) remove_user_flags(id, ADMIN_USER)
		set_user_flags(id, read_flags(g_flags[id]))
		menu_cancel(id);
		ExecuteForward(g_fwLogined, g_fwDummyResult, id)
	}
	else
	{
		message_begin(MSG_ONE_UNRELIABLE, g_screenfade, {0,0,0}, id)
		write_short(1<<12)
		write_short(1<<12)
		write_short(0x0000)
		write_byte(0)
		write_byte(0)
		write_byte(0)
		write_byte(255)
		message_end()
		static buffer[192]
		if (g_countdown[id] <= 0 && !is_user_bot(id))
		{
			g_kicktimes[id]++
			save_stats(id)
			client_cmd(id, "clear")
			server_cmd("kick #%i ^"逾時登入或註冊^"", get_user_userid(id))
			remove_task(id)
		}
		if(g_countdown[id] >= 20) set_hudmessage(10, 255, 10, -1.0, -1.0, 0, 1.0, 1.1, 0.1, 0.2, -1);
		else if(g_countdown[id] <= 10) set_hudmessage(255, 10, 10, -1.0, -1.0, 0, 1.0, 1.1, 0.1, 0.2, -1);
		else set_hudmessage(255, 255, 10, -1.0, -1.0, 0, 1.0, 1.1, 0.1, 0.2, -1);
		if(g_registered[id])
			format(buffer, charsmax(buffer), "[登入系統]^n請按 Y 鍵輸入密碼，並在 %i 秒內輸入密碼^n否則會被踢出", g_countdown[id])
		else
			format(buffer, charsmax(buffer), "[註冊系統]^n請按 Y 鍵輸入密碼，並在 %i 秒內輸入密碼^n否則會被踢出", g_countdown[id])
		show_hudmessage(id, "%s", buffer);
		g_countdown[id]--;
	}
	return 0;
}

public RegisterLogin(id)
{
	if(g_SqlTuple == Empty_Handle)
	{
		colored_print(id, "\x04[登入系統] \x03查询尚未完成，请稍等片刻！")
		return PLUGIN_CONTINUE;
	}
	if(g_countdown[id] <= 0 || g_logined[id])
		return PLUGIN_CONTINUE;
	read_args(typedpass, charsmax(typedpass))
	remove_quotes(typedpass)
	if(g_registered[id])
	{
		if(!equal(typedpass, g_userpassword[id]))
		{
			colored_print(id, "\x04[登入系統] \x03密碼錯誤！")
			if(g_wrongtimes[id] < 2)
			{
				g_wrongtimes[id]++
			}
			else
			{
				g_kicktimes[id]++
				save_stats(id)
				client_cmd(id, "clear")
				server_cmd("kick #%i ^"密碼錯誤次數過多^"", get_user_userid(id))
			}
		}
		else
		{
			g_logined[id] = true
			colored_print(id, "\x04[登入系統] \x03密碼正確，登入成功！")
			colored_print(id, "\x04[登入系統] \x03密碼正確，登入成功！")
			colored_print(id, "\x04[登入系統] \x03密碼正確，登入成功！")
			colored_print(id, "\x04[登入系統] \x03密碼正確，登入成功！")
			if(g_user_banned[id] > 0 && str_to_num(g_user_ban_timeout[id]) > get_systime())
			{
				client_cmd(id, "clear")
				server_cmd("kick #%i ^"您已被服务器封禁，剩余解封时间：%s^"", get_user_userid(id), timestamp_to_date(str_to_num(g_user_ban_timeout[id]) - get_systime()))
			}
		}
	}
	else
	{
		if(strlen(typedpass) < 6)
		{
			colored_print(id, "\x04[账号系统] \x03密码需要大于等于6位")
			return PLUGIN_HANDLED;
		}
		if(strlen(typedpass) > 30)
		{
			colored_print(id, "\x04[账号系统] \x03密码需要小于等于30位")
			return PLUGIN_HANDLED;
		}
		show_confim_pwd_menu(id, typedpass)
	}
	return PLUGIN_HANDLED;
}

public ClientInfoChanged(id) 
{
	if(!is_user_connected(id))
		return FMRES_IGNORED
	
	new oldname[64], newname[64];
		
	get_user_name(id, oldname, charsmax(oldname))
	get_user_info(id, "name", newname, charsmax(newname))

	if(!equal(oldname, newname))
	{
		replace_all(newname, charsmax(newname), "%", " ")
		set_user_info(id, "name", oldname)
		colored_print(id, "\x04[账号系統] \x03重新进入服务器来应用新更改的名字！")
		colored_print(id, "\x04[账号系統] \x03重新进入服务器来应用新更改的名字！")
		colored_print(id, "\x04[账号系統] \x03重新进入服务器来应用新更改的名字！")
		colored_print(id, "\x04[账号系統] \x03重新进入服务器来应用新更改的名字！")
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public plugin_natives()
{
	register_native("ac_get_user_logined", "native_logined", 1)
	register_native("ac_get_user_registered", "native_registered", 1)
}

public native_logined(id) return g_logined[id];
public native_registered(id) return g_registered[id];

public plugin_end()
{
    SQL_FreeHandle(g_SqlTuple)
}

public IgnoreHandle(FailState, Handle:Query, Error[], ErrorCode, Data[], DataSize)
{
	SQL_FreeHandle(Query)
	return PLUGIN_HANDLED
}

save_stats(id)
{
	// Check whether there is another record already in that slot
	if (db_name[id][0] && !equal(g_playername[id], db_name[id]))
	{
		// If DB size is exceeded, write over old records
		if (db_slot_i >= sizeof db_name)
			db_slot_i = get_maxplayers()+1
		
		// Move previous record onto an additional save slot
		copy(db_name[db_slot_i], charsmax(db_name[]), db_name[id])
		db_kicktimes[db_slot_i] = db_kicktimes[id]
		db_slot_i++
	}
	
	// Now save the current player stats
	copy(db_name[id], charsmax(db_name[]), g_playername[id]) // name
	db_kicktimes[id] = g_kicktimes[id]  // ammo packs
}

// Load player's stats from database (if a record is found)
load_stats(id)
{
	// Look for a matching record
	static i
	for (i = 0; i < sizeof db_name; i++)
	{
		if (equal(g_playername[id], db_name[i]))
		{
			// Bingo!
			g_kicktimes[id] = db_kicktimes[i]
			return;
		}
	}
}

public timestamp_to_date(ts)
{
    new d, h, m;
    d += ts / (24 * 60 * 60)
    ts = ts % (24 * 60 * 60)
    h += ts / (60 * 60)
    ts = ts % (60 * 60)
    m = ts / 60
    ts = ts % 60

	new text[128]
	if(d > 0) format(text, charsmax(text), "%d天 ", d)
	if(h > 0) format(text, charsmax(text), "%d时 ", h)
	if(m > 0) format(text, charsmax(text), "%d分 ", m)
	if(ts > 0) format(text, charsmax(text), "%d秒", ts)
	return text
}

stock colored_print(const id, const input[], any:...)
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