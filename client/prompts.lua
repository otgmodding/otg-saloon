------------------------------------------------------------------
-- otg-saloons | Proximity Prompts
------------------------------------------------------------------
-- Self-contained native prompt system.
-- Renders the RedM UI prompt (same native prompt API rsg-core uses) when
-- the player is within a zone of an interaction.
------------------------------------------------------------------

local RSGCore = exports['rsg-core']:GetCoreObject()

-- Collect every interaction from the database into a flat list
local allInteractions = {}
local interactionsLoaded = false

-- Native prompts currently rendered
local activePrompts = {}

------------------------------------------------
-- Native prompt helpers
------------------------------------------------
local function setupPrompt(interaction)
    local str = CreateVarString(10, 'LITERAL_STRING', interaction.label)
    local nativePrompt = Citizen.InvokeNative(0x04F97DE45A519419, Citizen.ReturnResultAnyway())
    Citizen.InvokeNative(0xB5352B7494A08258, nativePrompt, interaction.key or 'E') -- Default to E if not set
    Citizen.InvokeNative(0x5DD02A8318420DD7, nativePrompt, str)
    Citizen.InvokeNative(0x8A0FB4D03A630D21, nativePrompt, true)
    Citizen.InvokeNative(0x71215ACCFDE075EE, nativePrompt, true)
    Citizen.InvokeNative(0x94073D5CA3F16B7B, nativePrompt, 1000)
    Citizen.InvokeNative(0xF7AA2696A22AD8B9, nativePrompt)
    return nativePrompt
end

local function deletePrompt(name)
    if activePrompts[name] then
        UiPromptDelete(activePrompts[name])
        activePrompts[name] = nil
    end
end

local function firePrompt(interaction)
    if interaction.args then
        TriggerEvent(interaction.event, table.unpack(interaction.args))
    else
        TriggerEvent(interaction.event)
    end
end

-- Check if point is inside zone (same as in zone_editor.lua)
local function isPointInZone(zoneType, zoneData, point)
    if zoneType == 'point' then
        -- For point, we consider within a small radius (e.g., 1.5m)
        return #(point - zoneData) < 1.5
    elseif zoneType == 'box' then
        local center = zoneData.center
        local length = zoneData.length
        local width = zoneData.width
        local heading = zoneData.heading or 0.0
        local minZ = zoneData.minZ
        local maxZ = zoneData.maxZ

        -- Check Z first
        if point.z < minZ or point.z > maxZ then
            return false
        end

        -- Convert to local space
        local dx = point.x - center.x
        local dy = point.y - center.y
        local cosH = math.cos(math.rad(-heading))
        local sinH = math.sin(math.rad(-heading))
        local localX = dx * cosH - dy * sinH
        local localY = dx * sinH + dy * cosH

        return math.abs(localX) < length/2 and math.abs(localY) < width/2
    elseif zoneType == 'circle' then
        local center = zoneData.center
        local radius = zoneData.radius
        local minZ = zoneData.minZ
        local maxZ = zoneData.maxZ

        if point.z < minZ or point.z > maxZ then
            return false
        end

        return #(vector3(point.x, point.y, 0) - vector3(center.x, center.y, 0)) < radius
    elseif zoneType == 'polygon' then
        local points = zoneData.points
        local minZ = zoneData.minZ
        local maxZ = zoneData.maxZ

        if point.z < minZ or point.z > maxZ then
            return false
        end

        -- Simple ray casting algorithm for 2D (ignoring Z)
        local inside = false
        for i=1, #points do
            local j = i % #points + 1
            if ((points[i].y > point.y) ~= (points[j].y > point.y)) and
                (point.x < (points[j].x - points[i].x) * (point.y - points[i].y) / (points[j].y - points[i].y) + points[i].x) then
                inside = not inside
            end
        end
        return inside
    end
    return false
end

-- Fetch all interactions from the server
local function requestAllInteractions()
    TriggerServerEvent('otg-saloons:server:getAllInteractions')
end

-- Handle the interactions from the server
RegisterNetEvent('otg-saloons:client:allInteractions', function(interactions)
    allInteractions = interactions or {}
    interactionsLoaded = true
end)

