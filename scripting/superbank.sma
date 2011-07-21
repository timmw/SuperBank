#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <sqlx>

#define PLUGIN   	"SuperBank"
#define AUTHOR		"timmw"
#define VERSION		"0.3.0"

#define SQL_HOST		""
#define SQL_USER		""
#define SQL_PASS		""
#define SQL_DATABASE	""

/*	--- TABLE SQL --------------------------------------------------
 	
 	- Users Table
 
 	CREATE TABLE IF NOT EXISTS `bank_users`
 	(
 		`id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, 
		`username` VARCHAR(32) NOT NULL, 
		`steam_id` VARCHAR(32) NOT NULL,
		`balance` BIGINT UNSIGNED NOT NULL DEFAULT 0, 
		`date_opened` DATETIME NOT NULL, 
 		`access` TINYINT(1) NOT NULL DEFAULT 0,
		PRIMARY KEY(`id`),
 		UNIQUE(`steam_id`)
	)
 	
 	- Lottery Draws Table (not currently in use)
 	
 	CREATE TABLE IF NOT EXISTS `bank_lottery_draws`
 	(
 		`drawId` INT(5) UNSIGNED AUTO_INCREMENT NOT NULL,
 		`drawDate` DATETIME NOT NULL,
 		PRIMARY KEY(`drawId`)
 	)
 
	- Lottery Entries Table (not currently in use)
 
 	CREATE TABLE IF NOT EXISTS `bank_lottery_entries`
 	(
 		`userId` INT(10) UNSIGNED NOT NULL,
		`drawId` INT(5) UNSIGNED NOT NULL, 
 		FOREIGN KEY(`userId`) REFERENCES `bank_users`(`userId`),
 		FOREIGN KEY(`drawId`) REFERENCES `bank_lottery_draws`(`drawId`),
 		PRIMARY KEY(`drawId`, `userId`)
 	)
 
 	NOTES -------------------------------------------------------
 
 	User name is updated on client connect, every time a user checks/alters
     their balance and when they disconnect.
 
     Max. balance is $18,446,744,073,709,551,615 ($18.4 quintillion).
 
 	CMD List ----------------------------------------------------
 	
 	say /bankhelp
 	say /bankinfo
 	say /openaccount
 	say /balance
 	say /moneywithdrawn
 	say /deposit <amount>
 	say /withdraw <amount>
 	say /maxdep
 	say /maxwit
 	maxdep
 	maxwit
*/

// The handle for the database tuple
new Handle:g_sqlTuple

// How many rounds have past
new g_iRound = 0

// Array storing whether each player has an account or not
new bool:g_bHasAccount[33] = false

// Array storing how much each player has withdrawn so far this round
new g_iMoneyWithdrawn[33] = 0

// File cahces
new g_richlistCache[1000] = ""
new g_bankinfoCache[1000] = ""
new g_bankhelpCache[1200] = ""
new g_cssCache[256] = ""

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Cvars
	
	register_cvar("bank_offrounds", 	"3")
	register_cvar("bank_withdrawlimit", "10000")
	
	register_cvar("amx_sql_host", 	SQL_HOST)
	register_cvar("amx_sql_user", 	SQL_USER)
	register_cvar("amx_sql_pass", 	SQL_PASS)
	register_cvar("amx_sql_db",		SQL_DATABASE)
	
	new configsDir[64]
	get_configsdir(configsDir, 63)
	
	server_cmd("exec %s/sql.cfg", configsDir)
	
	// Client commands
	
	register_clcmd("say /openaccount",			"bank_create",      -1, "Creates a bank account.")
	register_clcmd("say_team /openaccount",		"bank_create",      -1, "Creates a bank account.")
	
	register_clcmd("say /balance",				"bank_balance",     -1, "Displays your balance.")
	register_clcmd("say_team /balance",			"bank_balance",     -1, "Displays your balance.")
	
	register_clcmd("say /moneywithdrawn",		"money_withdrawn",  -1, "Shows how much you've withdrawn this round.")
	register_clcmd("say_team /moneywithdrawn",	"money_withdrawn",  -1, "Shows how much you've withdrawn this round.")
	
	register_clcmd("say /maxdep",				"deposit_maximum",  -1, "Deposits all of your cash.")
	register_clcmd("say_team /maxdep",			"deposit_maximum",  -1, "Deposits all of your cash.")
	
	register_clcmd("say /maxwit", 				"withdraw_maximum", -1, "Withdraw cash until limit reached.")
	register_clcmd("say_team /maxwit",			"withdraw_maximum", -1, "Withdraw cash until limit reached.")
	
	register_clcmd("maxdep",					"deposit_maximum",  -1, "Deposits all of your cash.")
	register_clcmd("maxwit",					"withdraw_maximum", -1, "Withdraw cash until limit reached.")
	
	register_clcmd("say",						"say_handler",      -1)
	register_clcmd("say_team",					"say_handler",      -1)
	
	register_clcmd("say /bankinfo", 			"bank_info",		-1, "Show the player a motd with info about bank.")
	register_clcmd("say_team /bankinfo", 		"bank_info",		-1, "Show the player a motd with info about bank.")
	
	register_clcmd("say /bankhelp",       		"bank_help",       	-1, "Displays the bank help motd.")
	register_clcmd("say_team /bankhelp",		"bank_help",       	-1, "Displays the bank help motd.")
	
	register_clcmd("say /richlist",				"bank_richlist",	-1, "Displays the richest players motd.")
	register_clcmd("say_team /richlist",		"bank_richlist",	-1, "Displays the richest players motd.")
	
	// Currently unused client commands
	
	//register_clcmd("say /enterlottery",   "enter_lottery",	-1, 
	//    "Enters you into the lottery for this week.")
	
	// Log events
	
	register_logevent("event_round_start", 2, "0=World triggered", "1=Round_Start")
	//register_logevent("event_round_end", 2, "0=World triggered", "1=Round_End")
}

