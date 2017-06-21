--[[
        Export.lua
--]]

local Export, dbg = Object:newClass{ className = 'Export' }



Export.dialog = nil
Export.exports = {}



--- Constructor for extending class.
--      
function Export:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor to create the export object that represents the export dialog box.
--      
--  <p>One of these objects is created when the export dialog box is presented,
--  if it has not already been.</p>
--
function Export:newDialog( t )
    local o = Object.new( self, t )
    return o
end



--- Create a new export object.
--      
--  <p>One of these objects is created EACH time a new export is initiated,
--  then killed at export completion - supports multiple concurrent exports,
--  without interference (assuming a different set of photos is selected,
--  otherwise all kinds of interference...)</p>
--                          
--  @param t     Parameter table<ul>
--                  <li>exportContext
--                  <li>functionContext</ul>
--                          
--  @return      Export object
--
function Export:newExport( t )

    local o = Object.new( self, t )
	o.exportParams = o.exportContext.propertyTable
    o.exportSession = o.exportContext.exportSession
    o.functionContext = o.functionContext
    o.exportProgress = nil -- initialized when service gets under way (after renditions have been checked)
    o.nPhotosToExport = 0
    o.nPhotosToRender = 0 -- initialized in service function.
    o.nPhotosRendered = 0 -- counted during service.
    o.nRendFailures = 0
    o.srvc = nil
    return o
    
end



--- Method version of like-named static function.
--      
--  @usage      Base class implementation simply calls the export service method wrapped in an app call.
--  @usage      Derived export class can certainly override this method, but consider overriding the service & finale methods instead.
--  @usage      Called immediately after process-rendered-photos static "boot-strap" function.
--
function Export:processRenderedPhotosMethod()

    dbg( "Export class: ", str:to( self ) )

    local service = Service:new{
         name = app:getAppName() .. ' export',
         object = self,
         main = self.service,
         finale = self.finale,
    }
    
    self.srvc = service
    app:call( service )

end



--- Perform export service wrap-up.
--
--  @usage    Override this method in derived class to log stats...
--  @usage    *** IMPORTANT: This method is critical to export integrity.
--            Derived export class must remember to call it at end of special
--            export finale method.
--
function Export:finale( service, status, message )
    -- assert( self == Export.exports[self.exportContext], "whoami?" )
    -- app:logInfo( str:format( "^1 finale, ^2 rendered.", name, str:plural( self.nPhotosRendered, "photo" ) ) )
    Export.exports[self.exportContext] = nil -- *** kill self reference, garbage collection runs later...
    fprops:setPropertyForPlugin( _PLUGIN, "exportState", 'finished' )
    if status then
        fprops:setPropertyForPlugin( _PLUGIN, 'exportMessage', service.name .. " completed successfully." )
    else
        fprops:setPropertyForPlugin( _PLUGIN, 'exportMessage', service.name .. " terminated due to error: " .. message )
    end    
end



function Export:initiate( service )
    fprops:setPropertyForPlugin( _PLUGIN, "exportState", 'running' )
    fprops:setPropertyForPlugin( _PLUGIN, "exportMessage", service.name .. ' in progress' )
end



--[[ this needs more thought - problems with managed exports could cause unmanaged exports not to run - not cool.
-- note: can be very time consuming if exporting thousands of photos and not much inherent delay,
-- maybe best to tie to yield counter or something in that case.
-- note: checks for user cancelation via progress scope as well as managed cancelation via export-manager.
function Export:isCanceled()
    if self.srvc.scope and self.srvc.scope:isCanceled() then
        return true
    end
    local exportCanceled = fprops:getPropertyForPlugin( 'com.robcole.lightroom.export.ExportManager', 'exportCanceled', true ) -- re-reading nearly always required when reading a propterty to be set by a different plugin.
    if exportCanceled == nil then
        if self.notManaged == nil then
            self.notManaged = true
            app:logInfo( "Export appears not to be executing in managed environment." )
        end
        return false
    end
    if exportCanceled == 'yes' then
        return true
    elseif exportCanceled == 'no' then
        return false
    else
        app:logError( "bad cancel property value: " .. str:to( exportCanceled ) )
        return false
    end
    -- save for pausterity I guess:
    --app:logInfo( "Export paused." )
    --while exportEnabled == 'no' and not shutdown do
    --    LrTasks.sleep( 1 )
    --    exportEnabled = fprops:getPropertyForPlugin( 'com.robcole.lightroom.export.ExportManager', 'exportEnabled', true ) -- re-reading nearly always required when reading a propterty to be set by a different plugin.
    --end
    --app:logInfo( "Export resuming from pause." )
    --return true -- did pause
end
--]]



