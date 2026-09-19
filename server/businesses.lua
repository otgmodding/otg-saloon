local RSGCore = exports['rsg-core']:GetCoreObject()
local dynamicItems = {}

local function decode(value, fallback)
    if not value or value == '' then return fallback end
    local ok, data = pcall(json.decode, value)
    return ok and data or fallback
end

local function canManageAnyBusiness(source)
    if OTG.IsAdmin(source) then return true end
    for businessId in pairs(OTG.Businesses) do
        if OTG.IsBusinessBoss(source, businessId) then return true end
    end
    return false
end

local function buildBusiness(row)
    return {
        id = tonumber(row.id),
        slug = row.slug,
        label = row.label,
        job = row.job,
        owner_citizenid = row.owner_citizenid,
        balance = tonumber(row.balance) or 0,
        storage_weight = tonumber(row.storage_weight) or Config.DefaultStorageWeight,
        storage_slots = tonumber(row.storage_slots) or Config.DefaultStorageSlots,
        blip_x = tonumber(row.blip_x), blip_y = tonumber(row.blip_y), blip_z = tonumber(row.blip_z),
        blip_sprite = tonumber(row.blip_sprite) or Config.DefaultBlipSprite,
        blip_scale = tonumber(row.blip_scale) or Config.DefaultBlipScale,
        active = row.active == true or tonumber(row.active) == 1,
        stations = {},
        recipes = {}
    }
end

local function recipeItemDefinition(recipe)
    local name = tostring(recipe.result_item or ''):lower()
    return {
        name = name,
        label = tostring(recipe.label or name):sub(1, 100),
        weight = math.max(1, math.floor(tonumber(recipe.item_weight) or 100)),
        type = 'item',
        image = tostring(recipe.item_image or 'placeholder.png'):sub(1, 255),
        unique = false,
        useable = true,
        shouldClose = true,
        description = tostring(recipe.item_description or recipe.label or name):sub(1, 255),
        otgSaloon = true
    }
end

local function registerDynamicItem(recipe)
    if not recipe or not (recipe.dynamic_item == true or tonumber(recipe.dynamic_item) == 1) then return true end
    local name = tostring(recipe.result_item or ''):lower()
    if name == '' then return false end
    local definition = recipeItemDefinition(recipe)
    local existing = RSGCore.Shared.Items[name]
    local ok, reason
    if existing and existing.otgSaloon ~= true and not dynamicItems[name] then
        print(('[otg-saloon] dynamic item %s conflicts with an existing non-OTG item; definition was not changed.'):format(name))
        return false
    elseif existing then
        ok, reason = RSGCore.Functions.UpdateItem(name, definition)
    else
        ok, reason = RSGCore.Functions.AddItem(name, definition)
    end
    if not ok then
        print(('[otg-saloon] failed to register dynamic item %s: %s'):format(name, tostring(reason)))
        return false
    end
    dynamicItems[name] = true
    return true
end

