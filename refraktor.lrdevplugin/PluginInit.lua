--[[-------------------------------------------------------------------------
PluginInfoProvider.lua

This file is part of Refraktor Lightroom Plugin
Copyright(c) 2022 Cassie Wintermute


---------------------------------------------------------------------------]]

-- Simple function to check if a key exists in a table
function tableHasKey(table,key)
  return table[key] ~= nil
end

-- Simple function to check if value is nil or ''
function isEmpty(s)
  return s == nil or s == ''
end
