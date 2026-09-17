-- Handle fetching owned saloons from server
RegisterNetEvent('otg-saloons:client:zoneEditorOwnedSaloons', function(saloons)
    local options = {}

    for _, saloon in ipairs(saloons) do
        local saloonId = saloon.id
        local label = saloonId -- Default to id if not found in config
        -- Look up the label in Config.Saloons
        for _, s in pairs(Config.Saloons) do
            if s.id == saloonId then
                label = s.label
                break
            end
        end

        options[#options + 1] = {
            title = label,
            icon = 'fa-solid fa-building',
            description = 'ID: ' .. saloonId,
            onSelect = function()
                currentSaloonId = saloonId
                fetchInteractions(saloonId)
                openZoneEditorMenu()
            end
        }
    end

    if #options == 0 then
        options[#options + 1] = {
            title = 'No Owned Saloons',
            icon = 'fa-solid fa-info-circle',
            description = 'You do not own any saloons yet.',
            disabled = true
        }
    end

    options[#options + 1] = {
        title = 'Back',
        icon = 'fa-solid fa-arrow-left',
        description = 'Return to the main menu',
        onSelect = function()
            openZoneEditorMenu()
        }
    }

    lib.registerContext({
        id = 'otg_saloon_zone_editor_saloon_select',
        title = 'Select Saloon',
        options = options,
    })
    lib.showContext('otg_saloon_zone_editor_saloon_select')
end)