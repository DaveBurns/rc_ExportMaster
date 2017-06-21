--[[
        View.lua
--]]

local View, dbg = Object:newClass{ className = 'View' }



--- Constructor for extending class.
--
function View:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function View:new( t )
    local o = Object.new( self, t )
    return o
end



--- Get a view representing an editable text field and a combo box for selection.
--
--  <p>This method would not be needed if the combo box edit field implemented by Lightroom proper worked reliably.</p>
--
--  @return 2-item view (row)
--
function View:comboBoxWithEditField( params, items, props, name )

    local value = props[name]
    local c = { bind_to_object = props }
    c[#c + 1] = vf:edit_field {
        value = bind( name ),
        width_in_chars = 10,
        width = share( "cb_width" ),
    }
    c[#c + 1] = vf:combo_box {
        value = bind( name ),
        items = items,
        width = share( "cb_width" ),
    }
    local view = vf:row( c )
    return view
end
    


--- Get a view representing a path, with a browse button.
--
--  <p>Not yet implemented.</p>
--
--  @return 2-item view (row).
--
function View:pathWithBrowseButton( params, items, props, name )
end



--- Get a view implementing mult-selection combo box.
--
--  <p>Not yet implemented.</p>
--
function View:mutliSelectComboBox( param, props, name )
--[[
    local value = props[name]
    local arr = str:split( value, ',' )
    local editField = vf:edit_field {
        value = bind( name ),
    }
    local comboBox = vf:combo_box {
        value = bind{ key='dontcare', transform = function( value, fromModel )
            if fromModel then
                props[name
    }
--]]
end



return View
