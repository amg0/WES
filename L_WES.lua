-- // This program is free software: you can redistribute it and/or modify
-- // it under the condition that it is for private or home useage and
-- // this whole comment is reproduced in the source code file.
-- // Commercial utilisation is not authorized without the appropriate
-- // written agreement from amg0 / alexis . mermet @ gmail . com
-- // This program is distributed in the hope that it will be useful,
-- // but WITHOUT ANY WARRANTY; without even the implied warranty of
-- // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE .
local MSG_CLASS = "WES"
local WES_SERVICE = "urn:upnp-org:serviceId:wes1"
local devicetype = "urn:schemas-upnp-org:device:wes:1"
local this_device = nil
local DEBUG_MODE = false	-- controlled by UPNP action
local version = "v0.71"
local UI7_JSON_FILE= "D_WES_UI7.json"
local DEFAULT_REFRESH = 5
local CGX_FILE = "vera.cgx"		-- or data.cgx if extensions are not installed
local NAME_PREFIX = "WES "		-- trailing space needed
local json = require("dkjson")
local hostname = nil

local mime = require('mime')
local socket = require("socket")
local http = require("socket.http")
local ltn12 = require("ltn12")
local lom = require("lxp.lom") -- http://matthewwild.co.uk/projects/luaexpat/lom.html
local xpath = require("xpath")

-- local mime = require("mime")
-- local https = require ("ssl.https")
-- local modurl = require "socket.url"

