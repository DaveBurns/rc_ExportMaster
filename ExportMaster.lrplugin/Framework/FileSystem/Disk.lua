--[[
        Disk.lua
        
        Class with methods for dealing with disk files and folders.
--]]

local Disk, dbg = Object:newClass{ className = 'Disk' }



-- Public Constants:
Disk.throwErrorIfWrongType = true -- convenience constant - for calling context readability.
    -- deprecated: use dedicated exists-as-type function instead.
Disk.overwrite = true -- convenience constant - for calling context readability.
Disk.createDirs = true -- convenience constant - for calling context readability.
Disk.avoidUnnecessaryUpdate = true -- convenience constant - for calling context readability.



--   C O N S T R U C T O R S


--- Constructor for extending class.
--
function Disk:newClass( t )
    return Object.newClass( self, t )
end
 


--- Constructor for new instance.
--
function Disk:new( t )
    return Object.new( self, t )
end



--   B I N A R Y   F I L E   I O


--- Reads one byte from a file.
--
--  @return Numerical value of the byte, else nil for eof.
--
function Disk:getByte( file )
    local char = file:read( 1 )
    if char ~= nil then
        return string.byte( char )
    else
        return nil
    end
end



--- Reads one double-byte word from a file.
--
--  @usage         Machines have native endian, but that's overridden by file type, e.g. jpeg is big-endian on all platforms.
--                 
--  @return        Numerical value of the byte, else nil for eof.
--
function Disk:getWord( file, bigEndian )
    local b1 = self:getByte( file )
    if b1 == nil then return nil end
    local b2 = self:getByte( file )
    if b2 == nil then return nil end
    if not bigEndian then
        return b2 * 256 + b1
    else
        return b1 * 256 + b2
    end
end



--- Reads one quadruple byte word from a file.
--
--  @return         it
--
function Disk:getDouble( file, bigEndian )
    local word2 = self:getWord( file, bigEndian )
    if word2 == nil then return nil end
    local word3 = self:getWord( file, bigEndian )
    if word3 == nil then return nil end
    if not bigEndian then
        return word3 * 65536 + word2 -- assuming ls-word first. ###3 test this (same for get-word).
    else
        return word2 * 65536 + word3
    end
end



--  Gets specified number of bytes from a file.
--        
--  @usage      throws an error if specified number of bytes are not available.
--
--  @return     String of bytes, else nil for eof.
--
function Disk:getBytes( file, howMany )
    local chars = file:read( howMany )
    if chars ~= nil then
        local charLength = string.len( chars )
        if charLength == howMany then
            -- good
        else
            error( "file read underflow" )
        end
        return chars
    else
        return nil
    end
end



--   F I L E   O P E R A T I O N S . . .


--- Move or rename a file.
--      
--  <p>One motivation: to handle case of silent failure of Lr version.</p>
--                      
--  @usage              Lr doc says its just for files, but experience dictates it works on folders as well.
--  @usage              *** SOURCE EXISTENCE NOT PRE-CHECKED, NOR IS TARGET PRE-EXISTENCE - SO CHECK BEFORE CALLING IF DESIRED.
--
--  @return             boolean: true iff successfully moved.
--  @return             error message if unable to move.
--                      
function Disk:moveFolderOrFile( oldPath, newPath )
    local pcallStatus, more = LrTasks.pcall( LrFileUtils.move, oldPath, newPath )
    if pcallStatus then
        local exists = LrFileUtils.exists( newPath )
        if exists then
            return true
        else
            return false, str:format( "UNABLE TO MOVE ^1 TO ^2 - NOT SURE WHY.", oldPath, newPath )
        end
    else
        return false, str:format( "UNABLE TO MOVE ^1 TO ^2 - MORE: ^3", oldPath, newPath, more )
    end
end



--- Determines if path exists as a specified type.
--
--  <p>One motivation: Sometimes its not good enough to know if a path exists or not, but what type it exists as.
--  Adobe realized this, which is why their exists method returns a type string.
--  Problem is, one can not compare it directly to an expected type because if it does not
--  exist, a "boolean being compared to string" error is thrown. Thus, a nested conditional
--  is required: 1. does it exist, 2. What type. This method allows calling context to use a
--  single conditional.</p>
--
--  <p>Side Benefit: Forces calling context to deal with the possibility that a folder may exist where a file is expected,
--  or vice versa, which if un-detected, may cause strange and difficult to diagnose behavior / errors.</p>
--
--  <p>Examples:<blockquote><br>
--
--          path = "/asdf"<br>
--          existsAsFile, isDir = fso:existsAs( path, 'file' ) -- return opposite type else not found if not type.<br>
--          if existsAsFile then<br>
--              -- process file<br>
--          elseif isDir then<br>
--              assert( dirType == 'directory', "Path is to directory: " .. path )<br>
--              -- process path is to directory, not file.<br>
--          else<br>
--              -- process file not found.<br>
--          end<br><br>
--
--          existsAsDir = fso:existsAs( path, 'directory', true ) -- returns true or false, bombs if path is to file.<br>
--          if existsAsDir then<br>
--              -- process directory<br>
--          else<br>
--              -- process dir not found.<br>
--          end<br></blockquote>
--
--  @return             boolean: true iff exists as specified type.
--  @return             IF NOT THROWING ERROR UPON WRONG TYPE: returns the other type.
--
function Disk:existsAs( path, type, throwErrorIfWrongType )
    local exists = LrFileUtils.exists( path )
    if exists then
        if exists == type then
            return true -- 2nd return value nil - implied.
        elseif type == 'file' then
            if throwErrorIfWrongType then
                error( "Path specifies directory, should be file: " .. path )
            end
            return false, true
        elseif type == 'directory' then
            if throwErrorIfWrongType then
                error( "Path specifies file, should be directory: " .. path )
            end
            return false, true
        else
            error( "Program failure - invalid type argument to disk-exists-as: " .. str:to( type ) )
        end
    else
        return false, false
    end
