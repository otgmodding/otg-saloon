-- =====================================================================
-- Storage Stashes (rsg-inventory)
-- Employee Storage: owner + employees. Boss Storage: owner only.
-- =====================================================================
RegisterNetEvent('otg-saloons:server:openEmployeeStash', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    local isOwner = saloon.owner == Player.PlayerData.citizenid
    local isEmployee = OTGSaloons.SaloonEmployees[saloonId] and OTGSaloons.SaloonEmployees[saloonId][Player.PlayerData.citizenid] ~= nil

    if not isOwner and not isEmployee then
        OTGSaloons.Notify(src, 'You do not have access to this storage', nil, 'error')
        return
    end

    exports['rsg-inventory']:OpenInventory(src, 'otg_saloon_empstash_' .. saloonId, {
        label = saloon.label .. ' Employee Storage',
        slots = Config.Storage.EmployeeStash.Slots,
        maxweight = Config.Storage.EmployeeStash.Weight,
    })
end)

RegisterNetEvent('otg-saloons:server:openBossStash', function(saloonId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local saloon = OTGSaloons.Saloons[saloonId]
    if not saloon then return end

    if saloon.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Only the owner can access the boss storage', nil, 'error')
        return
    end

    exports['rsg-inventory']:OpenInventory(src, 'otg_saloon_bossstash_' .. saloonId, {
        label = saloon.label .. ' Boss Storage',
        slots = Config.Storage.BossStash.Slots,
        maxweight = Config.Storage.BossStash.Weight,
    })
end)
