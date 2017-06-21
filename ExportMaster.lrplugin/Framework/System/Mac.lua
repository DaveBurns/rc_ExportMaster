--[[
        Synopsis:           Opens one file in its O.S.-registered default app.
        
        Notes:              - I assume this is non-blocking.
                            - Good choice for opening local help files, since lr-http-open-url-in-browser does not work
                              properly on Mac in that case.
        
        Returns:            X
--]]        


local Mac = OperatingSystem:newClass{ className = 'Mac' }



--- Constructor for extending class.
--
function Mac:newClass( t )
    return OperatingSystem.newClass( self, t )
end



--- Constructor for new instance.
--
function Mac:new( t )
    return OperatingSystem.new( self, t )
end



--- Return OS shell name (e.g. Explorer or Finder)
--
function Mac:getShellName()
    return "Finder"
end



--- Open file in default app.
--
--  @param      file        path
--
function Mac:openFileInDefaultApp( file )
    LrShell.openFilesInApp( { file }, "open") -- macs like to feed the file to the "open" command.
end



--- Send key string verbatim to Lightroom.
--      
--  <p>Uses applescript string passed to osascript.</p>
--
function Mac:sendUnmodifiedKeys( keyStr, keyDowns, keyUps )
    local scriptTbl = {}

    scriptTbl[#scriptTbl + 1] = "-e 'tell application \"Lightroom\" to activate'"
    scriptTbl[#scriptTbl + 1] = "-e 'tell application \"System Events\"'"

    if keyDowns then
        tab:appendArray( scriptTbl, keyDowns )
    end

    scriptTbl[#scriptTbl + 1] = "-e 'keystroke \"" .. keyStr .. "\"'"

    if keyUps then
        tab:appendArray( scriptTbl, keyUps )
    end

    scriptTbl[#scriptTbl + 1] = "-e 'end tell'"

    local scriptStr = table.concat( scriptTbl, ' ' )
    local command = 'osascript'
    local params = scriptStr

    return self:executeCommand( command, params ) -- no targets, no output.
end



-- save for posterity...
--[[function Mac:_sendUnmodifiedKeys( keyStr )
    local command = 'osascript'
    local dir = Load.getFrameworkDir()
    dir = LrPathUtils.child( dir, 'System/Support' )
    local file = LrPathUtils.child( dir, 'SendKeys.ascript' )
    assert( fso:existsAsFile( file ), "no script" ) -- redundant since execute-command will also check it.
    local params = '"' .. file .. '" ' .. keyStr  
    return self:executeCommand( command, params ) -- no targets, no output.
end--]]



--- Send mac-modified keystroke sequence to mac os / lightroom.
--      
--  <p>Format examples:</p><blockquote>
--      
--          Ctrl-S<br>
--          Cmd-FS<br>
--          ShiftCtrl-S</blockquote></p>
--
--  @param     modKeys     Mash the modifiers together (in any order), follow with a dash, then mash the keystrokes together (order matters).
--
function Mac:sendModifiedKeys( modKeys )
    local k1, k2 = modKeys:find( '-' )
    local keyMods
    local keyStr
    if k1 then
        keyStr = modKeys:sub( k2 + 1 )
        keyMods = modKeys:sub( 1, k1 - 1 )
    else
        error( "No keystroke" )
    end
    local keyDownTbl = {}
    local keyUpTbl = {}
    if keyMods:find( 'Shift' ) then
        keyDownTbl[#keyDownTbl + 1] = "-e 'key down shift'"
        keyUpTbl[#keyUpTbl + 1] = "-e 'key up shift'"
    end
    if keyMods:find( 'Option' ) then
        keyDownTbl[#keyDownTbl + 1] = "-e 'key down option'"
        keyUpTbl[#keyUpTbl + 1] = "-e 'key up option'"
    end
    if keyMods:find( 'Cmd' ) then
        keyDownTbl[#keyDownTbl + 1] = "-e 'key down command'"
        keyUpTbl[#keyUpTbl + 1] = "-e 'key up command'"
    end
    if keyMods:find( 'Ctrl' ) then
        keyDownTbl[#keyDownTbl + 1] = "-e 'key down control'"
        keyUpTbl[#keyUpTbl + 1] = "-e 'key up control'"
    end
    return self:sendUnmodifiedKeys( keyStr, keyDownTbl, keyUpTbl )
end



return Mac
