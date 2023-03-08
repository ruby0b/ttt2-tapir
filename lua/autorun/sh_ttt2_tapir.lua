local drowsy_overlay = "vgui/ttt/drowsemy_overlay_v4.png"
local drowsy_icon = "vgui/ttt/status/hud_icon_drowsemy.png"

if SERVER then
    AddCSLuaFile()
    resource.AddFile("sound/touhou/eternal_spring_dream_short.ogg")
    resource.AddFile("materials/" .. drowsy_overlay)
    resource.AddFile("materials/" .. drowsy_icon)
end

local cv_health = CreateConVar("ttt_tapir_health", 400,
    { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "How much health should the tapir have?")
local cv_damage = CreateConVar("ttt_tapir_damage", 4,
    { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "How much damage should the tapir do with its attacks?")
local cv_close = CreateConVar("ttt_tapir_close_distance", 100,
    { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "How closely should the tapir follow its owner? (in hammer units)")
local cv_drowsy_duration = CreateConVar("ttt_tapir_drowsy_duration", 30,
    { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "How long should the drowsiness effect last in seconds? (def: 30, set to 0 to disable)")
local cv_volume = CreateConVar("ttt_tapir_drowsy_volume", 1.0,
    { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "How loud shoud the drowsiness music be? (1.0 means 100%, i.e. the normal volume of the file)")
local cv_audio = CreateConVar("ttt_tapir_drowsy_audio", "touhou/eternal_spring_dream_short.ogg",
    { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "The audio file to play for drowsy players, relative to \"sound/\" (set to empty string to disable) (def: \"touhou/eternal_spring_dream_short.ogg\")")
local cv_audio_length = CreateConVar("ttt_tapir_drowsy_audio_length", 51.25,
    { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "How long does the audio file play in seconds before it should be looped? (def: 51.25)")
local cv_overlay_enable = CreateConVar("ttt_tapir_drowsy_overlay_enable", "1",
    { FCVAR_ARCHIVE, FCVAR_REPLICATED },
    "Should drowsy players have a disorienting screen overlay effect?")

local drowsy_sound_fadeout = 2
local early_fadeout_adjustment = 0.1
local drowsy_status = "tapir_status_drowsy"
local tapir_model = Model("models/tsbb/animals/tapir2.mdl")
local function make_species(name, scale)
    return {
        name = name,
        material = "models/tsbb/animals/tapir2_" .. name .. ".vmt",
        scale = scale or 1
    }
end

local species_list = {
    make_species("baird"), make_species("kabomani"), make_species("lowland"),
    make_species("malayan"), make_species("mountain"), make_species("baby", 0.6)
}
local tapir_ent_class = "npc_antlion"
local sounds_to_stop = {
    "NPC_Antlion.MeleeAttack", "NPC_Antlion.BurrowIn", "NPC_Antlion.BurrowOut",
    "NPC_Antlion.MeleeAttackSingle", "NPC_Antlion.MeleeAttackDouble",
    "NPC_Antlion.Distracted", "NPC_Antlion.Idle", "NPC_Antlion.Pain",
    "NPC_Antlion.JumpTouch", "NPC_Antlion.Land", "NPC_Antlion.WingsOpen",
    "NPC_Antlion.LoopingAgitated", "NPC_Antlion.RunOverByVehicle",
    "NPC_Antlion.Voice", "NPC_Antlion.Heal"
}
local priority_normal, priority_high, priority_highest = 2, 3, 4

if CLIENT then
    hook.Add("Initialize", "tapir_status_Initialize", function()
        STATUS:RegisterStatus(drowsy_status,
            { hud = Material(drowsy_icon), type = "bad" })
    end)

    hook.Add("RenderScreenspaceEffects", "tapir_drowsy_overlay", function()
        if STATUS:Active(drowsy_status) and cv_overlay_enable:GetBool() then
            DrawMaterialOverlay(drowsy_overlay, 0)
        end
    end)

    local _loaded_music = nil
    local function get_music()
        if not _loaded_music and IsValid(LocalPlayer()) then
            local audio_path = cv_audio:GetString()
            if not audio_path or audio_path == "" then return end
            _loaded_music = CreateSound(LocalPlayer(), audio_path)
            _loaded_music:Stop()
        end
        return _loaded_music
    end

    local loop = nil
    hook.Add("Think", "tapir_drowsy_sound_Think", function()
        local music = get_music()
        if not music then return end
        local playing = music:IsPlaying()
        local status = STATUS.active[drowsy_status]
        local time_left = (status and status.displaytime - CurTime()) or 0
        if not playing and time_left > 0 then
            music:PlayEx(cv_volume:GetFloat(), 100)
            loop = CurTime() + cv_audio_length:GetFloat()
        elseif (playing and time_left <= 0) or (loop and CurTime() >= loop) then
            music:Stop()
        elseif playing then
            local fadeout_factor = math.Clamp(
                (time_left - early_fadeout_adjustment) / drowsy_sound_fadeout,
                0, 1
            )
            local volume = cv_volume:GetFloat() * fadeout_factor
            if music:GetVolume() ~= volume then
                music:ChangeVolume(volume)
            end
        end
    end)

    -- Prevent the sound from stopping (e.g. when alt-tabbing) by slighly altering the volume periodically.
    -- This will restart the sound somehow (idk why??) but it prevents people from stopping the sound altogether.
    timer.Create("tapir_drowsy_sound_random_volume", 2.1, 0, function()
        local music = get_music()
        if not music or not music:IsPlaying() then return end
        local volume = math.Clamp(
            music:GetVolume() - (CurTime() % 1) / 10000,
            0, 1
        )
        music:ChangeVolume(volume)
    end)
end

if SERVER then
    local function get_all_tapir_parents()
        local parents = {}
        local potential_parents = ents.FindByClass(tapir_ent_class)
        for _, npc in ipairs(potential_parents) do
            if IsValid(npc) and npc.tapir_owner then
                parents[#parents + 1] = npc
            end
        end
        return parents
    end

    local function make_drowsy(ply)
        local duration = cv_drowsy_duration:GetFloat()
        if duration <= 0 then return end
        ply.tapir_drowsy_until = CurTime() + duration
        STATUS:AddTimedStatus(ply, drowsy_status, duration, true)
    end

    local function spawn_npc(class, pos)
        local npc_list = list.Get("NPC")
        local npc_data = npc_list[class]

        local npc = ents.Create(npc_data.Class)
        if not IsValid(npc) then return end

        npc:SetPos(pos)

        if npc_data.Model then npc:SetModel(npc_data.Model) end

        local SpawnFlags = bit.bor(SF_NPC_FADE_CORPSE, SF_NPC_ALWAYSTHINK)
        if npc_data.SpawnFlags then
            SpawnFlags = bit.bor(SpawnFlags, npc_data.SpawnFlags)
        end
        if npc_data.TotalSpawnFlags then
            SpawnFlags = npc_data.TotalSpawnFlags
        end
        npc:SetKeyValue("spawnflags", SpawnFlags)

        if npc_data.KeyValues then
            for k, v in pairs(npc_data.KeyValues) do
                npc:SetKeyValue(k, v)
            end
        end

        if npc_data.Skin then npc:SetSkin(npc_data.Skin) end

        npc:Spawn()
        npc:Activate()
        return npc
    end

    function SpawnTapir(ply)
        local species = species_list[math.random(#species_list)]
        local pos = ply:EyePos() + (80 * ply:EyeAngles():Forward())

        -- Create an invisible and (mostly) silent parent entity to control the AI
        local parent = spawn_npc(tapir_ent_class, pos)
        if not parent or not IsValid(parent) then return end
        parent:SetRenderMode(RENDERMODE_NONE) -- SetNoDraw(true) apparently doesn't work on npc_antlion
        parent:DrawShadow(false)
        parent:SetBloodColor(BLOOD_COLOR_RED)
        parent:SetModelScale(0.9 * species.scale, .000001)
        parent:SetMaxHealth(cv_health:GetInt())
        parent:SetHealth(parent:GetMaxHealth())
        parent.tapir_owner = ply
        parent.userdata = { team = ply:GetTeam() } -- idk if this actually gets used
        -- Don't attack players for no reason
        for _, neutral_ply in ipairs(player.GetAll()) do
            if neutral_ply == ply then
                parent:AddEntityRelationship(neutral_ply, D_LI, priority_highest)
            else
                parent:AddEntityRelationship(neutral_ply, D_NU, priority_normal)
            end
        end

        -- Create a child entity that has the actual model
        local child = ents.Create("prop_dynamic")
        child:SetModel(tapir_model)
        child:SetMaterial(species.material)
        child:SetModelScale(species.scale, .000001)
        child:SetPos(pos)
        child:SetParent(parent)

        -- Do these after spawning the child to propagate the movement
        parent:SetAngles(Angle(0, math.random(360), 0))
        parent:DropToFloor()

        ply.tapir_ent = parent
    end

    hook.Add("Think", "tapir_npc_Think", function()
        for _, npc in ipairs(get_all_tapir_parents()) do
            -- Stop unwanted noises.
            -- This is very hacky. We're constantly stopping all unwanted sounds individually.
            for _, snd in ipairs(sounds_to_stop) do
                npc:StopSound(snd)
            end

            -- Follow your owner when not fighting.
            -- Figured this out thanks to this addon ❤️: https://steamcommunity.com/sharedfiles/filedetails/?id=1582693384
            local owner = npc.tapir_owner
            -- Only follow our owner if we don't have an enemy we're currently fighting
            if not IsValid(npc:GetEnemy()) and IsValid(owner) then
                npc:SetTarget(owner)
                if (npc:GetPos():Distance(owner:GetPos()) > cv_close:GetInt()) and
                    (npc:GetCurrentSchedule() ~= SCHED_TARGET_CHASE) then
                    -- We're too far away from our owner, chase them (ಥ﹏ಥ)
                    npc:SetSchedule(SCHED_TARGET_CHASE)
                end
            end
        end
    end)

    hook.Add("EntityTakeDamage", "tapir_EntityTakeDamage", function(victim, dmg)
        local att = dmg:GetAttacker()
        if not IsValid(victim) or not IsValid(att) then return end
        if IsValid(victim.tapir_ent) and att:IsPlayer() then
            -- Someone damaged the tapir's owner, attack them >:(
            victim.tapir_ent:AddEntityRelationship(att, D_HT, priority_high)
        elseif att.tapir_owner then
            -- Tapir attacked someone
            if victim == att.tapir_owner then
                -- Don't accidentally hit our owner
                return true
            end
            if dmg:IsDamageType(DMG_SLASH) then
                -- Constant predefined damage value
                dmg:SetDamage(cv_damage:GetInt())
            end
            if victim:IsPlayer() then make_drowsy(victim) end
        elseif victim.tapir_owner then
            -- Make sure the tapir entity never ragdolls
            dmg:SetDamageType(DMG_REMOVENORAGDOLL)
            if att:IsPlayer() and att.tapir_ent ~= victim then
                -- Someone else damaged the tapir, attack them >:(
                victim:AddEntityRelationship(att, D_HT, priority_high)
            end
        end
    end)

    hook.Add("PlayerDeath", "tapir_drowsy_stop_PlayerDeath", function(ply)
        if not ply.tapir_drowsy_until or ply.tapir_drowsy_until <= CurTime() then
            return
        end
        STATUS:RemoveStatus(ply, drowsy_status)
    end)
end
