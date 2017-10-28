-- // This program is free software: you can redistribute it and/or modify
-- // it under the condition that it is for private or home useage and
-- // this whole comment is reproduced in the source code file.
-- // Commercial utilisation is not authorized without the appropriate
-- // written agreement from amg0 / alexis . mermet @ gmail . com
-- // This program is distributed in the hope that it will be useful,
-- // but WITHOUT ANY WARRANTY; without even the implied warranty of
-- // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE .
local MSG_CLASS		= "WES"
local WES_SERVICE	= "urn:upnp-org:serviceId:wes1"
local devicetype	= "urn:schemas-upnp-org:device:wes:1"
local this_device	= nil
local DEBUG_MODE	= false -- controlled by UPNP action
local version		= "v0.85"
local UI7_JSON_FILE = "D_WES_UI7.json"
local DEFAULT_REFRESH = 30
local DATACGX_FILE	= "DATA.CGX"
local CGX_FILE		= "vera.cgx"	-- or data.cgx if extensions are not installed
local NAME_PREFIX	= "WES "	-- trailing space needed
local hostname		= ""

local json = require("dkjson")
local mime = require('mime')
local socket = require("socket")
local http = require("socket.http")
local ltn12 = require("ltn12")
local lom = require("lxp.lom") -- http://matthewwild.co.uk/projects/luaexpat/lom.html
local xpath = require("xpath")

