#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <engine>
#include <hamsandwich>


#define PLUGIN  "NPC: Core"
#define VERSION "1.0"
#define AUTHOR  "VINAGHOST"

#define NPC_ID EV_INT_iuser1

#define RPG_INVALID_NPC -1


new Array:g_NpcClassName;
new Array:g_NpcModel;
new Array:g_NpcSpriteTitle;
new g_NpcClassCount


new Float: g_Cooldown[32];

enum _:TOTAL_FORWARDS {
    FW_NPC_THINK = 0,
    FW_NPC_OBJECTCAPS
}
new g_Forwards[TOTAL_FORWARDS]
new g_ForwardResult

public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR);

    RegisterHam(Ham_ObjectCaps, "player", "npc_ObjectCaps", 1 );
    RegisterHam(Ham_Think, "info_target", "npc_Think");

    g_Forwards[FW_NPC_THINK] = CreateMultiForward("rpg_npc_think", ET_CONTINUE, FP_CELL);
    g_Forwards[FW_NPC_OBJECTCAPS] = CreateMultiForward("rpg_npc_objectCaps", ET_CONTINUE, FP_CELL);
}

public plugin_cfg()
{
    g_NpcClassName = ArrayCreate(33);
    g_NpcModel = ArrayCreate(33);
    g_NpcSpriteTitle = ArrayCreate(1);
}
public npc_Think(iEnt)
{
    if(!is_valid_ent(iEnt))
        return;

    ExecuteForward(g_Forwards[FW_NPC_THINK], g_ForwardResult, entity_get_int(iEnt, NPC_ID));

    entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + random_float(5.0, 10.0));
}
public npc_ObjectCaps(id)
{
    if(!is_user_alive(id))
        return;

    if(get_user_button(id) & IN_USE)
    {
        static Float: gametime ; gametime = get_gametime();
        if(gametime - 1.0 > g_Cooldown[id])
        {
            static iTarget, iBody;
            get_user_aiming(id, iTarget, iBody, 75);

            ExecuteForward(g_Forwards[FW_NPC_OBJECTCAPS], g_ForwardResult, entity_get_int(iTarget, NPC_ID) );

            g_Cooldown[id] = gametime;
        }
    }
}
public native_npc_register(plugin_id, num_params)
{
    new name[33]
    get_string(1, name, charsmax(name))

    if (strlen(name) < 1)
    {
        log_error(AMX_ERR_NATIVE, "[RPG] Can't register this NPC Class")
        return RPG_INVALID_NPC;
    }

    new index, npcClass_name[32]
    for (index = 0; index < g_NpcClassCount; index++)
    {
        ArrayGetString(g_NpcClassName, index, npcClass_name, charsmax(npcClass_name));
        if (equali(name, npcClass_name))
        {
            log_error(AMX_ERR_NATIVE, "[RPG] NPC class already registered (%s)", name);
            return RPG_INVALID_NPC;
        }
    }

    ArrayPushString(g_NpcClassName, name);

    new model[33];
    get_string(2, model, charsmax(model));
    new model_path[64];
    formatex(model_path, charsmax(model_path), "models/npc/%s.mdl", model);
    precache_model(model_path);
    ArrayPushString(g_NpcModel, model_path);

    new spriteTitle[33];
    get_string(3, spriteTitle, sizeof(spriteTitle));
    new sprite_path[64];
    formatex(sprite_path, charsmax(sprite_path), "sprites/npc/%s", spriteTitle);
    precache_model(sprite_path);
    ArrayPushString(g_NpcSpriteTitle, sprite_path);

    Load_Npc(g_NpcClassCount);

    g_NpcClassCount++;
    return (g_NpcClassCount - 1);
}
Create_Npc(id, id_npc, Float:flOrigin[3]= { 0.0, 0.0, 0.0 }, Float:flAngle[3]= { 0.0, 0.0, 0.0 } )
{
    new iEnt = create_entity("info_target");

    new className[33];

    ArrayGetString(g_NpcClassName, id_npc, className, sizeof(className));

    entity_set_string(iEnt, EV_SZ_classname, className);

    if(id)
    {
        entity_get_vector(id, EV_VEC_origin, flOrigin);

        entity_set_origin(iEnt, flOrigin);

        flOrigin[2] += 80.0;
        entity_set_origin(id, flOrigin);

        entity_get_vector(id, EV_VEC_angles, flAngle);
        flAngle[0] = 0.0;
        entity_set_vector(iEnt, EV_VEC_angles, flAngle);
    }
    else
    {
        entity_set_origin(iEnt, flOrigin);
        entity_set_vector(iEnt, EV_VEC_angles, flAngle);
    }

    entity_set_float(iEnt, EV_FL_takedamage, 0.0);

    new model[33];
    ArrayGetString(g_NpcModel, id_npc, model, sizeof(model));
    entity_set_model(iEnt, model);


    entity_set_int(iEnt, EV_INT_movetype, MOVETYPE_PUSHSTEP);
    entity_set_int(iEnt, EV_INT_solid, SOLID_BBOX);


    new Float: mins[3] = {-12.0, -12.0, 0.0 }
    new Float: maxs[3] = { 12.0, 12.0, 75.0 }

    entity_set_size(iEnt, mins, maxs);

    entity_set_int(iEnt, NPC_ID, id_npc);

    entity_set_byte(iEnt,EV_BYTE_controller1,125);
    // entity_set_byte(ent,EV_BYTE_controller2,125);
    // entity_set_byte(ent,EV_BYTE_controller3,125);
    // entity_set_byte(ent,EV_BYTE_controller4,125);

    drop_to_floor(iEnt);

    // set_rendering( ent, kRenderFxDistort, 0, 0, 0, kRenderTransAdd, 127 );
    entity_set_float(iEnt, EV_FL_nextthink, get_gametime() + 0.01)
}

