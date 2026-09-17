local RSGCore = exports['rsg-core']:GetCoreObject()
local resourceName = GetCurrentResourceName()

-- Client state
-- NOTE: `saloonData` and `currentSaloon` are intentional globals - the other
-- client files (counter, crafting, orders, music, dancer, menu, selfservice)
-- read `saloonData` and silently bail out when it is nil.
currentSaloon = nil
saloonData = nil
local isMenuOpen = false
lib.locale()

print(('[%s] ^2START^7 loaded, Saloons=%d'):format(resourceName, #Config.Saloons))

local function logError(msg)
    print(('[%s] ^1ERROR^7 %s'):format(resourceName, msg))
end

local function logWarn(msg)
    print(('[%s] ^3WARN^7 %s'):format(resourceName, msg))
end

------------------------------------------------
-- Notification Helper
------------------------------------------------
-- bln_notify (v2.3.1) does NOT export a `Notify` function. Its API is:
--   client: exports.bln_notify:send(options, template)
--   server: exports.bln_notify:send(target, options, template)
-- where `template` is a key of bln_notify's Config.Templates
-- (INFO, SUCCESS, ERROR, REWARD_MONEY, TIP, TIP_CASH, TIP_XP, TIP_GOLD).
local notifyTemplates = {
    info = 'INFO',
    success = 'SUCCESS',
    error = 'ERROR',
    warning = 'INFO', -- bln_notify has no WARNING template
}

local function blnSendNotify(title, description, type, duration)
    exports['bln_notify']:send({
        title = title,
        description = description,
        duration = duration,
    }, notifyTemplates[type] or 'INFO')
end

function OTGSaloonsNotify(title, description, type, duration)
    type = tostring(type or 'info'):lower()
    duration = duration or 5000

    if Config.Notifications.UseOxLib then
        lib.notify({
            title = title,
            description = description,
            type = type,
            duration = duration,
        })
        return
    end

    if Config.Notifications.UseRNotify and GetResourceState('rNotify') == 'started' then
        local ok = pcall(function()
            exports['rNotify']:Notify(title, description, type, duration)
        end)
        if ok then return end
        logWarn('rNotify:Notify failed, falling back to ox_lib notifications')
    end

    if Config.Notifications.UseBlnNotify and GetResourceState('bln_notify') == 'started' then
        local ok = pcall(blnSendNotify, title, description, type, duration)
        if ok then return end
        logWarn('bln_notify:send failed, falling back to ox_lib notifications')
    end

    -- Never drop a message silently: fall back to ox_lib notifications.
    lib.notify({
        title = title,
        description = description,
        type = type,
        duration = duration,
    })
end

-----------------------------------------------
-- Server Requested Notification
-----------------------------------------------
-- Lets the server use whichever notification provider is configured instead of
-- hardcoding ox_lib notifications inside every server file.
RegisterNetEvent('otg-saloons:client:notify', function(title, description, type, duration)
    OTGSaloonsNotify(title, description, type, duration)
end)

------------------------------------------------
-- Blips
------------------------------------------------
local saloonBlips = {}
CreateThread(function()
    for _, saloon in ipairs(Config.Saloons) do
        if saloon.blip and saloon.blip.enabled then
            local blip = AddBlipForCoord(saloon.coords.x, saloon.coords.y, saloon.coords.z)
            if blip and blip ~= 0 then
                local spriteHash = GetHashKey(saloon.blip.sprite) or joaat(saloon.blip.sprite)
                SetBlipSprite(blip, spriteHash)
                SetBlipScale(blip, saloon.blip.scale)
                SetBlipName(blip, saloon.label)
                saloonBlips[saloon.id] = blip
            end
        end
    end
end)

local function joaat(str)
    if not str then return 0 end
    return GetHashKey(str)
end

-- Function to create a blip for dynamically created saloons
function CreateSaloonBlip(saloon)
    if not saloon.blip or not saloon.blip.enabled then return end
    local blip = AddBlipForCoord(saloon.coords.x, saloon.coords.y, saloon.coords.z)
    if blip and blip ~= 0 then
        local spriteHash = GetHashKey(saloon.blip.sprite) or joaat(saloon.blip.sprite)
        SetBlipSprite(blip, spriteHash)
        SetBlipScale(blip, saloon.blip.scale)
        SetBlipName(blip, saloon.label)
        saloonBlips[saloon.id] = blip
        print(('[otg-saloons] ^2BLIP^7 created for %s'):format(saloon.label))
    end
end

-- Function to remove a saloon blip dynamically
function RemoveSaloonBlip(saloonId)
    if saloonBlips[saloonId] then
        RemoveBlip(saloonBlips[saloonId])
        saloonBlips[saloonId] = nil
    end
end

------------------------------------------------
-- Open Saloon Menu
------------------------------------------------
RegisterNetEvent('otg-saloons:client:openSaloonMenu', function(saloonId)
    -- If a context menu from a previous trigger is still visible, hide it first
    -- so the new saloon menu isn't blocked by the lingering playthrough/context.
    if lib then
        if lib.context and type(lib.context.isOpen) == 'function' and lib.context.isOpen() then
            if type(lib.hideContext) == 'function' then
                lib.hideContext()
            end
        end
    end

    print(('[%s] ^2PROMPT^7 openSaloonMenu fired for %s (isMenuOpen=%s)'):format(resourceName, tostring(saloonId), tostring(isMenuOpen)))
    if isMenuOpen then return end
    isMenuOpen = true

    -- Request saloon data from server
    TriggerServerEvent('otg-saloons:server:getSaloonData', saloonId)

    -- Safety net: if the server never answers, release the lock so the player
    -- can try again instead of losing the saloon interaction for the session.
    SetTimeout(2500, function()
        if isMenuOpen then
            isMenuOpen = false
            OTGSaloonsNotify('Saloon', 'Could not load saloon data, please try again', 'error')
        end
    end)
end)

RegisterNetEvent('otg-saloons:client:receiveSaloonData', function(data)
    print(('[%s] ^2DATA^7 received saloon data for %s, isOwner=%s isEmployee=%s owner=%s'):format(resourceName, tostring(data and data.id), tostring(data and data.isOwner), tostring(data and data.isEmployee), tostring(data and data.owner)))

    if not data then
        -- Nothing to show; release the lock so the prompt can be used again.
        isMenuOpen = false
        return
    end

    saloonData = data
    currentSaloon = data.id

    -- The request completed, so allow the saloon interaction to be used again.
    isMenuOpen = false

    -- Open the appropriate menu based on player role
    if data.isOwner then
        OpenOwnerMenu(data)
    elseif data.isEmployee then
        OpenEmployeeMenu(data)
    else
        -- Check if saloon is owned
        if data.owner then
            -- Customer menu (order drinks)
            OpenCustomerMenu(data)
        else
            -- Self-service mode
            OpenSelfServiceMenu(data)
        end
    end
end)

------------------------------------------------
-- Saloon Ownership Changed
------------------------------------------------
RegisterNetEvent('otg-saloons:client:saloonOwnershipChanged', function(saloonId, newOwner)
    if currentSaloon == saloonId then
        TriggerServerEvent('otg-saloons:server:getSaloonData', saloonId)
    end
end)

------------------------------------------------
-- Recipe Handling
------------------------------------------------
RegisterNetEvent('otg-saloons:client:receiveRecipes', function(recipes, context)
    lib.hideTextUI() -- Hide the loading text UI

    if context == 'crafting' then
        -- Show crafting station UI
        ShowCraftingStationMenu(recipes or {})
    elseif context == 'management' then
        -- Show crafting management UI
        if not recipes or #recipes == 0 then
            -- No recipes yet, show empty state
            ShowCraftingManagementMenu({}, true)
            return
        end

        -- Convert array to object for easier lookup if needed
        local recipesObj = {}
        for _, recipe in ipairs(recipes) do
            recipesObj[recipe.recipe_name] = recipe
        end

        ShowCraftingManagementMenu(recipesObj, false)
    else
        -- Default to management UI for backward compatibility
        if not recipes or #recipes == 0 then
            -- No recipes yet, show empty state
            ShowCraftingManagementMenu({}, true)
            return
        end

        -- Convert array to object for easier lookup if needed
        local recipesObj = {}
        for _, recipe in ipairs(recipes) do
            recipesObj[recipe.recipe_name] = recipe
        end

        ShowCraftingManagementMenu(recipesObj, false)
    end
end)

RegisterNetEvent('otg-saloons:client:craftingCompleted', function(saloonId, recipeName, craftedItem, craftedAmount)
    local craftedLabel = OTGSaloons.GetItemLabel(craftedItem)
    OTGSaloonsNotify('Crafting Complete', 'Successfully crafted ' .. craftedAmount .. 'x ' .. craftedLabel, 'success', 5000)
end)

------------------------------------------------
-- Crafting Station UI
------------------------------------------------
function ShowCraftingStationMenu(recipes)
    local options = {}

    if not recipes or #recipes == 0 then
        options[#options + 1] = {
            title = 'No recipes available',
            description = 'The saloon owner has not added any recipes yet',
            icon = 'fa-solid fa-warning',
            disabled = true,
        }
    else
        -- Add each recipe as an option
        for _, recipe in ipairs(recipes) do
            local displayName = recipe.display_name or recipe.recipe_name or 'Unknown'
            local category = recipe.category or 'Other'
            local price = recipe.price or 0

            options[#options + 1] = {
                title = displayName,
                description = 'Category: ' .. category .. ' | Price: $' .. string.format('%.2f', price),
                icon = 'fa-solid fa-martini-glass-citrus',
                onSelect = function()
                    ShowCraftingConfirmation(recipe)
                end,
                args = { recipe = recipe }
            }
        end
    end

    -- Add back button
    options[#options + 1] = {
        title = 'Back',
        description = 'Return to saloon interaction',
        icon = 'fa-solid fa-arrow-left',
        onSelect = function()
            -- Return to appropriate menu based on player role
            if saloonData then
                if saloonData.isOwner then
                    OpenOwnerMenu(saloonData)
                elseif saloonData.isEmployee then
                    OpenEmployeeMenu(saloonData)
                elseif saloonData.owner then
                    OpenCustomerMenu(saloonData)
                else
                    OpenSelfServiceMenu(saloonData)
                end
            end
        end,
    }

    lib.registerContext({
        id = 'otg_saloon_crafting_station',
        title = 'Crafting Station',
        options = options,
    })
    lib.showContext('otg_saloon_crafting_station')
end

function ShowCraftingConfirmation(recipe)
    local displayName = recipe.display_name or recipe.recipe_name or 'Unknown'
    local receiveAmount = recipe.receive_amount or 1
    local craftedLabel = OTGSaloons.GetItemLabel(recipe.receive_item or 'unknown')

    local inputs = lib.inputDialog('Confirm Crafting', {
        { type = 'number', label = 'Quantity to craft', default = 1, min = 1 },
    })

    if inputs then
        local quantity = inputs[1]
        local totalAmount = receiveAmount * quantity

        local confirm = lib.alertDialog({
            header = 'Confirm Crafting',
            content = 'Craft ' .. quantity .. 'x ' .. displayName .. '?\nThis will consume ingredients and produce ' .. totalAmount .. 'x ' .. craftedLabel .. '.',
            centered = true,
            cancel = true,
        })

        if confirm == 'confirm' then
            -- Start crafting process
            TriggerServerEvent('otg-saloons:server:craftItem', saloonData.id, recipe.recipe_name, quantity)
        end
    end
end

RegisterNetEvent('otg-saloons:client:openCraftingStation', function(saloonId)
    -- Request the saloon's recipes from the server for crafting
    TriggerServerEvent('otg-saloons:server:getRecipes', saloonId, 'crafting')
end)

RegisterNetEvent('otg-saloons:client:openCrafting', function(saloonId)
    -- Request the saloon's recipes from the server for management
    TriggerServerEvent('otg-saloons:server:getRecipes', saloonId, 'management')
end)

------------------------------------------------
-- Cleanup
------------------------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
        print(('[%s] ^2STOP^7 cleaning up'):format(resourceName))
end)

------------------------------------------------
-- Dynamic Saloon Creation (admin commands)
------------------------------------------------
RegisterNetEvent('otg-saloons:client:saloonCreated', function(saloonId, label, coords)
    if not Config.EnableAdminCommands then return end
    
    -- The new saloon will be added to Config.Saloons via server-side sync
    -- Client needs to update blips and prompts
    CreateThread(function()
        Wait(100) -- Let server finish initialization
        
        -- Create blip for new saloon
        local saloon = nil
        for _, s in ipairs(Config.Saloons) do
            if s.id == saloonId then
                saloon = s
                break
            end
        end
        
        if saloon and saloon.blip and saloon.blip.enabled then
            local blipId = 1664425300
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            if blip and blip ~= 0 then
                local spriteHash = GetHashKey(saloon.blip.sprite) or joaat(saloon.blip.sprite)
                SetBlipSprite(blip, spriteHash)
                SetBlipScale(blip, saloon.blip.scale)
                SetBlipName(blip, saloon.label)
            end
        end
        
        OTGSaloonsNotify('New Saloon', label .. ' has been created', 'success')
    end)
end)

RegisterNetEvent('otg-saloons:client:saloonDeleted', function(saloonId)
    if not Config.EnableAdminCommands then return end
    RemoveSaloonBlip(saloonId)
    OTGSaloonsNotify('Saloon Removed', 'A saloon has been removed', 'info')
end)

------------------------------------------------
-- Inventory Integration
------------------------------------------------
-- Sync inventory updates with saloon data
RegisterNetEvent('otg-saloons:client:syncInventory', function(itemChanges)
    if not saloonData then return end
    
    -- Update any displayed inventory counts
    if lib and lib.context and type(lib.context.isOpen) == 'function' and lib.context.isOpen() then
        -- Menu might need to be refreshed
    end
end)

------------------------------------------------
-- Prompt Integration Check
------------------------------------------------
-- Check if using ox_target or prompts for interactions
RegisterCommand('salooninteraction', function()
    if Config.UseOxTarget then
        OTGSaloonsNotify('Interaction Method', 'Using ox_target for interactions', 'info')
    else
        OTGSaloonsNotify('Interaction Method', 'Using prompts for interactions', 'info')
    end
end, false)
