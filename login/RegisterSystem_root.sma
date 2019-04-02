/*  AMX Mod X script
*                               ______                       __                    __          __                              ________
*		               / ____ \                      \ \                  / /         /  |                            |______  |
*		              / /    \ \                      \ \                / /         /   |                        __         | |
*		             | /      \ |                      \ \              / /         / /| |                       |__|        | |
*		             | |      | |    ______     _    __ \ \            / /  _      / / | |       ______                      | |
*    	 _   _____   _____   | |      | |   / ____ \   | |  / /  \ \          / /  |_|    / /  | |      / ____ \                     | |
*	| | / __  | / __  |  | |      | |  | /    \_\  | | / /    \ \        / /    _    / /   | |     /_/    \ \                    | |
*	| |/ /  | |/ /  | |  | |      | |  | \_____    | |/ /      \ \      / /    | |  / /____| |__     ______| |                   | |
*	| | /   | | /   | |  | |      | |   \_____ \   | | /        \ \    / /     | | /_______  |__|   / _____  |                   | |
*	| |/    | |/    | |  | |      | |         \ |  | |/\         \ \  / /      | |         | |     / /     | |        __         | |
* 	| |     | |     | |  | \      / |  __     | |  | |\ \         \ \/ /       | |         | |    | |     /| |       |  |        | |
*	| |     | |     | |   \ \____/ /   \ \____/ |  | | \ \         \  /        | |         | |     \ \___/ /\ \      / /    _____| |
*	|_|     |_|     |_|    \______/     \______/   |_|  \_\         \/         |_|         |_|      \_____/  \_\    /_/    |_______|
*
*
*
*** Copyright 2011 - 2013, m0skVi4a ;]
*** Plugin created in Rousse, Bulgaria
*** Credits:
*
* 	m0skVi4a ;]    	-	for the idea of the plugin and its creation
* 	ConnorMcLeod 	- 	for his help to block the name change for logged clients
*	Sylwester	-	for the idea for the encrypt
*	dark_style	-	for ideas in the plugin
* 	Vasilii-Zaicev	-	for testing the plugin
*/

#include <amxmodx>
#include <celltrie>
#include <cstrike>
#include <fun>
#include <fakemeta>
#include <hamsandwich>

#include <sqlx>

#define VERSION "9.0"
#define TASK_KICK 2000
#define TASK_MENU 3000
#define MENU_TASK_TIME 5.0
#define TASK_TIMER 4000
#define SALT "8c4f4370c53e0c1e1ae9acd577dddbed"
#define MAX_NAMES 64

#define TABLE "UserList"

//Start of CVAR pointers
new g_regtime;
new g_logtime;
new g_pass_length;
new g_attempts;
new g_chp_time;
new g_time;
new g_time_pass;
//End of CVAR pointers

//Start of Arrays
new params[2];
new check_pass[34];
new check_status[11];
new query[512];
new Handle:g_sqltuple;
new password[33][34];
new typedpass[32];
new new_pass[33][32];
new hash[34];
new attempts[33];
new times[33];
new g_player_time[33];
new g_client_data[33][35];
new value;
new menu[512];
new keys;
new length;
//new g_maxplayers;
new g_saytxt
new g_screenfade
new g_sync_hud
//End fo Arrays

#define Get_BitVar(%1,%2) !(!(%1 & (1 << (%2 & 31))))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

//Start of Booleans
new is_logged;
new is_registered;
new cant_change_pass;
new changing_name;
//End of Booleans

//Start of Trie handles
new Trie:g_commands;
new Trie:g_login_times;
new Trie:g_cant_login_time;
new Trie:g_pass_change_times;
new Trie:g_cant_change_pass_time;
//End of Trie handles

//Start of Constants
new const prefix[] = "[NTC]";

//Start of CVARs
new const g_cvars[][][] =
{
	{"rs_register_time", "60.0"},
	{"rs_login_time", "60.0"},
	{"rs_password_len", "6"},
	{"rs_attempts", "3"},
	{"rs_chngpass_times", "3"},
	{"rs_cant_login_time", "300"},
	{"rs_cant_change_pass_time", "300"}
};//End of CVARs
//End of Constants

