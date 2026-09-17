local RSGCore = exports['rsg-core']:GetCoreObject()


OTGSaloons.Saloons = OTGSaloons.Saloons or {}
OTGSaloons.OwnedSaloons = OTGSaloons.OwnedSaloons or {}
OTGSaloons.SaloonStock = OTGSaloons.SaloonStock or {}
OTGSaloons.SaloonCash = OTGSaloons.SaloonCash or {}
OTGSaloons.SaloonEmployees = OTGSaloons.SaloonEmployees or {}
OTGSaloons.SaloonOrders = OTGSaloons.SaloonOrders or {}
OTGSaloons.SaloonMusic = OTGSaloons.SaloonMusic or {}
OTGSaloons.SaloonDancers = OTGSaloons.SaloonDancers or {}
OTGSaloons.SaloonCounterItems = OTGSaloons.SaloonCounterItems or {}


local notifyTemplates = {
    info = 'INFO',
    success = 'SUCCESS',
    error = 'ERROR',
    warning = 'INFO', 
}

function OTGSaloons.Notify(target, title, description, type, duration)
    type = tostring(type or 'info'):lower()
    duration = duration or 5000

    if Config.Notifications.UseOxLib then
        TriggerClientEvent('ox_lib:notify', target, {
            title = title,
            description = description,
            type = type,
            duration = duration,
        })
        return
    end

    if Config.Notifications.UseBlnNotify and GetResourceState('bln_notify') == 'started' then
        local ok = pcall(function()
            exports['bln_notify']:send(target, {
                title = title,
                description = description,
                duration = duration,
            }, notifyTemplates[type] or 'INFO')
        end)
        if ok then return end
        print(('[%s] ^3WARN^7 bln_notify:send failed, falling back to client notifications'):format(GetCurrentResourceName()))
    end


    TriggerClientEvent('otg-saloons:client:notify', target, title, description, type, duration)
end

-----------------------------------------------
-- Database Setup
------------------------------------------------
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS otg_saloons (
            id INT AUTO_INCREMENT PRIMARY KEY,
            saloon_id VARCHAR(64) NOT NULL,
            owner VARCHAR(64) DEFAULT NULL,
            stock LONGTEXT NOT NULL,
            cash_balance DECIMAL(10,2) DEFAULT 0,
            music_track INT DEFAULT 0,
            music_volume DECIMAL(3,2) DEFAULT 0.5,
            music_enabled TINYINT(1) DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY unique_saloon (saloon_id)
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS otg_saloon_employees (
            id INT AUTO_INCREMENT PRIMARY KEY,
            saloon_id VARCHAR(64) NOT NULL,
            citizenid VARCHAR(64) NOT NULL,
            role VARCHAR(32) DEFAULT 'bartender',
            wage DECIMAL(10,2) DEFAULT 25,
            clocked_in TINYINT(1) DEFAULT 0,
            clock_in_time TIMESTAMP NULL DEFAULT NULL,
            total_hours DECIMAL(10,2) DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_employee (saloon_id, citizenid)
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS otg_saloon_sales (
            id INT AUTO_INCREMENT PRIMARY KEY,
            saloon_id VARCHAR(64) NOT NULL,
            item VARCHAR(64) NOT NULL,
            amount INT DEFAULT 1,
            price DECIMAL(10,2) DEFAULT 0,
            buyer VARCHAR(64) DEFAULT NULL,
            seller VARCHAR(64) DEFAULT NULL,
            sale_type VARCHAR(32) DEFAULT 'counter',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS otg_saloon_orders (
            id INT AUTO_INCREMENT PRIMARY KEY,
            saloon_id VARCHAR(64) NOT NULL,
            customer VARCHAR(64) NOT NULL,
            item VARCHAR(64) NOT NULL,
            amount INT DEFAULT 1,
            status VARCHAR(32) DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS otg_saloon_recipes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            saloon_id VARCHAR(64) NOT NULL,
            recipe_name VARCHAR(64) NOT NULL,
            display_name VARCHAR(128) NOT NULL,
            category VARCHAR(32),
            craft_time INT DEFAULT 5000,
            price DECIMAL(10,2) DEFAULT 0.00,
            ingredients LONGTEXT NOT NULL,
            receive_item VARCHAR(64) NOT NULL,
            receive_amount INT DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            UNIQUE KEY unique_saloon_recipe (saloon_id, recipe_name)
        )
    ]])

    -- Load all saloon data
    LoadAllSaloonData()
