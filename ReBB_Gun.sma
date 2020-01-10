#pragma semicolon 1

#include <amxmodx>
#include <reapi>
#include <re_basebuilder>

new const VERSION[] = "0.0.1";

public plugin_init() {
    register_plugin("[ReAPI] Base Builder", VERSION, "ReBB");

    RegisterHookChain(RG_CBasePlayer_OnSpawnEquip, "HC_CBasePlayer_OnSpawnEquip_Post", true);

    set_member_game(m_bTCantBuy, true);
}

public HC_CBasePlayer_OnSpawnEquip_Post(const id, bool:addDefault, bool:equipGame) {
    if(rebb_is_preparation_phase() && IsHuman(id)){
        OpenDefaultBuyMenu(id);
    }
}

OpenDefaultBuyMenu(id) {
    _show_vgui_menu(id, VGUI_Menu_Buy, (MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_0), "#Buy");
    set_member(id, m_iMenu, Menu_Buy);    // for oldstyle menu
}

stock _show_vgui_menu(const index, const any:menu, const keys, text[]) {
    if(get_member(index, m_bVGUIMenus) || menu > any:VGUI_Menu_Buy_Item) {
        static msgVGUIMenu;

        if(!msgVGUIMenu ) {
            msgVGUIMenu = get_user_msgid("VGUIMenu");
        }

        message_begin(index ? MSG_ONE : MSG_ALL, msgVGUIMenu, _, index);
        write_byte(menu);
        write_short(keys);
        write_char(-1);
        write_byte(0);
        write_string(text);
        message_end();
    } else {
        show_menu(index, keys, text);
    }
}