end



--- Determine if path is to a directory.
--
--  @param          path            directory path
--
--  @usage          The directory entry must either not exist, or be a directory, else an error is thrown.
--
function Disk:existsAsDirectory( path )
    return self:existsAs( path, 'directory', true ) -- if you don't want default error behavior, call the generic exists-as directly.
end
Disk.existsAsDir = Disk.existsAsDirectory -- synonym.



--- Determine if path is to a file.
--
--  @param          path            file path
--
--  @usage          The directory entry must either not exist, or be a file, else an error is thrown.
--
function Disk:existsAsFile( path )
    return self:existsAs( path, 'file', true ) -- if you don't want default error behavior, call the generic exists-as directly.
end



--- Deletes a file and confirms deletion instead of relying on status code returned from delete.
--
--  <p>Born from a case I had where a recently deleted file was not able to be immediately written, or something like that.</p>
--
--  @usage                   MUST be called from a task.
--                                
--  @return                  *** Unlike most methods of file-system, this one throws an error if cant delete.
--
function Disk:deleteFileConfirm( path )
    if self:existsAsFile( path ) then
        LrFileUtils.delete( path )
        local count = 0
        repeat
            LrTasks.sleep( .1 )
            count = count + 1
        until not self:existsAsFile( path ) or count == 100 -- ten seconds max.
        if self:existsAsFile( path ) then
            error( "Unable to delete " .. path )
        end
    end
end



--- Delete directory tree.
--      
--  @usage          All contents are deleted - does not need to be empty to start with.
--      
--  @usage          Throws error only upon attempt to delete root or nil tree arg.
--
--  @return         true iff deleted in its entirety.
--  @return         error message if not deleted.
--
function Disk:deleteTree( tree, trash )

    local parent = LrPathUtils.parent( tree )
    if parent == nil then
        error( "Unable to delete root of tree: " .. str:to( tree ) )
    end

    -- files
    for file in LrFileUtils.recursiveFiles( tree ) do
        if trash then
            self:moveToTrash( file ) -- return code ###2
        else
            LrFileUtils.delete( file )
        end
    end

    -- directories
    for file in LrFileUtils.recursiveDirectoryEntries( tree ) do
        -- lr-file-utils-delete doc suggests dir need not be empty, in which case,
        -- this method is not even necessary, except for moving to trash vs. delete, and root checking.
        if trash then
            self:moveToTrash( file )
        else
            LrFileUtils.delete( file )
        end
    end

    -- this dir
    if trash then
        self:moveToTrash( tree )
    else
        LrFileUtils.delete( tree )
    end
    
    if self:existsAsDirectory( tree ) then
        return false, "Unable to delete tree: " .. str:to( tree )
    else
        return true
    end
    
end



--- Moves specified folder or file to trash/recycle bin.
--
--  <p>Initial motivation: lr-move-to-trash was bombing when file was on network share.</p>
--  <p>If move-to-trash not supported, then file will simply be deleted.</p>
--
--  @usage          Note move-to-trash returns false with no reason if specified file does not exist, not sure about delete.<br>
--                  this function however will consider it a success if file not found, so it is strongly recommended to check existence before calling to avoid erroneous<br>
--                  messages about what got moved-to-trash/deleted. ###1
--
--  @return         status - boolean: true iff successfully moved to trash.
--  @return         errorMessage - string: if item not moved - the reason.
--
function Disk:moveToTrash( path )
    --local pcallStatus, status, reason = LrTasks.pcall( LrFileUtils.moveToTrash, path ) - changed 26/Oct/2011 17:02 by RDC - returns status instead of throwing errors, under normal circumstances.
    local status, reason = LrFileUtils.moveToTrash( path )
    if status then
        if reason ~= nil then
            Debug.logn( "lr-file-utils-move-to-trash returned a reason for success:", reason )
        end
        return true -- no comment.
    else
        if LrFileUtils.exists( path ) then
            app:logVerbose( "Move file to trash failed (expected if network drive) with reason: ^1 - trying delete, path: ^2", str:to( reason ), path ) -- remove this line if its bugging you.
            local s, m = LrFileUtils.delete( path ) -- not positive if I can trust this returns either, but...
            if s then -- I'm trusting a postive return status, but not a negative one.
                return true, str:fmt( "^1 could not be moved to trash - it was deleted instead.", path ) -- alls well that ends well. - calling context should check true message before telling user its in trash! ###1
            else
                if LrFileUtils.exists( path ) then
                    return false, "Unable to delete " .. path .. ", error message: " .. str:to( m )
                else
                    app:logWarning( "lr-delete says it didn't delete, but file no longer exists: ^1, error message: ", path, str:to( m ) )
                    return true, str:fmt( "lr-delete says it didn't delete, but file no longer exists - must have been deleted: ^1", path )
                end
            end
        else
            Debug.logn( str:fmt( "lr-file-utils says it couldn't move ^1 to trash because of ^2, but file no longer exists in original location - assuming never existed or successfully moved.", path, str:to( reason ) ) )
            return true -- ###1 this departs from lr's move-to-trash handling.
        end
    end