end)

------------------------------------------------
-- Load Saloon Data
------------------------------------------------
-- Load saloon locations from JSON file, then load their data from database
------------------------------------------------
function LoadSaloonLocations()
    local dataFilePath = Config.SaloonDataDir
    local raw = LoadResourceFile(GetCurrentResourceName(), dataFilePath)
    
    if raw then
        local success, data = pcall(json.decode, raw)
        if success and data and type(data) == 'table' then
            -- json.decode returns plain { x =, y =, z = } tables, so they have to
            -- be turned back into real vector3 values (see shared/utils.lua).
            Config.Saloons = OTGSaloons.NormalizeSaloons(data)
            print(('[otg-saloons] ^2LOAD^7 loaded %d saloons from JSON file: %s'):format(#Config.Saloons, dataFilePath))
        else
            print('[otg-saloons] ^1LOAD^7 failed to parse JSON, using empty saloon list')
            Config.Saloons = {}
        end
    else
        -- File doesn't exist yet - start with empty list, admin can create saloons in-game
        Config.Saloons = {}
        print('[otg-saloons] ^3INFO^7 no saloon data file found, starting with empty saloon list')
    end
end

function LoadAllSaloonData()
    local resourceName = GetCurrentResourceName()
    OTGSaloons.DebugPrint('loading saloon data')
    
    -- First load saloon locations from JSON
    LoadSaloonLocations()
    
    local loadedCount = 0
    for _, saloon in pairs(Config.Saloons) do
        local result = MySQL.single.await('SELECT * FROM otg_saloons WHERE saloon_id = ?', { saloon.id })
        if result then
            OTGSaloons.Saloons[saloon.id] = {
                id = saloon.id,
                label = saloon.label,
                owner = result.owner,
                stock = json.decode(result.stock) or saloon.defaultStock or {},
                cashBalance = tonumber(result.cash_balance) or 0,
                musicTrack = tonumber(result.music_track) or 0,
                musicVolume = tonumber(result.music_volume) or 0.5,
                musicEnabled = result.music_enabled == 1,
            }
            OTGSaloons.DebugPrint(('loaded DB row for %s owner=%s'):format(saloon.id, tostring(result.owner)))
        else
            -- Create default saloon data
            OTGSaloons.Saloons[saloon.id] = {
                id = saloon.id,
                label = saloon.label,
                owner = nil,
                stock = saloon.defaultStock or {},
                cashBalance = 0,
                musicTrack = 0,
                musicVolume = 0.5,
                musicEnabled = false,
            }
            MySQL.insert('INSERT INTO otg_saloons (saloon_id, owner, stock, cash_balance) VALUES (?, ?, ?, ?)', {
                saloon.id,
                nil,
                json.encode(saloon.defaultStock or {}),
                0,
            })
            OTGSaloons.DebugPrint(('created default data for %s'):format(saloon.id))
        end

        loadedCount = loadedCount + 1

        -- Load employees
        local employees = MySQL.query.await('SELECT * FROM otg_saloon_employees WHERE saloon_id = ?', { saloon.id })
        OTGSaloons.SaloonEmployees[saloon.id] = {}
        for _, emp in pairs(employees or {}) do
            OTGSaloons.SaloonEmployees[saloon.id][emp.citizenid] = {
                citizenid = emp.citizenid,
                role = emp.role,
                wage = tonumber(emp.wage) or Config.Employees.DefaultWage,
                clockedIn = emp.clocked_in == 1,
                clockInTime = emp.clock_in_time,
                totalHours = tonumber(emp.total_hours) or 0,
            }
        end

        -- Load recipes for this saloon
        local recipes = MySQL.query.await('SELECT * FROM otg_saloon_recipes WHERE saloon_id = ?', { saloon.id })
        OTGSaloons.Saloons[saloon.id].recipes = {}
        for _, recipe in pairs(recipes or {}) do
            OTGSaloons.Saloons[saloon.id].recipes[recipe.recipe_name] = {
                display_name = recipe.display_name,
                category = recipe.category,
                craft_time = recipe.craft_time,
                price = tonumber(recipe.price),
                ingredients = json.decode(recipe.ingredients),
                receive_item = recipe.receive_item,
                receive_amount = recipe.receive_amount,
            }
        end

        -- Initialize other data structures
        OTGSaloons.SaloonCash[saloon.id] = OTGSaloons.Saloons[saloon.id].cashBalance
        OTGSaloons.SaloonStock[saloon.id] = OTGSaloons.Saloons[saloon.id].stock
        OTGSaloons.SaloonOrders[saloon.id] = {}
        OTGSaloons.SaloonMusic[saloon.id] = {
            track = OTGSaloons.Saloons[saloon.id].musicTrack,
            volume = OTGSaloons.Saloons[saloon.id].musicVolume,
            enabled = OTGSaloons.Saloons[saloon.id].musicEnabled,
        }
        OTGSaloons.SaloonDancers[saloon.id] = {}
        OTGSaloons.SaloonCounterItems[saloon.id] = {}
    end

    print(('[%s] ^2LOAD^7 finished loading %d saloons'):format(resourceName, loadedCount))
end

------------------------------------------------
-- Save Saloon Data
------------------------------------------------
function SaveSaloonData(saloonId)
    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    MySQL.prepare('UPDATE otg_saloons SET owner = ?, stock = ?, cash_balance = ?, music_track = ?, music_volume = ?, music_enabled = ? WHERE saloon_id = ?', {
        saloon.owner,
        json.encode(saloon.stock),
        saloon.cashBalance,
        saloon.musicTrack,
        saloon.musicVolume,
        saloon.musicEnabled and 1 or 0,
        saloonId,
    })
end

------------------------------------------------
-- Get Saloon Data (for client)
------------------------------------------------
RegisterNetEvent('otg-saloons:server:getSaloonData', function(saloonId)
    local src = source
    local resourceName = GetCurrentResourceName()
    print(('[%s] ^2REQ^7 getSaloonData src=%s saloonId=%s'):format(resourceName, tostring(src), tostring(saloonId)))

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then
        print(('[%s] ^1DATA^7 saloon not found in OTGSaloons.Saloons for %s'):format(resourceName, tostring(saloonId)))
        return
    end

    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        print(('[%s] ^3DATA^7 no RSGCore player for src=%s'):format(resourceName, tostring(src)))
        return
    end

    local playerCitizenId = Player.PlayerData and Player.PlayerData.citizenid
    print(('[%s] ^2DATA^7 player=%s citizenid=%s saloonOwner=%s'):format(resourceName, tostring(src), tostring(playerCitizenId), tostring(saloon.owner)))

    local isOwner = saloon.owner == playerCitizenId
    local isEmployee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][playerCitizenId] ~= nil
    print(('[%s] ^2DATA^7 isOwner=%s isEmployee=%s'):format(resourceName, tostring(isOwner), tostring(isEmployee)))

    TriggerClientEvent('otg-saloons:client:receiveSaloonData', src, {
        id = saloon.id,
        label = saloon.label,
        owner = saloon.owner,
        isOwner = isOwner,
        isEmployee = isEmployee,
        employeeRole = isEmployee and OTGSaloons.SaloonEmployees[saloonId][playerCitizenId].role or nil,
        stock = saloon.stock,
        cashBalance = saloon.cashBalance,
        music = OTGSaloons.SaloonMusic[saloonId],
        counterItems = OTGSaloons.SaloonCounterItems[saloonId],
        recipes = saloon.recipes or {},
    })
    print(('[%s] ^2DATA^7 sent saloon data to %s for %s'):format(resourceName, tostring(src), tostring(saloonId)))
end)

------------------------------------------------
-- Ownership System
------------------------------------------------
RegisterNetEvent('otg-saloons:server:purchaseSaloon', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then
        OTGSaloons.Notify(src, 'Saloon not found', nil, 'error')
        return
    end

    if saloon.owner then
        OTGSaloons.Notify(src, 'This saloon is already owned', nil, 'error')
        return
    end

    -- Check if player already owns a saloon
    local ownedCount = 0
    for _, s in pairs(OTGSaloons.Saloons) do
        if s.owner == Player.PlayerData.citizenid then
            ownedCount = ownedCount + 1
        end
    end
    if ownedCount >= Config.Ownership.MaxOwnedSaloons then
        OTGSaloons.Notify(src, 'You already own the maximum number of saloons', nil, 'error')
        return
    end

    -- Check if player has enough money
    if Player.Functions.GetMoney('cash') < Config.Ownership.PurchasePrice then
        OTGSaloons.Notify(src, 'Not enough money', 'You need $' .. Config.Ownership.PurchasePrice, 'error')
        return
    end

    -- Purchase the saloon
    Player.Functions.RemoveMoney('cash', Config.Ownership.PurchasePrice, 'saloon-purchase')
    saloon.owner = Player.PlayerData.citizenid
    SaveSaloonData(saloonId)

    -- Add owner as manager employee
    OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid] = {
        citizenid = Player.PlayerData.citizenid,
        role = 'manager',
        wage = 0,
        clockedIn = false,
        clockInTime = nil,
        totalHours = 0,
    }
    MySQL.insert('INSERT INTO otg_saloon_employees (saloon_id, citizenid, role, wage) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE role = ?', {
        saloonId,
        Player.PlayerData.citizenid,
        'manager',
        0,
        'manager',
    })

    OTGSaloons.Notify(src, 'Saloon Purchased!', 'You are now the owner of ' .. saloon.label, 'success')
    TriggerClientEvent('otg-saloons:client:saloonOwnershipChanged', -1, saloonId, Player.PlayerData.citizenid)
end)

