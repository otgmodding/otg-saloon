local RSGCore = exports['rsg-core']:GetCoreObject()

-- Cooldown tracking
local withdrawCooldowns = {}
local depositCooldowns = {}

------------------------------------------------
-- Cash Register Management
------------------------------------------------
RegisterNetEvent('otg-saloons:server:getCashRegister', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or employee with cash register access
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local employee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    local canAccess = isOwner or (employee and Config.Employees.Roles[employee.role].canAccessCashRegister)

    if not canAccess then
        OTGSaloons.Notify(src, 'You do not have access to the cash register', nil, 'error')
        return
    end

    TriggerClientEvent('otg-saloons:client:receiveCashRegister', src, {
        id = saloonId,
        balance = saloon.cashBalance,
        maxBalance = Config.CashRegister.MaxBalance,
    })
end)

RegisterNetEvent('otg-saloons:server:depositCash', function(saloonId, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or employee with cash register access
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local employee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    local canAccess = isOwner or (employee and Config.Employees.Roles[employee.role].canAccessCashRegister)

    if not canAccess then
        OTGSaloons.Notify(src, 'You do not have access to the cash register', nil, 'error')
        return
    end

    -- Check cooldown
    if depositCooldowns[src] and os.time() - depositCooldowns[src] < Config.CashRegister.DepositCooldown then
        OTGSaloons.Notify(src, 'Please wait before depositing again', nil, 'error')
        return
    end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    -- Check if player has enough money
    if Player.Functions.GetMoney('cash') < amount then
        OTGSaloons.Notify(src, 'Not enough cash', nil, 'error')
        return
    end

    -- Check max balance
    if saloon.cashBalance + amount > Config.CashRegister.MaxBalance then
        OTGSaloons.Notify(src, 'Cash register is full', nil, 'error')
        return
    end

    -- Deposit cash
    Player.Functions.RemoveMoney('cash', amount, 'saloon-deposit')
    saloon.cashBalance = saloon.cashBalance + amount
    SaveSaloonData(saloonId)
    depositCooldowns[src] = os.time()

    OTGSaloons.Notify(src, 'Cash Deposited!', 'Deposited $' .. string.format('%.2f', amount), 'success')
    TriggerClientEvent('otg-saloons:client:receiveCashRegister', src, {
        id = saloonId,
        balance = saloon.cashBalance,
        maxBalance = Config.CashRegister.MaxBalance,
    })
end)

RegisterNetEvent('otg-saloons:server:withdrawCash', function(saloonId, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if player is owner or employee with cash register access
    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local employee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid]
    local canAccess = isOwner or (employee and Config.Employees.Roles[employee.role].canAccessCashRegister)

    if not canAccess then
        OTGSaloons.Notify(src, 'You do not have access to the cash register', nil, 'error')
        return
    end

    -- Check cooldown
    if withdrawCooldowns[src] and os.time() - withdrawCooldowns[src] < Config.CashRegister.WithdrawCooldown then
        OTGSaloons.Notify(src, 'Please wait before withdrawing again', nil, 'error')
        return
    end

    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    -- Check if saloon has enough cash
    if saloon.cashBalance < amount then
        OTGSaloons.Notify(src, 'Not enough cash in register', nil, 'error')
        return
    end

    -- Withdraw cash
    saloon.cashBalance = saloon.cashBalance - amount
    SaveSaloonData(saloonId)
    Player.Functions.AddMoney('cash', amount, 'saloon-withdraw')
    withdrawCooldowns[src] = os.time()

    OTGSaloons.Notify(src, 'Cash Withdrawn!', 'Withdrew $' .. string.format('%.2f', amount), 'success')
    TriggerClientEvent('otg-saloons:client:receiveCashRegister', src, {
        id = saloonId,
        balance = saloon.cashBalance,
        maxBalance = Config.CashRegister.MaxBalance,
    })
end)

------------------------------------------------
-- Sale Processing
------------------------------------------------
-- Process a sale and add money to the saloon cash register
function ProcessSale(saloonId, item, amount, price, buyer, seller)
    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return false end

    -- Check stock
    local currentStock = saloon.stock[item] or 0
    if currentStock < amount then
        return false
    end

    -- Calculate total with tax
    local total = price * amount
    local tax = total * Config.CashRegister.TaxRate
    local totalWithTax = total + tax

    -- Check if buyer has enough money
    local buyerPlayer = RSGCore.Functions.GetPlayer(buyer)
    if not buyerPlayer then return false end

    if buyerPlayer.Functions.GetMoney('cash') < totalWithTax then
        return false
    end

    -- Process the sale
    buyerPlayer.Functions.RemoveMoney('cash', totalWithTax, 'saloon-purchase')
    saloon.cashBalance = saloon.cashBalance + total
    saloon.stock[item] = currentStock - amount
    if saloon.stock[item] <= 0 then
        saloon.stock[item] = nil
    end
    SaveSaloonData(saloonId)

    -- Give item to buyer
    exports['rsg-inventory']:AddItem(buyer, item, amount, nil, {}, 'saloon-purchase')

    -- Record the sale
    RecordSale(saloonId, item, amount, total, buyerPlayer.PlayerData.citizenid, seller, 'counter')

    return true
end

RegisterNetEvent('otg-saloons:server:selfServicePurchase', function(saloonId, item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    -- Check if saloon is unowned (self-service mode)
    if saloon.owner then
        TriggerClientEvent('otg-saloons:client:selfServicePurchaseResult', src, false, item, amount)
        return
    end

    -- Validate item
    local price = 0
    for _, selfItem in pairs(Config.SelfService.Items) do
        if selfItem.name == item then
            price = selfItem.price
            break
        end
    end

    if price <= 0 then
        TriggerClientEvent('otg-saloons:client:selfServicePurchaseResult', src, false, item, amount)
        return
    end

    amount = tonumber(amount) or 1
    if amount <= 0 then amount = 1 end

    -- Check if player can carry the item
    if not exports['rsg-inventory']:CanAddItem(src, item, amount) then
        TriggerClientEvent('otg-saloons:client:selfServicePurchaseResult', src, false, item, amount)
        return
    end

    -- Process the sale
    local success = ProcessSelfServiceSale(saloonId, item, amount, price, src)
    if success then
        TriggerClientEvent('otg-saloons:client:selfServicePurchaseResult', src, true, item, amount)
    else
        TriggerClientEvent('otg-saloons:client:selfServicePurchaseResult', src, false, item, amount)
    end
end)

-- Process a self-service sale (unowned saloon)
function ProcessSelfServiceSale(saloonId, item, amount, price, buyer)
    local buyerPlayer = RSGCore.Functions.GetPlayer(buyer)
    if not buyerPlayer then return false end

    -- Calculate total
    local total = price * amount

    -- Check if buyer has enough money
    if buyerPlayer.Functions.GetMoney(Config.SelfService.MoneyType) < total then
        return false
    end

    -- Process the sale
    buyerPlayer.Functions.RemoveMoney(Config.SelfService.MoneyType, total, 'saloon-selfservice')
    exports['rsg-inventory']:AddItem(buyer, item, amount, nil, {}, 'saloon-selfservice')

    -- Record the sale
    RecordSale(saloonId, item, amount, total, buyerPlayer.PlayerData.citizenid, nil, 'selfservice')

    return true
end