/*==============================================================================
	Start of Plugin Init
================================================================================*/
public plugin_init() 
{
	register_plugin("Register System", VERSION, "m0skVi4a ;]")
	
	set_task(0.1, "Init_MYSQL")
	
	g_regtime = register_cvar(g_cvars[0][0], g_cvars[0][1])
	g_logtime = register_cvar(g_cvars[1][0], g_cvars[1][1])
	g_pass_length = register_cvar(g_cvars[2][0], g_cvars[2][1])
	g_attempts = register_cvar(g_cvars[3][0], g_cvars[3][1])
	g_chp_time = register_cvar(g_cvars[4][0], g_cvars[4][1])
	g_time = register_cvar(g_cvars[5][0], g_cvars[5][1])
	g_time_pass = register_cvar(g_cvars[6][0], g_cvars[6][1])

	register_clcmd("jointeam", "HookTeamCommands")
	
	register_clcmd("LOGIN_PASS", "Login")
	register_clcmd("REGISTER_PASS", "Register")
	register_clcmd("CHANGE_PASS_NEW", "ChangePasswordNew")
	register_clcmd("CHANGE_PASS_OLD", "ChangePasswordOld")
	register_clcmd("AUTO_LOGIN_PASS", "AutoLoginPassword")
	RegisterHam(Ham_Spawn, "player", "HookPlayerSpawn", 1)
	register_forward(FM_PlayerPreThink, "PlayerPreThink")
	register_forward(FM_ClientUserInfoChanged, "ClientInfoChanged")

	//g_maxplayers = get_maxplayers()
	g_saytxt = get_user_msgid("SayText")
	g_screenfade = get_user_msgid("ScreenFade")
	g_sync_hud = CreateHudSyncObj()

	g_login_times = TrieCreate()
	g_cant_login_time = TrieCreate()
	g_pass_change_times = TrieCreate()
	g_cant_change_pass_time = TrieCreate()
}
/*==============================================================================
	End of Plugin Init
================================================================================*/

/*==============================================================================
	Start of Plugin Natives
================================================================================*/
public plugin_natives()
{
	register_library("register_system")
	register_native("is_registered", "_is_registered")
	register_native("is_logged", "_is_logged")
	register_native("get_cant_login_time", "_get_cant_login_time")
	register_native("get_cant_change_pass_time", "_get_cant_change_pass_time")
}

public _is_registered(plugin, parameters)
{
	if(parameters != 1)
		return false

	new id = get_param(1)

	if(!id)
		return false

	if(Get_BitVar(is_registered,id))
	{
		return true
	}

	return false
}

public _is_logged(plugin, parameters)
{
	if(parameters != 1)
		return false

	new id = get_param(1)

	if(!id)
		return false

	if(Get_BitVar(is_logged,id))
	{
		return true
	}

	return false
}

public _get_cant_login_time(plugin, parameters)
{
	if(parameters != 1)
		return -1

	new id = get_param(1)

	if(!id)
		return -1

	new data[35];
	get_user_name(id, data, charsmax(data));
	if(TrieGetCell(g_cant_login_time, data, value))
	{
		new cal_time = get_pcvar_num(g_time) - (time() - value)
		return cal_time
	}

	return -1
}

public _get_cant_change_pass_time(plugin, parameters)
{
	if(parameters != 1)
		return -1

	new id = get_param(1)

	if(!id)
		return -1

	new data[35];

	get_user_name(id, data, charsmax(data));
	if(TrieGetCell(g_cant_change_pass_time, data, value))
	{
		new cal_time = get_pcvar_num(g_time_pass) - (time() - value)
		return cal_time
	}

	return -1
}
/*==============================================================================
	End of Plugin Natives
================================================================================*/

/*==============================================================================
	Start of Executing plugin's config and choose the save mode
================================================================================*/

public Init_MYSQL()
{
	g_sqltuple = SQL_MakeStdTuple()
	formatex(query, charsmax(query), "CREATE TABLE IF NOT EXISTS %s (ID INT AUTO_INCREMENT, Name VARCHAR(35), Password VARCHAR(34), Status VARCHAR(10), primary key(id))", TABLE);

	SQL_ThreadQuery(g_sqltuple, "QueryCreateTable", query)
}

public QueryCreateTable(failstate, Handle:query1, error[], errcode, data[], datasize, Float:queuetime)
{
	if(failstate == TQUERY_CONNECT_FAILED)
	{
		set_fail_state("[REGISTER SYSTEM] Could not connect to database!")
	}
	else if(failstate == TQUERY_QUERY_FAILED)
	{
		set_fail_state("[REGISTER SYSTEM] Query failed!")
	}
	else if(errcode)
	{
		server_print("[REGISTER SYSTEM] Error on query: %s", error)
	}
	else
	{
		server_print("[REGISTER SYSTEM] MYSQL connection succesful in %.0fs", queuetime);
	}	
}