RegisterNetEvent('otg-saloons:server:sellSaloon', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    if saloon.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'You do not own this saloon', nil, 'error')
        return
    end

    -- Sell the saloon
    Player.Functions.AddMoney('cash', Config.Ownership.SellPrice, 'saloon-sell')
    saloon.owner = nil
    SaveSaloonData(saloonId)

    -- Remove all employees
    for citizenid, _ in pairs(OTGSaloons.SaloonEmployees[saloonId]) do
        MySQL.prepare('DELETE FROM otg_saloon_employees WHERE saloon_id = ? AND citizenid = ?', { saloonId, citizenid })
    end
    OTGSaloons.SaloonEmployees[saloonId] = {}

    OTGSaloons.Notify(src, 'Saloon Sold!', 'You received $' .. Config.Ownership.SellPrice, 'success')
    TriggerClientEvent('otg-saloons:client:saloonOwnershipChanged', -1, saloonId, nil)
end)

RegisterNetEvent('otg-saloons:server:transferSaloon', function(saloonId, targetCitizenId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if not Config.Ownership.AllowTransfer then
        OTGSaloons.Notify(src, 'Transfers are disabled', nil, 'error')
        return
    end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    if saloon.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'You do not own this saloon', nil, 'error')
        return
    end

    -- Find target player
    local targetPlayer = nil
    for _, p in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if p.PlayerData.citizenid == targetCitizenId then
            targetPlayer = p
            break
        end
    end

    if not targetPlayer then
        OTGSaloons.Notify(src, 'Target player not found', nil, 'error')
        return
    end

    -- Transfer ownership
    saloon.owner = targetCitizenId
    SaveSaloonData(saloonId)

    -- Update employee roles
    OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid] = nil
    MySQL.prepare('DELETE FROM otg_saloon_employees WHERE saloon_id = ? AND citizenid = ?', { saloonId, Player.PlayerData.citizenid })

    OTGSaloons.SaloonEmployees[saloonId][targetCitizenId] = {
        citizenid = targetCitizenId,
        role = 'manager',
        wage = 0,
        clockedIn = false,
        clockInTime = nil,
        totalHours = 0,
    }
    MySQL.insert('INSERT INTO otg_saloon_employees (saloon_id, citizenid, role, wage) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE role = ?', {
        saloonId,
        targetCitizenId,
        'manager',
        0,
        'manager',
    })

    OTGSaloons.Notify(src, 'Saloon Transferred!', nil, 'success')
    OTGSaloons.Notify(targetPlayer.PlayerData.source, 'You received a saloon!', saloon.label, 'success')
    TriggerClientEvent('otg-saloons:client:saloonOwnershipChanged', -1, saloonId, targetCitizenId)
