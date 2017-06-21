--[[
        ExtendedExportFilter.lua
        
        Unlike most classes prefixed by the name "Extended...",
        @8/Nov/2011 14:28 there is no base "export filter" class that this to extends.
        
        Still, one day there probably will be... ###3
--]]


local ExtendedExportFilter = {}

local dbg = Object.getDebugFunction( 'ExtendedExportFilter' )



--- This function will check the status of the Export Dialog to determine 
--  if all required fields have been populated.
--
function ExtendedExportFilter._updateFilterStatus( props, name, value )
    app:call( Call:new{ name="Update Filter Status", guard=App.guardSilent, main=function( context )
        local message = nil
        repeat
      	
      	    app:show( name )
      	
        	if name == 'blah' then
        	    if value then
        	        message = "Can't do it..."
        	        break
        	    end
        	--elseif
        	--else
    	    end
            
        until true	
    	if message then
    		-- Display error.
	        props.LR_cantExportBecause = message
    
    	else
    		-- All required fields and been populated so enable Export button, reset message and set error status to false.
	        props.LR_cantExportBecause = nil
	        
    	end
    end } )
end




--- This optional function adds the observers for our required fields metachoice and metavalue so we can change
--  the dialog depending if they have been populated.
--
function ExtendedExportFilter.startDialog( propertyTable )

	-- propertyTable:addObserver( 'LR_ui_enableMinimizeMetadata', ExtendedExportFilter._updateFilterStatus ) - cant watch for lr-props
	--ExtendedExportFilter._updateFilterStatus( propertyTable )

end




--- This function will create the section displayed on the export dialog 
--  when this filter is added to the export session.
--
function ExtendedExportFilter.sectionForFilterInDialog( f, propertyTable )
	
	return {
		title = app:getAppName(),
		f:row {
			f:static_text {
				title = "Assures keywords assigned to exported photo are exactly the same as the photo being exported,\nregardless of 'Include On Export' attribute, or anything else...",
			},
		},
    }
	
end



ExtendedExportFilter.exportPresetFields = {
	-- { key = 'keywords', default = 'all' },
}



local prompt = false
local warning1 = false
local warning2 = false
--- This function obtains access to the photos and removes entries that don't match the metadata filter.
--
function ExtendedExportFilter.shouldRenderPhoto( exportSettings, photo )

    -- Debug.lognpp( exportSettings )
    
    if exportSettings.LR_reimportExportedPhoto then
        -- good
    else
        if not warning1 then
            app:logWarning( "*** Not being reimported into catalog - can't export." )
            app:show{ warning="Photos must be added to catalog to export with ^1 post-process action inline.", app:getAppName() }
            warning1 = true
        end
        return false
    end

    if not exportSettings.LR_minimizeEmbeddedMetadata and exportSettings.LR_metadata_keywordOptions == "lightroomHierarchical" then
        -- Debug.logn( "Exporting hierarchichal keywords" )
        return true
    else
        if not warning2 then
            app:logWarning( "*** Not exporting hierarchical keywords - can't export." )
            app:show{ warning="Not exporting hierarchical keywords - can't export with ^1 post-process action inline.", app:getAppName() }
            warning2 = true
        end
        return false
    end

end