Create_Title(id_npc, Float:origin[3]) {
    new iEnt = create_entity("info_target");

    new classNpc[33];
    ArrayGetString(g_NpcClassName, id_npc, classNpc, sizeof(classNpc));
    format(classNpc, charsmax(classNpc), "%s_title", classNpc);
    entity_set_string(iEnt, EV_SZ_classname,  classNpc);
    origin[0] -= 10.0;
    origin[2] += 40.0;
    entity_set_origin(iEnt, origin);
    set_rendering(iEnt, kRenderFxNone, 0, 0, 0, kRenderTransAdd, 255)

    new sprite[33];
    ArrayGetString(g_NpcSpriteTitles, id_npc, sprite, charsmax(sprite));

    new sprite_path[64];
    formatex(sprite_path, charsmax(sprite_path), "sprites/npc/%s", sprite);
    entity_set_model(iEnt, sprite_path);
}
Load_Npc(id_npc)
{
    new szConfigDir[256], szFile[256], szNpcDir[256];

    get_configsdir(szConfigDir, charsmax(szConfigDir));

    new szMapName[33];
    get_mapname(szMapName, charsmax(szMapName));

    new szNpcName[33];
    ArrayGetString(g_NpcClassName, id_npc, szNpcName, charsmax(szNpcName));

    formatex(szNpcDir, charsmax(szNpcDir),"%s/NPC", szConfigDir);
    formatex(szFile, charsmax(szFile),  "%s/%s_%s.cfg", szNpcDir, szMapName, szNpcName);

    if(!dir_exists(szNpcDir))
    {
        mkdir(szNpcDir);
    }

    if(!file_exists(szFile))
    {
        write_file(szFile, "");
    }

    new szFileOrigin[3][32]
    new sOrigin[128], sAngle[128];
    new Float:fOrigin[3], Float:fAngles[3];
    new iLine, iLength, sBuffer[256];

    while(read_file(szFile, iLine++, sBuffer, charsmax(sBuffer), iLength))
    {
        if((sBuffer[0]== ';') || !iLength)
            continue;

        strtok(sBuffer, sOrigin, charsmax(sOrigin), sAngle, charsmax(sAngle), '|', 0);

        parse(sOrigin, szFileOrigin[0], charsmax(szFileOrigin[]), szFileOrigin[1], charsmax(szFileOrigin[]), szFileOrigin[2], charsmax(szFileOrigin[]));

        fOrigin[0] = str_to_float(szFileOrigin[0]);
        fOrigin[1] = str_to_float(szFileOrigin[1]);
        fOrigin[2] = str_to_float(szFileOrigin[2]);

        fAngles[1] = str_to_float(sAngle[1]);

        Create_Npc(0, id_npc, fOrigin, fAngles)
    }
}

Save_Npc(id_npc)
{
    new szConfigsDir[256], szFile[256], szNpcDir[256];

    get_configsdir(szConfigsDir, charsmax(szConfigsDir));

    new szMapName[32];
    get_mapname(szMapName, charsmax(szMapName));

    new szNpcName[33];
    ArrayGetString(g_NpcClassName, id_npc, szNpcName, charsmax(szNpcName));

    formatex(szNpcDir, charsmax(szNpcDir),"%s/NPC", szConfigDir);
    formatex(szFile, charsmax(szFile),  "%s/%s_%s.cfg", szNpcDir, szMapName, szNpcName);

    if(file_exists(szFile))
        delete_file(szFile);

    new iEnt = -1, Float:fEntOrigin[3], Float:fEntAngles[3];
    new sBuffer[256];


    while( ( iEnt = find_ent_by_class(iEnt, szNpcName) ) )
    {
        entity_get_vector(iEnt, EV_VEC_origin, fEntOrigin);
        entity_get_vector(iEnt, EV_VEC_angles, fEntAngles);

        formatex(sBuffer, charsmax(sBuffer), "%s | %d %d %d | %d", floatround(fEntOrigin[0]), floatround(fEntOrigin[1]), floatround(fEntOrigin[2]), floatround(fEntAngles[1]));

        write_file(szFile, sBuffer, -1);

    }

}

stock Util_PlayAnimation(index, sequence, Float: framerate = 1.0)
{
    entity_set_float(index, EV_FL_animtime, get_gametime());
    entity_set_float(index, EV_FL_framerate,  framerate);
    entity_set_float(index, EV_FL_frame, 0.0);
    entity_set_int(index, EV_INT_sequence, sequence);
}