end



--- Deletes specified folder or file.
--
--  <p>Thin wrapper around lr-file-utils - delete.</p>
--  <p>Initial motivation is "historical".</p>
--
--  @usage          Not sure what happens if specified item does not exist - same as lr version.
--
--  @return         status - boolean: true iff successful.
--  @return         errorMessage - string: if unsuccessful - the reason.
--
function Disk:deleteFolderOrFile( path )
    local status, reason = LrFileUtils.delete( path ) -- Assume protected mode not required, since values returned reflects success or failure.
    if status then
        return true -- no comment.
    else
        return false, "UNABLE TO DELETE " .. path .. ", REASON: " .. str:to( reason )
    end
end



--- Attempts to assure sub-directory tree will exist upon return.
--
--  @usage      throws error if target not directory.
--
--  @usage  Examples:
--          <p>success, qual, created = fsoassureAllDirectories( target )
--          <br>if success then
--          <br>    if created then
--          <br>        nCreated = nCreated + 1
--          <br>        if qual then
--          <br>            logMessageLine( qual )
--          <br>        else
--          <br>            logMessageLine( "Directories created: " .. target )
--          <br>        end
--          <br>    else
--          <br>        nAlready = nAlready + 1
--          <br>    end
--          <br>    -- do things to target...
--          <br>else
--          <br>    assert( created == false )
--          <br>    assert( str:is( qual ) )
--          <br>    logError( "Unable to assure destination directory - " .. qual )
--          <br>    -- abort function...
--          <br>end<p>
--
--  @return         status - boolean: true iff successful.
--  @return         errorMessage - string: if unsuccessful - the reason.
--  @return         created - boolean: true if dir not pre-existing (one or more dir in path was actually created).
--
function Disk:assureAllDirectories( targetDir )
    local existsAsDir = self:existsAs( targetDir, 'directory', true )
    if existsAsDir then
        return true, nil, false
    -- else proceed
    end
    -- fall-through => dest dir not pre-existing.
    local created = LrFileUtils.createAllDirectories( targetDir ) -- supposedly false means dir already exists, but I dont believe it.
    if created then
        return true, nil, true
    else
        assert( not self:existsAsDirectory( targetDir ), "Program failure." ) -- if not existing, error already thrown.
        return false, "Failure creating directories: " .. targetDir, false
    end
end



local __copyBigFile = function( sourcePath, destPath, progressScope )

    local fileSize = LrFileUtils.fileAttributes( sourcePath ).fileSize

    local g
    local s
    local t
    -- local blkSize = 32768 -- typical cluster size on large system or primary data drive.
    local blkSize = 10000000 -- 10MB at a time - lua is fine with big chunks.
    local nBlks = math.ceil( fileSize / blkSize )
    local b
    local x
    g, s = pcall( io.open, sourcePath, 'rb' )
    if not g then return false, s end
    g, t = pcall( io.open, destPath, 'wb' )
    if not g then
        pcall( io.close, s )
        return false, t
    end
    local done = false
    local m = 'unknown error'
    local i = 0
    local yc = 0
    repeat -- forever - until break
        g, b = pcall( s.read, s, blkSize )
        if not g then
            m = b
            break
        end
        if b then
            g, x = pcall( t.write, t, b )
            if not g then
                m = x
                break
            end
            i = i + 1
            if progressScope then
                progressScope:setPortionComplete( i, nBlks )
            end
            yc = RcUtils.yield( yc )
        else
            g, x = pcall( t.flush, t ) -- close also flushes, but I feel more comfortable pre-flushing and checking -
                -- that way I know if any error is due to writing or closing after written / flushed.
            if not g then
                m = x
                break
            end
            m = '' -- completed sans incident.
            done = true
            break
        end
    until false
    pcall( s.close, s )
    pcall( t.close, t )
    if done then
        return true
    else
        return false, m
    end
        
end


