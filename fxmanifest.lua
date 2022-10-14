fx_version 'cerulean'
game 'gta5'
lua54 'yes'
shared_scripts {
	'config.lua',
    '@ox_lib/init.lua'
}

client_scripts {
    'client/apartment.lua',
}

server_script {
    '@oxmysql/lib/MySQL.lua',
    'server/apartment.lua'
}
