---- GITHUB: https://github.com/xultrascripts

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'xScripts'
description 'Rent A Car'
version '2.11.0'

shared_scripts {
    '@ox_lib/init.lua',
    'locales.lua',
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/*.png'
}

dependencies {
    'ox_target',
    'ox_lib',
    'es_extended'
}
