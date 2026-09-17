-- Counter state
local counterItems = {}
local counterProps = {}

------------------------------------------------
-- Open Counter
------------------------------------------------
RegisterNetEvent('otg-saloons:client:openCounter', function(saloonId)
    local data = saloonData
    if not data then
        TriggerServerEvent('otg-saloons:server:getSaloonData', saloonId)
        return
    end

    -- Check if player is owner or employee
    if not data.isOwner and not data.isEmployee then
        OTGSaloonsNotify('Access Denied', 'Only staff can use the counter', 'error')
        return
    end

    -- Get available items from stock
    TriggerServerEvent('otg-saloons:server:getStock', saloonId)
end)

RegisterNetEvent('otg-saloons:client:receiveStock', function(stock)
    local data = saloonData
    if not data then return end

    local options = {}
    for item, amount in pairs(stock) do
        if amount > 0 then
            local label = OTGSaloons.GetItemLabel(item)
            options[#options + 1] = {
                title = label,
                description = 'Stock: ' .. amount,
                icon = 'fa-solid fa-martini-glass',
                onSelect = function()
                    local input = lib.inputDialog('Place ' .. label .. ' on Counter', {
                        { type = 'number', label = 'Quantity', default = 1, min = 1, max = math.min(amount, 10) },
                    })
                    if input and input[1] then
                        TriggerServerEvent('otg-saloons:server:placeOnCounter', data.id, item, tonumber(input[1]))
                    end
                end,
            }
        end
    end

    if #options == 0 then
        options[1] = {
            title = 'No stock available',
            icon = 'fa-solid fa-circle-info',
            disabled = true,
        }
    end

    lib.registerContext({
        id = 'otg_saloon_counter_menu',
        title = 'Place Items on Counter',
        options = options,
    })
    lib.showContext('otg_saloon_counter_menu')
end)

------------------------------------------------
-- Place Item on Counter (Server Event)
------------------------------------------------
RegisterNetEvent('otg-saloons:client:placeItemOnCounter', function(saloonId, item, amount)
    local saloon = nil
    for _, s in pairs(Config.Saloons) do
        if s.id == saloonId then
            saloon = s
            break
        end
    end
    if not saloon then return end

    -- Check max items on counter
    local currentCount = 0
    for _, v in pairs(counterItems) do
        currentCount = currentCount + v.amount
    end
    if currentCount + amount > Config.Counter.MaxItemsOnCounter then
        OTGSaloonsNotify('Counter Full', 'The counter cannot hold more items', 'error')
        return
    end

    -- Get prop model
    local propModel = Config.Counter.ItemProps[item] or Config.Counter.DefaultProp

    -- Create props on the counter
    for i = 1, amount do
        local offset = #counterItems * 0.15
        local coords = vector3(
            saloon.counterCoords.x + math.cos(GetEntityHeading(cache.ped) * math.pi / 180) * offset,
            saloon.counterCoords.y + math.sin(GetEntityHeading(cache.ped) * math.pi / 180) * offset,
            saloon.counterCoords.z + 0.5
        )

        local modelHash = joaat(propModel)
        lib.requestModel(modelHash)
        local prop = CreateObject(modelHash, coords.x, coords.y, coords.z, true, true, false)
        SetEntityHeading(prop, GetEntityHeading(cache.ped))
        FreezeEntityPosition(prop, true)
        SetModelAsNoLongerNeeded(modelHash)

        local itemData = {
            id = #counterItems + 1,
            item = item,
            amount = 1,
            prop = prop,
            createdAt = GetGameTimer(),
        }
        counterItems[#counterItems + 1] = itemData
        counterProps[prop] = itemData
    end

    OTGSaloonsNotify('Items Placed', 'Placed ' .. amount .. 'x ' .. item .. ' on the counter', 'success')
end)

------------------------------------------------
-- Remove Item from Counter
------------------------------------------------
RegisterNetEvent('otg-saloons:client:removeItemFromCounter', function(saloonId, itemId)
    for i, itemData in pairs(counterItems) do
        if itemData.id == itemId then
            if DoesEntityExist(itemData.prop) then
                DeleteObject(itemData.prop)
            end
            counterProps[itemData.prop] = nil
            table.remove(counterItems, i)
            break
        end
    end
end)

------------------------------------------------
-- Counter Item Cleanup Thread
------------------------------------------------
CreateThread(function()
    while true do
        Wait(1000)
        local currentTime = GetGameTimer()
        for i = #counterItems, 1, -1 do
            local itemData = counterItems[i]
            if currentTime - itemData.createdAt > (Config.Counter.ItemLifetime * 1000) then
                if DoesEntityExist(itemData.prop) then
                    DeleteObject(itemData.prop)
                end
                counterProps[itemData.prop] = nil
                table.remove(counterItems, i)
            end
        end
    end
end)

------------------------------------------------
-- Pick Up Item from Counter
------------------------------------------------
RegisterNetEvent('otg-saloons:client:pickupCounterItem', function(saloonId, itemId)
    for i, itemData in pairs(counterItems) do
        if itemData.id == itemId then
            -- Give item to player
            TriggerServerEvent('otg-saloons:server:pickupCounterItem', saloonId, itemData.item, itemData.amount)

            -- Remove prop
            if DoesEntityExist(itemData.prop) then
                DeleteObject(itemData.prop)
            end
            counterProps[itemData.prop] = nil
            table.remove(counterItems, i)
            break
        end
    end
end)

------------------------------------------------
-- Cleanup on Resource Stop
------------------------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    for _, itemData in pairs(counterItems) do
        if DoesEntityExist(itemData.prop) then
            DeleteObject(itemData.prop)
        end
    end
    counterItems = {}
    counterProps = {}
end)