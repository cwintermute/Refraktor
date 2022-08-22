--[[-------------------------------------------------------------------------
Refraktor.lua

This file is part of Refraktor Lightroom Plugin
Copyright(c) 2022 Cassie Wintermute


---------------------------------------------------------------------------]]
json = require "json"


local LrDialogs         = import "LrDialogs"
local LrPrefs           = import "LrPrefs"
local LrBinding         = import "LrBinding"
local LrFunctionContext = import "LrFunctionContext"
local LrView            = import "LrView"
local LrHttp            = import "LrHttp"
local LrLogger          = import "LrLogger"
local LrTasks           = import "LrTasks"
local LrApplication     = import "LrApplication"
local LrPathUtils       = import "LrPathUtils"
local LrFileUtils       = import "LrFileUtils"

local catalog = LrApplication.activeCatalog()
local bind = LrView.bind -- a local shortcut for the binding function

-- Array of fields we are going to be processing
local fieldsToProcess = {
  "lensName",
  "lensProfile",
  "minFocalLength",
  "maxFocalLength",
  "minFStopAtMinFocalLength",
  "minFStopAtMaxFocalLength",
  "focalLength",
  "maxAperture",
  "minAperture",
  "focalLengthIn35mm",
  "lensSerialNumber",
  "fStop",
  "exposureTime",
}

-- Initialize the Plug-in preferences
prefs = LrPrefs.prefsForPlugin()

-- Initialize prefs.lensProfiles is it is nil
if prefs.lensProfiles == nil then
  prefs.lensProfiles = {}
end -- end if

-- Initialize the Logger
local logger = LrLogger( "Refraktor" )
if prefs.debugLogging ~= false then
  logger:enable( prefs.debugLogging )
  logger:trace("Initialized the logger")
end -- end if

-- Code to handle loading saved preferences
local backupFile = LrPathUtils.parent (_PLUGIN.path) .. "\\" .. "refraktor.lensprofiles"
logger:info("Backup save location: " ..  backupFile)
if LrFileUtils.exists(backupFile) then
  f = io.open(backupFile, "r")
  if f ~= nil then
    logger:trace("Saved profiles found on disk")
    io.input(f)
    local jsonText = io.read("*all")
    lensProfiles = json.decode(jsonText)
    -- if we don't have any profiles, just add them all
    if #prefs.lensProfiles == 0 then
      prefs.lensProfiles = lensProfiles
    end -- end if
    -- To-Do: Go through saved presets and load missing ones from disk?
    io.close(f)
  end -- end if
end -- end if

-- Display the warning about saving Metadata to disk.
LrDialogs.messageWithDoNotShow({
  message = "Please ensure Metadata is saved. Errors may occur otherwise",
  info = "Metadata > Save Metadata to Files",
  actionPrefKey = "hideMetadataPrompt",
})