local xmlmap = {
	["/data/info/firmware/text()"] = { variable="Firmware" , default="" },
	["/data/variables/*"] = { variable="%s" , default="" },
	["/data/*/PAP/text()"] = { variable="Watts" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
	["/data/*/vera/KWHJ/text()"] = { variable="KWH" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
	["/data/*/vera/IHP/text()"] = { variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="tic%s" , default="0"},
	["/data/temp/*/text()"] = { variable="CurrentTemperature" , service="urn:upnp-org:serviceId:TemperatureSensor1", child="SONDE%s" , default=""},
	["/data/temp/vera/NOM%s/text()"] = { attribute="name" ,child="SONDE%s" , default="" , mask=NAME_PREFIX.."%s"},
	["/data/relais/*/text()"] = { variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="rl%s" , default=""},
	["/data/relais/vera/NOM%s/text()"] = { attribute="name" , child="rl%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/analogique/*/text()"] = { variable="CurrentLevel" , service="urn:micasaverde-com:serviceId:GenericSensor1", child="ad%s" , default=""},
	["/data/analogique/vera/NOM%s/text()"] = { attribute="name" ,child="ad%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/switch_virtuel/*/text()"] = { variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="vs%s" , default=""},
	["/data/switch_virtuel/vera/NOM%s/text()"] = { attribute="name" , child="vs%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/entree/*/text()"] = { variable="Status" , service="urn:upnp-org:serviceId:SwitchPower1", child="in%s" , default=""},
	["/data/entree/vera/NOM%s/text()"] = { attribute="name" , child="in%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/impulsion/INDEX%s/text()"] = { variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},
	["/data/impulsion/vera/CONSOJ%s/text()"] = { variable="KWH" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},
	["/data/impulsion/vera/NOM%s/text()"] = { attribute="name" , child="pls%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/pince/INDEX%s/text()"] = { variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/pince/I%s/text()"] = { variable="Watts" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/pince/vera/NOM%s/text()"] = { attribute="name" , child="pa%s" , default="", mask=NAME_PREFIX.."%s"},
	["/data/pince/vera/CONSOJ%s/text()"] = { variable="KWH" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pa%s" , default=""},
	["/data/tic%s/vera/caption/text()"] = { attribute="name" , child="tic%s" , default="", mask=NAME_PREFIX.."%s"},
}
	-- ["/data/impulsion/PULSE%s/text()"] = { variable="Pulse" , service="urn:micasaverde-com:serviceId:EnergyMetering1", child="pls%s" , default=""},

-- altid is the object ID ( like the relay ID ) on the WES server
local childmap = {
	["SONDE%s"] = {
		devtype="urn:schemas-micasaverde-com:device:TemperatureSensor:1",
		devfile="D_TemperatureSensor1.xml",
		name="SONDE %s",
		map="TempSensors" -- user choice in a CSV string 1 to 8 ex:  2,3
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
		map={1,2}	-- hard coded dev 1 and 2
	},
	["in%s"] = {
		devtype="urn:schemas-upnp-org:device:BinaryLight:1",
		devfile="D_BinaryLight1.xml",
		name="ENTREE %s",
		map={1,2}	-- hard coded dev 1 and 2
	},
	["vs%s"] = {
		devtype="urn:schemas-upnp-org:device:BinaryLight:1",
		devfile="D_BinaryLight1.xml",
		name="SWITCH %s",
		map="VirtualSwitches"	-- user choice in a CSV string 1 to 8 ex:  2,3
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

function string.starts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

local function isempty(s)
  return s == nil or s == ""
end

---code from lolodomo DNLA plugin
local function xml_decode(val)
	  return val:gsub("&#38;", '&')
				:gsub("&#60;", '<')
				:gsub("&#62;", '>')
				:gsub("&#34;", '"')
				:gsub("&#39;", "'")
				:gsub("&lt;", "<")
				:gsub("&gt;", ">")
				:gsub("&quot;", '"')
				:gsub("&apos;", "'")
				:gsub("&amp;", "&")
end

---code from lolodomo DNLA plugin
local function xml_encode(val)
	  return val:gsub("&", "&amp;")
				:gsub("<", "&lt;")
				:gsub(">", "&gt;")
				:gsub('"', "&quot;")
				:gsub("'", "&apos;")
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

local function bxor (a,b)
  local r = 0
  for i = 0, 31 do
	local x = a / 2 + b / 2
	if x ~= math.floor (x) then
	  r = r + 2^i
	end
	a = math.floor (a / 2)
	b = math.floor (b / 2)
  end
  return r
end

local function smpEncrypt(text, pass)
  --log("smpEncrypt("..text..", "..pass..")")
  local keysize = pass:len()
  local textsize = text:len()
  local iT, iP = 0,0
	local out = {}
  for iT=0,textsize-1 do
	iP=(iT % keysize)
	local c = string.byte(text:sub(iT+1,iT+1))
	c = bxor( c , string.byte(pass:sub(iP+1,iP+1)) )
	c = string.format("%c",c)
		table.insert(out, c)
  end
	return table.concat(out)
end

local function smpDecrypt(text, pass)
  --log("smpDecrypt("..text..", "..pass..")")
  local keysize = pass:len()
  local textsize = text:len()
  local iT, iP = 0,0
	local out = {}
  for iT=0,textsize-1 do
	iP=(iT % keysize)
	local c = string.byte(text:sub(iT+1,iT+1))
	c = bxor( c , string.byte(pass:sub(iP+1,iP+1)) )
	c = string.char(c)
		table.insert(out, c)
  end
	return table.concat(out)
end

local function StrongEncrypt(str)
  local key = luup.hw_key
  local res= smpEncrypt(str, key)
  return res
end

local function StrongDecrypt(str)
  local key = luup.hw_key
  local res =  smpDecrypt(str, key)
  return res
end

------------------------------------------------
-- Device Properties Utils
------------------------------------------------

local function getSetVariable(serviceId, name, deviceId, default)
	local curValue = luup.variable_get(serviceId, name, deviceId)
	if (curValue == nil) then
		curValue = default
		luup.variable_set(serviceId, name, curValue, deviceId)
	end
	return curValue
end

local function getSetVariableIfEmpty(serviceId, name, deviceId, default)
	local curValue = luup.variable_get(serviceId, name, deviceId)
	if (curValue == nil) or (curValue:trim() == "") then
		curValue = default
		luup.variable_set(serviceId, name, curValue, deviceId)
	end
	return curValue
end

local function setVariableIfChanged(serviceId, name, value, deviceId)
	debug(string.format("setVariableIfChanged(%s,%s,%s,%s)",serviceId, name, value, deviceId))
	local curValue = luup.variable_get(serviceId, name, tonumber(deviceId)) or ""
	value = value or ""
	if (tostring(curValue)~=tostring(value)) then
		luup.variable_set(serviceId, name, value, tonumber(deviceId))
	end
end

local function setAttrIfChanged(name, value, deviceId)
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
		maxNb = 0    -- No limit
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

function string:split(sep) -- from http://lua-users.org/wiki/SplitJoin   : changed as consecutive delimeters was not returning empty strings
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

	local url = string.format ("http://%s/%s?%s", ip_address,cmd,data)
	debug("url:"..url)

	local str = mime.unb64(credentials)
	local parts = str:split(":")
	local code,content,httpStatusCode  = luup.inet.wget(url,60,parts[1],parts[2])
	if (code==0) then
		-- success
		debug(string.format("content:%s",content))
		setVariableIfChanged(WES_SERVICE, "IconCode", 100, lul_device)
		return content
	else
		setVariableIfChanged(WES_SERVICE, "IconCode", 0, lul_device)
	end
	-- failure
	debug(string.format("failure=> code:%s httpStatusCode:%s",code,httpStatusCode))
	return nil
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
	-- debug('WES_Handler: outputformat is: '..json.encode(lul_outputformat))
	local lul_html = "";	-- empty return by default
	local mime_type = "";
	-- debug("hostname="..hostname)
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

local function registerHandlers()
	luup.register_handler("myWES_Handler","WES_Handler")
end

local function prepareXMLmap(lul_device)
	local NamePrefix = getSetVariable(WES_SERVICE, "NamePrefix", lul_device, NAME_PREFIX)
	for xp,v in pairs(xmlmap) do
		if (v.mask ~=nil) then
			v.mask  = v.mask:gsub(NAME_PREFIX,NamePrefix,1)
		end
	end
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
			local csv  = getSetVariable(WES_SERVICE, child.map, lul_device, "")
			map = csv:split(",")
		end

		for k,v in pairs(map) do
			local i = tonumber(v)
			if (i ~= nil ) then
				luup.chdev.append(
					lul_device, child_devices,
					string.format(kchild,i),			-- children map index is altid
					NAME_PREFIX..string.format(child.name,i), 	-- children map name attribute is device name
					child.devtype,						-- children device type
					child.devfile, 						-- children devfile
					"", "",
					false								-- not embedded
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

local function doload(lul_device, lomtab, xp, child_target, service,  variable, attribute, default_value,mask)
	service = service or WES_SERVICE
	debug( string.format("xpath:%s child:%s service:%s variable:%s attribute:%s default:%s",xp,child_target or "", service or "", variable or "", attribute or "", default_value or "") )
	local map_iteration = {1}
	local child_iteration = {}
	if (child_target~=nil) then
		child_iteration = childmap[ child_target ].map
		if ( type(child_iteration) ~= "table") then
			local csv  = getSetVariable(WES_SERVICE, child_iteration, lul_device, "")
			child_iteration = csv:split(",")
			if (child_iteration[1] == "" ) then	-- default value of variable gives "" so it then gives at least an array of one entry with "" in it 
				child_iteration={}
			end
		end
	end
	local singleton = (tablelength(child_iteration)==0)
	
	if (string.match(xp,"%%")) then
		map_iteration = child_iteration
	end
	
	-- debug( string.format("map iteration will be:%s",json.encode(map_iteration)) )
	service = service or WES_SERVICE
	local child_nth=1		-- position in child_iteration array
	for k,idx in pairs(map_iteration) do
		local xpath_key = string.format(xp, idx)
		local nodes = xpath.selectNodes(lomtab,xpath_key)
		debug( string.format("xpath key:%s XML node result %s",xpath_key,json.encode(nodes) ) )
		for i,n in pairs(nodes) do
			-- determine value to keep
			local value = n or default_value
			local var_name = variable or attribute
			if (xpath_key:sub(-1)=="*") then
				var_name = string.format(var_name,n.tag)
				value = n[1]
			end
			if (value=="OFF") then
				value = 0
			elseif (value=="ON") then
				value = 1
			end

			-- determine target child
			local target_device = lul_device
			if (child_target~=nil) then
				local child_id = child_iteration[child_nth] or ""
				local child_name = string.format(child_target,child_id)
				target_device = findChild( lul_device, child_name )
				child_nth = child_nth +1
			end

			-- save value
			if (target_device ~= nil ) then
				-- debug( string.format("service:%s variable:%s value:%s child:%s",service, var_name, value, target_device) )
				if (mask~=nil) then
					value = string.format(mask,value)
				end
				if (variable~=nil) then
					setVariableIfChanged(service, var_name, value, target_device)
				else
					if (attribute~=nil) then
						setAttrIfChanged(var_name, value, target_device)
					end
				end
			else
				debug( string.format("target_device is null, child_nth=%s, child_iteration=%s",child_nth, json.encode(child_iteration))) 
			end
		end
	end
end

local function loadWesData(lul_device,xmldata)
	debug(string.format("loadWesData(%s) xml=%s",lul_device,xmldata))
	local lomtab = lom.parse(xmldata)
	for xp,v in pairs(xmlmap) do
		doload(lul_device, lomtab, xp, v.child , v.service, v.variable, v.attribute, v.default, v.mask)
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
		UserMessage(string.format("missing ip addr or credentials for device "..lul_device),TASK_ERROR_PERM)
	end

	debug(string.format("programming next refreshEngineCB(%s) in %s",lul_device,period))
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
		-- local zones = xpath.selectNodes(lomtab,"//zone/text()")
		-- debug("zones:"..json.encode(zones))
		-- createChildren(lul_device, zones )
		luup.call_delay("refreshEngineCB",period,tostring(lul_device))
		return loadWesData(lul_device,xmldata)
	else
		UserMessage(string.format("missing ip addr or credentials for device "..lul_device),TASK_ERROR_PERM)
	end
	return true
end

function startupDeferred(lul_device)
	lul_device = tonumber(lul_device)
	log("startupDeferred, called on behalf of device:"..lul_device)

	local debugmode = getSetVariable(WES_SERVICE, "Debug", lul_device, "0")
	local oldversion = getSetVariable(WES_SERVICE, "Version", lul_device, version)
	local period= getSetVariable(WES_SERVICE, "RefreshPeriod", lul_device, DEFAULT_REFRESH)
	local credentials  = getSetVariable(WES_SERVICE, "Credentials", lul_device, "")
	local tempsensors  = getSetVariable(WES_SERVICE, "TempSensors", lul_device, "")
	local VirtualSwitches  = getSetVariable(WES_SERVICE, "VirtualSwitches", lul_device, "")
	local PulseCounters  = getSetVariable(WES_SERVICE, "PulseCounters", lul_device, "")
	local AnalogClamps = getSetVariable(WES_SERVICE, "AnalogClamps", lul_device, "")
	local NamePrefix = getSetVariable(WES_SERVICE, "NamePrefix", lul_device, NAME_PREFIX)
	local iconCode = getSetVariable(WES_SERVICE,"IconCode", lul_device, "0")
	-- local ipaddr = luup.attr_get ('ip', lul_device )

	if (debugmode=="1") then
		DEBUG_MODE = true
		UserMessage("Enabling debug mode for device:"..lul_device,TASK_BUSY)
	end
	local major,minor = 0,0
	local tbl={}

	if (oldversion~=nil) then
		major,minor = string.match(oldversion,"v(%d+)%.(%d+)")
		major,minor = tonumber(major),tonumber(minor)
		debug ("Plugin version: "..version.." Device's Version is major:"..major.." minor:"..minor)

		newmajor,newminor = string.match(version,"v(%d+)%.(%d+)")
		newmajor,newminor = tonumber(newmajor),tonumber(newminor)
		debug ("Device's New Version is major:"..newmajor.." minor:"..newminor)

		-- force the default in case of upgrade
		if ( (newmajor>major) or ( (newmajor==major) and (newminor>minor) ) ) then
			log ("Version upgrade => Reseting Plugin config to default")
		end
		luup.variable_set(WES_SERVICE, "Version", version, lul_device)
	end

	-- start handlers
	registerHandlers()
	createChildren(lul_device)
	prepareXMLmap(lul_device)
	
	-- start engine
	local success = false
	success = startEngine(lul_device)

	-- NOTHING to start
	if( luup.version_branch == 1 and luup.version_major == 7) then
		if (success == true) then
			luup.set_failure(0,lul_device)	-- should be 0 in UI7
		else
			luup.set_failure(1,lul_device)	-- should be 0 in UI7
		end
	else
		luup.set_failure(false,lul_device)	-- should be 0 in UI7
	end

	log("startup completed")
end

function initstatus(lul_device)
	lul_device = tonumber(lul_device)
	this_device = lul_device
	log("initstatus("..lul_device..") starting version: "..version)
	checkVersion(lul_device)
	math.randomseed( os.time() )
	hostname = getIP()
	local delay = 1		-- delaying first refresh by x seconds
	debug("initstatus("..lul_device..") startup for Root device, delay:"..delay)
	luup.call_delay("startupDeferred", delay, tostring(lul_device))
end

-- do not delete, last line must be a CR according to MCV wiki page