/*==============================================================================
	End of Executing plugin's config and choose the save mode
================================================================================*/

/*==============================================================================
	Start of plugin's end function
================================================================================*/
public plugin_end()
{
	TrieDestroy(g_commands)
	TrieDestroy(g_login_times)
	TrieDestroy(g_cant_login_time)
	TrieDestroy(g_pass_change_times)
	TrieDestroy(g_cant_change_pass_time)
}
/*==============================================================================
	End of plugin's end function
================================================================================*/

/*==============================================================================
	Start of Client's connect and disconenct functions
================================================================================*/
public client_authorized(id)
{
	clear_user(id)
	remove_tasks(id)
	get_user_name(id, g_client_data[id], charsmax(g_client_data))
	
	if(TrieGetCell(g_login_times, g_client_data[id], value))
	{
		attempts[id] = value

		if(attempts[id] >= get_pcvar_num(g_attempts))
		{
			params[0] = id
			params[1] = 3
			set_task(1.0, "KickPlayer", id+TASK_KICK, params, sizeof params)
		}
	}

	if(TrieGetCell(g_pass_change_times, g_client_data[id], value))
	{
		times[id] = value

		if(times[id] >= get_pcvar_num(g_chp_time))
		{
			Set_BitVar(cant_change_pass,id)
		}
	}
	
	CheckClient(id)
}

public client_disconnect(id)
{
	clear_user(id)
	remove_tasks(id)
}
/*==============================================================================
	End of Client's connect and disconenct functions
================================================================================*/

/*==============================================================================
	Start of Check Client functions
================================================================================*/
public CheckClient(id)
{
	if(is_user_bot(id) || is_user_hltv(id))
		return PLUGIN_HANDLED

	remove_tasks(id)
	UnSet_BitVar(is_registered, id);
	UnSet_BitVar(is_logged, id);
	
	get_user_name(id, g_client_data[id], charsmax(g_client_data))

	new data[1]
	data[0] = id

	formatex(query, charsmax(query), "SELECT `Password`, `Status` FROM `%s` WHERE Name = ^"%s^";",TABLE ,  g_client_data[id])

	SQL_ThreadQuery(g_sqltuple, "QuerySelectData", query, data, 1)
	

	return PLUGIN_CONTINUE
}

public QuerySelectData(FailState, Handle:Query, error[], errorcode, data[], datasize, Float:fQueueTime)
{ 
	if(FailState == TQUERY_CONNECT_FAILED || FailState == TQUERY_QUERY_FAILED)
	{
		log_amx("%s", error)
		return
	}
	else
	{
		new id = data[0];
		new col_pass = SQL_FieldNameToNum(Query, "Password")
		new col_status = SQL_FieldNameToNum(Query, "Status")

		while(SQL_MoreResults(Query)) 
		{
			SQL_ReadResult(Query, col_pass, check_pass, charsmax(check_pass))
			SQL_ReadResult(Query, col_status, check_status, charsmax(check_status))
			Set_BitVar(is_registered,id);
			password[id] = check_pass

			/*if(equal(check_status, "LOGGED_IN"))
			{
				is_autolog[id] = true
				CheckAutoLogin(id)
			}*/

			if(is_user_connected(id))
			{
				user_silentkill(id)
				cs_set_user_team(id, CS_TEAM_UNASSIGNED)
				
				ShowMsg(id);
						
			}

			SQL_NextRow(Query)
		}
	}
}
/*==============================================================================
	End of Check Client functions
================================================================================*/