RegisterNetEvent('otg-saloon:server:reload', function()
    -- V2.5 migration: early OTG builds used the non-existent BLIP_AMBIENT_SALOON name.
    -- Its joaat value (-1861245094) was persisted. Replace only that known legacy value.
    MySQL.update.await('UPDATE otg_saloon_businesses SET blip_sprite=? WHERE blip_sprite=?',
        { Config.DefaultBlipSprite, -1861245094 })

    local rows = MySQL.query.await('SELECT * FROM otg_saloon_businesses') or {}
    local businesses = {}
    for _, row in ipairs(rows) do
        local business = buildBusiness(row)
        if business.id then businesses[business.id] = business end
    end

    local stations = MySQL.query.await('SELECT * FROM otg_saloon_stations') or {}
    for _, s in ipairs(stations) do
        local businessId = tonumber(s.business_id)
        if businesses[businessId] then
            s.id = tonumber(s.id)
            s.business_id = businessId
            s.x, s.y, s.z = tonumber(s.x), tonumber(s.y), tonumber(s.z)
            s.heading = tonumber(s.heading) or 0.0
            s.min_grade = tonumber(s.min_grade) or 0
            s.settings = decode(s.settings, {})
            businesses[businessId].stations[#businesses[businessId].stations + 1] = s
        end
    end

    -- Repair businesses created by older creator builds that dropped the blip draft
    -- before saving. A manager station is the safest existing business anchor.
    for _, business in pairs(businesses) do
        if not business.blip_x or not business.blip_y or not business.blip_z then
            for _, station in ipairs(business.stations) do
                if station.type == 'manager' and station.x and station.y and station.z then
                    business.blip_x, business.blip_y, business.blip_z = station.x, station.y, station.z
                    MySQL.update.await(
                        'UPDATE otg_saloon_businesses SET blip_x=?,blip_y=?,blip_z=? WHERE id=? AND (blip_x IS NULL OR blip_y IS NULL OR blip_z IS NULL)',
                        { station.x, station.y, station.z, business.id })
                    print(('[otg-saloon] repaired missing blip position for %s from manager station %s.'):format(
                        tostring(business.label), tostring(station.id)))
                    break
                end
            end
        end
    end

    local recipes = MySQL.query.await('SELECT * FROM otg_saloon_recipes') or {}
    for _, r in ipairs(recipes) do
        local businessId = tonumber(r.business_id)
        if businesses[businessId] then
            r.id = tonumber(r.id)
            r.business_id = businessId
            r.ingredients = decode(r.ingredients, {})
            r.effects = decode(r.effects, {})
            r.consumption = decode(r.consumption, {})
            r.item_weight = tonumber(r.item_weight) or 100
            r.dynamic_item = r.dynamic_item == true or tonumber(r.dynamic_item) == 1
            registerDynamicItem(r)
            businesses[businessId].recipes[#businesses[businessId].recipes + 1] = r
        end
    end

    OTG.Businesses = businesses
    for _, playerSource in ipairs(RSGCore.Functions.GetPlayers()) do
        local visibleBusinesses = {}
        for id, business in pairs(businesses) do
            if business.active or OTG.IsAdmin(playerSource) or OTG.IsBusinessBoss(playerSource, id) then
                visibleBusinesses[id] = business
            end
        end
        TriggerClientEvent('otg-saloon:client:syncBusinesses', playerSource, visibleBusinesses)
    end
    TriggerEvent('otg-saloon:server:loaded')
end)

lib.callback.register('otg-saloon:server:getBusinesses', function(source)
    if OTG.IsAdmin(source) then return OTG.Businesses end
    local visibleBusinesses = {}
    for id, business in pairs(OTG.Businesses) do
        if business.active or OTG.IsBusinessBoss(source, id) then visibleBusinesses[id] = business end
    end
    return visibleBusinesses
end)


lib.callback.register('otg-saloon:server:getCreatorItems', function(source, businessId)
    businessId = tonumber(businessId)
    local allowed = OTG.IsAdmin(source)
    if not allowed and businessId and OTG.Businesses[businessId] then
        allowed = OTG.IsBusinessBoss(source, businessId)
        if not allowed then
            local Player = OTG.GetPlayer(source)
            local cid = Player and Player.PlayerData.citizenid
            if cid then
                allowed = MySQL.scalar.await('SELECT 1 FROM otg_saloon_permissions WHERE business_id=? AND citizenid=? AND permission=? LIMIT 1',
                    {businessId, cid, 'manage_recipes'}) ~= nil
            end
        end
    end
    if not allowed then return {} end
    local items = {}
    for name, item in pairs(RSGCore.Shared.Items or {}) do
        if item.otgSaloon ~= true then
            out[#out+1] = { value=name, label=item.label or name, image=item.image or '' }
        end
    end
    table.sort(items, function(a,b) return a.label:lower() < b.label:lower() end)
    return items
end)

lib.callback.register('otg-saloon:server:getPropCatalog', function(source)
    return Config.PropCatalog or {}
end)

lib.callback.register('otg-saloon:server:getStock', function(source, businessId)
    if not OTG.HasBusinessAccess(source, businessId, 0) then return {} end
    return MySQL.query.await('SELECT item, amount FROM otg_saloon_stock WHERE business_id = ?', { businessId }) or {}
end)

lib.callback.register('otg-saloon:server:openManagement', function(source, businessId, stationId)
    local station, business = OTG.GetStation(businessId, stationId, 'manager')
    if not station or not business then
        return false, 'Management station not found.'
    end
    if not OTG.DistanceOK(source, vector3(station.x, station.y, station.z), Config.ServerValidationDistance) then
        return false, 'You must be at the management station.'
    end
    if not OTG.IsBusinessBoss(source, business.id) then
        return false, 'Only the RSG job boss can use business management. Check the isboss flag on this RSG job grade.'
    end
    return true
end)

lib.callback.register('otg-saloon:server:setBusinessBlip', function(source, businessId, coords)
    businessId = tonumber(businessId)
    if not businessId or not OTG.Businesses[businessId] then return false, 'Business not found.' end
    if not OTG.IsAdmin(source) and not OTG.IsBusinessBoss(source, businessId) then
        return false, 'Boss access is required.'
    end
    if type(coords) ~= 'table' then return false, 'Invalid blip coordinates.' end
    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return false, 'Invalid blip coordinates.' end

    local ok, changed = pcall(MySQL.update.await,
        'UPDATE otg_saloon_businesses SET blip_x=?,blip_y=?,blip_z=? WHERE id=?',
        { x, y, z, businessId })
    if not ok or changed == nil then
        print(('[otg-saloon] setBusinessBlip DB error for business %s: %s'):format(businessId, tostring(changed)))
        return false, 'Blip position could not be saved. Check the server console.'
    end
    TriggerEvent('otg-saloon:server:reload')
    return true, 'Blip position saved.'
end)

RSGCore.Commands.Add(Config.CreatorCommand, 'Open OTG Saloon creator', {}, false, function(source)
    if not OTG.IsAdmin(source) then
        return OTG.Notify(source, 'You do not have permission to use the saloon creator.', 'error')
    end
    TriggerClientEvent('otg-saloon:client:openCreator', source)
end, 'admin')

RegisterNetEvent('otg-saloon:server:createBusiness', function(data)
    local src = source
    if not OTG.IsAdmin(src) or type(data) ~= 'table' then return end
    local slug = tostring(data.slug or ''):lower():gsub('[^%w_%-]', '')
    local label, job = tostring(data.label or ''), tostring(data.job or '')
    if #slug < 2 or #label < 2 or #job < 2 then return OTG.Notify(src, 'Invalid business details.', 'error') end
    if not RSGCore.Shared.Jobs[job] then
        return OTG.Notify(src, ('RSG job "%s" does not exist. Add it to rsg-core/shared/jobs.lua first.'):format(job), 'error')
    end
    local duplicate = MySQL.scalar.await('SELECT id FROM otg_saloon_businesses WHERE slug=? LIMIT 1', {slug})
    if duplicate then return OTG.Notify(src, 'That business slug is already in use.', 'error') end
    local Player = OTG.GetPlayer(src)
    local fallbackOwner = Player and Player.PlayerData.citizenid or nil
    local requestedOwner = tostring(data.ownerCitizenId or '')
    local owner = requestedOwner ~= '' and requestedOwner:sub(1,64) or fallbackOwner
    local ok = pcall(function()
        MySQL.insert.await([[INSERT INTO otg_saloon_businesses
            (slug,label,job,owner_citizenid,active,storage_weight,storage_slots,blip_x,blip_y,blip_z,blip_sprite,blip_scale)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)]], { slug, label, job, owner, data.active == false and 0 or 1,
            math.max(Config.StorageLimits.minWeight, math.min(Config.StorageLimits.maxWeight, math.floor(tonumber(data.storageWeight) or Config.DefaultStorageWeight))),
            math.max(Config.StorageLimits.minSlots, math.min(Config.StorageLimits.maxSlots, math.floor(tonumber(data.storageSlots) or Config.DefaultStorageSlots))),
            tonumber(data.blipX), tonumber(data.blipY), tonumber(data.blipZ),
            tonumber(data.blipSprite) or Config.DefaultBlipSprite, tonumber(data.blipScale) or Config.DefaultBlipScale })
    end)
    if not ok then return OTG.Notify(src, 'Business slug already exists or database insert failed.', 'error') end
    TriggerEvent('otg-saloon:server:reload')
    OTG.Notify(src, 'Business created. Use the creator again to place stations.', 'success')
end)

local function cleanStationSettings(data, oldSettings)
    local settings = oldSettings or {}
    local prop = tostring(data.prop or settings.prop or ''):gsub('%s+', ''):sub(1,64)
    settings.prop = prop
    settings.radius = math.max(0.25, math.min(15.0, tonumber(data.radius) or tonumber(settings.radius) or Config.DefaultStationRadius))
    if data.shape ~= nil then
        settings.shape = data.shape == 'box' and 'box' or 'sphere'
    else
        settings.shape = settings.shape == 'box' and 'box' or 'sphere'
    end
    settings.length = math.max(0.25, math.min(30.0, tonumber(data.length) or tonumber(settings.length) or 1.5))
    settings.width = math.max(0.25, math.min(30.0, tonumber(data.width) or tonumber(settings.width) or 1.5))
    return settings, prop
end

lib.callback.register('otg-saloon:server:saveStation', function(source, data)
    if type(data) ~= 'table' then return false, 'Invalid station data.' end

    local businessId = tonumber(data.businessId)
    local business = businessId and OTG.Businesses[businessId]
    if not business then return false, 'Business not found.' end
    if not OTG.IsAdmin(source) and not OTG.IsBusinessBoss(source, businessId) then
        return false, 'Boss access is required.'
    end
    if not Config.StationTypes[data.type] then return false, 'Invalid station type.' end

    local station = data.stationId and OTG.GetStation(businessId, data.stationId) or nil
    if data.stationId and not station then return false, 'Station not found.' end
    local x = tonumber(data.x) or (station and station.x)
    local y = tonumber(data.y) or (station and station.y)
    local z = tonumber(data.z) or (station and station.z)
    local heading = tonumber(data.heading) or (station and station.heading) or 0.0
    if not x or not y or not z then return false, 'Station coordinates are invalid.' end

    local settings, prop = cleanStationSettings(data, station and station.settings)
    if prop ~= '' then
        local previous = type(settings.propCoords) == 'table' and settings.propCoords or {}
        settings.propCoords = {
            x = tonumber(data.propX) or tonumber(previous.x) or x,
            y = tonumber(data.propY) or tonumber(previous.y) or y,
            z = tonumber(data.propZ) or tonumber(previous.z) or z,
            h = tonumber(data.propHeading) or tonumber(previous.h) or heading
        }
    else
        settings.propCoords = nil
    end

    local label = tostring(data.label or Config.StationTypes[data.type]):sub(1, 100)
    local minGrade = math.max(0, math.floor(tonumber(data.minGrade) or 0))
    local ok, result = pcall(function()
        if station then
            return MySQL.update.await([[UPDATE otg_saloon_stations
                SET type=?,label=?,x=?,y=?,z=?,heading=?,min_grade=?,settings=?
                WHERE id=? AND business_id=?]],
                { data.type, label, x, y, z, heading, minGrade, json.encode(settings), station.id, businessId })
        end
        return MySQL.insert.await([[INSERT INTO otg_saloon_stations
            (business_id,type,label,x,y,z,heading,min_grade,settings) VALUES (?,?,?,?,?,?,?,?,?)]],
            { businessId, data.type, label, x, y, z, heading, minGrade, json.encode(settings) })
    end)
    if not ok or not result then
        print(('[otg-saloon] saveStation DB error for business %s: %s'):format(businessId, tostring(result)))
        return false, 'Station could not be saved. Check the server console for the database error.'
    end

    TriggerEvent('otg-saloon:server:reload')
    return true, station and 'Station updated.' or 'Station placed.'
end)

RegisterNetEvent('otg-saloon:server:addStation', function(data)
    local src = source
    if not OTG.IsAdmin(src) or type(data) ~= 'table' then return end
    local businessId = tonumber(data.businessId)
    if not OTG.Businesses[businessId] or not Config.StationTypes[data.type] then return end
    local x,y,z,h = tonumber(data.x),tonumber(data.y),tonumber(data.z),tonumber(data.heading) or 0
    if not x or not y or not z then return end
    local label = tostring(data.label or Config.StationTypes[data.type]):sub(1,100)
    local settings, prop = cleanStationSettings(data)
    if prop ~= '' then
        settings.prop = prop
        settings.propCoords = {
            x = tonumber(data.propX) or x,
            y = tonumber(data.propY) or y,
            z = tonumber(data.propZ) or z,
            h = tonumber(data.propHeading) or h
        }
    end
    MySQL.insert.await([[INSERT INTO otg_saloon_stations
        (business_id,type,label,x,y,z,heading,min_grade,settings) VALUES (?,?,?,?,?,?,?,?,?)]],
        { businessId, data.type, label, x,y,z,h, tonumber(data.minGrade) or 0, json.encode(settings) })
    TriggerEvent('otg-saloon:server:reload')
    OTG.Notify(src, 'Station placed.', 'success')
end)

lib.callback.register('otg-saloon:server:updateBusiness', function(src, data)
    if type(data) ~= 'table' then return false, 'Invalid business data.' end
    local id = tonumber(data.businessId)
    if not id or not OTG.Businesses[id] then return false, 'Business not found.' end
    local isAdmin, isBoss = OTG.IsAdmin(src), OTG.IsBusinessBoss(src, id)
    if not isAdmin and not isBoss then return false, 'Boss access is required.' end
    local current = OTG.Businesses[id]
    local slug, job, owner = current.slug, current.job, current.owner_citizenid
    local label = tostring(data.label or current.label):sub(1, 100)
    if #label < 2 then return false, 'Business name must be at least two characters.' end
    if isAdmin then
        slug = tostring(data.slug or ''):lower():gsub('[^%w_%-]', '')
        job = tostring(data.job or '')
        if #slug < 2 or not RSGCore.Shared.Jobs[job] then return false, 'Invalid business slug or job.' end
        local duplicate = MySQL.scalar.await('SELECT id FROM otg_saloon_businesses WHERE slug=? AND id<>? LIMIT 1', {slug, id})
        if duplicate then return false, 'That business slug is already in use.' end
        owner = tostring(data.ownerCitizenId or '')
        if owner == '' then owner = current.owner_citizenid end
    end
    local params = {
        label, slug, job, owner,
        data.active == true and 1 or 0,
        math.max(Config.StorageLimits.minWeight, math.min(Config.StorageLimits.maxWeight, math.floor(tonumber(data.storageWeight) or current.storage_weight or Config.DefaultStorageWeight))),
        math.max(Config.StorageLimits.minSlots, math.min(Config.StorageLimits.maxSlots, math.floor(tonumber(data.storageSlots) or current.storage_slots or Config.DefaultStorageSlots))),
        tonumber(data.blipX) or current.blip_x, tonumber(data.blipY) or current.blip_y, tonumber(data.blipZ) or current.blip_z,
        tonumber(data.blipSprite) or current.blip_sprite or Config.DefaultBlipSprite,
        math.max(0.05, math.min(2.0, tonumber(data.blipScale) or current.blip_scale or Config.DefaultBlipScale)), id
    }
    local ok, changed = pcall(function()
        return MySQL.update.await([[UPDATE otg_saloon_businesses SET label=?,slug=?,job=?,owner_citizenid=?,active=?,storage_weight=?,storage_slots=?,blip_x=?,blip_y=?,blip_z=?,blip_sprite=?,blip_scale=? WHERE id=?]], params)
    end)
    if not ok then
        print(('[otg-saloon] updateBusiness DB error for business %s: %s'):format(id, tostring(changed)))
        return false, 'Business update failed. Check the server console for the database error.'
    end
    TriggerEvent('otg-saloon:server:reload')
    return true, 'Business updated.'
end)

RegisterNetEvent('otg-saloon:server:updateStation', function(data)
    local src = source
    if not OTG.IsAdmin(src) or type(data) ~= 'table' then return end
    local station, business = OTG.GetStation(data.businessId, data.stationId)
    if not station or not Config.StationTypes[data.type] then return OTG.Notify(src, 'Station not found.', 'error') end
    local settings, prop = cleanStationSettings(data, station.settings)
    local x, y, z, h = tonumber(data.x) or station.x, tonumber(data.y) or station.y, tonumber(data.z) or station.z, tonumber(data.heading) or station.heading
    if prop ~= '' then settings.propCoords = { x=tonumber(data.propX) or settings.propCoords and settings.propCoords.x or x, y=tonumber(data.propY) or settings.propCoords and settings.propCoords.y or y, z=tonumber(data.propZ) or settings.propCoords and settings.propCoords.z or z, h=tonumber(data.propHeading) or h } else settings.propCoords = nil end
    MySQL.update.await('UPDATE otg_saloon_stations SET type=?,label=?,x=?,y=?,z=?,heading=?,min_grade=?,settings=? WHERE id=? AND business_id=?', { data.type, tostring(data.label or Config.StationTypes[data.type]):sub(1,100), x,y,z,h, math.max(0, tonumber(data.minGrade) or 0), json.encode(settings), station.id, business.id })
    TriggerEvent('otg-saloon:server:reload')
    OTG.Notify(src, 'Station updated.', 'success')
end)

RegisterNetEvent('otg-saloon:server:deleteStation', function(stationId)
    local src = source
    stationId = tonumber(stationId)
    local found, foundBusinessId
    for businessId in pairs(OTG.Businesses) do
        found = OTG.GetStation(businessId, stationId)
        if found then foundBusinessId = businessId break end
    end
    if not found then return OTG.Notify(src, 'Station not found.', 'error') end
    if not OTG.IsAdmin(src) and not OTG.IsBusinessBoss(src, foundBusinessId) then return end
    MySQL.update.await('DELETE FROM otg_saloon_stations WHERE id=?', { stationId })
    TriggerEvent('otg-saloon:server:reload')
    OTG.Notify(src, 'Station deleted.', 'success')
end)

RegisterNetEvent('otg-saloon:server:deleteBusiness', function(businessId)
    local src = source
    if not OTG.IsAdmin(src) then return end
    businessId = tonumber(businessId)
    local business = businessId and OTG.Businesses[businessId]
    if not business then return OTG.Notify(src, 'Business not found.', 'error') end

    MySQL.transaction.await({
        { query = 'DELETE FROM otg_saloon_contracts WHERE business_id = ?', values = { businessId } },
        { query = 'DELETE FROM otg_saloon_shipments WHERE business_id = ?', values = { businessId } },
        { query = 'DELETE FROM otg_saloon_stock WHERE business_id = ?', values = { businessId } },
        { query = 'DELETE FROM otg_saloon_recipes WHERE business_id = ?', values = { businessId } },
        { query = 'DELETE FROM otg_saloon_stations WHERE business_id = ?', values = { businessId } },
        { query = 'DELETE FROM otg_saloon_transactions WHERE business_id = ?', values = { businessId } },
        { query = 'DELETE FROM otg_saloon_businesses WHERE id = ?', values = { businessId } }
    })

    TriggerEvent('otg-saloon:server:reload')
    OTG.Notify(src, ('Deleted business: %s'):format(business.label), 'success')
end)


local function canManageRecipes(src, businessId)
    if OTG.IsAdmin(src) or OTG.IsBusinessBoss(src, businessId) then return true end
    local business = OTG.Businesses[tonumber(businessId)]
    local Player = OTG.GetPlayer(src)
    if not business or not Player then return false end
    local pd = Player.PlayerData
    if not pd.job or pd.job.name ~= business.job then return false end
    return MySQL.scalar.await('SELECT 1 FROM otg_saloon_permissions WHERE business_id=? AND citizenid=? AND permission=? LIMIT 1',
        {businessId, pd.citizenid, 'manage_recipes'}) ~= nil
end

local function cleanRecipeIngredients(src, ingredients)
    if type(ingredients) ~= 'table' or #ingredients == 0 then
        OTG.Notify(src, 'Recipe needs at least one ingredient.', 'error')
        return
    end
    local clean, seen = {}, {}
    for _, ingredient in ipairs(ingredients) do
        local item = tostring(ingredient.item or ''):lower()
        local amount = math.max(1, math.floor(tonumber(ingredient.amount) or 1))
        if not RSGCore.Shared.Items[item] then
            OTG.Notify(src, ('Ingredient "%s" is not a valid RSG item.'):format(item), 'error')
            return
        end
        if seen[item] then
            seen[item].amount = seen[item].amount + amount
        else
            local row={item=item,amount=amount}; clean[#clean+1]=row; seen[item]=row
        end
    end
    return clean
end

local function cleanEffects(data)
    data = type(data) == 'table' and data or {}
    local lim=Config.Consumables or {}
    local function b(v,m) return math.max(0,math.min(math.floor(tonumber(v) or 0),tonumber(m) or 0)) end
    return {hunger=b(data.hunger,lim.MaxHunger),thirst=b(data.thirst,lim.MaxThirst),
        health=b(data.health,lim.MaxHealth),stamina=b(data.stamina,lim.MaxStamina),
        alcohol=b(data.alcohol,lim.MaxAlcohol),duration=b(data.duration,lim.MaxDurationMs)}
end

local function cleanDynamicResult(src, data, recipeId)
    local result = tostring(data.resultItem or ''):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    if #result < 2 or #result > 64 then
        OTG.Notify(src, 'Result item name must be 2-64 characters using letters, numbers, underscore, or dash.', 'error')
        return
    end
    local existing = RSGCore.Shared.Items[result]
    if existing and existing.otgSaloon ~= true and not dynamicItems[result] then
        OTG.Notify(src, ('Result item "%s" already exists in items.lua. Choose a unique item name.'):format(result), 'error')
        return
    end
    local duplicate = MySQL.scalar.await(
        'SELECT id FROM otg_saloon_recipes WHERE result_item=? AND id<>? LIMIT 1',
        { result, tonumber(recipeId) or 0 })
    if duplicate then
        OTG.Notify(src, 'That result item name is already owned by another OTG recipe.', 'error')
        return
    end
    local image = tostring(data.itemImage or ''):gsub('[/\\]', ''):sub(1, 255)
    if image == '' then image = 'placeholder.png' end
    if not image:lower():match('%.png$') then
        OTG.Notify(src, 'Inventory image must be a PNG filename from rsg-inventory/html/images.', 'error')
        return
    end
    return {
        name = result,
        weight = math.max(1, math.min(100000, math.floor(tonumber(data.itemWeight) or 100))),
        image = image,
        description = tostring(data.itemDescription or data.label or result):sub(1, 255)
    }
end

lib.callback.register('otg-saloon:server:createRecipe', function(src, data)
    if type(data) ~= 'table' then return false, 'Invalid recipe data.' end
    local businessId = tonumber(data.businessId)
    if not OTG.Businesses[businessId] then return false, 'Business not found.' end
    if not canManageRecipes(src, businessId) then return false, 'You do not have recipe management permission.' end

    local output = cleanDynamicResult(src, data)
    if not output then return false, 'Invalid or conflicting result item definition.' end
    local ingredients = cleanRecipeIngredients(src, data.ingredients)
    if not ingredients then return false, 'Recipe needs at least one valid ingredient.' end

    local imageUrl = tostring(data.imageUrl or ''):sub(1, 1024)
    if imageUrl ~= '' and not imageUrl:match('^https://') then return false, 'Recipe image must use HTTPS.' end
    local ok, recipeId = pcall(MySQL.insert.await, [[INSERT INTO otg_saloon_recipes
        (business_id,label,result_item,result_amount,craft_ms,min_grade,ingredients,image_url,price,category,effects,item_weight,item_image,item_description,dynamic_item)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,1)]], {
        businessId, tostring(data.label or ''):sub(1, 100), output.name,
        math.max(1, math.floor(tonumber(data.resultAmount) or 1)),
        math.max(1000, math.floor(tonumber(data.craftMs) or 5000)), 0, json.encode(ingredients),
        imageUrl ~= '' and imageUrl or nil, math.max(0, tonumber(data.price) or 0),
        tostring(data.category or 'General'):sub(1, 64), json.encode(cleanEffects(data.effects)),
        output.weight, output.image, output.description
    })
    if not ok or not recipeId then
        print(('[otg-saloon] createRecipe DB error: %s'):format(tostring(recipeId)))
        return false, 'Recipe could not be saved. Check the server console.'
    end
    TriggerEvent('otg-saloon:server:reload')
    return true, 'Recipe created.'
end)

lib.callback.register('otg-saloon:server:updateRecipe', function(src, data)
    if type(data) ~= 'table' then return false, 'Invalid recipe data.' end
    local businessId, recipeId = tonumber(data.businessId), tonumber(data.recipeId)
    local business = businessId and OTG.Businesses[businessId]
    if not business then return false, 'Business not found.' end
    if not canManageRecipes(src, businessId) then
        return false, 'You do not have recipe management permission.'
    end
    local recipe
    for _, r in ipairs(business.recipes or {}) do if tonumber(r.id) == recipeId then recipe = r break end end
    if not recipe then return false, 'Recipe not found.' end
    local submittedResult = tostring(data.resultItem or ''):lower():gsub('%s+', '_'):gsub('[^%w_%-]', '')
    if submittedResult ~= tostring(recipe.result_item) then
        return false, 'The result item key cannot be changed after creation.'
    end
    local output, dynamic
    if recipe.dynamic_item then
        output = cleanDynamicResult(src, data, recipeId)
        if not output then return false, 'Invalid or conflicting result item definition.' end
        dynamic = 1
    else
        local existing = RSGCore.Shared.Items[submittedResult]
        if not existing then return false, 'The legacy result item no longer exists in shared items.' end
        output = {
            name = submittedResult,
            weight = tonumber(existing.weight) or 100,
            image = tostring(existing.image or 'placeholder.png'),
            description = tostring(existing.description or data.label or submittedResult)
        }
        dynamic = 0
    end
    local ingredients = cleanRecipeIngredients(src, data.ingredients)
    if not ingredients then return false, 'Recipe needs at least one valid ingredient.' end
    local imageUrl = tostring(data.imageUrl or ''):sub(1,1024)
    if imageUrl ~= '' and not imageUrl:match('^https://') then return false, 'Recipe image must use HTTPS.' end
    local ok, changed = pcall(MySQL.update.await, [[UPDATE otg_saloon_recipes SET label=?,result_item=?,result_amount=?,craft_ms=?,min_grade=?,ingredients=?,price=?,image_url=?,category=?,effects=?,item_weight=?,item_image=?,item_description=?,dynamic_item=? WHERE id=? AND business_id=?]], {
        tostring(data.label or ''):sub(1,100), output.name, math.max(1, math.floor(tonumber(data.resultAmount) or 1)),
        math.max(1000, math.floor(tonumber(data.craftMs) or 5000)), 0,
        json.encode(ingredients), math.max(0, tonumber(data.price) or 0), imageUrl ~= '' and imageUrl or nil,
        tostring(data.category or 'General'):sub(1,64), json.encode(cleanEffects(data.effects)), output.weight, output.image,
        output.description, dynamic, recipeId, businessId
    })
    if not ok or changed == nil then
        print(('[otg-saloon] updateRecipe DB error: %s'):format(tostring(changed)))
        return false, 'Recipe could not be updated. Check the server console.'
    end
    TriggerEvent('otg-saloon:server:reload')
    return true, 'Recipe updated.'
end)

RegisterNetEvent('otg-saloon:server:deleteRecipe', function(recipeId)
    local src = source
    recipeId = tonumber(recipeId)
    local businessId = MySQL.scalar.await('SELECT business_id FROM otg_saloon_recipes WHERE id=? LIMIT 1', {recipeId})
    if not businessId or not canManageRecipes(src, tonumber(businessId)) then
        return OTG.Notify(src, 'You do not have recipe management permission.', 'error')
    end
    if MySQL.update.await('DELETE FROM otg_saloon_recipes WHERE id=?', { recipeId }) < 1 then return OTG.Notify(src, 'Recipe not found.', 'error') end
    TriggerEvent('otg-saloon:server:reload')
    OTG.Notify(src, 'Recipe deleted.', 'success')
end)

RegisterNetEvent('otg-saloon:server:openStorage', function(businessId)
    local src = source
    businessId = tonumber(businessId)
    if not OTG.HasBusinessAccess(src, businessId, 0) then return end
    local business = OTG.Businesses[businessId]
    local stash = ('otg_saloon_%s_storage'):format(business.slug)
    exports['rsg-inventory']:CreateInventory(stash, {
        label = business.label .. ' Storage',
        maxweight = business.storage_weight,
        slots = business.storage_slots
    })
    exports['rsg-inventory']:OpenInventory(src, stash, {
        label = business.label .. ' Storage',
        maxweight = business.storage_weight,
        slots = business.storage_slots
    })
end)

RegisterNetEvent('otg-saloon:server:openTray', function(businessId, stationId)
    local src = source
    local station, business = OTG.GetStation(businessId, stationId, 'tray')
    if not station or not business or not OTG.DistanceOK(src, vector3(station.x, station.y, station.z), Config.ServerValidationDistance) then return end
    local stash = ('otg_saloon_%s_tray_%s'):format(business.slug, station.id)
    exports['rsg-inventory']:CreateInventory(stash, { label=business.label .. ' - ' .. station.label, maxweight=50000, slots=20, coords=vector3(station.x, station.y, station.z) })
    exports['rsg-inventory']:OpenInventory(src, stash, { label=business.label .. ' - ' .. station.label, maxweight=50000, slots=20 })
end)

lib.callback.register('otg-saloon:server:getFinances', function(src, businessId)
    if not OTG.IsBusinessBoss(src, businessId) then return end
    local business = OTG.Businesses[tonumber(businessId)]
    if not business then return end
    return { balance=business.balance, transactions=MySQL.query.await('SELECT type,amount,description,citizenid,created_at FROM otg_saloon_transactions WHERE business_id=? ORDER BY id DESC LIMIT 50', { businessId }) or {} }
end)


-- V2.5 reference catalogs
local catalog = { blips=nil, objects=nil, loading={} }

local fallbackBlips = {
    { name='blip_saloon', hash=1879260108 },
    { name='blip_shop_store', hash=1475879922 },
    { name='blip_grub', hash=935247438 },
    { name='blip_stable', hash=-73168905 },
    { name='blip_post_office', hash=1861010125 },
    { name='blip_proc_bank', hash=-2128054417 },
    { name='blip_campfire', hash=1754365229 },
    { name='blip_town', hash=-1258576797 }
}

local function fetchJson(url)
    local p=promise.new()
    PerformHttpRequest(url,function(status,body)
        if status and status >= 200 and status < 300 and body and body ~= '' then
            local ok,data=pcall(json.decode,body)
            if ok and type(data)=='table' then return p:resolve(data) end
        end
        p:resolve(nil)
    end,'GET','',{['User-Agent']='otg-saloon/2.5'})
    return Citizen.Await(p)
end

local function normalizeMap(data)
    local out={}
    for hash,name in pairs(data or {}) do
        if type(name)=='string' and name~='' then
            out[#out+1]={hash=tonumber(hash),name=name}
        end
    end
    table.sort(out,function(a,b) return a.name:lower()<b.name:lower() end)
    return out
end

local function load(kind)
    if catalog[kind] then return catalog[kind] end
    local url=Config.ReferenceCatalogs and Config.ReferenceCatalogs[kind]
    local data=url and fetchJson(url) or nil
    catalog[kind]=normalizeMap(data)
    if #catalog[kind]==0 then
        if kind=='blips' then catalog[kind]=fallbackBlips
        else
            catalog[kind]={}
            for _,v in ipairs(Config.PropCatalog or {}) do
                catalog[kind][#catalog[kind]+1]={name=v.model,label=v.label,category=v.category}
            end
        end
        print(('[otg-saloon] %s reference catalog unavailable; using packaged fallback.'):format(kind))
    else
        print(('[otg-saloon] loaded %s %s reference entries.'):format(#catalog[kind],kind))
    end
    return catalog[kind]
end

lib.callback.register('otg-saloon:server:getBlipCatalog',function(source)
    if not canManageAnyBusiness(source) then return {} end
    return load('blips')
end)

lib.callback.register('otg-saloon:server:searchPropCatalog',function(source,query)
    if not canManageAnyBusiness(source) then return {} end
    query=tostring(query or ''):lower():gsub('^%s+',''):gsub('%s+$','')
    if #query < 2 then
        local out={}
        for _,v in ipairs(Config.PropCatalog or {}) do
            out[#out+1]={name=v.model,label=v.label,category=v.category}
        end
        return out
    end
    local all=load('objects')
    local out,limit={},tonumber(Config.ReferenceCatalogs.maxPropResults) or 250
    for _,v in ipairs(all) do
        local name=tostring(v.name or '')
        if name:lower():find(query,1,true) then
            out[#out+1]={name=name,hash=v.hash,label=name,category='RDR2 Object'}
            if #out>=limit then break end
        end
    end
    return out
end)
