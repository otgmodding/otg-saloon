------------------------------------------------
-- Self-Service Purchase
------------------------------------------------
RegisterNetEvent('otg-saloons:client:selfServicePurchase', function(saloonId, item, amount)
    local data = saloonData
    if not data then return end

    -- Check if saloon is unowned (self-service mode)
    if data.owner then
        OTGSaloonsNotify('Not Available', 'This saloon is owned and uses staff service', 'error')
        return
    end

    -- Find item price
    local price = 0
    for _, selfItem in pairs(Config.SelfService.Items) do
        if selfItem.name == item then
            price = selfItem.price
            break
        end
    end

    if price <= 0 then
        OTGSaloonsNotify('Not Available', 'This item is not available for self-service', 'error')
        return
    end

    -- Confirm purchase
    local total = price * amount
    local confirm = lib.alertDialog({
        header = 'Confirm Purchase',
        content = 'Purchase ' .. amount .. 'x ' .. OTGSaloons.GetItemLabel(item) .. ' for $' .. string.format('%.2f', total) .. '?',
        centered = true,
        cancel = true,
    })

    if confirm == 'confirm' then
        TriggerServerEvent('otg-saloons:server:selfServicePurchase', saloonId, item, amount)
    end
end)

------------------------------------------------
-- Self-Service Purchase Result
------------------------------------------------
RegisterNetEvent('otg-saloons:client:selfServicePurchaseResult', function(success, item, amount)
    if success then
        OTGSaloonsNotify('Purchase Complete!', 'You bought ' .. amount .. 'x ' .. OTGSaloons.GetItemLabel(item), 'success')
    else
        OTGSaloonsNotify('Purchase Failed', 'You do not have enough money or inventory space', 'error')
    end
end)