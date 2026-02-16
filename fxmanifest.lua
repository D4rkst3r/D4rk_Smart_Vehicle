fx_version 'cerulean'
game 'gta5'

author 'D4rk'
description 'D4rk Smart Vehicle System - Advanced Vehicle Control with NUI'
version '2.0.0'

lua54 'yes'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua',
    'client/controls.lua',
    'client/cage.lua',
    'client/water.lua',
    'client/collision.lua',
    'client/props.lua',
    'client/spotlight.lua',
    'client/spinning.lua',
    'client/doors.lua'
}

server_scripts {
    'server/main.lua',
    'server/sync.lua',
    'server/hybrid.lua'
}

ui_page 'nui/html/index.html'

files {
    'nui/html/index.html',
    'nui/css/style.css',
    'nui/js/script.js',
    'nui/js/jquery.min.js',
    'nui/img/*.png'
}
