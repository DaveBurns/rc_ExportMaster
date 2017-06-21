--[[
        Gui.lua
--]]

local Gui, dbg = Object:newClass{ className = 'Gui' }



--- Constructor for extending class.
--
function Gui:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function Gui:new( t )
    local o = Object.new( self, t )
    return o
end



--- Switch to specified module.
--
--  @param moduleNumber -- 1=library, 2=develop, ...
--
--  @usage No guarantees - involve user with a prompt if absolute assurance required.
--
function Gui:switchModule( moduleNumber )
    if moduleNumber == nil then
        error( 'Module number must not be nil' )
    end
    moduleNumber = tonumber( moduleNumber ) -- make it a number, if not already a number.
    if moduleNumber >= 1 and moduleNumber <= 5 then
        if WIN_ENV then
            return app:sendWinAhkKeys( "{Ctrl Down}{Alt Down}" .. moduleNumber .. "{Ctrl Up}{Alt Up}" )
        else
            return app:sendMacEncKeys( "CmdOption-" .. moduleNumber )
        end
    else
        return false, "Invalid module number: " .. str:to( moduleNumber )
    end
end
    


return Gui
