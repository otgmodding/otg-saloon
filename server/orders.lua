local RSGCore = exports['rsg-core']:GetCoreObject()

-- Track order cooldowns per player
local orderCooldowns = {}

------------------------------------------------
-- Customer Ordering System
------------------------------------------------
RegisterNetEvent('otg-saloons:server:placeOrder', function(saloonId, item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check cooldown
    if orderCooldowns[src] and os.time() - orderCooldowns[src] < Config.Orders.OrderCooldown then
        OTGSaloons.Notify(src, 'Please wait before ordering again', nil, 'error')
        return
    end

    -- Validate item
    local validItem = false
    for _, orderItem in pairs(Config.Orders.OrderItems) do
        if orderItem == item then
            validItem = true
            break
        end
    end
    if not validItem then
        OTGSaloons.Notify(src, 'Invalid item', nil, 'error')
        return
    end

    amount = tonumber(amount) or 1
    if amount <= 0 then amount = 1 end

    -- Check max active orders
    local activeOrders = 0
    for _, order in pairs(OTGSaloons.SaloonOrders[saloonId] or {}) do
        if order.status == 'pending' or order.status == 'in_progress' then
            activeOrders = activeOrders + 1
        end
    end
    if activeOrders >= Config.Orders.MaxActiveOrders then
        OTGSaloons.Notify(src, 'Too many active orders', nil, 'error')
        return
    end

    -- Check if saloon has stock
    local stockCount = saloon.stock[item] or 0
    if stockCount < amount then
        OTGSaloons.Notify(src, 'Item out of stock', nil, 'error')
        return
    end

    -- Get price
    local price = OTGSaloons.GetItemPrice(item)
    if price <= 0 then
        OTGSaloons.Notify(src, 'Item not for sale', nil, 'error')
        return
    end

    -- Check if player has enough money
    local total = price * amount
    if Player.Functions.GetMoney('cash') < total then
        OTGSaloons.Notify(src, 'Not enough money', 'You need $' .. string.format('%.2f', total), 'error')
        return
    end

    -- Create the order
    local orderId = #OTGSaloons.SaloonOrders[saloonId] + 1
    OTGSaloons.SaloonOrders[saloonId][orderId] = {
        id = orderId,
        customer = Player.PlayerData.citizenid,
        customerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        item = item,
        amount = amount,
        price = price,
        total = total,
        status = 'pending',
        createdAt = os.time(),
    }

    -- Insert into database
    MySQL.insert('INSERT INTO otg_saloon_orders (saloon_id, customer, item, amount, status) VALUES (?, ?, ?, ?, ?)', {
        saloonId,
        Player.PlayerData.citizenid,
        item,
        amount,
        'pending',
    })

    orderCooldowns[src] = os.time()

    -- Notify all players in the saloon
    TriggerClientEvent('otg-saloons:client:orderPlaced', -1, saloonId, OTGSaloons.SaloonOrders[saloonId][orderId])
    OTGSaloons.Notify(src, 'Order Placed!', 'You ordered ' .. amount .. 'x ' .. item .. ' for $' .. string.format('%.2f', total), 'success')

    -- Set order timeout
    SetTimeout(Config.Orders.OrderTimeout * 1000, function()
        local order = OTGSaloons.SaloonOrders[saloonId][orderId]
        if order and order.status == 'pending' then
            order.status = 'expired'
            TriggerClientEvent('otg-saloons:client:orderUpdated', -1, saloonId, order)
        end
    end)
end)

RegisterNetEvent('otg-saloons:server:acceptOrder', function(saloonId, orderId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or employee
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local isEmployee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid] ~= nil

    if not isOwner and not isEmployee then
        OTGSaloons.Notify(src, 'You do not have permission to accept orders', nil, 'error')
        return
    end

    local order = OTGSaloons.SaloonOrders[saloonId][orderId]
    if not order then
        OTGSaloons.Notify(src, 'Order not found', nil, 'error')
        return
    end

    if order.status ~= 'pending' then
        OTGSaloons.Notify(src, 'Order is no longer pending', nil, 'error')
        return
    end

    -- Check stock
    local stockCount = saloon.stock[order.item] or 0
    if stockCount < order.amount then
        OTGSaloons.Notify(src, 'Not enough stock', nil, 'error')
        return
    end

    -- Accept the order
    order.status = 'in_progress'
    order.acceptedBy = Player.PlayerData.citizenid
    MySQL.prepare('UPDATE otg_saloon_orders SET status = ? WHERE id = ?', { 'in_progress', orderId })

    TriggerClientEvent('otg-saloons:client:orderUpdated', -1, saloonId, order)
    OTGSaloons.Notify(src, 'Order Accepted!', 'Prepare ' .. order.amount .. 'x ' .. order.item, 'success')
end)

RegisterNetEvent('otg-saloons:server:completeOrder', function(saloonId, orderId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or employee
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local isEmployee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid] ~= nil

    if not isOwner and not isEmployee then
        OTGSaloons.Notify(src, 'You do not have permission to complete orders', nil, 'error')
        return
    end

    local order = OTGSaloons.SaloonOrders[saloonId][orderId]
    if not order then
        OTGSaloons.Notify(src, 'Order not found', nil, 'error')
        return
    end

    if order.status ~= 'in_progress' then
        OTGSaloons.Notify(src, 'Order is not in progress', nil, 'error')
        return
    end

    -- Check stock
    local stockCount = saloon.stock[order.item] or 0
    if stockCount < order.amount then
        OTGSaloons.Notify(src, 'Not enough stock', nil, 'error')
        return
    end

    -- Process the sale
    local success = ProcessSale(saloonId, order.item, order.amount, order.price, RSGCore.Functions.GetSource(order.customer), Player.PlayerData.citizenid)
    if not success then
        OTGSaloons.Notify(src, 'Failed to complete order', nil, 'error')
        return
    end

    -- Complete the order
    order.status = 'completed'
    order.completedBy = Player.PlayerData.citizenid
    MySQL.prepare('UPDATE otg_saloon_orders SET status = ? WHERE id = ?', { 'completed', orderId })

    -- Notify customer
    local customerSource = RSGCore.Functions.GetSource(order.customer)
    if customerSource > 0 then
        OTGSaloons.Notify(customerSource, 'Order Ready!', 'Your ' .. order.item .. ' is ready!', 'success')
    end

    TriggerClientEvent('otg-saloons:client:orderUpdated', -1, saloonId, order)
    OTGSaloons.Notify(src, 'Order Completed!', 'You served ' .. order.amount .. 'x ' .. order.item, 'success')
end)

RegisterNetEvent('otg-saloons:server:cancelOrder', function(saloonId, orderId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local order = OTGSaloons.SaloonOrders[saloonId] and OTGSaloons.SaloonOrders[saloonId][orderId]
    if not order then return end

    -- Only the customer or staff can cancel
    local saloon = OTGSaloons.Saloons[saloonId]
    local isOwner = saloon and saloon.owner == Player.PlayerData.citizenid
    local isEmployee = saloon and OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid] ~= nil

    if order.customer ~= Player.PlayerData.citizenid and not isOwner and not isEmployee then
        OTGSaloons.Notify(src, 'You cannot cancel this order', nil, 'error')
        return
    end

    if order.status == 'completed' or order.status == 'expired' then
        OTGSaloons.Notify(src, 'Order cannot be cancelled', nil, 'error')
        return
    end

    order.status = 'cancelled'
    MySQL.prepare('UPDATE otg_saloon_orders SET status = ? WHERE id = ?', { 'cancelled', orderId })

    TriggerClientEvent('otg-saloons:client:orderUpdated', -1, saloonId, order)
    OTGSaloons.Notify(src, 'Order Cancelled', nil, 'info')
end)

RegisterNetEvent('otg-saloons:server:getOrders', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local orders = {}
    for _, order in pairs(OTGSaloons.SaloonOrders[saloonId] or {}) do
        if order.status == 'pending' or order.status == 'in_progress' then
            orders[#orders + 1] = order
        end
    end

    TriggerClientEvent('otg-saloons:client:receiveOrders', src, orders)
end)