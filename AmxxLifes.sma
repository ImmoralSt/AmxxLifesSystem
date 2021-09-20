#include <AmxModX>
#include <AmxMisc>
#include <ReApi>
#include <HamSandWich>
#include <sqlx>

new const PLUGIN[][] = {
	"[AMXX] Addon: Life",
	"0.1",
	"Immortal-"
};

enum {
	ADD_BUY = 0,
	ADD_SELL,
	ADD_SPAWNED
};

#define rg_get_user_money(%0) get_member(%0, m_iAccount)
#define is_user_valid(%1) (1 <= %1 <= get_maxplayers())

new	
	Array: g_HostDB,
	Array: g_UserDB,
	Array: g_PasswordDB,
	Array: g_NameDB,
	Array: g_TableDB,
	Array: g_Command,
	Array: g_Text,
	Array: g_AddType,
	Array: g_Buy,
	Array: g_Sell,
	Array: g_Chanse,
	Array: g_Limit;

new const GLOBAL_DIR[] = "lifes";  	
new const FILE[] = "lifes_system.ini"; 

new 
	g_szQuery[512],
	UserSteamID[MAX_PLAYERS + 2][MAX_PLAYERS + 2],
	g_szConfigsDir[256],
	g_iLimit[MAX_PLAYERS + 1],
	g_iLifes[MAX_PLAYERS + 1];

new 
	Handle:MYSQL_Tuple,
	Handle:MYSQL_Connect;

new bool: UserLoaded[MAX_PLAYERS + 1];

public plugin_init() {
	register_plugin(PLUGIN[0], PLUGIN[1], PLUGIN[2]);

	register_dictionary("amxx_lifes.txt")

	g_HostDB = ArrayCreate(256);
	g_UserDB = ArrayCreate(256);
	g_PasswordDB = ArrayCreate(256);
	g_NameDB = ArrayCreate(256);
	g_TableDB = ArrayCreate(256);

	g_Command = ArrayCreate(256);
	g_Text = ArrayCreate(256);
	g_AddType = ArrayCreate(256);
	g_Buy = ArrayCreate(256);
	g_Sell = ArrayCreate(256);
	g_Chanse = ArrayCreate(256);
	g_Limit = ArrayCreate(256);

	get_configsdir(g_szConfigsDir, charsmax(g_szConfigsDir));
	CreateFile();
	ReadFile();	

	new szCommand[128];
	ArrayGetString(g_Command, 0, szCommand,charsmax(szCommand));
	RegisterSayEvent(szCommand, "Show_LifeMenu");

	RegisterHookChain(RG_CBasePlayer_Killed, "CSGameRules_PlayerKilled", .post = true);
	RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound", .post = true);
}

public plugin_cfg() 
	SQL_LoadDebug();

public client_putinserver(iPlayer) 
	LoadData(iPlayer);

public client_disconnected(iPlayer) {	
	if(!UserLoaded[iPlayer]) {
		return
	}
		
	new szTable[128]; ArrayGetString(g_TableDB, 0, szTable, charsmax(szTable));	

	formatex(g_szQuery, charsmax(g_szQuery), "UPDATE `%s` SET `Lifes` = '%d' WHERE `%s`.`SteamID` = '%s';", szTable, g_iLifes[iPlayer], szTable, UserSteamID[iPlayer]);
	SQL_ThreadQuery(MYSQL_Tuple, "SQL_Thread", g_szQuery);
}

public plugin_end() {
	if(MYSQL_Tuple) 
		SQL_FreeHandle(MYSQL_Tuple);
			
	if(MYSQL_Connect) 
		SQL_FreeHandle(MYSQL_Connect);
}

