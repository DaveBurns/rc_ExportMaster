--[[
        InitFramework.lua
--]]



local Init, dbg = Object:newClass{ className = 'Init', register = false }


function Init:newClass( t )
    return Object.newClass( self, t )
end

function Init:new( t )
    return Object.new( self, t )
end



--- Initialize framework.
--
--  @usage this function born from the desire to reduce complexity of and changes to Init.lua when
--         the framework changes.
--
--  @usage init-var method of global object required since global policy is strict and functions called from Init.lua (which is 'main') are not considered to be executed as 'main'.
--
function Init:framework()

    local reloading = gbl:getValue( 'reloading' ) -- if reloading, its OK for a global variable value to be there already, otherwise its an error,
    -- since it means its being stomped on...

    gbl:initVar( 'shutdown', false, reloading ) -- the default shutdown function simply sets this flag. Plugin tasks can simply poll for it.
    -- gbl:initVar( 'enabled', true, reloading ) - obsolete: now using metadata polling to determine enable/disable status.
    gbl:initVar( 'service', 'done', reloading ) -- call or service sets this to 'started', then 'done' - used to synchronize call/services with debug-script.
    
    
    --   G L O B A L   L I G H T R O O M   M O D U L E S   -   B A S E L I N E
    gbl:initVar( 'LrPathUtils', import 'LrPathUtils', reloading )
    gbl:initVar( 'LrFileUtils', import 'LrFileUtils', reloading ) 
    gbl:initVar( 'LrErrors', import 'LrErrors', reloading ) 
    gbl:initVar( 'LrApplication', import 'LrApplication', reloading )
    gbl:initVar( 'LrTasks', import 'LrTasks', reloading )
    gbl:initVar( 'LrShell', import 'LrShell', reloading )
    gbl:initVar( 'LrStringUtils', import 'LrStringUtils', reloading )
    gbl:initVar( 'LrDate', import 'LrDate', reloading )
    gbl:initVar( 'LrProgressScope', import 'LrProgressScope', reloading )
    gbl:initVar( 'LrFunctionContext', import 'LrFunctionContext', reloading )
    gbl:initVar( 'LrPrefs', import 'LrPrefs', reloading )
    gbl:initVar( 'LrView', import 'LrView', reloading )
    gbl:initVar( 'LrBinding', import 'LrBinding', reloading )
    gbl:initVar( 'LrDialogs', import 'LrDialogs', reloading )
    gbl:initVar( 'LrLogger', import 'LrLogger', reloading )
    gbl:initVar( 'LrSystemInfo', import 'LrSystemInfo', reloading )
    gbl:initVar( 'LrHttp', import 'LrHttp', reloading )
    gbl:initVar( 'LrColor', import 'LrColor', reloading )
    gbl:initVar( 'LrXml', import 'LrXml', reloading )
    gbl:initVar( 'LrMD5', import 'LrMD5', reloading )
    gbl:initVar( 'LrMath', import 'LrMath', reloading )
    --[[ missing by default are:
         - LrFtp (hint: set ftp option in spec).
    --]]


    --   G L O B A L   L I G H T R O O M   O B J E C T S   -   B A S E L I N E
    
    -- migrate legacy preferences:
    local function prefsEmpty( p )
        for _,__ in p:pairs() do
            return false
        end
        return true
    end
    local legacyPrefs = LrPrefs.prefsForPlugin( _PLUGIN )
    local newPrefs = LrPrefs.prefsForPlugin( _PLUGIN.id ) -- this presently does the exact same thing as passing nil and letting it default (I *think*).
    -- the reason I pass the id explicitly is to make it clear the difference between prefs used in framework/plugin, and those used in debug module, which are separate.
    -- the other reason to pass explicitly, is in case I want to change toolkit ID in the future. This will allow me to migrate from one ID to the next as well,'
    -- or even continue to use the prefs of the previous ID, despite a new one... (note: custom metadata would need to be migrated too, in like fashion).
    local legacyEmpty = prefsEmpty( legacyPrefs )
    if not legacyEmpty then
        local newEmpty = prefsEmpty( newPrefs )
        if newEmpty then
            -- LrDialogs.message( "Migrating legacy preferences for plugin.",  LOC( "$$$/X=Plugin ID: ^1\n \nThis should only happen once for this plugin.", _PLUGIN.id ) )
            for k, v in legacyPrefs:pairs() do
                newPrefs[k] = v
                legacyPrefs[k] = nil
            end
        else
            -- wipe legacy prefs so the following message does not keep coming up.
            for k, v in legacyPrefs:pairs() do
                legacyPrefs[k] = nil -- legacy should be empty next time.
            end
            -- Note: this message will not normally appear for normal users - mostly me during development...
            LrDialogs.message( "There has been a strange problem with plugin preferences.", "You may have to redo your settings in plugin manager - sorry for any inconvenience this causes." )
        end
    end
    -- init new-prefs global var:    
    gbl:initVar( 'prefs', newPrefs, reloading ) -- *** Should only be used for assigining bind-to-object when binding to global preferences.
        -- preference access should otherwise be through app object's init-(global)-pref & get-(global)-pref methods (and occasionally set-(global)-pref).
        -- Reminder: local properties find their way into persistent storage (plugin preferences) by way of change handler that calls app-set-pref.
    
        -- this function prefers the _PLUGIN object, not nil (default) and not Id like doc says.
    gbl:initVar( 'catalog', LrApplication.activeCatalog(), reloading )
    gbl:initVar( 'vf', LrView.osFactory(), reloading )
    gbl:initVar( 'bind', LrView.bind, reloading )
    gbl:initVar( 'share', LrView.share, reloading )
    
    --   G L O B A L   C L A S S E S
    gbl:initVar( 'String', objectFactory:frameworkModule( 'Data/String' ), reloading ) -- required.
    gbl:initVar( 'Boolean', objectFactory:frameworkModule( 'Data/Boolean' ), reloading ) -- not sure, but its tiny.
    gbl:initVar( 'Number', objectFactory:frameworkModule( 'Data/Number' ), reloading ) -- ditto
    gbl:initVar( 'DateTime', objectFactory:frameworkModule( 'Data/DateTime' ), reloading ) -- probably optional, but also: small.
    gbl:initVar( 'Table', objectFactory:frameworkModule( 'Data/Table' ), reloading ) -- required.
    gbl:initVar( 'Disk', objectFactory:frameworkModule( 'FileSystem/Disk' ), reloading ) -- required.
    gbl:initVar( 'Dialog', objectFactory:frameworkModule( 'Gui/Dialog' ), reloading ) -- required.
    gbl:initVar( 'OperatingSystem', objectFactory:frameworkModule( 'System/OperatingSystem' ), reloading ) -- Required.
    if WIN_ENV then
        gbl:initVar( 'Windows', objectFactory:frameworkModule( 'System/Windows' ), reloading )
        gbl:initVar( 'Mac', nil, reloading )
    else
        gbl:initVar( 'Mac', objectFactory:frameworkModule( 'System/Mac' ), reloading )
        gbl:initVar( 'Windows', nil, reloading )
    end
    gbl:initVar( 'Properties', objectFactory:frameworkModule( 'System/Properties' ), reloading ) -- required.
    gbl:initVar( 'Preferences', nil, reloading ) -- optional, but highly recommended if you will support preferences in plugin manager.
    gbl:initVar( 'LogFile', objectFactory:frameworkModule( 'System/LogFile' ), reloading ) -- required.
    -- gbl:initVar( 'Debug', objectFactory:frameworkModule( 'System/Debug' ), reloading ) -- required: Loaded automatically by Require.lua.
    gbl:initVar( 'Call', objectFactory:frameworkModule( 'System/Call' ), reloading ) -- required.
    gbl:initVar( 'Service', objectFactory:frameworkModule( 'System/Service' ), reloading ) -- optional - needed for exports or substantial menu initiated services...
    gbl:initVar( 'User', objectFactory:frameworkModule( 'System/User' ), reloading ) -- required.
    gbl:initVar( 'App', objectFactory:frameworkModule( 'System/App' ), reloading ) -- required.
    gbl:initVar( 'Manager', objectFactory:frameworkModule( 'Gui/Manager' ), reloading ) -- required.
    gbl:initVar( 'Catalog', objectFactory:frameworkModule( 'Catalog/Catalog' ), reloading )
    gbl:initVar( 'Previews', objectFactory:frameworkModule( 'Catalog/Previews' ), reloading )
    gbl:initVar( 'Image', objectFactory:frameworkModule( 'Image/Image' ), reloading )
    gbl:initVar( 'Gui', objectFactory:frameworkModule( 'Gui/Gui' ), reloading )
    gbl:initVar( 'View', objectFactory:frameworkModule( 'Gui/View' ), reloading )
    gbl:initVar( 'DebugScript', objectFactory:frameworkModule( 'System/DebugScript' ), reloading )
    gbl:initVar( 'DelayedProgressScope', objectFactory:frameworkModule( 'Gui/DelayedProgressScope' ), reloading )


    
    
    
    --   O P T I O N A L   D E P E N D E N C I E S
    -- ###2 Note: Presently, the plugin generator does not rewrite this module.
    -- To exclude the following class functionalities, simple return nil for the following modules
    -- in the framework module loader method of the object factory. No attempt will be made to create the corresponding
    -- instance objects if their classes are absent.
    -- *** GEN_BEGIN globals ###
    gbl:initVar( 'XmlRpc', objectFactory:frameworkModule( 'Communication/XmlRpc' ), reloading ) -- user can specify option independently of xml-rpc update option.
    gbl:initVar( 'Xml', objectFactory:frameworkModule( 'Data/Xml' ), reloading ) -- user can specify option independently of xml-rpc update option.
    gbl:initVar( 'Export', objectFactory:frameworkModule( 'ExportAndPublish/Export' ), reloading )
    gbl:initVar( 'Preferences', objectFactory:frameworkModule( 'System/Preferences' ), reloading ) -- have extended object factory return nil if no pref mgr desired.
    gbl:initVar( 'Background', objectFactory:frameworkModule( 'System/Background' ), reloading )
    gbl:initVar( 'Reload', objectFactory:frameworkModule( 'System/Reload' ), reloading )
    gbl:initVar( 'CustomMetadata', objectFactory:frameworkModule( 'Catalog/CustomMetadata' ), reloading )
    gbl:initVar( 'Updater', objectFactory:frameworkModule( 'System/Updater' ), reloading )
    -- *** GEN_END
    


    
    
    --   G L O B A L   O B J E C T S
    -- gbl:initVar( 'props', objectFactory:newObject( Properties ), reloading ) -- bad name for this object, since it conflicts with property-table names.
    gbl:initVar( 'fprops', objectFactory:newObject( Properties ), reloading ) -- file based properties to di
    gbl:initVar( 'fso', objectFactory:newObject( Disk ), reloading )
    gbl:initVar( 'str', objectFactory:newObject( String ), reloading )
    gbl:initVar( 'app', objectFactory:newObject( App ), reloading ) -- depends on str
    gbl:initVar( 'dialog', objectFactory:newObject( Dialog ), reloading )
    gbl:initVar( 'dia', _G.dialog, reloading ) -- shortened synonym.
    gbl:initVar( 'view', objectFactory:newObject( View ), reloading )
    gbl:initVar( 'cat', objectFactory:newObject( Catalog ), reloading )
    gbl:initVar( 'previews', objectFactory:newObject( Previews ), reloading )
    gbl:initVar( 'bool', objectFactory:newObject( Boolean ), reloading )
    gbl:initVar( 'date', objectFactory:newObject( DateTime ), reloading )
    gbl:initVar( 'num', objectFactory:newObject( Number ), reloading )
    gbl:initVar( 'tab', objectFactory:newObject( Table ), reloading )
    gbl:initVar( 'gui', objectFactory:newObject( Gui ), reloading )
    gbl:initVar( 'guards', {}, reloading ) -- ###2 Dont know if it helps having guards be global or not, but I've become superstitious...
    if gbl:getValue( 'CustomMetadata' ) then
        gbl:initVar( 'meta', objectFactory:newObject( CustomMetadata ), reloading )
    end
    if gbl:getValue( 'Xml' ) then
        gbl:initVar( 'xml', objectFactory:newObject( Xml ), reloading )
    end
    if gbl:getValue( 'Updater' ) then
        gbl:initVar( 'upd', objectFactory:newObject( Updater ), reloading )
    end
    local url = app:getInfo( 'xmlRpcUrl' )
    if url then
        if not gbl:getValue( "XmlRpc" ) then
            gbl:initVar( 'XmlRpc', objectFactory:frameworkModule( 'Communication/XmlRpc' ), reloading )
            gbl:initVar( 'xmlRpc', objectFactory:newObject( XmlRpc, { url=url } ), reloading )
        else
            gbl:initVar( 'xmlRpc', objectFactory:newObject( XmlRpc, { url=url } ), reloading )
        end
    end
    if gbl:getValue( "Reload" ) then
        gbl:initVar( 'reload', objectFactory:newObject( Reload ), reloading )
    end

    --   S Y N C H R O N O U S   I N I T I A L I Z A T I O N   A N D   S T A R T U P   . . .
    app:checkSupport() -- silent if author's specified platform + lr support matches host & lr version. ###2 really this should be done in very beginning with no dependencies!
    app:init() -- complete synchronous initialization, once platform support confirmed.
    app:initGlobalPref( 'autoUpdateCheck', false, reloading )
    app:initGlobalPref( 'advDbgEna', false, reloading )
    app:initGlobalPref( 'classDebugEnable', false, reloading )
    app:initGlobalPref( 'classDebugSynopsis', "", reloading )
    app:initGlobalPref( 'logVerbose', false, reloading )
    app:initGlobalPref( 'backgroundState', 'idle' )
    if app:getGlobalPref( 'advDbgEna' ) then
        Debug.init( true )
    else
        Debug.init( false )
    end
    if app:getGlobalPref( 'autoUpdateCheck' ) then
        app:checkForUpdate( true ) -- true means silent if up-to-date.
    end

    app:logInfo()
    if reloading then
        app:logInfo( "Elare plugin framework reloaded.\n" )
    else
        app:logInfo( "Elare plugin framework initialized.\n" )
    end
    gbl:initVar( 'reloading', false, reloading )
    
end


return Init