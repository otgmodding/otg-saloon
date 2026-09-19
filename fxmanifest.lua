fx_version 'cerulean'

rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

game 'rdr3'

author 'OTG Modding'
description 'OTG Saloon V2 - in-game business creator for RSG Core / RedM'
version '2.6.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'locales/**'
}

client_scripts {
    'client/main.lua',
    'client/creator.lua',
    'client/consumables.lua',
    'client/freight.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/businesses.lua',
    'server/fivemanage.lua',
    'server/consumables.lua',
    'server/crafting.lua',
    'server/shipments.lua'
}

dependencies {
    'rsg-core',
    'ox_lib',
    'oxmysql',
    'ox_target',
    'rsg-inventory'
}

escrow_ignore {
    'install/*',
    'locales/*',
    'shared/*',
    'README.md'
}