--- Post process rendered photos.
--
function ExtendedExportFilter.postProcessRenderedPhotos( functionContext, filterContext )

    local exportSettings = filterContext.propertyTable

    -- Debug.lognpp( exportSettings )

    local n = 0
    local photos = {}
    local savePhotos = {}
    
    local correctionDelay = app:getPref( 'correctionDelay' ) or .5
    if correctionDelay < 0 then
        app:logWarning( "correction delay set to 0" )
        correctionDelay = 0
    elseif correctionDelay > 5 then
        app:logWarning( "max correction delay is 5" )
        correctionDelay = 5
    end
    app:log( "Correction delay is ^1", str:plural( correctionDelay, "second", true ) )
    
    local saveMetadataDelay = app:getPref( 'saveMetadataDelay' ) or 1
    if saveMetadataDelay < 0 then
        app:logWarning( "save metadata delay set to 0" )
        saveMetadataDelay = 0
    elseif saveMetadataDelay > 5 then
        app:logWarning( "max save-metadata delay is 5" )
        saveMetadataDelay = 5
    end
    app:log( "Save metadata delay is ^1", str:plural( saveMetadataDelay, "second", true ) )

    -- ###1 VIDEO
    
    for sourceRendition, renditionToSatisfy in filterContext:renditions() do
        repeat
            local success, pathOrMessage = sourceRendition:waitForRender()
            if success then
                Debug.logn( "Source \"rendition\" created at " .. pathOrMessage )
                if pathOrMessage ~= renditionToSatisfy.destinationPath then
                    app:logWarning( "Destination path mixup, expected '^1', but was '^2'", renditionToSatisfy.destinationPath, pathOrMessage )
                end
            else -- problem exporting original, which in my case is due to something in metadata blocks that Lightroom does not like.
                app:logWarning( "Unable to export '^1' to original format, error message: ^2. This may not cause a problem with this export, but does indicate a problem with the source photo.", renditionToSatisfy.destinationPath, pathOrMessage )
                pathOrMessage = renditionToSatisfy.destinationPath
            end    
            app:call( Call:new{ name="Post-Process Rendered Photo", main=function( context )

                local test = cat:findPhotoByPath( pathOrMessage )
                if not test then
                    prompt = true
                end
                photos[#photos + 1] = { sourceRendition.photo, pathOrMessage }
                app:logVerbose( "^1 to receive all keywords", pathOrMessage )
            
            end, finale=function( call, status, message )
                if status then
                    --Debug.logn( "didone" ) -- errors are not automatically logged for base calls, just services.
                else
                    app:logErr( message ) -- errors are not automatically logged for base calls, just services.
                end
            end } )
        until true
    end
    
    if #photos > 0 then
        app:call( Call:new{ name="Copy Keywords to Exported Photos", async=true, main=function( call )
            if prompt then -- at least one photo was not in the catalog
                local answer = app:show{ info="Please wait until export appears to be otherwise complete, then click 'Export Appears Complete', at which point keywords assigned to exported photos will be corrected.\n \nOr, press 'Cancel' to skip keyword correction.\n \n(you will *not* get this message if all photos being re-exported or re-published are already in the catalog)",
                          buttons = { dia:btn( "Export Appears Complete", 'ok' ) } }
                if answer == 'cancel' then
                    call:cancel()
                    return
                end
            end
            call.scope = LrProgressScope {
                title = "Correcting keywords",
                caption = "Please wait...",
                functionContext = call.context,
            }
            if correctionDelay > 0 then
                LrTasks.sleep( correctionDelay )
            end
            call.saveSel = cat:saveSelPhotos()
            local s, m = cat:withRetries( 10, catalog.withWriteAccessDo, call.name, function( context )
                local function wait( path, index )
                    local maxTime = 5 - ( ( 1 * index ) / #photos) -- wait longest for first photos... from 5 down to 1
                        -- (note: this is after user claimed export was complete).
                    local startTime = LrDate.currentTime()
                    repeat
                        local photo = cat:findPhotoByPath( path )
                        if photo then
                            return photo
                        elseif ( LrDate.currentTime() - startTime ) > maxTime then
                            break
                        end
                        LrTasks.sleep( .1 )
                    until false
                    return nil
                end
                for i, v in ipairs( photos ) do
                    repeat
                        local fromPhoto = v[1]
                        local toPath = v[2]
                        local toPhoto = wait( toPath, i )
                        if toPhoto then
                            app:logVerbose( "Adding all keywords to ^1", toPath )
                        else
                            app:log( str:fmt( "Exported, but not added to catalog: ^1", toPath ) )
                            break
                        end
                        local lookup = {}
                        local keywords = fromPhoto:getRawMetadata( "keywords" )
                        if keywords then
                            for i,v in ipairs( keywords ) do
                                Debug.logn( "Adding", v:getName() )
                                toPhoto:addKeyword( v )
                                lookup[v] = true
                            end
                        end
                        local keywords = toPhoto:getRawMetadata( "keywords" )
                        if keywords then
                            for i,v in ipairs( keywords ) do
                                if not lookup[v] then
                                    Debug.logn( "Removing", v:getName() )
                                    toPhoto:removeKeyword( v )
                                end
                            end
                        end
                        app:log( "Added all keywords to ^1", toPath )
                        -- can't write custom metadata from another plugin.
                        savePhotos[#savePhotos + 1] = toPhoto
                        n = n + 1
                    until true
                    if call.scope:isCanceled() then
                        call:cancel()
                        break
                    else
                        call.scope:setPortionComplete( i, #photos )
                    end
                end
            end )
            if s then
                if app:getPref( 'saveMetadata' ) and #savePhotos > 0 then
                    app:log( "Saving metadata." )
                    if saveMetadataDelay > 0 then
                        LrTasks.sleep( saveMetadataDelay ) -- .3 is enough on my machine for single photo - I rely on prompt in case multiple photos.
                    end
                    if #savePhotos == 1 then
                        cat:savePhotoMetadata( savePhotos[1], nil, nil, call, false )
                    else
                        cat:saveMetadata( savePhotos, true, false, false, call ) -- action-pref-key not working unless plugin export (e.g. not hard-disk).
                    end
                else
                    app:log( "Not saving metadata." )
                end
            else
                error( m )
            end
        
        end, finale=function( call, status, message )
            if call.saveSel then
                cat:restoreSelPhotos( call.saveSel )
            end
            app:log()
            if status then
                app:log( "^1 received all keywords", str:plural( n, "photo" ) )
                if call:isCanceled() then
                    app:log( "Canceled." )
                elseif call:isAborted() then
                    app:log( "Aborted." )
                else
                    app:log( "Done." )
                end
            else
                app:logErr( message ) -- errors are not automatically logged for base calls, just services.
            end
            app:log( "\n\n" )
            
            Debug.showLogFile()
            
        end } )
    else
        app:log( "No photos passed through for keyword assignment this export." )
    end
end



return ExtendedExportFilter
