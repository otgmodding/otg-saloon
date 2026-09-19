local RSGCore = exports['rsg-core']:GetCoreObject()
local registered = {}
local function hasEffect(e)
    return e and ((tonumber(e.hunger) or 0)>0 or (tonumber(e.thirst) or 0)>0 or
        (tonumber(e.health) or 0)>0 or (tonumber(e.stamina) or 0)>0 or (tonumber(e.alcohol) or 0)>0)
end
local function registerAll()
    for _,business in pairs(OTG.Businesses or {}) do
        for _,recipe in ipairs(business.recipes or {}) do
            local item=recipe.result_item
            if item and not registered[item] and (recipe.dynamic_item or hasEffect(recipe.effects)) then
                registered[item]=true
                RSGCore.Functions.CreateUseableItem(item,function(source,itemData)
                    local chosen
                    for _,b in pairs(OTG.Businesses or {}) do
                        for _,r in ipairs(b.recipes or {}) do
                            if r.result_item==item then chosen=r break end
                        end
                        if chosen then break end
                    end
                    if not chosen then return end
                    if not hasEffect(chosen.effects) then
                        return OTG.Notify(source, 'This item has no consumable effects configured.', 'error')
                    end
                    local Player=OTG.GetPlayer(source); if not Player then return end
                    if not exports['rsg-inventory']:RemoveItem(source,item,1,itemData and itemData.slot,'otg-saloon:consume') then return end
                    local e=chosen.effects or {}
                    local meta=Player.PlayerData.metadata or {}
                    Player.Functions.SetMetaData('hunger',math.min(100,(tonumber(meta.hunger) or 0)+(tonumber(e.hunger) or 0)))
                    Player.Functions.SetMetaData('thirst',math.min(100,(tonumber(meta.thirst) or 0)+(tonumber(e.thirst) or 0)))
                    TriggerClientEvent('otg-saloon:client:consume',source,e)
                end)
            end
        end
    end
end
AddEventHandler('onResourceStart',function(res) if res==GetCurrentResourceName() then CreateThread(function() Wait(1500); registerAll() end) end end)
AddEventHandler('otg-saloon:server:loaded',registerAll)