--- Service function of base export - processes renditions.
--      
--  <p>You can override this method in its entirety, OR just:</p><ul>
--      
--      <li>checkBeforeRendering
--      <li>processRenderedPhoto
--      <li>processRenderingFailure
--      <li>(and finale maybe)</ul>
--
function Export:service( service )

    if app:isAdvDbgEna() then
        app:logInfo( "Export Params:")
        app:logPropertyTable( self.exportParams ) -- no-op unless advanced debugging is enabled.
        app:logInfo()
    end

    self.nPhotosToExport = self.exportSession:countRenditions()
    self:checkBeforeRendering() -- remove photos not to be rendered.

    app:logInfo( "Exporting " .. str:plural( self.nPhotosToExport, "selected photo" ) )
    app:logInfo( "Rendering " .. str:plural( self.nPhotosToRender, "exported photo" ) )
    app:logInfo( "Export Format: " .. str:to( self.exportParams.LR_format ) )
    app:logInfo()
    
    local title = app:getAppName() .. " rendering " .. str:plural( self.nPhotosToRender, "photo" )
    self.exportProgress = self.exportContext:configureProgress{ title = title }
    
    for i, rendition in self.exportContext:renditions{ stopIfCanceled = true, progressScope = self.exportProgress } do
    
        -- self:pauseOrNot() -- make sure you call this in the processing loop(s) if you override the service method.
    
        local status, other = rendition:waitForRender()
        if status then
            local photoPath = other
            self:processRenderedPhoto( rendition, photoPath )
        else
            local message = other
            self:processRenderingFailure( rendition, message )
        end
            
    end
end



--   E X P O R T   D I A L O G   B O X



--- Handle change to properties under authority of base export class.
--      
--  <p>Presently there are none - but that could change</p>
--
--  @usage        Call from derived class to ensure base property changes are handled.
--
function Export:propertyChangeHandlerMethod( props, name, value )
end



--- Do whatever when dialog box opening.
--      
--  <p>Nuthin to do so far - but that could change.</p>
--
--  @usage        Call from derived class to ensure dialog is initialized according to base class.
--
function Export:startDialogMethod( props )
end



--- Do whatever when dialog box closing.
--      
--  <p>Nuthin yet...</p>
--
--  @usage        Call from derived class to ensure dialog is ended properly according to base class.
--
function Export:endDialogMethod( props )
end



--- Standard export sections for top of dialog.
--      
--  <p>Presently seems like a good idea to replicate the plugin manager sections.</p>
--
--  @usage      These sections can be combined with derived class's in their entirety, or strategically...
--
function Export:sectionsForTopOfDialogMethod( vf, props )
    return Manager.sectionsForTopOfDialog( vf, props ) -- instantiates the proper manager object via object-factory.
end



--- Standard export sections for bottom of dialog.
--      
--  <p>Reminder: Lightroom supports named export presets.</p>
--
--  @usage      These sections can be combined with derived class's in their entirety, or strategically - presently there are none.
--
function Export:sectionsForBottomOfDialogMethod( vf, props )
end



--   E X P O R T   S U B - T A S K   M E T H O D S


--- Remove photos not to be rendered, or whatever.
--
function Export:checkBeforeRendering()
    self.nPhotosToRender = self.nPhotosToExport
