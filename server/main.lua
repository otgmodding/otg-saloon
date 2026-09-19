local RSGCore = exports['rsg-core']:GetCoreObject()

OTG = OTG or {}
OTG.RSGCore = RSGCore
OTG.Businesses = OTG.Businesses or {}

local function notify(src, description, ntype)
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'OTG Saloon',
        description = description,
        type = ntype or 'inform'
    })
end
OTG.Notify = notify

function OTG.GetPlayer(src)
    return RSGCore.Functions.GetPlayer(src)
end

function OTG.IsAdmin(src)
    return RSGCore.Functions.HasPermission(src, 'admin')
end

function OTG.DistanceOK(src, coords, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local p = GetEntityCoords(ped)
    local dx, dy, dz = p.x - coords.x, p.y - coords.y, p.z - coords.z
    return (dx * dx + dy * dy + dz * dz) <= ((maxDistance or Config.ServerValidationDistance) ^ 2)
end

function OTG.HasBusinessAccess(src, businessId, minGrade)
    local Player = OTG.GetPlayer(src)
    local business = OTG.Businesses[tonumber(businessId)]
    if not Player or not business then return false end
    local job = Player.PlayerData.job
    if not job or job.name ~= business.job then return false end
    local grade = tonumber(job.grade and (job.grade.level or job.grade)) or 0
    return grade >= (tonumber(minGrade) or 0)
end

function OTG.IsBusinessBoss(src, businessId)
    local Player = OTG.GetPlayer(src)
    local business = OTG.Businesses[tonumber(businessId)]
    if not Player or not business or Player.PlayerData.job.name ~= business.job then return false end
    local playerJob = Player.PlayerData.job
    if playerJob.isboss == true or (type(playerJob.grade) == 'table' and playerJob.grade.isboss == true) then
        return true
    end
    local grade = tonumber(playerJob.grade and (playerJob.grade.level or playerJob.grade)) or 0
    local job = RSGCore.Shared.Jobs[business.job]
    return job and job.grades and job.grades[tostring(grade)] and job.grades[tostring(grade)].isboss == true
end

function OTG.GetStation(businessId, stationId, stationType)
    local business = OTG.Businesses[tonumber(businessId)]
    if not business then return end
    for _, station in ipairs(business.stations or {}) do
        if tonumber(station.id) == tonumber(stationId) and (not stationType or station.type == stationType) then
            return station, business
        end
    end
end

-- Existing installations are migrated automatically; new installations use sql/install.sql.
MySQL.ready(function()
    local migrations = {
        'ALTER TABLE otg_saloon_businesses ADD COLUMN storage_weight INT UNSIGNED NOT NULL DEFAULT 500000',
        'ALTER TABLE otg_saloon_businesses ADD COLUMN storage_slots INT UNSIGNED NOT NULL DEFAULT 80',
        'ALTER TABLE otg_saloon_businesses ADD COLUMN blip_x DOUBLE NULL',
        'ALTER TABLE otg_saloon_businesses ADD COLUMN blip_y DOUBLE NULL',
        'ALTER TABLE otg_saloon_businesses ADD COLUMN blip_z DOUBLE NULL',
        'ALTER TABLE otg_saloon_businesses ADD COLUMN blip_sprite BIGINT UNSIGNED NULL',
        'ALTER TABLE otg_saloon_businesses ADD COLUMN blip_scale FLOAT NOT NULL DEFAULT 0.2',
        'ALTER TABLE otg_saloon_businesses MODIFY COLUMN blip_sprite INT NULL',
        'UPDATE otg_saloon_businesses SET blip_sprite=1879260108 WHERE blip_sprite=1321928545',
        'ALTER TABLE otg_saloon_recipes ADD COLUMN item_weight INT UNSIGNED NOT NULL DEFAULT 100',
        'ALTER TABLE otg_saloon_recipes ADD COLUMN item_image VARCHAR(255) NULL',
        'ALTER TABLE otg_saloon_recipes ADD COLUMN item_description VARCHAR(255) NULL',
        'ALTER TABLE otg_saloon_recipes ADD COLUMN dynamic_item TINYINT(1) NOT NULL DEFAULT 0'
    }
    for _, query in ipairs(migrations) do pcall(MySQL.query.await, query) end
end)

CreateThread(function()
    Wait(1000)
    TriggerEvent('otg-saloon:server:reload')
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    print('^2[otg-saloon]^7 started - RSG Core / RedM')
end)
