local RSGCore = exports['rsg-core']:GetCoreObject()

local function getShipment(id)
    local row = MySQL.single.await('SELECT * FROM otg_saloon_shipments WHERE id = ?', { id })
    if row and row.contents then row.contents = json.decode(row.contents) or {} end
    return row
end

local function getDeliveryStation(businessId)
    local business = OTG.Businesses[tonumber(businessId)]
    if not business then return end
    for _, s in ipairs(business.stations or {}) do
        if s.type == 'delivery' then return s end
    end
end

RSGCore.Commands.Add(Config.FreightCommand, 'Open available OTG freight contracts', {}, false, function(source)
    TriggerClientEvent('otg-saloon:client:openFreight', source)
end, 'user')

lib.callback.register('otg-saloon:server:getContracts', function()
    return MySQL.query.await([[SELECT c.*, s.depot, s.crate_count, b.label AS business_label
        FROM otg_saloon_contracts c
        JOIN otg_saloon_shipments s ON s.id=c.shipment_id
        JOIN otg_saloon_businesses b ON b.id=c.business_id
        WHERE c.status IN ('open','accepted') ORDER BY c.id DESC LIMIT 50]]) or {}
end)

lib.callback.register('otg-saloon:server:getMyShipment', function(source)
    local Player = OTG.GetPlayer(source)
    if not Player then return nil end
    return MySQL.single.await([[SELECT s.*, b.label AS business_label
        FROM otg_saloon_shipments s JOIN otg_saloon_businesses b ON b.id=s.business_id
        WHERE s.assigned_to=? AND s.status IN ('assigned','loading','in_transit','partially_delivered')
        ORDER BY s.id DESC LIMIT 1]], { Player.PlayerData.citizenid })
end)

