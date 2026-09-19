local Businesses = {}
local creatorOpen = false
local placing = false
local previewProp = nil
local placement = nil
local blipDraft = nil
local nuiReady = false
local pendingOpen = nil

local function refresh()
    Businesses = lib.callback.await('otg-saloon:server:getBusinesses', false) or {}
end

local function businessesForNui(source)
    local out = {}
    for id, business in pairs(source or {}) do
        if type(business) == 'table' then
            out[tostring(id)] = business
        end
    end
    return out
end

local function sendOpen(selected)
    blipDraft = nil
    refresh()

    -- Never trap the player in NUI focus unless the browser page and JS have
    -- successfully booted and called uiReady.
    if not nuiReady then
        pendingOpen = selected or false
        return
    end

    SendNUIMessage({ action='open', businesses=businessesForNui(Businesses), selected=selected })
    Wait(50)
    SetNuiFocus(true, true)
    creatorOpen = true
end

local function reopen(selected)
    Wait(450)
    sendOpen(selected)
end

RegisterNetEvent('otg-saloon:client:openCreator', function()
    sendOpen(nil)
end)

RegisterNUICallback('uiReady', function(_, cb)
    nuiReady = true
    cb({ok=true})

    if pendingOpen ~= nil then
        local selected = pendingOpen ~= false and pendingOpen or nil
        pendingOpen = nil
        CreateThread(function()
            Wait(50)
            sendOpen(selected)
        end)
    end
end)

RegisterNUICallback('closeCreator', function(_, cb)
    SetNuiFocus(false, false); creatorOpen=false; cb({ok=true})
end)

RegisterNUICallback('useCurrentBlip', function(data, cb)
    local c=GetEntityCoords(cache.ped)
    blipDraft={x=c.x,y=c.y,z=c.z}
    local businessId=tonumber(data and data.businessId)
    if businessId then
        local ok,message=lib.callback.await('otg-saloon:server:setBusinessBlip',false,businessId,blipDraft)
        if not ok then return cb({ok=false,message=message}) end
        blipDraft=nil
    end
    cb({ok=true,x=c.x,y=c.y,z=c.z,message=businessId and 'Blip position saved.' or 'Blip position captured.'})
end)

RegisterNUICallback('createBusiness', function(data, cb)
    local c=blipDraft or GetEntityCoords(cache.ped)
    data.blipX,data.blipY,data.blipZ=c.x,c.y,c.z
    TriggerServerEvent('otg-saloon:server:createBusiness', data)
    cb({ok=true})
    CreateThread(function() Wait(700); SendNUIMessage({action='refresh',businesses=businessesForNui(lib.callback.await('otg-saloon:server:getBusinesses',false) or {})}) end)
end)

RegisterNUICallback('saveBusiness', function(data, cb)
    if blipDraft then data.blipX,data.blipY,data.blipZ=blipDraft.x,blipDraft.y,blipDraft.z end
    local ok,message=lib.callback.await('otg-saloon:server:updateBusiness',false,data)
    cb({ok=ok==true,message=message})
    if ok then CreateThread(function() Wait(250); SendNUIMessage({action='refresh',businesses=businessesForNui(lib.callback.await('otg-saloon:server:getBusinesses',false) or {})}) end) end
end)

