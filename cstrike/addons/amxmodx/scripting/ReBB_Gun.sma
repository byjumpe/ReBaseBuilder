#pragma semicolon 1

#include <amxmodx>
#include <re_basebuilder>

new const VERSION[] = "0.0.2 Alpha";

new const CONFIG_NAME[] = "rebb_guns_menu.ini";

#define MAX_PRIMARY_WEAPONS           5
#define MAX_SECONDARY_WEAPONS         3

#define EQUIPMENT_NON                 0
#define EQUIPMENT_PRIMARY             1
#define EQUIPMENT_SECONDARY           2

// List of client commands that open weapon menu
new const GUNS_CMDS[][] = {
    "say /guns",
    "say_team /guns"
};

enum _:SECTION_ENUM {
    PRIMARY,
    SECONDARY
};

new const g_szLangMsg[SECTION_ENUM][] = {
    "REBB_PRIMARY_MENU",
    "REBB_SECONDARY_MENU"
};

enum WeaponInfo    {
    WEAPON_NAME[12],
    WEAPON_CLASSNAME[20],
    WeaponIdType: WEAPON_ID,
    WEAPON_BPAMMO,
    WEAPON_COST
};

new g_szPrimaryWeapons[MAX_PRIMARY_WEAPONS +1][WeaponInfo];
new g_szSecondaryWeapons[MAX_SECONDARY_WEAPONS +1][WeaponInfo];

new g_iPrimaryWeapons,
    g_iSecondaryWeapons;

public plugin_init() {
    register_plugin("[ReBB] Guns Menu", VERSION, "ReBB");
    
    if(!rebb_core_is_running()) {
        set_fail_state("Core of mod is not running! No further work with plugin possible!");
    } 

    for(new i; i < sizeof(GUNS_CMDS); i++) {
        register_clcmd(GUNS_CMDS[i], "Guns_Menu");
    }

    ReadGunsFile();
}

