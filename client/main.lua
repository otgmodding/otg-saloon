local RSGCore = exports['rsg-core']:GetCoreObject()

-- Load locale
local lang = Config.Locale or 'en'
local langStr = LoadResourceFile(GetCurrentResourceName(), string.format('locales/%s.lua', lang))
local Lang = langStr and assert(load(langStr))() or {}
if not next(Lang) then
    -- fallback to default
    langStr = LoadResourceFile(GetCurrentResourceName(), 'locales/en.lua')
    Lang = langStr and assert(load(langStr))() or {}
end

local Businesses = {}
local zones = {}
local stationProps = {}
local businessBlips = {}

local function loadModel(model)
    if not model or model == '' then return nil end
    local hash = joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do Wait(0) end
    if not HasModelLoaded(hash) then return nil end
    return hash
end

local function removeZones()
    for _, id in pairs(zones) do
        pcall(function() exports.ox_target:removeZone(id) end)
    end
    zones = {}

    for _, entity in pairs(stationProps) do
        if entity and DoesEntityExist(entity) then DeleteObject(entity) end
    end
    stationProps = {}

    for _, blip in pairs(businessBlips) do
        if blip then RemoveBlip(blip) end
    end
    businessBlips = {}
end

local function jobGrade()
    local pd = RSGCore.Functions.GetPlayerData()
    local job = pd and pd.job
    return job and job.name, job and tonumber(job.grade and (job.grade.level or job.grade)) or 0
end