--      Synopsis:       Copy or move file from source to destination.
--
--      Assumes:        All pre-requisites have been pre-checked, or caller is willing to accept the consequences of not checking.
--
--      Returns:        - true, test-mode-expl - test mode: pretended to work.
--                      - true, nil  - file actually transferred without incident; no comment.
--                      - false, comment - trouble in paradise; here's why.
--
function Disk:__transferFileUnconditionally( transferFunc, sourcePath, destPath, progressScope )

    -- *** SAVE AS REMINDER: I COULD HAVE SWORN THIS WAS WORKING, YET IT NOW APPEARS NOT TO BE, ERROR MESSAGE: YIELD ACROSS C-CALL BOUNDARY OR SOMETHING LIKE THAT.
    -- IT SEEMS LIKE LIGHTROOM CHANGED THE GUTS SOMEHOW - MY PRESENT THEORY IS LIGHTROOM CHANGED IT TO RUN IN PROTECTED MODE INTERTERNALLY
    -- AND RETURN A BOOLEAN, INSTEAD OF CRASHING UNPROTECTEDLY, AND FORGOT TO DOCUMENT IT.
    -- R c Util s . log Message Line( "Copying " .. sourcePath .. " to " .. destPath )
    -- R c Util s . log Message Line( str:format( "Pcall/Copy returned ^1, ^2", str:to( success ), str:to( worked ) ) )
    
    local worked
    local orNot
    if transferFunc then -- lr-copy or lr-move
        worked, orNot = transferFunc( sourcePath, destPath )
    else
        worked, orNot = self:__copyBigFile( sourcePath, destPath, progressScope ) -- actually, this might be necessary for a move too if moving from one drive to another. ###3
    end

    if worked then
        return true
    else
        return false, "File transfer failed, source: " .. sourcePath .. ", destination: " .. destPath .. ", error message: " .. str:to( orNot )
    end
    
end
        


--      Synopsis:       Copies source file to destination, checking for and responding to potential blockages as specified by calling context.
--
--      Notes:          - if dest-dir-check and overwrite-check are omitted, function performs
--                        just like lr version, except test-mode aware.
--
--      Parameters:     - create-dest-dirs-if-necessary:
--                        - nil:    dest-dir-tree not checked for, just does whatever lr version would in that respect.
--                        - false:  checks for dest-dirs, and if not there, returns failure and explanation.
--                        - true:  checks for dest-dirs, and if not there, creates them.
--                      - overwrite-dest-file-if-necessary:
--                        - nil:    dest-file not checked for, just does whatever lr version would in that respect.
--                        - false:  checks for dest-file, and if there, returns failure and explanation.
--                        - true:  checks for dest-dirs, and if there, deletes it before copying.
--
--      Returns:        status, explanation, overwritten, dirs-created, justTouched
--
function Disk:_transferFile( transferFunc, sourcePath, destPath, createDestDirsIfNecessary, overwriteDestFileIfNecessary, avoidUnnecessaryUpdate, progressScope )
    local destDir
    local overwritten = false
    local dirsCreated = false
    -- local qualification = nil
    -- deal with pre-existing target, if requested.
    local justTouched = false
    if overwriteDestFileIfNecessary then
        local existsAsFile = self:existsAsFile( destPath )
        if existsAsFile then

            if avoidUnnecessaryUpdate then
                
                local same, problem = self:isFileSame( sourcePath, destPath )
                if not problem then
                    if same then
                        justTouched = true -- must still overwrite target to get date updated.
                            -- calling context must see this and avoid processing as changed if it matters.
                    -- else proceed
                    end
                else
                    return false, "Unable to compare files - " .. problem, false, false
                end
            -- else proceed
            end

            local completed, qualification = self:deleteFolderOrFile( destPath ) -- if you use move-to-trash you get a rapidly filling trashcan just by things being updated.
            if completed then -- function call completed successfully.
                -- nothing special done here upon qualification - calling context can look at overwrite flag...
                overwritten = true
            else
                return false, str:format( "Unable to delete pre-existing target for overwrite, path: ^1", destPath )
            end
        else
            -- not necessary
        end
    -- else just try it.
    end
    -- fall-through => dest-file does not exist or dont care if it does.
    -- deal with creating target sub-tree, if requested.
    if createDestDirsIfNecessary and not overwritten then
        destDir = LrPathUtils.parent( destPath )
        local existsAsDir, orNot = self:existsAs( destDir, 'directory', true ) -- bomb if dest-dir represents an existing file, although this is theoretically impossible.
        if existsAsDir then
            -- good to go
        else -- dest-dir does not exist, so necessary to create it.
            local assured, expl, created = self:assureAllDirectories( destDir )
            if assured then
                if created then -- dirs created, or would be.
                    dirsCreated = true
                else -- already exists?
                    error( "Program failure - assure-all-directories." )
                end
            else
                return false, "File transfer failed, explanation: " .. expl, false, false
            end

        end
    -- else not necessary
    end
    -- fall-through => target dirs prepared, or dont care if they are.
    local status, expl
    status, expl = self:__transferFileUnconditionally( transferFunc, sourcePath, destPath, progressScope )
    return status, expl, overwritten, dirsCreated, justTouched