ReadGunsFile() {
    new sConfigsDir[PLATFORM_MAX_PATH];
    get_localinfo("amxx_configsdir", sConfigsDir, charsmax(sConfigsDir));
    format(sConfigsDir, charsmax(sConfigsDir), "%s/%s/%s", sConfigsDir, REBB_MOD_DIR_NAME, CONFIG_NAME);

    new iFile = fopen(sConfigsDir, "rt");

    if(!iFile) {
        set_fail_state("File ^"%s^" is not found", sConfigsDir);
    }
    
    new iStrLen, iBlock, iSize, iCount;
        
    new szBuffer[128], szBlock[32];
    new szWeaponName[16], szClassName[16], szBpammo[6], szCost[6];

    new Trie: tGunsList = TrieCreate();
        
    new const szSections[][] = {
        "primary",
        "secondary"
    };
    for(iCount = 0, iSize = sizeof(szSections); iCount < iSize; iCount++) {
            TrieSetCell(tGunsList, szSections[iCount], iCount + 1);
    }
    while(!(feof(iFile))) {
            fgets(iFile, szBuffer, charsmax(szBuffer));
            trim(szBuffer);

            if(!(szBuffer[0]) || szBuffer[0] == ';' || szBuffer[0] == '#') {
                continue;
            }

            iStrLen = strlen(szBuffer);
            
            if(szBuffer[0] == '[' && szBuffer[iStrLen - 1] == ']') {
                
                iBlock = EQUIPMENT_NON;
                
                copyc(szBlock, charsmax(szBlock), szBuffer[1], szBuffer[iStrLen - 1]);
                if(!(TrieGetCell(tGunsList, szBlock, iBlock))) {
                    set_fail_state("File ^"%s^" is not found", szBlock);
                }
                continue;
            }

            switch(iBlock) {
                case EQUIPMENT_PRIMARY: {
                    g_iPrimaryWeapons++;
                    
                    parse(szBuffer, szWeaponName, charsmax(szWeaponName), szClassName, charsmax(szClassName), szBpammo, charsmax(szBpammo), szCost, charsmax(szCost));
                    
                    formatex(g_szPrimaryWeapons[g_iPrimaryWeapons][WEAPON_NAME], charsmax(g_szPrimaryWeapons[][WEAPON_NAME]), szWeaponName);
                    
                    formatex(g_szPrimaryWeapons[g_iPrimaryWeapons][WEAPON_CLASSNAME], charsmax(g_szPrimaryWeapons[][WEAPON_CLASSNAME]), szClassName);

                    g_szPrimaryWeapons[g_iPrimaryWeapons][WEAPON_ID] = rg_get_weapon_info(g_szPrimaryWeapons[g_iPrimaryWeapons][WEAPON_CLASSNAME], WI_ID);
                    g_szPrimaryWeapons[g_iPrimaryWeapons][WEAPON_BPAMMO] = str_to_num(szBpammo);
                    g_szPrimaryWeapons[g_iPrimaryWeapons][WEAPON_COST] = str_to_num(szCost);
                }
                case EQUIPMENT_SECONDARY: {
                    g_iSecondaryWeapons++;
                    
                    parse(szBuffer, szWeaponName, charsmax(szWeaponName), szClassName, charsmax(szClassName), szBpammo, charsmax(szBpammo), szCost, charsmax(szCost));

                    formatex(g_szSecondaryWeapons[g_iSecondaryWeapons][WEAPON_NAME], charsmax(g_szSecondaryWeapons[][WEAPON_NAME]), szWeaponName);
                    
                    formatex(g_szSecondaryWeapons[g_iSecondaryWeapons][WEAPON_CLASSNAME], charsmax(g_szSecondaryWeapons[][WEAPON_CLASSNAME]), szClassName);

                    g_szSecondaryWeapons[g_iSecondaryWeapons][WEAPON_ID] = rg_get_weapon_info(g_szSecondaryWeapons[g_iSecondaryWeapons][WEAPON_CLASSNAME], WI_ID);
                    g_szSecondaryWeapons[g_iSecondaryWeapons][WEAPON_BPAMMO] = str_to_num(szBpammo);
                    g_szSecondaryWeapons[g_iSecondaryWeapons][WEAPON_COST] = str_to_num(szCost);
                }
            }
        }
    fclose(iFile);
}

