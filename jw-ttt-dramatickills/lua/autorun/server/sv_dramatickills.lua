forcescale = CreateConVar("jw_dramatickills_scale", "1")

local playerMostRecentDamage = {}

local function getAllHitboxesInHitgroup(ply, hitgroup)
    local numHitboxes = ply:GetHitBoxCount(ply:GetHitboxSet())

    local hitboxesInGroup = {}
    for i = 0, numHitboxes - 1 do
        if ply:GetHitBoxHitGroup(i, ply:GetHitboxSet()) == hitgroup then
            table.insert(hitboxesInGroup, i)
        end
    end

    return hitboxesInGroup
end

hook.Add("ScalePlayerDamage", "JWDramaticCorpsesScalePlayerDamage", function(ply, hitgroup, dmginfo)
    local hitboxes = getAllHitboxesInHitgroup(ply, hitgroup)
    
    local bones = {}
    for k,v in pairs(hitboxes) do
        table.insert(bones, ply:GetHitBoxBone(v, ply:GetHitboxSet()))
    end

    playerMostRecentDamage[ply] = {
        bones = bones,
        force = dmginfo:GetDamageForce(),
        position = dmginfo:GetDamagePosition()
    }
end)

hook.Add("TTTOnCorpseCreated", "JWDramaticCorpsesTTTOnCorpseCreated", function(corpse, ply)
    local dmg = playerMostRecentDamage[ply]

    if dmg == nil then
        return nil
    end

    local physBones = {}
    for k,boneNum in pairs(dmg.bones) do
        local physObjNum = corpse:TranslateBoneToPhysBone(boneNum)
        if physObjNum ~= -1 then
            physObj = corpse:GetPhysicsObjectNum(physObjNum)
            if physObj && physObj:IsValid() then
                table.insert(physBones, physObj)
            end
        end
    end

    if #physBones > 0 then
        local force = dmg.force / #physBones
        for k,obj in pairs(physBones) do
            obj:ApplyForceOffset(force * forcescale:GetFloat(), dmg.position)
        end
    end
end)