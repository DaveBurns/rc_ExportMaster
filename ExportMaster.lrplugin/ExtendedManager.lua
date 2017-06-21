--[[
        ExtendedManager.lua
--]]


local ExtendedManager, dbg = Manager:newClass{ className='ExtendedManager' }



--[[
        Constructor for extending class.
--]]
function ExtendedManager:newClass( t )
    return Manager.newClass( self, t )
end



--[[
        Constructor for new instance object.
--]]
function ExtendedManager:new( t )
    return Manager.new( self, t )
end



--- Static function to initialize plugin preferences (not framework preferences) - both global and non-global.
--
function ExtendedManager.initPrefs()
    -- Init global prefs:
    -- Init local prefs:
    app:initPref( 'saveMetadata', false )
    app:setPref( 'background', false ) -- true to support on-going background processing, after async init (auto-update most-sel photo).
    -- Init base prefs:
    Manager.initPrefs()
end



--- Start of plugin manager dialog.
-- 
function ExtendedManager:startDialogMethod( props )
    Manager.startDialogMethod( self, props ) -- adds observer to all props.
end



--- Preference change handler.
--
--  @usage      Handles preference changes.
--              <br>Preferences not handled are forwarded to base class handler.
--  @usage      Handles changes that occur for any reason, one of which is user entered value when property bound to preference,
--              <br>another is preference set programmatically - recursion guarding is essential.
--
function ExtendedManager:prefChangeHandlerMethod( _props, _prefs, key, value )
    Manager.prefChangeHandlerMethod( self, _props, _prefs, key, value )
end



--- Property change handler.
--
--  @usage      Properties handled by this method, are either temporary, or
--              should be tied to named setting preferences.
--
function ExtendedManager:propChangeHandlerMethod( props, name, value, call )
    if app.prefMgr and (app:getPref( name ) == value) then -- eliminate redundent calls.
        -- Note: in managed cased, raw-pref-key is always different than name.
        -- Note: if preferences are not managed, then depending on binding,
        -- app-get-pref may equal value immediately even before calling this method, in which case
        -- we must fall through to process changes.
        return
    end
    -- *** Instructions: strip this if not using background processing:
    if name == 'blah' then
    else
        -- Note: preference key is different than name.
        Manager.propChangeHandlerMethod( self, props, name, value, call )
    end
end



--- Sections for bottom of plugin manager dialog.
-- 
function ExtendedManager:sectionsForBottomOfDialogMethod( vf, props)

    local appSection = {}
    if app.prefMgr then
        appSection.bind_to_object = props
    else
        appSection.bind_to_object = prefs
    end
    
	appSection.title = app:getAppName() .. " Settings"
	appSection.synopsis = bind{ key='presetName', object=prefs }

	appSection.spacing = vf:label_spacing()
	
	appSection[#appSection + 1] =
        vf:row {
            vf:checkbox {
                title = "Automatically save metadata after exporting, to avoid metadata conflict flags...",
                --width = share 'label_width',
                value = bind 'saveMetadata',
                tooltip = "If checked, will emit keystroke to save metadata of exported photos - click 'Edit Advanced Settings' to tweak, if necessary."
            },
        }

    if not app:isRelease() then
    	appSection[#appSection + 1] = vf:spacer{ height = 20 }
    	appSection[#appSection + 1] = vf:static_text{ title = 'For plugin author only below this line:' }
    	appSection[#appSection + 1] = vf:separator{ fill_horizontal = 1 }
    	appSection[#appSection + 1] = 
    		vf:row {
    			vf:edit_field {
    				value = bind( "testData" ),
    			},
    			vf:static_text {
    				title = str:format( "Test data" ),
    			},
    		}
    	appSection[#appSection + 1] = 
    		vf:row {
    			vf:push_button {
    				title = "Test",
    				action = function( button )
    				    app:call( Call:new{ name='Test', main = function( call )
                            app:show( { info="^1: ^2" }, str:to( app:getGlobalPref( 'presetName' ) or 'Default' ), app:getPref( 'testData' ) )
                        end } )
    				end
    			},
    			vf:static_text {
    				title = str:format( "Perform tests." ),
    			},
    		}
    end
		
    local sections = Manager.sectionsForBottomOfDialogMethod ( self, vf, props ) -- fetch base manager sections.
    if #appSection > 0 then
        tab:appendArray( sections, { appSection } ) -- put app-specific prefs after.
    end
    return sections
end



return ExtendedManager
-- the end.