local function parseIngredients(text)
    local out={}
    for pair in tostring(text or ''):gmatch('[^,]+') do
        local item,amount=pair:match('^%s*([%w_%-]+)%s*:%s*(%d+)%s*$')
        if item and amount then out[#out+1]={item=item,amount=tonumber(amount)} end
    end
    return out
end

RegisterNUICallback('requestRefresh', function(_, cb)
    refresh()
    SendNUIMessage({ action='refresh', businesses=businessesForNui(Businesses) })
    cb({ok=true})
end)

RegisterNUICallback('deleteBusiness', function(data, cb)
    TriggerServerEvent('otg-saloon:server:deleteBusiness', tonumber(data.businessId))
    cb({ok=true})
end)

RegisterNUICallback('updateRecipe', function(data, cb)
    local ok,message=lib.callback.await('otg-saloon:server:updateRecipe',false,data)
    cb({ok=ok==true,message=message})
end)

RegisterNUICallback('createRecipe', function(data, cb)
    local ok,message=lib.callback.await('otg-saloon:server:createRecipe',false,data)
    cb({ok=ok==true,message=message})
    if ok then CreateThread(function() Wait(250); SendNUIMessage({action='refresh',businesses=businessesForNui(lib.callback.await('otg-saloon:server:getBusinesses',false) or {})}) end) end
end)
RegisterNUICallback('deleteRecipe', function(data,cb) TriggerServerEvent('otg-saloon:server:deleteRecipe',data.recipeId); cb({ok=true}) end)
RegisterNUICallback('deleteStation', function(data,cb) TriggerServerEvent('otg-saloon:server:deleteStation',data.stationId); cb({ok=true}) end)

local function loadModel(model)
    if not model or model=='' then return nil end
    local hash=joaat(model)
    if not IsModelValid(hash) then return nil end
    RequestModel(hash); local timeout=GetGameTimer()+5000
    while not HasModelLoaded(hash) and GetGameTimer()<timeout do Wait(0) end
    return HasModelLoaded(hash) and hash or nil
end

local function cleanup()
    if previewProp and DoesEntityExist(previewProp) then DeleteObject(previewProp) end
    previewProp=nil
end

-- Key mappings are Cfx mappings supported by RedM. They avoid GTA-specific control hashes.
local keys={forward=false,back=false,left=false,right=false,up=false,down=false,rotl=false,rotr=false,fine=false}
local function bind(name,desc,key,field)
    RegisterCommand('+otg_'..name,function() if placing then keys[field]=true end end,false)
    RegisterCommand('-otg_'..name,function() keys[field]=false end,false)
    RegisterKeyMapping('+otg_'..name,'OTG Saloon: '..desc,'keyboard',key)
end
bind('place_forward','Move prop forward','UP','forward')
bind('place_back','Move prop backward','DOWN','back')
bind('place_left','Move prop left','LEFT','left')
bind('place_right','Move prop right','RIGHT','right')
bind('place_up','Raise prop','PAGEUP','up')
bind('place_down','Lower prop','PAGEDOWN','down')
bind('place_rotl','Rotate prop left','Q','rotl')
bind('place_rotr','Rotate prop right','E','rotr')
bind('place_fine','Precision movement','LSHIFT','fine')

local function drawZonePreview(p)
    local z=p.zone
    local targetZ=z.z+((Config.TargetHeight or 2.0)*0.5)
    if p.shape=='box' then
        Citizen.InvokeNative(0x2A32FAA57B937173,0x6EB7D3BB,z.x,z.y,targetZ,0.0,0.0,0.0,0.0,0.0,z.h,
            p.length,p.width,Config.TargetHeight or 2.0,190,145,70,110,false,false,2,false,nil,nil,false)
    else
        local d=math.max(p.radius,Config.MinimumTargetRadius or 1.5)*2.0
        Citizen.InvokeNative(0x2A32FAA57B937173,0x50638AB9,z.x,z.y,targetZ,0.0,0.0,0.0,0.0,0.0,0.0,
            d,d,d,190,145,70,95,false,false,2,false,nil,nil,false)
    end
end

local function placementHelp()
    if not placement then return end
    if placement.stage=='prop' then
        lib.showTextUI('PROP: ARROWS Move | PgUp/PgDn Height | Q/E Rotate | ENTER Next: Zone | Backspace Cancel',{icon='cube'})
    else
        local size=placement.shape=='box' and ('%.1f x %.1f'):format(placement.length,placement.width) or ('Radius %.1f'):format(placement.radius)
        lib.showTextUI(('ZONE (%s): ARROWS Move | PgUp/PgDn Height | Q/E Rotate | Wheel or [ / ] Size (0.25m) | ENTER Save | Backspace Cancel'):format(size),{icon='draw-polygon'})
    end
end

local function finishPlacement(confirm)
    if not placing then return end
    if confirm and placement and placement.stage=='prop' then
        placement.stage='zone'
        placementHelp()
        return
    end
    placing=false
    OTGSaloonCreatorPlacing=false
    lib.hideTextUI()
    if confirm and placement then
        local p=placement
        local saved, message = lib.callback.await('otg-saloon:server:saveStation', false, {
            stationId=p.stationId,businessId=p.businessId,type=p.type,label=p.label,minGrade=p.minGrade,
            prop=p.prop,shape=p.shape,radius=p.radius,length=p.length,width=p.width,
            x=p.zone.x,y=p.zone.y,z=p.zone.z,heading=p.zone.h,
            propX=p.propPos.x,propY=p.propPos.y,propZ=p.propPos.z,propHeading=p.propPos.h
        })
        lib.notify({description=message or (saved and 'Station saved.' or 'Station could not be saved.'),type=saved and 'success' or 'error'})
    end
    local selected=placement and tostring(placement.businessId) or nil
    cleanup(); placement=nil
    CreateThread(function() reopen(selected) end)
end

RegisterCommand('otg_place_confirm',function() finishPlacement(true) end,false)
RegisterKeyMapping('otg_place_confirm','OTG Saloon: Confirm / next placement stage','keyboard','RETURN')
RegisterCommand('otg_place_cancel',function() finishPlacement(false) end,false)
RegisterKeyMapping('otg_place_cancel','OTG Saloon: Cancel placement','keyboard','BACK')

local function resizeZone(direction)
    if not placing or not placement or placement.stage~='zone' then return end
    local amount=(Config.ZoneResizeStep or .25)*direction
    if placement.shape=='box' then
        placement.length=math.max(.25,math.min(30.0,placement.length+amount))
        placement.width=math.max(.25,math.min(30.0,placement.width+amount))
    else
        placement.radius=math.max(.25,math.min(15.0,placement.radius+amount))
    end
    placementHelp()
end
RegisterCommand('otg_zone_grow',function() resizeZone(1) end,false)
RegisterCommand('otg_zone_shrink',function() resizeZone(-1) end,false)
RegisterCommand('otg_zone_grow_wheel',function() resizeZone(1) end,false)
RegisterCommand('otg_zone_shrink_wheel',function() resizeZone(-1) end,false)
RegisterKeyMapping('otg_zone_grow','OTG Saloon: Increase zone size','keyboard',']')
RegisterKeyMapping('otg_zone_shrink','OTG Saloon: Decrease zone size','keyboard','[')
RegisterKeyMapping('otg_zone_grow_wheel','OTG Saloon: Increase zone size (wheel)','MOUSE_WHEEL','IOM_WHEEL_UP')
RegisterKeyMapping('otg_zone_shrink_wheel','OTG Saloon: Decrease zone size (wheel)','MOUSE_WHEEL','IOM_WHEEL_DOWN')

local function startPlacement(data)
    if placing then return end
    local ped=cache.ped
    local pc=GetEntityCoords(ped)
    local h=GetEntityHeading(ped)
    local hash=loadModel(data.prop)
    local hasProp=hash~=nil
    placement={
        businessId=tonumber(data.businessId),stationId=tonumber(data.stationId),type=data.type,label=data.label,
        minGrade=tonumber(data.minGrade) or 0,prop=data.prop or '',shape=data.shape=='box' and 'box' or 'sphere',
        radius=math.max(.25,tonumber(data.radius) or Config.DefaultStationRadius),
        length=math.max(.25,tonumber(data.length) or 1.5),
        width=math.max(.25,tonumber(data.width) or 1.5),
        propPos={x=pc.x,y=pc.y,z=pc.z,h=h},
        zone={x=pc.x,y=pc.y,z=pc.z,h=h},
        stage=hasProp and 'prop' or 'zone'
    }
    if hasProp then
        previewProp=CreateObject(hash,pc.x,pc.y,pc.z,false,false,false)
        SetEntityAlpha(previewProp,190,false)
        SetEntityCollision(previewProp,false,false)
        FreezeEntityPosition(previewProp,true)
    end
    placing=true
    OTGSaloonCreatorPlacing=true
    placementHelp()
    CreateThread(function()
        while placing and placement do
            local step=keys.fine and (Config.Placement.fineStep or .01) or (Config.Placement.moveStep or .05)
            local p=placement.stage=='prop' and placement.propPos or placement.zone
            local rad=math.rad(p.h)
            if keys.forward then p.x=p.x-math.sin(rad)*step;p.y=p.y+math.cos(rad)*step end
            if keys.back then p.x=p.x+math.sin(rad)*step;p.y=p.y-math.cos(rad)*step end
            if keys.left then p.x=p.x-math.cos(rad)*step;p.y=p.y-math.sin(rad)*step end
            if keys.right then p.x=p.x+math.cos(rad)*step;p.y=p.y+math.sin(rad)*step end
            if keys.up then p.z=p.z+(Config.Placement.verticalStep or .025) end
            if keys.down then p.z=p.z-(Config.Placement.verticalStep or .025) end
            if keys.rotl then p.h=p.h-(Config.Placement.rotateStep or 2.5) end
            if keys.rotr then p.h=p.h+(Config.Placement.rotateStep or 2.5) end

            if placement.stage=='prop' then
                if previewProp and DoesEntityExist(previewProp) then
                    SetEntityCoords(previewProp,p.x,p.y,p.z,false,false,false,false)
                    SetEntityHeading(previewProp,p.h)
                end
            else
                drawZonePreview(placement)
            end
            Wait(0)
        end
    end)
end


RegisterNUICallback('imageProviderStatus',function(_,cb)
    cb(lib.callback.await('otg-saloon:server:imageProviderStatus',false) or {})
end)

RegisterNUICallback('getCreatorItems', function(data, cb)
    cb(lib.callback.await('otg-saloon:server:getCreatorItems', false, tonumber(data.businessId)) or {})
end)


RegisterNUICallback('getBlipCatalog', function(_, cb)
    cb(lib.callback.await('otg-saloon:server:getBlipCatalog', false) or {})
end)

RegisterNUICallback('searchPropCatalog', function(data, cb)
    cb(lib.callback.await('otg-saloon:server:searchPropCatalog', false, tostring(data.query or '')) or {})
end)

RegisterNUICallback('previewProp', function(data, cb)
    local model=tostring(data.model or '')
    local hash=loadModel(model)
    if not hash then cb({ok=false}); return end
    SetNuiFocus(false,false)
    SendNUIMessage({action='previewMode',show=true,model=model})
    local ped=cache.ped
    local pc=GetEntityCoords(ped)
    local forward=GetEntityForwardVector(ped)
    local x,y,z=pc.x+forward.x*2.0,pc.y+forward.y*2.0,pc.z
    local obj=CreateObject(hash,x,y,z,false,false,false)
    if obj and obj~=0 then
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj,true)
        SetEntityAlpha(obj,220,false)
    end
    lib.showTextUI('PROP PREVIEW: '..model..' | ENTER Return',{icon='eye'})
    CreateThread(function()
        local untilTime=GetGameTimer()+15000
        while GetGameTimer()<untilTime do
            if IsControlJustReleased(0,0xC7B5340A) then break end -- INPUT_FRONTEND_ACCEPT
            Wait(0)
        end
        lib.hideTextUI()
        if obj and DoesEntityExist(obj) then DeleteObject(obj) end
        SetModelAsNoLongerNeeded(hash)
        SendNUIMessage({action='previewMode',show=false})
        SetNuiFocus(true,true)
    end)
    cb({ok=true})
end)

