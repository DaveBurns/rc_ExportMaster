--[[
        App:lua
        
        Design priniciple:
        
        App object methods implement primary API between derived plugin classes and app-framework/system.
        
        The idea is: as much as possible, to have a one-obj interface that will not have to change,
        despite potentially extensive changes in the code that implements the framework.
        
        For example, plugins don't interface directly to the preferences, since the preference object / methods may change,
        The app interface for preferences however should not change (as much...).
--]]


local App = Object:newClass{ className= 'App', register=false }

App.guardNot = 0
App.guardSilent = 1
App.guardVocal = 2
App.verbose = true


--- Constructor for extending class.
--
--  @param      t       initial table - optional.
--
function App:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance object.
--      
--  @param      t       initial table - optional.
--
--  @usage      Called from init-lua once all globals have been initialized.
--  @usage      Reads info-lua and creates encapsulated worker-bee objects.
--
function App:new( t )

    local o = Object.new( self, t )

    -- o.guards = {} - *** - seems guarding works better when loading / reloading if guards are global, but I could easily be mistaken - certainly cant justify...
    o.guarded = 0
        
    -- app-wide error/warning stats. Cleared when log cleared, even if no log file.
    -- service saves these to display difference at end-of-service.
    o.nErrors = 0
    o.nWarnings = 0

    -- read info-lua
    local status
    local status, infoLua = pcall( dofile, LrPathUtils.child( _PLUGIN.path, "Info.lua" ) )
    if status then
        o.infoLua = infoLua
    else
        error( infoLua )
    end
    
    math.randomseed( LrDate.currentTime() )

    if LogFile ~= nil then -- log file support is optional, but if logging, its first order of business,
        -- so other things can log stuff as they are being constructed / initialized.
        o.logr = objectFactory:newObject( LogFile )
        -- Note: the following is correct logic as long as one hasn't used a version with and without pref mgr and not cleared prefs in between.
        -- If incorrect, you can remedy by clearing all preferences for this plugin.
    end
    if o.logr then
        o.logr:enable{ verbose = ( prefs.logVerbose or prefs._global_logVerbose ) } -- *** could be smoother, but as long as I can search for -global-
            -- I can find all cases where this corner has been cut.
        if o.logr.verbose then
            o.logr:logInfo( "Logger enabled verbosely.\n" )
        else
            o.logr:logInfo( "Logger enabled.\n" )
        end
        o.logr:logInfo( LrSystemInfo.summaryString() )
        o.logr:logInfo( "Number of CPUs: " .. LrSystemInfo.numCPUs() )
        o.logr:logInfo( "Memory size: " .. LrSystemInfo.memSize() / 1000000 .. " MB\n")
        o.logr:logInfo( "Lightroom " .. LrApplication.versionString() .. "\n" )
        o.logr:logInfo( "Plugin name: " .. infoLua.LrPluginName )
        o.logr:logInfo( "Plugin path: " .. _PLUGIN.path )
        o.logr:logInfo( "Plugin version: " .. o:getVersionString() ) -- depends on str
        assert( _PLUGIN.id == infoLua.LrToolkitIdentifier, "ID mixup" )
        o.logr:logInfo( "Toolkit ID: " .. _PLUGIN.id )
        o.logr:logInfo( "Plugin enabled: " .. tostring( _PLUGIN.enabled ) .. "\n" )
    end    
    if Preferences then
        o.prefMgr = objectFactory:newObject( Preferences )
    end
    -- updater is global variable.
    o.user = objectFactory:newObject( User ) -- move to here 19/Aug/2011 2:06
    if o.logr then
        o.logr:logInfo( "Plugin username: " .. o.user:getName() )
    end
    o.os = objectFactory:newObject( 'OperatingSystem' )

    return o

end



--- Synchronous initialization
--
--  @usage      Called from Init.lua - initialization done here should be relatively quick and not yield or sleep, to eliminate race conditions between
--              startup and intiation of asynchronous services. Use background task for asynchronous initialization ( with post-init termination if nothing periodic/in-the-background to do ).
--
function App:init()

    -- supports binding to windows / mac specific things in the UI:
    if WIN_ENV then
        self:setGlobalPref( "Windows", true ) -- for binding to things that depend on platform.
        self:setGlobalPref( "Mac", false )
    else
        self:setGlobalPref( "Mac", true )
        self:setGlobalPref( "Windows", false )
    end
    
    self:switchPreset() -- assures presets are initialized before any asynchronous service accesses them,
        -- and before manager-init-prefs is called.
end



--- Determines if plugin is in release state.
--
--  @usage      Its considered a release state if plugin extension is "lrplugin".
--
function App:isRelease()
    return LrPathUtils.extension( _PLUGIN.path ) == 'lrplugin'
end
App.isReleaseMode = App.isRelease -- synonym



--- Determines if plugin can support Lr3 functionality.
--      
--  @usage          Returns false in Lr1 & Lr2, true in Lr3, will still return true in Lr4 (assuming deprecated items persist for one & only one version), false in Lr5.
--
function App:isLr3()
    local lrVerMajor = LrApplication.versionTable().major
    if LrApplication.versionTable ~= nil then
        return lrVerMajor >= 3 and lrVerMajor <= 4
    else
        return false
    end
end



--- Is app operating in verbose/debug mode, or normal.
--
function App:isVerbose()
    return app:getGlobalPref( 'logVerbose' )
end



--- Test mode detection.
--  
--  <p>Test mode was invented to support test-mode plugin operation, and especially file-ops (rc-common-modules), which were guaranteed not to modify any files unless real mode.
--  For better or for worse, this functionality has been dropped from disk file-system class, but could still be used on an app-by-app basis.</p>
--
--  @usage      If test-mode functionality is desired, then set up a UI and bind to test-mode as global pref.
--
function App:isTestMode()
    return app:getGlobalPref( 'testMode' ) or false
end



--- Real mode detection.
--      
--  <p>Convenience function for readability: opposite of test mode.</p>
--
--  @see        App:isTestMode
--
function App:isRealMode()
    return not self:isTestMode()
end



--- Create a new preference preset.
--
function App:createPreset( props )
    if self.prefMgr then
        self.prefMgr:createPreset( props )
    end
end



--- Switch to another preference preset.
--
function App:switchPreset( props )
    if self.prefMgr then
        self.prefMgr:switchPreset( props )
    end
end



--- Set global preference.
--
--  @param name pref name
--  @param val pref value
--
--  @usage use this instead of setting directly, to make sure the proper key is used.
--
function App:setGlobalPref( name, val )
    if self.prefMgr then
        self.prefMgr:setGlobalPref( name, val )
    else
        prefs[name] = val -- bypasses global prefix if no pref manager.
    end
end



--- Get global preference.
--
--  @param name pref name
--
--  @usage use this instead of setting directly, to make sure the proper key is used.
--
function App:getGlobalPref( name )
    if self.prefMgr then
        return self.prefMgr:getGlobalPref( name )
    else
        return prefs[name] -- bypasses global prefix if no pref manager.
    end
end



--- Get binding that uses the proper key.
--
--  <p>UI convenience function that combines getting a proper global preference key, with creating the binding...>/p>
--
--  @param name pref name
--  @param val pref value
--
--  @usage use this for convenience, or bind directly to get-global-pref-key if you prefer.
--
function App:getGlobalPrefBinding( name )
    local key = self:getGlobalPrefKey( name )
    return bind( key )
end



--- Get binding that uses the proper key.
--
--  <p>UI convenience function that combines getting a proper preference key, with creating the binding...>/p>
--
--  @param name pref name
--  @param val pref value
--
--  @usage *** One can bind directly to props in plugin manager, since set-pref is wired to prop change<br>
--             this is for prompts outside plugin manager, that will change plugin manager preset pref too.
--  @usage use this for convenience, or bind directly to get-pref-key if you prefer.
--
function App:getPrefBinding( name )
    local key = self:getPrefKey( name )
    return bind( key )
end



--- Init global preference.
--
--  @param name global pref name.
--  @param dflt global pref default value.
--
--  @usage a-kin to init-pref reglar, cept for global prefs...
--
function App:initGlobalPref( name, dflt )
    if not str:is( name ) then
        error( "Global preference name key must be non-empty string." )
    end
    if self.prefMgr then
        self.prefMgr:initGlobalPref( name, dflt )
    elseif prefs then
        if prefs[name] == nil then
            prefs[name] = dflt
        end
    else
        error( "No prefs." )
    end
end



--- Get global preference key for binding.
--
--  @param name global pref name.
--
--  @usage not usually needed since there's get-global-pref-binding function,
--         <br>but this is still needed for binding section synopsis's.
--
function App:getGlobalPrefKey( name )
    if self.prefMgr then
        return self.prefMgr:getGlobalKey( name )
    else
        return name -- bypasses global prefix if no pref manager.
    end
