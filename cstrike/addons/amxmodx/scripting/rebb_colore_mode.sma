#pragma semicolon 1

#include <amxmodx>
#include <re_basebuilder>

new const VERSION[] = "0.0.1 Alpha";

// List of client commands that open select color menu
new const COLOR_MENU_CMDS[][] = {
    "say /color",
    "say_team /color"
};

enum any:COLOR_ENUM {
    DEFAULT,
    RED,
    PINK,
    ORANGE,
    YELLOW,
    PURPLE,
    INDIGO,
    BLACK,
    GREEN,
    BLUE,
    AQUA,
    LIME,
    GOLD,
    DARK_RED,
    TEAL,
    NAVY,
    ORANGE_RED
};

new const Float:g_fBlockColor[COLOR_ENUM][] = {
    { 000.0, 150.0, 000.0 },
    { 255.0, 0.0, 0.0 },
    { 255.0, 20.0, 147.0 },
    { 255.0, 165.0, 0.0 },
    { 255.0, 255.0, 0.0 },
    { 128.0, 0.0, 128.0 },
    { 75.0, 0.0, 130.0 },
    { 0.0, 0.0, 0.0 },
    { 0.0, 128.0, 0.0 },
    { 0.0, 0.0, 255.0 },
    { 0.0, 255.0, 255.0 },
    { 0.0, 255.0, 0.0 },
    { 255.0, 215.0, 0.0 },
    { 139.0, 0.0, 0.0 },
    { 0.0, 128.0, 128.0 },
    { 0.0, 0.0, 128.0 },
    { 255.0, 69.0, 0.0 }
};

new const g_szColorName[COLOR_ENUM][] =  {
    "Default",
    "Red",
    "Pink",
    "Orange",
    "Yellow",
    "Purple",
    "Indigo",
    "Black",
    "Green",
    "Blue",
    "Aqua",
    "Lime",
    "Gold",
    "Dark Red",
    "Teal",
    "Navy",
    "Orange Red"
};

new g_pColorOwner[COLOR_ENUM];
new g_iPlayerColor[MAX_PLAYERS +1];

public plugin_init() {
    register_plugin("[ReBB] Color Mode", VERSION, "ReBB");

    RegisterHookChain(RG_CSGameRules_RestartRound, "CSGameRules_RestartRound_Pre", false);

    for(new i; i < sizeof(COLOR_MENU_CMDS); i++) {
        register_clcmd(COLOR_MENU_CMDS[i], "Color_Menu");
    }
}

public client_disconnected(id) {
    g_pColorOwner[g_iPlayerColor[id]] = 0;
    g_iPlayerColor[id] = 0;
}

public CSGameRules_RestartRound_Pre() {
    arrayset(g_pColorOwner, 0, sizeof(g_pColorOwner));
    arrayset(g_iPlayerColor, 0, sizeof(g_iPlayerColor));
}

public rebb_grab_post(id, iEnt) {
    set_entvar(iEnt, var_rendermode, kRenderTransColor);
    set_entvar(iEnt, var_rendercolor, g_fBlockColor[g_iPlayerColor[id]]);
    set_entvar(iEnt, var_renderamt, 100.0);
}

public rebb_drop_pre(id, iEnt) {
    set_entvar(iEnt, var_rendermode, kRenderNormal);
}

public Color_Menu(id){
    if(rebb_is_zombies_released() || is_user_zombie(id)) {
        return PLUGIN_HANDLED;
    }

    new menu = menu_create(fmt("%L", LANG_PLAYER, "REBB_COLOR_MENU"), "Color_Menu_Handler");

    for(new i = 1; i < COLOR_ENUM; i++) {
        if(g_pColorOwner[i]) {
            menu_additem(menu, fmt("\w%s ^t^tВладеет: %n", g_szColorName[i], g_pColorOwner[i]));
        }
        else {
            menu_additem(menu, fmt("\w%s", g_szColorName[i]));
        }
    }

    menu_setprop(menu , MPROP_NEXTNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_NEXT"));
    menu_setprop(menu , MPROP_BACKNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_BACK"));
    menu_setprop(menu , MPROP_EXITNAME, fmt("%L", LANG_PLAYER, "REBB_MENU_EXIT"));
    menu_display(id, menu, 0);

    return PLUGIN_HANDLED;
}

public Color_Menu_Handler(id, menu, item) {
    menu_destroy(menu);

    if(item == MENU_EXIT) {
        return;
    }

    item++; // as we skip first(0) cell with default color at building menu

    if(g_pColorOwner[item] && g_pColorOwner[item] != id) {
        client_print_color(id, print_team_default, "%L ^4%n", LANG_PLAYER, "REBB_COLOR_FAIL", g_szColorName[item], g_pColorOwner[item]);
        Color_Menu(id);
    }
    else {
        g_pColorOwner[item] = id;
        g_iPlayerColor[id] = item;
        client_print_color(id, print_team_default, "%L ^4%s", LANG_PLAYER, "REBB_COLOR_PICK", g_szColorName[item]);
    }
}