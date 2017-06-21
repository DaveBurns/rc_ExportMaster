--[[
        Service.lua
        
        A service is an operation with an associated log file.
--]]

local Service, dbg = Call:newClass{ className = "Service" }



--- Constructor for extending class.
--
function Service:newClass( t )
    return Call.newClass( self, t )
end



--- New instance constructor.
--      
--  @param      t   Parameter table whose elements are:
--                  <ul>
--                  <li>name: (string, required)<br>
--                  <li>object: (table) instance of class with main and finale methods - optional.<br>
--                  <li>main: (function, required)<br>
--                  <li>async: (boolean, default false) true => asynchronous, false => synchronous.<br>
--                  <li>finale: (function, default nil) executed after main if provided, regardless of whether main errors out.<br>
--                  <li>guard:  (number, default zero) nil or zero => reentrant, App.guardSilent => silent, App.guardVocal => vocal.</ul>
--
--  @usage      see Call class for more info.
--
--  @return     service object suitable for passing to app:call method.
--
function Service:new( t )
    
    local o = Call.new( self, t )
    if o.logFilePath == nil then
        o.logFilePath = _PLUGIN.id .. ".LogFile.txt"
    else
        -- 
    end
    return o
end



--- Initiate and perform main service function, excluding the finale.
--
--  <p>See Call parent class for more info.</p>
--
--  @param  context     function-context, in case you need to create a property table, hopefully thats the only use for it...
--  @param  ...         Passed to main.
--
function Service:perform( context, ... )

    self.startTime = LrDate.currentTime()
    local dateTimeFormat = '%Y-%m-%d %H:%M:%S'
    local startTimeFormatted = LrDate.timeToUserFormat( self.startTime, dateTimeFormat )
    
    self.startErrors = app:getErrorCount()
    self.startWarnings = app:getWarningCount()

    if app:isLoggerEnabled() then

        app:logInfo()
        app:logInfoToBeContinued( str:format( "^1 started ^2", self.name, startTimeFormatted ) )
        if app:isTestMode() then
            app:logInfoToBeContinued( " IN TEST MODE\n- TEST MODE: Theoretically no files were actually created, modified, or deleted.\n" )
        else
            app:logInfoToBeContinued( " IN REAL MODE\n- REAL MODE: Theoretically, files were actually created, modified, or deleted, as indicated.\n" )
        end
    
        if app:isVerbose() then
            app:logInfo( "Logging verbosely." )
            app:logInfo( "Lightroom Version: " .. LrApplication.versionString() )
            app:logInfo( "Plugin Name: " .. app:getPluginName() )
            app:logInfo( "Plugin ID: " .. _PLUGIN.id )
            app:logInfo( "Plugin Version: " .. app:getVersionString() )
            app:logInfo( "Plugin Enabled: " .. str:to( _PLUGIN.enabled ) )
            app:logInfo( "Platform: " .. app:getPlatformName() )
            app:logInfo( "Compatibility: " .. app:getCompatibilityString() )
    
            -- app no longer supports "support files". - Leaving in for nostalgia...
            --[[app:logInfo( "Support files may be specified absolutely or relative to these places, tried in this order:" )
            app:logInfo( "Catalog: " .. LrApplication.activeCatalog().path )
            app:logInfo( "Plugin parent: " .. LrPathUtils.parent( _PLUGIN.path ) )
            app:logInfo( "Plugin proper: " .. _PLUGIN.path )
            -- 'home', 'documents', 'appPrefs', 'desktop', 'pictures': must match order in app class.
            app:logInfo( "Home: " ..  LrPathUtils.getStandardFilePath( 'home' ) )
            app:logInfo( "Documents: " ..  LrPathUtils.getStandardFilePath( 'documents' ) )
            app:logInfo( "Application Preferences: " ..  LrPathUtils.getStandardFilePath( 'appPrefs' ) )
            app:logInfo( "Desktop: " ..  LrPathUtils.getStandardFilePath( 'desktop' ) )
            app:logInfo( "Pictures: " ..  LrPathUtils.getStandardFilePath( 'pictures' ) )--]]
            -- *** My experience has been the default directory would actually be c:/windows/system32 yet the default directory is
            -- being shown as '/'. Since this is misleading, and only reluctantly supported (will return file relative to
            -- default if found but accompanied by a warning), suppress logging of default dir.
        else
            app:logInfo( "Logging non-verbosely." )
        end
    
        app:logInfo()
        app:logInfo("Plugin path: " .. _PLUGIN.path .. '\n' )
       
    end
    
    Call.perform( self, context, ... )
    
end



