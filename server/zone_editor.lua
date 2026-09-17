local MySQL = exports.oxmysql

-- Get saloons owned by a player
RegisterServerEvent('otg-saloons:server:getOwnedSaloons', function()
    local src = source
    local player = GetPlayer(src)
    local citizenid = player.PlayerData.citizenid

    local result = MySQL.query.await('SELECT saloon_id FROM otg_saloons WHERE owner = ?', { citizenid })

    local saloons = {}
    for _, row in ipairs(result) do
        table.insert(saloons, {
            id = row.saloon_id, 
        })
    end

    TriggerClientEvent('otg-saloons:client:zoneEditorOwnedSaloons', src, saloons)
end)

-- Get interactions for a saloon
RegisterServerEvent('otg-saloons:server:getInteractions', function(saloonId)
    local src = source
    local result = MySQL.query.await('SELECT * FROM otg_saloon_interactions WHERE saloon_id = ?', { saloonId })

    local interactions = {}
    for _, row in ipairs(result) do
        table.insert(interactions, {
            id = row.id,
            saloon_id = row.saloon_id,
            name = row.name,
            label = row.label,
            event = row.event,
            args = row.args, -- This is already a JSON object from the database
            color = row.color,
            zone_type = row.zone_type,
            zone_data = row.zone_data -- This is already a JSON object
        })
    end

    TriggerClientEvent('otg-saloons:client:zoneEditorInteractions', src, interactions)
end)

-- Save interactions for a saloon
RegisterServerEvent('otg-saloons:server:saveInteractions', function(saloonId, interactions)
    local src = source

    -- First, delete all existing interactions for this saloon
    MySQL.update.await('DELETE FROM otg_saloon_interactions WHERE saloon_id = ?', { saloonId })

    -- Then, insert the new interactions
    for _, interaction in ipairs(interactions) do
        MySQL.insert.await('INSERT INTO otg_saloon_interactions (saloon_id, name, label, event, args, color, zone_type, zone_data) VALUES (?, ?, ?, ?, ?, ?, ?, ?)', {
            interaction.saloon_id,
            interaction.name,
            interaction.label,
            interaction.event,
            interaction.args,
            interaction.color,
            interaction.zone_type,
            interaction.zone_data
        })
    end

    TriggerClientEvent('otg-saloons:client:notify', src, 'Saloon Interactions', 'Interactions saved successfully', 'success', 5000)
end)

-- Get all interactions (for all saloons) - used by the prompt system
RegisterServerEvent('otg-saloons:server:getAllInteractions', function()
    local src = source
    local result = MySQL.query.await('SELECT * FROM otg_saloon_interactions', {})

    local interactions = {}
    for _, row in ipairs(result) do
        table.insert(interactions, {
            id = row.id,
            saloon_id = row.saloon_id,
            name = row.name,
            label = row.label,
            event = row.event,
            args = row.args,
            color = row.color,
            zone_type = row.zone_type,
            zone_data = row.zone_data
        })
    end

    TriggerClientEvent('otg-saloons:client:allInteractions', src, interactions)
end)