/*==============================================================================
	Start of Show Client's informative messages
================================================================================*/
public ShowMsg(id)
{		
	remove_tasks(id)

	params[0] = id

	if(!Get_BitVar(is_registered,id))
	{
		if(get_pcvar_float(g_regtime) != 0)
		{
			if(!Get_BitVar(changing_name,id))
			{
				CreateMainMenuTask(id+TASK_MENU)

				g_player_time[id] = get_pcvar_num(g_regtime)
				ShowTimer(id+TASK_TIMER)
			
				params[1] = 1
				set_task(get_pcvar_float(g_regtime) + 3, "KickPlayer", id+TASK_KICK, params, sizeof params)
				return PLUGIN_HANDLED
			}
			else
			{
				g_player_time[id] = -1
				set_task(1.0, "ShowTimer", id+TASK_TIMER)
			}
		}
	}
	else if(!Get_BitVar(is_logged,id))
	{
		if(!Get_BitVar(changing_name,id))
		{
			CreateMainMenuTask(id+TASK_MENU)
	
			g_player_time[id] = get_pcvar_num(g_logtime)
			ShowTimer(id+TASK_TIMER)
			
			params[1] = 2
			set_task(get_pcvar_float(g_logtime) + 3, "KickPlayer", id+TASK_KICK, params, sizeof params)
			return PLUGIN_HANDLED
		}
		else
		{
			g_player_time[id] = -1
			set_task(1.0, "ShowTimer", id+TASK_TIMER)
		}
	}
	return PLUGIN_CONTINUE
}

public ShowTimer(id)
{
	id -= TASK_TIMER

	if(!is_user_connected(id))
		return PLUGIN_HANDLED

	switch(g_player_time[id])
	{
		case 10..19:
		{
			set_hudmessage(255, 255, 0, -1.0, -1.0, 0, 0.02, 1.0,_,_, -1)
		}
		case 0..9:
		{
			set_hudmessage(255, 0, 0, -1.0, -1.0, 1, 0.02, 1.0,_,_, -1)
		}
		case -1:
		{
			set_hudmessage(255, 255, 255, -1.0, -1.0, 1, 0.02, 1.0,_,_, -1)
		}
		default:
		{
			set_hudmessage(0, 255, 0, -1.0, -1.0, 0, 0.02, 1.0,_,_, -1)
		}
	}

	if(g_player_time[id] == 0)
	{
		ShowSyncHudMsg(id, g_sync_hud, "BẠN ĐÃ BỊ KICK");
		return PLUGIN_CONTINUE
	}
	else if(!Get_BitVar(is_registered,id) && get_pcvar_float(g_regtime))
	{
		ShowSyncHudMsg(id, g_sync_hud, "Có %ds để đăng kí", g_player_time[id])
	}
	else if(Get_BitVar(is_registered,id) && !Get_BitVar(is_logged,id))
	{
		ShowSyncHudMsg(id, g_sync_hud, "Có %ds để đăng nhập", g_player_time[id])
	}
	else {
		return PLUGIN_HANDLED
	}

	g_player_time[id]--

	set_task(1.0, "ShowTimer", id+TASK_TIMER)

	return PLUGIN_CONTINUE
}

/*==============================================================================
	End of Show Client's informative messages
================================================================================*/

/*==============================================================================
	Start of the Main Menu function
================================================================================*/
public CreateMainMenuTask(id)
{
	id -= TASK_MENU

	if((!Get_BitVar(is_registered,id) && get_pcvar_float(g_regtime)) || (Get_BitVar(is_registered,id) && !Get_BitVar(is_logged,id)))
	{
		MainMenu(id)
		set_task(MENU_TASK_TIME, "CreateMainMenuTask", id+TASK_MENU)
	}
}

public MainMenu(id)
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED

	static title[32];
	if(  Get_BitVar(is_registered, id) ) {
		formatex(title, charsmax(title), " [NTC] Multimod DP - [DA DANG KI]");
	}
	else {
		formatex(title, charsmax(title), " [NTC] Multimod DP - [CHUA DANG KI]");
	}
	
	new menuid = menu_create(title, "HandlerMainMenu");

	if(!Get_BitVar(is_registered,id)) {
		menu_additem(menuid, "Dang ki");
	}
	else {
		menu_additem(menuid, "Dang nhap");
	}
	
	menu_additem(menuid, "Giup do");
	menu_additem(menuid, "Thoat");
	
	//menu_setprop( menuid, MPROP_PERPAGE, 0 );
	menu_setprop(menuid, MPROP_EXIT, MEXIT_NEVER);

	return PLUGIN_CONTINUE
}

