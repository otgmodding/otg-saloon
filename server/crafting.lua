local craftLocks = {}

local function findRecipe(businessId, recipeId)
    local b = OTG.Businesses[tonumber(businessId)]
    if not b then return nil end
    for _, recipe in ipairs(b.recipes or {}) do
        if tonumber(recipe.id) == tonumber(recipeId) then return recipe end
    end
end

RegisterNetEvent('otg-saloon:server:craft', function(businessId, recipeId, stationId)
    local src = source
    if craftLocks[src] then return end
    local business = OTG.Businesses[tonumber(businessId)]
    local recipe = findRecipe(businessId, recipeId)
    if not business or not recipe then return end
    if not OTG.HasBusinessAccess(src, businessId, recipe.min_grade) then return end

    local station
    for _, s in ipairs(business.stations or {}) do
        if tonumber(s.id) == tonumber(stationId) and s.type == 'craft' then station = s break end
    end
    if not station then return end
    if not OTG.DistanceOK(src, vector3(station.x, station.y, station.z), Config.CraftDistance) then return end

    for _, ing in ipairs(recipe.ingredients or {}) do
        local count = exports['rsg-inventory']:GetItemCount(src, ing.item) or 0
        if count < tonumber(ing.amount) then
            return OTG.Notify(src, ('Missing %sx %s.'):format(ing.amount, ing.item), 'error')
        end
    end

    local canAdd = exports['rsg-inventory']:CanAddItem(src, recipe.result_item, recipe.result_amount)
    if not canAdd then return OTG.Notify(src, 'Not enough inventory space.', 'error') end

    craftLocks[src] = true
    TriggerClientEvent('otg-saloon:client:craftProgress', src, recipe.label, tonumber(recipe.craft_ms) or 5000)
    Wait(tonumber(recipe.craft_ms) or 5000)

    if not OTG.DistanceOK(src, vector3(station.x, station.y, station.z), Config.CraftDistance) then
        craftLocks[src] = nil
        return OTG.Notify(src, 'Craft cancelled: you moved away.', 'error')
    end

    -- Re-check immediately before mutation.
    for _, ing in ipairs(recipe.ingredients or {}) do
        local count = exports['rsg-inventory']:GetItemCount(src, ing.item) or 0
        if count < tonumber(ing.amount) then
            craftLocks[src] = nil
            return OTG.Notify(src, 'Craft cancelled: ingredients changed.', 'error')
        end
    end

    for _, ing in ipairs(recipe.ingredients or {}) do
        local removed = exports['rsg-inventory']:RemoveItem(src, ing.item, tonumber(ing.amount), nil, 'otg-saloon craft')
        if not removed then craftLocks[src] = nil return end
    end
    exports['rsg-inventory']:AddItem(src, recipe.result_item, tonumber(recipe.result_amount), nil, {}, 'otg-saloon craft')
    craftLocks[src] = nil
    OTG.Notify(src, ('Crafted %s.'):format(recipe.label), 'success')
end)

AddEventHandler('playerDropped', function()
    craftLocks[source] = nil
end)