local function openCraftMenu(business, station)
    local job, grade = jobGrade()
    if job ~= business.job then return end
    local options = {}
    for _, recipe in ipairs(business.recipes or {}) do
        if grade >= (tonumber(recipe.min_grade) or 0) then
            local desc = {}
            for _, ing in ipairs(recipe.ingredients or {}) do
                desc[#desc+1] = ('%sx %s'):format(ing.amount, ing.item)
            end
            options[#options+1] = {
                title = recipe.label,
                description = table.concat(desc, ', '),
                icon = 'utensils',
                onSelect = function()
                    TriggerServerEvent('otg-saloon:server:craft', business.id, recipe.id, station.id)
                end
            }
        end
    end
    lib.registerContext({ id='otg_saloon_craft', title=business.label .. ' - Crafting', options=options })
    lib.showContext('otg_saloon_craft')
end

local function managementMenu(business)
    local options = {
        {
            title = Lang.menu_crafting or 'Crafting',
            icon = 'utensils',
            onSelect = function()
                -- Find the first crafting station in the business
                local craftStation = nil
                for _, station in ipairs(business.stations or {}) do
                    if station.type == 'craft' then
                        craftStation = station
                        break
                    end
                end
                if not craftStation then
                    return lib.notify({description=Lang.notification_no_crafting_station or 'No crafting station available for this business.', type='error'})
                end
                openCraftMenu(business, craftStation)
            end
        },
        {
            title = Lang.menu_view_stock or 'View Stock',
            icon = 'boxes-stacked',
            onSelect = function()
                local stock = lib.callback.await('otg-saloon:server:getStock', false, business.id) or {}
                local opts = {}
                for _, s in ipairs(stock) do opts[#opts+1] = { title=s.item, description=('Amount: %s'):format(s.amount) } end
                if #opts == 0 then opts[1] = { title='No delivered stock yet', disabled=true } end
                lib.registerContext({ id='otg_stock', title=business.label .. ' Stock', options=opts })
                lib.showContext('otg_stock')
            end
        },
        {
            title = Lang.menu_order_supplies or 'Order Supplies',
            icon = 'box',
            onSelect = function()
                local depotOptions = {}
                for key, depot in pairs(Config.SupplyDepots) do depotOptions[#depotOptions+1] = {value=key,label=depot.label} end
                local input = lib.inputDialog('Supply Order', {
                    {type='select', label='Pickup Depot', options=depotOptions, required=true},
                    {type='select', label='Ingredient', options=(function()
                        local t={} for _,v in ipairs(Config.Ingredients) do t[#t+1]={value=v.item,label=('%s ($%.2f)'):format(v.label,v.unitPrice)} end return t end)(), required=true},
                    {type='number', label='Amount', default=10, min=1, max=1000, required=true}
                })
                if not input then return end
                TriggerServerEvent('otg-saloon:server:createShipment', {
                    businessId=business.id, depot=input[1], items={{item=input[2], amount=input[3]}}
                })
            end
        },
        {
            title = Lang.menu_post_freight or 'Post Freight Contract',
            icon = 'horse',
            onSelect = function()
                local input = lib.inputDialog('Post Freight Contract', {
                    {type='number', label='Shipment ID', min=1, required=true},
                    {type='number', label='Payment', min=0, max=1000, required=true}
                })
                if input then TriggerServerEvent('otg-saloon:server:postContract', input[1], input[2]) end
            end
        },
        {
            title = Lang.menu_finances or 'Finances',
            description = Lang.menu_finances_desc or 'View balance and the latest 50 business transactions.',
            icon = 'wallet',
            onSelect = function()
                local finance = lib.callback.await('otg-saloon:server:getFinances', false, business.id)
                if not finance then return lib.notify({description=Lang.notification_boss_required or 'Boss access is required.', type='error'}) end
                local options = {{title=('Balance: $%.2f'):format(tonumber(finance.balance) or 0), icon='dollar-sign', readOnly=true}}
                for _, tx in ipairs(finance.transactions or {}) do
                    options[#options+1] = {title=tx.description, description=('%s | $%.2f | %s'):format(tx.type, tonumber(tx.amount) or 0, tx.created_at or ''), icon='receipt', readOnly=true}
                end
                lib.registerContext({id='otg_saloon_finances', title=business.label .. ' Finances', menu='otg_management', options=options})
                lib.showContext('otg_saloon_finances')
            end
        }
    }
    lib.registerContext({ id='otg_management', title=business.label .. ' Management', options=options })
    lib.showContext('otg_management')
end

local managementOpening = false
local function openManagementStation(business, station)
    if managementOpening then return end
    managementOpening = true
    local allowed, message = lib.callback.await('otg-saloon:server:openManagement', false, business.id, station.id)
    managementOpening = false
    if not allowed then
        return lib.notify({description=message or 'You cannot use this management station.',type='error'})
    end
    managementMenu(business)
end

local function rebuildZones()
    removeZones()
    local zoneCount, blipCount, failures = 0, 0, 0
    for _, business in pairs(Businesses) do
        if business.active ~= false and business.blip_x and business.blip_y and business.blip_z then
            local x, y, z = tonumber(business.blip_x), tonumber(business.blip_y), tonumber(business.blip_z)
            if x and y and z then
                local ok, err = pcall(function()
                    -- RedM's BLIP_ADD_FOR_COORDS takes a vector3, not separate x/y/z arguments.
                    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, vec3(x, y, z))
                    if not blip or blip == 0 then error('BLIP_ADD_FOR_COORDS returned an invalid handle') end
                    local requestedSprite = tonumber(business.blip_sprite) or Config.DefaultBlipSprite
                    local appliedSprite = tonumber(Config.RuntimeBlipSprite) or 1879260108
                    SetBlipSprite(blip, appliedSprite, 1)
                    SetBlipScale(blip, tonumber(business.blip_scale) or Config.DefaultBlipScale)
                    Citizen.InvokeNative(0x90293F03830CA913, blip, 2)
                    SetBlipAsShortRange(blip, false)
                    local blipName = CreateVarString(10, 'LITERAL_STRING', tostring(business.label or 'Saloon'))
                    Citizen.InvokeNative(0x9CB1A1623062F402, blip, blipName)
                    businessBlips[#businessBlips+1] = blip
                    blipCount = blipCount + 1
                    if Config.Debug then
                        print(('[otg-saloon:debug] blip ready | business=%s (%s) | coords=%.2f, %.2f, %.2f | sprite=%s | scale=%.2f | handle=%s'):format(
                            tostring(business.label), tostring(business.id), x, y, z,
                            tostring(appliedSprite),
                            tonumber(business.blip_scale) or Config.DefaultBlipScale, tostring(blip)))
                        if requestedSprite ~= appliedSprite then
                            print(('[otg-saloon:debug] blip sprite fallback | business=%s | requested=%s | applied=%s'):format(
                                tostring(business.id), tostring(requestedSprite), tostring(appliedSprite)))
                        end
                    end
                end)
                if not ok then
                    failures = failures + 1
                    print(('[otg-saloon] failed to create blip for business %s: %s'):format(tostring(business.id), tostring(err)))
                end
            end
        elseif Config.Debug then
            local reason = business.active == false
                and 'business is inactive; enable Business is active and save changes'
                or 'coordinates are not set; use SET BLIP TO MY CURRENT POSITION'
            print(('[otg-saloon:debug] blip skipped | business=%s (%s) | reason=%s'):format(
                tostring(business.label), tostring(business.id), reason))
        end
        for _, station in ipairs(business.stations or {}) do
            local s, b = station, business
            local ok, err = pcall(function()
                local sx, sy, sz = tonumber(s.x), tonumber(s.y), tonumber(s.z)
                if not sx or not sy or not sz then error('station has invalid coordinates') end
                local settings = type(s.settings) == 'table' and s.settings or {}
                if settings.prop and settings.prop ~= '' then
                    local hash = loadModel(settings.prop)
                    if hash then
                        local propCoords = type(settings.propCoords) == 'table' and settings.propCoords or {}
                        local px = tonumber(propCoords.x) or sx
                        local py = tonumber(propCoords.y) or sy
                        local pz = tonumber(propCoords.z) or sz
                        local ph = tonumber(propCoords.h) or tonumber(s.heading) or 0.0
                        local prop = CreateObject(hash, px, py, pz, false, false, false)
                        if prop and prop ~= 0 then
                            SetEntityHeading(prop, ph)
                            FreezeEntityPosition(prop, true)
                            stationProps[#stationProps+1] = prop
                        end
                        SetModelAsNoLongerNeeded(hash)
                    elseif Config.Debug then
                        print(('[otg-saloon] station %s uses invalid prop %s; creating its interaction zone without the prop.'):format(tostring(s.id), tostring(settings.prop)))
                    end
                end

                local zoneData = {
                    name = ('otg_saloon_%s'):format(s.id),
                    coords = vec3(sx, sy, sz + ((Config.TargetHeight or 2.0) * 0.5)),
                    debug = Config.Debug == true,
                    drawSprite = true,
                    options = {{
                    name = ('otg_saloon_%s'):format(s.id),
                    icon = 'fa-solid fa-martini-glass',
                    label = tostring(s.label or Config.StationTypes[s.type] or 'Saloon Station'),
                    distance = Config.DefaultInteractDistance,
                    canInteract = function()
                        -- Public trays and manager points remain visible. Manager authorization
                        -- is checked after selection so a bad job/grade never makes the target silently disappear.
                        if s.type == 'tray' or s.type == 'manager' then return true end
                        local job, grade = jobGrade()
                        return job == b.job and grade >= (tonumber(s.min_grade) or 0)
                    end,
                    onSelect = function()
                        if s.type == 'craft' then openCraftMenu(b,s)
                        elseif s.type == 'storage' then TriggerServerEvent('otg-saloon:server:openStorage', b.id)
                        elseif s.type == 'tray' then TriggerServerEvent('otg-saloon:server:openTray', b.id, s.id)
                        elseif s.type == 'manager' then
                            openManagementStation(b, s)
                        elseif s.type == 'delivery' then
                            local shipment = lib.callback.await('otg-saloon:server:getMyShipment', false)
                            if shipment and tonumber(shipment.business_id)==tonumber(b.id) then
                                TriggerServerEvent('otg-saloon:server:deliverCrate', shipment.id)
                            end
                        else
                            lib.notify({description='This station type is reserved for the next module.',type='inform'})
                        end
                    end
                    }}
                }
                local id
                if settings.shape == 'box' then
                    zoneData.size = vec3(tonumber(settings.length) or 1.5, tonumber(settings.width) or 1.5, Config.TargetHeight or 2.0)
                    zoneData.rotation = tonumber(s.heading) or 0.0
                    id = exports.ox_target:addBoxZone(zoneData)
                else
                    zoneData.radius = math.max(tonumber(settings.radius) or Config.DefaultStationRadius, Config.MinimumTargetRadius or 1.5)
                    id = exports.ox_target:addSphereZone(zoneData)
                end
                if not id then error('ox_target returned no zone id') end
                zones[#zones+1] = id
                zoneCount = zoneCount + 1
                if Config.Debug then
                    local dimensions = settings.shape == 'box'
                        and ('%.2f x %.2f'):format(tonumber(settings.length) or 1.5, tonumber(settings.width) or 1.5)
                        or ('radius %.2f'):format(tonumber(settings.radius) or Config.DefaultStationRadius)
                    print(('[otg-saloon:debug] target ready | business=%s (%s) | station=%s (%s/%s) | coords=%.2f, %.2f, %.2f | shape=%s %s | zone=%s'):format(
                        tostring(b.label), tostring(b.id), tostring(s.label), tostring(s.id), tostring(s.type),
                        sx, sy, sz, tostring(settings.shape or 'sphere'), dimensions, tostring(id)))
                end
            end)
            if not ok then
                failures = failures + 1
                print(('[otg-saloon] failed to create station %s (%s): %s'):format(tostring(s.id), tostring(s.type), tostring(err)))
            end
        end
    end
    if Config.Debug then
        print(('[otg-saloon:debug] runtime rebuilt | businesses=%s | zones=%s | blips=%s | failures=%s'):format(
            tostring((function() local count=0 for _ in pairs(Businesses) do count=count+1 end return count end)()),
            zoneCount, blipCount, failures))
    end
end

CreateThread(function()
    local showingManagerPrompt = false
    while true do
        local sleep = 750
        local nearestBusiness, nearestStation, nearestDistance
        local ped = cache.ped
        if ped and ped ~= 0 then
            local coords = GetEntityCoords(ped)
            for _, business in pairs(Businesses) do
                for _, station in ipairs(business.stations or {}) do
                    if station.type == 'manager' then
                        local sx, sy, sz = tonumber(station.x), tonumber(station.y), tonumber(station.z)
                        if sx and sy and sz then
                            local distance = #(coords - vec3(sx, sy, sz))
                            if not nearestDistance or distance < nearestDistance then
                                nearestBusiness, nearestStation, nearestDistance = business, station, distance
                            end
                        end
                    end
                end
            end
        end

        if not OTGSaloonCreatorPlacing and nearestStation and nearestDistance <= Config.DefaultInteractDistance then
            sleep = 0
            if not showingManagerPrompt and not lib.getOpenContextMenu() then
                lib.showTextUI(('[E] %s'):format(nearestStation.label or 'Management'), {icon='briefcase'})
                showingManagerPrompt = true
            end
            if IsControlJustReleased(0, 0xCEFD9220) then -- INPUT_CONTEXT_X / E
                if showingManagerPrompt then lib.hideTextUI() showingManagerPrompt = false end
                openManagementStation(nearestBusiness, nearestStation)
            end
        elseif showingManagerPrompt then
            lib.hideTextUI()
            showingManagerPrompt = false
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('otg-saloon:client:syncBusinesses', function(data)
    Businesses = data or {}
    rebuildZones()
end)

RegisterNetEvent('otg-saloon:client:craftProgress', function(label, duration)
    lib.progressBar({ duration=duration, label='Preparing '..label, canCancel=false, disable={combat=true,move=false} })
end)

RegisterNetEvent('otg-saloon:client:setSupplyRoute', function(coords, label, shipmentId)
    if not coords then return end
    SetNewWaypoint(coords.x, coords.y)
    lib.notify({title='Supply Order Ready', description=('Shipment #%s: pick up at %s. A route has been set.'):format(shipmentId, label), type='success', duration=9000})
end)

CreateThread(function()
    Wait(1500)
    Businesses = lib.callback.await('otg-saloon:server:getBusinesses', false) or {}
    rebuildZones()
end)

AddEventHandler('RSGCore:Client:OnPlayerLoaded', function()
    CreateThread(function()
        Wait(2000)
        local refreshed = lib.callback.await('otg-saloon:server:getBusinesses', false)
        if refreshed and (next(refreshed) ~= nil or next(Businesses) == nil) then
            Businesses = refreshed
            rebuildZones()
        elseif Config.Debug then
            print('[otg-saloon:debug] ignored transient empty business response during player initialization')
        end
    end)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'ox_target' then return end
    CreateThread(function()
        Wait(500)
        local refreshed = lib.callback.await('otg-saloon:server:getBusinesses', false)
        if refreshed and (next(refreshed) ~= nil or next(Businesses) == nil) then
            Businesses = refreshed
            rebuildZones()
        end
    end)
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    removeZones()
end)