end



--- Copies source file to destination, as specified.
--
--  <p>Initial motivation: frustration with most API's file copy functions which do not specify what they do
--  if source does not exist, or target does... are directories created?...</p>
--
--  @param      sourcePath                      source file path.
--  @param      destPath                        destination file path.
--  @param      createDestDirsIfNecessary       boolean: default is nil.<blockquote>
--                        - nil:    dest-dir-tree not checked for, just does whatever lr version would in that respect.<br>
--                        - false:  checks for dest-dirs, and if not there, returns failure and explanation.<br>
--                        - true:  checks for dest-dirs, and if not there, creates them.</blockquote>
--  @param      overwriteDestFileIfNecessary    boolean: default is nil.<blockquote>
--                        - nil:    dest-file not checked for, just does whatever lr version would in that respect.<br>
--                        - false:  checks for dest-file, and if there, returns failure and explanation.<br>
--                        - true:  checks for dest-dirs, and if there, deletes it before copying.</blockquote>
--  @param      avoidUnnecessaryUpdate          boolean: true => pre-read file before writing, and don't write if no new data. Default is false.
--
--  @usage    Assumes source file exists - bombs if not.
--
--  <p>Example #1:     sts, expl, ov, dirs, touched = fso:copyFile( source, dest, true, true )<blockquote>
--                      if sts then<br>
--                          if expl then<br>
--                              logMessage( expl ) -- test mode log<br>
--                          else<br>
--                              logMessage( "File copied. " ) -- normal mode log.<br>
--                          end<br>
--                          if ov then<br>
--                              logMessage( "Target file overwritten. " )<br>
--                          elseif dirs then<br>
--                              logMessage( "Target dirs created. " )<br>
--                          end<br>
--                          logMessageLine()<br>
--                      else<br>
--                          logError( "File copy failed: " .. expl )<br>
--                      end</blockquote></p>
--
--  <p>Example #2:     sts, expl = fso:copyFile( source, dest )<blockquote>
--                      if sts then<br>
--                          if expl then<br>
--                              logMessageLine( expl ) -- test mode log<br>
--                          else<br>
--                              logMessageLine( "File copied. " ) -- normal mode log.<br>
--                          end<br>
--                      else<br>
--                          logError( "File copy failed: " .. expl )<br>
--                      end</blockquote></p
--          
--  @return         status - boolean: true iff successful.
--  @return         errorMessage - string: if unsuccessful - the reason.
--  @return         overwritten - boolean: true if pre-exisint file overwritten.
--  @return         dirsCreated - boolean: true if target dir had to be created.
--  @return         touched - boolean: true if target file existed with exact same contents already.
--
function Disk:copyFile( sourcePath, destPath, createDestDirsIfNecessary, overwriteDestFileIfNecessary, avoidUnnecessaryUpdate )
    assert( self:existsAsFile( sourcePath ), "Source file does not exist: " .. sourcePath )
    return self:_transferFile( LrFileUtils.copy, sourcePath, destPath, createDestDirsIfNecessary, overwriteDestFileIfNecessary, avoidUnnecessaryUpdate )
end


--- Like copy-file, except for files big enough to warrant a progress-indicator - like video.
--
--  <p>The other motivation for this function is file transfer efficiency. For some reason, Lightrooms
--  file copy/mover can be extremely inefficient sometimes.</p>
--
--  <p>I probably should find someway to move the decision for use out of the app and into this class, until then...</p>
--
--  @usage parameters are the same as for copying normal file, except progress-scope is new...
--
function Disk:copyBigFile( sourcePath, destPath, createDestDirsIfNecessary, overwriteDestFileIfNecessary, avoidUnnecessaryUpdate, progressScope )
    assert( self:existsAsFile( sourcePath ), "Source file does not exist: " .. sourcePath )
    return self:_transferFile( nil, sourcePath, destPath, createDestDirsIfNecessary, overwriteDestFileIfNecessary, avoidUnnecessaryUpdate, progressScope )
end



--- Moves source file to destination, or rename.
--
--  @usage      Assumes source file exists - throws error if not.
--  @usage      See copy-file for additional info.
--
function Disk:moveFile( sourcePath, destPath, createDestDirsIfNecessary, overwriteDestFileIfNecessary, avoidUnnecessaryUpdate )
    assert( self:existsAsFile( sourcePath ), "Source file does not exist: " .. sourcePath )
    -- I'm assuming since lightroom gave us the same-volume api and suggested caller could use it to tell whether a copy or move
    -- is warranted, its because they did not do the right thing, and are passing the buck. I hereby accept...
    if LrFileUtils.pathsAreOnSameVolume( sourcePath, destPath ) then
        return self:_transferFile( LrFileUtils.move, sourcePath, destPath, createDestDirsIfNecessary, overwriteDestFileIfNecessary )
    else
        local status, expl, ov, dirs, justTouched = self:_transferFile( LrFileUtils.copy, sourcePath, destPath, createDestDirsIfNecessary, overwriteDestFileIfNecessary, avoidUnnecessaryUpdate )
        if status then
            local deleted, reason = LrFileUtils.delete( sourcePath ) -- Better to use delete instead of move to trash, so it doesn't fill up with stuff thats not really been deleted.
                -- no need for test mode aware-ness either, since that is pre-checked. lr-file-utils runs in protected mode, I think - at a minimum it pre-checks file existence before proceeding.
            if deleted then
                -- alls well.
            else
                status = false
                expl = "Unable to delete source file (" .. sourcePath .. ") after copying to destination (" .. destPath .. "), reason: " .. str:to( reason )
            end
        else
            status = false
            expl = "Could not copy source file to destination: " .. expl
        end
        return status, expl, ov, dirs, justTouched
    end
