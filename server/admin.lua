local RSGCore = exports['rsg-core']:GetCoreObject()

------------------------------------------------
-- Admin Command System for Saloon/Restaurant Management
-- Uses RSG-Core group permissions (group.admin)
-- Admins can set up saloons, manage recipes, and configure all settings
------------------------------------------------

-- Config.AdminGroup is written as 'group.admin' (RSG/QB style), but the ace
-- system created by rsg-core uses the bare level name ('rsgcore.admin').
local function GetAdminLevel()
    local level = tostring(Config.AdminGroup or 'admin')
    return (level:gsub('^group%.', ''))
end

local function IsAdminGroupName(group)
    if type(group) ~= 'string' then return false end
    if Config.AdminGroup and group == Config.AdminGroup then return true end

    local level = GetAdminLevel()
    return group == level or group == 'admin' or group == 'superadmin' or group == 'god'
end

-- Helper function to check if player is admin.
-- NOTE: this is a pure permission check. Feature toggles (Config.EnableAdminCommands
-- / Config.EnableCreator) are evaluated by the command handlers themselves so that
-- disabling the /saloon commands does not also lock admins out of the creator.
local function IsPlayerAdmin(src)
    src = tonumber(src)
    if not src then return false end

    -- The server console (source 0) is always allowed so saloons can be managed
    -- from the console even when no admin is connected.
    if src == 0 then return true end

    -- Ace permissions are checked first: they also cover ace-only admins who are
    -- not registered as an in-game character (and never reach PlayerData.group).
    if IsPlayerAceAllowed(src, ('rsgcore.%s'):format(GetAdminLevel())) then
        return true
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return false end

    local groups = Player.PlayerData and Player.PlayerData.group
    if type(groups) == 'table' then
        for group in pairs(groups) do
            if IsAdminGroupName(group) then return true end
        end
    elseif IsAdminGroupName(groups) then
        return true
    end

    -- rsg-core's own helper, which reads the same ace system as commands.lua.
    if type(RSGCore.Functions.HasPermission) == 'function' then
        if RSGCore.Functions.HasPermission(src, GetAdminLevel())
            or RSGCore.Functions.HasPermission(src, 'admin') then
            return true
        end
    end

    return false
end

exports('IsPlayerAdmin', IsPlayerAdmin)

------------------------------------------------
-- Saloon location persistence (data/saloons_data.json)
------------------------------------------------
-- config.lua declares Config.Saloons in memory, the JSON file is the
-- persistent copy that server/main.lua reads back on startup.
--
-- json.encode(vector3(x, y, z)) produces the plain array [x, y, z], so the
-- coordinates have to be converted to { x =, y =, z = } tables before writing
-- (otherwise coords.x is nil after the next restart and every native that needs
-- a vector breaks). OTGSaloons.SaloonsToJson from shared/utils.lua does that,
-- and LoadSaloonLocations() converts them back into real vector3 values.
------------------------------------------------
local function WriteSaloonLocations()
    local jsonContent = json.encode(OTGSaloons.SaloonsToJson(Config.Saloons), { indent = true })
    SaveResourceFile(GetCurrentResourceName(), Config.SaloonDataDir, jsonContent, -1)
end

------------------------------------------------
-- Creator System: Permission Check
------------------------------------------------
-- The client core object has no GetPlayer (that function only exists on the
-- server), so client/creator.lua asks the server whether the player is allowed
-- to open the creator instead of calling GetPlayer itself.
RegisterNetEvent('otg-saloons:server:creator:checkPermission', function()
    local src = source
    local allowed = IsPlayerAdmin(src) and Config.EnableCreator and true or false
    TriggerClientEvent('otg-saloons:client:creator:permission', src, allowed)
end)

