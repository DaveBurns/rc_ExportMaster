--[[================================================================================

        Boolean.lua

================================================================================--]]


local Boolean, dbg = Object:newClass{ className = 'Boolean', register = false }



--- Constructor for extending class.
--
function Boolean:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function Boolean:new( t )
    return Object.new( self, t )
end



--- Determine if the specified boolean is true.
--      
--  @usage      Returns the value as is if not nil, else the boolean 'false'.
--              Avoids problem of illegal comparison with nil.
--                      
function Boolean:isTrue( v )
    return v or false
end



--- Determine if value is non-nil, boolean, and true.
--
--  @usage      Convenience function for times when a value could be boolean true or something else...
--  @usage      this function will never throw an error.
--
--  @return     true iff "all of the above".
--
function Boolean:isBooleanTrue( v )
    return (v ~= nil) and type( v ) == 'boolean' and v == true
end



--- Determine if the specified boolean is false.
--
--  @usage  Same as 'not v' except it will throw an error if the value is not a boolean.
--
function Boolean:isFalse( v )
    return (v == nil) or (v == false)
end



function Boolean:booleanFromString( s )
    if s == 'true' then
        return true
    elseif s == 'false' then
        return false
    else
        return nil
    end
end


return Boolean