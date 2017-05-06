# WES
VERA driver for Wes lares security system


Fonctionalites:
- les relais , les entrees digitales, les virtual switchs: vue de l'etat dans vera et changement de l'etat par la UI de vera ou les scenes
- les sondes de temp : vue de l'etat dans vera et utilisation possible dans les scenes comme declencheur
- les entree analogiques,  les pinces amperimetriques, les compteurs a impulsion : vue dans VERA comme des devices de type "urn:micasaverde-com:serviceId:EnergyMetering1" avec les variables Pulse, KWH, Watts comme definis dans la spec UPNP. KWH etant la conso journaliere
- les variables 1-8 sous forme de variable dans le device maitre VERA "WES"

Necessite:
- installer le fichier vera.cgx dans le site web du Wes


Le mapping entre le vera.cgx et les types/variables devices est definie par un tableau base sur des XPATHS donc facilement modifiable/extensible


local xmlmap = {
	["/data/info/firmware/text()"] = { variable="Firmware" , default="" },
	["/data/variables/*"] = { variable="%s" , default="" },
	["/data/*/PAP/text()"] = { variable="Watts" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
	["/data/*/vera/KWHJ/text()"] = { variable="KWH" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
	["/data/*/vera/IHP/text()"] = { variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
	["/data/temp/*/text()"] = { variable="CurrentTemperature" , service="urn:upnp-org:serviceId:TemperatureSensor1", child="SONDE%s" , default=""},
	["/data/temp/vera/NOM%s/text()"] = { attribute="name" ,child="SONDE%s" , default=""},
	["/data/relais/*/text()"] = { variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="rl%s" , default=""},
	["/data/relais/vera/NOM%s/text()"] = { attribute="name" , child="rl%s" , default=""},
	["/data/analogique/*/text()"] = { variable="CurrentLevel" , service="urn:micasaverde-com:serviceId:GenericSensor1", child="ad%s" , default=""},
	["/data/analogique/vera/NOM%s/text()"] = { attribute="name" ,child="ad%s" , default=""},
	["/data/switch_virtuel/*/text()"] = { variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="vs%s" , default=""},
	["/data/switch_virtuel/vera/NOM%s/text()"] = { attribute="name" , child="vs%s" , default=""},
	["/data/entree/*/text()"] = { variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="in%s" , default=""},
	["/data/entree/vera/NOM%s/text()"] = { attribute="name" , child="in%s" , default=""},
	["/data/impulsion/INDEX%s/text()"] = { variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},
	["/data/impulsion/vera/CONSOJ%s/text()"] = { variable="KWH" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},
	["/data/impulsion/vera/NOM%s/text()"] = { attribute="name" , child="pls%s" , default=""},
	["/data/pince/INDEX%s/text()"] = { variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/pince/I%s/text()"] = { variable="Watts" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/pince/vera/NOM%s/text()"] = { attribute="name" , child="pa%s" , default=""},
	["/data/pince/vera/CONSOJ%s/text()"] = { variable="KWH" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/tic%s/vera/caption/text()"] = { attribute="name" , child="tic%s" , default=""},
}