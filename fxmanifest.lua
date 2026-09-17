fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

author 'OTG Modding'
description 'otg-saloons'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/utils.lua',
    'config.lua',
}

client_scripts {
    -- client/*.lua already includes zone_editor.lua, loading it twice made the
    -- file's event handlers register twice.
    'client/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
   'server/*.lua',
}

files {
    'install.sql',
    'data/saloons_data.json',
}

dependencies {
    'rsg-core',
    'rsg-inventory',
    'ox_lib',
    'ox_target',
    'oxmysql',
    'xsound',
    'PolyZone', -- Add PolyZone dependency
}

escrow_ignore {
'config.lua',

}

lua54 'yes'