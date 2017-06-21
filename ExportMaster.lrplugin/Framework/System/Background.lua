--[[
        Background.lua
        
        Background task - designed to be extended.
        
        Instructions:
        
            - Extend this background class to do something useful.
              - Override init method to do special initialization, if desired.
              - Override process method to do special processing.
            - Create (extended) background object and start background task in init.lua, perhaps conditioned by pref.
--]]

local Background, dbg = Object:newClass{ className = 'Background' }



--- Constructor for extending class.
--
function Background:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
--  @param      t       initialization table, including:
--                      <br>interval (number, default: 1 second) process frequency base-rate. Recommend .2 as normal minimum, .1 if process is quick and fast response is necessary.
--                      <br>minInitTime (number, default: 10 seconds), but recommend setting to 15 or 20 - so user has time to inspect startups in progress corner, or set to zero to suppress init progress indicator altogether.
--
function Background:new( t )
    if str:is( t.enableCheckName ) then
        dbg( "background task no longer needs enable-check-name" )
    end
    local o = Object.new( self, t )
    o.interval = o.interval or 1 -- polling interval
    o.initStatus = false
    o.done = false -- stop command flag, not state var.
    o.started = false -- state var, to avoid having to try and figure it out from the various transient states.
    o.minInitTime = o.minInitTime or 10
    o.idleThreshold = o.idleThreshold or 1 -- default to idle processing every idle cycle.
    o.idleCounter = 0
    o.state = 'idle'
    return o
end



--- Background init function.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
--  @usage      override to do special initialization, if desired.
--              <br>Try not to throw errors in init, but instead set initStatus to true or false depending on whether successful or not.
--              <br>no need to call this method from extended class, yet.
--
--  @usage      if init is lengthy, check for shutdown sometimes and abort(return) if set - initStatus a dont care in that case.
--
function Background:init( call )
    self.initStatus = true
end



--  Set state if changed, and pref to match, and log appropriately.
--
function Background:_setState( state, verbose )
    if self.state == state then
        return
    end
    self.state = state
    app:setGlobalPref( 'backgroundState', state )
    if verbose then
        app:logVerbose( "Background state changed to: " .. state )
    else
        app:log( "Background state changed to: " .. state )
    end
end



--- Wait for asynchronous initialization to complete.
--
--  @param tmo - initial timeout in seconds - default is half second.
--  @param ival - recheck interval if not finished initializing upon initial timeout - return immediately and do not prompt user if nil or zero. Ignored if tmo is zero.
--
--  @usage Untested @2011-01-08 ###2
--
--  @return status - true iff init completed successfully.
--  @return explanation if init failed.
-- 
function Background:waitForInit( tmo, ival )

    tmo = tmo or .5
    if self.initStatus then
        return true
    elseif tmo == 0 then
        return false, "initialization incomplete"
    else -- wait loop
        ival = ival or 0
    end
    local time = LrDate.currentTime() + tmo
    repeat
        LrTasks.sleep( .1 )
        if self.initStatus then
            break
        end    
        if LrDate.currentTime() > time then -- either initial or interval timeout
            if ival > 0 then
                if app:isOk( str:fmt( "^1 is not ready yet. Wait another ^2 seconds?", app:getAppName(), ival ) ) then
                    time = LrDate.currentTime() + ival
                else
                    return false, "wait for initialization was canceled"
                end
            else
                return false, "initialization timed out"
            end
        -- else keep checking.
        end
    until false
    return true -- init complete.

end



--- Background process function.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
function Background:process( call )
    error( "background process must be overridden." )
end



--- Background process-next-photo function.
--
--  @param      call object - usually not needed, but its got the name, and context... just in case.
--
function Background:idleProcess( photo, call )
    error( "idle background process must be overridden." )
end



--[[
        Note: Its up to the extended class to keep track of last-edit-date if desired,
        and whatever else. This class is merely going to feed photos from selection or
        catalog alternately, forever, as long as main process function remembers to call it,
        preferrably when it didn't have anything better to do.
        
        The idea is to continue to keep up-2-date whatever this plugin updates.
        For example dev-meta (if ported), exif-meta (hardly needs it, but...), and change-manager.
--]]



