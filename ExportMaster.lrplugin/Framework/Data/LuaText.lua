--[[
        LuaText.lua
        
        Object with methods to serialize / deserialize lua objects or data tables for storage / retrieval.
        
        Originally motivated by the neeed to store develop settings of virtual copies as pseudo-xmp, without having to write special handling
        for tabular adjustments like point curve and locals.
        
        But could be used to create lua objects that save state on disk.
--]]


local LuaText, dbg = Object:newClass{ className = 'LuaText', register = true }



--- Constructor for extending class.
--
function LuaText:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function LuaText:new( t )
    return Object.new( self, t )
end



--  Serialize lua data table t, recursively.
--
--  Acknowlegement: This method based on John Ellis' Debug.pp function.
--
function LuaText:_serialize( value, indent )

    if not indent then indent = 4 end
    local maxLines = 50000 -- for sanity.
    local maxChars = maxLines * 200 -- 10MB
    
    local s = ""
    local lines = 1
    local tableLabel = {}
    local nTables = 0    

    local function addNewline (i)
        if #s >= maxChars or lines >= maxLines then return true end
        if indent > 0 then
            s = s .. "\n" .. string.rep (" ", i)
            lines = lines + 1
            end
        return false
        end

    local function pp1 (x, i)
        if type (x) == "string" then
            s = s .. string.format ("%q", x):gsub ("\n", "n")
            
        elseif type (x) ~= "table" then
            s = s .. tostring (x)
            
        elseif type (getmetatable (x)) == "string" then
            s = s .. tostring (x)
            
        else
            if tableLabel [x] then
                -- s = s .. tableLabel [x] 
                return false
                end
            
            local isEmpty = true
            for k, v in pairs (x) do isEmpty = false; break end
            if isEmpty then 
                s = s .. "{}"
                return false
                end

            nTables = nTables + 1
            local label = "table: " .. nTables
            tableLabel [x] = label
            
            s = s .. "{" 
            -- if indent > 0 then s = s .. "--" .. label end
            local first = true
            for k, v in pairs (x) do
                if first then
                    first = false
                else
                    s = s .. ", "
                    end
                if addNewline (i + indent) then return true end 
                if type (k) == "string" and k:match ("^[_%a][_%w]*$") then
                    s = s .. k
                else
                    s = s .. "["
                    if pp1 (k, i + indent) then return true end
                    s = s .. "]"
                    end
                s = s .. " = "
                if pp1 (v, i + indent) then return true end
                end
            s = s .. "}"
            end

        return false
        end
    
    local v = pp1 ( value, 0 )
    return s

end



--- Serialize lua data object, typically a table.
--
--  @param t the lua table or simple variable to be serialized.
--
--  @usage excludes the dressing needed to use said table upon deserialization, so make sure you precede it with a "return " or "myTbl = " or something.
--
--  @return non-blank string or nil.
--
function LuaText:serialize( t )
    local s = self:_serialize( t, 4 )
    if str:is( s ) then
        return s
    else
        return nil
    end
end



--  Deserialize previously serialized lua data table from.
function LuaText:_deserialize( s, name )
    local func, err = loadstring( s, name ) -- returns nil, errm if any troubles: no need for pcall (short chunkname required for debug).
    if func then
        local result = {}
        result[1], result[2] = func() -- throw error, if any.
        if result[2] ~= nil then
            error( "Custom lua deserializer only supports a value" )
        else
            return result[1]
        end
    else
        --return nil, "loadstring was unable to load contents returned from: " .. tostring( file or 'nil' ) .. ", error message: " .. err -- lua guarantees a non-nil error message string.
        local x = err:find( name )
        if x then
            err = err:sub( x ) -- strip the funny business at the front: just get the good stuff...
        elseif err:len() > 77 then -- dunno if same on Mac ###1
            err = err:sub( -77 )
        end
        return nil, err -- return *short* error message
    end
end



--  Deserialize previously serialized lua data table from s, and assign to object o.
--  ###2 not yet tested.
function LuaText:deserialize( s, name, o )
    if not str:is( name ) then
        if o ~= nil then
            name = str:to( o )
        else
            name = "unknown chunk"
        end
    end
    local t, err = self:_deserialize( s )
    if t ~= nil then
        if not o then
            return t
        else
            for k, v in pairs( t ) do
                o[k] = v
            end
            return o
        end
    else
        return nil, err
    end
end



return LuaText