public plugin_cfg()
{
	g_sqlTuple = SQL_MakeStdTuple()
	
	new szQuery[354]
	
	formatex(szQuery, 353, "CREATE TABLE IF NOT EXISTS `bank_users`\
	(\
	`id` INT(10) UNSIGNED NOT NULL AUTO_INCREMENT, \
	`username` VARCHAR(32) NOT NULL, \
	`steam_id` VARCHAR(32) NOT NULL,\
	`balance` BIGINT UNSIGNED NOT NULL DEFAULT 0, \
	`date_opened` DATETIME NOT NULL, \
	`access` TINYINT(1) NOT NULL DEFAULT 0,\
	PRIMARY KEY(`id`),\
	UNIQUE(`steam_id`)\
	) ENGINE = InnoDB")
	
	// Automatically create the bank_users table if it doesn't already exist
	SQL_ThreadQuery(g_sqlTuple, "CreateTableHandler", szQuery)
	
	return PLUGIN_HANDLED
}


public bank_help(id)
{
	if(equal(g_bankhelpCache, ""))
	{		
		new bankhelpFilePath[128]
		get_configsdir(bankhelpFilePath, 127)
		format(bankhelpFilePath, 127, "%s/superbank/bank_help.html", bankhelpFilePath)
		
		new line = 0, textline[256], len
		while((line = read_file(bankhelpFilePath, line, textline, 255, len)))
		{
			add(g_bankhelpCache, 1199, textline)
		}
		
		update_css()
		
		replace(g_bankhelpCache, 1199, "{styles}", g_cssCache)
		
		log_amx("Bank help cache file created.")
	}
	
	show_motd(id, g_bankhelpCache, "[BANK] Help")
}

public bank_info(id)
{
	new data[1]
	data[0] = id
	
	SQL_ThreadQuery(g_sqlTuple, "bank_info_handler", "SELECT COUNT(`id`), SUM(`balance`) FROM `bank_users`", data, 1)
}

public bank_info_handler(failState, Handle:query, error[], errcode, data[], dataSize)
{
	GetQueryState(failState, errcode, error)
	new id = data[0]
	
	new iNumAccounts = SQL_ReadResult(query, 0), szNumAccounts[32]
	new iTotalMoney = SQL_ReadResult(query, 1), szTotalMoney[32]
	
	num_to_str(iNumAccounts, szNumAccounts, 31)
	num_to_str(iTotalMoney, szTotalMoney, 31)
	
	// If the bank info cache is empty, cache the template file
	if(equal(g_bankinfoCache, ""))
	{
		new bankinfoFilePath[128]
		
		get_configsdir(bankinfoFilePath, 127)
		format(bankinfoFilePath, 63, "%s/superbank/bank_info.html", bankinfoFilePath)
		
		new line = 0, textline[256], len
		
		while((line = read_file(bankinfoFilePath, line, textline, 255, len)))
		{
			add(g_bankinfoCache, 999, textline)
		}
		
		update_css()
		replace(g_bankinfoCache, 1199, "{styles}", g_cssCache)
		
		log_amx("Bank info cache file created.")
	}
	
	new bankinfo[1000]
	copy(bankinfo, 999, g_bankinfoCache)
	
	replace_all(bankinfo, 499, "{total_players}", szNumAccounts)
	replace_all(bankinfo, 499, "{total_balance}", szTotalMoney)
	
	show_motd(id, bankinfo, "[BANK] Info")
}
/**
* Handle to create table automatically
*/
public CreateTableHandler(failState, Handle:query, error[], errcode)
{
	GetQueryState(failState, errcode, error)
	
	server_print("[BANK] Create table query success bank_users table exists or was created.")
	
	return PLUGIN_CONTINUE
}

