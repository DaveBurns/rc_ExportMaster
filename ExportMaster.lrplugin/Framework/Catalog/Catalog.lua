--[[
        Catalog.lua
--]]

local Catalog, dbg = Object:newClass{ className = 'Catalog' }



--- Constructor for extending class.
--
function Catalog:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function Catalog:new( t )
    local o = Object.new( self, t )
    return o
end



--- Get lr folder for photo
--
function Catalog:getFolder( photo, photoPath )
    if not photoPath then
        photoPath = photo:getRawMetadata( 'path' )
    end
    local parent = LrPathUtils.parent( photoPath )
    local folder = catalog:getFolderByPath( parent )
    return folder
end



--- Refresh display of recently changed photo (externally changed).
--
function Catalog:refreshDisplay( photo, photoPath )
    if not photoPath then
        photoPath = photo:getRawMetadata( 'path' )
    end
    local p = catalog:getTargetPhoto()
    if p then
        if p:getRawMetadata( 'path' ) == photoPath then -- preview just updated is selected.
            local ps = catalog:getTargetPhotos()
            if #ps > 1 then 
                for k, v in ipairs( ps ) do
                    if v ~= p then
                        catalog:setSelectedPhotos( v, ps ) -- do not call framework version: task yield not necessary, and results in a hitch.
                        catalog:setSelectedPhotos( p, ps )
                        return true
                    end
                end
            else
                local folder = cat:getFolder( photo, photoPath )
                if folder then
                    local ps = folder:getPhotos()
                    if #ps > 0 then
                        for k, v in ipairs( ps ) do
                            if v ~= p then
                                catalog:setSelectedPhotos( v, ps ) -- do not call framework version: task yield not necessary, and results in a hitch.
                                catalog:setSelectedPhotos( p, { p } )
                                return true
                            end
                        end
                    end
                end                    
            end
        else
            local ps = cat:getSelectedPhotos()
            catalog:setSelectedPhotos( photo, ps )
            return true
        end
    else
        catalog:setSelectedPhotos( photo, { photo } )
        return true -- note: not definitive unless source is being currently viewed.
    end
    return false
end


--- Catalog access wrapper that distinquishes catalog contention errors from target function errors.
--
--  @deprecated         use with-retries method instead.
--
--  @param              tryCount        Number of tries before giving up, at a half second per try (average).
--  @param              func            Catalog with-do function.
--  @param              catalog             The lr-catalog object.
--  @param              p1              First parameter which may be a function, an action name, or a param table.
--  @param              p2              Second parameter which will be a function or nil.
--      
--  @usage              Returns immediately upon target function error. 
--  @usage              The purpose of this function is so multiple concurrent tasks can access the catalog in succession without error.
--                          
--  @return             status (boolean):    true iff target function executed without error.
--  @return             other:    function return value, or error message.
--
function Catalog:withDo( tryCount, func, catalog, p1, p2, ... )
    while( true ) do
        for i = 1, tryCount do
            local sts, qual = LrTasks.pcall( func, catalog, p1, p2, ... )
            if sts then
                return true, qual
            elseif str:is( qual ) then
                local found = qual:find( "LrCatalog:with", 1, true ) or 0 -- return position or zero, instead of position or nil.
                if found == 1 then -- problem reported by with-catalog-do method.
                    local found2 = qual:find( "already inside", 15, true )
                    if found2 then
                        -- problem is due to catalog access contention.
                        Debug.logn( 'catalog contention:', str:to( qual ) )
                        LrTasks.sleep( math.random( .1, 1 ) ) -- sleep for a half-second or so, then try again.
                    else
                        return false, qual
                    end
                else
                    return false, qual
                end
            else
                return false, 'Unknown error occurred accessing catalog.'
            end
        end
    	local action = app:show{ warning="Unable to access catalog.", buttons={ dia:btn( "Keep Trying", 'ok' ), dia:btn( "Give Up", 'cancel' ) } }
    	if action == 'ok' then
    		-- keep trying
    	elseif action=='cancel' then
    		-- assert( action == 'cancel', "unexpected error action: " .. str:to( action )  )
    		return false, "Gave up trying to access catalog."
    	else
    	    app:logError( "Invalid button" )
    	    return false, "Gave up trying to access catalog (invalid button)."
    	end
    end
    return false, str:format( "Unable to access catalog." )
end



--- Catalog access wrapper that distinquishes catalog contention errors from target function errors.
--
--  @param              tryCount        Number of tries before giving up, at a half second per try (average).
--  @param              func            Catalog with-do function.
--  @param              p1              First parameter which may be a function, an action name, or a param table.
--  @param              p2              Second parameter which will be a function or nil.
--      
--  @usage              Same as with-do method, except relies on global lr catalog.
--  @usage              Returns immediately upon target function error. 
--  @usage              The purpose of this function is so multiple concurrent tasks can access the catalog in succession without error.
--                          
--  @return             status (boolean):    true iff target function executed without error.
--  @return             other:    function return value, or error message.
--
function Catalog:withRetries( tryCount, func, p1, p2, ... )
    assert( _G.catalog ~= nil, "no catalog" )
    if type( tryCount ) == 'table' then
        func = tryCount.func
        p1 = tryCount.p1
        p2 = tryCount.p2
        tryCount = tryCount.tryCount
    end
    while( true ) do
        for i = 1, tryCount do
            local sts, qual = LrTasks.pcall( func, catalog, p1, p2, ... )
            if sts then
                return true, qual
            elseif str:is( qual ) then
                local found = qual:find( "LrCatalog:with", 1, true ) or 0 -- return position or zero, instead of position or nil.
                if found == 1 then -- problem reported by with-catalog-do method.
                    local found2 = qual:find( "already inside", 15, true )
                    if found2 then
                        -- problem is due to catalog access contention.
                        Debug.logn( 'catalog contention:', str:to( qual ) )
                        LrTasks.sleep( math.random( .1, 1 ) ) -- sleep for a half-second or so, then try again.
                    else
                        return false, qual
                    end
                else
                    return false, qual
                end
            else
                return false, 'Unknown error occurred accessing catalog.'
            end
        end
    	local action = app:show{ warning="Unable to access catalog.", buttons={ dia:btn( "Keep Trying", 'ok' ), dia:btn( "Give Up", 'cancel' ) } }
    	if action == 'ok' then
    		-- keep trying
    	elseif action=='cancel' then
    		-- assert( action == 'cancel', "unexpected error action: " .. str:to( action )  )
    		return false, "Gave up trying to access catalog."
    	else
    	    app:logError( "Invalid button" )
    	    return false, "Gave up trying to access catalog (invalid button)."
    	end
    end
    return false, str:format( "Unable to access catalog." )
end



--- select one photo, de-select all others - confirm selection.
--
--  @return     status, message
--
function Catalog:selectOnePhoto( photo )
    local try = 1
    while try <= 3 do -- retries are based on hope for luck - no real problem being fixed by this...
        catalog:setSelectedPhotos( photo, { photo } )
        if catalog:getTargetPhoto() == photo then
            return true
        else
            LrTasks.sleep( .1 )
            try = try + 1
        end
    end
    local p = photo:getRawMetadata( 'path' )
    local isBuried = cat:isBuriedInStack( photo )
    if isBuried then
        return false, str:fmt( "Unable to select photo (^1) after ^2 tries, probably because its buried in a stack.", p, try - 1 )
    else
        return false, str:fmt( "Unable to select ^1 after ^2 tries", p, try - 1 ) -- not sure why...
    end