public HandlerMainMenu( id, menuid, item )
{
	switch(item)
	{
		case 0:
		{
			if(!Get_BitVar(is_registered,id)) {
				client_cmd(id, "messagemode REGISTER_PASS")
			}
			else {
				client_cmd(id, "messagemode LOGIN_PASS")
			}
		}
		
		case 1:
		{
			if(!Get_BitVar(is_registered,id)) {
				show_motd(id, "link .html", "Hướng dẫn đăng kí");
			}
			else {
				show_motd(id, "link .html", "Hướng dẫn đăng nhập");
			}
		}
		case 2: 
		{
			params[0] = id
			params[1] = 4
			set_task(2.0, "KickPlayer", id+TASK_KICK, params, sizeof params)
		}
	}
	return PLUGIN_HANDLED
}
/*==============================================================================
	End of the Main Menu function
================================================================================*/

/*==============================================================================
	Start of Login function
================================================================================*/
public Login(id)
{
	if(Get_BitVar(changing_name, id))
	{
		client_printcolor(id, "!g%s!t Có thể đăng nhập sau khi đã đổi lại tên hoặc retry!", prefix)
		return PLUGIN_HANDLED
	}

	if(!Get_BitVar(is_registered,id))
	{	
		client_printcolor(id, "!g%s!t Đăng kí trước thì mới được đăng nhập!", prefix)
		return PLUGIN_HANDLED
	}

	if(Get_BitVar(is_logged,id))
	{
		client_printcolor(id, "!g%s!t Đã đăng nhập!", prefix)
		return PLUGIN_HANDLED
	}
	
	read_args(typedpass, charsmax(typedpass))
	remove_quotes(typedpass)

	if(equal(typedpass, ""))
		return PLUGIN_HANDLED

	hash = convert_password(typedpass)

	if(!equal(hash, password[id]))
	{	
		TrieSetCell(g_login_times, g_client_data[id], ++attempts[id])
		client_printcolor(id, "!g%s!t Sai pass [!g%d!t/!g%d!t lần]", prefix, attempts[id], get_pcvar_num(g_attempts))

		if(attempts[id] >= get_pcvar_num(g_attempts))
		{
			g_player_time[id] = 0
			ShowTimer(id+TASK_TIMER)
			

			if(get_pcvar_num(g_time))
			{
				TrieSetCell(g_cant_login_time, g_client_data[id], time())
			}
			else
			{
				TrieSetCell(g_cant_login_time, g_client_data[id], 0)
			}

			params[0] = id
			params[1] = 3
			set_task(2.0, "KickPlayer", id+TASK_KICK, params, sizeof params)

			if(get_pcvar_num(g_time))
			{	
				set_task(get_pcvar_float(g_time), "RemoveCantLogin", 0, g_client_data[id], sizeof g_client_data)
			}
			return PLUGIN_HANDLED
		}
		else
		{
			client_cmd(id, "messagemode LOGIN_PASS")
		}
		return PLUGIN_HANDLED
	}
	else
	{
		Set_BitVar(is_logged,id)
		attempts[id] = 0
		remove_task(id+TASK_KICK)
		
		//client_cmd(id, "menu");
	}
	
	
	return PLUGIN_CONTINUE
}

/*==============================================================================
	End of Login function
================================================================================*/

/*==============================================================================
	Start of Register function
================================================================================*/
public Register(id)
{
	if(Get_BitVar(changing_name,id))
	{
		client_printcolor(id, "!g%s!t Có thể đăng kí sau khi đã đổi lại tên hoặc retry!", prefix)
		return PLUGIN_HANDLED
	}

	read_args(typedpass, charsmax(typedpass))
	remove_quotes(typedpass)

	new passlength = strlen(typedpass)

	if(equal(typedpass, ""))
		return PLUGIN_HANDLED
	
	if(Get_BitVar(is_registered,id))
	{
		client_printcolor(id, "!g%s!t Tài khoản đã được đăng kí", prefix)
		return PLUGIN_HANDLED
	}

	if(passlength < get_pcvar_num(g_pass_length))
	{
		client_printcolor(id, "!g%s!t Mật khẩu phải có ít nhất!g %d!t kí tự!", prefix, get_pcvar_num(g_pass_length))
		client_cmd(id, "messagemode REGISTER_PASS")
		return PLUGIN_HANDLED
	}

	new_pass[id] = typedpass
	remove_task(id+TASK_MENU)
	ConfirmPassword(id)
	return PLUGIN_CONTINUE
}
/*==============================================================================
	End of Register function
================================================================================*/