local cgx_inserts = {
  ["t </tic1>"]= [[
t <vera>
c e n <caption>%s</caption>
c Ti1 <IHP>%s</IHP>
c Ti2 <IHC>%s</IHC>
c a T <KWHA>%d</KWHA>
c j T <KWHJ>%d</KWHJ>
c a 1 <KWHAHP>%d</KWHAHP>
c a 2 <KWHAHC>%d</KWHAHC>
c a 3 <KWHABHP>%d</KWHABHP>
c a 4 <KWHABHC>%d</KWHABHC>
c a 5 <KWHARHP>%d</KWHARHP>
c a 6 <KWHARHC>%d</KWHARHC>
c m 1 <KWHMHP>%d</KWHMHP>
c m 2 <KWHMHC>%d</KWHMHC>
c m 3 <KWHMBHP>%d</KWHMBHP>
c m 4 <KWHMBHC>%d</KWHMBHC>
c m 5 <KWHMRHP>%d</KWHMRHP>
c m 6 <KWHMRHC>%d</KWHMRHC>
c s 1 <KWHSHP>%d</KWHSHP>
c s 2 <KWHSHC>%d</KWHSHC>
c s 3 <KWHSBHP>%d</KWHSBHP>
c s 4 <KWHSBHC>%d</KWHSBHC>
c s 5 <KWHSRHP>%d</KWHSRHP>
c s 6 <KWHSRHC>%d</KWHSRHC>
c j 1 <KWHJHP>%d</KWHJHP>
c j 2 <KWHJHC>%d</KWHJHC>
c j 3 <KWHJBHP>%d</KWHJBHP>
c j 4 <KWHJBHC>%d</KWHJBHC>
c j 5 <KWHJRHP>%d</KWHJRHP>
c j 6 <KWHJRHC>%d</KWHJRHC>
t </vera>]],
  ["t </tic2>"]= [[
t <vera>
c e N <caption>%s</caption>
c TI1 <IHP>%s</IHP>
c TI2 <IHC>%s</IHC>
c A T <KWHA>%d</KWHA>
c J T <KWHJ>%d</KWHJ>
c A 1 <KWHAHP>%d</KWHAHP>
c A 2 <KWHAHC>%d</KWHAHC>
c A 3 <KWHABHP>%d</KWHABHP>
c A 4 <KWHABHC>%d</KWHABHC>
c A 5 <KWHARHP>%d</KWHARHP>
c A 6 <KWHARHC>%d</KWHARHC>
c m21 <KWHMHP>%d</KWHMHP>
c m22 <KWHMHC>%d</KWHMHC>
c m23 <KWHMBHP>%d</KWHMBHP>
c m24 <KWHMBHC>%d</KWHMBHC>
c m25 <KWHMRHP>%d</KWHMRHP>
c m26 <KWHMRHC>%d</KWHMRHC>
c S 1 <KWHSHP>%d</KWHSHP>
c S 2 <KWHSHC>%d</KWHSHC>
c S 3 <KWHSBHP>%d</KWHSBHP>
c S 4 <KWHSBHC>%d</KWHSBHC>
c S 5 <KWHSRHP>%d</KWHSRHP>
c S 6 <KWHSRHC>%d</KWHSRHC>
c J 1 <KWHJHP>%d</KWHJHP>
c J 2 <KWHJHC>%d</KWHJHC>
c J 3 <KWHJBHP>%d</KWHJBHP>
c J 4 <KWHJBHC>%d</KWHJBHC>
c J 5 <KWHJRHP>%d</KWHJRHP>
c J 6 <KWHJRHC>%d</KWHJRHC>
t </vera>]],
  ["t </impulsion>"]= [[
t <vera>
c pu1 <PULSEPL1>%d</PULSEPL1>
c pCh1 <CONSOV1>%s</CONSOV1>
c pCj1 <CONSOJ1>%s</CONSOJ1>
c pCm1 <CONSOM1>%s</CONSOM1>
c pCa1 <CONSOA1>%s</CONSOA1>
c pn1 <NOM1>%s</NOM1>
t <cpt1>
c pU11<LITRE>%s</LITRE>
c pU12<M3>%s</M3>
c pU13<WH>%s</WH>
c pU14<KWH>%s</KWH>
t </cpt1>
c pu2  <PULSEPL2>%d</PULSEPL2>
c pCh2 <CONSOV2>%s</CONSOV2>
c pCj2 <CONSOJ2>%s</CONSOJ2>
c pCm2 <CONSOM2>%s</CONSOM2>
c pCa2 <CONSOA2>%s</CONSOA2>
c pn2 <NOM2>%s</NOM2>
t <cpt2>
c pU21<LITRE>%s</LITRE>
c pU22<M3>%s</M3>
c pU23<WH>%s</WH>
c pU24<KWH>%s</KWH>
t </cpt2>
c pu3  <PULSEPL3>%d</PULSEPL3>
c pCh3 <CONSOV3>%s</CONSOV3>
c pCj3 <CONSOJ3>%s</CONSOJ3>
c pCm3 <CONSOM3>%s</CONSOM3>
c pCa3 <CONSOA3>%s</CONSOA3>
c pn3 <NOM3>%s</NOM3>
t <cpt3>
c pU31<LITRE>%s</LITRE>
c pU32<M3>%s</M3>
c pU33<WH>%s</WH>
c pU34<KWH>%s</KWH>
t </cpt3>
c pu4  <PULSEPL4>%d</PULSEPL4>
c pCh4 <CONSOV4>%s</CONSOV4>
c pCj4 <CONSOJ4>%s</CONSOJ4>
c pCm4 <CONSOM4>%s</CONSOM4>
c pCa4 <CONSOA4>%s</CONSOA4>
c pn4 <NOM4>%s</NOM4>
t <cpt4>
c pU41<LITRE>%s</LITRE>
c pU42<M3>%s</M3>
c pU43<WH>%s</WH>
c pU44<KWH>%s</KWH>
t </cpt4>
t </vera>]],
["t </pince>"]=[[
t <vera>
c Pn1 <NOM1>%s</NOM1>
c P P1 <VA1>%d</VA1>
c PCj1 <CONSOJ1>%.02f</CONSOJ1>
c PCm1 <CONSOM1>%.02f</CONSOM1>
c PCa1 <CONSOA1>%.02f</CONSOA1>
c Pn2 <NOM2>%s</NOM2>
c P P2 <VA2>%d</VA2>
c PCj2 <CONSOJ2>%.02f</CONSOJ2>
c PCm2 <CONSOM2>%.02f</CONSOM2>
c PCa2 <CONSOA2>%.02f</CONSOA2>
c Pn3 <NOM3>%s</NOM3>
c P P3 <VA3>%d</VA3>
c PCj3 <CONSOJ3>%.02f</CONSOJ3>
c PCm3 <CONSOM3>%.02f</CONSOM3>
c PCa3 <CONSOA3>%.02f</CONSOA3>
c Pn4 <NOM4>%s</NOM4>
c P P4 <VA4>%d</VA4>
c PCj4 <CONSOJ4>%.02f</CONSOJ4>
c PCm4 <CONSOM4>%.02f</CONSOM4>
c PCa4 <CONSOA4>%.02f</CONSOA4>
t </vera>]],
["t </temp>"]=[[
t <vera>
c W0N0 <NOM1>%s</NOM1>
c W0N1 <NOM2>%s</NOM2>
c W0N2 <NOM3>%s</NOM3>
c W0N3 <NOM4>%s</NOM4>
c W0N4 <NOM5>%s</NOM5>
c W0N5 <NOM6>%s</NOM6>
c W0N6 <NOM7>%s</NOM7>
c W0N7 <NOM8>%s</NOM8>
c W0N8 <NOM9>%s</NOM9>
c W0N9 <NOM10>%s</NOM10>
c W1N0 <NOM11>%s</NOM11>
c W1N1 <NOM12>%s</NOM12>
c W1N2 <NOM13>%s</NOM13>
c W1N3 <NOM14>%s</NOM14>
c W1N4 <NOM15>%s</NOM15>
c W1N5 <NOM16>%s</NOM16>
c W1N6 <NOM17>%s</NOM17>
c W1N7 <NOM18>%s</NOM18>
c W1N8 <NOM19>%s</NOM19>
c W1N9 <NOM20>%s</NOM20>
c W2N0 <NOM21>%s</NOM21>
c W2N1 <NOM22>%s</NOM22>
c W2N2 <NOM23>%s</NOM23>
c W2N3 <NOM24>%s</NOM24>
c W2N4 <NOM25>%s</NOM25>
c W2N5 <NOM26>%s</NOM26>
c W2N6 <NOM27>%s</NOM27>
c W2N7 <NOM28>%s</NOM28>
c W2N8 <NOM29>%s</NOM29>
c W2N9 <NOM30>%s</NOM30>
t </vera>]],
["t </relais>"]=[[
t <vera>
c o n0 <NOM1>%s</NOM1>
c o n1 <NOM2>%s</NOM2>
t </vera>]],
["t </entree>"]=[[
t <vera>
c l n1 <NOM1>%s</NOM1>
c l n2 <NOM2>%s</NOM2>
t </vera>]],
["t </analogique>"]=[[
t <vera>
c l a1 <NOM1>%s</NOM1>
c l a2 <NOM2>%s</NOM2>
c l a3 <NOM3>%s</NOM3>
c l a4 <NOM4>%s</NOM4>
t </vera>]],
["t </switch_virtuel>"]=[[
t <vera>
c l N1 <NOM1>%s</NOM1>
c l N2 <NOM2>%s</NOM2>
c l N3 <NOM3>%s</NOM3>
c l N4 <NOM4>%s</NOM4>
c l N5 <NOM5>%s</NOM5>
c l N6 <NOM6>%s</NOM6>
c l N7 <NOM7>%s</NOM7>
c l N8 <NOM8>%s</NOM8>
t </vera>]],
["t </data>"]=[[
t <vera>
c WRn <nCartesRelais1W>%d</nCartesRelais1W>
t <Carte1>
c WR01 <NOM1>%s</NOM1>
c WR02 <NOM2>%s</NOM2>
c WR03 <NOM3>%s</NOM3>
c WR04 <NOM4>%s</NOM4>
c WR05 <NOM5>%s</NOM5>
c WR06 <NOM6>%s</NOM6>
c WR07 <NOM7>%s</NOM7>
c WR08 <NOM8>%s</NOM8>
t </Carte1>
t <Carte2>
c WR11 <NOM1>%s</NOM1>
c WR12 <NOM2>%s</NOM2>
c WR13 <NOM3>%s</NOM3>
c WR14 <NOM4>%s</NOM4>
c WR15 <NOM5>%s</NOM5>
c WR16 <NOM6>%s</NOM6>
c WR17 <NOM7>%s</NOM7>
c WR18 <NOM8>%s</NOM8>
t </Carte2>
t </vera>]]
}

WESfixUnit = function (target_device,value)
	local str =tostring(value)
	if (str:sub(-2)=="m3") then
		str = (tonumber( str:match("%S+") ) * 1000) .. " l"
	end
	return str
