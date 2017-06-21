--[[
        Metadata.lua
--]]        


local CustomMetadata, dbg = Object:newClass{ className = 'CustomMetadata', register = true }



--- Constructor for extending class.
--
function CustomMetadata:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function CustomMetadata:new( t )
    local o = Object.new( self, t )
    return o
end



--- Set custom metadata property of photo, if not already.
--
--  @param      photo (lr-photo, required) photo set metadata on.
--  @param      name (string, required) property name
--  @param      value (string | date | number | boolean, required) property value
--  @param      version (number, default nil) optional version number.
--  @param      noThrow (boolean, default false) optional no-throw, if omitted, errors are thrown.
--  @param      tries (number, default 10) number of tries - only applies if internal catalog wrapping required.
--
--  @usage      Will wrap with catalog access if need be.
--  @usage      Always throws errors for catastrophic failure, just not for undeclared metadata if no-throw.
--
--  @return     status (boolean or nil) true iff property set to different value, false iff property need not be set - already same value, nil => error setting property.
--  @return     error-message (string or nil) nil if status true or false, else error message.
--
function CustomMetadata:update( photo, name, value, version, noThrow, tries )
    local _value, _errm = photo:getPropertyForPlugin( _PLUGIN, name, version, noThrow )
    if _errm then -- not doable & no-throw.
        return nil, _errm
    end
    if _value == value then -- whether one is nil or not.
        return false
    end
    
    -- fall-through => set
    if catalog.hasPrivateWriteAccess then -- has at least private write access, this should succeed since read succeeded.
        photo:setPropertyForPlugin( _PLUGIN, name, value, version )
        return true, _value -- return old value for logging purposes or whatever.
    else
        local status, message = cat:withRetries( tries or 10, catalog.withPrivateWriteAccessDo, function( context )
            photo:setPropertyForPlugin( _PLUGIN, name, value, version )
        end )
        if status then
            return true, _value
        else
            return nil, message
        end
    end
end