/*==============================================================================
	Start of Change Password function
================================================================================*/
public ChangePasswordNew(id)
{
	if(!Get_BitVar(is_registered,id) || !Get_BitVar(is_logged,id) || Get_BitVar(changing_name,id))
		return PLUGIN_HANDLED

	if(Get_BitVar(cant_change_pass,id))
	{
		client_printcolor(id, "!g%s!t Đã đổi pass!g %d!t lần! Chờ map tiếp nhé!", prefix, get_pcvar_num(g_chp_time))
		return PLUGIN_HANDLED
	}

	read_args(typedpass, charsmax(typedpass))
	remove_quotes(typedpass)

	new passlenght = strlen(typedpass)

	if(equal(typedpass, ""))
		return PLUGIN_HANDLED

	if(passlenght < get_pcvar_num(g_pass_length))
	{
		client_printcolor(id, "!g%s!t Mật khẩu phải có ít nhất!g %d!t kí tự!", prefix, get_pcvar_num(g_pass_length))
		client_cmd(id, "messagemode CHANGE_PASS_NEW")
		return PLUGIN_HANDLED
	}

	new_pass[id] = typedpass
	client_cmd(id, "messagemode CHANGE_PASS_OLD")
	return PLUGIN_CONTINUE
}

public ChangePasswordOld(id)
{
	if(!Get_BitVar(is_registered,id) || !Get_BitVar(is_logged,id) || Get_BitVar(changing_name,id))
		return PLUGIN_HANDLED

	if(Get_BitVar(cant_change_pass,id))
	{
		client_printcolor(id, "!g%s!t Đã đổi pass!g %d!t lần! Chờ map tiếp nhé!", prefix, get_pcvar_num(g_chp_time))
		return PLUGIN_HANDLED
	}

	read_args(typedpass, charsmax(typedpass))
	remove_quotes(typedpass)

	if(equal(typedpass, "") || equal(new_pass[id], ""))
		return PLUGIN_HANDLED

	hash = convert_password(typedpass)

	if(!equali(hash, password[id]))
	{
		TrieSetCell(g_login_times, g_client_data[id], ++attempts[id])
		client_printcolor(id, "!g%s!t Sai pass [!g%d!t/!g%d!t lần]", prefix, attempts[id], get_pcvar_num(g_attempts))

		if(attempts[id] >= get_pcvar_num(g_attempts))
		{
			g_player_time[id] = 0
			ShowTimer(id+TASK_TIMER)
			
			
			if(get_pcvar_num(g_time))
			{
				TrieSetCell(g_cant_login_time, g_client_data[id], time())
			}
			else
			{
				TrieSetCell(g_cant_login_time, g_client_data[id], 0)
			}
			params[0] = id
			params[1] = 3
			set_task(2.0, "KickPlayer", id+TASK_KICK, params, sizeof params)

			if(get_pcvar_num(g_time))
			{	
				set_task(get_pcvar_float(g_time), "RemoveCantLogin", 0, g_client_data[id], sizeof g_client_data)
			}
			return PLUGIN_HANDLED
		}
		else
		{
			client_cmd(id, "messagemode CHANGE_PASS_OLD")
		}
		return PLUGIN_HANDLED
	}

	ConfirmPassword(id)
	return PLUGIN_CONTINUE
}
/*==============================================================================
	End of Change Password function
================================================================================*/

/*==============================================================================
	Start of Confirming Register's or Change Password's password function
================================================================================*/
public ConfirmPassword(id)
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED

	length = 0
		
	formatex(menu, charsmax(menu) - length, "%L", LANG_SERVER, "MENU_PASS", new_pass[id])
	keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_0

	show_menu(id, keys, menu, -1, "Password Menu")
	return PLUGIN_CONTINUE
}