/**
 * Check whether the player has an account in the database
 */
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

/**
 * Function to check if the query or connection has failed
 */
public GetQueryState(failState, errcode, error[])
{
	if(failState == TQUERY_CONNECT_FAILED)
	{
		log_amx("Could not connect to database: %s", error)
		return set_fail_state("Could not connect to SQL database.")
	}
	else if(failState == TQUERY_QUERY_FAILED)
	{
		log_amx("Query failed: %s", error)
		return set_fail_state("Query failed.")
	}
	
	if(errcode)
	{
		log_amx("Error on query: %s", error)
	}
	
	return PLUGIN_CONTINUE
}

/**
* Handler for checking if the user has an account
*/
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

/**
* Check if the player typed /deposit or/withdraw
*/
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

/**
* Withdraw as much from the player's account as they are allowed
*/
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
	
	new szQuery[89]
	
	formatex(szQuery, 88, "SELECT `balance` FROM `bank_users` WHERE `steam_id` = '%s'", steamId)
	SQL_ThreadQuery(g_sqlTuple, "BalanceHandler", szQuery, data, 3)
	
	return PLUGIN_HANDLED
}

/**
* Withdraw money from the account
*/
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

/**
* Handler for queries which do require a result
*/
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

/**
* Deposit all of the player's cash into their account
*/
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

/**
* Deposit money into the player's account
*/
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

/**
* Show the player how much they have withdrawn so far this round
*/

public money_withdrawn(id)
{
	if(g_bHasAccount[id])
	{
		update_name(id)
		
		new szWithdrawLimit[6]
		get_cvar_string("bank_withdrawlimit", szWithdrawLimit, 5)
		new iWithdrawLimit = str_to_num(szWithdrawLimit)
		
		if(iWithdrawLimit <= 0)
		{
			client_print(id, print_chat, "[BANK] You have withdrawn $%i so far this round.", g_iMoneyWithdrawn[id])
		}
		else
		{
			client_print(id, print_chat, "[BANK] You have withdrawn $%i of a possible $%i so far this round.", g_iMoneyWithdrawn[id], iWithdrawLimit)
		}
		
		return PLUGIN_HANDLED
	}
	else
	{
		client_print(id, print_chat, "[BANK] You don't have an account, create one by typing /openaccount in chat.")
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_HANDLED
}

/**
* Create bank account
*/
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
	
	new szQuery[170]
	
	formatex(szQuery, 169, "INSERT INTO `bank_users` (`username`, `steam_id`, `date_opened`) VALUES ('%s', '%s', NOW())", szName, szSteamId)
	SQL_ThreadQuery(g_sqlTuple, "QueryHandler", szQuery)
	
	g_bHasAccount[id] = true
	
	client_print(id, print_chat, "[BANK] Your account has been created successfully.")
	
	return PLUGIN_HANDLED
}

/**
* Display the player's balance in chat
*/
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

/**
* Set the player's balance in the database
*/
public set_balance(id, iBalanceChange)
{
	new steamId[33]
	get_user_authid(id, steamId, 32)
	
	new szQuery[100]
	
	formatex(szQuery, 99, "UPDATE `bank_users` SET `balance` = balance + %i WHERE `steam_id` = '%s'", iBalanceChange, steamId)
	SQL_ThreadQuery(g_sqlTuple, "QueryHandler", szQuery)
	
	return PLUGIN_HANDLED
}

/**
* Update the player's name in the database
*/
public update_name(id)
{
	new szName[33], szSteamId[33]
	get_user_name(id, szName, 32)
	get_user_authid(id, szSteamId, 32)
	
	new szQuery[128] 
	formatex(szQuery, 127, "UPDATE `bank_users` SET `username` = ^"%s^" WHERE `steam_id` = '%s'", szName, szSteamId)
	
	SQL_ThreadQuery(g_sqlTuple, "QueryHandler", szQuery)
	
	return PLUGIN_HANDLED
}

/**
* Used for queries which don't return anything
*/
public QueryHandler(failState, Handle:query, error[], errcode, data[], dataSize)
{
	GetQueryState(failState, errcode, error)
	
	return PLUGIN_CONTINUE
}
	