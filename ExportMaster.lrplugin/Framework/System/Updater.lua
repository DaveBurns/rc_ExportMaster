--[[
        Updater.lua
        
        Note: this could encapsulate check-for-update and uninstall too, but doesn't, yet.
              Initial motivation is so plugin can customize updating without extending app object.
--]]


local Updater, dbg = Object:newClass{ className= 'Updater', register=true }



--- Constructor for extending class.
--
--  @param      t       initial table - optional.
--
function Updater:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance object.
--      
--  @param      t       initial table - optional.
--
--  @usage      Construct new updater with the default of no copy exclusions, and excluding preferences from being seen as extraneous and purging.
--
function Updater:new( t )
    local o = Object.new( self, t )
    o.copyExcl = o.copyExcl or {} -- no default copy protection.
    o.purgeExcl = o.purgeExcl or { "^Preferences[\\/]" } -- don't purge preferences
    return o
end



--- Migrate special plugin files.
--
--  @usage      In case some files require special handling instead of just copying.<br>
--              Prime examples are auto-generated metadata module files.<br>
--              Excludes preferences which are handled more specifically (see migrate-prefs method).
--
function Updater:migrateSpecials()
    local errs = 0
    -- self.service.scope:setCaption( "Copying files" )
    return errs
end



--- Migrate plugin preferences.
--
--  @usage      Default implementation simply transfers plugin preference backing files.<br>
--              Override in extended class to translate legacy preferences (backed or reglar) to new, if desired.
--
--  @return     number of errors encountered.
--
function Updater:migratePrefs()
    if self.me == self.target then
        app:log( "Not migrating prefs since I'm the target." )
        return 0
    end
    local mePrefDir = LrPathUtils.child( self.me, "Preferences" )
    local destPrefDir = LrPathUtils.child( self.target, 'Preferences' ) -- dest is synoymous with target.
    local errs = 0
    if fso:existsAsDir( mePrefDir ) then
        if fso:existsAsDir( destPrefDir ) then -- updating plugin supports pref backing too
            local count = 0
            for filePath in LrFileUtils.recursiveFiles( mePrefDir ) do
                self.service.scope:setCaption( "Copying files" ) -- this needs to be there to "goose" the delayed progress indicator, but I'm not trying to give too much info.
                local leaf = LrPathUtils.leafName( filePath )
                local name = LrPathUtils.removeExtension( leaf )
                local destPath = LrPathUtils.child( destPrefDir, leaf )
                if name ~= 'Default' then
                    count = count + 1
                    local overwrite
                    if fso:existsAsFile( destPath ) then
                        app:log( "Overwriting named pref file: " .. destPath )
                        overwrite = true
                    else
                        overwrite = false
                    end
                    local s, m = fso:copyFile( filePath, destPath, false, overwrite ) -- pref directory pre-verified.
                    Debug.logn( filePath, destPath )
                    if s then
                        app:log( "Migrated preference backing file from ^1 to ^2", filePath, destPath )
                    else
                        app:logError( "Unable to migrate pref support file: " .. m )
                        errs = errs + 1
                    end
                else
                    app:log( "Not migrated default preference backing file ^1 to ^2", filePath, destPath )
                end
            end
            if count == 0 then
                app:log( "No named preferences found to migrate." )
            end
        else
            app:log( "Updated plugin does not support preference backing, ignoring source preference backing files - please visit plugin manager to update configuration." )
        end
    else
        app:log( "No source preferences to migrate" )
    end
    return errs
end



--- Determine if a particular sub-path is to be excluded from copying from source of update to target.
--
--  @param f        sub-path relative to lrplugin dir
--
function Updater:isCopyExcluded( f )
    for i, v in ipairs( self.copyExcl ) do
        if f:find( v ) then
            return true
        end
    end
    return false
end



--- Determine if a particular sub-path is to be excluded from purging from updated target.
--
--  @param f        sub-path relative to lrplugin dir
--
function Updater:isPurgeExcluded( f )
    for i, v in ipairs( self.purgeExcl ) do
        if f:find( v ) then
            return true
        end
    end
    return false
end



