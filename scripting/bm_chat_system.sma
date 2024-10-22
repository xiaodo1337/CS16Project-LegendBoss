#include <amxmodx>
#include <amxmisc>
#include <fvault>
#include <account_system>

#pragma tabsize 4

#define CHARS_MAX 32
#define CHARS_MIN 1

new iPlayerTag[64], iMessages[64], iUserName[32], tUserTeam[16]

public plugin_init()
{
	register_plugin("說話系統", "1.0", "xiaodo")
	register_clcmd("say", "cmdHookSay")
	register_clcmd("say_team", "cmdHookSayTeam")
}

public cmdHookSay(id)
{
	read_args(iMessages, charsmax(iMessages));
	remove_quotes(iMessages);
	get_user_name(id, iUserName, charsmax(iUserName));
	if (!strlen(iMessages))
	    return PLUGIN_HANDLED;
	new name[32];
	get_user_name(id, name, charsmax(name));
	if (get_user_flags(id) & ADMIN_IMMUNITY)
	{
		format(iPlayerTag, charsmax(iPlayerTag), "伺服器最高領導人")
	}
	else if(get_user_flags(id) & ADMIN_KICK)
	{
		format(iPlayerTag, charsmax(iPlayerTag), "VIP")
	}
	else if(get_user_flags(id) & ADMIN_RESERVATION)
	{
		format(iPlayerTag, charsmax(iPlayerTag), "高玩")
	}
	else
	{
		format(iPlayerTag, charsmax(iPlayerTag), "伺服器玩家")
	}
	new szSignature[256], buffer[256];
	if (iMessages[0] == '/' && iMessages[1] == 'm' && iMessages[2] == 's' && iMessages[3] == 'g' && iMessages[4] == ' ')
	{
        replace(iMessages, 6, "/msg ", "")
		new iMsg = strlen(iMessages);
		if (iMsg < CHARS_MIN)
		{
			colored_print(id, "\x04[提示] \x03您所鍵入的個性簽名太短了。(下限: %d 個英文字或中文字)", CHARS_MIN);
		}
		else
		{
			if (iMsg > CHARS_MAX)
			{
				colored_print(id, "\x04[提示] \x03您所鍵入的個性簽名太長了。(上限: %d 個英文字或 %d 個中文字)", CHARS_MAX + -5, CHARS_MAX + -5 / 3);
			}
			colored_print(id, "\x04[提示] \x03您現在的個性簽名：^"%s^"。", iMessages);
			fvault_set_data("Chat_System", name, iMessages);
		}
		return PLUGIN_HANDLED;
	}
	if (iMessages[0] == '/' && iMessages[1] == 'f' && iMessages[2] == 'u' && iMessages[3] == 'n' && iMessages[4] == '_' && iMessages[5] == 'n' && iMessages[6] == 'a' && iMessages[7] == 'm' && iMessages[8] == 'e' && iMessages[9] == ' ')
	{
        replace(iMessages, 11, "/fun_name ", "")
		new iMsg = strlen(iMessages);
		if (iMsg < CHARS_MIN)
		{
			colored_print(id, "\x04[提示] \x03您所鍵入的個性簽名太短了。(下限: %d 個英文字或中文字)", CHARS_MIN);
		}
		else
		{
			if (iMsg > CHARS_MAX)
			{
				colored_print(id, "\x04[提示] \x03您所鍵入的個性簽名太長了。(上限: %d 個英文字或 %d 個中文字)", CHARS_MAX + -5, CHARS_MAX + -5 / 3);
			}
			colored_print(id, "\x04[提示] \x03您現在的個性簽名：^"%s^"。", iMessages);
			fvault_set_data("Chat_System", name, iMessages);
		}
		return PLUGIN_HANDLED;
	}

	if (equal(iMessages, "/delmsg"))
	{
		format(szSignature, charsmax(szSignature), "");
		fvault_set_data("Chat_System", name, szSignature);
		colored_print(id, "\x04[提示] \x03您現在的個性簽名已經刪除。");
		return PLUGIN_HANDLED;
	}
	if (!fvault_get_data("Chat_System", name, szSignature, charsmax(szSignature)))
	{
		format(szSignature, charsmax(szSignature), "");
	}
    format(buffer, charsmax(buffer), "%s", is_user_alive(id) ? "" : "*陣亡* ")
    format(buffer, charsmax(buffer), "%s\x04[%s] ", buffer, iPlayerTag)
    if(strlen(szSignature) > 0) format(buffer, charsmax(buffer), "%s\x04(%s) ", buffer, szSignature)
    format(buffer, charsmax(buffer), "%s\x03%s\x04 : %s", buffer, iUserName, iMessages)
    colored_print(0, "\x01%s", buffer)
    return PLUGIN_HANDLED;
}

public cmdHookSayTeam(id)
{
	read_args(iMessages, charsmax(iMessages));
	remove_quotes(iMessages);
	get_user_name(id, iUserName, charsmax(iUserName));
	if (!strlen(iMessages))
	    return PLUGIN_HANDLED;
	new name[32], buffer[256];
	get_user_name(id, name, charsmax(name));
    format(buffer, charsmax(buffer), "%s", is_user_alive(id) ? "" : "*陣亡* ")
    Get_UserTeamString(get_user_team(id))
    format(buffer, charsmax(buffer), "%s\x03%s%s\x01 : %s", buffer, tUserTeam, iUserName, iMessages)
    colored_print_team(id, "\x01%s", buffer)
    return PLUGIN_HANDLED;
}

public Get_UserTeamString(iUserTeam)
{
	switch (iUserTeam)
	{
		case 0:
		{
			copy(tUserTeam, 10, "( SPEC )");
		}
		case 1:
		{
			copy(tUserTeam, 10, "( TS )");
		}
		case 2:
		{
			copy(tUserTeam, 10, "( CT )");
		}
		case 3:
		{
			copy(tUserTeam, 10, "( SPEC )");
		}
	}
}

stock colored_print(const id, const input[], any:...)
{
    static count = 1, players[32]
    static msg[255], i
    vformat(msg, charsmax(msg), input, 3)
    
    replace_all(msg, charsmax(msg), "\x01", "^1")
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

stock colored_print_team(const id, const input[], any:...)
{
    static count = 1, players[32]
    static msg[255], i
    vformat(msg, charsmax(msg), input, 3)
    
    replace_all(msg, charsmax(msg), "\x01", "^1")
    replace_all(msg, charsmax(msg), "\x04", "^4")
    replace_all(msg, charsmax(msg), "\x03", "^3")
        
    get_players(players, count, "ch")
    for (i = 0; i < count; i++)
	{
        if (is_user_connected(players[i]) && get_user_team(players[i]) == get_user_team(id))
        {
            message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("SayText"), _, players[i])
            write_byte(players[i])
            write_string(msg)
            message_end()
        }
	}
}