------------------------------------------------
-- Admin Command: Saloon Management
-- Usage: /saloon create [id] [label]
--        /saloon delete [id]
--        /saloon list
------------------------------------------------
RegisterCommand('saloon', function(source, args)
    local src = source
    if not Config.EnableAdminCommands then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Disabled', 'Admin commands are disabled in the config', 'error')
        return
    end

    if not IsPlayerAdmin(src) then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Access Denied', 'You do not have permission to use this command', 'error')
        return
    end

    if #args < 1 then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Usage', '/saloon create [id] [label] or /saloon list or /saloon delete [id]', 'info')
        return
    end

    local action = string.lower(args[1])

    if action == 'create' then
        if #args < 3 then
            TriggerClientEvent('otg-saloons:client:notify', src, 'Usage', '/saloon create [id] [label]', 'info')
            return
        end

        local saloonId = args[2]
        local label = table.concat({select(3, unpack(args))}, ' ')
        local Player = RSGCore.Functions.GetPlayer(src)
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)

        -- Check if saloon ID already exists in config
        local exists = false
        for _, s in pairs(Config.Saloons) do
            if s.id == saloonId then
                exists = true
                break
            end
        end

        if exists then
            TriggerClientEvent('otg-saloons:client:notify', src, 'Error', 'A saloon with this ID already exists', 'error')
            return
        end

                -- Create new saloon in database
        MySQL.insert('INSERT INTO otg_saloons (saloon_id, owner, stock, cash_balance) VALUES (?, ?, ?, ?)', {
            saloonId,
            nil,
            json.encode({}),
            0.0
        })

        -- Add to Config.Saloons with full data
        Config.Saloons[#Config.Saloons + 1] = {
            id = saloonId,
            label = label,
            coords = vector3(coords.x, coords.y, coords.z),
            counterCoords = vector3(coords.x, coords.y, coords.z),
            cashRegisterCoords = vector3(coords.x, coords.y + 1.0, coords.z),
            craftingCoords = vector3(coords.x, coords.y - 1.0, coords.z),
            musicCoords = vector3(coords.x, coords.y - 2.0, coords.z),
            dancerCoords = vector3(coords.x, coords.y + 2.0, coords.z),
            blip = {
                enabled = true,
                sprite = 'blip_shop_store',
                scale = 0.2,
                color = 'BLIP_MODIFIER_MP_COLOR_6',
            },
            defaultStock = {
                beer = 50,
                whiskey = 30,
                bread = 25,
                stew = 20,
                coffee = 30,
            },
        }

        -- Save to JSON file for persistence
        WriteSaloonLocations()

        -- Initialize in memory
        OTGSaloons.Saloons[saloonId] = {
            id = saloonId,
            label = label,
            owner = nil,
            stock = {},
            cashBalance = 0,
            musicTrack = 0,
            musicVolume = 0.5,
            musicEnabled = false,
        }
        OTGSaloons.SaloonCash[saloonId] = 0
        OTGSaloons.SaloonStock[saloonId] = {}
        OTGSaloons.SaloonOrders[saloonId] = {}
        OTGSaloons.SaloonMusic[saloonId] = {
            track = 0,
            volume = 0.5,
            enabled = false,
        }
        OTGSaloons.SaloonDancers[saloonId] = {}
        OTGSaloons.SaloonCounterItems[saloonId] = {}
        OTGSaloons.SaloonEmployees[saloonId] = {}

        TriggerClientEvent('otg-saloons:client:saloonCreated', -1, saloonId, label, coords)

        print(('[otg-saloons] Saloon "%s" (%s) created by admin %s'):format(label, saloonId, tostring(src)))
        TriggerClientEvent('otg-saloons:client:notify', src, 'Saloon Created', 'Created saloon: ' .. label, 'success')
    end

    if action == 'delete' then
        if #args < 2 then
            TriggerClientEvent('otg-saloons:client:notify', src, 'Usage', '/saloon delete [id]', 'info')
            return
        end

        local saloonId = args[2]
        local saloon = nil
        local saloonIndex = nil

        for i, s in ipairs(Config.Saloons) do
            if s.id == saloonId then
                saloon = s
                saloonIndex = i
                break
            end
        end

        if not saloon then
            TriggerClientEvent('otg-saloons:client:notify', src, 'Error', 'Saloon not found', 'error')
            return
        end

        MySQL.prepare('DELETE FROM otg_saloons WHERE saloon_id = ?', { saloonId })
        MySQL.prepare('DELETE FROM otg_saloon_employees WHERE saloon_id = ?', { saloonId })
        MySQL.prepare('DELETE FROM otg_saloon_sales WHERE saloon_id = ?', { saloonId })
        MySQL.prepare('DELETE FROM otg_saloon_orders WHERE saloon_id = ?', { saloonId })
        MySQL.prepare('DELETE FROM otg_saloon_interactions WHERE saloon_id = ?', { saloonId })

        if saloonIndex then
            table.remove(Config.Saloons, saloonIndex)
        end

        -- Save updated saloon list to JSON file
        WriteSaloonLocations()

        OTGSaloons.Saloons[saloonId] = nil
        OTGSaloons.SaloonCash[saloonId] = nil
        OTGSaloons.SaloonStock[saloonId] = nil
        OTGSaloons.SaloonOrders[saloonId] = nil
        OTGSaloons.SaloonMusic[saloonId] = nil
        OTGSaloons.SaloonDancers[saloonId] = nil
        OTGSaloons.SaloonCounterItems[saloonId] = nil
        OTGSaloons.SaloonEmployees[saloonId] = nil

        TriggerClientEvent('otg-saloons:client:saloonDeleted', -1, saloonId)
        print(('[otg-saloons] Saloon %s deleted by admin %s'):format(saloonId, tostring(src)))
        TriggerClientEvent('otg-saloons:client:notify', src, 'Saloon Deleted', 'Deleted saloon: ' .. saloonId, 'success')
    end

    if action == 'list' then
        local saloonList = {}
        for _, s in ipairs(Config.Saloons) do
            table.insert(saloonList, {
                id = s.id,
                label = s.label,
                owner = s.owner or 'Unowned',
            })
        end
        TriggerClientEvent('otg-saloons:client:saloonList', src, saloonList)
    end
