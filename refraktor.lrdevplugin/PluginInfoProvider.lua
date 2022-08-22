--[[-------------------------------------------------------------------------
PluginInfoProvider.lua

This file is part of Refraktor Lightroom Plugin
Copyright(c) 2022 Cassie Wintermute

Adds the Top and Bottom sections of the plug-in manager dialog box

Top section is copyright and general information for the plugin
Bottom section is the exiftool.exe path and some developer functions


---------------------------------------------------------------------------]]

-- Lightroom SDK definitions
local LrDialogs   = import "LrDialogs"
local LrView      = import "LrView"
local LrHttp      = import "LrHttp"
local LrPrefs     = import "LrPrefs"
local LrPathUtils = import "LrPathUtils"
local LrFileUtils = import "LrFileUtils"

return {
  sectionsForTopOfDialog = function( f, propertyTable )
    return {
      {
        title = "General",
        synopsis = "General Information and Copyright",
        f:row {
          spacing = f:control_spacing(),
          f:static_text {
            title = "This is a WIP frontend to ExifTool.\nDesigned to be used on shots done with a manual lens.",
            alignment = "left",
            fill_horizontal = 1,
          },
          f:push_button {
            width = 60,
            title = "Website",
            enabled = true,
            action = function()
              LrHttp.openUrlInBrowser( "https://refraktor.org" )
            end, -- end function
          },
        }, -- end row 1
        f:row {
          spacing = f:control_spacing(),
          f:static_text {
            title = "Copyright 2022 Cassie Wintermute",
            alignment = "left",
            fill_horizontal = 1,
            },

            f:push_button {
              width = 100,
              title = "Github Page",
              enabled = true,
              action = function()
                LrHttp.openUrlInBrowser( "https://github.com/cwintermute/Refraktor" )
              end,
            },
        }, -- end row 2
        f:row {
          spacing = f:control_spacing(),
          f:static_text {
            title = "Official ExifTool Website",
            alignment = "left",
            fill_horizontal = 1,
            },
        },
        f:row {
            f:push_button {
              width = 100,
              title = "ExifTool",
              alignment = "left",
              enabled = true,
              action = function()
                LrHttp.openUrlInBrowser( "https://exiftool.org" )
              end,
            },
        }, -- end row 2
      },    
    }
  end, -- End the Top Section



  sectionsForBottomOfDialog = function( f, propertyTable )
    local prefs = LrPrefs.prefsForPlugin()
    local bind = LrView.bind -- a local shortcut for the binding function

    -- By default, we don't want debug logging
    if prefs.debugLogging == nil then
      prefs.debugLogging = false
    end

    return {
      {
        title = "Options",
        synopsis = "Options for Refraktor",
        
        f:row {
          spacing = f:control_spacing(),
          bind_to_object = prefs, 
          f:static_text {
            title = "exiftool.exe",
            alignment = "left",
          },

          f:edit_field {
            value = bind( "exifPath" ),
            alignment = "left",
            width = 420,
            immediate = true,

          },

          f:push_button {
            title = "Browse",
            enabled = true,
            action = function ()
                local location = LrDialogs.runOpenPanel({
                    title = "Please locate exiftool.exe",
                    canChooseDirectories = false,
                    allowsMultipleSelection = false,
                    canCreateDirectories = false,
                    fileTypes = "exe",
                })[1]
                if WIN_ENV then
                  prefs.exifPath = "\"" .. location .. "\""
                else
                  prefs.exifPath = location
                end
            end
         },
        }, -- end row 1
        f:row {
          spacing = f:control_spacing(),
          bind_to_object = prefs, 
          f:static_text {
            title = "Debug logging:"
          },
          f:popup_menu {
            title = "Logging mode:",
            value = bind ( "debugLogging" ),
            items = {
              {title = "No logging", value = false},
              {title = "Log File", value="logfile"},
              {title = "Console Output", value="print"}
            }
          },         
        }, -- end row 2
        f:row {
            f:push_button {
              title = "Reset Metadata Prompt",
              enabled = true,
              action = function ()
                LrDialogs.resetDoNotShowFlag( "hideMetadataPrompt" )
              end
            },
            f:push_button {
              width = 100,
              title = "Delete Profiles",
              enabled = true,
              action = function()
                local response = LrDialogs.confirm(
                  "Are you sure you want to delete all profiles.",
                  "This can't be undone!",
                  "Delete"
                )
                if response == "ok" then
                  prefs.lensProfiles = nil
                  if prefs.backupFile ~= nil then
                    res = LrFileUtils.delete(prefs.backupFile)
                    if res ~= true then
                      LrDialogs.message(res[2])
                    end
                  end
                  LrDialogs.message("Profiles have been removed")
                end -- end if
              end -- end function
            },
            
        },
      },
    }
  end -- End Bottom Section

}