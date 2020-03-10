#include <amxmodx>
#include <reapi>
#include <fakemeta>
#include <re_basebuilder>

new const VERSION[] = "0.0.1 Alpha";

new const CONFIG_NAME[] = "rebb_sounds.ini";

#define MAX_BUFFER_LENGTH       128

new const g_SoundKnifeType[][] = {
    "hit1",
    "hit2",
    "hit3",
    "hit4",
    "stab",
    "slash1",
    "slash2",
    "deploy",
    "hitwall"
};

new const g_KnifeSounds[][] = {
    "weapons/knife_hit1.wav",
    "weapons/knife_hit2.wav",
    "weapons/knife_hit3.wav",
    "weapons/knife_hit4.wav", 
    "weapons/knife_stab.wav",
    "weapons/knife_slash1.wav",
    "weapons/knife_slash2.wav",
    "weapons/knife_deploy1.wav",
    "weapons/knife_hitwall1.wav"
};

new const g_SoundOtherType[][] = {
    "build",
    "prep",
    "round_start",
    "infection",
    "block_grab",
    "block_drop"
};

enum (+=1) {
    SectionNone = -1,
    BuildersWin,
    ZombieWin,
    ZombieDeath,
    ZombiePain,
    ZombieKnife,
    Other
};

new Array:g_SoundsBuildersWin, Array:g_SoundsZombieWin, Array:g_SoundsZombieDeath, Array:g_SoundsZombiePain;
new Trie:g_SoundsKeys;
new Trie:g_SoundsZombieKnife, Trie:g_SoundsOther;

new g_NumSoundsBuildersWin, g_NumSoundsZombieWin, g_NumSoundsZombieDeath, g_NumSoundsZombiePain;
new g_Section;
new g_SoundBuffer[64];

public plugin_precache() {
    g_SoundsBuildersWin = ArrayCreate(MAX_RESOURCE_PATH_LENGTH);
    g_SoundsZombieWin = ArrayCreate(MAX_RESOURCE_PATH_LENGTH);
    g_SoundsZombieDeath = ArrayCreate(MAX_RESOURCE_PATH_LENGTH);
    g_SoundsZombiePain = ArrayCreate(MAX_RESOURCE_PATH_LENGTH);

    g_SoundsZombieKnife = TrieCreate();
    g_SoundsOther = TrieCreate();
    g_SoundsKeys = TrieCreate();

    for(new count, size = sizeof(g_SoundKnifeType); count < size; count++) {
        TrieSetCell(g_SoundsKeys, g_SoundKnifeType[count], count);
    }
    for(new count, size = sizeof(g_SoundOtherType); count < size; count++) {
        TrieSetCell(g_SoundsKeys, g_SoundOtherType[count], count);
    }

    new sConfigsDir[PLATFORM_MAX_PATH];
    get_localinfo("amxx_configsdir", sConfigsDir, charsmax(sConfigsDir));
    format(sConfigsDir, charsmax(sConfigsDir), "%s/%s/%s", sConfigsDir, REBB_MOD_DIR_NAME, CONFIG_NAME);

    if(!parseConfigINI(sConfigsDir)) {
        set_fail_state("Fatal parse error '%s' !", sConfigsDir);
    }

    if(g_SoundsBuildersWin) {
        g_NumSoundsBuildersWin = ArraySize(g_SoundsBuildersWin);
    }
        
    if(g_SoundsZombieWin) {
        g_NumSoundsZombieWin = ArraySize(g_SoundsZombieWin);
    }

    if(g_SoundsZombieDeath) {
        g_NumSoundsZombieDeath = ArraySize(g_SoundsZombieDeath);
    }

    if(g_SoundsZombiePain) {
        g_NumSoundsZombiePain = ArraySize(g_SoundsZombiePain);
    }

    TrieDestroy(g_SoundsKeys);
}

public plugin_init() {
    register_plugin("[ReBB] Sounds", VERSION, "ReBB");

    RegisterHooks();
}

public rebb_build_start() {
    TrieGetString(g_SoundsOther, "build", g_SoundBuffer, charsmax(g_SoundBuffer));
    rg_send_audio(0, g_SoundBuffer);
}

public rebb_preparation_start() {
    TrieGetString(g_SoundsOther, "prep", g_SoundBuffer, charsmax(g_SoundBuffer));
    rg_send_audio(0, g_SoundBuffer);
}

public rebb_zombies_released() {
    TrieGetString(g_SoundsOther, "round_start", g_SoundBuffer, charsmax(g_SoundBuffer));
    rg_send_audio(0, g_SoundBuffer);
}

public rebb_grab_pre(id, iEnt) {
    TrieGetString(g_SoundsOther, "block_grab", g_SoundBuffer, charsmax(g_SoundBuffer));
    rg_send_audio(id, g_SoundBuffer);
}

public rebb_drop_pre(id, iEnt) {
    TrieGetString(g_SoundsOther, "block_drop", g_SoundBuffer, charsmax(g_SoundBuffer));
    rg_send_audio(id, g_SoundBuffer);
}

