#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <sqlx>

#define PLUGIN    "SuperBank"
#define AUTHOR	"timmw"
#define VERSION	"0.1.1"

/**	--- TABLE SQL --------------------------------------------------
 * 	
 * 	- Users Table
 * 
 * 	CREATE TABLE IF NOT EXISTS `bank_users`
 * 	(
 * 		`id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, 
 *		`username` VARCHAR(32) NOT NULL, 
 *		`steam_id` VARCHAR(32) NOT NULL,
 *		`balance` BIGINT UNSIGNED NOT NULL DEFAULT 0, 
 *		`date_opened` DATETIME NOT NULL, 
 * 		`access` TINYINT(1) NOT NULL DEFAULT 0,
 *		PRIMARY KEY(`id`),
 * 		UNIQUE(`steam_id`)
 *	)
 * 	
 * 	- Lottery Draws Table (not currently in use)
 * 	
 * 	CREATE TABLE IF NOT EXISTS `bank_lottery_draws`
 * 	(
 * 		`drawId` INT(5) UNSIGNED AUTO_INCREMENT NOT NULL,
 * 		`drawDate` DATETIME NOT NULL,
 * 		PRIMARY KEY(`drawId`)
 * 	)
 * 
 *	- Lottery Entries Table (not currently in use)
 * 
 * 	CREATE TABLE IF NOT EXISTS `bank_lottery_entries`
 * 	(
 * 		`userId` INT(10) UNSIGNED NOT NULL,
 *		`drawId` INT(5) UNSIGNED NOT NULL, 
 * 		FOREIGN KEY(`userId`) REFERENCES `bank_users`(`userId`),
 * 		FOREIGN KEY(`drawId`) REFERENCES `bank_lottery_draws`(`drawId`),
 * 		PRIMARY KEY(`drawId`, `userId`)
 * 	)
 * 
 * 	NOTES -------------------------------------------------------
 * 
 * 	User name is updated on client connect, every time a user checks/alters
 *     their balance and when they disconnect.
 * 
 *     Max. balance is $18,446,744,073,709,551,615 ($18.4 quintillion).
 * 
 * 	CMD List ----------------------------------------------------
 * 
 * 	say /bankhelp
 * 	say /openaccount
 * 	say /balance
 * 	say /moneywithdrawn
 * 	say /deposit <amount>
 * 	say /withdraw <amount>
 * 	say /maxdep
 * 	say /maxwit
 * 	maxdep
 * 	maxwit
 * 	
 *	say /richlist
 */

new Handle:g_sqlTuple
new g_iRound = 0
new bool:g_bHasAccount[33] = false
new g_iMoneyWithdrawn[33] = 0

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_clcmd("say /openaccount",      "bank_create",      ADMIN_KICK, "Creates a bank account.")
	//register_clcmd("say /bankhelp",       "bank_help",		ADMIN_KICK, "Displays the bank help motd.")
	//register_clcmd("say /richlist",       "bank_richlist",	-1, "Displays the rich list.")
	//register_clcmd("say /enterlottery",   "enter_lottery",	-1, "Enters you into the lottery for this week.")
	
	register_clcmd("say /balance",          "bank_balance",	 ADMIN_KICK, "Displays your balance.")
	register_clcmd("say /moneywithdrawn",   "money_withdrawn",  ADMIN_KICK, "Shows how much you've withdrawn this round.")
	register_clcmd("say /maxdep",           "deposit_maximum",  ADMIN_KICK, "Deposits all of your cash.")
	register_clcmd("say /maxwit",           "withdraw_maximum", ADMIN_KICK, "Withdraw cash until limit reached.")
	
	register_clcmd("maxdep",                "deposit_maximum",  ADMIN_KICK, "Deposits all of your cash.")
	register_clcmd("maxwit",				"withdraw_maximum", ADMIN_KICK, "Withdraw cash until limit reached.")
	
	register_clcmd("say",                   "say_handler",	  ADMIN_KICK)
	register_clcmd("say_team",			  "say_handler",	  ADMIN_KICK)
	
	//register_cvar("bank_helppage", 			"http://timmw.co.uk")
	//register_cvar("bank_richlistpage", 		"http://prototypeclan.com")
	register_cvar("bank_offrounds", 		"3")
	register_cvar("bank_withdrawlimit", 	"10000")
	
	register_logevent("event_round_start", 2, "0=World triggered", "1=Round_Start")
	//register_logevent("event_round_end", 2, "0=World triggered", "1=Round_End")
}

