local RSGCore = exports['rsg-core']:GetCoreObject()
local resourceName = GetCurrentResourceName()

------------------------------------------------
-- Saloon Creator System
-- This allows admins to create and configure saloons in-game
-- with a UI for setting polyzones, cash registers, crafting stations, etc.
------------------------------------------------

local creatorMode = false
local currentSaloonData = nil
local selectedPointType = nil
local creatorPermissionGranted = false
local pendingPermissionCallbacks = {}

------------------------------------------------
-- Helper Functions
------------------------------------------------
-- NOTE: RSGCore.Functions.GetPlayer only exists on the SERVER. The client core
-- object only exposes GetPlayerData / TriggerCallback, so calling GetPlayer
-- here threw "attempt to call a nil value (field 'GetPlayer')".
-- Permission checks therefore have to be answered by the server.
------------------------------------------------
RegisterNetEvent('otg-saloons:client:creator:permission', function(allowed)
    creatorPermissionGranted = allowed and true or false

    local callbacks = pendingPermissionCallbacks
    pendingPermissionCallbacks = {}

    for _, callback in ipairs(callbacks) do
        callback(creatorPermissionGranted)
    end
end)

local function RequestCreatorPermission(callback)
    if not Config.EnableCreator then
        callback(false)
        return
    end

    pendingPermissionCallbacks[#pendingPermissionCallbacks + 1] = callback
    TriggerServerEvent('otg-saloons:server:creator:checkPermission')
end

local function GetPlayerCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
        return vector3(coords.x, coords.y, coords.z), heading
end

local function ShowNotification(title, description, type, duration)
    OTGSaloonsNotify(title, description, type or 'info', duration or 5000)
end

------------------------------------------------
-- Creator Menu
------------------------------------------------
function OpenCreatorMenu()
    RequestCreatorPermission(function(isAdmin)
        if not isAdmin then
            ShowNotification('Access Denied', 'You do not have permission to use the saloon creator', 'error')
            return
        end

        if creatorMode then
            -- The context menu closes as soon as an option is clicked, so the
            -- admin needs a way back in after walking to the spot they want to
            -- capture. Re-show the menu instead of refusing to open it.
            ShowCreatorMainMenu()
            return
        end

        StartCreatorMode()
    end)
end

------------------------------------------------
-- Start Creator Mode (called once the server has confirmed permissions)
------------------------------------------------
function StartCreatorMode()
    creatorMode = true
    local coords, heading = GetPlayerCoords()

    -- Initialize saloon data with default template
    currentSaloonData = {
        id = '',
        label = '',
        coords = vector3(coords.x, coords.y, coords.z),
        heading = heading,
        counterCoords = vector3(coords.x, coords.y, coords.z),
        cashRegisterCoords = vector3(coords.x + 1.0, coords.y, coords.z),
        craftingCoords = vector3(coords.x - 1.0, coords.y, coords.z),
        musicCoords = vector3(coords.x, coords.y - 2.0, coords.z),
        dancerCoords = vector3(coords.x + 2.0, coords.y, coords.z),
        zoneRadius = 5.0,
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

    ShowNotification('Creator Mode', 'Saloon creator is now active. Use the menu to configure your saloon.', 'success')
    ShowCreatorMainMenu()
end


------------------------------------------------
-- Main Creator Menu
------------------------------------------------
function ShowCreatorMainMenu()
    if not creatorMode then return end

    local coords = GetPlayerCoords()
    local coordStr = ('X: %.1f Y: %.1f Z: %.1f'):format(coords.x, coords.y, coords.z)

    local options = {
        {
            title = 'Saloon Information',
            description = 'Set ID, label, and main position',
            icon = 'fa-solid fa-edit',
            onSelect = function()
                ShowSaloonInfoDialog()
            end,
        },
        {
            title = 'Set Main Position',
            description = 'Position: ' .. coordStr,
            icon = 'fa-solid fa-location-dot',
            onSelect = function()
                -- Capture the position at click time, not at menu-open time:
                -- the admin walks to the spot before opening the menu again.
                local pos, posHeading = GetPlayerCoords()
                currentSaloonData.coords = vector3(pos.x, pos.y, pos.z)
                currentSaloonData.heading = posHeading
                ShowNotification('Position Set', ('Main saloon position updated to X: %.1f Y: %.1f Z: %.1f'):format(pos.x, pos.y, pos.z), 'success')
                ShowCreatorMainMenu()
            end,
        },
        {
            title = 'Configure Points',
            description = 'Set station positions',
            icon = 'fa-solid fa-cog',
            onSelect = function()
                ShowPointConfigurationMenu()
            end,
        },
        {
            title = 'Configure Zone',
            description = 'Set polyzone radius',
            icon = 'fa-solid fa-circle-nodes',
            onSelect = function()
                ShowZoneConfiguration()
            end,
        },
        {
            title = 'Blip Settings',
            description = 'Configure map blip',
            icon = 'fa-solid fa-map-location-dot',
            onSelect = function()
                ShowBlipSettings()
            end,
        },
        {
            title = 'Preview & Save',
            description = 'Preview and save saloon',
            icon = 'fa-solid fa-save',
            onSelect = function()
                PreviewAndSaveSaloon()
            end,
        },
        {
            title = 'Exit Creator',
            description = 'Cancel and exit creator mode',
            icon = 'fa-solid fa-xmark',
            onSelect = function()
                ExitCreatorMode()
            end,
        },
    }

    lib.registerContext({
        id = 'otg_saloon_creator_main',
        title = 'Saloon Creator',
        options = options,
    })
        lib.showContext('otg_saloon_creator_main')
end

------------------------------------------------
-- Saloon Info Dialog
------------------------------------------------
function ShowSaloonInfoDialog()
    local inputs = lib.inputDialog('Saloon Information', {
        { type = 'input', label = 'Saloon ID', description = 'Unique identifier (e.g., valentine_saloon)', required = true },
        { type = 'input', label = 'Saloon Label', description = 'Display name for the saloon', required = true },
    })

    if inputs then
        currentSaloonData.id = inputs[1]
        currentSaloonData.label = inputs[2]
        ShowNotification('Updated', 'Saloon information set', 'success')
                ShowCreatorMainMenu()
    end
end

------------------------------------------------
-- Point Configuration Menu
------------------------------------------------
function ShowPointConfigurationMenu()
    if not creatorMode then return end

    local function formatCoords(vec)
        return ('X: %.1f Y: %.1f Z: %.1f'):format(vec.x, vec.y, vec.z)
    end

    -- Positions must be sampled when the option is clicked, not when the menu
    -- was opened, because the admin walks to the spot before reopening the menu.
    local function CurrentPos()
        local pos = GetPlayerCoords()
        return vector3(pos.x, pos.y, pos.z)
    end

    local options = {
        {
            title = 'Counter / Table Service',
            description = formatCoords(currentSaloonData.counterCoords),
            icon = 'fa-solid fa-utensils',
            onSelect = function()
                currentSaloonData.counterCoords = CurrentPos()
                ShowNotification('Position Set', 'Counter position updated', 'success')
                ShowPointConfigurationMenu()
            end,
        },
        {
            title = 'Cash Register',
            description = formatCoords(currentSaloonData.cashRegisterCoords),
            icon = 'fa-solid fa-cash-register',
            onSelect = function()
                currentSaloonData.cashRegisterCoords = CurrentPos()
                ShowNotification('Position Set', 'Cash register position updated', 'success')
                ShowPointConfigurationMenu()
            end,
        },
        {
            title = 'Crafting Station',
            description = formatCoords(currentSaloonData.craftingCoords),
            icon = 'fa-solid fa-martini-glass-citrus',
            onSelect = function()
                currentSaloonData.craftingCoords = CurrentPos()
                ShowNotification('Position Set', 'Crafting station position updated', 'success')
                ShowPointConfigurationMenu()
            end,
        },
        {
            title = 'Music Control',
            description = formatCoords(currentSaloonData.musicCoords),
            icon = 'fa-solid fa-music',
            onSelect = function()
                currentSaloonData.musicCoords = CurrentPos()
                ShowNotification('Position Set', 'Music control position updated', 'success')
                ShowPointConfigurationMenu()
            end,
        },
        {
            title = 'Dancer Area',
            description = formatCoords(currentSaloonData.dancerCoords),
            icon = 'fa-solid fa-person-dancing',
            onSelect = function()
                currentSaloonData.dancerCoords = CurrentPos()
                ShowNotification('Position Set', 'Dancer area position updated', 'success')
                ShowPointConfigurationMenu()
            end,
        },
        {
            title = 'Back',
            description = 'Return to main menu',
            icon = 'fa-solid fa-arrow-left',
            onSelect = function()
                ShowCreatorMainMenu()
            end,
        },
    }

    lib.registerContext({
        id = 'otg_saloon_creator_points',
        title = 'Configure Points',
        options = options,
    })
    lib.showContext('otg_saloon_creator_points')
end

------------------------------------------------
-- Zone Configuration
------------------------------------------------
function ShowZoneConfiguration()
    if not creatorMode then return end

    local inputs = lib.inputDialog('Zone Configuration', {
        { type = 'number', label = 'Zone Radius (meters)', description = 'Radius of the interaction zone', default = currentSaloonData.zoneRadius, min = 1.0, max = 100.0 },
    })

    if inputs then
        currentSaloonData.zoneRadius = tonumber(inputs[1]) or 5.0
        ShowNotification('Zone Updated', 'Saloon zone radius set to ' .. currentSaloonData.zoneRadius .. 'm', 'success')
        ShowCreatorMainMenu()
    end
end

------------------------------------------------
-- Blip Settings
------------------------------------------------
function ShowBlipSettings()
    if not creatorMode then return end

    local inputs = lib.inputDialog('Blip Settings', {
        { type = 'checkbox', label = 'Enable Blip', checked = currentSaloonData.blip.enabled },
        { type = 'input', label = 'Sprite', description = 'Blip sprite name', default = currentSaloonData.blip.sprite },
        { type = 'number', label = 'Scale', description = 'Blip scale (0.1 - 1.0)', default = currentSaloonData.blip.scale, min = 0.1, max = 1.0 },
        { type = 'input', label = 'Color', description = 'Blip color identifier', default = currentSaloonData.blip.color },
    })

    if inputs then
        currentSaloonData.blip.enabled = inputs[1]
        currentSaloonData.blip.sprite = inputs[2]
        currentSaloonData.blip.scale = tonumber(inputs[3]) or 0.2
        currentSaloonData.blip.color = inputs[4]
        ShowNotification('Blip Settings', 'Blip settings updated', 'success')
        ShowCreatorMainMenu()
    end
end

------------------------------------------------
-- Preview and Save
------------------------------------------------
function PreviewAndSaveSaloon()
    if not creatorMode then return end
    if not currentSaloonData then return end

    if not currentSaloonData.id or currentSaloonData.id == '' then
        ShowNotification('Error', 'Please set a saloon ID first', 'error')
        ShowCreatorMainMenu()
        return
    end

    if not currentSaloonData.label or currentSaloonData.label == '' then
        ShowNotification('Error', 'Please set a saloon label first', 'error')
        ShowCreatorMainMenu()
        return
    end

    -- Show confirmation dialog
    local confirm = lib.alertDialog({
        header = 'Save Saloon',
        content = ('Create saloon "%s" (%s)?'):format(currentSaloonData.label, currentSaloonData.id),
        centered = true,
        cancel = true,
    })

    if confirm == 'confirm' then
        -- Send to server for creation
        TriggerServerEvent('otg-saloons:creator:saveSaloon', currentSaloonData)
        ShowNotification('Saving', 'Saloon data sent to server for creation', 'info')
    else
        ShowCreatorMainMenu()
    end
end

------------------------------------------------
-- Exit Creator Mode
------------------------------------------------
function ExitCreatorMode()
    local confirm = lib.alertDialog({
        header = 'Exit Creator',
        content = 'Are you sure you want to exit? Unsaved changes will be lost.',
        centered = true,
        cancel = true,
    })

    if confirm == 'confirm' then
        creatorMode = false
        currentSaloonData = nil
        ShowNotification('Creator Mode', 'Creator mode has been exited', 'info')
    end
end

------------------------------------------------
-- Server Response Handler
------------------------------------------------
RegisterNetEvent('otg-saloons:creator:saloonSaved', function(saloonId, success, message)
    creatorMode = false
    currentSaloonData = nil
    
    if success then
        ShowNotification('Saloon Created', 'Saloon "' .. saloonId .. '" has been created!', 'success')
    else
        ShowNotification('Error', message or 'Failed to create saloon', 'error')
    end
end)

------------------------------------------------
-- Register Command
------------------------------------------------
RegisterCommand(Config.CreatorCommand, function()
    OpenCreatorMenu()
end, false)

TriggerEvent('chat:addSuggestion', '/' .. Config.CreatorCommand, 'Open the saloon creator menu', {})

-- Cleanup on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    creatorMode = false
    currentSaloonData = nil
end)