function CustomMetadata:_promptForMetadataSaveOrRead( call, _SaveOrRead )

    local save = _SaveOrRead == 'Save'
    local read = _SaveOrRead == 'Read'
    local tidbit
    if save then
        tidbit = "in"
    elseif read then
        tidbit = "from"
    else
        app:callingError( "bad op" )
    end
    if not _PLUGIN.enabled then
        app:show{ warning="Plugin must be enabled in plugin manager (hint: 'Enable' button in 'Status' section)." }
        call:cancel()
        return nil
    end
        
    local photos = catalog:getTargetPhotos()
    local dir = LrPathUtils.child( LrPathUtils.parent( catalog:getPath() ), _PLUGIN.id )
    if photos == nil then
        app:show{ warning="No photos to " .. saveOrRead }
        call:cancel()
        return nil
    end
    if dia:isOk( "^1 custom metadata for ^2 ^3 ^4?", _SaveOrRead, str:plural( #photos, "photo", true ), tidbit, dir ) then
        return { photos=photos, dir=dir }
    else
        call:cancel()
        return nil
    end
        
end





--- Save (all) custom metadata for specified photos, to disk.
--
--  @usage includes user prompt and the whole nine yards.
--  @usage presently saves in sibling directory of catalog (named plugin-id), prefixed by photo path.
--
--  @return status (boolean) true if operation completed without uncaught error - there may have been individual file errors logged.
--  @return message (string) error message if status false.
--
function CustomMetadata:save()
    return app:call( Service:new{ name="Custom Metadata - Save", async=true, guard=App.guardVocal, main=function( call )
        local pluginId = _PLUGIN.id
        local response = self:_promptForMetadataSaveOrRead( call, "Save" )
        if response == nil then
            return
        end
        local photos = response.photos
        local dir = response.dir
        call.scope = LrProgressScope {
            title = str:fmt( "Saving custom metadata for ^1", str:plural( #photos, "photo", true ) ),
            caption = "Please wait...",
            functionContext = call.context,
        }
        app:log( "Saving custom metadata for plugin (^2): ^1", pluginId, str:plural( #photos, "photo" ) )
        local emptyXml = str:fmt( '<?xml version=1.0?>\n<custom-metadata pluginId="^1"></custom-metadata>', pluginId )
        local metaXml
        local rootElem
        local metaLookup
        local function populateMetaLookup()
            metaLookup = {}
            for i, v in ipairs( rootElem ) do
                metaLookup[v.xarg[1].text] = v
            end
        end
        local incl = app:getPref( 'metadataSaveInclusions' ) -- this is your "out" in case some metadata items are better left unsaved/restored.
        if incl ~= nil then
            assert( type( incl ) == 'table', "inclusions must be table" )
            for k, v in tab:sortedPairs( incl ) do
                if v then
                    app:log( "Including '^1'", k )
                end
            end
        else
            app:log( "Including all items, unless explicitly being excluded." )
        end
        local excl = app:getPref( 'metadataSaveExclusions' ) -- this is your "out" in case some metadata items are better left unsaved/restored.
        if excl == nil then
            app:log( "No exclusions.\n" )
            excl = {}
        elseif type( excl ) == 'table' then
            for k, v in tab:sortedPairs( excl ) do
                if v then
                    app:log( "Excluding '^1'", k )
                end
            end
            app:log( "\n" )
        else
            app:error( "exclusions should be table, typically defined in advanced settings" )
        end
        local function addMeta( meta ) -- to local meta-xml
            -- meta = id, value, sourcePlugin
            -- app:logVerbose( "Custom metadata being added: ^1=^2 (^3)", meta.id, meta.value, type( meta.value ) )
            if excl[meta.id] then
                return
            end
            if incl ~= nil and not incl[meta.id] then
                return
            end
            local typ
            if meta.value == nil then
                typ = 'nil'
            else
                typ = type( meta.value )
            end
            local xmlElem
            if metaLookup[meta.id] then
                xmlElem = metaLookup[meta.id]
                if xmlElem.xarg[3].text == 'nil' then
                    xmlElem.xarg[2].text = str:to( meta.value )
                    xmlElem.xarg[3].text = typ
                elseif xmlElem.xarg[3].text == typ then
                    xmlElem.xarg[2].text = str:to( meta.value )
                else
                    app:logWarning( "Metadata type for ^1 was ^2 (value='^4'), being overwritten with type ^3, value='^5'", meta.id, xmlElem.xarg[3].text, typ, xmlElem.xarg[2].text, meta.value )
                    xmlElem.xarg[2].text = str:to( meta.value )
                    xmlElem.xarg[3].text = typ
                end
            else
                xmlElem = { label="metadata-item", xarg={ { name="id", text=meta.id }, { name="value", text=str:to( meta.value ) }, { name="type", text=typ } } }
                rootElem[#rootElem + 1] = xmlElem -- ###1 may be a duplicate, and hence metadata will grow forever...
                metaLookup[meta.id] = xmlElem
            end
        end
        local rawMeta = catalog:batchGetRawMetadata( photos, { 'path' } )
        for i, photo in ipairs( photos ) do
            repeat
                local before
                local photoPath = rawMeta[photo].path
                local photoFilename = LrPathUtils.leafName( photoPath )
                local file = LrPathUtils.child( dir, LrPathUtils.addExtension( photoFilename, "custom-metadata.xml" ) ) -- add-extension may take care of character encoding(?)
                app:log( "Saving custom metadata of ^1 to ^2", photoPath, file )
                if fso:existsAsFile( file ) then
                    local c, m = fso:readFile( file ) -- c = content or error message
                    if c then
                        if str:is( c ) then
                            before = c
                            metaXml = xml:parseXml( c )
                            rootElem = metaXml[2]
                            if rootElem == nil then
                                app:logError( "Invalid xml file: ^1 - root element is nil - not saving custom metadata for ^2", file, photoPath )
                                break
                            elseif type( rootElem ) ~= 'table' then
                                app:logError( "Invalid xml file: ^1 - root element should be table - not saving custom metadata for ^2", file, photoPath )
                                break
                            elseif rootElem.label ~= 'custom-metadata' then
                                app:logError( "Invalid xml file: ^1 - root element should be named 'custom-metadata', not '^3' - not saving custom metadata for ^2", file, photoPath, ( rootElem.label or 'nil' ) )
                                break
                            else
                                if rootElem.xarg ~= nil then
                                    local arg
                                    for i, v in ipairs( rootElem.xarg ) do -- really should have method for reading attrs ###2
                                        if rootElem.xarg[i].name == 'pluginId' then
                                            arg = rootElem.xarg[i]
                                            break
                                        end
                                    end
                                    if arg then -- a bit presumptious to require it be first.
                                        if arg.text ~= pluginId then
                                            app:logError( "Invalid plugin id, found '^1' but expected '^2'", arg.text, pluginId )
                                            break
                                        else
                                            app:log( "Pre-existing custom metadata file appears to be valid: ^1", file )
                                            populateMetaLookup()
                                        end
                                    else
                                        app:logError( "First attribute of root element must be pluginId, file: ^1", file )
                                        break
                                    end
                                else
                                    app:logError( "Root element has no attributes, file: ^1", file )
                                    break
                                end
                            end
                        else
                            -- do not throw error since one file error should not the whole operation deny...
                            app:logError( "No content in '^1' - you may need to delete it before custom metadata will be saved for '^2'", file, photoPath )
                            break
                        end
                    else
                        -- do not throw error since one file error should not the whole operation deny...
                        app:logError( "Unable to read custom metadata file, error message: ^1 - custom metadata not saved for ^2", m, photoPath ) -- error message includes offending file-path.
                        break
                    end
                else
                    metaXml = xml:parseXml( emptyXml )
                    -- Debug.lognpp( metaXml )
                    rootElem = metaXml[2]
                    metaLookup = {}
                    -- Debug.lognpp( "Virginal root", rootElem )
                    app:log( "Pre-existing custom-metadata file does not exist: ^1", file )
                end
                local metadata = photo:getRawMetadata( 'customMetadata' ) -- all plugins
                for k, v in pairs( metadata ) do
                    if pluginId == nil then
                        addMeta( v )
                    elseif pluginId == v.sourcePlugin then
                        addMeta( v )
                    else
                        -- not saving...
                    end
                end
                local s, t = pcall( xml.serialize, xml, metaXml ) -- throws error if serialization failure
                if s then
                    --app:logVerbose( file )
                    local chg
                    if before then
                        --app:logVerbose( "Before" )
                        --app:logVerbose( before )
                        --app:logVerbose( "After" )
                        --app:logVerbose( t )
                        if before ~= t then
                            chg = true
                        -- else
                        end
                    else
                        --app:logVerbose( "New" )
                        --app:logVerbose( t )
                        chg = true
                    end
                    if chg then
                        local s, m = fso:assureAllDirectories( dir )
                        if s then
                            local s, m = fso:writeFile( file, t )
                            if s then
                                app:log( "Saved custom metadata for ^1 in ^2", photoPath, file )
                            else
                                app:logError( "Unable to save custom metadata for ^1, error message: ^2", photoPath, m ) -- error message contains offencting file path.
                            end
                        else
                            app:logError( "Unable to save custom metadata for ^1, error message: ^2", photoPath, m ) -- error message contains offencting file path.
                        end
                    else
                        app:log( "Custom metadata for ^1 has not changed, not writing ^2", photoPath, file )
                    end
                else
                    app:logError( "Unable to save custom metadata for ^1, error message: ^2", photoPath, t ) -- error message contains offencting file path.
                end
            until true
            if call.scope:isCanceled() then
                call:cancel()
                return
            else
                call.scope:setCaption( str:fmt( "^1 %", string.format( "%2u", ( i * 100 ) / #photos ) ) )
                call.scope:setPortionComplete( i, #photos )
            end
        end
    end } )
end



--- Read (all) custom metadata for specified photos, from disk.
--
--  @usage includes user prompt and the whole nine yards.
--  @usage presently expects files in sibling directory of catalog (named plugin-id), prefixed by photo path.
--
--  @return status (boolean) true if operation completed without uncaught error - there may have been individual file errors logged.
--  @return message (string) error message if status false.
--
function CustomMetadata:read()
    return app:call( Service:new{ name="Custom Metadata - Read", async=true, guard=App.guardVocal, main=function( call )
        local pluginId = _PLUGIN.id
        local response = self:_promptForMetadataSaveOrRead( call, "Read" )
        if response == nil then
            return
        end
        local photos = response.photos
        local dir = response.dir
        call.scope = LrProgressScope {
            title = "Reading custom metadata",
            functionContext = call.context,
        }
        app:log( "Reading custom metadata for plugin (^2): ^1", pluginId, str:plural( #photos, "photo" ) )
        local metaXml
        local rootElem
        local rawMeta = catalog:batchGetRawMetadata( photos, { 'path' } )
        for i, photo in ipairs( photos ) do
            repeat
                local changes = 0
                local photoPath = rawMeta[photo].path
                local photoFilename = LrPathUtils.leafName( photoPath )
                local file = LrPathUtils.child( dir, LrPathUtils.addExtension( photoFilename, "custom-metadata.xml" ) ) -- add-extension may take care of character encoding(?)
                app:log( "Considering reading custom metadata for ^1", photoPath )
                if fso:existsAsFile( file ) then
                    local c, m = fso:readFile( file ) -- c = content or error message
                    if c then
                        if str:is( c ) then
                            metaXml = xml:parseXml( c )
                            rootElem = metaXml[2]
                            if rootElem == nil then
                                app:logError( "Invalid xml file: ^1 - root element is nil - not saving custom metadata for ^2", file, photoPath )
                                break
                            elseif type( rootElem ) ~= 'table' then
                                app:logError( "Invalid xml file: ^1 - root element should be table - not saving custom metadata for ^2", file, photoPath )
                                break
                            elseif rootElem.label ~= 'custom-metadata' then
                                app:logError( "Invalid xml file: ^1 - root element should be named 'custom-metadata', not '^3' - not saving custom metadata for ^2", file, photoPath, ( rootElem.label or 'nil' ) )
                                break
                            else
                                if rootElem.xarg ~= nil then
                                    local arg
                                    for i, v in ipairs( rootElem.xarg ) do -- really should have method for reading attrs ###2
                                        if rootElem.xarg[i].name == 'pluginId' then
                                            arg = rootElem.xarg[i]
                                            break
                                        end
                                    end
                                    if arg then -- a bit presumptious to require it be first.
                                        if arg.text ~= pluginId then
                                            app:logError( "Invalid plugin id, found '^1' but expected '^2'", arg.text, pluginId )
                                            break
                                        else
                                            app:logVerbose( "Custom metadata file appears to be valid: ^1", file )
                                        end
                                    else
                                        app:logError( "First attribute of root element must be pluginId, file: ^1", file )
                                        break
                                    end
                                else
                                    app:logError( "Root element has no plugin attribute, file: ^1", file )
                                    break
                                end
                            end
                        else
                            -- do not throw error since one file error should not the whole operation deny...
                            app:logError( "No content in '^1' - you may need to delete it before custom metadata will be saved for '^2'", file, photoPath )
                            break
                        end
                    else
                        -- do not throw error since one file error should not the whole operation deny...
                        app:logError( "Unable to read custom metadata file, error message: ^1 - custom metadata not saved for ^2", m, photoPath ) -- error message includes offending file-path.
                        break
                    end
                else
                    app:log( "Saved custom metadata file does not exist: ^1", file )
                    break
                end
                if #rootElem > 0 then
                    for i, elem in ipairs( rootElem ) do            
                        local id
                        local val
                        local typ
                        for i2, attr in ipairs( elem.xarg ) do
                            if attr.name == 'id' then
                                id = attr.text
                            elseif attr.name == 'value' then
                                val = attr.text
                            elseif attr.name == 'type' then
                                typ = attr.text
                            else
                                app:logVerbose( "Attr '^1' ignored, value: ^2", attr.name, attr.text )
                            end
                        end
                        if id ~= nil then
                            if val ~= nil then -- presently even "nil" values have non-nil value attribute written - type is used to distinquish.
                                if typ ~= nil then
                                    local upd
                                    local value
                                    if typ == 'nil' then
                                        assert( val == 'nil', "val not consistent with typ nil" )
                                        -- app:logVerbose( "Setting ^1 to nil", id )
                                        value = nil -- for emphasis
                                        upd = true
                                    elseif typ == 'string' then
                                        value = val
                                        -- app:logVerbose( "Setting ^1 to string: ^2", id, value )
                                        upd = true
                                    elseif typ == 'number' then
                                        value = num:numberFromString( val )
                                        if value ~= nil then
                                            -- app:logVerbose( "Setting ^1 to number: ^2", id, val )
                                            upd = true
                                        else
                                            app:logWarning( "Can't set ^1 - type is 'number' but value isn't: ^2", id, val )
                                            upd = false
                                        end
                                    elseif typ == 'boolean' then
                                        value = bool:booleanFromString( val )
                                        if value ~= nil then
                                            upd = true
                                            -- app:logVerbose( "Setting ^1 to boolean: ^2", id, val )
                                        else
                                            upd = false
                                            app:logWarning( "Can't set ^1 - type is 'boolean' but value isn't: ^2", id, val )
                                        end
                                    end
                                    assert( upd ~= nil, "upd must be set" )
                                    if upd then
                                        local s, m = self:update( photo, id, value, nil, true, 20 ) -- version=nil, no-throw=true, 20 tries.
                                        if s ~= nil then -- definitive
                                            if s then
                                                app:logVerbose( "'^1' changed from '^2' to '^3'", id, str:to( m ), str:to( value ) )
                                                changes = changes + 1
                                            else
                                                -- not changed.
                                            end
                                        else
                                            app:logError( m )
                                        end
                                    -- else warning logged
                                    end
                                else
                                    app:logWarning( "No type for ^1, value is '^2'", id, val )
                                end
                            else
                                app:logWarning( "No value for '^1'", id )
                            end
                        else
                            app:logWarning( "No id attr" )
                        end
                    end
                    app:log( "^1 changed.", str:plural( changes, "metadata item", true ) )
                else
                    app:logWarning( "No custom metadata items for '^1' are present in '^2'", photoPath, file )
                end
            until true
        end
    end } )
end



--- Consolidate custom metadata for specified plugin into a lookup table (dictionary) form.
--
--  @param photo (LrPhoto, required) photo
--  @param pluginId (string, required) plugin id.
--  @param cMeta - (table, optional) batch of raw metadata including custom metadata for all plugins.
--
--  @return table - id/value members, or empty - never nil.
--
function CustomMetadata:getMetadata( photo, pluginId, cMeta )
    local r = {}
    if cMeta then
        local t = cMeta[photo].customMetadata -- throw error if custom-metadata not included.
        for k, v in pairs( t ) do
            local p1, p2 = k:find( pluginId )
            if p1 ~= nil then
                if p1 == 1 then -- starts with
                    r[k:sub( p2 + 2 )] = v -- skip over plugin id and '.'
                end
            end
        end
    else
        local s = photo:getRawMetadata( 'customMetadata' )
        -- dbg( s )
        for i, t in ipairs( s ) do
            if t.sourcePlugin == pluginId then
                r[t.id] = t.value
            end
        end
    end
    return r
end



--- Gets an array of custom metadata specs, from Metadata.lua
--
function CustomMetadata:getMetadataSpecs()
    local metaFilename = app:getInfo( 'LrMetadataProvider' )
    if metaFilename == nil then
        return nil
    end
    local metaFile = LrPathUtils.child( _PLUGIN.path, metaFilename )
    if not fso:existsAsFile( metaFile ) then
        return nil, "Metadata file missing: " .. metaFile
    end
    local s, d = pcall( dofile, metaFile )
    if not s then
        return nil, d
    end
    return d.metadataFieldsForPhotos
end



--- Copy selected metadata values from most selected photo to the other selected photos.
function CustomMetadata:manualSync()
    app:call( Service:new{ name="Custom Metadata Manual Sync", async=true, guard=App.guardVocal, main=function( call )
    
        call.nUpdated = 0
        call.nAlreadyUpToDate = 0
    
        local pluginId = _PLUGIN.id
    
        if not _PLUGIN.enabled then
            app:show{ warning="Plugin must be enabled in plugin manager (hint: 'Enable' button in 'Status' section)." }
            call:cancel()
            return nil
        end
            
        local photos = cat:getSelectedPhotos()
        local dir = LrPathUtils.child( LrPathUtils.parent( catalog:getPath() ), _PLUGIN.id )
        if photos == nil or #photos < 2 then
            app:show{ warning="Select two or more photos first." }
            call:cancel()
            return nil
        end
        local mostSelPhoto = catalog:getTargetPhoto()
        local mo = self:getMetadata( mostSelPhoto, _PLUGIN.id )
        local errm
        if self.specs == nil then
            self.specs, errm = self:getMetadataSpecs()
        end
        local me = self.specs
        
        if me == nil then
            if errm then
                app:show{ error="Error reading metadata spec file: ^1", errm }
            else
                app:show{ warning="No metadata specified." }
            end
            call:cancel()
            return
        end
                
        local props = LrBinding.makePropertyTable( call.context )
        
        
        local viewItems = {}
        
        viewItems[#viewItems + 1] =
            vf:static_text {
                title = str:fmt( "Copy custom metadata from ^1 to the other ^2?", mostSelPhoto:getFormattedMetadata( 'fileName' ), str:plural( #photos - 1, "selected photo", true ) ),
            }
        viewItems[#viewItems + 1] = vf:spacer { height = 20 }

        local c = 0        
        for i, v in ipairs( me ) do
            c = c + 1
            props[v.id] = false
            viewItems[#viewItems + 1] = vf:checkbox {
                bind_to_object = props,
                title = v.title,
                value = bind( v.id ),
            }
        end
        if c == 0 then
            app:show{ warning="No metadata" }
            call:cancel()
            return
        end
        
        local accItems = {}
        accItems[#accItems + 1] =
            vf:row {
                vf:push_button {
                    title = 'Check All',
                    action = function()
                        for i, v in ipairs( me ) do
                            props[v.id] = true
                        end
                    end,
                },
                vf:push_button {
                    title = 'Check None',
                    action = function()
                        for i, v in ipairs( me ) do
                            props[v.id] = false
                        end
                    end,
                },
            }
                    
        
        local args = { title=app:getAppName() .. " - manual sync" }
        args.contents = vf:view( viewItems )
        args.accessoryView = vf:row( accItems )
        local answer = LrDialogs.presentModalDialog( args )
        
        if answer == 'cancel' then
            call:cancel()
            return
        end
        
        call.scope = LrProgressScope {
            title = "Syncing custom metadata",
            functionContext = call.context,
        }
        app:log( "Copying custom metadata ^1", pluginId, str:plural( #photos, "photo" ) )
        
        local s, m = cat:withRetries( 20, catalog.withPrivateWriteAccessDo, function()
            for i, photo in ipairs( photos ) do
                repeat
                    if photo == mostSelPhoto then -- doesn't hurt to update most-sel photo too, but it bothers me.
                        break
                    end
                    for k, v in props:pairs() do
                        if v then
                            local chg, errm = meta:update( photo, k, mo[k], nil, true )
                            if chg == nil then
                                app:logErr( errm or "unknown error occurred" )
                            elseif chg then
                                call.nUpdated = call.nUpdated + 1
                            else
                                call.nAlreadyUpToDate = call.nAlreadyUpToDate + 1
                            end
                        end
                    end
                until true
            end
        end )
        
        if not s then
            app:error( m )
        end
    
    end, finale=function( service, status, message )
        if status and not service:isCanceled() then
            app:show{ info="^1 updated, ^2 already up to date.", subs = { str:plural( service.nUpdated, "field", true ), service.nAlreadyUpToDate }, actionPrefKey = 'Stats for manual sync' }
        end
    end } )
end



return CustomMetadata