end)

------------------------------------------------
-- Dancer Tip System
------------------------------------------------
RegisterNetEvent('otg-saloons:server:tipDancer', function(saloonId, targetPlayerId, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local targetPlayer = RSGCore.Functions.GetPlayer(targetPlayerId)
    if not targetPlayer then
        OTGSaloons.Notify(src, 'Dancer not found', nil, 'error')
        return
    end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    -- Check if player has enough money
    if Player.Functions.GetMoney('cash') < amount then
        OTGSaloons.Notify(src, 'Not enough money', nil, 'error')
        return
    end

    -- Transfer the tip
    Player.Functions.RemoveMoney('cash', amount, 'saloon-dancer-tip')
    targetPlayer.Functions.AddMoney('cash', amount, 'saloon-dancer-tip')

    OTGSaloons.Notify(src, 'Tip Given!', 'You tipped $' .. string.format('%.2f', amount), 'success')
    OTGSaloons.Notify(targetPlayerId, 'Tip Received!', 'You received $' .. string.format('%.2f', amount) .. ' from ' .. Player.PlayerData.charinfo.firstname, 'success')
end)

------------------------------------------------
-- Player Disconnect Cleanup
------------------------------------------------
AddEventHandler('playerDropped', function(reason)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Clock out any employees
    for saloonId, employees in pairs(OTGSaloons.SaloonEmployees) do
        local emp = employees[Player.PlayerData.citizenid]
        if emp and emp.clockedIn then
            emp.clockedIn = false
            emp.clockInTime = nil
            MySQL.prepare('UPDATE otg_saloon_employees SET clocked_in = 0, clock_in_time = NULL WHERE saloon_id = ? AND citizenid = ?', {
                saloonId,
                Player.PlayerData.citizenid,
            })
        end
    end
end)

------------------------------------------------
-- Recipe Management
------------------------------------------------
RegisterNetEvent('otg-saloons:server:getRecipes', function(saloonId, context)
    local src = source
    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- For now, we'll send the same data regardless of context
    -- The client can decide how to display it based on context
    TriggerClientEvent('otg-saloons:client:receiveRecipes', src, saloon.recipes or {}, context or 'management')
end)

RegisterNetEvent('otg-saloons:server:addRecipe', function(saloonId, recipeData)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon or saloon.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Unauthorized', nil, 'error')
        return
    end

    -- Validate recipe data
    if not recipeData.recipe_name or not recipeData.display_name or not recipeData.receive_item then
        OTGSaloons.Notify(src, 'Invalid recipe data', nil, 'error')
        return
    end

    -- Check if recipe already exists
    if saloon.recipes and saloon.recipes[recipeData.recipe_name] then
        OTGSaloons.Notify(src, 'Recipe already exists', nil, 'error')
        return
    end

    -- Add to database
    local success = MySQL.insert.await('INSERT INTO otg_saloon_recipes (saloon_id, recipe_name, display_name, category, craft_time, price, ingredients, receive_item, receive_amount) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        saloonId,
        recipeData.recipe_name,
        recipeData.display_name,
        recipeData.category or '',
        recipeData.craft_time or 5000,
        recipeData.price or 0.00,
        json.encode(recipeData.ingredients or {}),
        recipeData.receive_item,
        recipeData.receive_amount or 1
    })

    if success then
        -- Add to memory
        if not saloon.recipes then saloon.recipes = {} end
        saloon.recipes[recipeData.recipe_name] = {
            display_name = recipeData.display_name,
            category = recipeData.category,
            craft_time = recipeData.craft_time or 5000,
            price = recipeData.price or 0.00,
            ingredients = recipeData.ingredients or {},
            receive_item = recipeData.receive_item,
            receive_amount = recipeData.receive_amount or 1,
        }

        OTGSaloons.Notify(src, 'Recipe added successfully', nil, 'success')
        -- Notify clients about the update
        TriggerClientEvent('otg-saloons:client:receiveRecipes', -1, saloon.recipes)
    else
        OTGSaloons.Notify(src, 'Failed to add recipe', nil, 'error')
    end
end)