end



--- Determine if target file content is different than source file content.
--
--  @usage          Keeps unchanged targets from being updated if not necessary.
--  @usage          Works in protected mode to avoid bombing upon i-o failure.
--  @usage          Tests a relatively small block first, then does larger ones from there on out.
--                      
--  @usage          Examples:
--          <p>local same, problem = fso-isFileSame( path1, path2 )
--          <br>if not problem then
--          <br>    if same
--          <br>        -- dont update
--          <br>    else
--          <br>        -- update target
--          <br>    end
--          <br>else
--          <br>    -- process error message
--          <br>end</p>
--
--  @return         status (boolean) true if files are same content-wise, false if different, nil if error.
--  @return         error message (string) if error.
--
function Disk:isFileSame( path1, path2 )

    -- first check file sizes
    local size1 = LrFileUtils.fileAttributes( path1 ).fileSize
    local size2 = LrFileUtils.fileAttributes( path2 ).fileSize
    if size1 ~= size2 then return false end

    local success, file1, file2, errorMessage
    success, file1, errorMessage = LrTasks.pcall( io.open, path1, "rb" ) -- read-binary
    if success then
        if file1 then -- io-open returned a happy file handle
            success, file2, errorMessage = LrTasks.pcall( io.open, path2, "rb" ) -- read-binary
            if success then
                if file2 then
                    -- good
                else
                    file1:close()
                    return nil, "io-open error: " .. str:to( errorMessage ) .. ", path2: " .. path2
                end
            else
                file1:close()
                return nil, "Protected call to io-open failed, path2: " .. path2
            end
        else
            return nil, "io-open error: " .. str:to( errorMessage ) .. ", path1: " .. path1
        end
    else
        return nil, "Protected call to io-open failed, path1: " .. path1
    end
    -- fall-through => pcall success, and both files opened for reading.
    local blockSize = 32000 -- read a relatively small chunk first (about same size as default cluster for big disks on windows),
        -- in case difference is there (more efficient).
    local block1, block2

    local same = true
    assert( errorMessage == nil, "Program failure - got unexpected error message." )
    
    repeat -- until break
        success, block1 = LrTasks.pcall( file1.read, file1, blockSize )
        if success then -- call completed
            success, block2 = LrTasks.pcall( file2.read, file2, blockSize )
            if success then -- call completed
                if block1 then -- data read
                    if block2 then -- data read
                        if block1 == block2 then -- data same - I'm guessing modern hardware performs this comparison pretty fast, no?
                            -- continue
                        else
                            same = false
                            break
                        end
                    else
                        same = false
                        break
                    end
                elseif not block2 then
                    break -- out of data in both files, and no discrepancies so far.
                else
                    same = nil
                    errorMessage = "IO error reading file2: " .. path2
                    break
                end
            else
                -- same = false
                break
            end
        else
            same = nil
            errorMessage = "IO error reading file1: " .. path1
            break
        end
        blockSize = 1000000 -- ~1MB at a time hereafter. Hope this not too big...
    until true -- break to exit loop

    local ok1 = self:closeFile( file1 )
    local ok2 = self:closeFile( file2 )
    
    return same, errorMessage -- ignoring file closure errors.
end



--[[    *** SAVE FOR POSSIBLE FUTURE RESURRECTION.

        Synopsis:       Change last modified date to current date-time.

        Motivation:     Support for Photooey, which renders a file without knowing whether
                        it really needs to be done. If it doesn't then it opts to touch
                        the target, so its less likely to be rendered again next time.

        Notes:          - dependent libraries lack support for touching, so file is read, deleted,
                          then re-written instead.
    
        Returns:        true, nil:          worked, no comment.
                        true, comment:      pretending it worked - test mode message.
                        false, comment:     failed, error message.
--] ]
function Disk:touch( filePath )
    local sts, contents, qual
    contents, qual = self:readFile( filePath )
    if contents and not qual then -- read file works even in test mode.
        LrFileUtils.delete( filePath ) -- ### robusten/protect.
        sts, qual = self:writeFile( filePath, contents )
        return sts, qual
    else
        return false, str:format( "Unable to touch file: ^1, more: ^2", filePath, str:to( qual ) )
    end