public HandlerConfirmPasswordMenu(id, key)
{
	switch(key)
	{
		case 0:
		{
			get_user_name(id, g_client_data[id], charsmax(g_client_data))
			
			hash = convert_password(new_pass[id])

			if(Get_BitVar(is_registered,id))
			{
				formatex(query, charsmax(query), "UPDATE `%s` SET Password = ^"%s^" WHERE Name = ^"%s^";",TABLE, hash, g_client_data[id])
				SQL_ThreadQuery(g_sqltuple, "QuerySetData", query)
				
				password[id] = hash
				TrieSetCell(g_pass_change_times, g_client_data[id], ++times[id])
				client_printcolor(id, "%L", LANG_SERVER, "CHANGE_NEW", prefix, new_pass[id])

				if(times[id] >= get_pcvar_num(g_chp_time))
				{
					Set_BitVar(cant_change_pass,id);
					
					if(get_pcvar_num(g_time_pass))
					{
						TrieSetCell(g_cant_change_pass_time, g_client_data[id], time())
					}
					else
					{
						TrieSetCell(g_cant_change_pass_time, g_client_data[id], 0)
					}

					if(get_pcvar_num(g_time_pass))
					{	
						set_task(get_pcvar_float(g_time), "RemoveCantChangePass", 0, g_client_data[id], sizeof g_client_data)
					}
				}
				MainMenu(id)
			}
			else
			{
				formatex(query, charsmax(query), "INSERT INTO `%s` (`Name`, `Password`) VALUES (^"%s^", ^"%s^");", TABLE, g_client_data[id], hash)
				SQL_ThreadQuery(g_sqltuple, "QuerySetData", query)
				

				Set_BitVar(is_registered,id);
				password[id] = hash
				new_pass[id] = ""
								
				if(is_user_connected(id))
				{
					user_silentkill(id)
					cs_set_user_team(id, CS_TEAM_UNASSIGNED)
					ShowMsg(id)
				}
			}
		}
		case 1:
		{
			if(Get_BitVar(is_registered,id))
			{
				client_cmd(id, "messagemode CHANGE_PASS_NEW")
			}
			else
			{
				client_cmd(id, "messagemode REGISTER_PASS")
				CreateMainMenuTask(id+TASK_MENU)
			}
		}
		case 9:
		{
			MainMenu(id)
			CreateMainMenuTask(id+TASK_MENU)
			return PLUGIN_HANDLED
		}
	}
	return PLUGIN_HANDLED
}

public QuerySetData(FailState, Handle:Query, error[],errcode, data[], datasize)
{
	if(FailState == TQUERY_CONNECT_FAILED || FailState == TQUERY_QUERY_FAILED)
	{
		log_amx("%s", error)
		return
	}
}
/*==============================================================================
	End of Confirming Register's or Change Password's password function
================================================================================*/

/*==============================================================================
	Start of Jointeam menus and commands functions
================================================================================*/
public HookTeamCommands(id)
{
	if(!is_user_connected(id))
		return PLUGIN_CONTINUE

	if((!Get_BitVar(is_registered,id) && get_pcvar_float(g_regtime)) || (Get_BitVar(is_registered,id) && !Get_BitVar(is_logged,id)))
	{
		MainMenu(id)
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}
/*==============================================================================
	End of Jointeam menus and commands functions
================================================================================*/

/*==============================================================================
	Start of Player Spawn function
================================================================================*/
public HookPlayerSpawn(id)
{
	if(is_user_connected(id))
	{
		show_menu(id, 0, "^n", 1)
	}
}
/*==============================================================================
	End of Player Spawn function
================================================================================*/

/*==============================================================================
	Start of Player PreThink function for the blind function
================================================================================*/
public PlayerPreThink(id)
{
	if(!is_user_connected(id) || Get_BitVar(changing_name,id))
		return PLUGIN_HANDLED
	
	if((!Get_BitVar(is_registered,id) && get_pcvar_float(g_regtime)) || (Get_BitVar(is_registered,id) && !Get_BitVar(is_logged,id)))
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
	}

	return PLUGIN_CONTINUE
}
/*==============================================================================
	End of Player PreThink function for the blind function
================================================================================*/

/*==============================================================================
	Start of Client Info Change function for hooking name change of clients
================================================================================*/
public ClientInfoChanged(id) 
{
	if(!is_user_connected(id))
		return FMRES_IGNORED
	
	new oldname[32], newname[32];
		
	get_user_name(id, oldname, charsmax(oldname))
	get_user_info(id, "name", newname, charsmax(newname))

	if(!equal(oldname, newname))
	{
		replace_all(newname, charsmax(newname), "%", " ")

		UnSet_BitVar(changing_name,id)
		
		if(!is_user_alive(id))
		{
			Set_BitVar(changing_name,id)

		}
		else
		{
			if(Get_BitVar(is_logged, id))
			{
				set_user_info(id, "name", oldname)
				client_printcolor(id, "!g%s!y Vui lòng không đổi tên", prefix)
				return FMRES_HANDLED
			}
		}
	}
	return FMRES_IGNORED
}
/*==============================================================================
	End of Client Info Change function for hooking name change of clients
================================================================================*/

