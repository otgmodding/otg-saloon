------------------------------------------------
-- Open Order Menu
------------------------------------------------
function OpenOrderMenu(saloonId)
    local options = {}
    for _, itemName in pairs(Config.Orders.OrderItems) do
        local label = OTGSaloons.GetItemLabel(itemName)
        local price = OTGSaloons.GetItemPrice(itemName)
        options[#options + 1] = {
            title = label,
            description = '$' .. string.format('%.2f', price),
            icon = 'fa-solid fa-martini-glass',
            onSelect = function()
                local input = lib.inputDialog('Order ' .. label, {
                    { type = 'number', label = 'Quantity', default = 1, min = 1, max = 5 },
                })
                if input and input[1] then
                    TriggerServerEvent('otg-saloons:server:placeOrder', saloonId, itemName, tonumber(input[1]))
                end
            end,
        }
    end

    lib.registerContext({
        id = 'otg_saloon_order_menu',
        title = 'Place Order',
        options = options,
    })
    lib.showContext('otg_saloon_order_menu')
end

------------------------------------------------
-- Receive Orders (Staff View)
------------------------------------------------
RegisterNetEvent('otg-saloons:client:receiveOrders', function(orders)
    local data = saloonData
    if not data then return end

    local options = {}
    for _, order in pairs(orders) do
        local statusIcon = 'fa-solid fa-clock'
        local statusColor = nil
        if order.status == 'in_progress' then
            statusIcon = 'fa-solid fa-fire'
        end

        options[#options + 1] = {
            title = order.customerName .. ' - ' .. order.item .. ' x' .. order.amount,
            description = 'Status: ' .. order.status .. ' | Total: $' .. string.format('%.2f', order.total),
            icon = statusIcon,
            onSelect = function()
                local actions = {}
                if order.status == 'pending' then
                    actions[#actions + 1] = {
                        title = 'Accept Order',
                        description = 'Start preparing this order',
                        icon = 'fa-solid fa-check',
                        onSelect = function()
                            TriggerServerEvent('otg-saloons:server:acceptOrder', data.id, order.id)
                        end,
                    }
                elseif order.status == 'in_progress' then
                    actions[#actions + 1] = {
                        title = 'Complete Order',
                        description = 'Mark order as served',
                        icon = 'fa-solid fa-check-double',
                        onSelect = function()
                            TriggerServerEvent('otg-saloons:server:completeOrder', data.id, order.id)
                        end,
                    }
                end
                actions[#actions + 1] = {
                    title = 'Cancel Order',
                    description = 'Cancel this order',
                    icon = 'fa-solid fa-xmark',
                    onSelect = function()
                        TriggerServerEvent('otg-saloons:server:cancelOrder', data.id, order.id)
                    end,
                }

                lib.registerContext({
                    id = 'otg_saloon_order_actions',
                    title = 'Order - ' .. order.item,
                    options = actions,
                })
                lib.showContext('otg_saloon_order_actions')
            end,
        }
    end

    if #options == 0 then
        options[1] = {
            title = 'No active orders',
            icon = 'fa-solid fa-circle-info',
            disabled = true,
        }
    end

    lib.registerContext({
        id = 'otg_saloon_orders_menu',
        title = 'Active Orders',
        options = options,
    })
    lib.showContext('otg_saloon_orders_menu')
end)

------------------------------------------------
-- Order Placed (Notification)
------------------------------------------------
RegisterNetEvent('otg-saloons:client:orderPlaced', function(saloonId, order)
    local data = saloonData
    if data and data.id == saloonId and (data.isOwner or data.isEmployee) then
        OTGSaloonsNotify('New Order!', order.customerName .. ' ordered ' .. order.amount .. 'x ' .. order.item, 'info')
    end
end)

------------------------------------------------
-- Order Updated
------------------------------------------------
RegisterNetEvent('otg-saloons:client:orderUpdated', function(saloonId, order)
    local data = saloonData
    if not data or data.id ~= saloonId then return end

    if order.status == 'completed' then
        OTGSaloonsNotify('Order Completed', 'Your ' .. order.item .. ' is ready!', 'success')
    elseif order.status == 'cancelled' then
        OTGSaloonsNotify('Order Cancelled', 'Your order has been cancelled', 'error')
    elseif order.status == 'expired' then
        OTGSaloonsNotify('Order Expired', 'Your order has expired', 'error')
    end
end)