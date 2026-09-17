-- Dancer state
local isDancing = false
local danceCooldown = 0

------------------------------------------------
-- Start Dancing
------------------------------------------------
RegisterNetEvent('otg-saloons:client:startDancing', function(saloonId)
    if not Config.Dancers.Enabled then
        OTGSaloonsNotify('Dancing Disabled', 'The dancer system is disabled', 'error')
        return
    end

    if isDancing then
        OTGSaloonsNotify('Already Dancing', 'You are already dancing', 'error')
        return
    end

    -- Check cooldown
    local now = OTGSaloons.GetTimestamp()
    if now < danceCooldown then
        local waitTime = danceCooldown - now
        OTGSaloonsNotify('Cooldown', 'Please wait ' .. waitTime .. ' seconds before dancing again', 'error')
        return
    end

    -- Check max dancers
    local dancerCount = 0
    for _, player in pairs(GetActivePlayers()) do
        local ped = GetPlayerPed(player)
        if ped ~= cache.ped and IsPedUsingAnyScenario(ped) then
            dancerCount = dancerCount + 1
        end
    end
    if dancerCount >= Config.Dancers.MaxDancers then
        OTGSaloonsNotify('Too Many Dancers', 'The dance floor is full', 'error')
        return
    end

    isDancing = true

    -- Play dance animation
    local dict = Config.Dancers.DanceAnimDict
    lib.requestAnimDict(dict)

    TaskPlayAnim(cache.ped, dict, Config.Dancers.DanceAnimName, 1.0, 1.0, Config.Dancers.DanceDuration, 31, 1.0, false, false, false)

    OTGSaloonsNotify('Dancing!', 'Show off your moves!', 'success')

    -- Set cooldown
    danceCooldown = OTGSaloons.GetTimestamp() + Config.Dancers.DanceDuration + Config.Dancers.DanceCooldown

    -- Stop dancing after duration
    SetTimeout(Config.Dancers.DanceDuration * 1000, function()
        if isDancing then
            ClearPedTasks(cache.ped)
            isDancing = false
        end
    end)
end)

------------------------------------------------
-- Stop Dancing
------------------------------------------------
RegisterNetEvent('otg-saloons:client:stopDancing', function()
    if isDancing then
        ClearPedTasks(cache.ped)
        isDancing = false
    end
end)

------------------------------------------------
-- Dance Tip System
------------------------------------------------
-- When a player dances, others can tip them
RegisterNetEvent('otg-saloons:client:tipDancer', function(saloonId, targetPlayerId)
    local data = saloonData
    if not data then return end

    local input = lib.inputDialog('Tip Dancer', {
        { type = 'number', label = 'Tip Amount', default = 1, min = Config.Dancers.TipMin, max = Config.Dancers.TipMax },
    })
    if input and input[1] then
        TriggerServerEvent('otg-saloons:server:tipDancer', saloonId, targetPlayerId, tonumber(input[1]))
    end
end)

------------------------------------------------
-- Cleanup on Resource Stop
------------------------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if isDancing then
        ClearPedTasks(cache.ped)
        isDancing = false
    end
end)