LrFunctionContext.callWithContext( "refraktorSettings", function( context )
  local f = LrView.osFactory() --obtain a view factory
  local props = LrBinding.makePropertyTable( context ) -- make a table

  -- Load saved values from Plug-in Preferences
  props.exifPath     = prefs.exifPath
  props.command      = prefs.command
  props.editCommand  = prefs.editCommand
  props.useFileList  = prefs.useFileList
  props.exportXMP    = prefs.exportXMP

  -- By default, disable the editing of the command box
  if props.editCommand == nil then
    props.editCommand = false
  end

  -- By default, disable using a filelist
  if props.useFileList == nil then
    props.useFileList = false
  end

  -- By default, don't use XMP sidecar files
  if props.exportXMP == nil then
    props.exportXMP = false
  end

  -- Create the current lens table
  props.lens = {}

  -- Start checking for values saved in the Plug-in preferences and loading them
  for _,v in pairs(fieldsToProcess) do
    props[v] = prefs[v]
  end

  -- Pull up the list of photos selected
  local photo = catalog:getTargetPhoto()
  local photos = catalog:getTargetPhotos()


  -- Define output files and Line Breaks based off OS
  if WIN_ENV == true then
    props.outputLog = "C:\\Windows\\Temp\\RefraktorCmd.log"
    props.fileList = "C:\\Windows\\Temp\\RefraktorFileList.tmp"
    props.CR = "\r\n"
  elseif MAC_ENV == true then
    props.outputLog = "/tmp/RefracktorCmd.log"
    props.fileList = "/tmp/RefraktorFileList.tmp"
    props.CR = "\n"
  else
    LrDialogs.message("Unknown Environment?", nil, "warning")
  end


  local contents = f:view { -- define view hierarchy
    spacing = f:label_spacing(),
    f:row { -- The top warning line
      spacing = f:dialog_spacing(),
      f:static_text {
        title = "You can add other flags here. Don't change unless you know what you are doing!",
        alignment = "left",
     },
    }, -- end warning row

    f:row {  -- exiftool path line
      spacing = f:label_spacing(),
      bind_to_object = props, 
      f:static_text {
        title = "exiftool.exe:", alignment = "left",
      },
      f:edit_field { 
        fill_horizontal = 1,
        value = bind( "exifPath" ),
      },  
    }, -- End Exif Tool Path

    f:row {  -- a divider
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:separator {
        fill_horizontal = 1,
      },
    }, -- End Divider

    f:row { -- Notice to update the command
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:static_text {
        title = "After changing any of these values, please press 'Generate Command'.", 
        alignment = "left",
      },
    }, -- end Notice row
    
    f:row {  -- The Lens Name Line
      spacing = f:label_spacing(),
      bind_to_object = props, 
      f:static_text {
        title = "Lens Name:", 
        alignment = "left",
        tooltip = "Brand and Full name of Lens goes here",
      },
      f:edit_field { 
        fill_horizontal = 1,
        immediate = true,
        value = bind({
          bind_to_object = props, 
          key = "lensName",        
        }),
      },  
    }, -- End Lens Name

    f:row {  -- LensInfo line
      spacing = f:label_spacing(),
      bind_to_object = props, 
      f:static_text {
        title = "LensInfo Parameters:", alignment = "left",
        tooltip = [[Field 1 - Min Focal Length in mm
Field 2 - Max Focal Length in mm
Field 3 - Min F-Number in the Min Focal Length
Field 4 - Min F-Number in the Max Focal Length]],
      },
      f:edit_field { 
        fill_horizontal = 0,
        width_in_chars = 5,
        value = bind( "minFocalLength" ),
      },  
      f:edit_field { 
        fill_horizontal = 0,
        width_in_chars = 5,
        value = bind( "maxFocalLength" ),
      },  
      f:edit_field { 
        fill_horizontal = 0,
        width_in_chars = 5,
        value = bind( "minFStopAtMinFocalLength" ),
      },  
      f:edit_field { 
        fill_horizontal = 0,
        width_in_chars = 5,
        value = bind( "minFStopAtMaxFocalLength" ),
      },  
      f:push_button {
        width = 100,
        title = "Reference",
        enabled = true,
        action = function()
          LrHttp.openUrlInBrowser( 
            "https://exiftool.org/forum/index.php?topic=10586.msg56098#msg56098"
           )
        end,
      },
    }, -- End LensInfo Line

    f:row {  -- Focal Length and Focal Length in 35mm
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:static_text {
        title = "Focal Length:", alignment = "left",
        tooltip = "The actual focal length of the lens, in mm.\n\nFor Crop Sensor cameras, enter the lens Focal Length\nLightroom should auto calculate the 35mm equivalent",
      },
      f:edit_field { 
        fill_horizontal = 0,
        width_in_chars = 4,
        value = bind( "focalLength" ),
      },
      f:static_text {
        title = "Focal Length @ 35mm:", alignment = "left",
        tooltip = "Use this option if Lightroom doesn't auto calculate the 35mm equivalent"
      },
      f:edit_field { 
        fill_horizontal = 0,
        width_in_chars = 4,
        value = bind( "focalLengthIn35mm" ),
      },  
    }, -- End Focal Length and Focal Length in 35mm

    f:row {  -- Max and Min Aperture
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:static_text {
        title = "Max Aperture:", alignment = "left",
        tooltip = "Max Aperture of the lens used. Only available on some file formats",
      },
      f:edit_field { 
        fill_horizontal = 0,
       width_in_chars = 4,
       value = bind( "maxAperture" ),
      },
      f:static_text {
        title = "Min Aperture:", alignment = "left",
        tooltip = "Min Aperture of the lens used",
      },
      f:edit_field { 
        fill_horizontal = 0,
       width_in_chars = 4,
       value = bind( "minAperture" ),
      },
    }, -- End Max and Min Aperture

    f:row { -- Lens Serial #
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:static_text {
        title = "Lens Serial #:", alignment = "left",
      },
      f:edit_field { 
        fill_horizontal = 0,
        width_in_chars = 16,
        value = bind( "lensSerialNumber" ),
      },  
    }, -- End Lens Serial #

    f:row {  -- F-Stop used
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:static_text {
        title = "F-Stop:", alignment = "left",
      },
      f:edit_field { 
        fill_horizontal = 0,
        width_in_chars = 4,
        value = bind( "fStop" ),
      },  
      f:static_text {
        title = "Only updates when field is filled out", alignment = "left",
      },
    }, -- End F-Stop Section

    f:row {  -- Exposure Time in Seconds
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:static_text {
        title = "Exposure Time:", alignment = "left",
        tooltip = "Exposure time in seconds",
      },
      f:edit_field { 
        fill_horizontal = 0,
        width_in_chars = 8,
        value = bind( "exposureTime" ),
      },  
    }, -- End Exposure Time in Seconds

    f:row {  -- a divider
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:separator {
        fill_horizontal = 1,
      },
    }, -- End Divider

    f:row { -- Use fileList and show fileList buttons
      spacing = f:control_spacing(),
      bind_to_object = props,
      f:checkbox {
        title = "Use a filelist?",
        tooltip = "Useful when dealing with large number of files.\nGets around windows limitations",
        value = bind ( "useFileList" ),
      },
      f:push_button {
        width = 100,
        title = "Show Filelist",
        tooltip = "Please make sure command is up to date before using",
        enabled = true,
        action = function()
          return nil
        end
      }
    }, -- end Use fileList and show fileList buttons

    f:row { -- Export to XMP sidecar line
      spacing = f:control_spacing(),
      bind_to_object = props,
      f:checkbox {
        title = "Export to xmp sidecar file? -- Stil in testing...",
        tooltip = "Saved Exif data to sidecar XMP file instead",
        value = bind ( "exportXMP" ),
      },
    }, -- End Export to XMP sidecar line

    f:row {  -- a divider
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:separator {
        fill_horizontal = 1,
      },
    }, -- End Divider

    f:row { -- Lens Profile combo box row
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:combo_box {
        fill_horizontal = 1,
        value = bind 'lensProfile',
        items = function()
          local lensProfiles = prefs.lensProfiles
          if lensProfiles == nil then
            logger:trace('found empty prefs.lensProfiles?')
            lensProfiles = {}
          end

          local profileList = {}
          for i, v in ipairs(lensProfiles) do
            profileList[ #profileList + 1 ] = lensProfiles[i].lensProfile
          end

          return profileList
        end
      },
    }, -- End Lens Profile combo box row

    f:row { -- Row of Profile buttons, e.g. Load, Save, Import, Export and Delete
      f:push_button {
        width = 100,
        title = "Load Profile",
        enabled = true,
        action = function()
          -- We won't be updating the lensProfiles table
          -- So let's just iterate it directly
          local loadIndex
          for i, v in ipairs( prefs.lensProfiles ) do
            if v.lensProfile == props.lensProfile then
              loadIndex = i
            end
          end
          logger:trace('loadIndex: ' .. loadIndex)
          -- Next iterate over the fields in the profile and update props.lens
          for _,v in pairs(fieldsToProcess) do
            logger:trace("Loading key: " .. v .. " - " .. prefs.lensProfiles[loadIndex][v])
            props[v] = prefs.lensProfiles[loadIndex][v]
            logger:trace("Loaded key: " .. v .. " - " .. props[v])
          end
        end,
      },
      f:push_button {
        width = 100,
        title = "Save Profile",
        enabled = true,
        action = function()
          logger:trace('test')
          logger:trace("Saving Profile: " .. props.lensProfile)

          local profiles = prefs.lensProfiles
          if profiles == nil then
            profiles = {}
          end

          local existingEntry
          logger:trace('making new table')
          -- make a new table to hold values we are gonna save
          newTable = {}
          for _,v in pairs(fieldsToProcess) do
            newTable[v] = props[v]
          end
          logger:trace('looking for dupes')
          -- See if we have an existing record
          for i,v in ipairs(profiles) do
            if v.lensProfile == props.lensProfile then
              existingEntry = i
            end
          end
          logger:trace('after dupe check')
          local saved
          if existingEntry == nil then -- we have a new record to save
            profiles[ #profiles + 1 ] = newTable
            saved = true
          else -- Overwrite existing record
            local response = LrDialogs.confirm(
              "Are you sure you want to overwrite the following profile:",
              props.lensProfile,
              "Overwrite"
            )
            if response == 'ok' then
              profiles[existingEntry] = newTable
              saved = true
            end
          end
          
          if saved then
            prefs.lensProfiles = profiles
            LrDialogs.message(
              "Profile saved: " .. props.lensProfile,
              "Please restart the plugin to continue",
              "info"
            )
          end
        end,
      },

      f:push_button {
        width = 100,
        title = "Export Profile",
        enabled = true,
        action = function()
          logger:trace('Starting Export')
          local outputFile = LrDialogs.runSavePanel({
            title = "Please choose output file",
            canCreateDirectories = true,
            requiredFileType = "lensprofile",
          })
          if outputFile ~= nil then
            logger:trace("Saving to file: " .. outputFile)

            -- figure out what index the profile is
            local loadIndex
            for i, v in ipairs( prefs.lensProfiles ) do
              if v.lensProfile == props.lensProfile then
                loadIndex = i
              end
            end
            logger:trace("loadIndex: "  .. loadIndex)
            if loadIndex ~= nil then
              
              local lensProfile = {}
              for _,key in ipairs(fieldsToProcess) do
                lensProfile[key] = prefs.lensProfiles[loadIndex][key]
              end -- end for
              logger:trace('Finished building values to save')
              jsonText = json.encode(lensProfile)
              logger:trace('Creating json output text')
              f = io.open(outputFile, "w+")
              io.output(f)
              io.write(jsonText)
              io.close(f)

              LrDialogs.message("Lens Profile has been exported")
            end
          end -- end if
        end -- end function

      },
      
      f:push_button {
        width = 100,
        title = "Import Profile",
        enabled = true,
        action = function()
          local lensProfiles = prefs.lensProfiles
          logger:trace("Starting Import Profile")
          local inFile = LrDialogs.runOpenPanel({
            title = "Please locate profile",
            canChooseDirectories = false,
            allowsMultipleSelection = false,
            canCreateDirectories = false,
            fileTypes = "lensprofile",
          })[1]
          logger:trace("Following file selected:")
          logger:trace(inFile)
          f = io.open (inFile, "r")
          logger:trace("File Opened")
          io.input(f)
          logger:trace("io.input has been called")
          jsonText = io.read("*all")
          logger:trace(jsonText)
          logger:trace("File has been read")
          newValues = json.decode(jsonText)
          -- figure out what is actually loaded up...
          logger:trace("JSON Decoded")
          io.close(f)
          logger:trace("File has been closed")
          -- Make sure we aren't overwriting an existing lens
          local dupeFound = false
          for _,lens in ipairs(lensProfiles) do
            if lens.lensProfile == newValues.lensProfile then
              logger:trace("Duplicate profile found")
              dupeFound = true
            end -- end if
          end -- end for

          if not dupeFound then
            lensProfiles [ #lensProfiles + 1 ] = newValues
            prefs.lensProfiles = lensProfiles
            --prefs.lensProfiles[ #prefs.lensProfiles + 1] = newValues
            LrDialogs.message("Profile has been imported","Please restart plugin to continue")
          else
            LrDialogs.message("Duplicate Profile found!")
          end -- end if

        
        end
        },
        f:push_button {
          width = 100,
          title = "Delete Profile",
          enabled = true,
          action = function()
            local lensProfiles = prefs.lensProfiles -- get current items list from this table
            local response = LrDialogs.confirm(
              "Are you sure you want to delete the following profile:",
              props.lensProfile,
              "Confirm"
            )
            if response == "ok" then
              local deleted = false
              for i, v in ipairs( lensProfiles ) do
                logger:trace(v)
                if v.lensProfile == props.lensProfile then
                  table.remove(lensProfiles, i)
                  deleted = true
                  break
                end
              end
              if deleted == true then
                prefs.lensProfiles = lensProfiles -- Update the saved lensProfiles
                LrDialogs.message(
                  "Profile removed: " .. props.lensProfile,
                  "Please restart the plugin to continue",
                  "warning"
                )
                props.lensProfile = nil
              end -- end if
            end -- end if
          end -- end function
        },  
    }, -- End Row of Profile buttons, e.g. Load, Save, Import, Export and Delete

    f:row {  -- a divider
      spacing = f:control_spacing(),
      f:separator {
        fill_horizontal = 1,
      },
    }, -- End Divider

    f:row { -- Edit command checkbox
      spacing = f:control_spacing(),
      bind_to_object = props,
      f:checkbox {
        value = bind ( "editCommand" ),
        title = "Edit Command?",
      }
    }, -- End Edit command checkbox


    f:row { -- The command preview box
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:edit_field {
        value = bind ( "command" ),
        height_in_lines = 6,
        width_in_chars = 45,
        enabled = bind ( "editCommand" ),
      }
    }, -- End preview box

    f:row { -- Update and Run Command buttons
      spacing = f:control_spacing(),
      bind_to_object = props, 
      f:push_button {
        width = 115,
        title = "Update Command",
        enabled = true,
        action = function()
          -- Determine if we are using a filelist, and create it if so
          logger:trace(props.useFileList)
          if props.useFileList == true then
            logger:trace("Using filelist")
            logger:trace("Opening filelist")
            f = io.open (props.fileList, "w+")
            io.output(f)
            
            if #photos > 1 then
              logger:trace("Multiple files detected")
              for _, photo in ipairs(photos) do
                if props.exportXMP == true then
                  local filename = LrPathUtils.leafName(photo.path)
                  logger:trace("file: " .. filename)
                else
                  io.write(photo.path .. props.CR)
                end
              end
            else
              logger:trace("Single file detected")
              if props.exportXMP == true then
                local filename = LrPathUtils.removeExtension(photo.path)
                io.write(filename .. ".xmp")
              else
                io.write(photo.path)
              end
            end
            logger:trace("Closing filelist")
            io.close(f)
            props.statusText = "Using filelist"
          else
            props.statusText = "Not using filelist"
          end


          local c -- The command we are building
          c = "\"" .. props.exifPath .. ""

          if not isEmpty(props.lensName) then
            c = c .. " -Lens=\"" .. props.lensName .. "\"" 
            c = c .. " -LensModel=\"" .. props.lensName .. "\""
            c = c .. " -LensType=\"" .. props.lensName .. "\"" 
          end

          -- Ignore blank and nil values for LensInfo parameters
          if not isEmpty(props.minFocalLength) then
            local lensInfo = props.minFocalLength
            if not isEmpty(props.maxFocalLength) then
              lensInfo = lensInfo .. " " .. props.maxFocalLength
            else
              lensInfo = lensInfo .. " " .. props.minFocalLength
            end
            if not isEmpty(props.minFStopAtMinFocalLength) then
              lensInfo = lensInfo .. "  " .. props.minFStopAtMinFocalLength
              if not isEmpty(props.minFStopAtMaxFocalLength) then
                lensInfo = lensInfo .. " " .. props.minFStopAtMaxFocalLength
              else
                lensInfo = lensInfo .. " " .. props.minFStopAtMinFocalLength
              end
            else
              -- "When the minimum F number is unknown, the notation is 0/0"
              -- https://www.cipa.jp/std/documents/e/DC-X008-Translation-2019-E.pdf
              lensInfo = lensInfo .. " f/0-0"
            end
            c = c .. " -LensInfo=\"" .. lensInfo .. "\""
          end 

          if not isEmpty(props.focalLength) then
            c = c .. " -FocalLength=\"" .. props.focalLength .. "\""
          end

          if not isEmpty(props.focalLengthIn35mm) then
            c = c .. " -FocalLengthIn35mmFormat=\"" .. props.focalLengthIn35mm .. "\""
          end

          if not isEmpty(props.maxAperture) then
            c = c .. " -MaxAperture=\"" .. props.maxAperture .. "\""
          end
          
          if not isEmpty(props.minAperture) then
            c = c .. " -MinAperture=\"" .. props.minAperture .. "\""
          end

          if not isEmpty(props.lensSerialNumber) then
            c = c .. " -LensSerialNumber=\"" .. props.lensSerialNumber .. "\""
          end

          if not isEmpty(props.fStop) then
            -- Updating both the -FNumber and -ApertureValue per this thread
            -- https://exiftool.org/forum/index.php?topic=5311.msg25773#msg25773
            c = c .. " -FNumber=\"" .. props.fStop .. "\""
            c = c .. " -ApertureValue=\"" .. props.fStop .. "\""
          end

          if not isEmpty(props.exposureTime) then
            c = c .. " -ExposureTime=\"" .. props.exposureTime .. "\""
          end

          -- Ingore minor errors
          c = c .. " -m"

          -- Overwrite the Original in Place
          c = c .. " -overwrite_original_in_place"

          -- Preserve file modification date/time
          c = c .. " -P" 

          -- Update the UserComment to indicate this was edited by Refraktor
          c = c .. " \"-UserComment=RefraktorVer:0.0.1\""
          
          if props.useFileList == true then
            -- Treat the fileList as a utf8 encoded file
            c = c .. " -charset filename=utf8"
            -- Tell Exiftool to use the file list
            c = c .. " -@ " .. props.fileList
          else
            if #photos > 1 then
              -- We need to update this to have the option for a filelist
              for _, p in ipairs(photos) do
                if props.exportXMP == true then
                  local filename = LrPathUtils.removeExtension(p.path)
                  c = c .. " \"" .. filename .. ".xmp" .. "\""
                else
                  c = c .. " \"" .. p.path .. "\""
                end
              end
            else
              if props.exportXMP == true then
                local filename = LrPathUtils.removeExtension(photo.path)
                c = c .. " \"" .. filename .. ".xmp" .. "\""
              else
                c = c .. " \"" .. photo.path .. "\""
              end
            end
          end
          -- Set verbosity and output file
          c = c .. " -v0 > " .. props.outputLog

          c = c .. "\"" -- Closing quote for the whole command

          props.command = c
        end -- end function
      },

      f:push_button {
        width = 115,
        title = "Run Command",
        enabled = true,
        action = function()
          if props.editCommand == true then
            LrDialogs.message(
              "Please finish editing the command",
              "The Edit Command box is checked",
              "warning"
            )
            props.statusText = "Error - Edit Box is checked"
            return nil
          end -- End if

          if isEmpty( props.command ) then
            props.statusText = "Error - Command is blank\nPlease press \"Update Command\""
            return nil
          end

          LrTasks.startAsyncTask( function()
            props.statusText = "Status - Starting command"
            exitCode = LrTasks.execute( props.command )
            if exitCode ~= 0 then
              props.statusText = "Error - Exit Code: " .. tostring(exitCode)
              return nil
            end -- End if

            props.statusText = "Success - Lightroom is refreshing Metadata"
            for _, photo in ipairs(photos) do
              photo:readMetadata()
              LrTasks.sleep(0.1)
            end -- End for
            props.statusText = "Success"

            -- Echo out that we are finished to the log file
            local exitCode = LrTasks.execute("echo Operation Complete >> " .. props.outputLog)
            if exitCode ~= 0 then
              props.statusText = "Error - Failed to echo?"
            end -- End if
          end, "runCommand") -- End startAsyncTask
        end -- End Function
      } -- End f:push_button
    }, -- End Update and Run Command buttons
      

    f:row {  -- a divider
      spacing = f:control_spacing(),
      f:separator {
        fill_horizontal = 1,
      },
    }, -- End Divider

    f:row { -- Status text
      spacing = f:dialog_spacing(),
      bind_to_object = props,
      f:static_text {
        title = bind( "statusText" ),
        width_in_chars = 42,
        height_in_lines = 2,
      }
    },
  }


  local result = LrDialogs.presentModalDialog( -- Invoke the dialog box
    {
      title = "Refraktor", 
      contents = contents, -- UI elements defined earlier
      actionVerb = "Close", -- Replaces the OK button
    }
  )
  if result == "ok" then
    for _,v in ipairs( fieldsToProcess ) do
      prefs[v] = props[v]
    end
    prefs.exifPath    = props.exifPath
    prefs.useFileList = props.useFileList
    prefs.command     = props.command
    prefs.backupFile  = backupFile
    prefs.exportXMP   = props.exportXMP

    -- Save the lenses to backup file
    jsonText = json.encode(prefs.lensProfiles)
    f = io.open( backupFile, "w+")
    io.output(f)
    io.write(jsonText)
    io.close(f)
  end -- end if
end -- End LrFunctionContext.callWithContext
)