end, false)

------------------------------------------------
-- Admin Command: Recipe Management
-- Usage: /recipe list [saloon_id]
--        /recipe remove [saloon_id] [recipe_name]
--        /recipe add [saloon_id] [recipe_name]
------------------------------------------------
RegisterCommand('recipe', function(source, args)
    local src = source
    if not Config.EnableAdminCommands or not Config.EnableRecipeManagement then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Disabled', 'Recipe management is disabled in the config', 'error')
        return
    end

    if not IsPlayerAdmin(src) then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Access Denied', 'You do not have permission to use this command', 'error')
        return
    end

    if #args < 2 then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Usage', '/recipe list [saloon_id] | /recipe remove [saloon_id] [recipe_name] | /recipe add [saloon_id] [recipe_name]', 'info')
        return
    end

    local action = string.lower(args[1])
    local saloonId = args[2]
    local saloon = OTGSaloons.Saloons[saloonId]

    if not saloon then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Error', 'Saloon not found', 'error')
        return
    end

    if action == 'list' then
        local recipeList = {}
        if saloon.recipes then
            for recipeName, recipe in pairs(saloon.recipes) do
                table.insert(recipeList, {
                    name = recipeName,
                    display_name = recipe.display_name,
                    price = recipe.price,
                    category = recipe.category or 'General',
                })
            end
        end

        if #recipeList == 0 then
            TriggerClientEvent('otg-saloons:client:notify', src, 'Recipes', 'No recipes found for this saloon', 'info')
        else
            TriggerClientEvent('otg-saloons:client:openRecipeList', src, recipeList, saloonId)
        end
    elseif action == 'remove' then
        if #args < 3 then
            TriggerClientEvent('otg-saloons:client:notify', src, 'Usage', '/recipe remove [saloon_id] [recipe_name]', 'info')
            return
        end

        local recipeName = args[3]
        if not saloon.recipes or not saloon.recipes[recipeName] then
            TriggerClientEvent('otg-saloons:client:notify', src, 'Error', 'Recipe not found for this saloon', 'error')
            return
        end

        MySQL.prepare('DELETE FROM otg_saloon_recipes WHERE saloon_id = ? AND recipe_name = ?', { saloonId, recipeName })
        saloon.recipes[recipeName] = nil
        TriggerClientEvent('otg-saloons:client:notify', src, 'Recipe Removed', 'Removed recipe: ' .. recipeName, 'success')
        TriggerClientEvent('otg-saloons:client:recipeRemoved', -1, saloonId, recipeName)
    elseif action == 'add' then
        if #args < 3 then
            TriggerClientEvent('otg-saloons:client:notify', src, 'Usage', '/recipe add [saloon_id] [recipe_name]', 'info')
            return
        end

        local recipeName = args[3]
        TriggerClientEvent('otg-saloons:client:notify', src, 'Recipe Creation', 'Creating recipe "' .. recipeName .. '" for saloon "' .. saloonId .. '"', 'info')
        TriggerClientEvent('otg-saloons:client:openRecipeEditor', src, saloonId, recipeName)
    else
        TriggerClientEvent('otg-saloons:client:notify', src, 'Usage', '/recipe list [saloon_id] | /recipe remove [saloon_id] [recipe_name] | /recipe add [saloon_id] [recipe_name]', 'info')
    end
end, false)

------------------------------------------------
-- Admin Command: Stock Management
-- Usage: /stock set [saloon_id] [item_name] [amount]
------------------------------------------------
RegisterCommand('stock', function(source, args)
    local src = source
    if not Config.EnableAdminCommands then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Disabled', 'Admin commands are disabled in the config', 'error')
        return
    end

    if not IsPlayerAdmin(src) then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Access Denied', 'You do not have permission to use this command', 'error')
        return
    end

    if #args < 4 then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Usage', '/stock set [saloon_id] [item_name] [amount]', 'info')
        return
    end

    local action = string.lower(args[1])
    if action ~= 'set' then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Usage', '/stock set [saloon_id] [item_name] [amount]', 'info')
        return
    end

    local saloonId = args[2]
    local itemName = args[3]
    local amount = tonumber(args[4]) or 0
    local saloon = OTGSaloons.Saloons[saloonId]

    if not saloon then
        TriggerClientEvent('otg-saloons:client:notify', src, 'Error', 'Saloon not found', 'error')
        return
    end

    saloon.stock[itemName] = amount
    SaveSaloonData(saloonId)
    TriggerClientEvent('otg-saloons:client:notify', src, 'Stock Updated', 'Updated stock for ' .. itemName .. ' to ' .. amount, 'success')
    TriggerClientEvent('otg-saloons:client:saloonStockUpdated', -1, saloonId, itemName, amount)
end, false)