end



--- Get selected photos.
--
--  @usage Use instead of getTargetPhotos if you don't want the entire filmstrip to be returned when nothing is selected.
--
--  @return empty table if none selected - never returns nil.
--
function Catalog:getSelectedPhotos()
    local photo = catalog:getTargetPhoto()
    if not photo then -- nothing selected
        return {} -- target nothing...
    else
        return catalog:getTargetPhotos() -- would target whole filmstrip if nothing selected.
    end
end
    


--- Same as LrCatalog method, *except* verifies specified photos are actually selected.
--
--  @usage Catalog photo selection may not take until processor is given up for Lightroom to do its thing.<br>
--         If you must be certain selection has settled before continuing with processing, call<br>
--         this method instead.
--  @usage  Do not call this method, unless you know the photos are all in active sources.
--          Presently, there is no method for assuring multiple selected photos from diverse (possibly not active) sources.
--
function Catalog:setSelectedPhotos( photo, photos )
    local try = 1
    local function valid() -- not robust
        local ps = catalog:getTargetPhotos()
        if #ps == #photos then
            -- I could check each and every photo but no guarantee arrays are ordered the same,
            -- and an exhaustive check could be very time consuming.
            if catalog:getTargetPhoto() == photo then -- at least check most-sel photo.
                return true
            else
                return false
            end
        else
            return false
        end
    end
    repeat
        catalog:setSelectedPhotos( photo, photos )
        if try == 1 then
            LrTasks.yield() -- necessary for Lightroom to do its thing.
        elseif try == 2 then
            LrTasks.sleep( .1 )
        else
            break
        end
        if valid() then
            return true
        end
        try = try + 1
    until false
    local bm = catalog:batchGetRawMetadata( photos, { 'isInStackInFolder', 'stackPositionInFolder', 'stackInFolderIsCollapsed' } )
    for i, p in ipairs( photos ) do
        if cat:isBuriedInStack( p, bm ) then
            return false, str:fmt( "Unable to select specified photos - possibly because at least one of them is buried in a stack (e.g. ^1)", p:getRawMetadata( 'path' ) )
            -- could provide better error message by factoring in active source considerations, but outcome would be the same...
        end
    end
    return false, "Unable to select specified photos, not sure why..."
end
    