public Guns_Menu(id){
    if(rebb_is_building_phase() || rebb_is_zombies_released() || is_user_zombie(id)) {
        return PLUGIN_HANDLED;
    }

    new menu = menu_create(fmt("%L", LANG_PLAYER, "REBB_GUNS_MENU"), "Guns_Menu_Handler");

    for(new i; i < SECTION_ENUM; i++) {
        menu_additem(menu, fmt("\w%L", LANG_PLAYER, g_szLangMsg[i]));
    }

    menu_setprop(menu , MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_NEXT"));
    menu_setprop(menu , MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_BACK"));
    menu_setprop(menu , MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_EXIT"));
    menu_display(id, menu, 0);

    return PLUGIN_HANDLED;
}

public Guns_Menu_Handler(id, menu, item) {
    menu_destroy(menu);

    if(item == MENU_EXIT) {
        return;
    }

    item++;
    if(rebb_is_building_phase() || rebb_is_zombies_released() || is_user_zombie(id)) {
        return;
    }
    switch(item) {
        case EQUIPMENT_PRIMARY: {
             Primary_Menu(id);
        }
        case EQUIPMENT_SECONDARY: {
             Secondary_Menu(id);
        }
    }
}

public Primary_Menu(id){
    if(rebb_is_building_phase() || rebb_is_zombies_released() || is_user_zombie(id)) {
        return PLUGIN_HANDLED;
    }

    new menu = menu_create(fmt("%L", LANG_PLAYER, "REBB_PRIMARY_MENU"), "Primary_Menu_Handler");

    for(new i = 1; i <= g_iPrimaryWeapons; i++) {
        menu_additem(menu, fmt("\w%s \y^t^t%d$", g_szPrimaryWeapons[i][WEAPON_NAME], g_szPrimaryWeapons[i][WEAPON_COST]));
    }

    menu_setprop(menu , MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_NEXT"));
    menu_setprop(menu , MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_BACK"));
    menu_setprop(menu , MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_EXIT"));
    menu_display(id, menu, 0);

    return PLUGIN_HANDLED;
}

public Primary_Menu_Handler(id, menu, item) {
    menu_destroy(menu);

    if(item == MENU_EXIT) {
        return;
    }
    
    item++;
    if(rebb_is_building_phase() || rebb_is_zombies_released() || is_user_zombie(id)) {
        return;
    }

    new iMoney = get_member(id, m_iAccount);
    if(iMoney < g_szPrimaryWeapons[item][WEAPON_COST]){
        client_print_color(id, print_team_red, "^3%L", LANG_PLAYER, "REBB_GUNS_BUY_FAIL");
        return;
    } else {
        rg_give_item(id, g_szPrimaryWeapons[item][WEAPON_CLASSNAME], GT_REPLACE);
        rg_set_user_bpammo(id, g_szPrimaryWeapons[item][WEAPON_ID], g_szPrimaryWeapons[item][WEAPON_BPAMMO]);
        rg_add_account(id, iMoney - g_szPrimaryWeapons[item][WEAPON_COST], AS_SET);
        client_print_color(id, print_team_default, "%L ^4%s", LANG_PLAYER, "REBB_GUNS_BUY_SUCCESS", g_szPrimaryWeapons[item][WEAPON_NAME]);
    }
}

public Secondary_Menu(id){
    if(rebb_is_building_phase() || rebb_is_zombies_released() || is_user_zombie(id)) {
        return PLUGIN_HANDLED;
    }

    new menu = menu_create(fmt("%L", LANG_PLAYER, "REBB_SECONDARY_MENU"), "Secondary_Menu_Handler");

    for(new i = 1; i <= g_iSecondaryWeapons; i++) {
        menu_additem(menu, fmt("\w%s \y^t^t%d$", g_szSecondaryWeapons[i][WEAPON_NAME], g_szSecondaryWeapons[i][WEAPON_COST]));
    }

    menu_setprop(menu , MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_NEXT"));
    menu_setprop(menu , MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_BACK"));
    menu_setprop(menu , MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_EXIT"));
    menu_display(id, menu, 0);

    return PLUGIN_HANDLED;
}

public Secondary_Menu_Handler(id, menu, item) {
    menu_destroy(menu);

    if(item == MENU_EXIT) {
        return;
    }
    
    item++;
    if(rebb_is_building_phase() || rebb_is_zombies_released() || is_user_zombie(id)) {
        return;
    }

    new iMoney = get_member(id, m_iAccount);
    if(iMoney < g_szSecondaryWeapons[item][WEAPON_COST]){
        client_print_color(id, print_team_red, "^3%L", LANG_PLAYER, "REBB_GUNS_BUY_FAIL");
        return;
    } else {
        rg_give_item(id, g_szSecondaryWeapons[item][WEAPON_CLASSNAME], GT_REPLACE);
        rg_set_user_bpammo(id, g_szSecondaryWeapons[item][WEAPON_ID], g_szSecondaryWeapons[item][WEAPON_BPAMMO]);
        rg_add_account(id, iMoney - g_szSecondaryWeapons[item][WEAPON_COST], AS_SET);
        client_print_color(id, print_team_default, "%L ^4%s", LANG_PLAYER, "REBB_GUNS_BUY_SUCCESS", g_szSecondaryWeapons[item][WEAPON_NAME]);
    }
}

public plugin_natives() {
    register_native("rebb_open_guns_menu", "native_open_guns_menu");
}

public native_open_guns_menu(iPlugin, iParams) {
    new id = get_param(1);
    if(!is_user_connected(id)){
        return -1;
    }

    return Guns_Menu(id);
}
