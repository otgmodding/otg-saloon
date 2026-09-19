local freightZones = {}
local carrying = false
local crateObject = nil

local function cleanupCrate()
    carrying = false
    if crateObject and DoesEntityExist(crateObject) then DeleteObject(crateObject) end
    crateObject = nil
    ClearPedTasks(cache.ped)
end

local function depotLabel(key)
    return Config.SupplyDepots[key] and Config.SupplyDepots[key].label or key
end

local function openFreight()
    local contracts = lib.callback.await('otg-saloon:server:getContracts', false) or {}
    local options = {}
    for _, c in ipairs(contracts) do
        local contract = c
        options[#options+1] = {
            title = ('%s - $%.2f'):format(contract.business_label, tonumber(contract.payment) or 0),
            description = ('%s | %s crates | %s'):format(depotLabel(contract.depot), contract.crate_count, contract.status),
            disabled = contract.status ~= 'open',
            onSelect = function() TriggerServerEvent('otg-saloon:server:acceptContract', contract.id) end
        }
    end
    if #options == 0 then options[1]={title='No freight contracts available',disabled=true} end
    lib.registerContext({id='otg_freight',title='Freight Contracts',options=options})
    lib.showContext('otg_freight')
end

RegisterNetEvent('otg-saloon:client:openFreight', openFreight)
RegisterNetEvent('otg-saloon:client:refreshFreight', function() Wait(500) openFreight() end)

RegisterNetEvent('otg-saloon:client:carryCrate', function()
    cleanupCrate()
    local model = Config.CrateProp
    lib.requestModel(model)
    local c = GetEntityCoords(cache.ped)
    crateObject = CreateObject(model, c.x,c.y,c.z, false,false,false)
    AttachEntityToEntity(crateObject, cache.ped, GetPedBoneIndex(cache.ped, 7966), 0.12,0.28,0.08, 10.0,0.0,0.0, true,true,false,true,1,true)
    carrying = true
    lib.notify({description='Crate collected. Take it to the saloon delivery point.',type='success'})
end)

RegisterNetEvent('otg-saloon:client:shipmentComplete', cleanupCrate)

CreateThread(function()
    for key, depot in pairs(Config.SupplyDepots) do
        local depotKey = key
        local boardId = exports.ox_target:addSphereZone({
            coords=depot.freightBoard, radius=1.5, debug=Config.Debug,
            options={{name='otg_freight_board_'..depotKey,icon='fa-solid fa-clipboard',label='Freight Contracts',onSelect=openFreight}}
        })
        freightZones[#freightZones+1]=boardId

        local pickupId = exports.ox_target:addSphereZone({
            coords=depot.pickup, radius=2.0, debug=Config.Debug,
            options={{
                name='otg_freight_pickup_'..depotKey,icon='fa-solid fa-box',label='Collect Shipment Crate',
                onSelect=function()
                    if carrying then return lib.notify({description='You are already carrying a crate.',type='error'}) end
                    local shipment=lib.callback.await('otg-saloon:server:getMyShipment',false)
                    if not shipment or shipment.depot~=depotKey then return lib.notify({description='No assigned shipment at this depot.',type='error'}) end
                    TriggerServerEvent('otg-saloon:server:pickupCrate',shipment.id)
                end
            }}
        })
        freightZones[#freightZones+1]=pickupId
    end
end)

-- V1 cargo state is server-persistent and visually carried. Wagon slot attachment is intentionally
-- isolated for a later model-specific attachment pass; no GTA/FiveM vehicle assumptions are used.

AddEventHandler('onResourceStop', function(resource)
    if resource~=GetCurrentResourceName() then return end
    cleanupCrate()
    for _,id in ipairs(freightZones) do pcall(function() exports.ox_target:removeZone(id) end) end
end)