end

local xmlmap = {
  ["/data/info/firmware/text()"] =			{ variable="Firmware" , default="" },
  ["/data/variables/*"] =					{ variable="%s" , default="" },
  ["/data/vera/nCartesRelais1W/text()"] =	{ variable="nCartesRelais1W" ,	default="0"},
  ["/data/*/PAP/text()"] =					{ variable="Watts" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
  ["/data/*/vera/KWHJ/text()"] =			{ variable="KWH" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
  ["/data/*/vera/IHP/text()"] =				{ variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
  ["/data/temp/*/text()"] =					{ variable="CurrentTemperature" , service="urn:upnp-org:serviceId:TemperatureSensor1", child="SONDE%s" , default=""},
  ["/data/temp/vera/NOM%s/text()"] =		{ attribute="name" ,child="SONDE%s" , default="" , mask=NAME_PREFIX.."%s"},
  ["/data/relais/*/text()"] =				{ variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="rl%s" , default=""},
  ["/data/relais/vera/NOM%s/text()"] =		{ attribute="name" , child="rl%s" , default="", mask=NAME_PREFIX.."%s"},
  ["/data/analogique/*/text()"] =			{ variable="CurrentLevel" , service="urn:micasaverde-com:serviceId:GenericSensor1", child="ad%s" , default=""},
  ["/data/analogique/vera/NOM%s/text()"] =	{ attribute="name" ,child="ad%s" , default="", mask=NAME_PREFIX.."%s"},
  ["/data/switch_virtuel/*/text()"] =		{ variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="vs%s" , default=""},
  ["/data/switch_virtuel/vera/NOM%s/text()"] = { attribute="name" , child="vs%s" , default="", mask=NAME_PREFIX.."%s"},
  ["/data/entree/*/text()"] =				{ variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="in%s" , default=""},
  ["/data/entree/vera/NOM%s/text()"] =		{ attribute="name" , child="in%s" , default="", mask=NAME_PREFIX.."%s"},
  ["/data/impulsion/PULSE%s/text()"] =		{ variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},
  ["/data/impulsion/vera/PULSEPL%s/text()"] = { variable="PulsePerUnit" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},
  ["/data/impulsion/vera/CONSOV%s/text()"] = { variable="DayBefore,DisplayLine2" , service="urn:micasaverde-com:serviceId:EnergyMetering1,urn:upnp-org:serviceId:altui1", child="pls%s" , func="WESfixUnit", default=""},
  ["/data/impulsion/vera/CONSOJ%s/text()"] = { variable="Daily,DisplayLine1" , service="urn:micasaverde-com:serviceId:EnergyMetering1,urn:upnp-org:serviceId:altui1", child="pls%s" , func="WESfixUnit",  default=""},
  ["/data/impulsion/vera/CONSOM%s/text()"] = { variable="Monthly" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" ,func="WESfixUnit", default=""},
  ["/data/impulsion/vera/CONSOA%s/text()"] = { variable="Yearly" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" ,func="WESfixUnit", default=""},
  ["/data/impulsion/vera/NOM%s/text()"] =	{ attribute="name" , child="pls%s" , default="", mask=NAME_PREFIX.."%s"},
  ["/data/pince/INDEX%s/text()"] =			{ variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
  ["/data/pince/I%s/text()"] =				{ variable="Amps" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
  ["/data/pince/vera/VA%s/text()"] =		{ variable="Watts" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
  ["/data/pince/vera/NOM%s/text()"] =		{ attribute="name" , child="pa%s" , default="", mask=NAME_PREFIX.."%s"},
  ["/data/pince/vera/CONSOJ%s/text()"] =	{ variable="KWH,Daily" , service="urn:micasaverde-com:serviceId:EnergyMetering1,urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
  ["/data/pince/vera/CONSOM%s/text()"] =	{ variable="Monthly" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
  ["/data/pince/vera/CONSOA%s/text()"] =	{ variable="Yearly" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
  ["/data/tic%s/vera/caption/text()"] =		{ attribute="name" , child="tic%s" , default="", mask=NAME_PREFIX.."%s"},
  ["/data/relais1W/*/text()"] =				{ variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="rl1w%s", offset=100, default=""}
}

-- altid is the object ID ( like the relay ID ) on the WES server
local childmap = {
  ["SONDE%s"] = {
	devtype="urn:schemas-micasaverde-com:device:TemperatureSensor:1",
	devfile="D_TemperatureSensor1.xml",
	name="SONDE %s",
	map="TempSensors" -- user choice in a CSV string 1 to 8 ex:	 2,3
  },
  ["ad%s"] = {
	devtype="urn:schemas-micasaverde-com:device:GenericSensor:1",
	devfile="D_GenericSensor1.xml",
	name="ANALOG %s",
	map="AnalogInputs" -- user choice in a CSV string 1 to 8 ex:  2,3
  },
  ["rl%s"] = {
	devtype="urn:schemas-upnp-org:device:BinaryLight:1",
	devfile="D_BinaryLight1.xml",
	name="RELAIS %s",
	map={1,2} -- hard coded dev 1 and 2
  },
  ["rl1w%s"] = {
	devtype="urn:schemas-upnp-org:device:BinaryLight:1",
	devfile="D_BinaryLight1.xml",
	name="RELAIS 1W %s",
	map="Relais1W"	-- user choice in a CSV string 1 to 8 ex:  2,3
  },
  ["in%s"] = {
	devtype="urn:schemas-upnp-org:device:BinaryLight:1",
	devfile="D_BinaryLight1.xml",
	name="ENTREE %s",
	map={1,2} -- hard coded dev 1 and 2
  },
  ["vs%s"] = {
	devtype="urn:schemas-upnp-org:device:BinaryLight:1",
	devfile="D_BinaryLight1.xml",
	name="SWITCH %s",
	map="VirtualSwitches" -- user choice in a CSV string 1 to 8 ex:	 2,3
  },
  ["tic%s"] = {
	devtype="urn:schemas-micasaverde-com:device:PowerMeter:1",
	devfile="D_PowerMeter1.xml",
	name="TIC %s",
	map={1,2} -- hard coded dev 1 and 2
  },
  ["pa%s"] = {
	devtype="urn:schemas-micasaverde-com:device:PowerMeter:1",
	devfile="D_PowerMeter1.xml",
	name="PINCE %s",
	map="AnalogClamps" -- user choice in a CSV string 1 to 8 ex:  2,3
  },
  ["pls%s"] = {
	devtype="urn:schemas-micasaverde-com:device:PowerMeter:1",
	devfile="D_PowerMeter1.xml",
	name="PULSE %s",
	map="PulseCounters" -- user choice in a CSV string 1 to 8 ex:  2,3
  }
}

------------------------------------------------
-- Debug --
------------------------------------------------
function log(text, level)
  luup.log(string.format("%s: %s", MSG_CLASS, text), (level or 50))
end

function debug(text)
  if (DEBUG_MODE) then
	log("debug: " .. text)
  end
end

function warning(stuff)
  log("warning: " .. stuff, 2)
end

function error(stuff)
  log("error: " .. stuff, 1)
end

local function isempty(s)
  return s == nil or s == ""
end

local function extractTagValue(xml)
  local pattern = "<(.*)>(.*)</.*>"
  local resa,resb = string.match( xml, pattern)
  return resa,resb
end

local function findTHISDevice()
  for k,v in pairs(luup.devices) do
	if( v.device_type == devicetype ) then
	  return k
	end
  end
  return -1
end

------------------------------------------------
-- Device Properties Utils
------------------------------------------------
function getSetVariable(serviceId, name, deviceId, default)
  local curValue = luup.variable_get(serviceId, name, deviceId)
  if (curValue == nil) then
	curValue = default
	luup.variable_set(serviceId, name, curValue, deviceId)
  end
  return curValue
end

function getSetVariableIfEmpty(serviceId, name, deviceId, default)
  local curValue = luup.variable_get(serviceId, name, deviceId)
  if (curValue == nil) or (curValue:trim() == "") then
	curValue = default
	luup.variable_set(serviceId, name, curValue, deviceId)
  end
  return curValue
end

function setVariableIfChanged(serviceId, name, value, deviceId)
  debug(string.format("setVariableIfChanged(%s,%s,%s,%s)",serviceId, name, value, deviceId))
  local curValue = luup.variable_get(serviceId, name, tonumber(deviceId)) or ""
  value = value or ""
  if (tostring(curValue)~=tostring(value)) then
	luup.variable_set(serviceId, name, value, tonumber(deviceId))
  end
end

function setAttrIfChanged(name, value, deviceId)
  debug(string.format("setAttrIfChanged(%s,%s,%s)",name, value, deviceId))
  local curValue = luup.attr_get(name, deviceId)
  if ((value ~= curValue) or (curValue == nil)) then
	luup.attr_set(name, value, deviceId)
	return true
  end
  return value
end

local function getIP()
  -- local stdout = io.popen("GetNetworkState.sh ip_wan")
  -- local ip = stdout:read("*a")
  -- stdout:close()
  -- return ip
  local mySocket = socket.udp ()
  mySocket:setpeername ("42.42.42.42", "424242")  -- arbitrary IP/PORT
  local ip = mySocket:getsockname ()
  mySocket: close()
  return ip or "127.0.0.1"
end

------------------------------------------------
-- Tasks
------------------------------------------------
local taskHandle = -1
local TASK_ERROR = 2
local TASK_ERROR_PERM = -2
local TASK_SUCCESS = 4
local TASK_BUSY = 1

--
-- Has to be "non-local" in order for MiOS to call it :(
--
local function task(text, mode)
  if (mode == TASK_ERROR_PERM)
  then
	error(text)
  elseif (mode ~= TASK_SUCCESS)
  then
	warning(text)
  else
	log(text)
  end
  if (mode == TASK_ERROR_PERM)
  then
	taskHandle = luup.task(text, TASK_ERROR, MSG_CLASS, taskHandle)
  else
	taskHandle = luup.task(text, mode, MSG_CLASS, taskHandle)

	-- Clear the previous error, since they're all transient
	if (mode ~= TASK_SUCCESS)
	then
	  luup.call_delay("clearTask", 15, "", false)
	end
  end
end

function clearTask()
  task("Clearing...", TASK_SUCCESS)
end

function UserMessage(text, mode)
  mode = (mode or TASK_ERROR)
  task(text,mode)
end

------------------------------------------------
-- LUA Utils
------------------------------------------------
local function Split(str, delim, maxNb)
  -- Eliminate bad cases...
  if string.find(str, delim) == nil then
	return { str }
  end
  if maxNb == nil or maxNb < 1 then
	maxNb = 0	 -- No limit
  end
  local result = {}
  local pat = "(.-)" .. delim .. "()"
  local nb = 0
  local lastPos
  for part, pos in string.gmatch(str, pat) do
	nb = nb + 1
	result[nb] = part
	lastPos = pos
	if nb == maxNb then break end
  end
  -- Handle the last field
  if nb ~= maxNb then
	result[nb + 1] = string.sub(str, lastPos)
  end
  return result
end

function string:split(sep) -- from http://lua-users.org/wiki/SplitJoin	 : changed as consecutive delimeters was not returning empty strings
  return Split(self, sep)
  -- local sep, fields = sep or ":", {}
  -- local pattern = string.format("([^%s]+)", sep)
  -- self:gsub(pattern, function(c) fields[#fields+1] = c end)
  -- return fields
end


function string:template(variables)
  return (self:gsub('@(.-)@',
	function (key)
	  return tostring(variables[key] or '')
	end))
end

function string:trim()
  return self:match "^%s*(.-)%s*$"
end

------------------------------------------------
-- VERA Device Utils
------------------------------------------------

local function tablelength(T)
  local count = 0
  if (T~=nil) then
  for _ in pairs(T) do count = count + 1 end
  end
  return count
end

local function getParent(lul_device)
  return luup.devices[lul_device].device_num_parent
end

local function getAltID(lul_device)
  return luup.devices[lul_device].id
end

-----------------------------------
-- from a altid, find a child device
-- returns 2 values
-- a) the index === the device ID
-- b) the device itself luup.devices[id]
-----------------------------------
local function findChild( lul_parent, altid )
  -- debug(string.format("findChild(%s,%s)",lul_parent,altid))
  for k,v in pairs(luup.devices) do
	if( getParent(k)==lul_parent) then
	  if( v.id==altid) then
		return k,v
	  end
	end
  end
  return nil,nil
end

local function getParent(lul_device)
  return luup.devices[lul_device].device_num_parent
end

local function getRoot(lul_device)
  while( getParent(lul_device)>0 ) do
	lul_device = getParent(lul_device)
  end
  return lul_device
end
------------------------------------------------
-- Communication TO WES system
------------------------------------------------
-- myHttpGet("192.168.1.31",80,"/vera.cgx",5)
local function myHttpGet(dst_ipaddr,dst_port,uri,timeout,credentials)
  debug( string.format("myHttpGet(%s,%s,%s,%s,%s)",dst_ipaddr,dst_port,uri,timeout,credentials) )
  local a,b,s
  local result = {}
  local command = string.format("GET %s HTTP/1.1\r\n",uri)
  dst_port = dst_port or 80
  timeout = timeout or 5

  local auth = ""
  if (isempty(credentials) == false) then
	auth = "Authorization: Basic ".. credentials .. "\r\n"
  end

  local headers = [[
Host: %s
User-Agent: LuaSocket 3.0-rc1
Accept: */*
TE: trailers
Connection: close, TE
]]
  headers = string.format(headers,dst_ipaddr)
  headers = headers:gsub("\n","\r\n")

  local tcp,b = socket.tcp()
  if (tcp==nil) then
	  error( string.format("Socket tcp creation failed. err:%s",b or ""))
  else
	tcp:settimeout( timeout )
	s,b = tcp:connect (dst_ipaddr, dst_port) -- this should be server IP
	if (s==nil) then
	  error( string.format("Socket connect to %s:%s failed, err:%s",dst_ipaddr,dst_port,b or ""))
	else
	  tcp:settimeout(timeout)
	  a,b  = tcp:send(command..auth..headers)
	  if (a==nil) then
		error( string.format("Socket send failed, err=%s",b or ""))
	  else
		a,b = tcp:receive('*l')
		debug(string.format("Socket received: %s",a or ""))
		-- should be HTTP/1.1 200 OK
		if (a==nil) or (a~="HTTP/1.1 200 OK") then
		  error( string.format("Socket received failed, err=%s",b or ""))
		else
		  -- HEADERS
		  repeat
			a,b,s = tcp:receive('*l')
			if (a~=nil) then
			  debug(string.format("header received: %s",a))
			else
			  debug(string.format("b=%s s=%s",b,s))
			end
		  until #a == 0 -- empty line received

		  -- BODY
		  repeat
			a,b,s = tcp:receive('*l')
			if (a~=nil) then
			  table.insert(result, a)
			elseif (s~=nil) then
			  -- strange but apparently we receive a socket "close" while there is still some data in 's'
			  table.insert(result, s)
			end
		  until b	-- that is, until "timeout" or "closed"

		  tcp:close()
		  return table.concat(result)
		end
	  end
	  tcp:close()
	end
  end
  return nil,b
end

local function WesHttpCall(lul_device,cmd,data)
  lul_device = tonumber(lul_device)
  local lul_root = getRoot(lul_device)
  data = data  or ""
  debug(string.format("WesHttpCall(%d,%s,%s) , root:%s",lul_device,cmd,data,lul_root))

  -- get parameter from root device
  local credentials= getSetVariable(WES_SERVICE,"Credentials", lul_root, "")
  local ip_address = luup.attr_get ('ip', lul_root )

  if (isempty(ip_address)) then
	warning(string.format("IPADDR is not initialized. ipaddr=%s",ip_address))
	return nil
  end
  if (credentials=="") then
	warning("Missing credentials for Wes device :"..lul_device)
	return nil
  end

  local uri = string.format ("/%s?%s", cmd,data)

  local txt,msg = myHttpGet(ip_address,80,uri,5,credentials)

  if (txt==nil) then
	-- failure
	setVariableIfChanged(WES_SERVICE, "IconCode", 0, lul_device)
	debug(string.format("failure=> Error Message:%s",msg or ""))
	return nil
  end
  -- success
  debug(string.format("myHttpGet returns:%s",txt))
  setVariableIfChanged(WES_SERVICE, "IconCode", 100, lul_device)
  return txt
end

------------------------------------------------------------------------------------------------
-- Http handlers : Communication FROM ALTUI
-- http://192.168.1.5:3480/data_request?id=lr_WES_Handler&command=xxx
-- recommended settings in ALTUI: PATH = /data_request?id=lr_WES_Handler&mac=$M&deviceID=114
------------------------------------------------------------------------------------------------
function switch( command, actiontable)
  -- check if it is in the table, otherwise call default
  if ( actiontable[command]~=nil ) then
	return actiontable[command]
  end
  warning("WES_Handler:Unknown command received:"..command.." was called. Default function")
  return actiontable["default"]
end

function myWES_Handler(lul_request, lul_parameters, lul_outputformat)
  debug('myWES_Handler: request is: '..tostring(lul_request))
  debug('myWES_Handler: parameters is: '..json.encode(lul_parameters))
  local lul_html = "";	-- empty return by default
  local mime_type = "";
  if (hostname=="") then
	hostname = getIP()
	debug("now hostname="..hostname)
  end

  -- find a parameter called "command"
  if ( lul_parameters["command"] ~= nil ) then
	command =lul_parameters["command"]
  else
	  debug("WES_Handler:no command specified, taking default")
	command ="default"
  end

  local deviceID = this_device or tonumber(lul_parameters["DeviceNum"] or findTHISDevice() )

  -- switch table
  local action = {

	  ["default"] =
	  function(params)
		return "default handler / not successful", "text/plain"
	  end
  }
  -- actual call
  lul_html , mime_type = switch(command,action)(lul_parameters)
  if (command ~= "home") and (command ~= "oscommand") then
	debug(string.format("lul_html:%s",lul_html or ""))
  end
  return (lul_html or "") , mime_type
end

------------------------------------------------
-- STARTUP Sequence
------------------------------------------------

function prepareWEScgx(lul_device)
  local ftp = require("socket.ftp")
  local userftp= getSetVariable(WES_SERVICE,"UserFTP", lul_device, "adminftp")
  local passwordftp= getSetVariable(WES_SERVICE,"PasswordFTP", lul_device, "wesftp")
  local lul_root = getRoot(lul_device)
  local ip_address = luup.attr_get ('ip', lul_root )
  local data_cgx_tbl = {}
  -- luup.register_handler("myWES_Handler","WES_Handler")
  -- local str = "coucou"

  local f, e = ftp.get({
	host = ip_address,
	sink = ltn12.sink.table(data_cgx_tbl),
	argument = DATACGX_FILE,
	user = userftp,
	password = passwordftp
  })
  debug(string.format("FTP get	file=%s f=%s e=%s",DATACGX_FILE,json.encode(f),json.encode(e)))
  local data_cgx = table.concat(data_cgx_tbl)

  local tmp = string.match(data_cgx,"<firmware>(.+)</firmware>")
  local firmware = string.match(tmp,"0.7")
  local vera_cgx = data_cgx
  for k,v in pairs(cgx_inserts) do
	v = v:gsub("%%","%%%%")
	vera_cgx = vera_cgx:gsub(k,v.."\n"..k)
  end
  
	-- Warning 0.7 firmware requires
	-- c Ti1 <IHP>%09u</IHP>
	-- c Ti2 <IHC>%09u</IHC>
	-- but firmware 0.6 requires
	-- c Ti1 <IHP>%s</IHP>
	-- c Ti2 <IHC>%s</IHC>
  if (firmware=="0.7") then
	debug( string.format("firmware==%s, changing <IHP> and <IHC> type",tmp) )
	vera_cgx = vera_cgx:gsub("<IHP>%%s</IHP>","<IHP>%%09u</IHP>")
	vera_cgx = vera_cgx:gsub("<IHC>%%s</IHC>","<IHC>%%09u</IHC>")
  else
	debug( string.format("firmware==%s",tmp) )
  end
  
  f,e = ftp.put( {
	host = ip_address,
	source = ltn12.source.string(vera_cgx),
	argument = CGX_FILE,
	user = userftp,
	password = passwordftp
  --	port = 21,
  --	type = "a"
  })
  debug(string.format("FTP put file=%s f=%s e=%s",CGX_FILE,json.encode(f),json.encode(e)))
  if (f==nil) then
	error(string.format("Failed to upload %s file, error = %s",CGX_FILE,e))
  end
end

local function prepareXMLmap(lul_device)
  debug(string.format("prepareXMLmap(lul_device:%s)  xmlmap:%s",lul_device,json.encode(xmlmap)))
  local NamePrefix = getSetVariable(WES_SERVICE, "NamePrefix", lul_device, NAME_PREFIX)
  for xp,v in pairs(xmlmap) do
	if (v.mask ~=nil) then
	  v.mask  = v.mask:gsub(NAME_PREFIX,NamePrefix,1)
	end
  end

  -- local v = xmlmap["/data/impulsion/vera/CONSOV%s/text()"]
  -- debug(string.format("v:%s",json.encode(v)))
  
  -- init XML Map
  -- ["/data/vera/Carte1/*/text()"] = { attribute="name", child="rl1w%s", offset=100, default="", mask=NAME_PREFIX.."%s"},
  local nCartesRelais1W = getSetVariable(WES_SERVICE,"nCartesRelais1W", lul_device, 0)
  for i=1,nCartesRelais1W do
	local k = string.format("/data/vera/Carte%d/*/text()",i)
	local v = { attribute="name", child="rl1w%s", offset=100+(i-1)*10, default="", mask=NAME_PREFIX.."%s"}
	xmlmap[k]=v
  end
  debug(string.format("xmlmap initialized to %s",json.encode(xmlmap)))
end

local function createChildren(lul_device)
  debug(string.format("createChildren(%s)",lul_device))

  -- for all children device, iterate
  local child_devices = luup.chdev.start(lul_device);

  -- iterate through type of child
  for kchild,child in pairs(childmap) do
	-- get the map ( csv list of numbers )
	local map={}

	-- child.map is either directly a table, or a name of a variable containng a csv string
	if ( type(child.map) == "table") then
	  map = child.map
	else
	  local csv	 = getSetVariable(WES_SERVICE, child.map, lul_device, "")
	  map = csv:split(",")
	end

	for k,v in pairs(map) do
	  local i = tonumber(v)
	  if (i ~= nil ) then
		luup.chdev.append(
		  lul_device, child_devices,
		  string.format(kchild,i),		-- children map index is altid
		  NAME_PREFIX..string.format(child.name,i),	  -- children map name attribute is device name
		  child.devtype,			-- children device type
		  child.devfile,			-- children devfile
		  "", "",
		  false				  -- not embedded
		  )
	  end
	end
  end

  luup.chdev.sync(lul_device, child_devices)
end

function UserSetPowerTarget(lul_device,newTargetValue)
  lul_device = tonumber(lul_device)
  debug(string.format("UserSetPowerTarget(%s,%s)",lul_device,newTargetValue))
  local status = luup.variable_get("urn:upnp-org:serviceId:SwitchPower1", "Status", lul_device)
  if (status ~= newTargetValue) then
	local val = "ON";
	if (newTargetValue=="0") then
	  val = "OFF";
	end
	-- altid is the relay ID on the WES
	local childid = luup.devices[lul_device].id;
	-- prefix rl1W should be replaced by rl
	childid = string.gsub(childid, "1w", "")
	luup.variable_set("urn:upnp-org:serviceId:SwitchPower1", "Status", newTargetValue, lul_device)
	local xmldata = WesHttpCall(lul_device,"RL.cgx",childid.."="..val)
  else
	debug(string.format("UserSetPowerTarget(%s,%s) - same status, ignoring",lul_device,newTargetValue))
  end
end

function UserToggleState(lul_device)
  debug(string.format("UserToggleState(%s)",lul_device))
  local status = luup.variable_get("urn:upnp-org:serviceId:SwitchPower1", "Status", lul_device)
  status = 1-tonumber(status)
  UserSetPowerTarget(lul_device,tostring(status))
end

function getCurrentTemperature(lul_device)
  lul_device = tonumber(lul_device)
  debug(string.format("getCurrentTemperature(%d)",lul_device))
  return luup.variable_get("urn:upnp-org:serviceId:TemperatureSensor1", "CurrentTemperature", lul_device)
end

local function saveDeviceVariable(target_device, mask, func, variable, service, value )
  service = service or WES_SERVICE
  if (target_device ~= nil ) then
	debug( string.format("service:%s variable:%s value:%s child:%s mask:%s, func:%s",service, variable, value, target_device, mask or "nil", tostring(func~=nil) ))
	if (mask~=nil) then
		value = string.format(mask,value)
	elseif (func~=nil) then
		local ff = _G[func]
		value = (ff)(target_device,value)
	end

	local var_parts = variable:split(",")
	local ser_parts = service:split(",")
	for k,v in pairs(var_parts) do
	  setVariableIfChanged( ser_parts[k] or ser_parts[1], v, value, target_device)
	end
  else
	-- warning( string.format("target_device is null"))
  end
end

local function saveDeviceAttribute(target_device, mask, func, attr, value )
  if (target_device ~= nil ) then
	-- debug( string.format("variable:%s value:%s child:%s", attr, value, target_device) )
	if (mask~=nil) then
	  value = string.format(mask,value)
	elseif (func~=nil) then
	  value = (func)(target_device,value)
	end
	setAttrIfChanged(attr, value, target_device)
  else
	-- warning( string.format("target_device is null"))
  end
end

local function getValueFromXML(xpath_key, n, default_value)
  local value = n or default_value
  if (xpath_key:sub(-1)=="*") then
	value = n[1]
  end

  -- transform ON OFF into 1 0
  if (value=="OFF") then
	value = 0
  elseif (value=="ON") then
	value = 1
  end
  return value
end

local function doload(lul_device, lomtab, xp, child_target, service,  variable, attribute, default_value,mask,func,child_offset)
  debug( string.format("doload xpath:%s child:%s service:%s variable:%s attribute:%s default:%s offset:%s",xp,child_target or "", service or "", variable or "", attribute or "", default_value or "",child_offset) )
  local map_iteration = {1}
  local child_iteration = {}
  if (child_target~=nil) then
	child_iteration = childmap[ child_target ].map
	if ( type(child_iteration) ~= "table") then
	  local csv	 = getSetVariable(WES_SERVICE, child_iteration, lul_device, "")
	  child_iteration = csv:split(",")
	  if (child_iteration[1] == "" ) then -- default value of variable gives "" so it then gives at least an array of one entry with "" in it
		child_iteration={}
	  end
	end
  end
  local singleton = (tablelength(child_iteration)==0)
  local iterative_key = string.match(xp,"%%")
  if (iterative_key) then
	map_iteration = child_iteration
  end

  -- debug( string.format("map iteration will be:%s",json.encode(map_iteration)) )
  local child_nth=1	  -- position in child_iteration array
  for k,idx in pairs(map_iteration) do
	local xpath_key = string.format(xp, idx)
	local nodes = xpath.selectNodes(lomtab,xpath_key)
	debug( string.format("xpath key:%s XML node result %s",xpath_key,json.encode(nodes) ) )
	for i,n in pairs(nodes) do
	  -- XML child element appear as empty string, skip them as we do only key with text() or direct key with /*
	  if (n ~= " ") then

		-- determine target child
		local target_device = lul_device
		if (child_target~=nil) then
		  -- in iterative_key, the idx is the child id
		  -- in normal key mode, the index in XML nodes is the index which is based on offset
		  local child_id = nil
		  if (iterative_key) then
			child_id = idx
		  else
			if (i+child_offset == tonumber(child_iteration[child_nth] )) then
			  child_id = child_iteration[child_nth] or ""
			end
		  end
		  if ( child_id ~= nil ) then
			target_device = findChild( lul_device, string.format(child_target,child_id) )
			child_nth = child_nth +1
		  else
			debug( string.format("child_id not found in target:%s, iterative_key:%s idx:%s i:%s offset:%s child_nth:%s child_iteration:%s",child_target, tostring(iterative_key ~=nil ),idx,i,child_offset,child_nth, json.encode(child_iteration) ) )
			target_device = nil
		  end
		end

		-- determine value to keep
		local value = getValueFromXML( xpath_key, n, default_value )

		-- save value
		if (variable~=nil) then
		  local var_name = variable
		  if (xpath_key:sub(-1)=="*") then
			var_name = string.format(var_name,n.tag)
		  end
		  saveDeviceVariable( target_device, mask, func, var_name, service, value )
		elseif (attribute~=nil) then
		  saveDeviceAttribute( target_device, mask, func, attribute, value )
		end

	  end
	end
  end
end

local function loadWesData(lul_device,xmldata)
  debug(string.format("loadWesData(%s) xml=%s",lul_device,xmldata))
  local lomtab = lom.parse(xmldata)
  for xp,v in pairs(xmlmap) do
	doload(lul_device, lomtab, xp, v.child , v.service, v.variable, v.attribute, v.default, v.mask, v.func, v.offset or 0)
  end

  -- load tic data
  for i,child_name in pairs( {"tic1","tic2"} ) do
	local child_device = findChild( lul_device, child_name )
	if (child_device~=nil) then
	  -- iterate xml
	  local xpath_tmpl = "/data/".. child_name .. "/*"
	  debug(string.format("xpath=%s",xpath_tmpl))
	  local nodes = xpath.selectNodes(lomtab,xpath_tmpl)
	  for idx,xml in pairs(nodes) do
		-- debug(string.format("idx:%s xml:%s",idx,json.encode(xml)))
		-- if it is a simple string
		if (type(xml[1]) == "string") then
		  setVariableIfChanged(WES_SERVICE, xml.tag, xml[1], child_device)
		end
	  end
	end
  end

  return true
end

function refreshEngineCB(lul_device,norefresh)
  norefresh = norefresh or false
  debug(string.format("refreshEngineCB(%s,%s)",lul_device,tostring(norefresh)))
  lul_device = tonumber(lul_device)
  local period= getSetVariable(WES_SERVICE, "RefreshPeriod", lul_device, DEFAULT_REFRESH)

  local xmldata = WesHttpCall(lul_device,CGX_FILE)
  if (xmldata ~= nil) then
	loadWesData(lul_device,xmldata)
  else
	UserMessage(string.format("missing ip addr or credentials or "..CGX_FILE.." file for device "..lul_device),TASK_ERROR_PERM)
  end

  debug(string.format("programming next refreshEngineCB(%s) in %s sec",lul_device,period))
  if (norefresh==false) then
	luup.call_delay("refreshEngineCB",period,tostring(lul_device))
  end
end

------------------------------------------------
-- UPNP actions Sequence
------------------------------------------------
local function setDebugMode(lul_device,newDebugMode)
  lul_device = tonumber(lul_device)
  newDebugMode = tonumber(newDebugMode) or 0
  debug(string.format("setDebugMode(%d,%d)",lul_device,newDebugMode))
  luup.variable_set(WES_SERVICE, "Debug", newDebugMode, lul_device)
  if (newDebugMode==1) then
	DEBUG_MODE=true
  else
	DEBUG_MODE=false
  end
end

local function refreshData(lul_device)
  lul_device = tonumber(lul_device)
  debug(string.format("refreshData(%d)",lul_device))
  refreshEngineCB(lul_device,true)
end

local function startEngine(lul_device)
  debug(string.format("startEngine(%s)",lul_device))
  lul_device = tonumber(lul_device)

  local xmldata = WesHttpCall(lul_device,CGX_FILE)
  -- local xmldata = WesHttpCall(lul_device,"xml/zones/zonesDescription16IP.xml")
  if (xmldata ~= nil) then
	local period= getSetVariable(WES_SERVICE, "RefreshPeriod", lul_device, DEFAULT_REFRESH)
	luup.call_delay("refreshEngineCB",period,tostring(lul_device))
	return loadWesData(lul_device,xmldata)
  else
	UserMessage(string.format("missing ip addr or credentials or "..CGX_FILE.." file for device "..lul_device),TASK_ERROR_PERM)
  end
  return true
end

function startupDeferred(lul_device)
  lul_device = tonumber(lul_device)
  log("startupDeferred, called on behalf of device:"..lul_device)

  local debugmode = getSetVariable(WES_SERVICE, "Debug", lul_device, "0")
  local oldversion = getSetVariable(WES_SERVICE, "Version", lul_device, "")
  local period= getSetVariable(WES_SERVICE, "RefreshPeriod", lul_device, DEFAULT_REFRESH)
  local credentials	 = getSetVariable(WES_SERVICE, "Credentials", lul_device, "")
  local tempsensors	 = getSetVariable(WES_SERVICE, "TempSensors", lul_device, "")
  local AnalogInputs  = getSetVariable(WES_SERVICE, "AnalogInputs", lul_device, "")
  local Relais1W  = getSetVariable(WES_SERVICE, "Relais1W", lul_device, "")
  local VirtualSwitches	 = getSetVariable(WES_SERVICE, "VirtualSwitches", lul_device, "")
  local PulseCounters  = getSetVariable(WES_SERVICE, "PulseCounters", lul_device, "")
  local AnalogClamps = getSetVariable(WES_SERVICE, "AnalogClamps", lul_device, "")
  local NamePrefix = getSetVariable(WES_SERVICE, "NamePrefix", lul_device, NAME_PREFIX)
  local iconCode = getSetVariable(WES_SERVICE,"IconCode", lul_device, "0")
  local userftp= getSetVariable(WES_SERVICE,"UserFTP", lul_device, "adminftp")
  local passwordftp= getSetVariable(WES_SERVICE,"PasswordFTP", lul_device, "wesftp")
  -- local ipaddr = luup.attr_get ('ip', lul_device )

  if (debugmode=="1") then
	DEBUG_MODE = true
	UserMessage("Enabling debug mode for device:"..lul_device,TASK_BUSY)
  end
  local major,minor = 0,0
  local tbl={}

  if (oldversion~=nil) then
	if (oldversion ~= "") then
	  major,minor = string.match(oldversion,"v(%d+)%.(%d+)")
	  major,minor = tonumber(major),tonumber(minor)
	  debug ("Plugin version: "..version.." Device's Version is major:"..major.." minor:"..minor)

	  newmajor,newminor = string.match(version,"v(%d+)%.(%d+)")
	  newmajor,newminor = tonumber(newmajor),tonumber(newminor)
	  debug ("Device's New Version is major:"..newmajor.." minor:"..newminor)

	  -- force the default in case of upgrade
	  if ( (newmajor>major) or ( (newmajor==major) and (newminor>minor) ) ) then
		log ("Version upgrade => Reseting Plugin config to default and FTP uploading the *.CGX file on the WES server")
		prepareWEScgx(lul_device)
	  end
	else
	  log ("New installation =>	 FTP uploading the *.CGX file on the WES server")
	  prepareWEScgx(lul_device)
	end
	luup.variable_set(WES_SERVICE, "Version", version, lul_device)
  end

  -- start handlers
  createChildren(lul_device)
  prepareXMLmap(lul_device)

  -- start engine
  local success = false
  success = startEngine(lul_device)

  -- NOTHING to start
  if( luup.version_branch == 1 and luup.version_major == 7) then
	if (success == true) then
	  luup.set_failure(0,lul_device)  -- should be 0 in UI7
	else
	  luup.set_failure(1,lul_device)  -- should be 0 in UI7
	end
  else
	luup.set_failure(false,lul_device)	-- should be 0 in UI7
  end

  log("startup completed")
end

------------------------------------------------
-- Check UI7
------------------------------------------------
local function checkVersion(lul_device)
  local ui7Check = luup.variable_get(WES_SERVICE, "UI7Check", lul_device) or ""
  if ui7Check == "" then
	luup.variable_set(WES_SERVICE, "UI7Check", "false", lul_device)
	ui7Check = "false"
  end
  if( luup.version_branch == 1 and luup.version_major == 7 and ui7Check == "false") then
	luup.variable_set(WES_SERVICE, "UI7Check", "true", lul_device)
	luup.attr_set("device_json", UI7_JSON_FILE, lul_device)
	luup.reload()
  end
end

function initstatus(lul_device)
  lul_device = tonumber(lul_device)
  this_device = lul_device
  log("initstatus("..lul_device..") starting version: "..version)
  checkVersion(lul_device)
  hostname = getIP()
  local delay = 1	-- delaying first refresh by x seconds
  debug("initstatus("..lul_device..") startup for Root device, delay:"..delay)
  luup.call_delay("startupDeferred", delay, tostring(lul_device))
end

-- do not delete, last line must be a CR according to MCV wiki page