--- Perform finale...
--
--  <p>See Call parent class for more info.</p>
--
--  @param      status      boolean: true iff execution completed without an error being thrown.
--  @param      message     string: error message corresponding to error if thrown.
--
function Service:cleanup( status, message )

    -- Call.cleanup( self, status, message ) - calls regstered finale method. commented out 17/Oct/2011 since it seems like service cleanup should be protected.
        -- call cleanup is no longer protected so errors can be propagated out of nested calls.
    local cleanupStatus, cleanupMessage = LrTasks.pcall( Call.cleanup, self, status, message ) -- calls regstered finale method.
    
    local function failureHandler( _false, m )
        App.defaultFailureHandler( _false, "Unable to complete service due to a bug in the framework's service cleanup method, error message: " .. m )
    end

    LrFunctionContext.callWithContext( "service cleanup finish", function( context )
        context:addFailureHandler( failureHandler )

        if cleanupStatus then
            if status then
                -- dbg( "cleanup good" )
            else
                app:logError( message or "Unknown error." ) -- log service error message - reminder: no error is logged in base class (call) cleanup method.
                self:abort("Aborted due to error.") -- but continue to display log footer / status.
            end
        else
            app:logError( "Unable to complete '^1' service due to error in cleanup/finale function, error message: ^2", self.name, cleanupMessage )
            self:abort("Aborted due to cleanup/finale error.") -- but continue to display log footer / status.
            status = false -- not presently looked at past here, but...
            if not str:is( message ) then
                message = cleanupMessage -- ditto.
            end
        end

        self.stopTime = LrDate.currentTime()
        local elapsedTimeFormatted = date:formatTimeDiff( self.stopTime - self.startTime )
        self.startTime = nil -- closes the service/export so end-service can be called redundently with impunity.
        
        local nErrors = app:getErrorCount() - self.startErrors -- number of app errors logged while this service was processing.
        local nWarnings = app:getWarningCount() - self.startWarnings -- ditto - warnings.
    
        local dateTimeFormat = '%Y-%m-%d %H:%M:%S'
        local stopTimeFormatted = LrDate.timeToUserFormat( self.stopTime, dateTimeFormat )
    
        app:logInfo( '\n' )
        app:logInfo( str:format( "^1 finished at ^2 (^3 seconds).\n\n\n\n\n", self.name, stopTimeFormatted, elapsedTimeFormatted ) )
    
        if self:isCanceled() or _G.shutdown then -- just be done if canceled.
            return
        end
        
        -- present final dialog box message:
        local msg = nil
        local prefix = ''
        prefix = self.name .. ' '
        if not self:isAborted() then
            if nErrors == 0 then
                msg = prefix .. ' - all done (no errors).\n'
            else
                msg = prefix .. " - done, but " .. str:plural( nErrors, "error" ) ..".\n" 
            end
        else
            -- progress scope has been cancelled.
            if nErrors == 0 then
                msg = prefix .. ' - quit early (but no errors). Reason: ' .. self:getAbortMessage() .. '\n'
            else
                msg = prefix .. " - quit early, and " .. str:plural( nErrors, "error" ) ..".\n" 
            end
        end
        if nWarnings > 0 then
            msg = msg .. str:plural( nWarnings, "warning" ) ..".\n" 
        end
    
    	if app:isLoggerEnabled() then
    		msg = msg .. str:format( "\nSee log file for details: ^1", app:getLogFilePath() )
    	else
    		msg = msg .. str:format( "\nNo log file was created." )
    	end
    	
    	if str:is( self.mandatoryMessage ) then
    	    msg = msg .. "\n \n" .. self.mandatoryMessage
    	end
    
    
        -- present final dialog box.
        local actionPrefKey
        local buttons = nil
        if nErrors == 0 and nWarnings == 0 and app:isRealMode() and not str:is( self.mandatoryMessage ) then
            actionPrefKey = self.name .. " - view logs"
            if app:isLoggerEnabled() then
                buttons = { { label="View Log File", verb='ok' }, { label="Skip Log File", verb='cancel', memorable=true } }
            end
        else
            actionPrefKey = nil
            if app:isLoggerEnabled() then
                buttons = { { label="View Log File", verb='ok' } }
            end
        end
        
        if self.scope then -- might as well kill the cope before putting up the final dialog box - if any...
            if status then
                -- self.scope:done() -- commented out 27/Oct/2011 16:59
                self.scope:setCaption( "Finished - see dialog box for results..." ) -- added 27/Oct/2011 17:00
                    -- if scope already canceled, this message will not appear, or if dialog box not displayed it will be too quick to see.
            else
                self.scope:setCaption( "Error: " .. app:parseErrorMessage( message ) ) -- this is the touch I was after in case service concludes due to an uncaught error.
            end
        end
        local answer = app:show{ info=msg, buttons=buttons, actionPrefKey=actionPrefKey } -- no longer using error/warning specific dialog boxes for final presentation
            -- in honor of view-log-file upgrade.
        if answer =='ok' then -- seems like this used to die if left hand was nil, but it doesn't die now.
            if app:isLoggerEnabled() and LrFileUtils.exists( app:getLogFilePath() ) then
                app:showLogFile()
            else
                app:show( "no log" )
                --dbg( "no log" )
            end
        elseif answer == 'skip' then
           -- dbg( "notokforlogs" )
        elseif answer == 'cancel' then
            -- same as skip, except cancel can't be remembered.
        else
            app:show{ error="bad answer to question about viewing or skipping log file: ^1", str:to( answer ) }
        end

        -- note: if service scope is tied to service context, then it will be 'done' upon return from this function.
        -- if it was tied to some other context (highly unusual), then the calling context must determine when scope is done.
        if self.scope then
            self.scope:setCaption( "" ) -- just in case scope context is not service context - don't want it to say a dialog box still up.
        end
        service = 'done'    -- call or service sets this to 'started', then 'done' - used to synchronize call/services with debug-script: this is still being used @19/Aug/2011.

    end )
end



return Service