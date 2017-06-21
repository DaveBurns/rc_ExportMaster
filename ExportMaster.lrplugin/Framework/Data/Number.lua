--[[
        Number.lua
--]]

local Number, dbg = Object:newClass{ className = 'Number', register = false }



--- Constructor for extending class.
--
function Number:newClass( t )
    return Object.newClass( self, t )
end




--- Constructor for new instance.
--
function Number:new( t )
    return Object.new( self, t )
end



---     Call to check whether a value assumed to be number or not at all is not zero.
--
function Number:isNonZero( s )
    if (s ~= nil) and (s ~= 0) then
        return true
    else
        return false
    end
end



---     Try to convert a string to a number, without croaking if the string is nil, null, or isn't a number...
--
function Number:numberFromString( s )
    if s == nil or s == '' then
        return nil
    end
    local sts, num = pcall( tonumber, s )
    if sts and num then
        return num
    else
        return nil
    end
end



function Number:isInteger( num )

    return (num % 1) == 0

end



return Number