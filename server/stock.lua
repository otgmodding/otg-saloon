local RSGCore = exports['rsg-core']:GetCoreObject()

------------------------------------------------
-- Stock Management
------------------------------------------------
RegisterNetEvent('otg-saloons:server:getStock', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner, employee, or saloon is unowned (self-service)
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local isEmployee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid] ~= nil

    if not isOwner and not isEmployee and saloon.owner then
        OTGSaloons.Notify(src, 'You do not have access to this stock', nil, 'error')
        return
    end

    TriggerClientEvent('otg-saloons:client:receiveStock', src, saloon.stock)
end)

RegisterNetEvent('otg-saloons:server:addStock', function(saloonId, item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or employee
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local employee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    local isEmployee = employee ~= nil

    if not isOwner and not isEmployee then
        OTGSaloons.Notify(src, 'You do not have permission to add stock', nil, 'error')
        return
    end

    -- Check if employee has stock management permission
    if isEmployee and not isOwner and not Config.Employees.Roles[employee.role].canManageStock then
        OTGSaloons.Notify(src, 'Your role cannot manage stock', nil, 'error')
        return
    end

    amount = tonumber(amount) or 1
    if amount <= 0 then return end

    -- Check if player has the items
    local itemCount = exports['rsg-inventory']:GetItemCount(src, item)
    if itemCount < amount then
        OTGSaloons.Notify(src, 'Not enough items', 'You need ' .. amount .. 'x ' .. item, 'error')
        return
    end

    -- Check max stock
    local currentStock = saloon.stock[item] or 0
    if currentStock + amount > Config.Stock.MaxStockPerItem then
        OTGSaloons.Notify(src, 'Stock limit reached', 'Max stock is ' .. Config.Stock.MaxStockPerItem, 'error')
        return
    end

    -- Remove items from player and add to stock
    exports['rsg-inventory']:RemoveItem(src, item, amount, nil, 'saloon-stock-add')
    saloon.stock[item] = currentStock + amount
    SaveSaloonData(saloonId)

    OTGSaloons.Notify(src, 'Stock Added!', 'Added ' .. amount .. 'x ' .. item .. ' to stock', 'success')
    TriggerClientEvent('otg-saloons:client:receiveStock', src, saloon.stock)
end)

RegisterNetEvent('otg-saloons:server:removeStock', function(saloonId, item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or employee
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local employee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    local isEmployee = employee ~= nil

    if not isOwner and not isEmployee then
        OTGSaloons.Notify(src, 'You do not have permission to remove stock', nil, 'error')
        return
    end

    -- Check if employee has stock management permission
    if isEmployee and not isOwner and not Config.Employees.Roles[employee.role].canManageStock then
        OTGSaloons.Notify(src, 'Your role cannot manage stock', nil, 'error')
        return
    end

    amount = tonumber(amount) or 1
    if amount <= 0 then return end

    -- Check if there is enough stock
    local currentStock = saloon.stock[item] or 0
    if currentStock < amount then
        OTGSaloons.Notify(src, 'Not enough stock', nil, 'error')
        return
    end

    -- Check if player can carry the items
    if not exports['rsg-inventory']:CanAddItem(src, item, amount) then
        OTGSaloons.Notify(src, 'Inventory full', nil, 'error')
        return
    end

    -- Remove from stock and add to player
    saloon.stock[item] = currentStock - amount
    if saloon.stock[item] <= 0 then
        saloon.stock[item] = nil
    end
    SaveSaloonData(saloonId)
    exports['rsg-inventory']:AddItem(src, item, amount, nil, {}, 'saloon-stock-remove')

    OTGSaloons.Notify(src, 'Stock Removed!', 'Removed ' .. amount .. 'x ' .. item .. ' from stock', 'success')
    TriggerClientEvent('otg-saloons:client:receiveStock', src, saloon.stock)
end)

RegisterNetEvent('otg-saloons:server:setStockPrice', function(saloonId, item, price)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Only owner can set prices
    if saloon.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Only the owner can set prices', nil, 'error')
        return
    end

    price = tonumber(price) or 0
    if price < 0 then price = 0 end

    -- Store price in stock item data
    if not saloon.stock[item] then
        saloon.stock[item] = 0
    end
    saloon.stockPrices = saloon.stockPrices or {}
    saloon.stockPrices[item] = price
    SaveSaloonData(saloonId)

    OTGSaloons.Notify(src, 'Price Updated!', item .. ' is now $' .. string.format('%.2f', price), 'success')
end)

------------------------------------------------
-- Automatic Restock
------------------------------------------------
CreateThread(function()
    while true do
        Wait(Config.Stock.RestockTime * 1000)

        if Config.Stock.RestockEnabled then
            for saloonId, saloon in pairs(OTGSaloons.Saloons) do
                -- Only restock owned saloons
                if saloon.owner then
                    for item, amount in pairs(saloon.defaultStock or {}) do
                        local currentStock = saloon.stock[item] or 0
                        if currentStock < amount then
                            saloon.stock[item] = math.min(amount, currentStock + Config.Stock.RestockAmount)
                        end
                    end
                    SaveSaloonData(saloonId)
                end
            end
        end
    end
end)

------------------------------------------------
-- Counter Placement
------------------------------------------------
RegisterNetEvent('otg-saloons:server:placeOnCounter', function(saloonId, item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or employee
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local employee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    local isEmployee = employee ~= nil

    if not isOwner and not isEmployee then
        OTGSaloons.Notify(src, 'You do not have permission to place items', nil, 'error')
        return
    end

    -- Check if employee has serve permission
    if isEmployee and not isOwner and not Config.Employees.Roles[employee.role].canServe then
        OTGSaloons.Notify(src, 'Your role cannot serve items', nil, 'error')
        return
    end

    amount = tonumber(amount) or 1
    if amount <= 0 then return end

    -- Check stock
    local currentStock = saloon.stock[item] or 0
    if currentStock < amount then
        OTGSaloons.Notify(src, 'Not enough stock', nil, 'error')
        return
    end

    -- Remove from stock
    saloon.stock[item] = currentStock - amount
    if saloon.stock[item] <= 0 then
        saloon.stock[item] = nil
    end
    SaveSaloonData(saloonId)

    -- Trigger client to place props
    TriggerClientEvent('otg-saloons:client:placeItemOnCounter', src, saloonId, item, amount)
end)

RegisterNetEvent('otg-saloons:server:pickupCounterItem', function(saloonId, item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player can carry the item
    if not exports['rsg-inventory']:CanAddItem(src, item, amount) then
        OTGSaloons.Notify(src, 'Inventory full', nil, 'error')
        return
    end

    -- Add item back to player
    exports['rsg-inventory']:AddItem(src, item, amount, nil, {}, 'saloon-counter-pickup')
end)

------------------------------------------------
-- Stash Management
------------------------------------------------
RegisterNetEvent('otg-saloons:server:openStash', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or employee
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local isEmployee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid] ~= nil

    if not isOwner and not isEmployee then
        OTGSaloons.Notify(src, 'You do not have access to this stash', nil, 'error')
        return
    end

    local stashId = Config.Stock.StashIdentifier .. saloonId
    exports['rsg-inventory']:OpenInventory(src, stashId, {
        label = saloon.label .. ' Stash',
        slots = Config.Stock.StashSlots,
        maxweight = Config.Stock.StashWeight,
    })
end)

------------------------------------------------
-- Sales History
------------------------------------------------
RegisterNetEvent('otg-saloons:server:getSalesHistory', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Only owner can view sales history
    if saloon.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Only the owner can view sales history', nil, 'error')
        return
    end

    local sales = MySQL.query.await('SELECT * FROM otg_saloon_sales WHERE saloon_id = ? ORDER BY created_at DESC LIMIT 50', { saloonId })
    TriggerClientEvent('otg-saloons:client:receiveSalesHistory', src, sales or {})
end)

-- Helper function to record a sale
function RecordSale(saloonId, item, amount, price, buyer, seller, saleType)
    MySQL.insert('INSERT INTO otg_saloon_sales (saloon_id, item, amount, price, buyer, seller, sale_type) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        saloonId,
        item,
        amount,
        price,
        buyer,
        seller,
        saleType or 'counter',
    })
end