RegisterNetEvent('otg-saloons:server:updateRecipe', function(saloonId, recipeName, recipeData)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon or saloon.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Unauthorized', nil, 'error')
        return
    end

    -- Validate recipe data
    if not recipeName or not recipeData.display_name or not recipeData.receive_item then
        OTGSaloons.Notify(src, 'Invalid recipe data', nil, 'error')
        return
    end

    -- Check if recipe exists
    if not saloon.recipes or not saloon.recipes[recipeName] then
        OTGSaloons.Notify(src, 'Recipe not found', nil, 'error')
        return
    end

    -- Update in database
    local success = MySQL.update.await('UPDATE otg_saloon_recipes SET display_name = ?, category = ?, craft_time = ?, price = ?, ingredients = ?, receive_item = ?, receive_amount = ?, updated_at = CURRENT_TIMESTAMP WHERE saloon_id = ? AND recipe_name = ?', {
        recipeData.display_name,
        recipeData.category,
        recipeData.craft_time,
        recipeData.price,
        json.encode(recipeData.ingredients),
        recipeData.receive_item,
        recipeData.receive_amount,
        saloonId,
        recipeName
    })

    if success then
        -- Update in memory
        saloon.recipes[recipeName] = {
            display_name = recipeData.display_name,
            category = recipeData.category,
            craft_time = recipeData.craft_time,
            price = recipeData.price,
            ingredients = recipeData.ingredients,
            receive_item = recipeData.receive_item,
            receive_amount = recipeData.receive_amount,
        }

        OTGSaloons.Notify(src, 'Recipe updated successfully', nil, 'success')
        -- Notify clients about the update
        TriggerClientEvent('otg-saloons:client:receiveRecipes', -1, saloon.recipes)
    else
        OTGSaloons.Notify(src, 'Failed to update recipe', nil, 'error')
    end
end)