public SQL_LoadDebug() {
	new szError[512];
	new iErrorCode;

	new szHost[128]; ArrayGetString(g_HostDB, 0, szHost, charsmax(szHost));		
	new szUser[128]; ArrayGetString(g_UserDB, 0, szUser, charsmax(szUser));			
	new szPassword[128]; ArrayGetString(g_PasswordDB, 0, szPassword, charsmax(szPassword));
	new szName[128]; ArrayGetString(g_NameDB, 0, szName, charsmax(szName));			
	new szTable[128]; ArrayGetString(g_TableDB, 0, szTable, charsmax(szTable));		
		
	MYSQL_Tuple = SQL_MakeDbTuple(szHost, szUser, szPassword, szName);
	MYSQL_Connect = SQL_Connect(MYSQL_Tuple, iErrorCode, szError, charsmax(szError));
		
	if(MYSQL_Connect == Empty_Handle) {
		set_fail_state(szError);
	}

	if(!SQL_TableExists(MYSQL_Connect, szTable)) {
		new Handle:hQueries;
		new szQuery[512];
			
		formatex( szQuery, charsmax(szQuery), "CREATE TABLE IF NOT EXISTS `%s` (SteamID VARCHAR(32) CHARACTER SET cp1250 COLLATE cp1250_general_ci NOT NULL, Lifes INT NOT NULL, PRIMARY KEY (SteamID))", szTable);
		hQueries = SQL_PrepareQuery(MYSQL_Connect, szQuery);
			
		if(!SQL_Execute(hQueries)) {
			SQL_QueryError(hQueries, szError, charsmax(szError));
			set_fail_state(szError);
		}

		SQL_FreeHandle(hQueries);
		}
	SQL_QueryAndIgnore(MYSQL_Connect, "SET NAMES utf8");
}

public SQL_Query(const iState, Handle: hQuery, szError[], iErrorCode, iParams[], const iParamsSize) {
	switch(iState) {
		case TQUERY_CONNECT_FAILED: log_amx("Load - Could not connect to SQL database. [%d] %s", iErrorCode, szError);
		case TQUERY_QUERY_FAILED: log_amx("Load Query failed. [%d] %s", iErrorCode, szError);
	}
		
	new iPlayer = iParams[0];
	UserLoaded[iPlayer] = true;

	new szTable[128]; ArrayGetString(g_TableDB, 0, szTable, charsmax(szTable));	
		
	if(SQL_NumResults(hQuery) < 1) {
		if(equal(UserSteamID[iPlayer], "ID_PENDING"))
			return PLUGIN_HANDLED;
			
		formatex(g_szQuery, charsmax(g_szQuery), "INSERT INTO `%s` (`SteamID`, `Lifes`) VALUES ('%s', '%d');", szTable, UserSteamID[iPlayer], g_iLifes[iPlayer])
		SQL_ThreadQuery(MYSQL_Tuple, "SQL_Thread", g_szQuery)
			
		return PLUGIN_HANDLED;
	}
	else 
		g_iLifes[iPlayer] = SQL_ReadResult(hQuery, 1);
		
	return PLUGIN_HANDLED;
}

public LoadData(const iPlayer) {
	if(!is_user_connected(iPlayer)) 
		return;
		
	new iParams[1];
	iParams[0] = iPlayer;

	new szTable[128]; ArrayGetString(g_TableDB, 0, szTable, charsmax(szTable));			
		
	get_user_authid(iPlayer, UserSteamID[iPlayer], charsmax(UserSteamID[]));
		
	formatex(g_szQuery, charsmax(g_szQuery), "SELECT * FROM `%s` WHERE (`%s`.`SteamID` = '%s')", szTable, szTable, UserSteamID[iPlayer]);
	SQL_ThreadQuery(MYSQL_Tuple, "SQL_Query", g_szQuery, iParams, sizeof iParams);
}

public SQL_Thread(const iState, Handle: hQuery, szError[], iErrorCode, iParams[], const iParamsSize) {
	if(iState == 0) 
		return;
		
	log_amx("SQL Error: %d (%s)", iErrorCode, szError);
}

