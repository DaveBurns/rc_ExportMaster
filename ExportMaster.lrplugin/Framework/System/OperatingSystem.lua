--[[
        OperatingSystem.lua
        
        Abstract class encapsulating generic operating system functionality.
        
        Pure Abstract Methods (meaning derived class must implement these):
        
            - openFileInDefaultApp
            - sendKeys
--]]

local OperatingSystem = Object:newClass{ className = 'OperatingSystem' }



--- Constructor for extending class.
--
function OperatingSystem:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function OperatingSystem:new( t )

    local object = Object.new( self, t )
    return object
    
end



--- Return OS shell name (e.g. Explorer or Finder)
--
function OperatingSystem:getShellName()
    return "Unknown Operating System"
end



--- Opens one file in its O.S.-registered default app.
--      
--  @usage      Non-blocking - nothing returned.
--  @usage      Good choice for opening local help files, since lr-http-open-url-in-browser does not work properly on Mac in that case.
--  @usage      Not called directly - see operating system parent class for more info
--      
function OperatingSystem:openFileInDefaultApp( file )
    error( "Must be implemented in extended class." )
end



--- Send unmodified keys (pure abstract method).
--
function OperatingSystem:sendUnmodifiedKeys( text )
    error( "Must be implemented in extended class." )
end



--- Executes the specified command via the OS command shell.
--
--  @param              command         Complete command string.
--
--  @usage              Not usually called directly, but available for cutting out the middle man for testing...
--  @usage              Command is a string generally consisting of a target app, parameters, and object files.
--  @usage              Must be called from asynchronous task.
--
--  @return             boolean: true iff command successfully executed, as indicated by exit-code = 0.
--  @return             command string executed if successful, else error message.
--
function OperatingSystem:execute( command )
    local sts, other = LrTasks.pcall( LrTasks.execute, command )
    if sts then
        if other ~= nil and other == 0 then
            return true, command
        else
            return false, "Non-zero exit code returned by command: " .. command .. ", exit-code: " .. str:to( other )
        end
    else
        return false, "Error executing command: " .. command .. ", error message: " .. other
    end
end



--- Executes the specified command via the windows or mac command shell.
--
--  @param      exeFile name or path of executable.
--  @param      _params command parameter string, e.g. '-p -o "/Programs for lunch"' (without the apostrophes).
--  @param      _targets array of command targets, usually one or more paths.
--  @param      outPipe: filename or path - used for capturing output. if nil, but outHandling is 1 or 2, then a temp file will be used (same dir as plugin).
--  @param      outHandling: nil or '' => do nothing with output, 'get' => retrieve output as string, 'del' => retrieve output as string and delete output file.
--
--  @usage      Normally called indirectly by way of app object - see it for more info.
--
--  @return     status (boolean):       true iff successful.
--  @return     command-or-error-message(string):     command if success, error otherwise.
--  @return     content (string):       content of output file, if out-handling > 0.
--
function OperatingSystem:executeCommand( exeFile, _params, _targets, outPipe, outHandling )
    if exeFile == nil then
        return false, "executable file spec is nil"
    end
    local params
    if _params == nil then
        params = ''
    else
        params = ' ' .. _params
    end
    local targets
    if tab:isEmpty( _targets )  then
        targets = {}
    else
        targets = _targets
    end
    local cmd
    if WIN_ENV then
        cmd = '"' -- windows seems to be happiest with an extras set of quotes around the whole thing(?), or at least does not mind them. Mac does not like them.
    else
        cmd = ''
    end
    cmd = cmd .. '"' .. exeFile .. '"'.. params
    for i,v in ipairs( targets ) do
        cmd = cmd .. ' "' .. v .. '"'
    end
    if str:is( outHandling ) then
        if not outPipe then
            outPipe = LrFileUtils.chooseUniqueFileName( LrPathUtils.child( _PLUGIN.path, '__tempOutPipe.txt' ) )
        end
    end
    if outPipe then
        cmd = cmd .. ' > "' .. outPipe .. '"'
    end 
    if WIN_ENV then
        cmd = cmd .. '"'
    end
    
    if LrPathUtils.isRelative( exeFile ) or LrFileUtils.exists( exeFile ) then -- reminder: do not use rc-file-utils here.
    
        --   E X E C U T E   C O M M A N D
        local s, m = self:execute( cmd )
        if not s or not str:is( outHandling ) then
            return s, m
        end
        
        -- fall-through => executed and need to handle output.
        if fso:existsAsFile( outPipe ) then
            local content, orNot = fso:readFile( outPipe )
            local sts, msg
            if str:is( content ) then
                sts, msg = true, m
            else
                sts, msg = false, "Unable to read content of output file, error message: " .. (orNot or 'nil') .. ", command: " .. cmd -- errm includes path.
            end
            if outHandling == 'del' then
                -- local s, m = fso:deleteFolderOrFile( outPipe )
                local s, m = true, nil
                fso:deleteFileConfirm( outPipe ) -- ignores lr-delete return code and just checks checks for deleted file a few times.
                if s then
                    return sts, msg, content
                else
                    return false, "Unable to delete output file: " .. m .. ", command: " .. cmd -- error message includes path.
                end
            elseif outHandling == 'get' then
                app:logVerbose( "Content gotten from ^1", outPipe ) 
                return sts, msg, content
            else
                return false, "invalid output handling specified: " .. str:to( outHandling )
            end
            
        else
            return false, "There was no output from command: " .. cmd .. ", was hoping for file to exist: " .. outPipe
        end
        
    else
        return false, "Command file is missing: " .. exeFile
    end
    
    
end



return OperatingSystem