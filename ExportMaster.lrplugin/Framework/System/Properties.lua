--[[
        Properties.lua
        
        Serves a few different flavors of properties (name-value pairs).
--]]


local Properties, dbg = Object:newClass{ className = 'Properties' }
 
local sharedProperties
local propsForPlugin
local propsForPluginSpanningCatalogs



--- Constructor for extending class.
--
function Properties:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function Properties:new( t )
    return Object.new( self, t )
end



--      Synopsis:           Substitute for non-working Lightroom version, until fixed.
--      
--      Notes:              - This will be removed or replaced with the equivalent lightroom version once difficulties are resolved.
--                          - Writes a table into file plugin-id.properties.lua with the specified property.
--      
--      Returns:            Nothing. throws error if bad property file.
--
function Properties:_readPropertyFile( pth )

    local sts, props
    if LrFileUtils.exists( pth ) then
        sts, props = pcall( dofile, pth )
        if sts then
            if props and type( props ) == 'table' then
                -- good
            else
                error( "Bad property file (no return table): " .. pth )
            end

        else
            error( "Bad property file (syntax error?): " .. pth )
        end
    else
        props = {}
    end
    return props

end



--      Synopsis:           Substitute for non-working Lightroom version, until fixed.
--      
--      Notes:              - This will be removed or replaced with the equivalent lightroom version once difficulties are resolved.
--                          - Writes a table into file plugin-id.properties.lua with the specified property.
--      
--      Returns:            Nothing. throws error if can't set property.
--
function Properties:_savePropertyFile( pth, props )

    local sts, msg
    local overwrite = LrFileUtils.exists( pth )
    local c = {}
    c[#c + 1] = '_t={}'
    for k,v in pairs( props ) do
        local valStr
        if v == nil then
            valStr = 'nil'
        elseif type( v ) == 'string' then
            valStr = '"' .. v .. '"'
        else
            valStr = str:to( v )
        end
        c[#c + 1] = '_t["' .. k .. '"]=' .. valStr
    end
    c[#c + 1] = 'return _t'
    
    local contents = table.concat( c, '\n' )
    
    --sts, msg = fso:writeFile( pth, contents ) -- overwrite is default behavior.
    local ok, fileOrMsg = pcall( io.open, pth, "wb" )
    local msg = nil
    if ok then
        local orMsg
        ok, orMsg = pcall( fileOrMsg.write, fileOrMsg, contents )
        if ok then
            -- good
        else
            msg = str:format( "Cant write file, path: ^1, additional info: ^2", pth, str:to( orMsg ) )
        end
        -- ok = fso:closeFile( fileOrMsg )
        fileOrMsg:close()
        if not ok then
            msg = str:format( "Unable to close file that was open for writing, path: ^1", pth )
        end
    else
        msg = str:format( "Cant open file for writing, path: ^1, additional info: ^2", pth, str:to( fileOrMsg ) )
    end
    if msg then
        error( msg )
    end

end



--- Set property value specified by name associated with catalog.
--  
--  @param          _plugin - _PLUGIN or pluginId.
--  @param          name - property name
--  @param          value - property value
--
--  @usage          Substitute for non-working Lightroom version, until fixed.
--  @usage          This will be removed or replaced with the equivalent lightroom version once difficulties are resolved.
--  @usage          Writes a table into file plugin-id.properties.lua with the specified property.
--  @usage          name should be string, and value should be number or string or nil.
--  @usage          Returns nothing - throws error if can't set property.
--
function Properties:setPropertyForPlugin( _plugin, name, value )

    local pluginId
    if _plugin == nil then
        pluginId = _PLUGIN.id
    elseif type( _plugin ) == 'string' then
        pluginId = _plugin
    else
        pluginId = _plugin.id
    end
    assert( pluginId ~= nil, "bad plugin id" )

    local fn = pluginId .. ".Properties.lua"
    local pth = LrPathUtils.child( LrPathUtils.parent( catalog:getPath() ), fn )

    if name == nil then
        error( "set catalog property name can not be nil." )
    end

    if not propsForPlugin then
        propsForPlugin = {}
    end

    if not propsForPlugin[pluginId] then
        propsForPlugin[pluginId] = self:_readPropertyFile( pth )
    end
    if propsForPlugin[pluginId] then
        propsForPlugin[pluginId][name] = value
        dbg( str:fmt( "Property for plugin ^1 named ^2 set to '^3' in file ^4", pluginId, name, value, pth ) )
        self:_savePropertyFile( pth, propsForPlugin[pluginId] ) -- throws error if failure.
    else
        error( "Program failure - no catalog properties for plugin." )
    end

end



--- Reads named property value associated with catalog.
--      
--  @param              _plugin - _PLUGIN or pluginId.
--  @param              name - property name
--
--  @usage              Substitute for non-working Lightroom version, until fixed.
--  @usage              This will be removed or replaced with the equivalent lightroom version once difficulties are resolved.
--  @usage              Reads from loaded table or loads then reads.
--  @usage              Name must be a string.
--  @usage              Throws error if problem reading properties.
--      
--  @return             Value as set, which may be nil.
--
function Properties:getPropertyForPlugin( _plugin, name, forceRead )

    local pluginId
    if _plugin == nil then
        pluginId = _PLUGIN.id
    elseif type( _plugin ) == 'string' then
        pluginId = _plugin
    else
        pluginId = _plugin.id
    end
    assert( pluginId ~= nil, "bad plugin id" )

    local fn = pluginId .. ".Properties.lua"
    local pth = LrPathUtils.child( LrPathUtils.parent( catalog:getPath() ), fn )

    if name == nil then
        error( "get catalog property name can not be nil." )
    end

    if not propsForPlugin then
        propsForPlugin = {}
    end

    if not propsForPlugin[pluginId] or forceRead then
        propsForPlugin[pluginId] = self:_readPropertyFile( pth )
    end
    if propsForPlugin[pluginId] then
        return propsForPlugin[pluginId][name] -- may be nil.
    else
        error( "Program failure - no catalog properties to get." )
    end

end



--- Gets property tied to plugin, but not to specific catalog.
--      
--  @usage         Initial application: Importer master sequence number, so an index used for import file naming into different catalogs
--                 <br>would not create conflicts in common backup bucket, or when catalogs merged...
--      
--  @return        simple value (original type not table).
--
function Properties:getPropertyForPluginSpanningCatalogs( _plugin, name )

    local fn = _PLUGIN.id .. ".Properties.lua"
    local pth = LrPathUtils.child( LrPathUtils.parent( _PLUGIN.path ), fn )

    if name == nil then
        error( "get catalog spanning property name can not be nil." )
    end

    if not propsForPluginSpanningCatalogs then
        propsForPluginSpanningCatalogs = self:_readPropertyFile( pth )
    end
    if propsForPluginSpanningCatalogs then
        return propsForPluginSpanningCatalogs[name] -- may be nil.
    else
        error( "Program failure - no catalog spanning properties to get." )
    end

end



--- Set plugin property that is catalog independent.
--      
--  @usage          see 'get' function
--  @usage          Returns nothing - throws error if trouble.
--
function Properties:setPropertyForPluginSpanningCatalogs( _plugin, name, value )

    local fn = _PLUGIN.id .. ".Properties.lua"
    local pth = LrPathUtils.child( LrPathUtils.parent( _PLUGIN.path ), fn )
    
    if name == nil then
        error( "set catalog spanning property name can not be nil." )
    end

    if not propsForPluginSpanningCatalogs then
        propsForPluginSpanningCatalogs = self:_readPropertyFile( pth )
    end
    if propsForPluginSpanningCatalogs then
        propsForPluginSpanningCatalogs[name] = value
        self:_savePropertyFile( pth, propsForPluginSpanningCatalogs ) -- throws error if failure.
    else
        error( "Program failure - no catalog spanning properties for plugin." )
    end

end



--- Gets shared value associated with specified name.
--      
--  @usage              Shared meaning all-plugins, all-catalogs, all-users, ...
--  @usage              Initial application: user-name.
--  @usage              Properties are stored in plugin parent, so they will only be shared by child plugins.
--  @return             Throws error if name not supplied or existing properties unobtainable.
--      
--  @return             simple value (string, number, boolean - not table), else nil if non-existing.
--
function Properties:getSharedProperty( name )

    local fn = "com.robcole.lightroom.plugin.Shared.Properties.lua"
    local pth = LrPathUtils.child( LrPathUtils.parent( _PLUGIN.path ), fn )

    if name == nil then
        error( "get shared property name can not be nil." )
    end

    if not sharedProperties then
        sharedProperties = self:_readPropertyFile( pth )
    end
    if sharedProperties then
        return sharedProperties[name] -- may be nil.
    else
        error( "Program failure - no shared properties to get." )
    end

end



--- Sets property readable by sister function.
--      
--  @usage              see 'get' function.
--  @usage              Returns nothing - throws error if trouble.
--
function Properties:setSharedProperty( name, value )

    local fn = "com.robcole.lightroom.plugin.Shared.Properties.lua"
    local pth = LrPathUtils.child( LrPathUtils.parent( _PLUGIN.path ), fn )
    
    if name == nil then
        error( "set shared property name can not be nil." )
    end

    if not sharedProperties then
        sharedProperties = self:_readPropertyFile( pth )
    end
    if sharedProperties then
        sharedProperties[name] = value
        self:_savePropertyFile( pth, sharedProperties ) -- throws error if failure.
    else
        error( "Program failure - no shared properties to set." )
    end

end



return Properties