--- Save metadata for selected photos.
--
--  @param              photo - single photo object to save metadata for.
--  @param              photoPath - photo path.
--  @param              targ - path to file containing xmp.
--  @param              call - if a scope in here it will be used for captioning.
--
--  @usage              Windows + Mac (its the *read* metadata that's not supported on mac).
--  @usage              If you've just done something that needs settling before save, call sleep(e.g. .1) before this method to increase odds for success on first try.
--  @usage              Library mode is not necessary to save single photo metadata.
--  @usage              *** Side-effect of single photo selection - be sure to save previous multi-photo selection to restore afterward if necessary.
--  @usage              Will cause metadata conflict flag if xmp is read-only, so make read-write before calling, if desired.
--  @usage              Uses keystroke emission to do the job.
--
--  @return             true iff metadata saved.
--  @return             error message if metadata not saved.
--
function Catalog:savePhotoMetadata( photo, photoPath, targ, call, noVal )

    if photo == nil then
        app:callingError( "need photo" )
    end

    if photoPath == nil then
        photoPath = photo:getRawMetadata( 'path' )
    end
    
    if targ == nil then
        local fmt = photo:getRawMetadata( 'fileFormat' )
        if fmt == 'RAW' then -- raw not dng. Beware, if you don't want to save metadata for cooked nefs (which are considered "raw")..., then check before calling.
            targ = LrPathUtils.replaceExtension( photoPath, "xmp" )
        else
            targ = photoPath
        end
    end

    local done = false -- cancel flag
    
    -- Side effect: selection of single photo to be saved.
    -- local s, m = cat:selectOnePhoto( photo ) - commented out 13/Sep/2011 16:47
    local s = cat:assurePhotoIsSelected( photo, photoPath ) -- added 13/Sep/2011 16:47
    if s then
        app:logVerbose( "Photo selected for metadata save: ^1", photoPath )
    else
        --return false, str:fmt( "Unable to select photo for metadata save, error message: ^1", m ) -- m includes path.
            -- no way it'll work if cant select it.
        return false, str:fmt( "Unable to select photo for metadata save (see log file for details), path: ^1", str:to( photoPath ) )
            -- no way it'll work if cant select it.
    end
    
    local time, time2, tries
    local m
    if call and call.scope then
        call.scope:setCaption( str:fmt( "Waiting for 'Save Metadata' confirmation..." ) ) -- only visible after the save metadata operation is complete.
        -- calling context needs to put something else up upon return if desired.
    end
    tries = 1
    local code = app:getPref( 'saveMetadataKeyChar' ) or 's'
    repeat
        local keys
        if WIN_ENV then
            time = LrDate.currentTime() -- windows file times are high-precision and haven't needed a fudge factor so far. ###1 watch for metadata timeout on Windows too.
            keys = str:fmt( "{Ctrl Down}^1{Ctrl Up}", code )
            s, m = app:sendWinAhkKeys( keys ) -- Save metadata - for one photo: seems reliable enough so not using the catalog function which includes a prompt.
        else -- mac-env
            time = math.floor( LrDate.currentTime() ) -- file-attrs seem to be nearest second on Mac - make sure this does not appear to be in the future.
            keys = str:fmt( "Cmd-^1", code )
            s, m = app:sendMacEncKeys( keys )
        end
        if s then
            app:logVerbose( "Issued keystroke command '^1' to save metadata for ^2", keys, photoPath ) -- just log final results in normal case.
        else
            return false, str:fmt( "Unable to save metadata for ^1 because ^2", photoPath, m )
        end
        time2 = LrFileUtils.fileAttributes( targ ).fileModificationDate
        local count = 10 -- give a second or so for the metadata save to settle, in case Lr is constipated on this machine, or some other process is interfering temporarily...
        while count > 0 and (time2 == nil or time2 < time) do
            LrTasks.sleep( .1 )
            count = count - 1
            time2 = LrFileUtils.fileAttributes( targ ).fileModificationDate
        end
        if time2 ~= nil and time2 >= time then
            app:logVerbose( "^1 metadata save validated.", photoPath )
            return true
        elseif time2 == nil then
            if tries == 1 then
                app:log( "*** Unable to save metadata for ^1 because save validation timed out, unable to get time of xmp file: ^2.", photoPath, targ )
            elseif tries == 2 then
                app:logWarn( "Unable to save metadata for ^1 because save validation timed out, unable to get time of xmp file: ^2.", photoPath, targ )
            -- else return value will be logged as error if user gives up.
            end
        else
            if tries == 1 then -- first time is considered "normal" (although not optimal).
                app:log( "*** Unable to save metadata for ^1 because save validation timed out, xmp file (^2) time: ^3, save metadata command time: ^4.", photoPath, targ, time2, time )
            elseif tries == 2 then -- second time it should have taken.
                app:logWarn( "Unable to save metadata for ^1 because save validation timed out, xmp file (^2) time: ^3, save metadata command time: ^4.", photoPath, targ, time2, time )
            -- else return value will be logged as error if user gives up.
            end
        end
        if tries >= 3 then -- after 3rd and subsequent tries, involve the user.
            if noVal then
                return true -- pretend like it worked, even thought it didn't in the hope that it's a "pseudo" problem (there will still be the warning logged).
            end
            repeat
                local answer = app:show{ warning="Unable to save metadata for ^1 - try again?",
                    buttons={ dia:btn( "Yes", 'ok' ), dia:btn( "Give Me a Moment", 'other' ) },
                    subs=photoPath }
                if answer == 'ok' then
                    break
                    -- go again
                elseif answer == 'other' then
                    app:sleepUnlessShutdown( 3 )
                elseif answer == 'cancel' then
                    done = true -- can't cancel the call because it may be the background process call, and there is nothing to un-cancel it.
                        -- not only that, but call param is optional, and sometimes is not passed.
                    break -- quit
                else
                    app:error( "bad answer" )
                end
            until done or shutdown
        end
        if not done then
            tries = tries + 1
        -- else exit loop below.
        end
    until done or shutdown
    if time2 == nil then
        return false, str:fmt( "Unable to save metadata for ^1 because save validation timed out, unable to get time of xmp file: ^2.", photoPath, targ )
    else
        return false, str:fmt( "Unable to save metadata for ^1 because save validation timed out, xmp file (^2) time: ^3, save metadata command time: ^4.", photoPath, targ, time2, time )
    end
    
end



--- Save metadata for selected photos.
--
--  @param              photos - photos to save metadata for, or nil to do all target photos.
--  @param              preSelect - true to have specified photos selected before saving metadata, false if you are certain they are already selected.
--  @param              restoreSelect - true to have previously photo selections restored before returning.
--  @param              service - if a scope in here it will be used for captioning.
--
--  @usage              Windows + Mac (its the *read* metadata that's not supported on mac).
--  @usage              Switch to grid mode first if desired, and select target photos first if possible.
--  @usage              Cause metadata conflict for photos that are set to read-only, so make read-write before calling, if desired.
--  @usage              Uses keystroke emission to do the job.
--  @usage              User will be prompted to first make sure the "Overwrite Settings" prompt will no longer appear.
--
--  @return             true iff metadata saved.
--  @return             error message if metadata not saved.
--
function Catalog:saveMetadata( photos, preSelect, restoreSelect, alreadyInGridMode, service )

    if photos == nil then
        app:callingError( "photos must not be nil" )
    end
    
    if #photos < 1 then
        app:callingError( "photo count can not be zero" )
    end

    local selPhotos = self:saveSelPhotos()

    if preSelect then
        local photoToBe
        if selPhotos.mostSelPhoto then
            for i, photo in ipairs( photos ) do
                if photo == selPhotos.mostSelPhoto then
                    photoToBe = photo
                    break
                end
            end
        end
        if not photoToBe then
            photoToBe = photos[1]
        end
        local s, m = cat:setSelectedPhotos( photoToBe, photos ) -- make sure the photos to have their metadata saved are the ones selected.
        if s then
            app:logVerbose( "Photos selected for metadata save." )
        else
            return false, str:fmt( "Unable to select photos for metadata save, error message: ^1", m )
        end
    end

    local status = false
    local message = "unknown"
    
    if not alreadyInGridMode then    
        app:sendKeys( 'g' ) -- attempt to put in grid mode, but dont prompt.
    end

    
    if service and service.scope then
        service.scope:setCaption( str:fmt( "Waiting for 'Save Metadata' button click..." ) ) -- only visible after the save metadata operation is complete.
    end
    -- Note: this prompt is optional, but the confirmation prompt is not:
    local m = {}
    m[#m + 1] = "Metadata must be saved to ensure this operation is successful."
    m[#m + 1] = "After you click 'Save Metadata', you should see an extra \"Operation\" pop up in the upper left corner of Lightroom's main window - be looking for it... (if no other operations are in progress, it will say 'Saving Metadata')"
    m[#m + 1] = "If you are in grid mode, and there are no other dialog boxes open, then click 'Save Metadata' to begin. If there are other Lightroom/plugin dialog boxes open, the click 'Let Me Close Dialogs' and do so (close them). If you are not in grid mode, or cant get the dialog boxes to stay closed, then you must click 'Cancel', and try again after remedying..."
    m[#m + 1] = "Click 'Save Metadata' when ready."
    m = table.concat( m, '\n\n' )

    local answer
    repeat
        answer = app:show{ info=m, actionPrefKey="Save metadata", buttons={ dia:btn( "Save Metadata", 'ok' ), dia:btn( "Let Me Close Dialogs", 'other', false ) } }
        
        if answer == 'other' then
            LrTasks.sleep( 3 )
        else
            break
        end
    until false
    repeat
        if answer == 'ok' then
            if service and service.scope then
                service.scope:setCaption( str:fmt( "Waiting for 'Save Metadata' confirmation..." ) ) -- only visible after the save metadata operation is complete.
            end
            local code = app:getPref( 'saveMetadataKeyChar' ) or 's'
            if WIN_ENV then
                local keys = str:fmt( "{Ctrl Down}^1{Ctrl Up}", code )
                status, message = app:sendWinAhkKeys( keys ) -- include post keystroke yield.
            else
                local keys = str:fmt( "Cmd-^1", code )
                status, message = app:sendMacEncKeys( keys )
            end
            if status then
                --
            else
                break
            end
            --local m = "Has the 'Save Metadata' operation completed?\n \nYou can tell by the upper left-hand corner of the main Lightroom window: the 'Save Metadata' operation that was started there will disappear when the operation has completed."
            local m = "Wait for the 'Save Metadata' operation to complete, then click 'Save Metadata is Complete'.\n \nYou can tell when its complete by looking in the upper left-hand corner of the main Lightroom window: it will say \"Waiting for 'Save Metadata' confirmation...\" when the operation has completed."
            local answer2 = app:show{ info=m, buttons={ dia:btn( "Save Metadata is Complete", 'ok' ), dia:btn( "Save Metadata Never Started", 'other' ) } }
            if answer2 == 'ok' then -- yes
                status = true
            elseif answer2 == 'cancel' then -- no
                status, message = false, "Apparently, metadata was not saved - most often caused by dialog box interference. Try to eliminate interfereing dialog boxes, then attempt again..."
            elseif answer2 == 'other' then -- dunno
                status, message = nil, "Metadata must be saved. Hint: to tell if it gets saved, watch the progress indicator in the upper left-hand corner of the main Lightroom window."
            end
        elseif not answer or answer == 'cancel' then -- answer is coming back false for cancel - doc says cancel => nil for prompt-for-action-with-do-not-show...
            -- 'cancel' is returned by other lr-dialog methods, so test for it left in here as cheap insurance / reminder...
            status, message = nil, "User canceled."
        else
            error( "invalid answer: " .. str:to( answer ) )
        end
    until true
    
    if restoreSelect then
        cat:restoreSelPhotos( selPhotos )
    end
    return status, message

end



--- Read metadata for selected photos.
--
--  @param              photo - single photo object to read metadata for.
--  @param              photoPath - photo path.
--  @param              alreadyInLibraryModule - true iff library module has been assured before calling.
--  @param              service - if a scope in here it will be used for captioning.
--
--  @usage              Not reliable in a loop without user prompting in between (or maybe lengthy delays).
--  @usage              Switch to grid mode first if necessary.
--  @usage              *** Side-effect of single photo selection - be sure to read previous multi-photo selection to restore afterward if necessary.
--  @usage              Ignores photos that are set to read-only, so make read-write before calling, if desired.
--  @usage              Uses keystroke emission to do the job.
--  @usage              Will not work on virtual copy (returns error message), so check before calling.
--
--  @return             true iff metadata read
--  @return             error message if metadata not readd.
--
function Catalog:readPhotoMetadata( photo, photoPath, alreadyInLibraryModule, service )

    if not photoPath then
        error( "need photo-path" )
    end
    
    if MAC_ENV then
        error( "Read Metadata not supported on Mac (programmatically)")
    end
   
    -- Side effect: selection of single photo to be read.
    -- local s, m = cat:selectOnePhoto( photo ) - commented out 13/Sep/2011 16:47
    local s = cat:assurePhotoIsSelected( photo, photoPath ) -- added 13/Sep/2011 16:47
    if s then
        app:logVerbose( "Photo selected for metadata read: ^1", photoPath )
    else
        --return false, str:fmt( "Unable to select photo for metadata read, error message: ^1", m ) -- m includes path.
            -- no way it'll work if cant select it.
        return false, str:fmt( "Unable to select photo for metadata read (see log file for details), path: ^1", str:to( photoPath ) )
            -- no way it'll work if cant select it.
    end
    
    local time
    if WIN_ENV then
        if service and service.scope then
            service.scope:setCaption( str:fmt( "Waiting for 'Read Metadata' confirmation..." ) ) -- only visible after the save metadata operation is complete.
        end
        
        -- must be as sure as possible we're in library module, view mode does not matter.
        if not alreadyInLibraryModule then
            local s, m = gui:switchModule( 1 )
            if s then
                app:logVerbose( "Issued command to switch to library module for ^1", photoPath ) -- just log final results in normal case.
            else
                return false, str:fmt( "Unable to switch to library module for ^1 because ^2", photoPath, m )
            end
        end
        time = LrDate.currentTime() -- windows file times are high-precision and haven't needed a fudge factor so far.
        local s, m = app:sendWinAhkKeys( "{Alt Down}mr{Alt Up}" ) -- Read metadata - for one photo: seems reliable enough so not using the catalog function which includes a prompt.
        if s then
            app:logVerbose( "Issued command to read metadata for ^1", photoPath ) -- just log final results in normal case.
        else
            return false, str:fmt( "Unable to read metadata for ^1 because ^2", photoPath, m )
        end
    end
    
    -- fall-through => one photo selected in library, and command issued to read metadata.
    
    local time2 = photo:getRawMetadata( 'lastEditTime' )
    local count = 50 -- give 5 seconds or so for the metadata read to settle, in case Lr is constipated on this machine, or some other process is interfering temporarily...
    while count > 0 and (time2 ~= nil and time2 < time) do -- see if possible to not have a fudge factor here. ###1
        LrTasks.sleep( .1 )
        count = count - 1
        time2 = photo:getRawMetadata( 'lastEditTime' )
    end
    if time2 ~= nil and time2 >= time then
        return true
    elseif time2 == nil then
        return false, str:fmt( "Unable to read metadata for ^1 because read validation timed out (never got a read on last-edit-time).", photoPath )
    else
        local isVirt = photo:getRawMetadata( 'isVirtualCopy' ) -- this is deferred for efficient performance in the normal case.
        if isVirt then
            local copyName = photo:getFormattedMetadata( 'copyName' ) -- this is deferred for efficient performance in the normal case.
            return false, str:fmt( "Unable to read metadata for ^1 (^2) because its a virtual copy", photoPath, copyName )
        else
            return false, str:fmt( "Unable to read metadata for ^1 because read validation timed out (last-edit-time never updated).", photoPath )
        end
    end
end



--  Read metadata for selected photos.
--
--  @param              photos - photos to save metadata for, or nil to do all target photos.
--  @param              preSelect - true to have specified photos selected before reading metadata, false if you are certain they are already selected.
--  @param              restoreSelect - true to have previously photo selections restored before returning.
--  @param              service - if a scope in here it will be used for captioning.
--
--  @usage              Only supported on Windows platform - if called in Mac environment it will throw an error.
--  @usage              Switch to grid mode first if desired, and pre-select target photos.
--  @usage              Uses keystroke emission to do the job.
--  @usage              Includes optional user pre-prompt (before issuing read-metadata keys), and mandatory user post-prompt (to confirm metadata read).
--
--  @return             true iff metadata saved.
--  @return             error message if metadata not read.
--
function Catalog:readMetadata( photos, preSelect, restoreSelect, alreadyInGridMode, service )

    if not photos then
        error( "read-metadata requires photos" )
    end
    
    if #photos < 1 then
        error( "check photo count before calling read-metadata" )
    end
    
    if MAC_ENV then
        error( "Plugins cant 'Read Metadata' on Mac." )
    end
    
    local selPhotos = self:saveSelPhotos()

    if preSelect then
        local photoToBe
        if selPhotos.mostSelPhoto then
            for i, photo in ipairs( photos ) do
                if photo == selPhotos.mostSelPhoto then
                    photoToBe = photo
                    break
                end
            end
        end
        if not photoToBe then
            photoToBe = photos[1]
        end
        local s, m = cat:setSelectedPhotos( photoToBe, photos ) -- make sure the photos to have their metadata read are the ones selected.
        if s then
            app:logVerbose( "Photos selected for metadata read." )
        else
            return false, str:fmt( "Unable to select photos for metadata read, error message: ^1", m )
        end
    end

    
    local status = false
    local message = "unknown"
    
    if not alreadyInGridMode then
        app:sendKeys( 'g' ) -- confirmation requested below.
    end
    
    if service and service.scope then
        service.scope:setCaption( str:fmt( "Waiting for 'Read Metadata' button click..." ) ) -- not seen if optional prompt is bypassed (confirmation is not optional and scope will be updated at that point).
    end

    local m = {}
    m[#m + 1] = "Metadata must be read to ensure this operation is successful."
    m[#m + 1] = "After you click 'Read Metadata', you should see an extra \"Operation\" pop up in the upper left corner of Lightroom's main window - be looking for it... (if no other operations are in progress, it will say 'Reading Metadata')"
    m[#m + 1] = "If you are in grid mode, and there are no other dialog boxes open, then click 'Read Metadata' to begin. If there are other Lightroom/plugin dialog boxes open, then click 'Let Me Close Dialogs' and then do so (close them).  If you are not in grid mode, or you cant get dialogs to stay closed, then you must click 'Cancel', and retry again after remedying..."
    m[#m + 1] = "Click 'Read Metadata' when ready."
    m = table.concat( m, '\n\n' )
    
    local answer
    repeat
        answer = app:show{ info=m, actionPrefKey="Read metadata", buttons={ dia:btn( 'Read Metadata', 'ok' ), dia:btn( "Let Me Close Dialogs", 'other', false ) } }
        if answer == 'other' then
            LrTasks.sleep( 3 )
        else
            break
        end
    until false
    repeat
        if answer == 'ok' then
            if WIN_ENV then
                if service and service.scope then
                    service.scope:setCaption( str:fmt( "Waiting for 'Read Metadata' confirmation..." ) ) -- only visible after the save metadata operation is complete.
                end
                status, message = app:sendWinAhkKeys( "{Alt Down}mr{Alt Up}" ) -- makes photo look changed again.
                if not status then
                    break
                end
            else
                error( "Program failure...") -- this will never happen.
            end
            local m = "Wait for the 'Read Metadata' operation to complete, then click 'Read Metadata is Complete'.\n \nYou can tell when its complete by looking in the upper left-hand corner of the main Lightroom window: it will say \"Waiting for 'Read Metadata' confirmation...\" when the operation is complete."
            local answer = app:show{ info=m, buttons={ dia:btn( "Read Metadata is Complete", 'ok' ), dia:btn( "Read Metadata Never Started", 'other' ) } }
            if answer == 'ok' then -- yes
                status = true
            elseif answer == 'cancel' then -- no
                status, message = false, "Apparently, metadata was not read - most often caused by dialog box interference. Try to eliminate dialog boxes, then attempt again..."
            elseif answer == 'other' then -- dunno
                status, message = nil, "Metadata must be read. Hint: to tell if it gets read, watch the progress indicator in the upper left-hand corner of the main Lightroom window."
            end
        elseif answer == 'cancel' then
            status, message = nil, "User canceled."
        else
            error( "invalid answer: " .. answer )
        end
    until true
    
    if restoreSelect then -- not restored upon program failure.
        cat:restoreSelPhotos( selPhotos )
    end
    return status, message    

end



--- Save selected photos for restoral later.
--
--  @usage     call if photo selection will be changed temporarily by plugin.
--             <br>- restore in cleanup handler.
--
--  @return    black box to pass to restoral function.
--
function Catalog:saveSelPhotos()
    -- return { mostSelPhoto = catalog:getTargetPhoto(), selPhotos = catalog:getTargetPhotos() }
    return { mostSelPhoto = catalog:getTargetPhoto(), selectedPhotos = self:getSelectedPhotos(), sources=catalog:getActiveSources(), filterTable=catalog:getCurrentViewFilter() } -- ignore filter name,
        -- since it can't be restored - restoral by name depends on uuid...
end



--- Restore previously saved photo selection.
--
--  @usage     call in cleanup handler if photo selection was changed temporarily by plugin.
--  @usage     cant deselect photos, so if nothing was selected in filmstrip before restoral, then restoral will just be a no-op.
--
function Catalog:restoreSelPhotos( selPhotos )
    if selPhotos then
        if selPhotos.sources and #selPhotos.sources > 0 then
            catalog:setActiveSources( selPhotos.sources ) -- restore original sources
            local sources = catalog:getActiveSources()
            if #sources == #selPhotos.sources then
                app:logVerbose( "Active sources restored, should be: " )
                for i, src in ipairs( selPhotos.sources ) do
                    app:logVerbose( src:getName() )
                end
            else -- some sources were dropped, probably took folders over collections, probably need the opposite.
                app:logWarning( "Unable to restore all active sources." )
                local newSources = {}
                local fldrs = {}
                local colls = {}
                local misc = {}
                for i, src in ipairs( selPhotos.sources ) do
                    app:logVerbose( src:getName() )
                    local typ = src:type()
                    if typ == 'LrFolder' then
                        fldrs[#fldrs + 1] = src
                    elseif typ == 'LrCollection' then
                        colls[#colls + 1] = src
                    else
                        misc[#misc + 1] = src
                    end
                end
                if #colls > 0 then
                    catalog:setActiveSources( colls )
                    local srcs = catalog:getActiveSources()
                    if #srcs == #colls then
                        if #fldrs > 0 then
                            app:logVerbose( "Folders were dropped." )
                        end
                        if #misc > 0 then
                            app:logVerbose( "Other sources were dropped." )
                        end
                        app:logVerbose( "Collections only are now selected." )
                    else
                        app:logWarning( "Not all previous collection sources could be restored." )
                    end
                else
                    app:logVerbose( "no collections to favor..." )
                end
            end
        end
        if selPhotos.selectedPhotos and #selPhotos.selectedPhotos > 0 then
            assert( selPhotos.mostSelPhoto, "sel photos without most-sel" )
            catalog:setSelectedPhotos( selPhotos.mostSelPhoto, selPhotos.selectedPhotos ) -- restore remaining selected photos.
            -- not sure what to do if original photos can not be restored, so...
        end
        if selPhotos.filterTable then
            catalog:setViewFilter( selPhotos.filterTable ) -- restore table values, even if same as before - table may have been recreated with same values,
                -- so its either blind restore, or element-by-element compare...
            app:logVerbose( "Previous lib filter table restored." )
        else
            app:logVerbose( "No previous lib filter table to restore." )
        end
    end
end



--- Make specified photo most selected, without changing other selections if possible.
--
--  @usage      photo source must already be active, or this won't work.
--
--  @return status
--  @return message
--
function Catalog:selectPhoto( photo )
    return cat:setSelectedPhotos( photo, cat:getSelectedPhotos() )
end



--- Determine if specified photo is buried in collapsed stack in folder of origin.
--
function Catalog:isBuriedInStack( photo, bm )
    local isStacked = self:getRawMetadata( photo, 'isInStackInFolder', bm ) 
    if not isStacked then
        return false
    end
    -- photo in stack.
    local stackPos = self:getRawMetadata( photo, 'stackPositionInFolder', bm )
    if stackPos == 1 then -- top of stack
        return false
    end
    -- photo in stack, not at top
    local collapsed = self:getRawMetadata( photo, 'stackInFolderIsCollapsed', bm )
    return collapsed -- buried if collapsed.
end



--- Set active sources, and verify all were properly set.
--
--  @return status
--  @return error-message
--
function Catalog:setActiveSources( sources )
    local try = 1
    local sts, msg
    repeat
        sts, msg = true, "Unable to make all specified sources active."
        local lookup = {}
        catalog:setActiveSources( sources ) -- restore original sources
        local asources = catalog:getActiveSources()
        if #asources == #sources then
            for i, src in ipairs( asources ) do
                lookup[src] = true
            end
            app:logVerbose( "Active sources set to: " )
            for i, src in ipairs( sources ) do
                if not lookup[src] then
                    sts, msg = false, "Source not settable: " .. src:getName()
                    break
                end
                app:logVerbose( src:getName() )
            end
        else -- some sources were dropped, probably took folders over collections, probably need the opposite.
            --app:logWarning( "Unable to restore all active sources." )
            sts = false
        end
        if sts then
            return true
        else
            try = try + 1
            if try <= 3 then
                LrTasks.sleep( .1 )
            else
                break
            end
        end
    until false
    return false, msg
end



--- Make specified photo the only photo selected, whether source is active or not.
--
--  @usage      present implementation satisfies by adding folder to source.<br>
--
--  @return     status, but NOT error message - logs stuff as it goes...
--
function Catalog:assurePhotoIsSelected( photo, photoPath )
    if photoPath and not photo then
        photo = catalog:findPhotoByPath( photoPath )
    elseif photo and not photoPath then
        photoPath = photo:getRawMetadata( 'path' )
    end
    if photo then
        catalog:setSelectedPhotos( photo, { photo } )
        if catalog:getTargetPhoto() ~= photo then -- photo not selected (not visible or not in filmstrip).
            local folderPath = LrPathUtils.parent( photoPath )
            local lrFolder = catalog:getFolderByPath( folderPath )
            local found = false
            if lrFolder then
            
                -- Note: No way to assure photo is selected, unless source becomes exclusive.
                
                local s, m = catalog:setActiveSources( lrFolder ) -- Note: calling context must restore active sources if need be. ###1
                if s then                    
                    app:logVerbose( "Set lr-folder as active source: ^1", folderPath )
                else
                    return false -- can't assure photo selected if can't assure source is set.
                end
                catalog:setSelectedPhotos( photo, { photo } )
    			if catalog:getTargetPhoto() ~= photo then -- photo not selected (not visible or not in filmstrip).
    				app:logVerbose( "Unable to select photo (^1) in newly set source folder (^2)", photoPath, lrFolder:getName() ) -- got this error once even though it was selected.
    			    -- may be due to stackage or lib filter.
    			else
    				app:logInfo( "Photo in newly selected source now selected: " .. photoPath )
    				return true
    			end
    			
            else
                -- app:logWarning( "Unable to select photo." ) -- could just be buried in stack.
            end
        else -- selected properly already.
            app:logVerbose( "Photo already selected: ^1", photoPath )
            return true
        end
    else
        app:logWarning( "No photo for path: " .. photoPath )
        return false
    end
    -- fall-through => not able to select existing photo.
    local isStacked = photo:getRawMetadata( 'isInStackInFolder' )
    if isStacked then
        local stackPos = photo:getRawMetadata( 'stackPositionInFolder' )
        if stackPos == 1 then
            app:logVerbose( "Unable to select photo that is top of stack: " .. photoPath )
        else
            local collapsed = photo:getRawMetadata( 'stackInFolderIsCollapsed' )
            if collapsed then
                app:logWarning( "Photo can not be selected when buried in collapsed stack: " .. photoPath )
                return false -- impossible to select, despite lib filter setting.
            else
                app:logVerbose( "Unable to select stacked photo despite not being collapsed in folder of origin: " .. photoPath ) -- may still be due to lib filter.
            end
        end
    else
        app:logVerbose( "Unable to select photo that is not in a stack: " .. photoPath )
    end
    -- fall-through => unable to select photo not buried in stack, try for lib-filtering next.
    catalog:setViewFilter{ -- equivalent of 'None'.
        columnBrowserActive = false, -- metadata
        filtersActive = false, -- attributes
        searchStringActive = false, -- text
    }
    LrTasks.sleep( .1 ) -- needs a moment to settle in. dunno if yield sufficient, but sleep seems safer. ###2
    -- Note: filter should be restored externally after selected photo processed, when appropriate.
    catalog:setSelectedPhotos( photo, { photo } )
	if catalog:getTargetPhoto() ~= photo then -- photo not selected (not visible or not in filmstrip).
		app:logWarning( "Unable to select photo (^1) even without lib filter", photoPath )
		return false
	else
		app:log( "Photo selected by lifting the lib filter: ^1", photoPath )
		return true
	end
end



--[[ *** save for possible future resurrection
function Catalog:setCropertyForPlugin( name, value, tries )
    local sts, msg
    app:call( Call:new{ name='Update Catalog Property', async = not LrTasks.canYield(), guard = App.guardSilently, main=function( call )
        local _value = catalog:getPropertyForPlugin( _PLUGIN, name ) -- get is fast compared to set.
        if _value == value then -- whether one is nil or not.
            sts = false
            return
        end
        -- fall-through => set
        if catalog.hasWriteAccess then -- not sure private access is enough
            catalog:setPropertyForPlugin( _PLUGIN, name, value )
            sts = true
            return
        else
            local s, m = cat:withRetries( tries or 15, catalog.withWriteAccessDo, "Updating catalog property", function( context )
                catalog:setPropertyForPlugin( _PLUGIN, name, value )
            end )
            if s then
                sts = true
            else
                error( m )
            end
        end
        
    end, finale=function( call, status, message )
        if not status then -- will only be seen if this is already being called from a task.
            msg = message
        end
    end } )
    return sts, msg -- note: always nil when not called from task.
end--]]



--- Set catalog metadata property if not already.
--
--  @param      name (string, required) property name
--  @param      value (string | date | number | boolean, required) property value
--  @param      tries (number, default 15) number of tries - only applies if internal catalog wrapping required.
--
--  @usage      *** This is for setting catalog properties, NOT for setting photo properties (use metadata-manager for that).
--  @usage      Will wrap with async task if need be (in which case BEWARE: returns are always nil, and property is not guaranteed).<br>
--              This mode appropriate for calling from plugin init module only.
--  @usage      Will wrap with catalog access if need be.
--  @usage      Reminder: you can only set for current plugin - you can read for any plugin if you have its ID.
--  @usage      No errors are thrown - see status and error message for results.
--  @usage      *** property whose name is photo-uuid is reserved for background task.
--
--  @return     status (boolean or nil) true iff property set to different value, false iff property need not be set - already same value, nil => error setting property.
--  @return     error-message (string or nil) nil if status true or false, else error message.
--
function Catalog:setPropertyForPlugin( name, value )

    if self.catKey == nil then
        self.catKey = str:pathToPropForPluginKey( catalog:getPath() )
    end
    local prefName = self.catKey .. "_" .. name
    app:setGlobalPref( prefName, value )
    return true

end



function Catalog:getPropertyForPlugin( name )

    if self.catKey == nil then
        self.catKey = str:pathToPropForPluginKey( catalog:getPath() )
    end
    local prefName = self.catKey .. "_" .. name
    return app:getGlobalPref( prefName )

end




--- Creates a virtual copy of one photo.
--
--  @param      photo (LrPhoto, default nil) Photo object to create virtual copy of, or nil to create copy of most selected photo.
--  @param      prompt (boolean, default false) Pass true to prompt user about this stuff, or false to let 'er rip and take yer chances (definitive status will be returned).
--
--  @usage      Use to create virtual copies until Lr4 ;-}
--  @usage      Must be called from asynchronous task.
--  @usage      No errors are thrown - check return values for status, and error message if applicable.
--  @usage      Can be used to create multiple copies, by calling in a loop - but is very inefficient for doing multiples like that.<br>
--              if you want multiples, you should code a new method that selects all photos you want copied, then issues the Ctrl/Cmd-'<br>
--              And for robustness, the routine should check for existence of all copies before returning with thumbs up.
--  @usage      Its up to calling context to assure Lightroom is in library or develop modules before calling.
--  @usage      Hint: calling context can restore selected photos upon return, or whatever...
--
--  @return     photo-copy (lr-photo) if virtual copy successfully created.
--  @return     error-message (string) if unable to create virtual copy, nil if user canceled.
--
function Catalog:createVirtualCopy( photo, prompt )
    local photoCopy, msg
    app:call( Call:new{ name="Create Virtual Copy", async=false, main=function( call )
        repeat
            if not photo then
                photo = catalog:getTargetPhoto()
            end
            if not photo then
                error( "No photo to create virtual copy of." )
            end
            local masterPhoto
            local photoPath = photo:getRawMetadata( 'path' )
            local isVirtualCopy = photo:getRawMetadata( 'isVirtualCopy' )
            local copyName = photo:getFormattedMetadata( 'copyName' )
            if isVirtualCopy then
                masterPhoto = photo:getRawMetadata( 'masterPhoto' )
                photoPath = photoPath .. " (" .. copyName .. ")"
            else
                masterPhoto = photo
            end
            
            local copies = masterPhoto:getRawMetadata( 'virtualCopies' )
            local lookup = {}
            for i, copy in ipairs( copies ) do
                lookup[copy] = true
            end

            -- local s, m = cat:selectOnePhoto( photo ) -- no big penalty if its already selected...
            -- highly unlikely this part will fail since it was selected to begin with, but cheap insurance...
            local s = cat:assurePhotoIsSelected( photo, photoPath ) -- can never be to sure...
            if s then
                app:logVerbose( "Photo selected for virtual copy creation: ^1", photoPath )
            else
                --return false, str:fmt( "Unable to select photo for virtual copy creation, error message: ^1", m ) -- m includes path.
                    -- no way it'll work if cant select it.
                return false, str:fmt( "Unable to select photo for virtual copy creation (see log file for details), path: ^1", photoPath )
                    -- no way it'll work if cant select it.
            end
            
            if prompt then
                repeat
                    local answer = app:show{
                        info = "^1 is about to attempt creation of a virtual copy of ^2\n\nFor this to work, there must not be any dialog boxes open in Lightroom, and focus must not be in any Lightroom text field.\n\nClick 'OK' to proceed, and check the 'Don\'t show again' box to suppress prompt in the future, or click 'Give Me a Moment' to hide this dialog box temporarily so you can clear the way, or click 'Cancel' to abort.",
                        subs = { app:getAppName(), photoPath },
                        buttons = { dia:btn( "OK", 'ok' ), dia:btn( "Give Me a Moment", 'other', false ) },
                        actionPrefKey="Create virtual copy" }
                    if answer == 'ok' then
                        break
                    elseif answer == 'other' then
                        app:sleepUnlessShutdown( 5 ) -- 5 seconds seems about right.
                    elseif answer == 'cancel' then
                        call:cancel() -- note: this only cancels this wrapper not calling wrapper.
                        photoCopy, msg = nil, nil
                        return
                    else
                        error( "bad answer: " .. str:to( answer ) )
                    end
                until false
            end
            local count = masterPhoto:getRawMetadata( 'countVirtualCopies' )
            local m
            if WIN_ENV then
                s, m = app:sendWinAhkKeys( "{Ctrl Down}'{Ctrl Up}" ) -- include post keystroke yield.
            else
                s, m = app:sendMacEncKeys( "Cmd-'" )
            end
            if not s then
                photoCopy, msg = nil, m
                return
            end
            local newCount = masterPhoto:getRawMetadata( 'countVirtualCopies' )
            local iters = 20
            while newCount <= count and iters > 0 and not shutdown do
                LrTasks.sleep( .1 )
                iters = iters - 1
                newCount = masterPhoto:getRawMetadata( 'countVirtualCopies' )
            end
            local sts = newCount > count
            if sts then
                local newCopies = masterPhoto:getRawMetadata( 'virtualCopies' )
                for i, photo in ipairs( newCopies ) do
                    if not lookup[photo] then
                        photoCopy = photo
                        break
                    end
                end
                if not photoCopy then
                    msg = "Virtual copy created, but it can't be found."
                end
            else
                msg = "Unable to create virtual copy of " .. photoPath .. " for unknown reason (hint: Lightroom should have been in (or gone to) Library or Develop module when the attempt was made)."
            end
        until true
    end, finale=function( call, status, message )
        if not status then
            msg = message
        end
    end } )
    return photoCopy, msg
end



--- Get list of photos in filmstrip.
--
--  @usage this function *may* not be perfect, and may return photos even if excluded by lib filter or buried in stack.
--      <br>    presently its working perfectly, but I don't trust it, and neither should you!?
--      <br>    *** originally: function Catalog:getFilmstripPhotos( assumeSubfoldersToo, bottomFeedersToo )
--
--  @return      array of photos - may be empty, but never nil (should not throw any errors).
--
function Catalog:getFilmstripPhotos( assumeSubfoldersToo, ignoreIfBuried )
--function Catalog:getFilmstripPhotos()
    local subfolders
    if assumeSubfoldersToo == nil then
        -- subfolders = false -- nil means true otherwise.
        subfolders = true -- nil means true otherwise. - true is not a bad default though.
    end
    if ignoreIfBuried == nil then
        ignoreIfBuried = true
    end
    local targetPhoto = catalog:getTargetPhoto()
    if targetPhoto == nil then
        return catalog:getTargetPhotos()
    end
    local sources = catalog:getActiveSources()
    if sources == nil or #sources == 0 then
        return {}
    end
    local photoDict = {} -- lookup
    local filmstrip = {} -- array
    local function addToDict( photos )
        local bm = catalog:batchGetRawMetadata( photos, { 'isInStackInFolder', 'stackPositionInFolder', 'stackInFolderIsCollapsed' } )
        for i, photo in ipairs( photos ) do
            if ignoreIfBuried then
                local isBuried = cat:isBuriedInStack( photo, bm )
                if isBuried then
                    --
                else
                    photoDict[photo] = true
                end
            else
                photoDict[photo] = true
            end
        end
    end
    local function getPhotosFromSource( source )
        if source.getPhotos then
            local photos = source:getPhotos( subfolders ) -- reminder: nil parameter behaves as true, not false.
            --local photos = source:getPhotos() -- At the moment, this function is doing exactly what I want: returning the photos as they contribute to filmstrip,
            -- and excluding bottom feeders - its ignoring the "include-children" parameter. I could have sworn it was previously attending to said parameter as documented.
            -- Although I'm glad it is behaving as it is, I fear problems that go away by themselves will return by themselves. ###3 - good for now I guess...
            addToDict( photos ) -- assure no duplication, in case overlapping sources.
            return
        elseif source.getChildren then
            local children = source:getChildren()
            for i, child in ipairs( children ) do
                getPhotosFromSource( child )
            end
        elseif source.type then
            app:logWarning( "Unrecognized source type: " .. source:type() )
        else
            app:logWarning( "Unrecognized source: " .. str:to( source ) )
        end
    end
    local sources = catalog:getActiveSources()
    -- local sc = 0
    for i, source in ipairs( sources ) do
        -- sc = sc + 1
        getPhotosFromSource( source )                            
    end    
    for k, v in pairs( photoDict ) do
        filmstrip[#filmstrip + 1] = k
    end
    return filmstrip
end



--- Assures collections are created in plugin set.
--
--  @param names (array of strings, required) sub-collection names to be created in plugin collection set.
--  @param tries (number, default = 20) maximum number of catalog access attempts before giving up.
--  @param doNotRemoveDevSuffixFromPluginName (boolean, default = false) pass 'true' if you want to keep the ' (Dev)' suffix in the development version of the collection set.
--
--  @usage NOT be called from a with-write-access-gate.
--
--  @return collection or throws error trying.
--
function Catalog:assurePluginCollections( names, tries, doNotRemoveDevSuffixFromPluginName )
    if type( names ) == 'string' then
        names = { names }
    end
    local pluginName = app:getPluginName()
    if not doNotRemoveDevSuffixFromPluginName then
        if str:isEndingWith( pluginName, " (Dev)" ) then -- remove dev identification suffix if present - documented in plugin generator default pref backer file. ###4
            pluginName = pluginName:sub( 1, pluginName:len() - 6 )
        end
    end
    local colls = {}
    local set
    local function assure1()
        set = catalog:createCollectionSet( pluginName, nil, true ) -- nil => at root, true => return existing.
        if set then
            app:logVerbose( "Plugin collection set is created" )
        else
            app:error( "Unable to create plugin collection set - unknown error." )
        end
    end
    local function assure2( name )
        local collection = catalog:createCollection( name, set, true )
        if collection then
            app:logVerbose( "Plugin collection is created: ^1", name )
            colls[#colls + 1] = collection
        else
            app:error( "Unable to create plugin collection - unknown error." )
        end
    end
    --if catalog.hasPrivateWriteAccess then
    --    app:callingError( "Do not call from write-access method." )
    --else
        app:log( "Assuring plugin collections for ^1", app:getPluginName() ) 
        local s, m = self:withRetries( tries or 20, catalog.withWriteAccessDo, "Create plugin collection set", function( context )
            assure1()
            for i, v in ipairs( names ) do
                assure2( v )
            end
        end )
        if s then
            --local s, m = self:withRetries( tries or 20, catalog.withWriteAccessDo, "Create collection", function( context )
            --    assure2()
            --end )
            if not s then
                app:error( m )
            end
        else
            app:error( m )
        end
    --end
    return unpack( colls )
end



--- Assures collection is created in plugin set.
--
--  @usage NOT be called from a with-write-access-gate.
--
--  @return collection or throws error trying.
--
function Catalog:assurePluginCollection( name, tries )
    local coll = self:assurePluginCollections( { name }, tries )
    return coll
end



--- Like lr-catalog method of same name, except one day it will not be case sensitive.
--
function Catalog:findPhotoByPath( file, copyName, rawMeta, fmtMeta )
    local realPhoto = catalog:findPhotoByPath( file ) -- ###2 - not robust: should be retrofitted with logic from tree-sync or photooey web-photos.
    if not str:is( copyName ) then
        return realPhoto
    elseif not realPhoto then
        return false
    end
    -- get virtual copy
    local vCopies = self:getRawMetadata( realPhoto, 'virtualCopies', rawMeta )
    if (vCopies ~= nil) and #vCopies > 0 then
        for i, vCopy in ipairs( vCopies ) do
            local cName = self:getFormattedMetadata( vCopy, 'copyName', fmtMeta )
            if cName == copyName then
                return vCopy
            end
        end
    end
    return nil
end
Catalog.isFileInCatalog = Catalog.findPhotoByPath -- synonym.



--- Get raw metadata, preferrable from that read in batch mode, else from photo directly.
--
function Catalog:getRawMetadata( photo, name, rawMeta )
    local data
    if rawMeta ~= nil then
        data = rawMeta[photo]
        if data ~= nil then
            return data[name]
        else
            return nil
        end
    else
        return photo:getRawMetadata( name )
    end
end
        
        
            
--- Get formatted metadata, preferrable from that read in batch mode, else from photo directly.
--
function Catalog:getFormattedMetadata( photo, name, fmtMeta )
    local data
    if fmtMeta ~= nil then
        data = fmtMeta[photo]
        if data ~= nil then
            return data[name]
        else
            return nil
        end
    else
        return photo:getFormattedMetadata( name )
    end
end



--- Set collection photos.
--
--  @param coll (lr-collection object, required)
--  @param photos (array of lr-photos, required) may be empty, but may not be nil.
--
--  @return nil - throws error if problem.
--
function Catalog:setCollectionPhotos( coll, photos )

    if coll ~= nil and coll.type ~= nil and type( coll.type ) == 'function' and coll:type() == 'LrCollection' then
        --
    else
        app:callingError( "Not lr-collection object: ^1", str:to( coll ) )
    end
    if photos ~= nil and type( photos ) == 'table' then
        -- Its OK to pass an empty array of photos (equivalent to clearing a collection), but check before calling if it doesn't make sense.
    else
        app:callingError( "Not array of photos: ^1", str:to( photos ) )
    end
    local name = coll:getName()
    local s, m = cat:withRetries( 20, catalog.withWriteAccessDo, str:fmt( "Removing photos from ^1", name ), function( context )
        coll:removeAllPhotos()
    end )
    if s then
        if #photos > 0 then
            s, m = cat:withRetries( 20, catalog.withWriteAccessDo, str:fmt( "Adding photos to ^1", name), function( context )
                coll:addPhotos( photos )
            end )
        end
    end
    if not s then
        error( m )
    end
end
       


--- Get local image id for photo.
--
--  @param photo the photo
--
--  @return imageId (string) local database id corresponding to photo, or nil if problem.
--  @return message (string) error message if problem, else nil.
--
function Catalog:getLocalImageId( photo )
    local imageId
    local s = tostring( photo ) -- THIS IS WHAT ALLOWS IT TO WORK DESPITE LOCKED DATABASE (id is output by to-string method).
    local p1, p2 = s:find( 'id "' )
    if p1 then
        s = s:sub( p2 + 1 )
        p1, p2 = s:find( '" )' )
        if p1 then
            imageId = s:sub( 1, p1-1 )
        end
    end
    if str:is( imageId ) then
        -- app:logVerbose( "Image ID: ^1", imageId )
        return imageId
    else
        return nil, "bad id"
    end
end        
            


--- Get directory containing catalog (just a tiny convenience/reminder function).
--
function Catalog:getCatDir()
    return LrPathUtils.parent( catalog:getPath() )
end



--  Get xmp status (on-hold: locked photos always appear "changed" relative to xmp due to lockage metadata).
--
--  @return status (number) nil if virtual copy, 0 if last-edit-time same as, 1 if photo edited since xmp file saved, -1 if xmp changed since photo edited.
--[[
function Catalog:getXmpStatus( photo, rawMeta )
    local fileFormat
    local isVirtual
    if rawMeta then
        fileFormat = rawMeta[photo].fileFormat
        isVirtual = rawMeta[photo].isVirtual
    else
        fileFormat = photo:getRawMetadata( 'fileFormat' )
        isVirtual = photo:getRawMetadata( 'isVirtual' )
    end
    if isVirtual then return
        return nil
end
--]]



return Catalog