public plugin_natives() {
	register_native("amxx_get_user_life", "_amxx_get_user_life", true);
	register_native("amxx_set_user_life", "_amxx_set_user_life", true);
}

public _amxx_get_user_life(const iPlayer) {
	if(!is_user_valid(iPlayer)) {
		log_error(AMX_ERR_NATIVE, "[LIFES] Invalid Player (%d)", iPlayer);
		return -1;
	}

	return g_iLifes[iPlayer];
}

public _amxx_set_user_life(const iPlayer, const iAmount){
	if(!is_user_valid(iPlayer)) 
		return false;

	g_iLifes[iPlayer] = iAmount;

	return true;
}

public CSGameRules_PlayerKilled(const pId, const pKiller, const iGibs) {
	if(!is_user_connected(pId))
		return;

	new iChanse = ArrayGetCell(g_Chanse, 0);
	if(iChanse > 0) {

		if(iChanse > 100) {
			log_to_file("amxx_lifes.log", "[LIFES] Chanse count > 100. Plugin paused!");
			pause("a");
		}

		new iRandom = random_num(0, 100);
		if(iRandom <= iChanse) {
			g_iLifes[pKiller] ++;
			client_print_color(pKiller, print_team_default, "%L", LANG_PLAYER, "GIVE");
		}
	}
}

public CSGameRules_RestartRound() {
	for(new pId = 1; pId < MaxClients; pId++) 
		if(g_iLimit[pId] > 0) 
			g_iLimit[pId] --;
}

public Show_LifeMenu(const pId) {
	new szMenu[MAX_MENU_LENGTH], szNum[6];
	new pMenu = menu_create(fmt("%L", LANG_PLAYER, "MENU_TITLE", g_iLifes[pId]), "LifeMenu__Handler");

	new iAddType;

	for(new iItem; iItem < ArraySize(g_AddType); iItem++) {
		num_to_str(iItem, szNum, charsmax(szNum));

		iAddType = ArrayGetCell(g_AddType, iItem);
		if(iAddType == ADD_BUY || iAddType == ADD_SELL || iAddType == ADD_SPAWNED) {
			ArrayGetString(g_Text, iItem, szMenu, charsmax(szMenu));
			menu_additem(pMenu, szMenu, szNum);
		}
	}

	menu_setprop(pMenu, MPROP_NEXTNAME, "Далее");
	menu_setprop(pMenu, MPROP_BACKNAME, "Назад");
	menu_setprop(pMenu, MPROP_EXITNAME, "Выход");

	menu_setprop(pMenu, MPROP_NUMBER_COLOR, "\r");

	if(is_user_connected(pId))
		menu_display(pId, pMenu);
	
	return PLUGIN_HANDLED;
}

public LifeMenu__Handler(const pId,const pMenu,const pItem) {
	if(pItem == MENU_EXIT)
		return menu_destroy(pMenu);
	
	new iAccess, szData[64], szName[64];
	menu_item_getinfo(pMenu, pItem, iAccess, szData, charsmax(szData), szName, charsmax(szName));
	menu_destroy(pMenu);

	new iAddType = ArrayGetCell(g_AddType, str_to_num(szData));

	new iBuy = ArrayGetCell(g_Buy, str_to_num(szData));

	new iSell = ArrayGetCell(g_Sell, str_to_num(szData));	

	new iLimit = ArrayGetCell(g_Limit, 0);	
	
	if(iAddType == ADD_BUY) {
		if(rg_get_user_money(pId) < iBuy) {
			client_print_color(pId, print_team_default, "%L", LANG_PLAYER, "NO_MONEY");
			return PLUGIN_HANDLED;
		}
		else {
			rg_add_account(pId, rg_get_user_money(pId) - iBuy, AS_SET);
			g_iLifes[pId]++;
			client_print_color(pId, print_team_default, "%L", LANG_PLAYER, "GIVE");
		}
	}
	else if(iAddType == ADD_SELL) {
		if(g_iLifes[pId] <= 0) {
			client_print_color(pId, print_team_default, "%L", LANG_PLAYER, "NO_LIFE");
			return PLUGIN_HANDLED;
		}
		else {
			rg_add_account(pId, rg_get_user_money(pId) + iSell, AS_SET);
			g_iLifes[pId]--;
			client_print_color(pId, print_team_default, "%L", LANG_PLAYER, "SELL");
		}		
	}
	else {
		if(is_user_alive(pId)) {
			client_print_color(pId, print_team_default, "%L", LANG_PLAYER, "ALIVE");
			return PLUGIN_HANDLED;
		}

		if(g_iLifes[pId] <= 0) {
			client_print_color(pId, print_team_default, "%L", LANG_PLAYER, "NO_LIFE");
			return PLUGIN_HANDLED;
		}	

		if(iLimit > 0) {
			if(g_iLimit[pId] >= iLimit) {
				client_print_color(pId, print_team_default, "%L", LANG_PLAYER, "LIMIT");
				return PLUGIN_HANDLED;				
			}
		}	

		ExecuteHamB(Ham_CS_RoundRespawn, pId);
		g_iLifes[pId] --;
		g_iLimit[pId] ++;
	}

	return PLUGIN_CONTINUE;
}