end



--- Get preference key for binding.
--
--  @param name pref name.
--
--  @usage not usually needed since most preset prefs are defined in plugin manager via binding to props wired to set-pref<br>
--         and also there's the get-pref-binding function, but this could be used in unusual circumstances maybe - say if local pref being used in section synopsis.
--
function App:getPrefKey( name )
    if self.prefMgr then
        return self.prefMgr:_getPrefKey( name ) -- they're "friends".
    else
        return name -- bypasses preset prefix if no pref manager.
    end
end



--- Get global preference name given key.
--
--  @param name global pref key.
--
--  @usage not usually needed, but useful for pref change handler functions when handling arrays of keys.
--
function App:getGlobalPrefName( key )
    if self.prefMgr then
        return key:sub( 9 ) -- return part after the '_global_'.
    else
        return key -- bypasses global prefix if no pref manager.
    end
end



--- Preset name change handler.
--
--  @usage  Preferences module may be assumed if preset name is changing.
--
--  @usage  Wrapped externally.
--
function App:presetNameChange( props, name, value )
    if not str:is( value ) then
        self.prefMgr.setGlobalPref( 'Default' ) -- Let entering of blank preset be same as entering 'Default'...
        return -- Change will be processed *after* returning (recursion guard keeps it from happening before returning, but does not keep it from happening ever).
    end
    local presetName = self.prefMgr:getPresetName()
    if presetName ~= 'Default' then
        if self.prefMgr:isPresetExisting( value ) then -- go through App?
            self:switchPreset( props ) -- creates new set with backing file if appropriate then loads into props.
            app:show{ info="Preferences switched to preset: ^1", value, actionPrefKey="Switched to named preset" }
        else
            if dia:isOk( "Create a new preset named '^1'?", presetName ) then
                self:createPreset( props ) -- creates new set with backing file if appropriate then loads into props.
                app:show{ info="New preset created: ^1", value, actionPrefKey="Created new named preset" }
            else
                app.prefMgr:setGlobalPref( 'presetName', 'Default' ) -- gotta get rid of new value, but its been pre-commited (dunno what it used to be).
                self:switchPreset( props )
                app:show{ info="Reloaded default preset.", actionPrefKey="Switched to named preset" }
            end
        end
    else
        -- self.prefMgr:setGlobalPref( 'presetName', '' ) -- in case its not already (will not trigger recursion, since silently guarded).
            -- will however cause a double load if preset name change is being called NOT from a change handler.
        self.prefMgr:setGlobalPref( 'presetName', 'Default' ) -- I think this is OK - keeps the double-change from happening anyway.
        self:switchPreset( props )
        app:show{ info="Reverted to default preset.", actionPrefKey="Switched to named preset" }
    end
end



--- Clear all preferences for this plugin.
--
--  @usage Generally only called in response to button press when adv-Debug.logn-enabled and prefs are managed.
--         <br>but could be called in init-lua or wherever if you like - for testing and debug only...
--
--  @usage Works for managed as well as un-managed preferences.
--
function App:clearAllPrefs( props )
    for k,v in prefs:pairs() do -- note: nil prefs are not delivered by pairs function.
        prefs[k] = nil
    end
    for k,v in props:pairs() do -- note: nil prefs are not delivered by pairs function.
        props[k] = nil
    end
end



--- Loads (plugin manager) properties from named set or unnamed.
--      
--  @param      props       The properties to load.
--
--  @usage      Handles case when preference preset manager is installed, or not.
--
function App:loadProps( props )

    if self.prefMgr then
        self.prefMgr:loadProps( props )
    else
        -- this stolen from preferences-lua.
        for k,v in prefs:pairs() do
            local p1, p2 = k:find( '__', 1, true )
            if p1 and ( p1 > 1 ) then
                -- ignore manage preferences from previous incarnations.
            else
                -- Debug.logn( "loading unnamed pref into prop: ", str:format( "prop-name: ^1, val: ^2", k, str:to( v ) ) )
                --if k == 'testData' then
                --    Debug.logn( "loading unnamed test data preference into property" )
                --end                    
                props[k] = v -- note: this will pick up all the globals too, but hopefully won't matter, since they won't be on the view.
            end
        end
    end

end



--- Save properties in preferences.
--      
--  @param      props       The properties to save.
--
--  @usage      file-backing is read-only.
--  @usage      As coded, this only applies to named presets when preset-name property changes.
--
function App:saveProps( props )

    if self.prefMgr then
        self.prefMgr:saveProps( props )
    else
        -- *** presently all are saved in manager using setpref.
    end

end



--- Get number of errors logged since logger was cleared (or app startup).
--
function App:getErrorCount()
    return self.nErrors
end



--- Get number of warnings logged since logger was cleared (or app startup).
--
function App:getWarningCount()
    return self.nWarnings
end



--- Get log file contents as text string.
--
--  <p>Invented to support Dialog function (kluge) to copy log contents to clipboard.</p>
--
function App:getLogFileContents()
    if self.logr then
        return self.logr:getLogContents()
    else
        return nil, "No logger."
    end
end



---     Not usually needed, since show-log-file and send-log-file are both app interfaces.
--      
--      In any case, it may be handy...
--
function App:getLogFilePath()
    if self.logr then
        return self.logr:getLogFilePath()
    else
        return nil
    end
end



---     Determines if advanced debug functionality is present and enabled.
--      
--      May be useful externally before embarking in time consuming loops that are no-op if not enabled.
--
function App:isAdvDbgEna()
    -- if self.advDbg and self:getGlobalPref( 'advDbgEna' ) then
    if self:getGlobalPref( 'advDbgEna' ) then
        return true
    else
        return false
    end
end



---     Shows log file to user by opening in default app for .log.
--      
--      I assume if no default set up, the OS will prompt user to do so(?)
--
function App:showLogFile()

    if self:isLoggerEnabled() then
        local logFile = self.logr:getLogFilePath()
        if fso:existsAsFile( logFile ) then
            local path = self.logr:getLogFilePath()
            self:openFileInDefaultApp( path, true )
        else
            self:show( { info="There are no logs to view (log file does not exist)." } )
        end        
    else
        self:show( { info="There is no log file to show." } )
    end

end



---     Clear the contents of the log file and the logged error/warning counts.
--
function App:clearLogFile()

    self.nErrors = 0
    self.nWarnings = 0

    if self:isLoggerEnabled() then
        self.logr:clear()
    else
        self:show( { info="There is no log file to clear, nevertheless: error+warning counts have been zeroed." } )
    end

end



--- Get name of function or calling function...
--
--  @param      spec (number or string, default=2) 0 for "this" function, 1 for calling function..., or alternate mnemonic for "this" function.
--
--  @usage      for debug message display.
--
--  @return     string - never nil nor empty
--
function App:func( her )
    local level = her or 2
    local funcInfo = debug.getinfo( level, 'n' )
    if funcInfo ~= nil and str:is( funcInfo.namewhat ) then -- name found
        return funcInfo.namewhat .. " function " .. str:to( funcInfo.name )
    end
    if level == 2 then
        return str:fmt( "this function" )
    elseif level == 3 then
        return "calling function"
    else
        return "unknown function"
    end
end