end
--]]



--- Closes a file protectedly.
--
--  <p>Initial motivation: to keep file close errors from interrupting export services - better to log error and keep going.</p>
--
--  @return         true iff successful.
--
function Disk:closeFile( fileHandle )
    local ok = pcall( fileHandle.close, fileHandle )
    return ok
end



--- Get entire contents of file.
--
--  <p>Runs in protected mode so export does not die upon first i-o failure.</p>
--
--  @param      filePath        absolute path to file.
--
--  @usage      Uses binary mode, which can also be used for reading text files as long as you don't mind zeros and CR/LF in your string...
--  @usage      @3/Aug/2011 10:37 works with non-ascii chars in path (previous versions did NOT). ###1 - should re-release all plugins using this method.
--
--  @return     contents - string: non-nil if successful.
--  @return     comment - string: explanation for failure.    
--
function Disk:readFile( filePath )
    -- local status, contents = LrTasks.pcall( LrFileUtils.readFile, filePath )
    local status, contents = pcall( LrFileUtils.readFile, filePath ) -- required for non-ascii path, hopefully doesn't yield (so this function works whether task or not),
        -- for the time being, if there is ever a yield failure, I want to know about it, since I'm assuming/hoping/advertising this will work in task or out.
        -- also, dofile and loadfile are using lr-file-utils-read-file in a non-task environment.
    if status then
        if contents then
            return contents
        else
            return nil, "unable to obtain contents of file: " .. str:to( filePath )
        end
    elseif str:is( contents ) then
        return nil, contents -- error message
    else
        return nil, "unknown error reading contents of " .. str:to( filePath )
    end
    --[[ *** save for posterity
    local msg = nil
    local contents = nil
    local ok, fileOrMsg = pcall( io.open, filePath, "rb" )
    if ok and fileOrMsg then
        local contentsOrMsg
        ok, contentsOrMsg = pcall( fileOrMsg.read, fileOrMsg, "*all" ) - won't work with non-ascii chars in path
        if ok then
            contents = contentsOrMsg
        else
            msg = str:format( "Read file failed, path: ^1, additional info: ^2", filePath, str:to( contentsOrMsg ) )
        end
        self:closeFile( fileOrMsg ) -- ignore return values.
    else
        msg = str:format( "Unable to open file for reading, path: ^1, additional info: ^2", filePath, str:to( fileOrMsg ) )
    end
    return contents, msg
    --]]
end



--- Reads as binary, then gets rid of the zero characters which look like string term char to Lr.
--
--  @param      filePath        absolute path to file.
--
--  @return     binary file contents sans zero bytes.
--
function Disk:readTextFile( filePath )

    local contents, message = self:readFile( filePath )
    if contents then
        return contents:gsub( "[%z]", "" )
    else
        return nil, message
    end
    
end



--- Write entire contents of file.
--
--  <p>Runs in protected mode so export does not die upon first io failure.</p>
--
--  @usage      Dunno how this works out when file-path contains non-ascii characters. ###1
--
--  @return true iff successful.
--  @return error message if failure.
--
function Disk:writeFile( filePath, contents )
    local msg = nil
    local ok
    local fileOrMsg
    ok, fileOrMsg = pcall( io.open, filePath, "wb" )
    if ok and fileOrMsg then
        local orMsg
        ok, orMsg = pcall( fileOrMsg.write, fileOrMsg, contents )
        if ok then
            -- good
        else
            msg = str:format( "Cant write file, path: ^1, additional info: ^2", filePath, str:to( orMsg ) )
        end
        ok = self:closeFile( fileOrMsg )
        if not ok then
            msg = str:format( "Unable to close file that was open for writing, path: ^1", filePath )
        end
    else
        ok = false
        msg = str:format( "Cant open file for writing, path: ^1, additional info: ^2", filePath, str:to( fileOrMsg ) )
    end
    return ok, msg
end



--- Counts directory entries.
--      
--  <p>Initial motivation - in case preparation needs be done before loop processing dir entries.</p>
--
--  @usage      Assumes specified directory is known to exist: does not check.
--
--  @return     number
--
function Disk:numOfDirEntries( path )

    local c = 0
    for dirEnt in LrFileUtils.directoryEntries( path ) do
        c = c + 1
    end
    return c
    
end



--- Get exact path, case and all, to file (typically) already known to exist, but case unknown.
--
--  <p>Handles condition when exact case of file on disk is important - like for looking up in lr-catalog.</p>
--      
--  @usage                 Very inefficient for large directories - best confined to small dirs if possible.
--      
--  @return                path if exists, else nil.
--
function Disk:getExactPath( _path )
    local dir = LrPathUtils.parent( _path )
    local path = LrStringUtils.lower( _path )
    for filePath in LrFileUtils.files( dir ) do
        local path2 = LrStringUtils.lower( filePath )
        if path == path2 then
            return filePath
        end
    end
    return nil
end 