------------------------------------------------
-- Creator System: Save Saloon from In-Game Creator
------------------------------------------------
RegisterNetEvent('otg-saloons:creator:saveSaloon', function(saloonData)
    local src = source
    
    if not Config.EnableCreator then
        TriggerClientEvent('otg-saloons:creator:saloonSaved', src, saloonData.id or 'unknown', false, 'Creator system is disabled')
        return
    end

    if not IsPlayerAdmin(src) then
        TriggerClientEvent('otg-saloons:creator:saloonSaved', src, saloonData.id or 'unknown', false, 'Insufficient permissions')
        return
    end

    if not saloonData.id or saloonData.id == '' then
        TriggerClientEvent('otg-saloons:creator:saloonSaved', src, 'unknown', false, 'Saloon ID is required')
        return
    end

    if not saloonData.label or saloonData.label == '' then
        TriggerClientEvent('otg-saloons:creator:saloonSaved', src, saloonData.id, false, 'Saloon label is required')
        return
    end

    -- Check if saloon already exists
    local existing = MySQL.single.await('SELECT saloon_id FROM otg_saloons WHERE saloon_id = ?', { saloonData.id })
    if existing then
        TriggerClientEvent('otg-saloons:creator:saloonSaved', src, saloonData.id, false, 'A saloon with this ID already exists')
        return
    end

    -- Convert vector3 to table for storage
    local vecToTable = OTGSaloons.CoordsToTable

    -- Prepare saloon data for database
    local saloonRecord = {
        id = saloonData.id,
        label = saloonData.label,
        coords = saloonData.coords,
        counterCoords = saloonData.counterCoords or saloonData.coords,
        cashRegisterCoords = saloonData.cashRegisterCoords or saloonData.coords,
        craftingCoords = saloonData.craftingCoords or saloonData.coords,
        musicCoords = saloonData.musicCoords or saloonData.coords,
        dancerCoords = saloonData.dancerCoords or saloonData.coords,
        zoneRadius = saloonData.zoneRadius or 5.0,
        blip = saloonData.blip,
        defaultStock = saloonData.defaultStock,
    }

    -- Insert into database
    local stockJson = json.encode(saloonData.defaultStock or {})
    local coordsJson = json.encode(vecToTable(saloonData.coords))

    MySQL.insert('INSERT INTO otg_saloons (saloon_id, owner, stock, cash_balance) VALUES (?, ?, ?, ?)', {
        saloonData.id,
        nil,
        stockJson,
        0.0
    })

    -- Add to Config.Saloons
    Config.Saloons[#Config.Saloons + 1] = saloonRecord

    -- Initialize in memory
    OTGSaloons.Saloons[saloonData.id] = {
        id = saloonData.id,
        label = saloonData.label,
        owner = nil,
        stock = saloonData.defaultStock or {},
        cashBalance = 0,
        coords = saloonData.coords,
        counterCoords = saloonData.counterCoords or saloonData.coords,
        cashRegisterCoords = saloonData.cashRegisterCoords or saloonData.coords,
        craftingCoords = saloonData.craftingCoords or saloonData.coords,
        musicCoords = saloonData.musicCoords or saloonData.coords,
        dancerCoords = saloonData.dancerCoords or saloonData.coords,
    }
    OTGSaloons.SaloonCash[saloonData.id] = 0
    OTGSaloons.SaloonStock[saloonData.id] = saloonData.defaultStock or {}
    OTGSaloons.SaloonOrders[saloonData.id] = {}
    OTGSaloons.SaloonMusic[saloonData.id] = {
        track = 0,
        volume = 0.5,
        enabled = false,
    }
    OTGSaloons.SaloonDancers[saloonData.id] = {}
    OTGSaloons.SaloonCounterItems[saloonData.id] = {}
    OTGSaloons.SaloonEmployees[saloonData.id] = {}

    -- Save to JSON file for persistence
    WriteSaloonLocations()

    -- Notify clients
    TriggerClientEvent('otg-saloons:client:saloonCreated', -1, saloonData.id, saloonData.label, saloonData.coords)
    TriggerClientEvent('otg-saloons:creator:saloonSaved', src, saloonData.id, true, 'Saloon created successfully')

    print(('[otg-saloons] Saloon "%s" (%s) created via in-game creator by admin %s'):format(saloonData.label, saloonData.id, tostring(src)))
end)