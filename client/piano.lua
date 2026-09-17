
local isPlaying = false
local textUIShown = false

local PianoScenarios = {
    male = {
        'PROP_HUMAN_PIANO',
        'PROP_HUMAN_PIANO_UPPERCLASS',
        'PROP_HUMAN_PIANO_RIVERBOAT',
        'PROP_HUMAN_PIANO_SKETCHY',
    },
    female = {
        'PROP_HUMAN_ABIGAIL_PIANO',
    },
}

local function getNearestPiano()
    local coords = GetEntityCoords(cache.ped)
    local nearest, nearestDist = nil, math.huge
    for _, piano in pairs(Config.Pianos) do
        local dist = #(coords - piano.coords)
        if dist < nearestDist then
            nearest = piano
            nearestDist = dist
        end
    end
    if nearest and nearestDist <= (Config.Piano.InteractDistance or 2.5) then
        return nearest, nearestDist
    end
    return nil, nil
end

function OTGSaloonsPlayPiano(piano)
    if isPlaying then
        OTGSaloonsNotify('Piano', 'You are already playing the piano', 'error')
        return
    end

    local ped = PlayerPedId()
    local isMale = IsPedMale(ped)
    local scenarios = isMale and PianoScenarios.male or PianoScenarios.female
    local scenario = scenarios[math.random(1, #scenarios)]

    TaskStartScenarioAtPosition(ped, GetHashKey(scenario),
        piano.coords.x, piano.coords.y, piano.coords.z,
        piano.heading or 0.0, 0, false, false, 0, true)

    isPlaying = true
    OTGSaloonsNotify('Piano', 'Playing piano... press Backspace to stop', 'info')
end

function OTGSaloonsStopPiano()
    if not isPlaying then return end
    ClearPedTasks(PlayerPedId())
    isPlaying = false
end

CreateThread(function()
    while true do
        local sleep = 500

        if not (Config.Piano and Config.Piano.Enabled) then
            sleep = 1000
        elseif isPlaying then
            sleep = 0
            if not textUIShown then
                lib.showTextUI('[BACKSPACE] Stop playing')
                textUIShown = true
            end
            DisableControlAction(0, 0x8FD015D8, true) -- W
            DisableControlAction(0, 0xD27782E3, true) -- S
            DisableControlAction(0, 0xA65EBAB4, true) -- A
            DisableControlAction(0, 0x6319DB71, true) -- D
            if IsControlJustPressed(0, 0x156F7119) then -- BACKSPACE
                textUIShown = false
                lib.hideTextUI()
                OTGSaloonsStopPiano()
            end
        else
            local piano = getNearestPiano()
            if piano then
                sleep = 0
                if not textUIShown then
                    lib.showTextUI('[E] Play Piano')
                    textUIShown = true
                end
                if IsControlJustPressed(0, 0x8AAA0AD4) then -- E
                    textUIShown = false
                    lib.hideTextUI()
                    OTGSaloonsPlayPiano(piano)
                end
            elseif textUIShown then
                textUIShown = false
                lib.hideTextUI()
            end
        end

        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    if isPlaying then
        ClearPedTasks(PlayerPedId())
    end
    lib.hideTextUI()
end)