--- Show info to user.
--
--  @deprecated in favor of universal show method, which supports formatting, and named parameter passing.
--
--  @usage      See Dialog class for param descriptions.
--
function App:showInfo( info, actionPrefKey, buttons, cancelButton, otherButton )
    -- return dialo g : s how Inf o (  info, actionPrefKey, buttons, cancelButton, otherButton ) - legacy function: deprecated.
    local answer
    local namedParams = { info=info, actionPrefKey=actionPrefKey }
    if buttons then
        local b = {}
        if type( buttons ) == 'string' then
            b[#b + 1] = {label=buttons,verb='ok'}
            if cancelButton then
                namedParams.cancelLabel = cancelButton
            end
            if otherButton then
                b[#b + 1] = {label=otherButton,verb='other'}
            end
        elseif type( buttons ) == 'table' then
            b = buttons
            -- cancel handled in default fashion in this case.
        end
        namedParams.buttons = b
    end
    return app:show( namedParams ) -- formatting not supported.
end



--- Show info to user - supports formatting.
--
--  @usage      See Dialog class for param descriptions.
--  @usage      New calling option (info as table):
--                  local answer = app:show({ info="^1 is a ^2", actionPrefKey="promptOrNot", buttons={ { label="My OK Button", verb="ok" }, { label="3rd Button", verb='othered' } } },
--                                            "Jane", "Doe" ) -- note: buttons still need to be in a table when there's an action-pref.
--                  answer = app:show({ info="^1 is a ^2", okButton="My OK Button", cancelButton="Please Dont Cancel", otherButton="3rd Button" },
--                                     "John", "Buck" ) -- note: buttons are just strings, returns are fixed.
--
function App:show( message, ... )
    return dialog:messageWithOptions( message, ... )
end



--- Show warning to user.
--
--  @deprecated in favor of universal show method.
--
--  @usage      See Dialog class for param descriptions.
--
function App:showWarning( info, buttons, cancelButton, otherButton )
    -- return di alo g : s how W arning ( info, b1, b2, b3 ) - obsolete
    local answer
    local namedParams = { warning=info } -- no action-pref-key
    if buttons then
        local b = {}
        if type( buttons ) == 'string' then
            b[#b + 1] = {label=buttons,verb='ok'}
            if cancelButton then
                namedParams.cancelLabel = cancelButton
            end
            if otherButton then
                b[#b + 1] = {label=otherButton,verb='other'}
            end
        elseif type( buttons ) == 'table' then
            b = buttons
            -- ###2 cancel-label?
        end
        namedParams.buttons = b
    end
    return app:show( namedParams ) -- formatting not supported.
end
App.showWarn = App.showWarning -- so its like log method.



--- Show error to user.
--
--  @deprecated in favor of universal show method.
--
--  @usage      See Dialog class for param descriptions.
--
function App:showError( info, buttons, cancelButton, otherButton )
    -- return di al og : s ho wEr r or( info, b1, b2, b3 ) - obsolete
    local answer
    local namedParams = { error=info } -- no action-pref-key
    if buttons then
        local b = {}
        if type( buttons ) == 'string' then
            b[#b + 1] = {label=buttons,verb='ok'}
            if cancelButton then
                namedParams.cancelLabel = cancelButton
            end
            if otherButton then
                b[#b + 1] = {label=otherButton,verb='other'}
            end
        elseif type( buttons ) == 'table' then
            b = buttons
            -- ###2 cancel-label?
        end
        namedParams.buttons = b
    end
    return app:show( namedParams ) -- formatting not supported.
end
App.showErr = App.showError -- so its like log method.



--- Determine if app has a logger that can be used.
--      
--  <p>Purpose is to circumvent log loops or other functionality
--  that only makes sense if there is a logger.</p>
--      
--  <p>Presently it does not indicate if the logger is enabled for logging or not,
--  however, if there is a logger, then it is enabled - for now. - Non-logging plugins
--  are not even supported. But they don't have to log anything they don't want to,
--  so it does not have to slow them down much - still the future may change this.</p>
--
function App:isLoggerEnabled()
    return self.logr ~= nil
end



--- Open file in OS default app.
--
--  @param file     The file to open.
--
--  @usage  Presently supports just one file, but could be enhanced to support multiple files.
--  @usage  throws error if attempt fails.
--  @usage  does NOT pre-check for file existence so do so before calling.
--
--  @return status true iff worked (false means user canceled).
--  @return message non-nil iff didn't work.
--
function App:openFileInDefaultApp( file, prompt )
    local ext = LrPathUtils.extension( file )
    local dotExt = "." .. ext
    local promptKey = 'About to open file in default app for ' .. dotExt
    --local promptKey2 = 'Opened file in default app for ' .. dotExt - too much
    if prompt and ext ~= 'txt' and ext ~= 'log' then -- it was the 'lua' files that were causing the real problem.
        local question = "About to open ^1 in default app.\n\nIf no app registered to open ^2 files, this will fail.\n\nNow would be a good time to use your operating system to specify a default for opening ^2 files, if you haven't already.\n\nProceed to open?"
        local answer = app:show{ confirm=question, buttons={ dia:btn( "OK", 'ok' ) }, subs={ file, dotExt }, actionPrefKey=promptKey }
        if answer == 'ok' then
            -- proceed
        else
            return false, "User opted out..."
        end
    end
    local s, anythingQ = LrTasks.pcall( self.os.openFileInDefaultApp, self.os, file )
    if s then
        --if prompt then - too much. it should have worked, and if not, then the error prompt will have to suffice.
        --    local name = LrPathUtils.leafName( file )
        --    app:show( { info="^1 should be open in the default app for ^2 files.", actionPrefKey=promptKey2 }, name, dotExt )
        --end
        return true
    else
        -- assume its an unregistered extension error:
        local m = "Unable to open file in default app - probably because it isn't registered. To remedy, use your operating system to specify an application to open " .. dotExt .. " files."
        error( m )
    end
end



--- Get OS platform name.
--
--  @return     'Windows' or 'Mac'.
--
function App:getPlatformName()
    if WIN_ENV then
        return 'Windows'
    else
        return 'Mac'
    end
end



--- Determine if non-anonymous user.
--      
--  @return     boolean
--
function App:isUser()
    return self.user:is()
end



--- Get name of user.
--      
--  <p>Note: There is no API for entering a user name,
--  however it will be read from shared properties when available.</p>
--      
--  <p>It used to be critical before named preferences came along, now
--  its just there in case you want to alter logic slightly depending
--  on user name - I sometimes customize behavior for myself, that other
--  users will never see...</p>
--      
--  <p>You could make custom versions for a friend or client that does not
--  require a separate plugin nor named preference set.</p>
--
--  @return     user's name: typically "_Anonymous_" if none.
--
function App:getUserName()
    return self.user:getName()
end



--- Executes a shell command.
--
--  <p>Although the format for command/params... is platform independent, the command itself may not be. For example:</p>
--  <blockquote>'exiftool' may be all that is needed to reference a pre-installed version of exiftool on Mac. However, full path may be required on windows,
--  since exiftool installer does not automatically add exiftool to path.</blockquote>
--
--  @param          command         A pathed command name, or absolute path to executable.
--  @param          parameters      Example string: '-G -p "asdf qwerty"'
--  @param          targets         An array of filenames.
--  @param          output          Path to file where command output will be re-directed, or nil for let method decide.
--  @param          handling        nil or '' => do nothing with output, 'get' => retrieve output as string, 'del' => retrieve output as string and delete output file.--
--  @usage          Quotes will be added where necessary depending on platform. The only exception to this is when something in parameter string needs to be quoted.
--
--  @usage          calling context can choose to alter parameters based on user and/or debug mode in order to keep output file(s) for perusal if desired.
--
--  @return         status (boolean):       true iff successful.
--  @return         command-or-error-message(string):     command if success, error otherwise.
--  @return         content (string):       content of output file, if out-handling > 0.
--
function App:executeCommand( command, parameters, targets, output, handling )
    return self.os:executeCommand( command, parameters, targets, output, handling )
end



--- Touch file(s) with current time or specified time.
--
--  @param path (string, required) file or file-mask.
--  @param time (number, default is current time)
--  @param justDate (boolean, default is false) -- if true, sets the date only, time will be 12:00Am I assume.
--
--  @return status
--  @return message
--  @return content
--
function App:touchFile( path, time, justDate )
    local s, cm, c
    if WIN_ENV then
        local f = LrPathUtils.child( _PLUGIN.path, "FileTouch.exe" )
        local p = "/W"
        if time then
            -- app:callingError( "time not supported yet" )
            local d = LrDate.timeToUserFormat( time, "%m-%d-%Y" )
            p = p ..  " /D " .. d
            if not justDate then
                local t = LrDate.timeToUserFormat( time, "%H:%M:%S" )
                p = p ..  " /T " .. t
            end
        -- else silently don't do time explicitly.
        end
        s, cm, c = self:executeCommand( f, p, { path } )
    else
        if time then
            app:callingError( "time not supported yet" )
        else
            p = ""
        end
        s, cm, m = self:executeCommand( "touch", p, { path } )
    end
    return s, cm, c
end



--- Call an operation, with optional variable parameters.
--
--  <p>See 'Call' and 'Service' classes for more information.</p>
--
--  @param      op      Object encapsulating operation to be performed - must extend the 'Call' class.<br><br>
--      
--          Reminder, must include:<br><ul>
--      
--              <li>name
--              <li>main (called as method if object passed)
--              <li>(object - if main is a method)<br><br></ul>
--          
--          Optional:<br><ul>
--          
--              <li>cleanup (also called as method if object passed).
--              <li>async
--              <li>guard</ul><br>
--
--  @param      ...     Passed to main function.
--
--  @usage      Main function call will be wrapped with interactive debug (show-errors) during development,
--              <br>and regular error handling upon production (finale function or default handler - see Call class).
--
--  @return     guarded (boolean, default: nil) true iff call did not commence due to guarding.
--
function App:call( op, ... )

    local param = { ... }
    
    if (op.guard ~= nil) and (op.guard ~= App.guardNot) then
        if guards[op.name] then
            if op.guard == App.guardSilent then
                self.guarded = self.guarded + 1
                --Debug.logn( "Guarded", op.name )
                return nil -- ###1 true
            else -- assume vocal guarding...
                self:show( { warning="^1 already started." }, op.name )
                return nil -- true ###1
            end
        else
            guards[op.name] = true -- record call in progress.
        end
    end

    -- guard MUST be cleared regardless of outcome of guarded call.    
    local function guardCleanup( status, message )
        guards[op.name] = nil
    end
    
    if op.async then
        LrFunctionContext.postAsyncTaskWithContext( op.name, function( context )
            if op.guard then -- no reason to cleanup guards if there ain't none.
                context:addCleanupHandler( guardCleanup )
            end
            op.status, op.message = LrTasks.pcall( op.perform, op, context, unpack( param ) )
            op:cleanup( op.status, op.message ) -- unprotected cleanup handler is how cleanup handlers can propagate errors to outer context, should they choose.
        end )
    else
        op.status, op.message = LrFunctionContext.pcallWithContext( op.name, function( context )
            if op.guard then
                context:addCleanupHandler( guardCleanup )
            end
            op:perform( context, unpack( param ) )
        end )
        op:cleanup( op.status, op.message ) -- unprotected cleanup handler is how cleanup handlers can propagate errors to outer context, should they choose.
    end
    return op.status, op.message, false -- I like this, but not compatible with previously defined return code.
end



--  *** Save just in case...
--  An older obsolete version - suffers from the fact that errors are still propagated to outer context
--  when calls are nested, despite inner call error handling...
--[[function App:____call( op, ... )

    local param = { ... }
    
    if (op.guard ~= nil) and (op.guard ~= App.guardNot) then
        --if self.guards[op.name] then ###2 - see other places like this one.
        if guards[op.name] then
            if op.guard == App.guardSilent then
                self.guarded = self.guarded + 1
                -- Debug.logn( "Guarded", op.name )
                return true
            else
                self:show( { warning="^1 already started." }, op.name )
                return true
            end
        else
            guards[op.name] = true
        end
    end
    
    local cleanup = function( status, message )
        if op.guard then
            guards[op.name] = nil
        end
        LrFunctionContext.callWithContext( "app-call-cleanup", function( context )
            context:addFailureHandler( App.defaultFailureHandler )
            op:cleanup( status, message )
        end )
    end
    
    if op.async then
        LrFunctionContext.postAsyncTaskWithContext( op.name, function( context )
            -- context:addFailureHandler( failure ) - no need for failure handler if you've got a cleanup handler
            context:addCleanupHandler( cleanup )
            op:perform( context, unpack( param ) )
        end )
    else
        LrFunctionContext.callWithContext( op.name, function( context )
            -- context:addFailureHandler( failure ) - no need for failure handler if you've got a cleanup handler
            context:addCleanupHandler( cleanup )
            op:perform( context, unpack( param ) )
        end )
    end
end--]]



--- Start or continue log entry, without terminating it.
--
--  @usage      Useful for starting a log line at the entrance to some code block, then finishing it upon exit, depending on status...
--
function App:logInfoToBeContinued( message, ... )
    if self.logr and message then
        self.logr:logInfoStart( str:fmt( message, ... ) )
    end
end


--- Log info (will append to whatever was "to-be-continued").
--
--  @deprecated use log and log-verbose methods instead, since they support formatting.
--  @param message informational message
--  @param verbose set to App.verbose if the message should only be emitted if verbose logging is enabled.
--
function App:logInfo( message, verbose )
    if self.logr then
        self.logr:logInfo( message, verbose )
    end
end



--- Log info, if more than one param, first is assumed to be a format string.
--
function App:log( message, ... )
    if message then
        self:logInfo( str:fmt( message, ... ) )
    else -- str-fmtr unhappy
        self:logInfo()
    end
end
    


--- Log verbose info, if more than one param, first is assumed to be a format string.
--
function App:logVerbose( message, ... )
    if self.logr then
        local m = str:fmt( message, ... )
        self.logr:logInfo( m, true )
    end
end



--- Count warning and log it with number - supports LOC-based formatting.
--
function App:logWarning( message, ... )
    self.nWarnings = self.nWarnings + 1
    if self.logr then
        self.logr:logWarning( self.nWarnings, str:fmt( message, ... ) )
    end
end
App.logWarn = App.logWarning -- synonym


--- Count error and log it with number - supports LOC-based formatting.
--
function App:logError( message, ... )
    self.nErrors = self.nErrors + 1
    if self.logr then
        self.logr:logError( self.nErrors, str:fmt( message, ... ) )
    end
end
App.logErr = App.logError -- synonym



--- Attempts to break an error message (obtained via lua debug object) into pure text message component, filename, and line number as string.
--
--  @param message (string, required) original error message
--
--  @return error-message sans filename/line-no
--  @return filename or nil
--  @return line number string or nil
--
function App:parseErrorMessage( message )
    local filename, line
    local c1  = message:find( ":", 1, true )
    if c1 then
        filename = message:sub( 1, c1 - 1 )
        if str:is( filename ) then
            local f = filename:match( "%[string \"(.-)\"%]" )
            if str:is( f ) then
                filename = f
            end
        end
        message = message:sub( c1 + 1 )
        c1 = message:find( ":", 1, true )
        if c1 then
            line = message:sub( 1, c1 - 1 )
            message = message:sub( c1 + 2 ) -- skip 1-char space separator.
        end
    end
    return message, filename, line
end



--  Background:             How Lightroom handles errors in plugins:<br><br>
--      
--                          - if error occurs, then check if there is a registered handler,<br>
--                            if so, then call it, if not - do nothing.<br><br>
--                            
--                          - button handlers operate in contexts that do not have error handlers<br>
--                            registered.<br><br>
--
--  Notes:                  - This default failure handler, should be used "instead" of a pcall, in cases<br>
--                            where you you just want to display an error message, instead of croaking<br>
--                            with the default lightroom error message (e.g. normal plugin functions),<br>
--                            or dieing siliently (e.g. button handlers).<br></p>
--
--- Failure handler which can be used if nothing better springs to mind.
--      
--  @param      _false      First parmameter is always false and can be safely ignored.
--  @param      errMsg      Error message.
--
--  @usage                  Generally only used when there is no cleanup handler.
--  @usage                  Note: This is NOT a method.
--
function App.defaultFailureHandler( _false, errMsg )
    local msg = tostring( errMsg or 'program failure' ) .. ".\n\nPlease report this problem - thank you in advance..."
    local plugin
    if rawget( _G, 'app' ) then
        plugin = app:getPluginName()
    else
        plugin = "Plugin"
    end
    LrDialogs.message( LOC( "$$$/X=^1 has encountered a problem.", plugin), "Error message: " .. msg, 'critical' )
end



--- Get app name, which in general is a close derivative of the plugin name.
--
--  @usage I use different plugin names for distinguishing test/dev version and release version,
--         but same appname for both.
--
function App:getAppName()
    if self.infoLua.appName then
        return self.infoLua.appName
    else
        return self:getPluginName()
    end
end



--- Get plugin version number as a string.
--
--  <p>Preferrably without the build suffix, but manageable even with...</p>
--
--  @usage       Correct functioning depends on compatible VERSION format, which is either:
--
--               <p>- major/minor/revision, or
--               <br>- {version-number-string}{white-space}{build-info}</p>
--
--               <p>Plugin generator & releasor generate compatible version numbers / string format.
--               <br>If you are using an other build/release tool, just make sure the xml-rpc-server recognizes
--               <br>the value returned by this method and all should be well.</p>
--               
--               <p>Even if build is tossed in with version number due to omission of expected white-space
--               <br>it will still work as long as xml-rpc-server understands this...</p>
--               
--  @usage       It is up to the xml-rpc-server implementation to make sure if there is a version mismatch
--               between client version and server version, that the server version is always considered "newest".
--
--               <p>In other words, a string equality comparison is done, rather than a numerical version comparison,
--               <br>to determine whether the server version shall be considered "newer".</p>
--
--  @return      Unlike some similarly named app methods, the value returned by this one is used
--               <br>not only for UI display but for checking version number on server via xml-rpc.
--
--               <p>Returns "unknown" if not parseable from info-lua-VERSION...</p>
--
function App:getVersionString()
    local ver
    if self.infoLua.VERSION then
        if self.infoLua.VERSION.major then -- minor + revision implied.
            ver = '' .. self.infoLua.VERSION.major .. '.' .. self.infoLua.VERSION.minor
            if self.infoLua.VERSION.revision > 0 or self.infoLua.VERSION.build > 0 then
                ver = ver .. '.' .. self.infoLua.VERSION.revision
            end
            if self.infoLua.VERSION.build > 0 then
                ver = ver .. '.' .. self.infoLua.VERSION.build
            end
        else -- display is mandatory if no major/minor/revision.
            local split = str:split( self.infoLua.VERSION.display, " " )
            ver = split[1]
        end
    end
    if ver then
        return ver
    else
        return "unknown"
    end
end 



--- Get friendly Lr compatibility display string.
--
--  @return              string: e.g. Lr2+Lr3
--
function App:getLrCompatibilityString()

    local infoLua = self.infoLua    
    
    local lrCompat = "Lr" .. infoLua.LrSdkMinimumVersion
    if infoLua.LrSdkVersion ~= infoLua.LrSdkMinimumVersion then
        lrCompat = lrCompat .. " to Lr" .. infoLua.LrSdkVersion
    else
        -- lrCompat = lrCompat .. " only" -- trying to say too much - may make user think it won't work with dot versions.
        -- Note: an older version of Lightroom won't load it if min ver too high, so the "only" would never show in that case anyway.
        -- Only value then would be on more advanced version of Lightroom. So, its up to the plugin developer to bump that number
        -- once tested on the higher version of Lightroom. Users of higher Lr versions should rightly be concerned until then.
    end
    
    return lrCompat
    
end



--- Get plugin author's name as specified in info-lua.
--
--  @return string: never nil, blank only if explicitly set to blank in info-lua, otherwise something like "unknown".
--
function App:getAuthor()
    return self.infoLua.author or "Unknown" -- new way: set author in info.lua.
end



--- Get plugin author's website as specified in info-lua.
--
--  @return string: never nil, blank only if explicitly set to blank in info-lua, otherwise something like "unknown".
--
function App:getAuthorsWebsite()
    return self.infoLua.authorsWebsite or "Unknown"
end



--- Get plugin url as specified in info-lua.
--
--  @return string: never nil, blank only if explicitly set to blank in info-lua, otherwise something like "unknown".
--
function App:getPluginUrl()
    return self.infoLua.LrPluginInfoUrl or "Unknown"
end



--- Get plugin name as specified in info-lua.
--
--  @return string: required by Lightroom.
--
function App:getPluginId()
    if self.infoLua.pluginId then
        return self.infoLua.pluginId -- overridden.
    else
        return _PLUGIN.id -- standard.
    end
end 



--- Get plugin name as specified in info-lua.
--
--  @return string: required by Lightroom.
--
function App:getPluginName()
    return self.infoLua.LrPluginName or error( "Plugin name must be specified in info-lua." ) -- I don't think we could get this far without it, still...
end 



--- Get friendly string for displaying Platform compatibility - depends on platform support array defined in info-lua.
--
--  @return string: never nil. e.g. Windows+Mac
--
function App:getPlatformString()
    local infoLua = self.infoLua
    if not tab:isEmpty( infoLua.platforms ) then
        return table.concat( infoLua.platforms, "+" )
    else
        return ""
    end
end 



--- Determine if plugin supports Windows OS.
--
--  @return true if definitely yes, false if definitely no, nil if unspecified.
--
function App:isWindowsSupported()
    local infoLua = self.infoLua
    if not tab:isEmpty( infoLua.platforms ) then
        if str:isEqualIgnoringCase( infoLua.platforms[1], 'Windows' ) or str:isEqualIgnoringCase( infoLua.platforms[2], 'Windows' ) then
            return true
        else
            return false
        end
    else
        return nil
    end
end



--- Determine if plugin supports Mac OS.
--
--  @return true if definitely yes, false if definitely no, nil if unspecified.
--
function App:isMacSupported()
    local infoLua = self.infoLua
    if not tab:isEmpty( infoLua.platforms ) then
        if str:isEqualIgnoringCase( infoLua.platforms[1], 'Mac' ) or str:isEqualIgnoringCase( infoLua.platforms[2], 'Mac' ) then
            return true
        else
            return false
        end
    else
        return nil
    end
end



--- Determine if plugin supports current platform.
--
--  @return true if definitely yes, false if definitely no, nil if unspecified.
--
function App:isPlatformSupported()
    local is
    if WIN_ENV then
        is = self:isWindowsSupported()
    else
        is = self:isMacSupported()
    end
    return is
end



--- Determine if plugin supports current Lightroom version.
--
--  @return true iff definitely yes.
--
function App:isLrVersionSupported()
    local infoLua = self.infoLua
    
    local lrVerMajor = LrApplication.versionTable().major
    
    if lrVerMajor <= infoLua.LrSdkVersion then
        -- actual version less than specified version: note this is always OK, since LR would not load if actual version was less than minimimum.
        return true
    else -- lrVerMajor > infoLua.LrSdkVersion 
        -- here's where there is potential for a rub: Lightroom assumes backward compatibility, but I don't - i.e. if Lr is 5 and max Lr is 3, do we really want to run it?
        -- maybe so, and maybe not, but this is what this check is all about...
        return false
    end
end



--- Get Lightroom version name.
--
--  @return e.g. Lightroom 3
--
function App:getLrVersionName()
    local lrVerMajor = LrApplication.versionTable().major
    return 'Lightroom ' .. lrVerMajor
end



--- Check if platform (OS) is supported, and if version of Lightroom is supported. Offer user opportunity to bail if not.
--
--  @usage      Returns nothing - presents dialog if plugin lacks pre-requisite support, and throws error if user opts not to continue.
--  @usage      It is intended that this be called WITHOUT being wrapped by an error handler, so error causes true abortion.
--              <br>Init.lua is a good candidate...
--
function App:checkSupport()
    local op = Call:new{ name='check support', async=false, main=function( call )
        local is = self:isPlatformSupported()
        if is ~= nil then
            if is then
                -- good to go - be silent.
                -- app:show( "Good to go..." )
                self:log( "Platform support verified - certified for " .. self:getPlatformString() )
            else
                if dialog:isOk( str:fmt( "Plugin not officially supported on ^1, want to try your luck anyway?", self:getPlatformName() ) ) then
                    -- continue
                else
                    call:abort( self:getPlatformName() .. " platform not supported." )
                end
            end
        else
            if dialog:isOk( str:fmt( "Plugin author has not specified whether ^1 runs on ^2, want to try your luck anyway?", self:getPluginName(), self:getPlatformName() ) ) then
                -- continue
                self:log( "Continuing without explicitly specified platform support..." )
            else
                call:abort( self:getPlatformName() .. " platform not supported." )
            end
        end
        is = self:isLrVersionSupported()
        if is ~= nil then
            if is then
                -- good to go - be silent.
                -- app:show( "Good to go..." )
                self:log( "Lightroom version support verified - certified for " .. self:getLrCompatibilityString() )
            else
                if dia:isOk( str:fmt( "Plugin not officially supported on ^1, want to try your luck anyway?", self:getLrVersionName() ) ) then
                    -- continue
                else
                    call:abort( str:fmt( "Lightroom version ^1 not supported.", LrApplication.versionString() ) )
                end
            end
        else
            if dialog:isOk( str:fmt( "Plugin author has not specified whether ^1 runs on ^2, want to try your luck anyway?", self:getPluginName(), self:getLrVersionName() ) ) then
                -- continue
                self:logInfo( "Continuing without explicitly specified lightroom version support..." )
            else
                call:abort( str:fmt( "Lightroom version ^1 not supported.", LrApplication.versionString() ) )
            end
        end
    end }
    self:call( op )
    -- the following code depends on async=false.
    if op:isAborted() then
        LrErrors.throwUserError( op:getAbortMessage() )
    end
end



--- Returns string for displaying Platform & Lightroom compatibility.
--
--  <p>Typically this is used in the plugin manager for informational purposes only.
--  Info for program logic best obtained using other methods, since format returned
--  by this function is not guaranteed.</p>
--
--  @return         string: e.g. "Windows+Mac, Lr2 to Lr3"
--
function App:getCompatibilityString()

    local compatTbl = {}
    local platforms = self:getPlatformString()
    if str:is( platforms ) then
        compatTbl[#compatTbl + 1] = platforms
    end
    compatTbl[#compatTbl + 1] = self:getLrCompatibilityString() -- always includes standard stuff
    local compatStr = table.concat( compatTbl, ", " )
    return compatStr

end



--- Does debug trace action provided supporting object has been created, and master debug is enabled.
--
--  <p>Typically this is not called directly, but instead by way of the Debug.logn function returned
--  by the class constructor or object registrar. Still, it is available to be called directly if desired.</p>
--
--  @usage      Pre-requisite: advanced debug enabled, and logger enabled (@2010-11-22 - the latter always is).
--  @usage      See advanced-debug class for more information.
--
function App:debugTrace(...)
    --if self:isAdvDbgLogOk() then -- debug object created and debug enabled and logr available.
    if self:isAdvDbgEna() then -- advanced debug enabled - probably redundent, since dbgr-pause only pauses when enabled, oh well.
        -- self.advDbg:debugTrace( name, id, info )
        -- Debug.pause(...)
        Debug.logn( ... ) -- ###2
    -- else deep-6.
    end
end



--- Output debug info for class if class enabled for debug.
--
--  @usage      Typically this is not called directly, but instead by way of the Debug.logn function returned
--              by the class constructor or object registrar. Still, it is available to be called directly if desired.
--  @usage      Pre-requisite: advanced debug enabled, and logger enabled (@2010-11-22 - the latter always is).
--  @usage      See advanced-debug class for more information.
--
function App:classDebugTrace( name, ...)
    if self:isClassDebugEnabled( name ) then
        -- Debug.pause( name, ... )
        Debug.logn( "'" .. name .. "':", ... ) -- ###2
    end
end



--- Determine if advanced debug support and logger enabled to go with.
--
--  @usage        Typical use for determining whether its worthwhile to embark on some advanced debug support activity.
--  @usage        Consider using Debug proper instead.
--
--  @return       boolean: true iff advanced debug functionality is "all-systems-go".
--
function App:isAdvDbgLogOk() -- ###2 - Really using Debug logr for advanced debugging now.
    return self:isAdvDbgEna() and self.logr
end



--- Determine if class-filtered debug mode is in effect, and class of executing method is specifically enabled.
--
--  <p>Typically not called directly, but indirectly by Debug.logn function, although it can be called directly if desired...</p>
--  
--  @param      name        Full-class-name, or pseudo-class-name(if not a true class) as registered.
--
function App:isClassDebugEnabled( name )
    if self:isAdvDbgEna() then
        if self:getGlobalPref( 'classDebugEnable' ) then -- limitations are in effect
            local propKey = Object.classRegistry[ name ].propKey
            if propKey then
                return self:getGlobalPref( propKey )
            else
                return true -- default to enabled if object not registered for limitation.
            end
        else
            return true
        end
    else
        return false
    end
end



--- Determine if basic app-wide debug mode is in effect.
--      
--  <p>Synonymous with log-verbose.</p>
--
function App:isDebugEnabled()
    return self:getGlobalPref( 'logVerbose' )
end



--- Determine if metadata-supporting plugin is enabled.
--
--  @deprecated in favor of _PLUGIN.enabled instead.
--
--  @param      name (string, default dummy_) name of alternative plugin metadata item (property) to be used.
--  @param      photo (lr-photo, default 1st photo of all) photo to use to check.
--
--  @usage      This method presently only works when a metadata item is defined. Maybe one day it will also work even with no plugin metadata defined.
--  @usage      Only works from an async task.
--
--  @return     enabled (boolean) true iff valid property name and plugin is enabled. Throws error if not called from async task.
--  @return     error message indicating property name was bad or plugin is disabled.
--
function App:isPluginEnabled( name, photo )
    return _PLUGIN.enabled -- there used to be a lot more in this method ;-}
end



--- Get property from info-lua.
--
--  @param      name     The name of the property to get.
--
function App:getInfo( name )

    return self.infoLua[name]

end



--- Logs a rudimentary stack trace (function name, source file, line number).
--
--  @usage      No-op when advanced debugging is disabled.
--      
function App:debugStackTrace()
    --if not self:isAdvDbgLogOk() then -- debug object created and debug enabled and logr available.
    if not self:isAdvDbgEna() then -- advanced debug enabled - now uses independent logger. this is probably redundent.
        return
    end
    -- self.advDbg:debugStackTrace( 3 ) -- skip level 1 (Debug.logn-func) and level 2 (this func).
    Debug.stackTrace( 3 )
end



--- Get the value of the specified preference.
--      
--  @param      name        Preference property name (format: string without dots).
--
--  @usage      Preference may be a member of a named set, or the un-named set.
--  @usage      See Preferences class for more info.
--
function App:getPref( name, presetName )
    if not str:is( name ) then
        error( "Preference name key must be non-empty string." )
    end
    if self.prefMgr then
        return self.prefMgr:getPref( name, presetName )
    elseif prefs then
        return prefs[name]
    else
        error( "No prefs." )
    end
end 



--- Set the specified preference to the specified value.
--      
--  @param      name        Preference property name (format: string without dots).
--  @param      value       Preference property value (type: simple - string, number, or boolean).
--
--  @usage      Preference may be a member of a named set, or the un-named set.
--  @usage      See Preferences class for more info.
--
function App:setPref( name, value )
    if not str:is( name ) then
        error( "Preference name key must be non-empty string." )
    end
    if self.prefMgr then
        self.prefMgr:setPref( name, value )
    elseif prefs then
        prefs[name] = value
    else
        error( "No prefs." )
    end
end 



--- Make sure support preference is initialized.
--
--  <p>Because of the way all this pref/prop stuff works,
--  uninitialized prefs can be a problem, since they are
--  saved into props via pairs() function that won't recognize
--  nil items, thus items that should be blanked, may retain
--  bogus values.</p>
--      
--  @usage      Pref value set to default only if nil.</p>
--      
--  @usage      Make sure init-props is being called to init the props
--              from the prefs afterward.
--
function App:initPref( name, default, presetName )
    if not str:is( name ) then
        error( "Preference name key must be non-empty string." )
    end
    if self.prefMgr then
        self.prefMgr:initPref( name, default, presetName )
    elseif prefs then
        -- preset-name ignored in this case.
        if prefs[name] == nil then
            prefs[name] = default
        end
    else
        error( "No prefs." )
    end
end 



--- Get global preference iterator.
--
--  @param      sortFunc (boolean or function, default false) pass true for default name sort, or function for custom name sort.
--
--  @usage      for iterating global preferences, without having to wade through non-globals.
--
--  @return     iterator function that returns name, value pairs, in preferred name sort order.
--              <br>Note: the name returned is not a key. to translate to a key, call get-global-pref-key and pass the name.
-- 
function App:getGlobalPrefPairs( sortFunc )

    if self.prefMgr then
        return self.prefMgr:getGlobalPrefPairs( sortFunc )
    else
        if sortFunc then
            error( "Preference manager required for sorting global preference pairs." ) -- this limitation could be lifted by some more coding.
        end
        return prefs:pairs()
    end
    
end



--- Get local preference iterator.
--
--  @param      sortFunc (boolean or function, default false) pass true for default name sort, or function for custom name sort.
--
--  @usage      for iterating local preferences, without having to wade through globals.
--
--  @return     iterator function that returns name, value pairs, in preferred name sort order.
--              <br>Note: the name returned is not a key. to translate to a key, call get-global-pref-key and pass the name.
-- 
function App:getPrefPairs( sortFunc )

    if self.prefMgr then
        return self.prefMgr:getPrefPairs( sortFunc )
    else
        if sortFunc then
            error( "Preference manager required for sorting preference pairs." ) -- this limitation could be lifted by some more coding.
        end
        return prefs:pairs() -- locals and globals share same space when not managed.
    end
    
end



--- Delete preference preset.
--
--  @param props - get re-loaded from defaults, or if default set is being "deleted" (reset), then they're reloaded from saved default values.
--
--  @usage which is governed by global preset name pref.
--
function App:deletePrefPreset( props )
    self.prefMgr:deletePreset( props )
end



--- Log a simple key/value table.
--      
--  @usage      *** Deprecated - use Debug function instead.
--  @usage      No-op unless advanced debug enabled.
--  @usage      Does not re-curse.
--      
function App:logTable( t ) -- indentation would be nice - presently does not support table recursion.
    self:logWarning( "app:logTable is deprecated - please use debug function instead." )
    if not self:isAdvDbgLogOk() then
        return
    end
    if t == nil then
        self:logInfo( "nil" )
        return
    end    
    for k,v in pairs( t ) do
        self:logInfo( "key: " .. str:to( k ) .. ", value: " .. str:to( v ) )
    end
end



--- Log any lua variable, including complex tables with cross links. - debug only
--      
--  <p>It could use a little primping, but it has served my purpose so I'm moving on.</p>
--
--  @usage          *** Deprecated - please use Debug function instead.
--  @usage          Can not be used to log _G, everything else thrown at it so far has worked.
--  @usage          Example: app:logObject( someTable )
--      
function App:logObject( t )
    self:logWarning( "app:logObject is deprecated - please use Debug function instead." )
    --if not self:isAdvDbgLogOk() then
    --    return
    --end
    if self:isAdvDbgEna() then
        --self.advDbg:logObject( t, 0 )
        Debug.pp( t ) -- test this
    end
end



--- Log an observable property table. - debug only
--      
--  @usage          No-op unless advanced debug logging is enabled.
--
function App:logPropertyTable( t, name )
    if not self:isAdvDbgLogOk() then
        return
    end
    if t == nil then
        Debug.logn( "property table is nil" )
        return
    end
    if t.pairs == nil then
        Debug.logn( str:to( name ) .. " is not a property table" )
        return
    end
    for k,v in t:pairs() do
        Debug.logn( k , " = ", v )
    end
end



--- Send unmodified keystrokes to lightroom.
--
--  <p>Unmodified meaning not enhanced by Ctrl/Cmd/Option/Alt/Shift...</p>
--      
--  @param      text        string: e.g. "p" or "u", maybe "g"...
--      
--  @usage      Platform agnostic (os specific object does the right thing).
--  @usage      Direct keystrokes at Lightroom proper, NOT dialog boxes, nor metadata fields, ...
--
--  @return     status(boolean): true iff command to send keys executed without an error.
--  @return     message(string): if status successful: the command issued, else error message (which includes command issued).
--
function App:sendKeys( text, noYield )
    local s, m = self.os:sendUnmodifiedKeys( text )
    if not noYield then
        LrTasks.yield()
    end
    return s, m
end



--- Send windows modified keystrokes to lightroom in AHK encoded format.
--      
--  @param      keys    i.e. mash the modifiers together (any order, case sensitive), followed by a dash, followed by the keystrokes mashed together (order matters, but case does not).
--  @param      noYield I've found, more times than not, a yield helps the keystrokes take effect. If yielding after sending the keys is causing more harm than good, set this arg to true.
--
--  @usage      e.g. '{Ctrl Down}s{Ctrl Up}' - note: {Ctrl}s doesn't cut it - probably whats wrong with vbs/powershell versions.
--  @usage      Direct keystrokes at Lightroom proper, NOT dialog boxes, nor metadata fields, ...
--      
--  @return     status(boolean): true iff command to send keys executed without an error.
--  @return     message(string): if status successful: the command issued, else error message (which includes command issued).
--
function App:sendWinAhkKeys( keys, noYield )
    if WIN_ENV then
        local s, m = self.os:sendUnmodifiedKeys( keys ) -- all keystrokes go through ahk.exe file now.
        if not noYield then
            LrTasks.yield() -- ok not done in loop.
        end
        return s, m
    else
        error( "Don't send windows keys on mac." )
    end
end



--  Could have emulated ahk format until ahk works well enough on Mac.
--  For now, plugin author is tasked with issuing two different sequences of things
--  depending on platform.
--      
--- Send mac modified keystrokes to lightroom, in proprietary encoded format as follows:
--      
--  @param      keys    i.e. mash the modifiers together (any order, case sensitive), followed by a dash, followed by the keystrokes mashed together (order matters, but case does not).
--
--  @usage      e.g. 'CmdOptionCtrlShift-FS'
--  @usage      Direct keystrokes at Lightroom proper, NOT dialog boxes, nor metadata fields, ...
--
--  @return     status(boolean): true iff command to send keys executed without an error.
--  @return     message(string): if status successful: the command issued, else error message (which includes command issued).
--
function App:sendMacEncKeys( keys, noYield )
    if MAC_ENV then
        local s, m = self.os:sendModifiedKeys( keys )
        if not noYield then
            LrTasks.yield()
        end
        return s, m
    else
        error( "Don't send mac keys on windows." )
    end
end



--- Checks for new version of plugin to download.
--
--  @param      autoMode        (boolean) set true if its an auto-check-upon-startup mode, so user isn't bothered by version up-2-date message.
--
--  @usage      Requires global xmlRpc object constructed with xml-rpc service URL.
--  @usage      Does not return anything - presents dialog if appropriate...
--
function App:checkForUpdate( autoMode )
    self:call( Call:new{ name = 'Check for Update', async=true, main=function( call )
        local id = self:getPluginId()
        local status, msgOrValues = xmlRpc:sendAndReceive( "updateCheck", id )
        if status then
            local values = msgOrValues
            local currVer = self:getVersionString()
            assert( currVer, "no ver" )
            if #values ~= 2 then
                app:show{ error="Wrong number of values (^1) returned by server when checking for update", #values }
                return
            end
            if type( values[1] ) ~= 'string' then
                app:show{ error="1st return value bad type: ^1", type( values[1] ) }
                return
            end
            if type( values[2] ) ~= 'string' then
                app:show{ error="2nd return value bad type: ^1", type( values[2] ) }
                return
            end
            local latest = values[1]
            local download = values[2]
            if not str:is( download ) then
                download = self:getPluginUrl()
            end
            local name = self:getPluginName()
            if currVer ~= latest then
                -- Debug.logn( "new ver: ", str:format( "^1 from ^2", latest, download ) )
                if dialog:isOk( str:fmt( "There is a newer version of ^1 (current version is ^2).\n \nNewest version is ^3 - click 'OK' to download.", name, currVer, latest ) ) then
                    LrHttp.openUrlInBrowser( download )
                end
            elseif not autoMode then
                app:show{ info="^1 is up to date at version: ^2", name, currVer }
            else
                self:logInfo( str:fmt( "Check for update result: ^1 is up to date at version: ^2", name, currVer ) )
            end
        else
            local msg = msgOrValues
            app:show( msg )
        end
    end } )
end



--- Updates plugin to new version (must be already downloaded/available).
--
function App:updatePlugin()
    if gbl:getValue( 'upd' ) then
        upd:updatePlugin() -- returns nothing.
    else
        self:show( { error="Updater not found - please report this problem - thanks." } )
    end
end



--- Updates plugin to new version (must be already downloaded/available).
--
function App:uninstallPlugin()
    self:call( Call:new{ name = 'Uninstall Plugin', async=true, guard=App.guardVocal, main=function( call )
        -- plugin need not be enabled to be uninstalled.
        local id = self:getPluginId()
        local appData = LrPathUtils.getStandardFilePath( 'appData' )
        local pluginFolderName = LrPathUtils.leafName( _PLUGIN.path )
        local modulesPath = LrPathUtils.child( appData, "Modules" ) -- may or may not already exist.
        local path = LrPathUtils.child( modulesPath, pluginFolderName )
        local name = LrPathUtils.leafName( path )
        local base = LrPathUtils.removeExtension( name )
        if path == _PLUGIN.path then
            if not dia:isOk( str:fmt( "Are you sure you want to remove ^1 from ^2?", app:getPluginName(), path ) ) then
                app:show{ info="Plugin has not been uninstalled - nothing has changed." }
                return
            end
            local answer = app:show{ info="Remove plugin preferences too? *** If unsure, then answer 'No'.",
                                     buttons={ dia:btn( "Yes, permanently remove all plugin preferences", 'ok' ), dia:btn( "No, I'm not sure this is a good idea", 'no' ) } }
            if answer == 'cancel' then
                app:show{ info="^1 has not been uninstalled - nothing has changed.", app:getPluginName() }
                return
            end
            local s, m = fso:moveToTrash( path )
            if s then
                -- prompt comes later (below).
            else
                app:show{ error="Unable to remove plugin, error message: ^1", m }
                return 
            end            
            if answer == 'ok' then
                for k, v in prefs:pairs() do
                    prefs[k] = nil
                end
                app:show{ info="^1 has been uninstalled and its preferences have been wiped clean - restart Lightroom now.", app:getPluginName() }
            elseif answer == 'no' then
                app:show{ info="^1 has been uninstalled, but preferences have been preserved in case of later re-install - restart Lightroom now.", app:getPluginName() }
            else
                error( "bad answer" )
            end
        else
            app:show{ warning="You must use the plugin manager's 'Remove' button to uninstall this plugin." }
        end
    end } )
end



--- Sleep unless shutdown, for 100msec minimum.
--
--  @usage      Called by background tasks primarily, to sleep in 100 msec increments, checking shutdown flag each increment.
--              <br>Returns when time elapsed or shutdown flag set.
-- 
function App:sleepUnlessShutdown( time )
    local startTime = LrDate.currentTime()
    while not shutdown and (LrDate.currentTime() - startTime < time) do
        LrTasks.sleep( .1 )
    end
    return
end



--- Sleep for short while - just yields if amount == 0
--
function App:sleep( amt )
    if amt == nil then
        app:callingError( "can't sleep for nil" )
    elseif amt == 0 then
        LrTasks.yield()
    else
        LrTasks.sleep( amt )
    end
end



--- Yield unless too soon.
--
--  @param      count (number, required) initialize to zero before loop, then pass return value back in, in loop.
--  @param      maxCount (number, default 20 ) number of calls to burn before actually yielding
--
--  @usage      Use instead of lr-tasks-yield in potentially lengthy loops, to avoid poor performance.
--
--  @return     count to be passed back in next call.
--
function App:yield( count, maxCount )
    count = count + 1
    if not maxCount then
        maxCount = 20
    end
    if count >= maxCount then
        LrTasks.yield()
        return 0
    else
        return count
    end
end



--- Get name of explorer or finder.
--
function App:getShellName()
    return self.os:getShellName()
end    



--- Get control-modified keystroke string for display purposes only.
--
--  <p>Purpose is so Mac users don't have to be bothered with Windows syntax, nor vice versa.</p>
--
--  @usage      Not for issuing keystrokes but for prompting user.
--  @usage      For example: str:format( 'Press ^1 to save metadata first...', app:getCtrlKeySeq( 's' ) )
--  @usage      Sorry about the Windows bias to the method name.
--
function App:getCtrlKeySeq( key )
    if WIN_ENV then
        return "Ctrl-" .. key
    else
        return "Cmd-" .. key
    end
end



--- Get control keyboard sequence for running platform.
--
--  <p>Purpose is so Mac users don't have to be bothered with Windows syntax, nor vice versa.</p>
--
--  @usage      Not for issuing keystrokes but for prompting user.
--  @usage      For example: str:format( 'Press ^1 to save metadata first...', app:getCtrlKeySeq( 's' ) )
--  @usage      Sorry about the Windows bias to the method name.
--
function App:getAltKeySeq( key )
    if WIN_ENV then
        return "Alt-" .. key
    else
        return "Opt-" .. key
    end
end



--- Asserts (synchronous) initialization is complete.
--
--  @usage Call at end of plugin's Init.lua module.
--
--  @usage Dumps declared globals to debug log, if advanced debug enabled.
--
function App:initDone()

    --self._initDone = true
    app:log()
    app:log( "Plugin synchronous initialization has completed.\n" )
    if not self:isAdvDbgEna() then return end
    
    Debug.logn( "Globals (declared):" )
    local g = getmetatable( _G ).__declared or {}
    local c = 0
    for k, v in tab:sortedPairs( g ) do
        local value = gbl:getValue( k )
        local className
        if value ~= nil and type( value ) == 'table' and value.getFullClassName then
            className = value:getFullClassName()
            if className == k then
                className = 'Class'
            end
        else
            className = type( value )
        end
        Debug.logn( str:to( k ), str:to( '(' .. className .. ')' ) )
        c = c + 1
    end
    Debug.logn( "Total:" .. c, '\n' )
    Debug.logn( "Undeclared globals:" )
    local c2 = 0
    for k, v in tab:sortedPairs( _G ) do
        if not g[k] then
            Debug.logn( str:to( k ) )
            c2 = c2 + 1
        end
    end
    
    Debug.logn( "Total undeclared globals:" .. c2, '\n' )

    if self:isVerbose() then
        local globalsByFile = Require.newGlobals() -- now cleared.
        Debug.logn( "Global details by file: ", Debug.pp( globalsByFile ) )
    end
    
end



--- Open debug log in default app for viewing.
--
--  @usage wrapped internally
--
function App:showDebugLog()
    self:call( Call:new { name='Show Debug Log', async=not LrTasks.canYield(), main=function( call )
        local logFile = Debug.getLogFilePath()
        if fso:existsAsFile( logFile ) then
            local ext = LrPathUtils.extension( logFile )
            self:openFileInDefaultApp( logFile, true )
        else
            self:show( { info="No debug log file: ^1" }, logFile )
        end
    end } )
end



--- Clear debug log by moving to trash.
--
--  @usage wrapped internally
--
function App:clearDebugLog()
    self:call( Call:new { name='Clear Debug Log', async=true, guard=App.guardSilent, main=function( call )
        local logFile = Debug.getLogFilePath()
        if fso:existsAsFile( logFile ) then
            local s, m = fso:moveToTrash( logFile )
            if s then
                self:show( { info="Debug log cleared." } )
            else
                self:show( { error=m } )
            end
        else
            self:show( { info="No debug log file: ^1" }, logFile )
        end
    end } )
end



--- Find framework resource reference.
--
--  @usage      Only use I know of at present is for displaying a vf-picture.
--  @usage      Supports png - Lr doc says what else...
--  @usage      Assures resource comes from framework and not user plugin resource.
--
--  @return     abs path or nil if no resource. If Adobe changes type, so will this function.
--
function App:findFrameworkResource( name )
    assert( Require.frameworkDir, "No framework dir." )
    local path
    if LrPathUtils.isAbsolute( Require.frameworkDir ) then
        path = LrPathUtils.child( Require.frameworkDir, 'Resources' )
    else
        local dir = LrPathUtils.child( _PLUGIN.path, 'Framework' )
        path = LrPathUtils.child( dir, 'Resources' )
    end
    local file = LrPathUtils.child( path, name )
    if fso:existsAsFile( file ) then
        return file
    else
        return nil -- picture component deals with this OK.
    end
end



--- Get framework resource reference.
--
--  @usage      Only use I know of at present is for displaying a vf-picture.
--  @usage      Supports png - Lr doc says what else...
--  @usage      Assures resource comes from framework and not user plugin resource.
--
--  @return     abs path or nil if no resource. If Adobe changes type, so will this function.
--
function App:getFrameworkResource( name )
    local rsrc = self:findFrameworkResource( name )
    if rsrc then
        return rsrc
    else
        self:logErr( "Missing framework resource: ^1", name )
        return nil -- picture component deals with this by displaying a "blank" picture.
    end
end



--- Get find plugin or framework resource reference.
--
--  @usage      Only use I know of at present is for displaying a vf-picture.
--  @usage      Supports png - Lr doc says what else...
--  @usage      Resource will be searched for in all require-paths, so plugin resources take priority (as long as they are in folder called 'Resource').
--              but will also return framework resources.
--
--  @return     abs path or nil if no resource. If Adobe changes type, so will this function.
--
function App:findResource( name )
    local file = Require.findFile( str:fmt( 'Resources/^1', name ) ) -- searches '.' first, then framework...
    if fso:existsAsFile( file ) then
        return file
    else
        return nil -- picture component deals with this by displaying a "blank" picture.
    end
end



--- Get plugin or framework resource reference.
--
--  @usage      Only use I know of at present is for displaying a vf-picture.
--  @usage      Supports png - Lr doc says what else...
--  @usage      Resource will be searched for in all require-paths, so plugin resources take priority (as long as they are in folder called 'Resource').
--              but will also return framework resources.
--
--  @return     abs path or nil if no resource. If Adobe changes type, so will this function.
--
function App:getResource( name )
    local rsrc = self:findResource( name )
    if rsrc then
        return rsrc
    else
        self:logErr( "Missing resource: ^1", name ) -- if you don't wan't an error logged, use find-resource instead.
        return nil -- picture component deals with this by displaying a "blank" picture.
    end
end



--- Reset Lightroom warning dialogs and custom warning dialogs.
--
--  @usage      Be sure to call this instead of the lr-dialogs one.
--
function App:resetWarningDialogs()
    LrDialogs.resetDoNotShowFlag() -- Take care of anything that did NOT go through the framework API, just in case.
    for k, v in self:getGlobalPrefPairs() do
        if str:isStartingWith( k, 'actionPrefKey_' ) then
            self:setGlobalPref( k, false )
        end
    end
end



--- Throw an error in executing context, with built-in formatting.
--
--  @param          m (string, required) error message.
--  @param          ... formating substitutions.
--
--  @usage          Example: if var == nil then app:error( "var ^1 must not be nil", varNumber )
--
function App:error( m, ... )
    if m == nil then
        m = 'unknown error'
    else
        m = str:fmt( m, ... )
    end
    error( m, 2 ) -- throw in caller of this function.
end



--- Throw an error in calling context, with built-in formatting.
--
--  @param          m (string, required) error message.
--  @param          ... formating substitutions.
--
--  @usage          Example: if param[1] == nil then app:callingError( "param ^1 must not be nil", paramNumber )
--
function App:callingError( m, ... )
    if m == nil then
        m = 'unknown error'
    else
        m = str:fmt( m, ... )
    end
    error( m, 3 ) -- throw in context of function calling caller of this function.
end



return App