//[ Stock ]
stock bool: SQL_TableExists(Handle: hDataBase, const szTable[]) {
	new Handle: hQuery = SQL_PrepareQuery(hDataBase, "SELECT * FROM information_schema.tables WHERE table_name = '%s' LIMIT 1;", szTable);
	new szError[512];
	
	if(!SQL_Execute(hQuery)) {
		SQL_QueryError(hQuery, szError, charsmax(szError));
		set_fail_state(szError);
	}
	else if( !SQL_NumResults(hQuery)) {
		SQL_FreeHandle(hQuery);
		return false;
	}

	SQL_FreeHandle(hQuery);
	return true;
}

stock CreateFile() {
	new szData[256];

	formatex(szData, charsmax(szData), "%s/%s", g_szConfigsDir, GLOBAL_DIR);

	if(!dir_exists(szData))
		mkdir(szData);
	
	formatex(szData, charsmax(szData), "%s/%s", szData, FILE);

	if(!file_exists(szData))
		write_file(szData,
		";  /*-----[Инструкция]-----*/^n\
		;^n\
		; 	SQL_HOST -- IP от БД.^n\
		; 	SQL_USER -- Имя пользователя от БД.^n\
		; 	SQL_PASS -- Пароль от БД.^n\
		; 	SQL_NAMEDB -- Название БД.^n\
		; 	SQL_TABLE -- Имя таблицы в БД.^n\
		;^n\
		;	MENU_COMMAND -- команда открытия меню^n\
		;		Команду нужно писать без say, say_team, она регистрируется сразу в чат и в консоль!^n\
		;   ADD_TYPE -- Куда записываем:^n\
		;	   ADD_SELL -- В покупку.^n\		
		;	   ADD_BUY -- В продажу.^n\
		;	   ADD_SPAWNED -- Возродится.^n\
		;^n\
		;   MENU_NAME -- Название пункта в меню.^n\
		;	   Если 'ADD_TYPE != MENU', оставить пустым:^n\
		;		   MENU_NAME = ^n\
		;^n\
		;   BUY -- Цена за покупку.^n\
		;^n\
		;   SELL -- Цена за продажу.^n\
		;^n\
		;   CHANSE -- Включить шанс получения жизни при убийстве.^n\
		;	   Если не нужно, оставить пустым.^n\
		;	   В другом случае CHANSE -- Минимальное число выпадения (Не выставлять больше 100!!!).^n\
		;	  	Как это работает? Функция рандома проверяет, если число <= CHANSE, то жизнь выдаст при убийстве игрока.^n\
		;	  	Если число > CHANSE или равно 100, оно не выдаст жизнь при убийстве игрока.^n\
		;^n\
		;   LIMIT -- Лимит использования.^n\
		;	   Если не нужно, оставить пустым. В другом случае, просто напишите цифру, она и будет отвечать, сколько раз можно будет использовать жизнь.^n\
		;^n\   
		;   /*-----[Глобальные Настройки]-----*/^n\
		SQL_HOST = 127.0.0.1^n\
		SQL_USER = root^n\
		SQL_PASS = ^n\
		SQL_NAMEDB = sborka^n\
		SQL_TABLE = lifesys^n^n\
		CHANSE = 25^n\
		LIMIT = 1^n^n\
		;   /*-----[Настройки]-----*/^n\
		MENU_COMMAND = lifes^n^n\
		ADD_TYPE = ADD_BUY^n\
		MENU_NAME = Купить^n\
		BUY = 5^n\
		SELL = ^n^n\
		ADD_TYPE = ADD_SELL^n\
		MENU_NAME = Продать^n\
		BUY = ^n\
		SELL = 5 ^n^n\
		ADD_TYPE = ADD_SPAWNED^n\
		MENU_NAME = Возродится^n\
		BUY = ^n\
		SELL = "
	);
}