--- Sync source tree to target tree.
--
function Updater:syncTree()
    local errs = 0
    for src in LrFileUtils.recursiveFiles( self.src ) do
        self.service.scope:setCaption( "Copying files" )
        local subPath = LrPathUtils.makeRelative( src, self.src )
        local dest = LrPathUtils.child( self.target, subPath )
        if not self:isCopyExcluded( subPath ) then
            local s, m = fso:copyFile( src, dest, true, true )
            if s then
                app:log( "Copied ^1 to ^2", src, dest )
            else
                errs = errs + 1
                app:log( "Unable to copied plugin file, error message: ^1", m )
            end
        else
            app:log( "Excluded from copy: " .. subPath )
        end
    end
    local extras = {}
    for dest in LrFileUtils.recursiveFiles( self.target ) do
        self.service.scope:setCaption( "Copying files" ) -- not exactly correct, but...
        local subPath = LrPathUtils.makeRelative( dest, self.target )
        local src = LrPathUtils.child( self.src, subPath )
        if not self:isPurgeExcluded( subPath ) then
            if not fso:existsAsFile( src ) then
                extras[#extras + 1] = dest
                app:log( "Extraneous: " .. dest )
            end
        else
            app:log( "Excluded from purge: " .. subPath )
        end
    end
    if #extras > 0 then
        app:log( "^1 in ^2", str:plural( #extras, "extraneous file" ), self.target )
        local answer
        repeat
            if app:logVerbose() or app:isAdvDbgEna() or ( app:getUserName() == '_RobCole_' ) then
                answer = app:show{ confirm="Extraneous files have been found in ^1, ok to delete?\n \nSee log file for details.",
                                   buttons={ dia:btn( "Yes - OK to delete", 'ok' ), dia:btn( "Show Log File", 'showLogs' ), dia:btn( "No - Keep them", 'cancel' ) }, subs=self.target }
            else
                answer = 'ok'
            end
            if answer == 'ok' then
                for i, v in ipairs( extras ) do
                    local s, m = fso:moveToTrash( v )
                    if s then
                        app:log( "Moved to trash or deleted ^1", v )
                    else
                        errs = errs + 1
                        app:logErr( "Unable to move extraneous plugin file to trash, error message: ^1", m )
                    end
                end
                break
            elseif answer == 'showLogs' then
                app:showLogFile()
            elseif answer == 'cancel' then
                break                
            else
                error( "bad answer: " .. answer )
            end
        until false            
    else
        app:log( "No extraneous files in ^1 to move to trash.", self.target )
    end
    return errs
end




--- Updates plugin to new version (must be already downloaded/available).
--
function Updater:updatePlugin()
    app:call( Service:new{ name = 'Update Plugin', async=true, guard=App.guardVocal, main=function( service )
        -- Its legal to have two copies of the same plugin installed, but only one can be enabled.
        -- so make sure its the enabled one that's being updated.
        self.service = service
        if app:isPluginEnabled() then
            -- good
        else
            app:show{ warning="Plugin must be enabled to be updated." }
            service:cancel()
            return
        end
        if gbl:getValue( 'background' ) then
            local s, m = background:pause() -- Note: do NOT continue background processing after update.
            -- Might be better to stop instead of pausing, but I'm not sure stopping is as robust as pausing is now - same for all practical purposes I think.
            if s then
                -- good: won't be running.
            else
                app:logErr( "Unable to pause background processing for sake of update, error message: ^1\n \nDisable background processing then try upating plugin again.", m )
                service:abort( "Unable to pause background processing" ) -- may be something useful in log file.
                return
            end
        end
        local id = app:getPluginId()
        local dir
        if app:getUserName() == '_RobCole_' then
            if app:isAdvDbgEna() then
                dir = "X:\\Dev\\LightroomPlugins\\RC_ExifMeta\\ReleasePackageContents\\ExifMeta.lrplugin"
            else
                dir = "X:\\Dev\\LightroomPlugins"
            end
        else
            dir = "/"
        end
        self.src = dia:selectFolder { -- source of the update
            title = "Choose newly downloaded (and unzipped) plugin folder (name must end with .lrplugin)",
            -- 'prompt' ignored by (OS) folder chooser.
            initialDirectory = dir,
            fileTypes = { ".lrplugin", ".lrdevplugin" }, -- ignored by OS chooser, but respected by select-folder method.
        }
        if self.src then
            local appData = LrPathUtils.getStandardFilePath( 'appData' )
            assert( fso:existsAsDir( appData ), "Where's Lr app-data?" )
            local modulesPath = LrPathUtils.child( appData, "Modules" ) -- may or may not already exist.
            if fso:existsAsDir( modulesPath ) then
                app:log( "Updating in existing modules directory: " .. modulesPath )
            else
                local s, m = fso:assureAllDirectories( modulesPath )
                if s then
                    app:log( "Updating into freshly created modules directory: " .. modulesPath )
                else
                    error( "Unable to directory for updated plugin: " .. str:to( m ) )
                end
            end
            self.name = LrPathUtils.leafName( self.src ) -- name of the update
            self.base = LrPathUtils.removeExtension( self.name ) -- base-name of the update
            self.me = _PLUGIN.path -- identity of the plugin doing the updating.
            self.target = LrPathUtils.child( modulesPath, self.name )
            if self.src == self.me then
                local parent = LrPathUtils.parent( self.src )
                if parent ~= modulesPath then
                    if dia:isOk( "Are you sure you want to update the same plugin?\n \nthus effectively moving it to " .. modulesPath ) then
                        app:log( "Moving plugin to lr-modules dir: " .. self.target )
                    else 
                        service:cancel()
                        return
                    end
                else 
                    app:show{ warning="Source plugin selected (^1) is this one, and is already running from Lightroom modules directory - can't update it: maybe try selecting a different one.", self.src }
                    service:cancel()
                    return
                end
            end
            if self.src == self.target then
                app:logError( "Source plugin must not already reside in target directory." )
                return
            end
            if self.base ~= str:getBaseName( _PLUGIN.path ) then
                if not dia:isOk( "Source plugin has different filename - are you sure its the same plugin?" ) then
                    service:cancel()
                    return
                end
            end
            if fso:existsAsDir( self.target ) then
                local answer
                if self.me == self.target then
                    app:log( "Plugin updating itself: " .. self.target )
                else
                    app:log( "Plugin updating a foreign instance: " .. self.target )
                    answer = app:show{ confirm="OK to overwrite ^1?", subs=self.target, buttons={ dia:btn( "OK", 'ok' ) } }
                    if answer == 'ok' then
                        -- just proceed to update.
                    elseif answer == 'cancel' then
                        service:cancel()
                        return
                    else
                        error( "bad answer" )
                    end
                end
            else
                app:log( "Updating ^1 for first time to ^2", app:getPluginName(), self.target )
            end

            assert( self.src, "no src" )
            assert( self.target, "no target" )
            
            service.scope = DelayedProgressScope:new {
                title = "Updating plugin",
                functionContext = service.context,
                modal = true,
            }

            local s, m = self:syncTree() -- copy/overwrite files, except for exclusions, then delete the rest.
            if s then
                local errs = self:migratePrefs()
                errs = errs + self:migrateSpecials()
                if errs > 0 then
                    error( "Errors occurred, update not successful: see log file for details." )
                end
                if self.me ~= self.target then -- running plugin is not in modules folder, so it was updated from somewhere else.
                    local notMe = self.me .. "." .. app:getVersionString()
                    local s, m = fso:moveFolderOrFile( self.me, notMe ) -- can cause strange errors under unusual circumstances.
                    service.scope:setCaption( "Done" )
                    service.scope:done()
                    LrTasks.yield()
                    if not s then
                        app:log( "Unable to rename previous plugin, error message: ", m )
                        app:show{ error="Unable to rename original plugin from ^1 to ^2.\n \nAlthough its not necessary for the updated plugin to work, you will have two versions of plugin installed - take care which is enabled.", self.me, notMe }
                    else                    
                        app:log( "Previous plugin was renamed: " .. notMe )
                    end
                    app:log( "Update was successful - after restarting, revisit plugin manager and make sure ^1 is enabled (click 'Enable' button if need be).", app:getPluginName() )
                    app:show{ info="Update was successful - You must restart Lightroom now, then revisit plugin manager and make sure ^1 is enabled (click 'Enable' button if need be).", app:getPluginName() }
                    service:cancel("") -- kill normal service ending message if update was successful (to avoid extraneous error messages)
                else -- running plugin is in modules folder, so was updated in place.
                    service.scope:setCaption( "Done" )
                    service.scope:done()
                    LrTasks.yield()
                    if WIN_ENV then
                        app:show{ info="^1 update successful - either reload plugin (see plugin author section), or restart Lightroom now.", app:getPluginName() }
                    else
                        app:show{ info="^1 update successful - restart Lightroom now.", app:getPluginName() }
                    end
                    service:cancel("") -- haven't seen extraneous error messages in this case, but rather not take a chance...
                end
            else
                error( m )
            end
            
        else
            service:cancel()
        end
    end } )
end



return Updater
