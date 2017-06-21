--[[
        Filename:           Dialog.lua
        
        Synopsis:           Utilities to support building dialog boxes and such.

        Notes:              -
--]]


local Dialog, dbg = Object:newClass{ className = 'Dialog' }


-- static constants
Dialog.inputMsg = "$$$/X=^1 is requesting input..."
Dialog.isOkMsg = "$$$/X=^1 is asking if its OK..."
Dialog.confirmMsg = "$$$/X=^1 is asking..."
Dialog.infoMsg = "$$$/X=^1 has something to say..."
Dialog.warningMsg = "$$$/X=^1 is concerned..."
Dialog.errorMsg = "$$$/X=^1 has encountered a problem..."
Dialog.infoType = "info"
Dialog.warningType = "warning"
Dialog.errorType = "critical" -- @2008-02-13: appears same as warning (SDK version 2.0 or 2.2?) - try again after the next version of SDK is released. Maybe only different on Mac.



---  Constructor for extending class.
--
function Dialog:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function Dialog:new( t )
    local o = Object.new( self, t )
    o.answers = {}
    return o
end



--- Klugerian function whose impetus was to support log file contents copy-n-paste to email.
--
--  <p>Presents text in a multi-line edit-field with instructions to user to copy to clipboard...</p>
--
function Dialog:putTextOnClipboard( param )

    local button = 'undefined'
    
    local text = param.contents or 'Oops!'
    
    app:call( Call:new{ name = "text to clipboard", main = function( call )
        local props = LrBinding.makePropertyTable( call.context )
        props.copied = false
        local view = {} -- no bind-to object
        view[#view + 1] = vf:edit_field {
            value = text,
            width_in_chars = param.width_in_chars or 80,
            height_in_lines = param.height_in_lines or 27,
        }
        local s = {}
        s[#s+1] = "Instructions:"
        s[#s+1] = "1. If Log contents are not already selected (indicated by being all blue), then click anywhere in the text field, then press ^1 to select all text."
        s[#s+1] = "2. Press ^2 to copy to clipboard."
        s[#s+1] = "3. Check the confirmation box below."
        s[#s+1] = "4. Click 'OK'."
        s = table.concat( s, '\n' )
        view[#view + 1] = vf:static_text {
            title = param.subtitle or str:format( s, app:getCtrlKeySeq( "A" ), app:getCtrlKeySeq( "C" ) ),
        }
        param.accessoryView = vf:checkbox {
            title = 'I have successfully copied the contents to the clipboard, as instructed.',
            bind_to_object = props,
            value = bind( 'copied' ),            
        }
        param.title = param.title or "Copy to Clipboard"
        param.contents = vf:column( view )
        repeat
            button = LrDialogs.presentModalDialog( param )
            if props.copied then
                break -- good to go
            elseif button == 'ok' then
                self:messageWithOptions( "Please revisit the instructions, or click cancel to abort..." )
            else
                break
            end
        until false
    end } )
    
    return button == 'ok'
    -- return button == 'copied'

end



--      Obsolete: just use '< exclude >' to kill the cancel button (this does not work on some (all?) macs anyway.
--
--      Synopsis:           Returns the specified button if found in the dialog box.
--      
--      Notes:              specified by label, e.g. "OK"
--      
--      Returns:            button object or nil
--
--[[ *** save for reference...
function Dialog:_findButton (x, label, visited)
    if visited == nil then visited = {} end

    if type (x) ~= "table" or visited [x] then return nil end
    visited [x] = true
   
    if x._WinClassName == "AgViewWinPushButton" and x.title == label then
        return x
    else
        -- LrDialog s . m essage( x._WinClassName )
    end
           
    for k, v in pairs (x) do
        local result = self:_findButton (v, label, visited)
        if result then return result end
    end
   
    return nil
end
--]]
 
 

--- Presents a modal dialog without an OK button.
--
--  @param          args                same as to lr-dialog -> present-modal-dialog
--  @param          returnAllButtons    true => return first button click, else hold out for 'cancel' button.
--
--  @usage          *** Only suitable if when you don't need form elements to be commited upon dismissal.
--      
--  @return         string: dismissal button - either 'ok' or one of the other buttons passed - never returns 'cancel',
--                  even if cancel button clicked (Mac).
--
function Dialog:presentModalFrame( args, returnAllButtons )
    args.cancelVerb = '< exclude >'
    --[[local snuff = false *** save for future reference
    local okButtonHidden
    if WIN_ENV then 
        args.cancelVerb = args.actionVerb or 'OK'
    	LrTasks.startAsyncTask( function()
    	    while not shutdown and not snuff do
    	        okButtonHidden = self:_findButton( args.contents, "OK" ) -- action-verb pre-checked, so the fram dismissal button will be labeled "OK".
    	        if okButtonHidden then
    	            okButtonHidden.enabled = false
    	            okButtonHidden.visible = false
    	            return
    	        else
    	            LrTasks.yield() -- dont sleep or there may be a noticable visual hitch - yielding is a must however.
    	        end
    	    end
    	end )
    end--]]
	local button
    repeat
    	button = LrDialogs.presentModalDialog( args )
        --[[if WIN_ENV then *** save for future reference
            snuff = true
    	    if not okButtonHidden then -- ok button was hidden - this is the normal functioning case in Windows.
    	        app:logErr( "Dialog box frame unsettled." )
    	    end
	        if button == 'cancel' then
	            button = 'ok'
	        end
    	end--]]
    	if returnAllButtons then
    	    break
    	elseif button == 'ok' then
    	    break
    	elseif button == 'cancel' then -- Frame-closer 'X' acts like a 'cancel' button.
    	    break
    	else
    	    -- re-present
    	end
    until false
    return button
end



--- Prompt user to enter a string via simple dialog box.
--      
--  @param          param           table with the following elements:<ul>
--                                      <li>title - window frame title
--                                      <li>subtitle - static text banner at top of content.
--                                      <li>init - initial value optional.</ul>
--
--  @usage          self-wrapped.
--      
--  @return         string, or nil for cancelled.
--
function Dialog:getSimpleTextInput( param )

    local text, msg

    app:call( Call:new{ name="get simple text input", main=function( call )
    
        local props = LrBinding.makePropertyTable( call.context )
        
        if param.init then
            props['text'] = param.init
        end
    
        local args = {}
        args.title = param.title
        local viewItems = { bind_to_object = props }
        viewItems[#viewItems + 1] =
            vf:row {
                vf:static_text {
                    title = param.subtitle,
                },
            }
        viewItems[#viewItems + 1] =
            vf:row {
                vf:edit_field {
                    value = bind( 'text' ),
                    fill_horizontal = 1,
                },
            }
        args.contents = vf:view( viewItems )
        local button = LrDialogs.presentModalDialog( args )
        if button == 'ok' then
            text = props.text
        else
            msg = "Canceled"
        end
            
    end } )
    
    return text, msg
    
end



--- Prompt user to enter a string via simple dialog box.
--      
--  @param          param           table with the following elements:<ul>
--                                      <li>title - window frame title
--                                      <li>subtitle - static text banner at top of content.</ul>
--
--  @usage          self-wrapped.
--      
--  @return         string, or nil for cancelled.
--
function Dialog:getNumericInput( param )
    local num, msg
    app:call( Call:new{ name="get numeric input", main=function( call )
    
        local props = LrBinding.makePropertyTable( call.context )
    
        local args = {}
        args.title = param.title or "Enter a number..."
        local viewItems = { bind_to_object = props }
        viewItems[#viewItems + 1] =
            vf:row {
                vf:static_text {
                    title = param.subtitle,
                },
            }
        viewItems[#viewItems + 1] =
            vf:spacer {
                height = 10
            }
        viewItems[#viewItems + 1] =
            vf:row {
                vf:edit_field {
                    value = bind( 'text' ),
                    width_in_chars = 10,
                },
            }
        args.contents = vf:view( viewItems )
        
        repeat
            local button = LrDialogs.presentModalDialog( args )
            if button == 'ok' then
                local sts, text = pcall( tonumber, props.text )
                if sts then
                    num = text
                    break
                else
                    self:messageWithOptions( { warning="This is not a number: ^1" }, str:to ( props.text ) )
                end
            else
                num = nil
                msg = "Canceled"
                break
            end
        until false
            
    end } )
    
    return num, msg
    
end



--- Fetch a user selection from a combo-box.
--      
--  @param              param               Table with the following elements:<ul>
--                                              <li>title - goes on window frame
--                                              <li>subtitle - static text banner goes in content at top.
--                                              <li>items - for combo box.</ul> 
--  @usage              self-wrapped.
--  @usage              multiple selection is not supported.
--      
--  @return             string, or nil for cancel.
--
function Dialog:getComboBoxSelection( param )

    local text, msg
    
    app:call( Call:new{ name="get combo-box selection", async = false, main = function( call )
    
        repeat
        
            if tab:isEmpty( param.items ) then
                msg = "No items"
                break
            end
    
            local props = LrBinding.makePropertyTable( call.context )
            
            props.text = param.items[1] -- can be optimized if inadequate.
        
            local args = {}
            args.title = param.title or 'Choose Item'
            local viewItems = { bind_to_object = props }
            viewItems[#viewItems + 1] =
                vf:row {
                    vf:static_text {
                        title = param.subtitle or "Choose an item from the drop-down list",
                        height_in_lines = param.lines or 1
                    },
                }
            viewItems[#viewItems + 1] =
                vf:row {
                    vf:combo_box {
                        value = bind( 'text' ),
                        items = param.items,
                        fill_horizontal = param.fill_horizontal or 1,
                    },
                }
            args.contents = vf:view( viewItems )
            local button = LrDialogs.presentModalDialog( args )
            if button == 'ok' then
                text = props.text
            else
                msg = "Canceled"
            end
            
        until true
            
    end } )
    
    return text, msg
    
end




--- Allows user to select a folder by way of the "open file" dialog box.
--      
--  @param              param       table - same as run-open-panel, except all are optional:<ul>
--                          <li>title
--                          <li>prompt ("OK" button label alternative) - NOT supported.
--                          <li>can-create-directories
--                          <li>file-types (string or array of strings, optional): prefix with '.' for best results.
--                          <li>initial-directory</ul>
--  @param              props       Properties into which folder path will be written.
--  @param              name        Name of property to write.
--      
--  @usage              Folder is written to named property if provided, in which case return value is typically ignored.
--
--  @return             string: path of folder, else nil if user cancelled.
--
function Dialog:selectFolder( param, props, name )

    local args = {}
    args.title = param.title or "Choose Folder"
    if param.prompt then
        Debug.pause( "prompt parameter not supported by folder chooser" )
    end
    args.canChooseFiles = false
    if param.canCreateDirectories == nil then
        args.canCreateDirectories = false
    else
        args.canCreateDirectories = param.canCreateDirectories
    end
    args.canChooseDirectories = true
    args.allowsMultipleSelection = false
    args.initialDirectory = param.initialDirectory or "/" -- I hate defaulting to documents folder - so start at the top...

    repeat
    
        local folders = LrDialogs.runOpenPanel( args )
        
        if folders then
            local folder = folders[1]
            local isOk
            local fileTypes = param.fileTypes
            if fileTypes then
                isOk = false
                if type( fileTypes ) == 'string' then
                    fileTypes = { fileTypes }
                end
                local folderExt = LrStringUtils.lower( LrPathUtils.extension( folder ) )
                for i, v in ipairs( fileTypes ) do
                    local ext = LrStringUtils.lower( v )
                    if str:getFirstChar( ext ) == '.' then
                        ext = ext:sub( 2 ) -- will still work if not dot-prefixed, just won't look as nice in the prompt if incorrect folder chosen.
                    end
                    if ext == folderExt then
                        isOk = true
                    end
                end
            else
                isOk = true
            end
            if isOk then
                if props then
                    props[name] = folder
                end
                return folder
            else
                app:show{ warning="Folder must end with ^1.", table.concat( fileTypes, ", or " ) }
            end
        else
            return nil
        end
        
    until false
        
end



--  Allows user to select a file by way of the "open file" dialog box.
--      
--  @param              param       Same as run-open-panel, except all are optional:<ul>
--                          <li>title
--                          <li>prompt ("OK" button label alternative)
--                          <li>filetypes
--                          <li>initial-directory</ul>
--  @param              props       Properties into which folder path will be written.
--  @param              name        Name of property to write.
--      
--  @usage              File path is written to named property if provided, in which case return value is typically ignored.
--
--  @return             string: path of file, else nil if user cancelled.
--
function Dialog:_selectFile( param, props, name, _out )

    local dir
    if props and name and not param.initialDirectory then
        dir = LrPathUtils.parent( props[name] ) -- if this is wonky, Lightroom handles in a reasonable fashion.
    else
        dir = param.initialDirectory or "/" -- I hate defaulting to documents folder - put 'em at da top...
    end
    local args = {}
    args.title = param.title or "Choose File"
    args.prompt = param.prompt or "OK"
    args.canChooseFiles = true
    args.canCreateDirectories = false
    args.canChooseDirectories = false
    args.allowsMultipleSelection = false
    args.fileTypes = param.fileTypes or "*"
    args.initialDirectory = dir

    local files
    if _out then
        files = { LrDialogs.runSavePanel( args ) }
    else
        files = LrDialogs.runOpenPanel( args )
    end
    
    if files ~= nil and #files > 0 then
        if props then
            props[name] = files[1]
        end
        return files[1]
    else
        return nil
    end
    
end



--- Allows user to select a file by way of the "open file" dialog box.
--      
--  @param              param       Same as run-open-panel, except all are optional:<ul>
--                          <li>title
--                          <li>prompt ("OK" button label alternative)
--                          <li>filetypes
--                          <li>initial-directory</ul>
--  @param              props       Properties into which folder path will be written.
--  @param              name        Name of property to write.
--      
--  @usage              File path is written to named property if provided, in which case return value is typically ignored.
--
--  @return             string: path of file, else nil if user cancelled.
--
function Dialog:selectFile( param, props, name )
    return self:_selectFile( param, props, name, false )
end



--- Allows user to select a file by way of the "save file" dialog box.
--      
--  @param              param       Same as run-save-panel, except all are optional:<ul>
--                          <li>title
--                          <li>prompt ("OK" button label alternative)
--                          <li>filetypes
--                          <li>initial-directory</ul>
--  @param              props       Properties into which folder path will be written.
--  @param              name        Name of property to write.
--      
--  @usage              File path is written to named property if provided, in which case return value is typically ignored.
--
--  @return             string: path of file, else nil if user cancelled.
--
function Dialog:selectSaveFile( param, props, name )
    return self:_selectFile( param, props, name, true )
end



--- Present quick-tips dialog box.
--      
--  @param              strTbl - table of "paragraph" strings - will be concatenated with double EOL between.
--
--  @usage              Convenience function for presenting a help string with standard title, buttons, and link to web for more info.
--      
function Dialog:quickTips( strTbl )
    local helpStr
    if type( strTbl ) == 'table' then
        helpStr = table.concat( strTbl, "\n\n" )
    elseif type( strTbl ) == 'string' then
        helpStr = strTbl
    else
        helpStr = "Sorry - no quick tips."
    end
    local button = self:messageWithOptions( { info=helpStr, buttons={{label="More on the Web",verb='ok'},{label="That's Enough",verb='cancel'}} } )
    if button == 'ok' then
        LrHttp.openUrlInBrowser( app:getPluginUrl() ) -- get-plugin-url returns a proper url for plugin else site home.
    end

end



--- Show information, and remember answer for a while.
--
--  @usage          Keyword consolidator uses like function in rc-utils: its the only one using this technique, so this function
--                  is reserved in case kwc is ever ported to elare framework.
--  @usage          How long answer is remembered is governed by the plugin - generally memory lasts for the duration of a service.
--  @usage          Must be used in conjunction with "forget-answer" or there's not much point in it...
--  @usage          Unlike normal Lr memory, remembers "cancel" answer as well.
--
function Dialog:showInfoAndRememberAnswer( msg, memKey, memText, okButton, cancelButton, otherButton )

    local answer

    LrFunctionContext.callWithContext( memKey, function( context )
    
        local props = LrBinding.makePropertyTable( context )
        props.box = false

        local message = LOC( Dialog.confirmMsg, app:getAppName() )
        local info = msg
    
    	if not str:is( memKey ) then
    	    error( "need key to remember answer" )
    	end
    	
        answer = self.answers[memKey]
        if answer then
            return
        end
        
        local viewItems = {} -- no properties on main view.
        viewItems[#viewItems + 1] = vf:static_text{
            title = msg,
        }
        
        local args = {}
        --args.title = "Please answer by clicking button"
        args.title = message
        args.contents = vf:view( viewItems )
        args.accessoryView = vf:row { 
            vf:push_button{
                title = otherButton,
                action = function( button )
                    LrDialogs.stopModalWithResult( button, 'other' )
                end,
            },
            vf:spacer{
                alignment = 'right',
                fill_horizontal = 1,
            },
            vf:checkbox{
                title = memText or "Do same for remainder...",
                bind_to_object = props,
                value = bind( 'box' ),
            },
        }
        args.resizable = true
        args.save_frame = memKey
        args.actionVerb = okButton
        args.cancelVerb = cancelButton
        args.otherVerb = otherButton
    
        answer = LrDialogs.presentModalDialog( args )
        if props.box then
            self.answers[memKey] = answer
        end
        
    end )
    
    return answer
    
end



--- Forget previously remembered answer.
--
--  @usage Call before a loop where you always want user to answer the first time, even if not subsequently.
--
function Dialog:forgetAnswer( memKey )
    self.answers[memKey] = nil
end



--- Get answer if rememebered.
--
function Dialog:getAnswer( memKey )
    local answer = self.answers[memKey]
    return answer
end



--- Remember answer.
--
--  @usage      Used in case presentation is via custom dialog box.
--
function Dialog:rememberAnswer( memKey, answer )
    self.answers[memKey] = '' .. answer -- remember a copy, since Lr likes to garbage collect properties.
end



--- Determine if its OK with the user to do something, or not - aLways prompts.
--
--	<p>For more complex prompts, use confirm box directly.</p>
--
--  @param  msg     string message.
--
--  @return boolean true iff is ok.
--
function Dialog:isOk( msg, ... )
    assert( msg ~= nil and type( msg ) == 'string', "dia-is-ok needs msg string" )
    local answer = self:messageWithOptions( { confirm=msg, buttons={{label="OK",verb='ok'}} }, ... )
    return answer == 'ok'
end



--- Prompt user to continue or not, with option to remember decision.
--
--  @param  msg     string message.
--  @param  id      string key for dismissal option.
--
--  @usage  Same as is-ok plain, except with option to suppress next time.
--
--  @return boolean true iff is user answered ok this time or previously...
--
function Dialog:isOkOrDontAsk( msg, id )
    assert( msg ~= nil and type( msg ) == 'string', "dia-is-ok-or... needs msg string" )
    assert( str:is( id ), "isOkOrDontAsk requires actionPrefKey" ) -- check for common mistake to omit the apk.
    local answer = self:messageWithOptions{  confirm=msg, actionPrefKey=id, buttons={{label="OK",verb='ok'}} }
    return answer == 'ok'
end



--- Auto-wrap text to fit in specified width.
--
--  @param          m text to wrap.
--  @param          maxWidth maximum len in real string-len characters.
--
--  @usage          Assumes single line-feed as term char.
--
--  @return         wrapped text (string)
--  @return         number of lines required to display wrapped text.
--
function Dialog:autoWrap( m, maxWidth )
    -- auto-wrap long lines and compute height-in-lines.
    local lines = 2 -- (height-in-lines)
    local maxLen = 0
    local lineBuf = {}
    local s = m
    local prevLine = false
    for v in m:gmatch( "[^\n]*" ) do
        repeat
            local len = v:len()
            --dbg( "next line: ", v )
            if len == 0 then
                if not prevLine then
                    lineBuf[#lineBuf + 1] = ""
                    s = nil
                else
                    prevLine = false
                end
                break
            else
                prevLine = true -- ignore eol that just caps this line.
            end
            s = v
            local buf = {}
            while len > maxWidth do
                local ln = s:sub( 1, maxWidth ) -- take first maxWidth characters
                local lastSpace = str:lastIndexOf( ln, " " )
                if lastSpace > 0 then
                    --dbg( "Last space ", lastSpace )
                    buf[#buf + 1] = ln:sub( 1, lastSpace - 1 ) -- .. "%"
                    --dbg( "piece before space: ", buf[#buf] )
                    s = s:sub( lastSpace + 1 )
                    --dbg( "s remainder ", s )
                    len = len - lastSpace -- I assume this is correct???
                else
                    buf[#buf + 1] = ln:sub( 1, maxWidth ) -- .. "@"
                    --dbg( "piece since no space: ", buf[#buf] )
                    s = s:sub( maxWidth + 1 )
                    --dbg( "s remainder after no space ", s )
                    len = len - maxWidth
                end
            end
            --dbg( "remainder, taking s ", s )
            local remLen = s:len()
            if remLen > 0 then
                if buf[#buf] ~= nil then
                    local lastLineLen = string.len( buf[#buf] )
                    if (remLen + lastLineLen) <= maxWidth then
                        buf[#buf] = buf[#buf] .. " " .. s -- .. "*"
                    else
                        buf[#buf + 1] = s -- .. "^"
                    end
                else
                    buf[#buf + 1] = s -- .. "$"
                end
            end
            s = nil
            --dbg( "line broken into pieces ", #buf )
            if #buf > 0 then
                lines = lines + #buf - 1
                lineBuf[#lineBuf + 1] = table.concat( buf, "\n" )
            end
            --if len > maxLen then
            --    maxLen = len
            --end
        until true
    end
    if s then
        --dbg( "final piece ", s )
        lineBuf[#lineBuf + 1] = s
        --dbg( "final count ", #lineBuf )
    end
    lines = lines + #lineBuf - 1
    m = table.concat( lineBuf, "\n" )
    --self:rawMessageDisplay( "m", m )
    return m, lines
        
end



--- Displays a message for the user to see, and provides options for the user to choose.
--  
--  @param      message ( string or table, default="" )<br>
--              If string<br>
--              - message is info-type format string.<br>
--              If table<br>
--              - message table contains the following members:<br>
--              - info (string) info format string, or<br>
--              - warning (string) warning format string, or<br>
--              - error (string) error format string.<br>
--              - actionPrefKey (string, default=nil ) for "do not show" informational messages only (never warning or error messages).<br>
--                - This should be a user friendly string since these prefs are now individual clearable by user via combo_box.
--              - buttons ( table, default = nil ) button entries are tables with members:<br>
--                label (string, required) button display text<br>
--                verb (string, required) button return text<br>
--                forget (string, default=false) whether button must not be remembered (only applies if actionPrefKey is passed),<br>
--                In which case, at least one button must not be forgetable.<br>
--                *** One button must have verb='ok'
--                Note: A cancel button is not optional in the dialog box, but it is optional as a parameter to this function.
--                - if passed, it may be used to change the label and optionally make memorable (the default for cancel button (labeled "Cancel") is not memorable). the verb must be 'cancel' (that's what makes it a "cancel" button definition).
--                - if not passed, then it defaults to "Cancel" label, returns 'cancel', and is not memorable (will not be remembered by checking 'Don't show again').
--              Normal use does not include these, but for special occasions: 
--              - width (integer, default=nil) units are pixels, or
--              - width_in_chars (integer, default=nil) units are that of big fat characters, generally 50% to double that of true character width.
--              - height (integer, default=nil) of message text, in pixels, or
--              - height_in_lines (integer, default = nil) in lines - best to include an extra line or two to spare and to keep it above the buttons.
--              - wrap (boolean, default=false) whether text should be wrapped at width. Note: strings without spaces are still truncated to fit. *** Requires width AND height to be specified somehow.
--                
--  @param      ... ( any type, default = nil, nil, nil, ... ) variables to be formatted<br>
--
--  @usage      Like lr-dialogs.message, lr-dialogs.message-with-do-not-show, lr-dialogs.confirm, and lr-dialogs.prompt-for-action-with-do-not-show combined,<br>
--              except won't compress nor truncate the message.
--  @usage      Will automatically wrap if lines are too long, at space if possible, otherwise cuts in the middle.<br>
--              Max width chosen to accomodate most whole file paths.
--  @usage      Supports formatting and named parameter passing.
--  @usage      Examples:<br>
--              app:show( "I'm simple" ) -- informational<br>
--              app:show( "I'm ^1 simple", howSimple ) -- informational/formatted.<br>
--              app:show( { info="I'm simple" } ) -- informational using named parameter passing.<br>
--              app:show( { info="I'm ^1 simple" }, "very" ) -- informational, named, formatted.<br>
--              app:show( { confirm="I'm asking, but I'll remember your answer", actionPrefKey="QuestionablePrompt", buttons={{label="Yes",verb='ok'},{label='No',verb='cancel',memorable=true}} } ) -- confirm prompt, both yes and no answers can be remembered.
--              app:show( { warning="I'm ^1 simple" }, adjective ) -- simple warning, formatted.<br>
--              app:show( { info="I'm ^1 simple", actionPrefKey="My friendly prompt", buttons={ {label='OK',verb='ok'},{label='Not OK',verb='other',memorable=false} }, "not so" ) -- you can remember OK button only,<br>
--              app:show( { error="I'm an error", buttons={{label="I guess its OK...",verb='ok'},{label='Abort',verb='cancel'}} } ) -- error message with custom cancel button.<br>
--
function Dialog:messageWithOptions( message, ... )

    -- step 0: check main message argument
    if message == nil then
        app:logError( "Message for display in dialog box is nil - displaying as blank." )
        message = "" -- might as well give a blank box I guess.
    end
    
    local m                 -- formatted message to present.
    local apk               -- action-pref-key as passed by caller.
    local apkPrefEna        -- global action-pref-key preference name for dont-show-again enable setting.
    local apkPrefFriendly   -- name for global property to set friendly name
    local apkPrefAnswer     -- global action-pref-key preference name for answer lookup when not showing.
    local flavor            -- akin to "style" but delegates responsibility for all garnish to this method.
    local buttons           -- button table as passed by calling context.
    local okButton          -- for special handling of "main action" button.
    local cancelButton      -- for special handling of "cancel" button.
    local args={}           -- arguments to lr-dialogs-present-modal-dialog, OR self-present-modal-frame.
    
    --   S T E P   1 :   analyze passed parameters, and translate un-named or named parameters to local variables.
    --                   (includes checking for and returning stored answer)
    
    if type( message ) == 'string' then
        m = str:fmt( message, ... )
        flavor = 'info'
    else
        buttons = message.buttons
        if str:is( message.actionPrefKey ) then
            apk = str:makeLuaVariableNameCompliant( message.actionPrefKey )
            apkPrefEna = "actionPrefKey_enabled_" .. apk -- must be resettable.
            apkPrefAnswer = "actionPrefKey_answer_" .. apk -- must be resettable.
            apkPrefFriendly = "actionPrefKey_friendly_" .. apk -- must be resettable.
            app:initGlobalPref( apkPrefEna, false ) -- default to do-show if not set already by user.
            if app:getGlobalPref( apkPrefEna ) then
                local answer = app:getGlobalPref( apkPrefAnswer )
                if not str:is( answer ) then
                    app:logError( "no answer" )
                else
                    return answer
                end
            end
        end
        if message.info then
            m = message.info
            flavor = 'info'
        elseif message.warning then
            m = message.warning
            flavor = 'warning'
        elseif message.error then
            m = message.error
            flavor = 'error'
        elseif message.confirm then
            m = message.confirm
            flavor = 'confirm'
        else
            error( "Message to be shown should be passed as named parameter, either 'info', 'confirm', 'warning', or 'error'." )
        end
        if message.subs == nil then -- no named substitutions.
            if #message > 0 then -- substitution variables included unnamed in message table.
                if #{ ... } > 0 then -- ya can't have unnamed param in calling table and calling list.
                    app:callingError( "Unnamed params in both table and calling list." )
                else
                    m = str:fmt( m, unpack( message ) )
                end
            else
                m = str:fmt( m, ... ) -- assume legacy mode: substitutions after message table - optional.
            end
        elseif type( message.subs ) == 'table' then
            if #message > 0 or #{...} > 0 then
                app:callingError( "Pass subs table or unnamed, not both." )
            else
                m = str:fmt( m, unpack( message.subs ) ) -- next way: named substitution table.
            end
        else -- one sub - any type
            if #message > 0 or #{...} > 0 then
                app:callingError( "Pass subs or unnamed, not both." )
            else
                m = str:fmt( m, message.subs ) -- other next way: named substitution simple variable.
            end
        end
    end
    
    --   S T E P   2 :   Determine dimensions for static-text, and reformat message by wrapping if necessary.
    --                   (includes determination of wrap specifier)
    
    -- *** There's rarely a need for explicit wrap specification or explicit dimensions
    -- since automatic wrapping and dimensions computation is supported.

    if message.wrap then
        dbg( "Are you sure you need text wrapping?" )
    end
    
    if message.width then
        dbg( "Are you sure you need to specify text width explicitly?" )
    end
    
    if message.width_in_chars then
        dbg( "Are you sure you need to specify text width-in-chars explicitly?" )
    end
    
    if message.height then
        dbg( "Are you sure you need to specify text height explicitly?" )
    end
    
    if message.height_in_lines then
        dbg( "Are you sure you need to specify text height_in_lines explicitly?" )
    end
    
    local chars = nil
    local width = nil
    local height = nil
    local wrap = nil
    local lines = nil

    if message.width_in_chars then
        if message.width then
            error( "specify width or width_in_chars, not both" )
        end
        chars = message.width_in_chars
    elseif message.width then
        width = message.width
    end
    
    if message.height_in_lines then
        if message.height then
            error( "specify height or height_in_lines, not both" )
        end
        lines = message.height_in_lines
    elseif message.height then
        height = message.height
    else
        m, lines = self:autoWrap( m, 100 ) -- 100 seems like a good balance between controlled width and not truncating paths...
    end

    -- wrap spec is supported, but should *never* be warranted(?)
    if message.wrap then
        if (message.height or message.height_in_lines) and (message.width or message.width_in_chars) then
            wrap = message.wrap
        else
            error( '"width" and "height" must be specified somehow along with \'wrap\'' )
        end
    end
    
    --   S T E P   3 :   Initialize args for "present modal" dialog box.
    --                   (includes detection of ok & cancel buttons, and determination of whats memorable and what not)    
    
    local title -- window title
    local icon -- upper left corner
    if flavor == 'info' then
        if not apkPrefEna then -- distinction between this and the normal prompting...
            args.title = "Info"
            title = app:getAppName() .. " has something to say..."
            icon = "info.png"
        else
            args.title = "Lightroom" -- the idea being the less things to have to read the better...
            title = app:getAppName() .. " can remember your answer for next time..."
            icon = "Adobe_Lightroom_Icon_32x32.png"
        end
    elseif flavor == 'warning' then
        args.title = "Warning"
        title = app:getAppName() .. " is concerned..."
        icon = "warning.png"
        if apkPrefEna then
            app:logWarning( "Warnings can not be suppressed, key: " .. apk )
            apkPrefEna = nil
        end
    elseif flavor == 'error' then
        args.title = "Error"
        title = app:getAppName() .. " has encountered a problem..."
        icon = "error.png"
        if apkPrefEna then
            app:logWarning( "Errors can not be suppressed, key: " .. apk )
            apkPrefEna = nil
        end
    elseif flavor == 'confirm' then
        args.title = "Confirm"
        title = app:getAppName() .. " is asking..."
        icon = "Adobe_Lightroom_Icon_32x32.png"
    else
        error( str:fmt( "Program failure: invalid flavor: ^1", str:to ( flavor ) ) ) -- should've been checked/set above.
    end
    local viewItems = {}
    viewItems[#viewItems + 1] =
        vf:picture {
            value = app:getFrameworkResource( icon ),
            width = share 'wid',
        }
    viewItems[#viewItems + 1] = vf:spacer{ width = 10 }
    local fontName
    -- ref: http://www.ampsoft.net/webdesign-l/WindowsMacFonts.html
    if WIN_ENV then
        fontName = 'Lucida Sans Unicode'
    else
        -- fontName = 'Lucida Grande' -- this doesn't work - default font is chosen on Mac. ###2
        fontName = 'Lucida Sans Unicode' -- might as well try this...
    end
    local viewCol = {}
    viewCol[1] = 
        vf:static_text {
            title = title,
            font = { name=fontName, size = 14 },
            text_color = LrColor( .1, .2, .5 ), -- off blue (dark).
            height_in_lines = 2, -- "spacer".
        }
    viewCol[2] =
        vf:static_text {
            title = m,
            height = height,
            height_in_lines = lines,
            width = width,
            width_in_chars = chars,
            wrap = wrap,
        }
    if message.viewItems then
        tab:appendArray( viewCol, message.viewItems )
        viewCol[#viewCol + 1] = vf:spacer{ height = 20 }
    end    
    viewItems[#viewItems + 1] = vf:column( viewCol )
    local accItems = { bind_to_object=prefs }
    if apkPrefEna then
        accItems[#accItems + 1] = vf:spacer{ width = share 'wid' }
        accItems[#accItems + 1] = vf:spacer{ width = 10 }
        accItems[#accItems + 1] =
            vf:checkbox {
                title = "Don't show again",
                value = app:getGlobalPrefBinding( apkPrefEna ),
                height = share 'ht',
            }
    end
    accItems[#accItems + 1] = vf:spacer{ width = 1, fill_horizontal = 1 }
    local memorable = {}
    local forgetable = {}
    if buttons then
        local rowItems = {}
        local verbs = {}
        if type( buttons ) == 'table' then
            for i, button in ipairs( buttons ) do
                assert( str:is( button.verb ), "button verb must be non-blank string, this isn't: " .. str:to( button.verb ) )
                assert( str:is( button.label ), "button label must be non-blank string, this isn't: " .. str:to( button.label ) )
                if button.verb == 'ok' then
                    if okButton then
                        error( "Only one button can have verb='ok'" )
                    else
                        okButton = button
                        args.actionVerb = okButton.label -- Adobe got confused...
                    end
                elseif button.verb == 'cancel' then
                    if cancelButton then
                        error( "Only one button can have verb='cancel'" )
                    else
                        cancelButton = button
                        if cancelButton.label == 'Cancel' then
                            if cancelButton.memorable then
                                error( "Memorable cancel button must not be labeled 'Cancel'." )
                            else
                                cancelButton.forgetable = true -- assure all cancel buttons labeled 'Cancel' are not memorable (i.e. are forgetable).
                            end
                        -- else as long as label is not 'Cancel', its treated like any other button.
                        end
                        args.cancelVerb = cancelButton.label -- Adobe got verb & label terminology mixed up...
                    end
                else
                    if verbs[button.verb] then
                        -- app:logVerbose( "Redundent verb: " .. button.verb ) -- not prohibited, although represents an unusual case which is usually a bug.
                        error( str:fmt( "Verbs must be unique, '^1' is already taken by ^2.", button.verb, str:to( verbs[button.verb].label ) ) ) -- on the other hand, app can always do the same thing for both answers - make it an error.
                    end
                    verbs[button.verb] = button
                    rowItems[#rowItems + 1] =
                        vf:push_button {
                            title = button.label,
                            action = function( view )
                                LrDialogs.stopModalWithResult( view, button.verb )
                            end
                        }
                end
                if button.forgetable then
                    forgetable[button.verb] = button
                elseif (button.memorable==nil or button.memorable) then -- default is memorable, but can be explicitly asserted.
                    assert( not button.forgetable, "cant be both" )
                    if button.label == 'Cancel' then
                        error( "No buttons labeled 'Cancel' should be memorable." )
                    end
                    memorable[button.verb] = button
                end
            end
            -- ok button is not optional
            if not okButton then
                error( "One button must have verb='ok'" )
            end
            -- cancel button is optional, and is used only for altering label and memorable-ness.
            if not cancelButton then -- unlike other buttons, cancel button defaults to not-memorable.
                forgetable['cancel'] = { label='Cancel', verb='cancel' } -- pseudo-button to record default forgetableness of cancel button.
                memorable['cancel'] = nil -- this would have got set above.
            end
            local row = vf:row( rowItems )
            accItems[#accItems + 1] =
                vf:column {
                    vf:spacer{ height=1, fill_vertical = 1 },
                    row,
                    height = share 'ht',
                }
        else
            error( "Buttons must be table, this isn't: " .. str:to( buttons ) )
        end
    else
        args.cancelVerb = 'Cancel' -- will only show on Mac.
        args.actionVerb = 'OK'
        forgetable = { cancel = { label='Cancel' } } -- this won't do anything if there's no action-pref-key.
        memorable = { ok = { label = "OK" } } -- this won't do anything if there's no action-pref-key.
    end
    if buttons and apkPrefEna and tab:isEmpty( memorable ) then
        error( "Must have at least one memorable answer" )
    end
    args.accessoryView = vf:row( accItems )
    local rows={}
    rows[1] = vf:row( viewItems )
    rows[2] = vf:row{ vf:spacer{ width=share'wid' }, vf:spacer{ width=8 }, vf:separator{ fill_horizontal = 1 } }
    args.contents = vf:view( rows ) -- view and column are same with default placement being vertical.
    
    -- S T E P   4 :   Present modal dialog box until user chooses an acceptable answer.
    --                 (unacceptable answers are those that try to remember non memorable choices)
    
    local answer
    repeat
        if buttons then
            answer = LrDialogs.presentModalDialog( args )
        else
            answer = self:presentModalFrame( args ) -- should only return 'ok', but perhaps one should be prepared for 'cancel' also.
        end
        if apkPrefEna then -- don't show again?
            if app:getGlobalPref( apkPrefEna ) then
                if memorable[answer] then
                    app:setGlobalPref( apkPrefAnswer, answer )
                    app:setGlobalPref( apkPrefFriendly, message.actionPrefKey )                    
                    break
                elseif forgetable[answer] then
                    app:setGlobalPref( apkPrefEna, false )
                    app:setGlobalPref( apkPrefAnswer, "" )
                    app:setGlobalPref( apkPrefFriendly, "" )                    
                    app:show{ warning="The '^1' answer can not be remembered for next time - try again...", forgetable[answer].label } -- recursive but should be OK.
                else
                    error( str:fmt( "Program failure: answer should be memorable or forgetable, '^1' is neither.", str:to( answer ) ) )
                end
            else
                app:setGlobalPref( apkPrefEna, false )
                app:setGlobalPref( apkPrefAnswer, "" )
                app:setGlobalPref( apkPrefFriendly, "" )
                break
            end
        else
            break
        end
    until false
    
    -- step 5: return answer...
    return answer     
end             



--- Convenience function to make a button ultimately bound for lr-dialog box.
--
--  @param label (string, required) button text
--  @param verb (string, required) return value
--  @param memorable (boolean, default=true) pass false to make otherwise memorable buttons not memorable.
--
function Dialog:btn( label, verb, memorable )
    return { label=label, verb=verb, memorable=memorable }
end


return Dialog
