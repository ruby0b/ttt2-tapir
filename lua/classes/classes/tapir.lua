local function TapirActivate(ply)
    if CLIENT then return end
    SpawnTapir(ply)
    if not IsValid(ply.tapir_ent) then return true end
    ply.tapir_ent:CallOnRemove("deactivate_owner_class_ability", function(ent)
        -- timer needed due to: https://github.com/Facepunch/garrysmod-issues/issues/4675
        timer.Simple(0, function()
            if IsValid(ent) then return end -- Check if we actually got removed
            if (not IsValid(ply)) or (not ply.GetCustomClass) or
                (ply:GetCustomClass() ~= CLASS.CLASSES.TAPIR.index) or
                (not ply:HasClassActive()) then
                return
            end
            -- Calling ClassDeactivate is not enough, we also need to inform the client, see:
            -- https://github.com/TTT-2/TTTC/blob/17f4afeb74d90e5761781acec672b996a0310b39/lua/terrortown/autorun/shared/sh_classes_hooks.lua#L389-L394
            ply:ClassDeactivate()
            net.Start("TTTCDeactivateClass")
            net.Send(ply)
        end)
    end)
end

local function TapirDeactivate(ply)
    if CLIENT or not IsValid(ply.tapir_ent) then return end
    ply.tapir_ent:Remove()
end

CLASS.AddClass("TAPIR", {
    color = Color(76, 52, 38, 255),
    OnAbilityActivate = TapirActivate,
    OnAbilityDeactivate = TapirDeactivate,
    endless = true,
    cooldown = 40,
    charging = 1.5,
    avoidWeaponReset = true,
    lang = {
        name = { en = "Tapir" },
        desc = { en = "Spawn a friendly tapir that protects you." }
    }
})
