-- Drunk state
local drunkLevel = 0
local drunkThreadRunning = false

------------------------------------------------
-- Add Drunk Level
------------------------------------------------
RegisterNetEvent('otg-saloons:client:addDrunkLevel', function(item)
    if not Config.DrunkEffects.Enabled then return end

    local level = Config.DrunkEffects.DrunkLevels[item]
    if not level then return end

    drunkLevel = math.min(Config.DrunkEffects.MaxDrunkLevel, drunkLevel + level)

    -- Start the drunk thread if not running
    if not drunkThreadRunning then
        StartDrunkThread()
    end

    -- Notify player
    if drunkLevel >= Config.DrunkEffects.SevereDrunkThreshold then
        OTGSaloonsNotify('Very Drunk!', 'You are very drunk...', 'warning')
    elseif drunkLevel >= Config.DrunkEffects.DrunkThreshold then
        OTGSaloonsNotify('Getting Drunk', 'You are starting to feel the effects...', 'info')
    end
end)

------------------------------------------------
-- Clear Drunk Level
------------------------------------------------
RegisterNetEvent('otg-saloons:client:clearDrunkLevel', function()
    drunkLevel = 0
end)

------------------------------------------------
-- Drunk Effects Thread
------------------------------------------------
function StartDrunkThread()
    drunkThreadRunning = true

    CreateThread(function()
        while drunkLevel > 0 do
            -- Decay drunk level
            drunkLevel = math.max(0, drunkLevel - Config.DrunkEffects.DrunkDecayRate)

            -- Apply effects based on drunk level
            if drunkLevel >= Config.DrunkEffects.DrunkThreshold then
                -- Camera sway
                if Config.DrunkEffects.EnableCameraSway then
                    local intensity = (drunkLevel / Config.DrunkEffects.MaxDrunkLevel)
                    local sway = Config.DrunkEffects.SwayMin + (Config.DrunkEffects.SwayMax - Config.DrunkEffects.SwayMin) * intensity
                    local time = GetGameTimer() / 1000

                    local pitch = math.sin(time * 2.0) * sway * 10
                    local roll = math.cos(time * 1.5) * sway * 10
                    local yaw = math.sin(time * 1.2) * sway * 5

                    SetGameplayCamRelativePitch(pitch, 1.0)
                    SetGameplayCamRelativeHeading(yaw)
                end

                -- Screen effects
                if Config.DrunkEffects.EnableBlur then
                    local intensity = (drunkLevel - Config.DrunkEffects.DrunkThreshold) / (Config.DrunkEffects.MaxDrunkLevel - Config.DrunkEffects.DrunkThreshold)
                    SetTimecycleModifier('drunk', intensity)
                end

                if Config.DrunkEffects.EnableColorShift then
                    local intensity = (drunkLevel / Config.DrunkEffects.MaxDrunkLevel)
                    SetExtraTimecycleModifier('spectator5', intensity)
                end

                -- Movement impairment
                if Config.DrunkEffects.EnableMovementImpairment and drunkLevel >= Config.DrunkEffects.SevereDrunkThreshold then
                    if math.random() < Config.DrunkEffects.MovementImpairmentChance / 100 then
                        -- Random stumble
                        local dict = 'amb_rest_drunk@world_human_drinking@male_a@idle_a'
                        lib.requestAnimDict(dict)
                        TaskPlayAnim(cache.ped, dict, 'idle_a', 1.0, 1.0, 1000, 31, 1.0, false, false, false)
                    end
                end
            end

            Wait(1000)
        end

        -- Clear effects when sober
        ClearTimecycleModifier()
        ClearExtraTimecycleModifier()
        SetGameplayCamRelativePitch(0.0, 1.0)
        SetGameplayCamRelativeHeading(0.0)
        drunkThreadRunning = false
    end)
end

------------------------------------------------
-- Cleanup on Resource Stop
------------------------------------------------
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    drunkLevel = 0
    ClearTimecycleModifier()
    ClearExtraTimecycleModifier()
    SetGameplayCamRelativePitch(0.0, 1.0)
    SetGameplayCamRelativeHeading(0.0)
end)