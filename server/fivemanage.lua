local function configured()
    return GetConvar('otg_fivemanage_upload_url', '') ~= '' and GetConvar('otg_fivemanage_token', '') ~= ''
end
lib.callback.register('otg-saloon:server:imageProviderStatus', function(source)
    return { fivemanage = configured() }
end)