stock ReadFile() {
	new szData[256], szFile[256], f;

	formatex(szFile, charsmax(szFile), "%s/%s/%s", g_szConfigsDir, GLOBAL_DIR,FILE);

	f = fopen(szFile, "r");

	new szLeft[256], szRight[256];
	while(!feof(f)) {
		fgets(f, szData, charsmax(szData));
		trim(szData);

		if(!szData[0] || szData[0] == ';' || szData[0] == EOS)
			continue;
		
		strtok(szData, szLeft, charsmax(szLeft), szRight, charsmax(szRight), '=');
		trim(szLeft), trim(szRight);

		if(equal(szLeft, "SQL_HOST"))
			ArrayPushString(g_HostDB, szRight);
		else if(equal(szLeft, "SQL_USER"))
			ArrayPushString(g_UserDB, szRight);		
		else if(equal(szLeft, "SQL_PASS"))
			ArrayPushString(g_PasswordDB, szRight);	
		else if(equal(szLeft, "SQL_NAMEDB"))
			ArrayPushString(g_NameDB, szRight);		
		else if(equal(szLeft, "SQL_TABLE"))
			ArrayPushString(g_TableDB, szRight);										
		else if(equal(szLeft, "MENU_COMMAND"))
			ArrayPushString(g_Command, szRight);
		else if(equal(szLeft, "ADD_TYPE")) {
			if(equal(szRight,"ADD_BUY"))
				ArrayPushCell(g_AddType, ADD_BUY);
			else if(equal(szRight, "ADD_SELL"))
				ArrayPushCell(g_AddType, ADD_SELL);
			else if(equal(szRight, "ADD_SPAWNED"))
				ArrayPushCell(g_AddType, ADD_SPAWNED);
		}
		else if(equal(szLeft, "MENU_NAME"))
			ArrayPushString(g_Text, szRight);
		else if(equal(szLeft, "BUY"))
			ArrayPushCell(g_Buy, str_to_num(szRight));
		else if(equal(szLeft, "SELL"))
			ArrayPushCell(g_Sell, str_to_num(szRight));
		else if(equal(szLeft, "CHANSE"))
			ArrayPushCell(g_Chanse, str_to_num(szRight));
		else if(equal(szLeft, "LIMIT"))
			ArrayPushCell(g_Limit, str_to_num(szRight));

		continue;
	}
	fclose(f);
}

stock RegisterSayEvent(const szCmd[], const szFunc[]) {
	new szData[256];

	formatex(szData, charsmax(szData), "say /%s", szCmd);
	register_clcmd(szData, szFunc);
	formatex(szData, charsmax(szData), "say_team /%s", szCmd);
	register_clcmd(szData, szFunc);
	formatex(szData, charsmax(szData), "%s", szCmd);
	register_clcmd(szData, szFunc);
}