public rebb_infected() {
    TrieGetString(g_SoundsOther, "infection", g_SoundBuffer, charsmax(g_SoundBuffer));
    rg_send_audio(0, g_SoundBuffer);
}

public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event) {
    switch(event) {
        case ROUND_CTS_WIN: {
            rg_send_audio(0, fmt("%a", ArrayGetStringHandle(g_SoundsBuildersWin, random(g_NumSoundsBuildersWin))));
        }
        case ROUND_TERRORISTS_WIN: {
            rg_send_audio(0, fmt("%a", ArrayGetStringHandle(g_SoundsZombieWin, random(g_NumSoundsZombieWin))));
        }
        case ROUND_GAME_OVER: {
            rg_send_audio(0, fmt("%a", ArrayGetStringHandle(g_SoundsBuildersWin, random(g_NumSoundsBuildersWin))));
        }
    }
}

public SV_StartSound_Pre(const recipients, const entity, const channel, const sample[], const volume, Float:attenuation, const fFlags, const pitch) {
    if(IsPlayer(entity)) {
        if(IsZombie(entity)) {
            new szSound[64];
            if(sample[0] == 'w' && sample[8] == 'k' && sample[13] == '_') {
                TrieGetString(g_SoundsZombieKnife, sample, szSound, charsmax(szSound));
            }
            if(g_NumSoundsZombieDeath){
                if(sample[7] == 'd' && sample[8] == 'i' && sample[9] == 'e'){
                    ArrayGetString(g_SoundsZombieDeath, random(g_NumSoundsZombieDeath), szSound, charsmax(szSound));
                }
            }
            if(g_NumSoundsZombiePain){
                if(sample[7] == 'b' && sample[8] == 'h' && sample[9] == 'i' && sample[10] == 't'){
                    ArrayGetString(g_SoundsZombiePain, random(g_NumSoundsZombiePain), szSound, charsmax(szSound));
                }
            }
            SetHookChainArg(4, ATYPE_STRING, szSound);
        }
    }
    return HC_CONTINUE;
}

RegisterHooks() {
    RegisterHookChain(RG_RoundEnd, "RoundEnd_Post", true);
    RegisterHookChain(RH_SV_StartSound, "SV_StartSound_Pre", false);
}

bool:parseConfigINI(const configFile[]) {
    new INIParser:parser = INI_CreateParser();

    if(parser != Invalid_INIParser) {
        INI_SetReaders(parser, "ReadCFGKeyValue", "ReadCFGNewSection");
        INI_ParseFile(parser, configFile);
        INI_DestroyParser(parser);
        return true;
    }

    return false;
}

public bool:ReadCFGNewSection(INIParser:handle, const section[], bool:invalid_tokens, bool:close_bracket) {
    if(!close_bracket) {
        log_amx("Closing bracket was not detected! Current section name is '%s'.", section);
        return false;
    }

    if(equal(section, "builders_win")) {
        g_Section = BuildersWin;
        return true;
    }

    if(equal(section, "zombie_win")) {
        g_Section = ZombieWin;
        return true;
    }

    if(equal(section, "zombie_death")) {
        g_Section = ZombieDeath;
        return true;
    }

    if(equal(section, "zombie_pain")) {
        g_Section = ZombiePain;
        return true;
    }

    if(equal(section, "zombie_knife")) {
        g_Section = ZombieKnife;
        return true;
    }

    if(equal(section, "other")) {
        g_Section = Other;
        return true;
    }

    return false;
}

public bool:ReadCFGKeyValue(INIParser:handle, const key[], const value[]) {
    if(g_Section == SectionNone || key[0] == EOS) {
        return false;
    }

    static buffer[MAX_BUFFER_LENGTH], keyid;
    formatex(buffer, charsmax(buffer), "%s", key);
    switch(g_Section) {
        case BuildersWin: {
                ArrayPushString(g_SoundsBuildersWin, buffer);
                engfunc(EngFunc_PrecacheSound, buffer);
        }
        case ZombieWin: {
                ArrayPushString(g_SoundsZombieWin, buffer);
                engfunc(EngFunc_PrecacheSound, buffer);
        }
        case ZombieDeath: {
                ArrayPushString(g_SoundsZombieDeath, buffer);
                engfunc(EngFunc_PrecacheSound, buffer);
        }
        case ZombiePain: {
                ArrayPushString(g_SoundsZombiePain, buffer);
                engfunc(EngFunc_PrecacheSound, buffer);
        }
        case ZombieKnife: {
            if(TrieGetCell(g_SoundsKeys, key, keyid)) {
                formatex(buffer, charsmax(buffer), "%s", value);
                TrieSetString(g_SoundsZombieKnife, g_KnifeSounds[keyid], buffer);
                engfunc(EngFunc_PrecacheSound, buffer);
            }
        }
        case Other: {
             formatex(buffer, charsmax(buffer), "%s", value);
             TrieSetString(g_SoundsOther, key, buffer);
             engfunc(EngFunc_PrecacheSound, buffer);
        }
    }

    return true;
}
