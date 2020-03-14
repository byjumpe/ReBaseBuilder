#include <amxmodx>
#include <re_basebuilder>

new const VERSION[] = "0.1.2 Alpha";
new const CONFIG_NAME[] = "rebb_sounds.ini";

new const g_DefaultKnifeSounds[][] = {
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

new const g_GameEventsKeys[][] = { 
    "build_event", 
    "prep_event", 
    "round_start", 
    "infection_event"
};

new const g_MiscKeys[][] = { 
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
    GameEvents,
    MiscSound
};

new Array:g_SoundsBuildersWin, Array:g_SoundsZombieWin, Array:g_SoundsZombieDeath, Array:g_SoundsZombiePain;
new Trie:g_SoundsZombieKnife, Trie:g_SoundsZombieKnifeKeys, Trie:g_SoundsGameEvents, Trie:g_SoundsGameEventsKeys, Trie:g_SoundsMisc, Trie:g_SoundsMiscKeys;

new g_BufferInfo[MAX_RESOURCE_PATH_LENGTH];

new g_NumSoundsBuildersWin, g_NumSoundsZombieWin, g_NumSoundsZombieDeath, g_NumSoundsZombiePain;
new g_Section;

#define CONTAIN_WAV_FILE(%1)        (containi(%1, ".wav") != -1)

public plugin_precache() {
    g_SoundsBuildersWin = ArrayCreate(MAX_RESOURCE_PATH_LENGTH);
    g_SoundsZombieWin = ArrayCreate(MAX_RESOURCE_PATH_LENGTH);
    g_SoundsZombieDeath = ArrayCreate(MAX_RESOURCE_PATH_LENGTH);
    g_SoundsZombiePain = ArrayCreate(MAX_RESOURCE_PATH_LENGTH);

    g_SoundsZombieKnife = TrieCreate();
    g_SoundsZombieKnifeKeys = TrieCreate();

    g_SoundsGameEvents = TrieCreate();
    g_SoundsGameEventsKeys = TrieCreate();

    g_SoundsMisc = TrieCreate();
    g_SoundsMiscKeys = TrieCreate();

    new const SoundKnifeKeys[][] = { "hit1", "hit2", "hit3", "hit4", "stab", "slash1", "slash2", "deploy", "hitwall" };
    for(new count, size = sizeof(SoundKnifeKeys); count < size; count++) {
        TrieSetCell(g_SoundsZombieKnifeKeys, SoundKnifeKeys[count], count);
    }

    for(new count, size = sizeof(g_GameEventsKeys); count < size; count++) {
        TrieSetCell(g_SoundsGameEventsKeys, g_GameEventsKeys[count], count);
    }

    for(new count, size = sizeof(g_MiscKeys); count < size; count++) {
        TrieSetCell(g_SoundsMiscKeys, g_MiscKeys[count], count);
    }

    new sConfigsDir[MAX_RESOURCE_PATH_LENGTH];
    get_localinfo("amxx_configsdir", sConfigsDir, charsmax(sConfigsDir));
    format(sConfigsDir, charsmax(sConfigsDir), "%s/%s/%s", sConfigsDir, REBB_MOD_DIR_NAME, CONFIG_NAME);

    if(!file_exists(sConfigsDir)) {
        set_fail_state("File '%s' not found!", sConfigsDir);   
    }

    if(!parseConfigINI(sConfigsDir)) {
        set_fail_state("Fatal parse error!");
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

    TrieDestroy(g_SoundsZombieKnifeKeys);
    TrieDestroy(g_SoundsGameEventsKeys);
    TrieDestroy(g_SoundsMiscKeys);
}

public plugin_init() {
    register_plugin("[ReBB] Sounds", VERSION, "ReBB");
/*
    if(!rebb_core_is_running()) {
        set_fail_state("Core of mod is not running! No further work with plugin possible!");
    }
*/    
    register_message(get_user_msgid("SendAudio"), "MessageHook_SendAudio");

    RegisterHookChain(RH_SV_StartSound, "SV_StartSound_Pre", false);
    RegisterHookChain(RG_RoundEnd, "RoundEnd_Post", true);
}

public rebb_build_start() {
    TrieGetString(g_SoundsGameEvents, "build_event", g_BufferInfo, charsmax(g_BufferInfo));
    rg_send_audio(0, g_BufferInfo);
}

public rebb_preparation_start() {
    TrieGetString(g_SoundsGameEvents, "prep_event", g_BufferInfo, charsmax(g_BufferInfo));
    rg_send_audio(0, g_BufferInfo);
}

public rebb_zombies_released() {
    TrieGetString(g_SoundsGameEvents, "round_start", g_BufferInfo, charsmax(g_BufferInfo));
    rg_send_audio(0, g_BufferInfo);
}

public rebb_infected() {
    TrieGetString(g_SoundsGameEvents, "infection_event", g_BufferInfo, charsmax(g_BufferInfo));
    rg_send_audio(0, g_BufferInfo);
}

public rebb_grab_post(id, iEnt) {
    TrieGetString(g_SoundsMisc, "block_grab", g_BufferInfo, charsmax(g_BufferInfo));
    rg_send_audio(id, g_BufferInfo);
}

public rebb_drop_pre(id, iEnt) {
    TrieGetString(g_SoundsMisc, "block_drop", g_BufferInfo, charsmax(g_BufferInfo));
    rg_send_audio(id, g_BufferInfo);
}

public MessageHook_SendAudio()  {
    new sample[17];
    get_msg_arg_string(2, sample, charsmax(sample));

    if(equal(sample[7], "terwin") || equal(sample[7], "ctwin") || equal(sample[7], "rounddraw")) {   
        return PLUGIN_HANDLED;
    }

    return PLUGIN_CONTINUE;
}

public RoundEnd_Post(WinStatus:status, ScenarioEventEndRound:event) {
    switch(event) {
        case ROUND_HUMANS_WIN: rg_send_audio(0, fmt("%a", ArrayGetStringHandle(g_SoundsBuildersWin, random(g_NumSoundsBuildersWin))));
        case ROUND_ZOMBIES_WIN: rg_send_audio(0, fmt("%a", ArrayGetStringHandle(g_SoundsZombieWin, random(g_NumSoundsZombieWin))));
        case ROUND_GAME_OVER: rg_send_audio(0, fmt("%a", ArrayGetStringHandle(g_SoundsBuildersWin, random(g_NumSoundsBuildersWin))));
    }
}

public SV_StartSound_Pre(const recipients, const entity, const channel, const sample[], const volume, Float:attenuation, const fFlags, const pitch) {
    if(!is_user_authorized(entity)) {
        return HC_CONTINUE;
    }

    if(!is_user_zombie(entity)) {
        return HC_CONTINUE; 
    }

    new sound[MAX_RESOURCE_PATH_LENGTH];
    if(g_SoundsZombieKnife && sample[0] == 'w' && sample[8] == 'k' && sample[13] == '_') {
        TrieGetString(g_SoundsZombieKnife, sample, sound, charsmax(sound));
    }

    if(g_NumSoundsZombieDeath && sample[7] == 'd' && sample[8] == 'i' && sample[9] == 'e'){
        ArrayGetString(g_SoundsZombieDeath, random(g_NumSoundsZombieDeath), sound, charsmax(sound));
    }

    if(g_NumSoundsZombiePain && sample[7] == 'b' && sample[8] == 'h' && sample[9] == 'i' && sample[10] == 't'){
        ArrayGetString(g_SoundsZombiePain, random(g_NumSoundsZombiePain), sound, charsmax(sound));
    }

    if(sound[0] != EOS) {
        SetHookChainArg(4, ATYPE_STRING, sound);
    }

    return HC_CONTINUE;
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
        log_amx("Closing bracket was not detected! Current section name '%s'.", section);
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

    if(equal(section, "game_events")) {
        g_Section = GameEvents;
        return true;
    }

    if(equal(section, "misc_sound")) {
        g_Section = MiscSound;
        return true;
    }

    return false;
}

public bool:ReadCFGKeyValue(INIParser:handle, const key[], const value[]) {
    if(g_Section == SectionNone) {
        return false;
    }

    if(g_Section < ZombieKnife) {
        if(key[0] && !CONTAIN_WAV_FILE(key)) {
            log_amx("Invalid sound file! Parse string '%s'. Only sound files in wav format should be used!", key);
            return false;
        }

        if(file_exists(fmt("sound/%s", key))) {
            precache_sound(key);
        }
    } else {
        if(value[0] && !CONTAIN_WAV_FILE(value)) {
            log_amx("Invalid sound file! Key '%s', value '%s'. Only sound files in wav format should be used!", key, value);
            return false;
        }

        if(file_exists(fmt("sound/%s", value))) {
            precache_sound(value);
        }
    }

    new keyid;
    switch(g_Section) {
        case BuildersWin: ArrayPushString(g_SoundsBuildersWin, key);
        case ZombieWin: ArrayPushString(g_SoundsZombieWin, key);
        case ZombieDeath: ArrayPushString(g_SoundsZombieDeath, key);
        case ZombiePain: ArrayPushString(g_SoundsZombiePain, key);
        case ZombieKnife: {
            if(TrieGetCell(g_SoundsZombieKnifeKeys, key, keyid)) {
                TrieSetString(g_SoundsZombieKnife, g_DefaultKnifeSounds[keyid], value);
            }
        }
        case GameEvents: {
            if(TrieGetCell(g_SoundsGameEventsKeys, key, keyid)) {
                TrieSetString(g_SoundsGameEvents, g_GameEventsKeys[keyid], value);
            }
        }
        case MiscSound: {
            if(TrieGetCell(g_SoundsMiscKeys, key, keyid)) {
                TrieSetString(g_SoundsMisc, g_MiscKeys[keyid], value);
            }
        }
    }

    return true;
}