RegisterNetEvent('otg-saloon:server:createShipment', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local businessId = tonumber(data.businessId)
    if not OTG.HasBusinessAccess(src, businessId, 2) then return end
    if not Config.SupplyDepots[data.depot] then return end
    local Player = OTG.GetPlayer(src)
    local items = data.items
    if type(items) ~= 'table' or #items == 0 then return end

    local allowed, total = {}, 0
    for _, cfg in ipairs(Config.Ingredients) do allowed[cfg.item] = cfg end
    local clean = {}
    for _, entry in ipairs(items) do
        local cfg = allowed[tostring(entry.item)]
        local amount = math.floor(tonumber(entry.amount) or 0)
        if cfg and amount > 0 and amount <= 1000 then
            clean[#clean+1] = { item = cfg.item, amount = amount }
            total = total + (cfg.unitPrice * amount)
        end
    end
    if #clean == 0 or total <= 0 then return end
    if not Player.Functions.RemoveMoney('cash', total, 'otg-saloon supply order') then
        return OTG.Notify(src, 'You cannot afford this supply order.', 'error')
    end

    local crateCount = math.max(1, math.ceil(#clean / 3))
    local id = MySQL.insert.await([[INSERT INTO otg_saloon_shipments
        (business_id,depot,status,crate_count,contents,ordered_by) VALUES (?,?,?,?,?,?)]],
        { businessId, data.depot, 'ready', crateCount, json.encode(clean), Player.PlayerData.citizenid })
    MySQL.insert.await('INSERT INTO otg_saloon_transactions (business_id,type,amount,description,citizenid) VALUES (?,?,?,?,?)',
        { businessId, 'supply_order', -total, ('Shipment #%s'):format(id), Player.PlayerData.citizenid })
    OTG.Notify(src, ('Shipment #%s is ready at %s (%s crates).'):format(id, Config.SupplyDepots[data.depot].label, crateCount), 'success')
    TriggerClientEvent('otg-saloon:client:setSupplyRoute', src, Config.SupplyDepots[data.depot].pickup, Config.SupplyDepots[data.depot].label, id)
end)

RegisterNetEvent('otg-saloon:server:postContract', function(shipmentId, payment)
    local src = source
    shipmentId, payment = tonumber(shipmentId), tonumber(payment)
    local shipment = getShipment(shipmentId)
    if not shipment or shipment.status ~= 'ready' or not OTG.HasBusinessAccess(src, shipment.business_id, 2) then return end
    payment = math.floor(math.max(0, math.min(payment or 0, 1000)) * 100) / 100
    MySQL.insert.await('INSERT IGNORE INTO otg_saloon_contracts (shipment_id,business_id,payment) VALUES (?,?,?)',
        { shipmentId, shipment.business_id, payment })
    OTG.Notify(src, 'Freight contract posted.', 'success')
end)

RegisterNetEvent('otg-saloon:server:acceptContract', function(contractId)
    local src = source
    local Player = OTG.GetPlayer(src)
    if not Player then return end
    local cid = Player.PlayerData.citizenid
    local active = MySQL.scalar.await([[SELECT COUNT(*) FROM otg_saloon_shipments
        WHERE assigned_to=? AND status IN ('assigned','loading','in_transit','partially_delivered')]], { cid })
    if (tonumber(active) or 0) > 0 then return OTG.Notify(src, 'Finish your current freight job first.', 'error') end

    local contract = MySQL.single.await('SELECT * FROM otg_saloon_contracts WHERE id=? AND status="open"', { tonumber(contractId) })
    if not contract then return OTG.Notify(src, 'That contract is no longer available.', 'error') end
    local changed = MySQL.update.await('UPDATE otg_saloon_contracts SET status="accepted", contractor_citizenid=?, accepted_at=NOW() WHERE id=? AND status="open"',
        { cid, contract.id })
    if changed ~= 1 then return end
    MySQL.update.await('UPDATE otg_saloon_shipments SET status="assigned", assigned_to=? WHERE id=? AND status="ready"',
        { cid, contract.shipment_id })
    local shipment = getShipment(contract.shipment_id)
    if not shipment or not Config.SupplyDepots[shipment.depot] then return end
    OTG.Notify(src, 'Contract accepted. Go to the freight depot.', 'success')
    TriggerClientEvent('otg-saloon:client:setSupplyRoute', src, Config.SupplyDepots[shipment.depot].pickup, Config.SupplyDepots[shipment.depot].label, shipment.id)
    TriggerClientEvent('otg-saloon:client:refreshFreight', src)
end)

RegisterNetEvent('otg-saloon:server:pickupCrate', function(shipmentId)
    local src = source
    local Player = OTG.GetPlayer(src)
    local shipment = getShipment(tonumber(shipmentId))
    if not Player or not shipment or shipment.assigned_to ~= Player.PlayerData.citizenid then return end
    if not Config.SupplyDepots[shipment.depot] then return end
    local depot = Config.SupplyDepots[shipment.depot]
    if not OTG.DistanceOK(src, depot.pickup, Config.ServerValidationDistance + 3.0) then return end
    if shipment.picked_crates >= shipment.crate_count then return OTG.Notify(src, 'All crates have been collected.', 'error') end
    MySQL.update.await([[UPDATE otg_saloon_shipments
        SET picked_crates=picked_crates+1, status=IF(picked_crates+1>=crate_count,'in_transit','loading')
        WHERE id=? AND picked_crates<crate_count]], { shipment.id })
    TriggerClientEvent('otg-saloon:client:carryCrate', src, shipment.id)
end)

RegisterNetEvent('otg-saloon:server:deliverCrate', function(shipmentId)
    local src = source
    local Player = OTG.GetPlayer(src)
    local shipment = getShipment(tonumber(shipmentId))
    if not Player or not shipment or shipment.assigned_to ~= Player.PlayerData.citizenid then return end
    local station = getDeliveryStation(shipment.business_id)
    if not station or not OTG.DistanceOK(src, vector3(station.x,station.y,station.z), Config.DeliveryDistance) then return end
    if shipment.delivered_crates >= shipment.picked_crates then return OTG.Notify(src, 'You have no collected crate to unload.', 'error') end

    MySQL.update.await('UPDATE otg_saloon_shipments SET delivered_crates=delivered_crates+1 WHERE id=? AND delivered_crates<picked_crates', { shipment.id })
    shipment = getShipment(shipment.id)
    if shipment.delivered_crates < shipment.crate_count then
        MySQL.update.await('UPDATE otg_saloon_shipments SET status="partially_delivered" WHERE id=?', { shipment.id })
        return OTG.Notify(src, ('Delivered crate %s/%s.'):format(shipment.delivered_crates, shipment.crate_count), 'success')
    end

    for _, item in ipairs(shipment.contents or {}) do
        MySQL.query.await([[INSERT INTO otg_saloon_stock (business_id,item,amount) VALUES (?,?,?)
            ON DUPLICATE KEY UPDATE amount=amount+VALUES(amount)]],
            { shipment.business_id, item.item, item.amount })
    end
    MySQL.update.await('UPDATE otg_saloon_shipments SET status="delivered", completed_at=NOW() WHERE id=?', { shipment.id })

    local contract = MySQL.single.await('SELECT * FROM otg_saloon_contracts WHERE shipment_id=? AND status="accepted"', { shipment.id })
    if contract then
        -- Contract reward is created by the business contract and paid only on server-verified completion.
        Player.Functions.AddMoney('cash', tonumber(contract.payment) or 0, 'otg-saloon freight contract')
        MySQL.update.await('UPDATE otg_saloon_contracts SET status="completed", completed_at=NOW() WHERE id=?', { contract.id })
    end
    OTG.Notify(src, 'Shipment complete. Supplies were added to saloon stock.', 'success')
    TriggerClientEvent('otg-saloon:client:shipmentComplete', src)
end)
