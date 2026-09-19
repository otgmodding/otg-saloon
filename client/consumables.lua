RegisterNetEvent('otg-saloon:client:consume',function(e)
    e=type(e)=='table' and e or {}
    local duration=math.max(0,math.min(tonumber(e.duration) or 0,120000))
    if duration>0 then lib.progressBar({duration=duration,label='Consuming...',canCancel=false,disable={combat=true}}) end
    local ped=PlayerPedId()
    local hp=math.max(0,math.min(tonumber(e.health) or 0,50))
    if hp>0 then SetEntityHealth(ped,math.min(GetEntityMaxHealth(ped),GetEntityHealth(ped)+hp)) end
    local stamina=math.max(0,math.min(tonumber(e.stamina) or 0,50))
    if stamina>0 then RestorePlayerStamina(PlayerId(),math.min(1.0,stamina/100.0)) end
    -- Alcohol value is retained for a verified RedM drunk-effect adapter; no GTA-only native is used.
end)
