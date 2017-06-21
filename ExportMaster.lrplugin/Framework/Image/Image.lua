--[[
        Image.lua
--]]


local Image, dbg = Object:newClass{ className = "Image", register = true }



--- Constructor for extending class.
--
function Image:newClass( t )
    return Object.newClass( self, t )
end


--- Constructor for new instance.
--
--  @return      new image instance, or nil.
--  @return      error message if no new instance.
--
function Image:new( t )
    local o = Object.new( self, t )
    local s, m
    if o.file and o.content then
        s, m = fso:writeFile( o.file, o.content )
        if s then
            local p = {}
            if o.degrees then
                p[#p + 1] = "-rotate " .. o.degrees
            end
            if o.orient then
                o:addOrientation( o.orient, p )
            end
            s, m = self:mogrify( p )
        -- else return error below
        end
    else
        s, m = false, "need file and content to create an image"
    end
    if s then
        return o
    else
        return nil, m
    end
end



function Image:transferMetadata( fromPhoto, fromPath, profile, toPath )
    -- variable used in cleanup
    local argFilePath
    local tempXmlPath
    -- variables to return
    local s, m = false, "unknown error"
    app:call( Call:new{ name="Transfer Metadata", main=function( context )
    
        local exifTool = app:getPref( 'exifToolApp' )
        if str:is( exifTool ) then
            app:logVerbose( "Using custom exif-tool: " .. exifTool )
        else
            if WIN_ENV then
                exifTool = LrPathUtils.child( _PLUGIN.path, "exiftool.exe" ) -- need extension for windows exe file existence pre-check.
            elseif MAC_ENV then
                exifTool = "exiftool" -- this may or may not work for some folk - if not, they need to specify complete path explicitly.
            else
                app:error( "Undefined environment." )
            end
            -- exiftool command will be detailed below...
        end
        
        local argFileBuf = { "-overwrite_original" }
        local jpgMeta = app:getPref( 'exifMeta' ) -- isolate config for exiftool metadata transfer.

        if jpgMeta then    
            local _tempXmlPath = LrPathUtils.replaceExtension( fromPath, ".exif-pvwXtr.xml" ) -- best if this does not use the same thing as exif-meta.
            tempXmlPath = LrFileUtils.chooseUniqueFileName( _tempXmlPath )
            if tempXmlPath ~= _tempXmlPath then
                app:logVerbose( "Temp exif-xml file should have been deleted last run: " .. _tempXmlPath )
                LrFileUtils.delete( _tempXmlPath )
            end
            
            local s, m = app:executeCommand( exifTool, "-X", { fromPath }, tempXmlPath )
            if s then
                app:logVerbose( "exif xml file obtained using this command: " .. str:to( m ) )
            else
                app:error( "Unable to obtain metadata using exiftool for icc profile info and such stuff, error message: ^1", m )
            end
            local content, comment = LrFileUtils.readFile( tempXmlPath )
            LrFileUtils.delete( tempXmlPath )
            if not str:is( content ) then
                app:error( "Unable to read file: " .. str:to( comment ) )
            end
            -- _debugTrace( "x: ", content )
            local tbl = xml:parseXml( content )
            if not tbl then
                app:error( "Unable to parse exiftool output for icc profile info and such stuff." )
            end
            local stf = ((tbl[2] or {}) [1]) or {}
            for j = 1, #stf do
                repeat
                    local thng = stf[j]
                    if thng == nil then
                        break
                    end
                    
                    local ns = thng.ns
                    local name = thng.name
                    
                    local ref = jpgMeta[ns]
                    if ref then
                        local t = ref[name]
                        if t then -- meta include
                            local value = thng[1]
                            if str:is( value ) then
                                argFileBuf[#argFileBuf + 1] = "-" .. thng.label .. "=" .. value
                            else
                                dbg( "xar ", name )
                            end
                        else
                        
                        end
                        
                    else
                    end                        
                until true                    
            end
        else
            app:logVerbose( "No exif-meta configured for transfer." )
        end
                    
        if profile == 'AdobeRGB' then
            local profilePath = LrPathUtils.child( _PLUGIN.path, 'AdobeRGB1998.icc' )
            app:logVerbose( "Assigning icc profile via exif-tool: ^1", profilePath )
            argFileBuf[#argFileBuf + 1] = "-icc_profile<=" .. profilePath
        elseif profile == 'sRGB' then
            app:logVerbose( "Not assigning sRGB profile." )
        else
            -- app:logWarn( "Invalid icc-profile (^1) - none being assigned, which means it will be treated as sRGB.", str:to( profile ) )
        end
        
        local lrMeta = app:getPref( 'lrMeta' )
        if lrMeta ~= nil then
        for name, tag in pairs( lrMeta ) do
            local value = fromPhoto:getFormattedMetadata( name )
            if value == nil then
                value = fromPhoto:getRawMetadata( name )
            end
            if value ~= nil then
                if type( value ) == 'string' then
                    if value ~= "" then
                        argFileBuf[#argFileBuf + 1] = '-' .. tag .. "=" .. value
                    else
                        app:logVerbose( "xmp val blank: ^1", tag )
                    end
                elseif type( value ) == 'number' then
                    argFileBuf[#argFileBuf + 1] = "-" .. tag .. "=" .. value
                elseif type( value ) == 'boolean' then
                    argFileBuf[#argFileBuf + 1] = "-" .. tag .. "=" .. str:to( value )
                else
                    app:logWarning( "Type?" .. type( value ) )
                    argFileBuf[#argFileBuf + 1] = "-" .. tag .. "=" .. str:to( value )
                end
            else
                app:logVerbose( "No lr metdata for " .. name )
            end
        end
        else
            app:logVerbose( "No Lr Metadata" )
        end

        local spec = app:getPref( 'lrSpecialMeta' )
        if spec then
            -- keywords:
            local kwTags = spec.keywordTags
            local kwTags4Exp = spec.keywordTagsForExport
            local kwStr
            if kwTags then
                kwStr = fromPhoto:getFormattedMetadata( 'keywordTags' )
            elseif kwTags4Exp then
                kwStr = fromPhoto:getFormattedMetadata( 'keywordTagsForExport' )
            else
                app:logVerbose( "No keywords" )
            end
            if str:is( kwStr ) then
                -- argFileBuf[#argFileBuf + 1] = str:fmt( '-sep ", " -keywords+="^1"', kwStr ) - couldn't get this to work.
                local kwArr = str:split( kwStr, "," )
                for i, key in ipairs( kwArr ) do -- this works...
                    argFileBuf[#argFileBuf + 1] = "-keywords+=" .. key
                end
            end 
            -- copyright status
            if spec.copyrightState then
                local status = fromPhoto:getRawMetadata( 'copyrightState' )
                if status == 'copyrighted' then
                    argFileBuf[#argFileBuf + 1] = "-XMP-xmpRights:Marked=True"
                elseif status == 'public domain' then
                    argFileBuf[#argFileBuf + 1] = "-XMP-xmpRights:Marked=False"
                -- else don't mark it.
                end
            end
                    
        else
            app:logVerbose( "No special metadata like keywords." )
        end        
        
        if #argFileBuf > 0 then
            local argFileStr = table.concat( argFileBuf, "\n" )
            local _argFilePath = LrPathUtils.replaceExtension( fromPath, "exif-arg.txt" )
            argFilePath = LrFileUtils.chooseUniqueFileName( _argFilePath )
            if argFilePath ~= _argFilePath then
                app:log( "Temp arg file should have been cleaned up last run, deleting: " .. _argFilePath )
                LrFileUtils.delete( _argFilePath ) -- doesn't really matter the status of this, since
                -- we already have a unique file-path that is free & clear.
            end
            
            local s, m = fso:writeFile( argFilePath, argFileStr )
            
            if s then
                app:logVerbose( "Arg file written: ^1", argFilePath )
                if LrFileUtils.exists( toPath ) then
                    app:logVerbose( "Raw jpg still exists: ^1", toPath )
                    local s, m = app:executeCommand( exifTool, '-@ "' .. argFilePath .. '"', { toPath } )
                    if s then
                        app:log( "Metadata transferred using this command: " .. m )
                    else
                        app:error( "Unable to assign metadata and icc profile, error message: " .. m )
                    end
                else
                    app:error( "Can't do exiftool command - ^1 no longer exists.", toPath )
                end
            else
                app:error( "Unable to write arg file for exiftool input, error message: " .. m )
            end
        else
            app:logWarn( "No metadata to transfer." ) -- very strange to me, but not necessarily an error.
        end

    end, finale=function( call, status, message )
        if argFilePath and fso:existsAsFile( argFilePath ) then
            LrFileUtils.delete( argFilePath )
        end
        local tempXmlPath
        if tempXmlPath and fso:existsAsFile( tempXmlPath ) then
            LrFileUtils.delete( tempXmlPath )
        end
        --[[ original is being overwritten now (save for posterity...)
        local original = toPath .. "_original" -- this is created by default in exiftool command.
        if fso:existsAsFile( original ) then
            LrFileUtils.delete( original )
            app:logError( "Shouldn't be original" )
        end--]]
        s, m = status, message
    end } )
    return s, m

end



function Image:mogrify( p, ... )
    local mog = app:getPref( 'mogrify' )
    if not str:is( mog ) then
        return false, "cant find mogrify setting in plugin manager configuration"
    end
    local param
    -- just dont call if p is nil.
    if type( p ) == 'string' then
        assert( p ~= "", "cant mogrify with a blank string" )
        param = str:fmt( p, ...)
    elseif type( p ) == 'table' then
        if #p > 0 then
            param = table.concat( p, " " )
        else
            app:logVerbose( "Unmogrified." )
            return true, "not mogrified" -- not necessarily bad to not have anything to mog. If its is bad, then check before calling.
        end
    end
    local s, m = app:executeCommand( mog, param, { self.file } )
    return s, m
end



-- profile-name is name of profile that should rightfully be assigned to unmodified image data.
-- 
function Image:addColorProfile( icc, profileName, toProfile, param )
    if icc == 'A' or ( icc == 'C' and profileName == 'AdobeRGB' and toProfile == 'AdobeRGB' ) then -- assignment
        if profileName == 'AdobeRGB' then
            local file = LrPathUtils.child( _PLUGIN.path, 'AdobeRGB1998.icc' )
            if fso:existsAsFile( file ) then
                -- local status, message = app:executeCommand( im, str:fmt( '"^1" -profile "^2"', self.file, file ), { self.file } )
                param[#param + 1] = str:fmt( '-profile "^1"', file )
            else
                app:error( "Missing " .. file )
            end
        elseif profileName == 'sRGB' then -- ###1 note: this assumes the data *is* rgb, if its *not*, then do a convert instead.
            app:logVerbose( "No assignment of color profile in case of sRGB" )
        else
            app:error( "ICC profile not supported: ^1", profileName ) 
        end
    elseif icc == 'C' and not ( profileName == 'sRGB' and toProfile == 'sRGB' ) then -- convert
        if profileName == 'AdobeRGB' then
            assert( toProfile == 'sRGB', "bad icc target profile" )
            local file = LrPathUtils.child( _PLUGIN.path, 'AdobeRGB1998.icc' )
            if fso:existsAsFile( file ) then
                local file2 = LrPathUtils.child( _PLUGIN.path, 'sRGB_IEC61966-2-1_black_scaled.icc' ) -- this looks right.
                -- local file2 = LrPathUtils.child( _PLUGIN.path, 'sRGB_IEC61966-2-1_no_black_scaling.icc' ) -- this closes the shadows too much.
                if fso:existsAsFile( file2 ) then
                    param[#param + 1] = str:fmt( '-profile "^1" -profile "^2"', file, file2 )
                else
                    app:error( "Missing " ..  file2 )
                end
            else
                app:error( "Missing " .. file )
            end
        elseif profileName == 'sRGB' then
            local file = LrPathUtils.child( _PLUGIN.path, 'sRGB_IEC61966-2-1_black_scaled.icc' )
            if fso:existsAsFile( file ) then
                local file2 = LrPathUtils.child( _PLUGIN.path, 'AdobeRGB1998.icc' )
                if fso:existsAsFile( file2 ) then
                    param[#param + 1] = str:fmt( '-profile "^1" -profile "^2"', file, file2 )
                else
                    app:error( "Missing " ..  file2 )
                end
            else
                app:error( "Missing " .. file )
            end
        else
            app:error( "ICC profile not supported: ^1", profileName ) 
        end
    elseif icc ~= 'A' and icc ~= 'C' then
        app:callingError( "Bad icc op: ^1", icc )
    elseif profileName == 'sRGB' then
        assert( toProfile == 'sRGB', "icc profile mixup" )
        app:logVerbose( "No need to convert from sRGB to sRGB" )
    end
end



--[[ obs
function Image:setRotation( degrees )
    self.degrees = degrees
    if self.file then
        local s, m = self:mogrify( '-rotate ^1', degrees )
        if s then
            app:logVerbose( "Rotated ^1", degrees )
        end
        return s, m
    else
        app:logWarning( "Unable to set rotation if no file" )
        return false, "@1/Oct/2011, unable to set rotation if no file."
    end
end
--]]



function Image:addOrientation( orient, param )
    app:logVerbose( "Setting orientation of ^1 to ^2", self.file, orient  )
    self.orient = orient
    local degrees
    -- local suspect = "not sure what to do"
    local flop
    if orient == 'AB' then -- unflipped/unrotated, or its flipped & rotated equivalent.
        -- degrees = 0 - for purposes here, no need to rotate if 0 degrees.
        return
    elseif orient == 'BC' then
        degrees = 90
    elseif orient == 'CD' then
        degrees = 180
    elseif orient == 'DA' then
        degrees = 270
    elseif orient == 'BA' then -- flipped horizontal, no rotation.
        flop = "-flop"
    elseif orient == 'AD' then -- ", 90
        flop = "-flop"
        degrees = 90
    elseif orient == 'DC' then -- ", 180 (which is equivalent to flipped vertically).
        flop = "-flip"
    elseif orient == 'CB' then -- ", 270
        flop = "-flop"
        degrees = 270
    else
        app:callingError( "^1 has '^2' db-orientation, which is not yet supported - please report error: ", str:to( self.file ), orient )
    end
    if flop then
        param[#param + 1] = flop
    end
    if degrees then
        param[#param + 1] = '-rotate ' .. degrees
    end
    return
end


--[[ obs
function Image:getContent()
    app:error( "get-content not implemented - you can get it by reading file instead." )
    -- return self.content
end
function Image:getOrientation()
    return self.orient
end
function Image:getRotation()
    return self.degrees
end
--]]

function Image:getFile()
    return self.file
end



return Image