--- Make file read-only.
--
--  @return true iff worked.
--  @return error message iff didn't work.
--
function Disk:makeReadOnly( path )
    local s, m
    if WIN_ENV then
        s, m = app:executeCommand( "ATTRIB", "+R", { path } )
    else
        s, m = app:executeCommand( "chmod", "a-w", { path } )
        if s and app:isDebugEnabled() then
            assert( fso:isReadOnly( path ), "still writeable" )
        end
    end
    return s, m
end



--- Make file read-write.
--
--  @return true iff worked.
--  @return error message iff didn't work.
--
function Disk:makeReadWrite( path )
    local s, m
    if WIN_ENV then
        s, m = app:executeCommand( "ATTRIB", "-R", { path } )
    else
        s, m = app:executeCommand( "chmod", "a+w", { path } )
        if s and app:isDebugEnabled() then
            assert( not fso:isReadOnly( path ), "not read-write" )
        end
    end
    return s, m
end



--- Determine if file is read-only.
--
--  @return true iff read-only.
--  @return error message iff didn't work.
--
function Disk:isReadOnly( path )

    if WIN_ENV then
        local s, m, c = app:executeCommand( "ATTRIB", nil, { path }, nil, "del" )
        if s then
            local r = c:find( "%sR%s" )
            local f = c:find( path, 1, true )
            if f then
                if r and r < f then
                    return true
                else
                    return false
                end
            else
                return nil, "file attributes not found: " .. path
            end
        else
            return nil, m
        end
    else
        local s, m, c = app:executeCommand( "ls", "-l", { path }, nil, "del" )
        if s then
            if c then
                local p1, p2 = c:find( LrPathUtils.leafName( path ), 1, true )
                if p1 and p1 > 10 then
                    --  u  g  o
                    -- drwxrwxrwx
                    -- 1234567890
                    local u = str:getChar( c, 3 )
                    local g = str:getChar( c, 6 )
                    local o = str:getChar( c, 9 )
                    if u == 'w' or g == 'w' or o == 'w' then -- its writeable by somebody.
                        return false
                    else
                        return true -- not writeable by anybody.
                    end
                else
                    return nil, "invalid response to ls command (for read-only attributes): " .. str:to( c )
                end
            else
                error( "program failure - no command content returned" )
            end
        else
            return nil, m
        end
    end
    
end



--- Copy files in folder to target destination, maintaining directory structure.
--
--  @usage  does not pre-check destination, so if an exact dup is desired, pre-delete dest.
--
function Disk:copyTree( src, dest, excl )
    local errs = 0
    local copied = 0
    if excl == nil then
        excl = {}
    end
    local function isExcl( f )
        for i, v in ipairs( excl ) do
            local fc = str:getFirstChar( v )
            local lc = str:getLastChar( v )
            local mt, fd
            if fc == '*' then
                if lc == '*' then
                    mt = v:sub( 2, v:len() - 1 )
                    fd = f:find( mt, 1, true )
                    if fd then
                        return true
                    end
                else
                    mt = v:sub( 2 )
                    fd = str:isEndingWith( f, mt )
                    if fd then
                        return true
                    end
                end
            else
                if lc == '*' then
                    mt = v:sub( 1, v:len() - 1 )
                    fd = str:isStartingWith( f, mt )
                    if fd then
                        return true
                    end
                else
                    fd = f:find( v, 1, true )
                    if fd then
                        return true
                    end
                end
            end
        end
        return false
    end
    for filePath in LrFileUtils.recursiveFiles( src ) do
        repeat
            local destPath
            local subPath = LrPathUtils.makeRelative( filePath, src )
            if isExcl( subPath ) then -- this allows one to use asdf* notation and know that asdf will be anchored at common sub-path.
                app:logVerbose( "Excluding copy of " .. subPath )
                break
            end
            if subPath then
                destPath = LrPathUtils.child( dest, subPath )
                local s, m = fso:copyFile( filePath, destPath, true, false ) -- create dir, but error out if pre-existing file (dir should have been pre-deleted).
                if s then
                    -- copy logged?
                    app:log( "copied ^1 to ^2", filePath, destPath )
                    copied = copied + 1
                else
                    app:logError( m )
                    errs = errs + 1
                end
            else
                error( "bad" )
            end
        until true
    end
    if errs > 0 then
        return false, "See log file for errors."
    else
        return true
    end
end



--- Determine if source file is newer than target file.
--
--  @usage both files are expected to exist.
--
function Disk:isNewer( srcFile, targFile )

    local d1 = LrFileUtils.fileAttributes( srcFile ).fileModificationDate
    local d2 = LrFileUtils.fileAttributes( targFile ).fileModificationDate
    return d1 > d2
    
end



--- Get file modification date - file need not be known to exist.
--
function Disk:getFileModificationDate( file )

    local attr = LrFileUtils.fileAttributes( file )
    if attr then
        return attr.fileModificationDate
    end
    
end



--- Determine if file is read-write.
--
--  @usage Convenience function: same as not-read-only.
--
function Disk:isReadWrite( path )
    return not isReadOnly( path )
end



return Disk
