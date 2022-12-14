--[[----------------------------------------------------------------------------
info.lua

This file is part of Refraktor Lightroom Plugin
Copyright(c) 2022 Cassie Wintermute

Information for the Refraktor ExifTool Plug-in


---------------------------------------------------------------------------]]
pluginMajor = 0
pluginMinor = 0
pluginRev = 5
pluginBuild = 20220821

pluginVersion = pluginMajor .. '.' .. pluginMinor .. '.' ..pluginRev .. '.' .. pluginBuild



return {
  LrSdkVersion            = 11.0,  
  LrSdkMinimumVersion     = 3.0,
  LrToolkitIdentifier     = "org.refraktor.lightroom",
  LrPluginName            = "Refraktor Exif Plugin",
  LrPluginInfoUrl         = "https://refraktor.org/",
  LrPluginInfoProvider    = "PluginInfoProvider.lua",
  LrInitPlugin            = "PluginInit.lua",

  
  -- Add an entry for the File Menu

  LrExportMenuItems = {
    {
      title = "Refraktor",
      file = "Refraktor.lua",
      enabledWhen = "photosSelected",
    }
  },  

  -- Add an entry for the Library Menu
  
  LrLibraryMenuItems = {
    {
      title = "Refraktor",
      file = "Refraktor.lua",
      enabledWhen = "photosSelected",
    }
  },  

  VERSION = { major=pluginMajor, minor=pluginMinor, revision=pluginRev, build=pluginBuild},
}