RegisterNUICallback('getPropCatalog', function(_, cb)
    cb(lib.callback.await('otg-saloon:server:getPropCatalog', false) or {})
end)

RegisterNUICallback('validateProp', function(data, cb)
    local model = tostring(data.model or '')
    local hash = loadModel(model)
    cb({ ok = hash ~= nil, model = model })
    if hash then SetModelAsNoLongerNeeded(hash) end
end)

RegisterNetEvent('otg-saloon:client:openRecipeManager', function(businessId)
    refresh()
    local b = Businesses[tonumber(businessId)] or Businesses[tostring(businessId)]
    if not b then return lib.notify({description='Business is not available.',type='error'}) end
    if not nuiReady then pendingOpen = tostring(businessId); return end
    SendNUIMessage({action='openRecipeManager',businesses=businessesForNui(Businesses),selected=tostring(businessId)})
    Wait(50); SetNuiFocus(true,true); creatorOpen=true
end)

RegisterNUICallback('placeStation',function(data,cb)
    SetNuiFocus(false,false);creatorOpen=false;cb({ok=true});startPlacement(data)
end)

AddEventHandler('onResourceStop',function(resource)
    if resource~=GetCurrentResourceName() then return end
    OTGSaloonCreatorPlacing=false
    SetNuiFocus(false,false);cleanup();lib.hideTextUI()
end)
