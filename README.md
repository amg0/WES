# WES
VERA driver for Wes v2 serveur from cartelectronic.fr
https://www.cartelectronic.fr/index.php?id_cms=8&controller=cms
plugin sur le MCV store : http://apps.mios.com/plugin.php?id=8906

## Install instructions

https://github.com/amg0/WES/blob/master/Docs/Documentation%20Installation%20WES.pdf

NOTE for openluup users: it requires the LUA EXPAT library from  https://matthewwild.co.uk/projects/luaexpat/lom.html
on a rapsberry PI you can install it by :  sudo apt-get install lua_expat

## Fonctionalites: V0.90

- support for openLuup
- les relais , les entrees digitales, les virtual switchs, les relais 1Wire: vue de l'etat dans vera et changement de l'etat par la UI de vera ou les scenes
- les sondes de temp : vue de l'etat dans vera et utilisation possible dans les scenes comme declencheur
- les entree analogiques,  les pinces amperimetriques, les compteurs a impulsion : vue dans VERA comme des devices de type "urn:micasaverde-com:serviceId:EnergyMetering1" avec les variables Pulse, KWH, Watts comme definis dans la spec UPNP. KWH etant la conso journaliere
- les variables 1-8 sous forme de variable dans le device maitre VERA "WES"
- icone contextuelle ( verte route selon l'etat de la connection ). 
- possibilite de programmer une scene sur l'etat de la connection vers le WES ( variable IconCode 0 ou 100 )
- ecran de parametrisation assisté ( controle des champs par des regexp )
- possibilite de choisir un prefix ( ou nom ) pour les peripheriques "enfants" du WES ( variable NamePrefix)
- UPNP Actions: forcer un refresh,  uploader le fichier .cgx par ftp

### Necessite:

- le fichier vera.cgx dans le site web du Wes
- l'installation de ce fichier au sein du serveur WES est automatique par le plugin VERA  (FTP)
- Firmware version of the WES server must be >= V 0.83


Le mapping entre le vera.cgx et les types/variables devices est definie par un tableau base sur des XPATHS donc facilement modifiable/extensible


local xmlmap = {
	["/data/info/firmware/text()"] = 					{ variable="Firmware" , default="" },
	["/data/variables/*"] = 								{ variable="%s" , default="" },
	["/data/vera/nCartesRelais1W/text()"] = 	{ variable="nCartesRelais1W" ,  default="0"},
	["/data/*/PAP/text()"] = 								{ variable="Watts" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
	["/data/*/vera/KWHJ/text()"] = 					{ variable="KWH" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
	["/data/*/vera/IHP/text()"] = 						{ variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
	["/data/temp/*/text()"] = 							{ variable="CurrentTemperature" , service="urn:upnp-org:serviceId:TemperatureSensor1", child="SONDE%s" , default=""},
	["/data/temp/vera/NOM%s/text()"] = 			{ attribute="name" ,child="SONDE%s" , default="" , mask=NAME_PREFIX.."%s"},
	["/data/relais/*/text()"] = 							{ variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="rl%s" , default=""},
	["/data/relais/vera/NOM%s/text()"] = 		{ attribute="name" , child="rl%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/analogique/*/text()"] = 					{ variable="CurrentLevel" , service="urn:micasaverde-com:serviceId:GenericSensor1", child="ad%s" , default=""},
	["/data/analogique/vera/NOM%s/text()"] = { attribute="name" ,child="ad%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/switch_virtuel/*/text()"] = 				{ variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="vs%s" , default=""},
	["/data/switch_virtuel/vera/NOM%s/text()"] = { attribute="name" , child="vs%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/entree/*/text()"] = 							{ variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="in%s" , default=""},
	["/data/entree/vera/NOM%s/text()"] = 		{ attribute="name" , child="in%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/impulsion/PULSE%s/text()"] = 		{ variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},
	["/data/impulsion/vera/PULSEPL%s/text()"] = { variable="PulsePerUnit" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},
	["/data/impulsion/vera/CONSOV%s/text()"] = { variable="DayBefore,DisplayLine2" , service="urn:micasaverde-com:serviceId:EnergyMetering1,urn:upnp-org:serviceId:altui1", child="pls%s" , default=""},
	["/data/impulsion/vera/CONSOJ%s/text()"] = { variable="Daily,DisplayLine1" , service="urn:micasaverde-com:serviceId:EnergyMetering1,urn:upnp-org:serviceId:altui1", child="pls%s" , default=""},
	["/data/impulsion/vera/CONSOM%s/text()"] = { variable="Monthly" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},
	["/data/impulsion/vera/CONSOA%s/text()"] = { variable="Yearly" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},
	["/data/impulsion/vera/NOM%s/text()"] = 	{ attribute="name" , child="pls%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/pince/INDEX%s/text()"] = 			{ variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/pince/I%s/text()"] = 				{ variable="Amps" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/pince/vera/VA%s/text()"] = 		{ variable="Watts" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/pince/vera/NOM%s/text()"] = 		{ attribute="name" , child="pa%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/pince/vera/CONSOJ%s/text()"] = 	{ variable="KWH,Daily" , service="urn:micasaverde-com:serviceId:EnergyMetering1,urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/pince/vera/CONSOM%s/text()"] = 	{ variable="Monthly" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/pince/vera/CONSOA%s/text()"] = 	{ variable="Yearly" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/tic%s/vera/caption/text()"] = 			{ attribute="name" , child="tic%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/relais1W/*/text()"] = 						{ variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="rl1w%s", offset=100, default=""},
}