end



--- Process one rendered photo.
--
function Export:processRenderedPhoto( rendition, photoPath )
    self.nPhotosRendered = self.nPhotosRendered + 1
end



--- Process one photo rendering failure.
--
--  @param      message         error message generated by Lightroom.
--
function Export:processRenderingFailure( rendition, message )
    self.nRendFailures = self.nRendFailures + 1
    app:logError( str:fmt( "Photo rendering failed, photo path: ^1, error message: ^2", rendition.photo:getRawMetadata( 'path' ) or 'nil',  message or 'nil' ) )
end



--- Export parameter change handler proper - static function
--
--  @usage      Generally no reason to override in derived class - override method instead.
--  @usage      Just calls corresponding method of actual (i.e derived class) export object.
--
function Export.propertyChangeHandler( props, name, value )
    assert( Export.dialog ~= nil, "No export dialog." )
    Export.dialog:propertyChangeHandlerMethod( props, name, value )
end



--- Called when dialog box is opening - static function as required by Lightroom.
--
--  @usage      Generally no reason to override in derived class - override method instead.
--  @usage      Just calls corresponding method of actual (i.e derived class) export object.
--
function Export.startDialog( props )
    if Export.dialog == nil then
        Export.dialog = objectFactory:newObject( 'ExportDialog' )
    end
    assert( Export.dialog ~= nil, "No export dialog." )
    Export.dialog:startDialogMethod( props )
end



--- Called when dialog box is closing.
--
--  @usage      Generally no reason to override in derived class - override method instead.
--  @usage      Just calls corresponding method of actual (i.e derived class) export object.
--
function Export.endDialog( props )
    assert( Export.dialog ~= nil, "No export dialog." )
    Export.dialog:endDialogMethod( props )
end



--- Presently, it is imagined to just replicate the manager's top section in the export.
--
--  @usage      Generally no reason to override in derived class - override method instead.
--  @usage      Just calls corresponding method of actual (i.e derived class) export dialog object.
--
function Export.sectionsForTopOfDialog( vf, props )
    if Export.dialog == nil then
        Export.dialog = objectFactory:newObject( 'ExportDialog' )
    end
    assert( Export.dialog ~= nil, "No export dialog." )
    return Export.dialog:sectionsForTopOfDialogMethod( vf, props )
end



--- Presently, there are no default sections imagined for the export bottom.
--
--  @usage      Generally no reason to override in derived class - override method instead.
--  @usage      Just calls corresponding method of actual (i.e derived class) export dialog object.
--
function Export.sectionsForBottomOfDialog( vf, props )
    if Export.dialog == nil then
        Export.dialog = objectFactory:newObject( 'ExportDialog' )
    end
    assert( Export.dialog ~= nil, "No export dialog." )
    return Export.dialog:sectionsForBottomOfDialogMethod( vf, props )
end



--- Called to process render(ing) photos.
--      
--  <p>Photos have not started rendering when this is first called.
--  Once started, they will be rendered in an asynchronous task within Lightroom.
--  Rendering may be started implicitly by invoking the renditions iterator of the export context,
--  or explicitly by calling export-context - start-rendering.</p>
--      
--  @usage      Generally no reason to override in derived class - override method instead.
--  @usage      1st: creates derived export object via object factory,
--              <br>then calls corresponding method of actual (i.e derived class) export object.
--  @usage      Rendering order is not guaranteed, however experience dictates they are in order.
--
function Export.processRenderedPhotos( functionContext, exportContext )

    if Export.exports[exportContext] ~= nil then
        app:logError( "Export not properly terminated." ) -- this should never happen provided derived class remembers to call base class finale method.
        Export.exports[exportContext] = nil -- terminate improperly...
    end
    Export.exports[exportContext] = objectFactory:newObject( 'Export', { functionContext = functionContext, exportContext = exportContext } )
    Export.exports[exportContext]:processRenderedPhotosMethod()
    
end

   

return Export