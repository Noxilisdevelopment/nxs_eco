fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'NXS'
description 'Système de gestion et surveillance économique du serveur'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}

dependencies {
    'es_extended',
    'oxmysql'
}