-- Main loop: create/remove prompts by proximity (now zone-based)
CreateThread(function()
    -- Wait for interactions to be loaded
    while not interactionsLoaded do
        Wait(100)
    end

    while true do
        local sleep = 1000
        local coords = GetEntityCoords(cache.ped)
        local nearestInteraction, nearestDist = nil, 9999.0
        local isInsideAnyZone = false

        -- Find the nearest interaction where the player is inside the zone (or closest point for point type)
        for _, interaction in pairs(allInteractions) do
            local dist = 9999.0
            local inside = isPointInZone(interaction.zone_type, interaction.zone_data, coords)

            if inside then
                dist = 0 -- Inside the zone, distance is 0
                isInsideAnyZone = true
            else
                -- For point type, we calculate distance to the point
                -- For other types, we calculate distance to the zone boundary (simplified as distance to center for now)
                if interaction.zone_type == 'point' then
                    dist = #(coords - interaction.zone_data)
                else
                    -- For other types, we use the distance to the center as an approximation
                    local center
                    if interaction.zone_type == 'box' or interaction.zone_type == 'circle' then
                        center = interaction.zone_data.center
                    elseif interaction.zone_type == 'polygon' then
                        -- For polygon, we can use the average of points as center
                        if #interaction.zone_data.points > 0 then
                            local sumX, sumY, sumZ = 0, 0, 0
                            for _, point in ipairs(interaction.zone_data.points) do
                                sumX = sumX + point.x
                                sumY = sumY + point.y
                                sumZ = sumZ + point.z
                            end
                            center = {
                                x = sumX / #interaction.zone_data.points,
                                y = sumY / #interaction.zone_data.points,
                                z = sumZ / #interaction.zone_data.points
                            }
                        else
                            center = {x=0, y=0, z=0}
                        end
                    end
                    if center then
                        dist = #(vector3(coords.x, coords.y, coords.z) - vector3(center.x, center.y, center.z))
                    end
                end
            end

            if dist < nearestDist then
                nearestDist = dist
                nearestInteraction = interaction
            end
        end

        local inRange = nearestDist <= Config.PromptDistance or isInsideAnyZone

        if inRange then
            sleep = 100
            local interaction = nearestInteraction

            if not activePrompts[interaction.name] then
                -- Add a key to the interaction for the prompt (we'll use the name as key)
                interaction.key = interaction.name
                activePrompts[interaction.name] = setupPrompt(interaction)
            end

            if UiPromptHasHoldModeCompleted(activePrompts[interaction.name]) then
                firePrompt(interaction)
                -- briefly disable/re-enable to stop the prompt re-firing immediately
                UiPromptSetEnabled(activePrompts[interaction.name], false)
                UiPromptSetVisible(activePrompts[interaction.name], false)
                Wait(0)
                UiPromptSetEnabled(activePrompts[interaction.name], true)
                UiPromptSetVisible(activePrompts[interaction.name], true)
            end
        end

        -- Remove any prompt that is no longer the nearest interaction
        local activeName = inRange and nearestInteraction.name or nil
        for name in pairs(activePrompts) do
            if name ~= activeName then
                deletePrompt(name)
            end
        end

        -------------------------------------------------
        -- Debug mode: markers at every trigger point
        -------------------------------------------------
        if Config.Debug then
            sleep = 100
            for _, interaction in pairs(allInteractions) do
                local pm = 9999.0
                if interaction.zone_type == 'point' then
                    pm = #(coords - interaction.zone_data)
                else
                    -- For other types, we approximate with distance to center
                    local center
                    if interaction.zone_type == 'box' or interaction.zone_type == 'circle' then
                        center = interaction.zone_data.center
                    elseif interaction.zone_type == 'polygon' then
                        if #interaction.zone_data.points > 0 then
                            local sumX, sumY, sumZ = 0, 0, 0
                            for _, point in ipairs(interaction.zone_data.points) do
                                sumX = sumX + point.x
                                sumY = sumY + point.y
                                sumZ = sumZ + point.z
                            end
                            center = {
                                x = sumX / #interaction.zone_data.points,
                                y = sumY / #interaction.zone_data.points,
                                z = sumZ / #interaction.zone_data.points
                            }
                        else
                            center = {x=0, y=0, z=0}
                        end
                    end
                    if center then
                        pm = #(vector3(coords.x, coords.y, coords.z) - vector3(center.x, center.y, center.z))
                    end
                end

                if pm < 50.0 then -- Debug marker range
                    local colour = {
                        main = { 255, 255, 255 },
                        counter = { 0, 200, 255 },
                        cash = { 0, 255, 100 },
                        craft = { 255, 200, 0 },
                        music = { 200, 0, 255 },
                        dancer = { 255, 100, 200 }
                    }
                    -- We don't have a color field in interaction, so we'll default to main or try to map from name
                    local c = colour[interaction.name] or colour.main
                    DrawMarker(
                        1,
                        interaction.zone_data.x or (interaction.zone_data.center and interaction.zone_data.center.x) or 0,
                        interaction.zone_data.y or (interaction.zone_data.center and interaction.zone_data.center.y) or 0,
                        (interaction.zone_data.z or (interaction.zone_data.center and interaction.zone_data.center.z) or 0) - 0.98,
                        0.0, 0.0, 0.0,
                        0.0, 0.0, 0.0,
                        0.6, 0.6, 0.3,
                        c[1], c[2], c[3], 110,
                        false, false, 0, false, nil, nil, false
                    )

                    -- Also draw the zone shape
                    -- We'll use the drawZone function from zone_editor.lua, but we don't have it here.
                    -- For now, we'll just draw the marker.
                end
            end

            -- HUD readout of the nearest interaction point (only redrawn on change).
            if nearestInteraction ~= nil and nearestDist <= 50.0 then
                local displayDist = math.floor(nearestDist * 10) / 10
                if nearestInteraction ~= lastDebugPrompt or displayDist ~= lastDebugDist then
                    lastDebugPrompt = nearestInteraction
                    lastDebugDist = displayDist
                    lib.showTextUI(('[otg-saloons] %s %.1fm'):format(nearestInteraction.label, displayDist))
                    debugTextUIShown = true
                end
            elseif debugTextUIShown then
                lastDebugPrompt, lastDebugDist = nil, -1
                debugTextUIShown = false
                lib.hideTextUI()
            end
        end

        Wait(sleep)
    end
end)

-- Variables for debug HUD
local lastDebugPrompt, lastDebugDist = nil, -1
local debugTextUIShown = false

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for name in pairs(activePrompts) do
        deletePrompt(name)
    end
    if Config.Debug then
        lib.hideTextUI()
    end
end)