public plugin_cfg()
{
	//g_sqlTuple = SQL_MakeStdTuple()
	g_sqlTuple = Handle:SQL_MakeDbTuple ("domain.com", "user", "pwd", "db")
}

public check_account(id)
{
	new steamId[33]
	get_user_authid(id, steamId, 32)
	
	new szQuery[100]
	
	formatex(szQuery, 99, "SELECT `id` FROM `bank_users` WHERE `steam_id` = '%s'", steamId)
	
	new data[1]
	data[0] = id
	SQL_ThreadQuery(g_sqlTuple, "CheckSelectHandler", szQuery, data, 1)
	
	return PLUGIN_HANDLED	
}

public GetQueryState(failState, errcode, error[])
{
	if(failState == TQUERY_CONNECT_FAILED)
		return set_fail_state("Could not connect to SQL database.")
	else if(failState == TQUERY_QUERY_FAILED)
		return set_fail_state("Query failed.")
	
	if(errcode)
		return log_amx("Error on query: %s", error)
	
	return PLUGIN_CONTINUE
}
  
public CheckSelectHandler(failState, Handle:query, error[], errcode, data[], dataSize)
{	
	GetQueryState(failState, errcode, error)
	
	if(SQL_NumResults(query) != 0)
	{
		g_bHasAccount[data[0]] = true
		update_name(data[0])
	}
	
	return PLUGIN_CONTINUE
}

