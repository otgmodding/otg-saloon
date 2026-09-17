local RSGCore = exports['rsg-core']:GetCoreObject()

-- Make the phonograph item usable on the server (starts placement)
RSGCore.Functions.CreateUseableItem('phonograph', function(source)
    TriggerClientEvent('otg-saloons:client:startPlacingPhonograph', source)
end)

-- =====================================================================
-- Phonograph (server side)
-- Tracks placed phonographs, validates the item on place/pickup and
-- relays play/stop/volume to every client (audio via xsound).
-- Phonographs are session-only (cleared on restart) like the reference.
-- =====================================================================
local phonos = {} -- [id] = { coords = vector3, heading = number, owner = citizenid }

local function countPlayerPhonos(citizenid)
    local count = 0
    for _, data in pairs(phonos) do
        if data.owner == citizenid then
            count = count + 1
        end
    end
    return count
end

RegisterNetEvent('otg-saloons:server:placePhonograph', function(coords, heading)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Phonographs are only usable where locations are configured AND enabled.
    local phonographLocations = Config.PhonographLocations or {}
    if not phonographLocations or #phonographLocations == 0 then return end

    local citizenid = Player.PlayerData.citizenid
    if countPlayerPhonos(citizenid) >= 1 then
        OTGSaloons.Notify(src, 'Phonograph', 'You already have the maximum phonographs placed', 'error')
        return
    end

    -- Consume the item
    local removed, err = RSGCore.Functions.RemoveItem(Player.PlayerData.source, 'phonograph', 1, 'phonograph-place')
    if not removed and err ~= 'no inventory' and err ~= 'item not found' then
        OTGSaloons.Notify(src, 'Phonograph', 'Could not consume the phonograph item', 'error')
        return
    end

    local id = 'phono_' .. src .. '_' .. math.random(100000, 999999)
    phonos[id] = {
        coords = vector3(coords.x, coords.y, coords.z),
        heading = heading or 0.0,
        owner = citizenid,
    }

    TriggerClientEvent('otg-saloons:client:phonographPlaced', -1, id, coords, heading, citizenid)
    OTGSaloons.Notify(src, 'Phonograph', 'Phonograph placed at your location', 'success')
end)

RegisterNetEvent('otg-saloons:server:pickupPhonograph', function(id)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local phono = phonos[id]
    if not phono then return end
    if phono.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Phonograph', 'This phonograph does not belong to you', 'error')
        return
    end

    phonos[id] = nil
    TriggerClientEvent('otg-saloons:client:phonographRemoved', -1, id)

    -- Return an item so the player doesn't just lose it
    RSGCore.Functions.AddItem(Player.PlayerData.source, 'phonograph', 1, nil, 'phonograph-pickup')
    OTGSaloons.Notify(src, 'Phonograph', 'Phonograph picked up', 'info')
end)

RegisterNetEvent('otg-saloons:server:phonoPlay', function(id, url, volume)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local phono = phonos[id]
    if not phono then return end
    if phono.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Phonograph', 'You do not own this phonograph', 'error')
        return
    end

    if not url or type(url) ~= 'string' or #url == 0 then
        OTGSaloons.Notify(src, 'Phonograph', 'No track URL provided', 'error')
        return
    end

    local vol = tonumber(volume) or 0.3
    vol = math.max(0.0, math.min(1.0, vol))

    -- Relay to all clients so the audio is heard by anyone near the phonograph
    TriggerClientEvent('otg-saloons:client:phonoPlay', -1, id, phono.coords, url, vol)
end)

RegisterNetEvent('otg-saloons:server:phonoStop', function(id)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local phono = phonos[id]
    if not phono then return end
    if phono.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Phonograph', 'You do not own this phonograph', 'error')
        return
    end

    TriggerClientEvent('otg-saloons:client:phonoStop', -1, id)
end)

RegisterNetEvent('otg-saloons:server:phonoVolume', function(id, volume)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local phono = phonos[id]
    if not phono then return end
    if phono.owner ~= Player.PlayerData.citizenid then
        OTGSaloons.Notify(src, 'Phonograph', 'You do not own this phonograph', 'error')
        return
    end

    local vol = tonumber(volume) or 0.3
    vol = math.max(0.0, math.min(1.0, vol))

    TriggerClientEvent('otg-saloons:client:phonoVolume', -1, id, vol)
end)

-- Broadcast the full phonograph list to a client on join/placement so theirs stays in sync
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    print(('[%s] ^2START^7 phonograph server module loaded, locations=%d'):format(resourceName, #(Config.PhonographLocations or {})))
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    phonos = {}
end)