RegisterNetEvent('otg-saloons:server:deleteRecipe', function(saloonId, recipeName)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon or saloon.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Unauthorized', nil, 'error')
        return
    end

    -- Check if recipe exists
    if not saloon.recipes or not saloon.recipes[recipeName] then
        OTGSaloons.Notify(src, 'Recipe not found', nil, 'error')
        return
    end

    -- Delete from database
    local success = MySQL.update.await('DELETE FROM otg_saloon_recipes WHERE saloon_id = ? AND recipe_name = ?', { saloonId, recipeName })

    if success then
        -- Remove from memory
        saloon.recipes[recipeName] = nil

        OTGSaloons.Notify(src, 'Recipe deleted successfully', nil, 'success')
        -- Notify clients about the update
        TriggerClientEvent('otg-saloons:client:receiveRecipes', -1, saloon.recipes)
    else
        OTGSaloons.Notify(src, 'Failed to delete recipe', nil, 'error')
    end
end)

------------------------------------------------
-- Crafting
------------------------------------------------
RegisterNetEvent('otg-saloons:server:craftItem', function(saloonId, recipeName, quantity)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then
        OTGSaloons.Notify(src, 'Saloon not found', nil, 'error')
        return
    end

    -- Check if player is owner or employee with crafting permission
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local isEmployee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid] ~= nil
    local canCraft = false

    if isOwner then
        canCraft = true
    elseif isEmployee then
        local employeeData = OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
        local role = employeeData.role
        -- Check if the role can craft (based on Config.Employees.Roles)
        if Config.Employees.Roles[role] and Config.Employees.Roles[role].canCraft then
            canCraft = true
        end
    end

    if not canCraft then
        OTGSaloons.Notify(src, 'Unauthorized', 'You do not have permission to craft items', 'error')
        return
    end

    -- Check if recipe exists
    if not saloon.recipes or not saloon.recipes[recipeName] then
        OTGSaloons.Notify(src, 'Recipe not found', nil, 'error')
        return
    end

    local recipe = saloon.recipes[recipeName]
    quantity = tonumber(quantity) or 1

    -- Check if saloon has enough ingredients
    local hasEnoughIngredients = true
    local missingIngredients = {}

    for _, ingredient in pairs(recipe.ingredients) do
        local item = ingredient.item
        local amountNeeded = ingredient.amount * quantity
        local amountInStock = saloon.stock[item] or 0

        if amountInStock < amountNeeded then
            hasEnoughIngredients = false
            table.insert(missingIngredients, {item = item, needed = amountNeeded, have = amountInStock})
        end
    end

    if not hasEnoughIngredients then
        local missingList = {}
        for _, ing in ipairs(missingIngredients) do
            local label = OTGSaloons.GetItemLabel(ing.item)
            table.insert(missingList, label .. ' (' .. ing.have .. '/' .. ing.needed .. ')')
        end
        OTGSaloons.Notify(src, 'Insufficient ingredients', 'Missing: ' .. table.concat(missingList, ', '), 'error')
        return
    end

    -- Remove ingredients from stock
    for _, ingredient in pairs(recipe.ingredients) do
        local item = ingredient.item
        local amountNeeded = ingredient.amount * quantity
        saloon.stock[item] = (saloon.stock[item] or 0) - amountNeeded
    end

    -- Add crafted item to stock
    local receiveItem = recipe.receive_item
    local receiveAmount = (recipe.receive_amount or 1) * quantity
    saloon.stock[receiveItem] = (saloon.stock[receiveItem] or 0) + receiveAmount

    -- Save updated stock
    SaveSaloonData(saloonId)

    -- Notify success
    local craftedLabel = OTGSaloons.GetItemLabel(receiveItem)
    OTGSaloons.Notify(src, 'Crafting complete!', 'Crafted ' .. receiveAmount .. 'x ' .. craftedLabel, 'success')

    -- Notify anyone listening that crafting completed (for UI updates)
    TriggerClientEvent('otg-saloons:client:craftingCompleted', src, saloonId, recipeName, receiveItem, receiveAmount)
end)

------------------------------------------------
-- Exports
------------------------------------------------
exports('GetSaloonOwner', function(saloonId)
    local saloon = OTGSaloons.Saloons[saloonId]
    return saloon and saloon.owner or nil
end)

exports('IsSaloonOwned', function(saloonId)
    local saloon = OTGSaloons.Saloons[saloonId]
    return saloon and saloon.owner ~= nil or false
end)

exports('GetSaloonStock', function(saloonId)
    local saloon = OTGSaloons.Saloons[saloonId]
    return saloon and saloon.stock or {}
end)

exports('GetSaloonCashBalance', function(saloonId)
    local saloon = OTGSaloons.Saloons[saloonId]
    return saloon and saloon.cashBalance or 0
end)

exports('IsPlayerSaloonOwner', function(source, saloonId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    local saloon = OTGSaloons.Saloons[saloonId]
    return saloon and saloon.owner == Player.PlayerData.citizenid or false
end)

exports('IsPlayerSaloonEmployee', function(source, saloonId)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then return false end
    return OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid] ~= nil or false
end)