--- Background process for processing next photo or video in the catalog.
--
--  @usage      Called when nothing else to do in background process.
--
function Background:considerIdleProcessing( call )

    -- step -1 init on demand:
    if self.phase == nil then
        if self.photoIndex == nil then
            self.photoIndex = 1 -- target photo index
        end
        if self.allPhotosIndex == nil then
            self.allPhotosIndex = 1
        end
        if self.filmstripPhotosIndex == nil then
            self.filmstripPhotosIndex = 1
        end
        self.lastEditTime = 0
        self.targetTimes = {}
        self.lastPhoto = nil
        self.lastTargets = {}
        self.allPhotoCount = 0
        self.filmstripPhotoCount = 0
        self.phase = 0
    end
    
    local target
    
    -- step 0: see if preferences are specifying any background processing.
    local doTargetPhotos = app:getPref( "processTargetPhotosInBackground" ) -- meaning "selected".
    local doAllPhotos = app:getPref( "processAllPhotosInBackground" )       -- meaning "whole catalog".
    local doFilmstripPhotos = app:getPref( "processFilmstripPhotosInBackground" ) -- meaning filmstrip photos, whether selected or not.
    if not doTargetPhotos and not doAllPhotos and not doFilmstripPhotos then
        return
    end

    -- step 1: check that Lightroom is in a steady state
    -- in order to minimize load when Lr/user is busy.
    
    local targetPhoto = catalog:getTargetPhoto()
    if targetPhoto ~= self.lastPhoto then -- may be nil
        self.lastPhoto = targetPhoto
        -- self.photoIndex = 1 -- when target changes, idle processing re-starts at the beginning, since new target could be used
        -- to sync other targets.
        -- self.phase = 0
        dbg( "photo changed" )
        return
    end
    
    local targetPhotos = catalog:getTargetPhotos()    
    if #targetPhotos ~= #self.lastTargets then -- may be zero
        self.lastTargets = targetPhotos
        -- self.photoIndex = 1 -- when targets change, idle processing re-starts at the beginning.
        -- self.phase = 0
        dbg( "target count changed" )
        return
    elseif #targetPhotos == 1 then
        if not doFilmstripPhotos then
            dbg( "Single photo selected - not included in idle-processing, should be explicitly processed." )
            return
        -- else filmstrip photos can do unselected photos too.
        end
    elseif #targetPhotos > 1 then -- counts are equal
        if targetPhotos[1] ~= self.lastTargets[1] or targetPhotos[#targetPhotos] ~= self.lastTargets[#targetPhotos] then -- rough check for
                -- selection content change despite same number selected.
            self.lastTargets = targetPhotos
            -- self.photoIndex = 1 -- when targets change, idle processing re-starts at the beginning.
            -- self.phase = 0
            dbg( "target selection changed" )
            return
        end
    end
    
    
    local allPhotos = catalog:getAllPhotos()
    if #allPhotos ~= self.allPhotoCount then -- may be zero
        self.allPhotoCount = #allPhotos
        -- self.allPhotosIndex = 1 - all photos index just keeps on trucking regardless of new photos added to catalog
        -- if user selects any of the new photos, it'll be picked up.
        dbg( "catalog photo count changed" )
        return
    else
        --
    end
    
    -- this may be very time consuming, so don't do unless necessary.
    local filmstripPhotos
    if doFilmstripPhotos then
        filmstripPhotos = cat:getFilmstripPhotos( app:getPref( "includeSubfolders" ), app:getPref( "ignoreIfBuried" ) )
        if #filmstripPhotos ~= self.filmstripPhotoCount then -- may be zero
            self.filmstripPhotoCount = #filmstripPhotos
            -- self.allPhotosIndex = 1 - all photos index just keeps on trucking regardless of new photos added to catalog
            -- if user selects any of the new photos, it'll be picked up.
            dbg( "filmstrip photo count changed" )
            return
        else
            --
        end
    end
    
    -- targets same as last time, which may be none or zero.
    if #allPhotos == 0 then -- dont die if its a new catalog.
        self.allPhotoCount = 0
        dbg( "catalog photo count zero" )
        return
    end
    
    -- fall-through => there is at least one photo in the catalog, and all targets are same as last time.
    if targetPhoto then
        local lastEditTime = targetPhoto:getRawMetadata( 'lastEditTime' )
        if lastEditTime > self.lastEditTime then -- let changes to most selected photo be handled by auto-update
            self.lastEditTime = lastEditTime
            -- self.phase = 0
            dbg( "Most selected photo edited, since last idle check, better pass on idle processing." ) -- (most-sel photo always gotten by auto-update non-idle processing)
            return
        end
    end
    
    self.idleCounter = self.idleCounter + 1
    if self.idleCounter < self.idleThreshold then
        return
    else
        self.idleCounter = 0
    end
    
    if self.phase == 0 then
        if doTargetPhotos then
            dbg( "Phase 0:", self.photoIndex )
        else
            dbg( "Phase 0 but not doing target photos." )
        end
    elseif self.phase == 1 then
        if doAllPhotos then
            dbg( "Phase 1:", self.allPhotosIndex, "total in catalog:", #allPhotos )
        else
            dbg( "Phase 1 but not doing all photos." )
        end
    elseif self.phase == 2 then
        if doFilmstripPhotos then
            dbg( "Phase 2:", self.filmstripPhotosIndex, "total in filmstrip:", #filmstripPhotos )
        else
            dbg( "Phase 1 but not doing all photos." )
        end
    else
        error( "invalid phase" )
    end

    -- step 2: compute potential target
    
    if doTargetPhotos and self.phase == 0 then
        if #targetPhotos > 0 then
            if self.photoIndex <= #targetPhotos then
                target = targetPhotos[self.photoIndex]
                self.photoIndex = self.photoIndex + 1
            else
                target = targetPhotos[1]
                self.photoIndex = 2
            end
        end
    end

    if doAllPhotos and self.phase == 1 then
        if #allPhotos > 0 then
            if self.allPhotosIndex <= #allPhotos then
                target = allPhotos[self.allPhotosIndex]
                self.allPhotosIndex = self.allPhotosIndex + 1
            else
                target = allPhotos[1]
                self.allPhotosIndex = 2
            end
        end
    end
    
    if doFilmstripPhotos and self.phase == 2 then
        if #filmstripPhotos > 0 then
            if self.filmstripPhotosIndex <= #filmstripPhotos then
                target = filmstripPhotos[self.filmstripPhotosIndex]
                self.filmstripPhotosIndex = self.filmstripPhotosIndex + 1
            else
                target = filmstripPhotos[1]
                self.filmstripPhotosIndex = 2
            end
        end
    end
    
    if self.phase == 0 then
        if doAllPhotos then
            self.phase = 1
        elseif doFilmstripPhotos then
            self.phase = 2
        end
    elseif self.phase == 1 then
        if doFilmstripPhotos then
            self.phase = 2
        elseif doTargetPhotos then
            self.phase = 0
        end
    elseif self.phase == 2 then
        if doTargetPhotos then
            self.phase = 0
        elseif doAllPhotos then
            self.phase = 1
        end
    else
        app:error( "Bad phase" )
    end

    if target then
        if target ~= catalog:getTargetPhoto() then -- most selected photo processing is not handled by idle processor.
            dbg( "idle processing", target:getRawMetadata( 'path' ) )
            self:idleProcess( target, call ) -- may do nothing, may do something...
        else
            dbg( "most selected photo, skipped: ", target:getRawMetadata( 'path' ) )
        end
    else
        dbg( "No target" )
    end
    
end



--- Start's background initialization, followed by periodic background processing - if desired.
--
--  @usage      Generally called from init module if background auto-start is enabled.
--              also called from plugin manager for start/stop on demand.
--
function Background:start()
    local status, message = app:call( Call:new { name='Background Task', async=true, guard=App.guardSilent, object=self, main=self.main, finale=self.finale } )
    if status == nil then -- guarded - already running...
        return false -- so not started
    else
        self.done = false -- do this outside async task, just in case quit is called before this task gets underway, it won't be ignored.
        return true
    end
end



--- Background initializer and optional main loop.
--
function Background:main( call )
    self.call = call
    self:_setState( 'starting' ) -- and set pref, and log normal.
    call.scope = LrProgressScope {
        title = app:getAppName() .. " Starting Up",
        caption = "Please wait...",
        functionContext = call.context,
    }
    local scope = call.scope -- convenience
    local startTime = LrDate.currentTime()
    LrTasks.sleep( .1 ) -- without this ya cant see the startup progress bar.
    self:init( call ) -- errors will cause permanent failure.
    if self.initStatus then
        while not self.done and not shutdown and not scope:isCanceled() and (LrDate.currentTime() < (startTime + self.minInitTime)) do
            LrTasks.sleep( .2 ) -- coarse sleep timer OK for responding to status change while initializing.
        end
        scope:done()
    else
        scope:setCaption( "Initialization failed." )
        repeat
            app:sleepUnlessShutdown( .5 ) -- coarse is ok - takes a bit for cancellation to be acknowleged anyway.
            if scope:isCanceled() then
                error( "Unable to initialize background task." )
            elseif shutdown then
                scope:done()
            end
        until scope:isDone()
    end
    if self.initStatus then
        app:logInfo( "Asynchronous initialization completed successfully." )
        self:_setState( 'running' ) -- and set pref, and log normal.
        local consecErrors = 0
        while not shutdown and not self.done do
            repeat
                if not app:isPluginEnabled() then
                    app:setGlobalPref( 'backgroundState', '*** Plugin Disabled' ) -- pseudo state: not used interally - for user only.
                    LrTasks.sleep( .5 ) -- disable holdoff.
                    break
                else
                    local interval = app:getPref( "backgroundPeriod" )
                    if interval == nil then
                        interval = self.interval
                    elseif type( interval ) == 'number' then
                        -- take it sight unseen...
                    end
                    app:sleepUnlessShutdown( interval )
                    if shutdown or self.done then
                        break
                    end
                end
                -- fall-through => enabled and not quitting and not shutting down.
                if self.state == 'pausing' then
                    self:_setState( 'paused', App.verbose ) -- and set pref, and log verbose.
                elseif self.state == 'paused' then
                    -- dont do anything
                else -- if not pausing or paused, then run if possible...
                    dbg( "processing" )
                    local status, message = LrTasks.pcall( self.process, self, call ) -- errors in processing must not terminate the task.
                    dbg( "process status/message:", status, message )
                    if status then -- executing process without error is the definition of "running" I think.
                        if app:getGlobalPref( 'backgroundState' ) ~= 'running' or self.state ~= 'running' then
                            if self.state ~= 'pausing' then
                                -- app:log("setting running after process return, previous state: " .. self.state )
                                -- self:_setState( 'running' ) - dont use this method, since it will return if state is running, even if pref isnt.
                                -- (misses the plugin disable/reenable transition which does not set the state to non-running).
                                app:setGlobalPref( 'backgroundState', 'running' )
                                self.state = 'running'
                            else
                                dbg( "Went into pausing state asynchronously while processing." )
                            end
                        else
                            -- dbg( "already running" )
                        end
                        consecErrors = 0
                    else
                        message = str:to( message )
                        -- anomalies are common when photos are deleted.
                        if app:isVerbose() or app:isAdvDbgEna() then
                            app:logVerbose( "*** Anomaly in background task (expected when most selected photo is deleted, or if background task updates catalog and its not accessible due to another plugin hogging it or something), error message: ^1", message )
                                -- ###3 check for type of anomaly = catalog prob?
                            dbg( "*** Anomaly in background task (expected when most selected photo is deleted, or if background task updates catalog and its not accessible due to another plugin hogging it or something), error message:", message )
                                -- ###3 check for type of anomaly = catalog prob?
                            app:setGlobalPref( 'backgroundState', "*** Anomaly: see log file." )
                        else
                            -- this is a very normal thing, when photos deleted from disk or removed from collection... - so no reason to even mention: it should clear.
                            -- If it does not clear, then user can see that here, and turn verbose logging on to find out what's happening...
                            app:setGlobalPref( 'backgroundState', "*** Anomaly: should clear." )
                        end
                        consecErrors = consecErrors + 1
                        if consecErrors >= 11 then
                            consecErrors = 11 -- clamp for sleep computation purposes.
                        end
                        app:sleepUnlessShutdown( .8 + ( .2 * consecErrors ) ) -- institute an error hold-off, so as not to overrun the logger...
                            -- don't hold off too long though, or background processing takes too long to resume after a deleted photo.
                            -- dont hold off too short, or background my resume before its time. Presently 1 - 3 seconds.
                    end
                end
            until true
        end
    end
end



--- Background call finale.
--
--  @usage      If overriding, you MUST set state to idle, or just call this from extended class method.
--
function Background:finale( call, status, message )
    self:_setState( 'idle' ) -- and set pref, and log normal.
    if status then
        app:logInfo( "Background/init task terminated without error." )
    else
        app:logError( "Background task aborted due to error: " .. ( message or 'nil' ) )
        app:show{ error="Background task aborted due to error: ^1", message or 'nil' }
    end
end



--- Signal background task to quit.
--
--  @usage Need not be called from task - does not wait for confirmation.
--
function Background:quit()
    if self.state ~= 'quitting' and self.state ~= 'idle' then
        app:logVerbose( "Background task is quitting" )
        self:_setState( 'quitting', App.verbose ) -- and set pref, and log verbose (normal state change log when quit state acknowleged).
    else
        app:logVerbose( "Background task cant really quit, state: " .. str:to( self.state ) )
    end
    self.done = true
end



--- Stop background task.
--
--  @param tmo (number, required) - seconds to wait for stop confirmation.
--
--  @usage no-op if already stopped.
--  @usage must be called from task - waits until stopped.
--
--  @return  confirmed (boolean) true iff stoppage confirmed.
--
function Background:stop( tmo )
    assert( (tmo ~= nil)  and (type( tmo ) == 'number') and (tmo > 0), "stop requires non-zero tmo" )
    self:quit()
    self:waitForIdle( tmo )
    return self.state == 'idle'
end



--- Pause background task.
--
--  @usage you must continue in finale method of call or service, lest background task dies forever.
--
function Background:pause()
    local status
    if self.state == 'starting' then
        while not shutdown do
            local s, m = self:waitForInit( 10, 3 ) -- wait up to 10 seconds to start with, then another 3 each time after prompting user.
            if s then
                -- give it a chance to run before trying to pause it.
                local count = 10
                while not shutdown and count > 0 do
                    if self.state == 'running' then
                        break
                    else
                        LrTasks.sleep( 1 )
                        count = count - 1
                    end
                end
                break -- give it a try regardless, background task may not ever run: not a pre-requisite.
            else    
                return false, m
            end
        end
    end
    if self.state ~= 'running' then
        app:logVerbose( "Background task not running - so it cant be paused, state: " .. str:to( self.state ) )
        return true -- lets not get hung up trying to pause something that is not even running.
    end
    self:_setState( 'pausing', App.verbose ) -- and set pref, and log verbose.
    local count = 100 -- 10 second timeout.
    while not shutdown and not (self.state == 'paused') and (count > 0) do
        LrTasks.sleep( .1 )
        count = count - 1
    end
    if count == 0 then
        app:logError( "Unable to pause background task - continuing with state: " .. self.state )
        return false, "background process not pausing"
    else
        app:logVerbose( "Background task paused." )
        return true
    end
end



--- Continue background task.
--
--  @usage No-op if not paused.
--
function Background:continue()
    if self.state == 'pausing' or self.state == 'paused' then
        self:_setState( 'running', App.verbose ) -- and set pref, and log verbose.
    else -- else leave state alone.
        app:logInfo( "Cant continue background task, state: " .. str:to( self.state ), App.verbose )
    end
end



--- Wait for background task to finish.
--
--  @usage Dont call unless you know its on its way out, e.g. shutdown for reload.
--
function Background:waitForIdle( tmo )
    tmo = tmo or 30 -- for backward compatibility.
    local startTime = LrDate.currentTime()
    while self.state ~= 'idle' do
        LrTasks.sleep( .1 )
        if (LrDate.currentTime() - startTime) > tmo then
            break
        end
    end
    if self.state == 'idle' then
        app:setGlobalPref( 'backgroundState', 'idle' )
        app:logVerbose( "Background task became idle." )
    end
end





return Background