/*==============================================================================
	Start of Kick Player function
================================================================================*/
public KickPlayer(parameters[])
{
	new id = parameters[0]
	new reason = parameters[1]

	if(!is_user_connecting(id) && !is_user_connected(id))
		return PLUGIN_HANDLED

	new userid = get_user_userid(id)

	switch(reason)
	{
		case 1:
		{
			if(Get_BitVar(is_registered,id))
				return PLUGIN_HANDLED

			console_print(id, "BỊ KICK DO CHƯA ĐĂNG KÍ");
			server_cmd("kick #%i ^"PHẢI ĐĂNG KÍ MỚI ĐƯỢC THAM GIA^"", userid);
		}
		case 2:
		{
			if(Get_BitVar(is_logged,id))
				return PLUGIN_HANDLED

			console_print(id, "BỊ KICK DO CHƯA ĐĂNG NHẬP");
			server_cmd("kick #%i ^"PHẢI ĐĂNG NHẬP MỚI ĐƯỢC THAM GIA^"", userid);
		}
		case 3:
		{
			if(TrieGetCell(g_cant_login_time, g_client_data[id], value))
			{
				console_print(id, "BỊ KICK DO ĐĂNG NHẬP THẤT BẠI NHIỀU LẦN");

				if(!value)
				{
					server_cmd("kick #%i ^"Sai mật khẩu %d lần nên map sau mới vào được server^"", userid, get_pcvar_num(g_attempts))
				}
				else
				{
					new cal_time = get_pcvar_num(g_time) - (time() - value)
					server_cmd("kick #%i ^"Sai mật khẩu %d lần nên sau %d mới vào được server^"", userid, get_pcvar_num(g_attempts), cal_time)
				}
			}
		}
		case 4:
		{
			console_print(id, "BỊ KICK DO THOÁT SERVER");
			server_cmd("kick #%i ^"THOÁT KHỎI SERVER THÀNH CÔNG^"", userid);
		}
	}
	return PLUGIN_CONTINUE
}
/*==============================================================================
	End of Kick Player function
================================================================================*/

/*==============================================================================
	Start of Removing Punishes function
================================================================================*/
public RemoveCantLogin(data[])
{
	TrieDeleteKey(g_login_times, data)
	TrieDeleteKey(g_cant_login_time, data)
}

public RemoveCantChangePass(data[])
{
	TrieDeleteKey(g_cant_change_pass_time, data)
	TrieDeleteKey(g_pass_change_times, data)

	new target;
	target = find_player("a", data)
	
	if(!target)
		return PLUGIN_HANDLED

	UnSet_BitVar(cant_change_pass,target)
	client_printcolor(target, " !g%s!t Đã có thể đổi mạt khẩu!", prefix)
	return PLUGIN_CONTINUE
}
/*==============================================================================
	End of Removing Punish function
================================================================================*/

/*==============================================================================
	Start of Plugin's stocks
================================================================================*/
stock client_printcolor(const id, const message[], any:...)
{
	new g_message[191];
	new i = 1, players[32];

	vformat(g_message, charsmax(g_message), message, 3)

	replace_all(g_message, charsmax(g_message), "!g", "^4")
	replace_all(g_message, charsmax(g_message), "!n", "^1")
	replace_all(g_message, charsmax(g_message), "!t", "^3")

	if(id)
	{
		players[0] = id
	}
	else
	{
		get_players(players, i, "ch")
	}

	for(new j = 0; j < i; j++)
	{
		if(is_user_connected(players[j]))
		{
			message_begin(MSG_ONE_UNRELIABLE, g_saytxt,_, players[j])
			write_byte(players[j])
			write_string(g_message)
			message_end()
		}
	}
}

stock convert_password(const password[])
{
	new pass_salt[64], converted_password[34];

	formatex(pass_salt, charsmax(pass_salt), "%s%s", password, SALT)
	md5(pass_salt, converted_password)
	
	return converted_password
}

stock clear_user(const id)
{
	UnSet_BitVar(is_logged, id);
	UnSet_BitVar(is_registered, id);
	UnSet_BitVar(cant_change_pass, id);
	UnSet_BitVar(changing_name, id);
	attempts[id] = 0
	times[id] = 0
}

stock remove_tasks(const id)
{
	remove_task(id+TASK_KICK)
	remove_task(id+TASK_MENU)
	remove_task(id+TASK_TIMER)
	remove_task(id)
}
/*==============================================================================
	End of Plugin's stocks
================================================================================*/