public say_handler(id)
{
	new said[191]
	read_args(said, 190)
	remove_quotes(said)
	
	new szParse[2][33]
	parse(said, szParse[0], 32, szParse[1], 32)
	
	if(containi(szParse[0], "/deposit") != -1)
	{
		new iDepositAmount = str_to_num(szParse[1])
		bank_deposit(id, iDepositAmount)
		
		return PLUGIN_HANDLED
	}
	else if(containi(szParse[0], "/withdraw") != -1)
	{
		new iWithdrawAmount = str_to_num(szParse[1])
		bank_withdraw(id, iWithdrawAmount)
		
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}

public plugin_end()
{
	SQL_FreeHandle(g_sqlTuple)
}

public event_round_start()
{
	arrayset(g_iMoneyWithdrawn, 0, 32)
	g_iRound++
}

public client_putinserver(id)
{
	check_account(id)
}

public client_disconnect(id)
{
	if(g_bHasAccount[id])
		update_name(id)

	g_bHasAccount[id] = false
	g_iMoneyWithdrawn[id] = 0
}

public withdraw_maximum(id)
{
	if(g_bHasAccount[id] == false)
	{
		client_print(id, print_chat, "[BANK] You don't have an account, create one by typing /openaccount in chat.")
		return PLUGIN_HANDLED
	}
	
	update_name(id)
	
	new szOffRounds[3]
	get_cvar_string("bank_offrounds", szOffRounds, 2)
	new iOffRounds = str_to_num(szOffRounds)
	
	if(g_iRound <= iOffRounds)
	{
		client_print(id, print_chat, "[BANK] You cannot withdraw for the first %i rounds.", iOffRounds)
		return PLUGIN_HANDLED
	}
	
	if(cs_get_user_team(id) == CS_TEAM_SPECTATOR)
	{
		client_print(id, print_chat, "[BANK] You must join a team before you can withdraw money.")
		return PLUGIN_HANDLED
	}
	
	new szWithdrawLimit[10]
	get_cvar_string("bank_withdrawlimit", szWithdrawLimit, 9)
	new iWithdrawLimit = str_to_num(szWithdrawLimit)
	new iMoney = cs_get_user_money(id)
	new iMoneySpace = (16000 - iMoney)
	new iMoneyLeft = iWithdrawLimit - g_iMoneyWithdrawn[id]
	
	if(iMoneySpace <= 0)
	{
		client_print(id, print_chat, "[BANK] You can only hold a maximum of $16000.")
		return PLUGIN_HANDLED
	}
	
	if(iMoneyLeft <= 0)
	{
		client_print(id, print_chat, "[BANK] You have already reached the maximum withdraw limit for this round.")
		return PLUGIN_HANDLED
	}
	
	new iLimit = min(iMoneySpace, iMoneyLeft)
	
	new data[3]
	data[0] = id
	data[1] = iMoney
	data[2] = iLimit
	
	new steamId[33]
	get_user_authid(id, steamId, 32)
	
	new szQuery[100]
	
	formatex(szQuery, 99, "SELECT `balance` FROM `bank_users` WHERE `steam_id` = '%s'", steamId)
	SQL_ThreadQuery(g_sqlTuple, "BalanceHandler", szQuery, data, 3)
	
	return PLUGIN_HANDLED
}

public bank_withdraw(id, iWithdrawAmount)
{
	if(g_bHasAccount[id] == false)
	{
		client_print(id, print_chat, "[BANK] You don't have an account, create one by typing /openaccount in chat.")
		return PLUGIN_HANDLED
	}
	
	update_name(id)
	
	new szOffRounds[3]
	get_cvar_string("bank_offrounds", szOffRounds, 2)
	new iOffRounds = str_to_num(szOffRounds)
	
	if(g_iRound <= iOffRounds)
	{
		client_print(id, print_chat, "[BANK] You cannot withdraw for the first %i rounds.", iOffRounds)
		return PLUGIN_HANDLED
	}
	
	if(cs_get_user_team(id) == CS_TEAM_SPECTATOR)
	{
		client_print(id, print_chat, "[BANK] You must join a team before you can withdraw money.")
		return PLUGIN_HANDLED
	}
	
	new szWithdrawLimit[10]
	get_cvar_string("bank_withdrawlimit", szWithdrawLimit, 9)
	new iWithdrawLimit = str_to_num(szWithdrawLimit)
	new iMoney = cs_get_user_money(id)
	new iMoneySpace = (16000 - iMoney)
	new iMoneyLeft = iWithdrawLimit - g_iMoneyWithdrawn[id]
	
	if(iMoneySpace == 0)
	{
		client_print(id, print_chat, "[BANK] You can only hold a maximum of $16000.")
		return PLUGIN_HANDLED
	}
	
	if(iMoneyLeft == 0)
	{
		client_print(id, print_chat, "[BANK] You have already reached the maximum withdraw limit for this round.")
		return PLUGIN_HANDLED
	}
	
	new iLimit = min(iMoneySpace, iMoneyLeft)
	
	new data[4]
	data[0] = id
	data[1] = iMoney
	data[2] = iLimit
	data[3] = iWithdrawAmount
	
	new steamId[33]
	get_user_authid(id, steamId, 32)
	
	new szQuery[100]
	
	formatex(szQuery, 99, "SELECT `balance` FROM `bank_users` WHERE `steam_id` = '%s'", steamId)
	SQL_ThreadQuery(g_sqlTuple, "BalanceHandler", szQuery, data, 4)

	return PLUGIN_HANDLED
}

public BalanceHandler(failState, Handle:query, error[], errcode, data[], dataSize)
{
	GetQueryState(failState, errcode, error)
	
	new szBalance[21]
	SQL_ReadResult(query, 0, szBalance, 20)
	
	new iBalance = SQL_ReadResult(query, 0)
	
	new id = data[0]
	
	if(dataSize == 4) // Someone typed /withdraw x
	{
		new iMoney = data[1]
		new iLimit = data[2]
		new iWithdrawAmount = data[3]
		
		if(iLimit > iBalance)
			iLimit = iBalance
		
		if(iWithdrawAmount > iLimit)
			iWithdrawAmount = iLimit
		
		set_balance(id, -iWithdrawAmount)
		cs_set_user_money(id, (iMoney + iWithdrawAmount), 1)
		g_iMoneyWithdrawn[id] += iWithdrawAmount
		client_print(id, print_chat, "[BANK] You have withdrawn $%i.", iWithdrawAmount)
	}
	else if(dataSize == 3) // Someone typed /maxwit
	{
		new iMoney = data[1]
		new iLimit = data[2]
		
		if(iLimit > iBalance)
			iLimit = iBalance
	
		set_balance(id, -iLimit)
		cs_set_user_money(id, (iMoney + iLimit), 1)
		g_iMoneyWithdrawn[id] += iLimit
		client_print(id, print_chat, "[BANK] You have withdrawn $%i.", iLimit)
	}
	else if(dataSize == 1) // Someone typed /balance
	{
		client_print(data[0], print_chat, "[BANK] Your balance is $%s.", szBalance)
	}
	
	return PLUGIN_CONTINUE
}

public deposit_maximum(id)
{
	if(g_bHasAccount[id] == false)
	{
		client_print(id, print_chat, "[BANK] You don't have an account, create one by typing /openaccount in chat")
		return PLUGIN_HANDLED
	}
	
	update_name(id)
	
	if(cs_get_user_team(id) == CS_TEAM_SPECTATOR)
	{
		client_print(id, print_chat, "[BANK] You must join a team before you can deposit money.")
		return PLUGIN_HANDLED
	}
	
	new iDepositAmount = cs_get_user_money(id)
	cs_set_user_money(id, 0, 1)
	set_balance(id, iDepositAmount)
	client_print(id, print_chat, "[BANK] You have deposited $%i.", iDepositAmount)
	
	return PLUGIN_HANDLED
}

public bank_deposit(id, iDepositAmount)
{
	if(g_bHasAccount[id] == false)
	{
		client_print(id, print_chat, "[BANK] You don't have an account, create one by typing /openaccount in chat.")
		return PLUGIN_HANDLED
	}
	
	update_name(id)
	
	if(cs_get_user_team(id) == CS_TEAM_SPECTATOR)
	{	
		client_print(id, print_chat, "[BANK] You must join a team before you can deposit money.")
		return PLUGIN_HANDLED
	}
	
	new iMoney = cs_get_user_money(id)
	
	if(iDepositAmount > iMoney)
		iDepositAmount = iMoney
	
	cs_set_user_money(id, iMoney - iDepositAmount, 1)
	set_balance(id, iDepositAmount)
	client_print(id, print_chat, "[BANK] You have deposited $%i.", iDepositAmount)
	
	return PLUGIN_HANDLED
}

public money_withdrawn(id)
{
	if(g_bHasAccount[id])
	{
		update_name(id)
		
		new szWithdrawLimit[10]
		get_cvar_string("bank_withdrawlimit", szWithdrawLimit, 9)
		new iWithdrawLimit = str_to_num(szWithdrawLimit)
		
		client_print(id, print_chat, "[BANK] You have withdrawn $%i of a possible $%i so far this round.", g_iMoneyWithdrawn[id], iWithdrawLimit)
		return PLUGIN_HANDLED
	}
	else
	{
		client_print(id, print_chat, "[BANK] You don't have an account, create one by typing /openaccount in chat.")
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_HANDLED
}

public bank_create(id)
{	
	if(g_bHasAccount[id])
	{
		update_name(id)
		client_print(id, print_chat, "[BANK] You already have an account.")
		return PLUGIN_HANDLED
	}
	
	new szName[33], szSteamId[33]
	get_user_name(id, szName, 32)
	get_user_authid(id, szSteamId, 32)
	
	new szQuery[150]
	
	formatex(szQuery, 149, "INSERT INTO `bank_users` (`username`, `steam_id`, `date_opened`) VALUES ('%s', '%s', NOW())", szName, szSteamId)
	SQL_ThreadQuery(g_sqlTuple, "QueryHandler", szQuery)
	
	g_bHasAccount[id] = true
	
	client_print(id, print_chat, "[BANK] Your account has been created successfully.")
	
	return PLUGIN_HANDLED
}

public bank_balance(id)
{
	if(g_bHasAccount[id])
	{
		update_name(id)
		
		new data[1]
		data[0] = id
		
		new szSteamId[33]
		get_user_authid(id, szSteamId, 32)
		
		new szQuery[100]
		
		formatex(szQuery, 99, "SELECT `balance` FROM `bank_users` WHERE `steam_id` = '%s'", szSteamId)
		SQL_ThreadQuery(g_sqlTuple, "BalanceHandler", szQuery, data, 1)
		
		return PLUGIN_HANDLED
	}
	else
	{
		client_print(id, print_chat, "[BANK] You don't have an account, create one by typing /openaccount in chat.")
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_HANDLED
}

public set_balance(id, iBalanceChange)
{
	new steamId[33]
	get_user_authid(id, steamId, 32)
	
	new szQuery[100]
	
	formatex(szQuery, 99, "UPDATE `bank_users` SET `balance` = balance + %i WHERE `steam_id` = '%s'", iBalanceChange, steamId)
	SQL_ThreadQuery(g_sqlTuple, "QueryHandler", szQuery)
	
	return PLUGIN_HANDLED
}

public update_name(id)
{
	new szName[33], szSteamId[33]
	get_user_name(id, szName, 32)
	get_user_authid(id, szSteamId, 32)
	
	new szQuery[100] 
	formatex(szQuery, 99, "UPDATE `bank_users` SET `username` = '%s' WHERE `steam_id` = '%s'", szName, szSteamId)
	SQL_ThreadQuery(g_sqlTuple, "QueryHandler", szQuery)
	
	return PLUGIN_HANDLED
}

public QueryHandler(failState, Handle:query, error[], errcode, data[], dataSize)
{	
	GetQueryState(failState, errcode, error)
	
	return PLUGIN_CONTINUE
}
/*
public bank_help(id)
{
	new szHelpPage[200]
	get_cvar_string("bank_helppage", szHelpPage, 199)
	
	show_motd(id, szHelpPage)
}
*/
/*
public get_balance(id)
{
	new errorCode
	new Handle:sqlConnection = SQL_Connect(g_sqlTuple, errorCode, g_szError, 511)
	if(sqlConnection == Empty_Handle)
		set_fail_state(g_szError)
	
	new steamId[33]
	get_user_authid(id, steamId, 32)
	
	new Handle:query = SQL_PrepareQuery(sqlConnection, "SELECT `balance` FROM `bank_users` WHERE `steam_id` = '%s'", steamId)
	
	if(!SQL_Execute(query))
	{
		SQL_QueryError(query,g_szError,511)
		set_fail_state(g_szError)
	}
	
	new balance = SQL_ReadResult(query, 0)
	
	SQL_FreeHandle(query)
	
	update_name(id)
	
	SQL_FreeHandle(sqlConnection)
	
	return balance
}
*/
// Extras...
/*public bank_menu(id)
{
new menu = menu_create("[PROTOTYPE] Bank Menu", "menu_handler")

if(g_bHasAccount[id] == false)
	menu_additem(menu, "Create account", "1", -1)
else
{
menu_additem(menu, "Check balance",		"2", -1)
menu_addblank(menu, 0)
menu_additem(menu, "Withdraw money",	"3", -1)
menu_additem(menu, "Withdraw maximum",	"4", -1)
menu_addblank(menu, 0)
menu_additem(menu, "Deposit money",		"5", -1)
menu_additem(menu, "Deposit maximum",	"6", -1)
menu_addblank(menu, 0)
menu_additem(menu, "Bank Help",			"7", -1)
}

menu_setprop(menu, MPROP_EXIT, MEXIT_ALL)

menu_display(id, menu, 0)

return PLUGIN_HANDLED
}

public menu_handler(id, menu, item)
{
if(item == MENU_EXIT)
{
menu_destroy(menu)
return PLUGIN_HANDLED
}

new data[6], iName[64]
new access, callback

menu_item_getinfo(menu, item, access, data,5, iName, 63, callback)

new key = str_to_num(data)

switch(key)
{
case 1:
{
bank_create(id)
client_print(id, print_chat, "[BANK] Your account has been created successfully.");

menu_destroy(menu)
return PLUGIN_HANDLED
}
case 2:
{
new balance = get_balance(id)
client_print(id, print_chat, "[BANK] You have $%i in your account.", balance)

menu_destroy(menu)
return PLUGIN_HANDLED
}
case 3:
{
client_print(id, print_chat, "[BANK] Please enter the amount you wish to withdraw.")
client_cmd(id, "messagemode")

menu_destroy(menu)
return PLUGIN_HANDLED
}
case 4:
{
withdraw_maximum(id)

menu_destroy(menu)
return PLUGIN_HANDLED
}
case 5:
{
client_print(id, print_chat, "[BANK] Please enter the amount you wish to deposit.")
client_cmd(id, "messagemode")

menu_destroy(menu)
return PLUGIN_HANDLED
}
case 6:
{
deposit_maximum(id)

menu_destroy(menu)
return PLUGIN_HANDLED
}
case 7:
{
bank_help(id)

menu_destroy(menu)
return PLUGIN_HANDLED	
}
}

menu_destroy(menu)
return PLUGIN_HANDLED
}*/
/*public bank_richlist(id)
{
new szRichListPage[200]
get_cvar_string("bank_richlistpage", szRichListPage, 199)

show_motd(id, szRichListPage)
}*/
/*public get_userid(id)
{
new errorCode
new Handle:sqlConnection = SQL_Connect(g_sqlTuple, errorCode, g_szError, 511)
if(sqlConnection == Empty_Handle)
	set_fail_state(g_szError)

new szSteamId[33]
get_user_authid(id, szSteamId, 32)

new Handle:query = SQL_PrepareQuery(sqlConnection, "SELECT `userId` FROM `bank_users` WHERE `userSteamId` = '%s'", szSteamId)

if(!SQL_Execute(query))
{
SQL_QueryError(query,g_szError,511)
set_fail_state(g_szError)
}

new iUserId = SQL_ReadResult(query, 0)

SQL_FreeHandle(query)
SQL_FreeHandle(sqlConnection)

return iUserId
}*/
/*public enter_lottery(id)
{
if(g_bHasAccount[id])
{
new errorCode
new Handle:sqlConnection = SQL_Connect(g_sqlTuple, errorCode, g_szError, 511)
if(sqlConnection == Empty_Handle)
	set_fail_state(g_szError)

new Handle:query = SQL_PrepareQuery(sqlConnection, "SELECT `drawId` FROM `bank_lottery_draws` ORDER BY `drawId` DESC LIMIT 1")

if(!SQL_Execute(query))
{
SQL_QueryError(query,g_szError,511)
set_fail_state(g_szError)
}

new iDrawId = SQL_ReadResult(query, 0)

SQL_FreeHandle(query)

new iUserId = get_userid(id)

new Handle:query2 = SQL_PrepareQuery(sqlConnection, "SELECT `drawId` FROM `bank_lottery_entries` WHERE `drawId` = %i AND `userId` = %i", iDrawId, iUserId)

new iNumResults = SQL_NumResults(query2)

SQL_FreeHandle(query2)

if(iNumResults < 0)
{
new iBalance = get_balance(id)
if(iBalance < 20000)
{
client_print(id, print_chat, "[BANK] Sorry, you need $20,000 in your account to enter the lottery.")
return PLUGIN_HANDLED
}
else
{
query = SQL_PrepareQuery(sqlConnection, "INSERT INTO `bank_lottery_entries` (`userId`, `drawId`) VALUES (%i, %i)", iUserId, iDrawId)

if(!SQL_Execute(query))
{
SQL_QueryError(query,g_szError,511)
set_fail_state(g_szError)
}

SQL_FreeHandle(query)
SQL_FreeHandle(sqlConnection)

client_print(id, print_chat, "[BANK] You have entered the lottery for this week. Good luck!")
set_balance(id, iBalance - 20000)
return PLUGIN_HANDLED
}
}
else
{
client_print(id, print_chat, "[BANK] You have already entered this week's lottery.")
return PLUGIN_HANDLED
}

SQL_FreeHandle(sqlConnection)
return PLUGIN_HANDLED
}
else
{
client_print(id, print_chat, "[BANK] You need a bank account in order to enter the lottery, create one by typing /openaccount in chat.")
return PLUGIN_HANDLED
}
return PLUGIN_HANDLED	
}*/