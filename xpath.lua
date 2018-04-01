-----------------------------------------------------------------------------
-- XPath module based on LuaExpat
-- Description: Module that provides xpath capabilities to xmls.
-- Author: Gal Dubitski
-- Version: 0.1
-- Date: 2008-01-15
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- Modification A. Mermet, only import needed functions
-----------------------------------------------------------------------------

function trim(str)
	if str ~= nil then
   		return (string.gsub(str, "^%s*(.-)%s*$", "%1"))
   	else
   		return nil
   	end
end

function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 	table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function findText(str,regex)
	local lastPosition = 1
	local words = {}
	repeat
		local temp,pos,w = string.find(str,regex,lastPosition)
		if w ~= nil then
			table.insert(words,w)
			lastPosition = pos + 1
		end
	until w == nil
	return words
end

function string.beginTag(str,tagName,spaces,opened)
	local newline = [[
	
]]
	if opened then
		return str..newline..string.rep(" ",spaces).."<"..tagName..">" , spaces+2 , true
	else
		return str..string.rep(" ",spaces).."<"..tagName..">" , spaces+2 , true
	end
end

function string.endTag(str,tagName,spaces,closed)
	local newline = [[
	
]]
	if closed then
		return str..string.rep(" ",spaces-2).."</"..tagName..">"..newline , spaces-2 , false
	else
		return str.."</"..tagName..">"..newline , spaces-2 , false
	end
end

-- return a copy of the table t
function clone(t)
  local new = {}
  local i, v = next(t, nil)
  while i do
  	if type(v)=="table" then v=clone(v) end
    new[i] = v
    i, v = next(t, i)
  end
  return new
end

--- this function converts a lom object to a string
function lomToString(t)
	assert(type(t)=='table')
	local res = ""
	res = res .. "<" .. t.tag
	if t.attr ~= nil then
		attrs = t.attr
		for i,v in ipairs(attrs) do
			if type(v) == 'string' and type(attrs[v]) == 'string' then
				res = res .. " " .. v .. "=\"" .. attrs[v] .. "\""
			end
		end
	end
	res = res .. ">"
	if type(t[1]) == 'string' then res = res .. t[1] end
	for i,v in ipairs(t) do
		if type(v) == 'table' and v.tag ~= nil then
			res = res .. lomToString(v)
		end
	end
	res = res.."</"..t.tag..">"
	return res
end


-----------------------------------------------------------------------------
-- Declare module and import dependencies
-----------------------------------------------------------------------------

local lom = require "lxp.lom"
module("xpath",package.seeall)
local resultTable,option = {},nil

-----------------------------------------------------------------------------
-- Supported functions
-----------------------------------------------------------------------------

local function insertToTable(leaf)
	if type(leaf) == "table" then
		if option == nil then
			table.insert(resultTable,leaf)
		elseif option == "text()" then
			table.insert(resultTable,leaf[1])
		elseif option == "node()" then
			table.insert(resultTable,leaf.tag)
		elseif option:find("@") == 1 then
			table.insert(resultTable,leaf.attr[option:sub(2)])
		end
	end
end


local function match(tag,tagAttr,tagExpr,nextTag)
	
	local expression,evalTag
	
	-- check if its a wild card
	if tagExpr == "*" then
		return true
	end
	
	-- check if its empty
	if tagExpr == "" then
		if tag == nextTag then
			return false,1
		else
			return false,0
		end
	end
	
	-- check if there is an expression to evaluate
	if tagExpr:find("[[]") ~= nil and tagExpr:find("[]]") ~= nil then
		evalTag = tagExpr:sub(1,tagExpr:find("[[]")-1)
		expression = tagExpr:sub(tagExpr:find("[[]")+1,tagExpr:find("[]]")-1)
		if evalTag ~= tag then
			return false
		end
	else
		return (tag == tagExpr)
	end
	
	-- check if the expression is an attribute
	if expression:find("@") ~= nil then
		local evalAttr,evalValue
		evalAttr = expression:sub(expression:find("[@]")+1,expression:find("[=]")-1)
		evalValue = string.gsub(expression:sub(expression:find("[=]")+1),"'","")
		evalValue = evalValue:gsub("\"","")
		if tagAttr[evalAttr] ~= evalValue then
			return false
		else
			return true
		end
	end
	
end

local function parseNodes(tags,xmlTable,counter)
	if counter > #tags then
		return nil
	end
	local currentTag = tags[counter]
	local nextTag
	if #tags > counter then
		nextTag = tags[counter+1]
	end
	for i,value in ipairs(xmlTable) do
		if type(value) == "table" then
			if value.tag ~= nil and value.attr ~= nil then
				local x,y = match(value.tag,value.attr,currentTag,nextTag)
				if x then
					if #tags == counter then
						insertToTable(value)
					else
						parseNodes(tags,value,counter+1)
					end
				else
					if y ~= nil then
						if y == 1 then
							if counter+1 == #tags then
								insertToTable(value)
							else
								parseNodes(tags,value,counter+2)
							end
						else
							parseNodes(tags,value,counter)
						end
					end
				end
			end
		end
	end
end

function selectNodes(xml,xpath)
	assert(type(xml) == "table")
	assert(type(xpath) == "string")
	
	resultTable = {}
	local xmlTree = {}
	table.insert(xmlTree,xml)
	assert(type(xpath) == "string")
	
	tags = split(xpath,'[\\/]+')
	
	local lastTag = tags[#tags] 
	if lastTag == "text()" or lastTag == "node()" or lastTag:find("@") == 1 then
		option = tags[#tags]
		table.remove(tags,#tags)
	else
		option = nil
	end
	
	if xpath:find("//") == 1 then
		table.insert(tags,1,"")
	end
	
	parseNodes(tags,xmlTree,1)
	return resultTable
end




