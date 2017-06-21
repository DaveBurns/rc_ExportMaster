--[[
        Table.lua
--]]

local Table, dbg = Object:newClass{ className = 'Table', register = false }



--- Constructor for extending class.
--
function Table:newClass( t )
    return Object.newClass( self, t )
end



--- Constructor for new instance.
--
function Table:new( t )
    return Object.new( self, t )
end



--  Compute md5 over table elements.
--
function Table:_md5( t )

    if t == nil then return end
    
    if self.visited [t] then return end
    self.visited [t] = true
    
    if type( t ) ~= 'table' then
        local val = str:to( t )
        -- app:logInfo( "val-t: " .. val )
        self.md5str[#self.md5str + 1] = val
    else
        for k,v in pairs( t ) do
            if type( v ) == 'table' then
                self:_md5( v )
            else
                local val = str:to( v )
                -- app:logInfo( "val-tv, key: " .. str:to( k ) .. ", val: " .. val )
                self.md5str[#self.md5str + 1] = val
            end
        end 
    end
end



--- Compute md5 over table elements.
--
function Table:md5( t )
    self.md5str = {}
    self.visited = {}
    self:_md5( t )
    local str = table.concat( self.md5str, '' )
    local md5 = LrMD5.digest( str )
    return md5
end



---     Get array of sorted keys.
--
function Table:arrayOfSortedKeys( t, sortFunc )
    local a = {}
    for k in pairs( t ) do
        a[#a + 1] = k
    end
    table.sort( a, sortFunc )
    return a
end



--- Return iterator that feeds k,v pairs back to the calling context sorted according to the specified sort function.
--      
--  @usage      sort-func may be nil, in which case default sort order is employed.
--      
--  @return     iterator function
--
function Table:sortedPairs( t, sortFunc )
    local a = self:arrayOfSortedKeys( t, sortFunc )
    local i = 0
    return function()
        i = i + 1
        return a[i], t[a[i]]
    end
end



--- Determine if table has any elements.
--      
--  @usage      Determine if specified variable includes at least one item in the table, either at a numeric index or as key/value pair.
--      
--  @return     boolean
--
function Table:isEmpty( t )
    if t == nil then return true end
    if #t > 0 then return false end
    for _,__ in pairs( t ) do
        return false
    end
    return true
end



--- Count non-nil items in table.
--      
--  @usage     #table-name gives highest assigned item - won't span nil'd items, therefore: this function is for when some have been nil'd out.
--
function Table:countItems( t )
    local count = 0
    for k,v in pairs( t ) do
        if v ~= nil then
            count = count + 1
        end
    end
    return count
end



--- Appends one array to another.
--
--  @usage      the first array is added to directly - nothing is returned.
--
function Table:appendArray( t1, t2 )
    for i = 1, #t2 do
        t1[#t1 + 1] = t2[i]
    end
end



--- Searches for an item in an array.
--      
--  @return            boolean
--
function Table:isFoundInArray( t1, item )

    if t1 then
        for i = 1, #t1 do
            if t1[i] == item then
                return true
            end
        end
    end
    return false

end



--- Like "append", except creates a new array.
--      
--  @usage             Does not check for item duplication.
--      
--  @return            new array = combination of two passed arrays.
--
function Table:combineArrays( t1, t2 )
    local t = {}
    if t1 ~= nil then
        for k,v1 in ipairs( t1 ) do
            t[#t + 1] = v1
        end
    end
    if t2 ~= nil then
        for i,v2 in ipairs( t2 ) do
            t[#t + 1] = v2
        end
    end
    return t
end




--- Like "combine", except DOES check for item duplication.
--      
--  @usage      good for coming up with a new array that includes all items from the passed arrays.
--      
--  @return     new array.
--
function Table:mergeArrays( t1, t2 )
    local t = {}
    if t1 then
        for k,v1 in ipairs( t1 ) do
            t[#t + 1] = v1
        end
    end
    if t2 then
        for i,v2 in ipairs( t2 ) do
            if not self:isFoundInArray( t1, v2 ) then
                t[#t + 1] = v2
            end
        end
    end
    return t
end



--- Adds items in one table to another.
--
--  @param      t      a table of key-value pairs to be added to.
--  @param      t2      a table of key-value pairs to add.
--
--  @usage      adds all t2 items to t - nothing is returned.
--  @usage      Note: values of t2 will overwrite same-key values of t, so make sure thats what you want...
--      
function Table:addItems( t, t2 )
    for k, v in pairs( t2 ) do
        t[k] = v
    end
    return t
end



--- Set table member access strictness policy.
--
--  @param write (boolean, default false) true => strict write access, false => lax.
--  @param read (boolean, default false) true => strict read access, false => lax.
--
--  @usage Do not use for _G - use global-specific set-strict method instead.
--  @usage Useful for closing a table (strict) so accidental assignment or access is caught immediately.
--  @usage Note: one can always use rawset and rawget directly to bypassness strictness completely.
--
function Table:setStrict( t, write, read )
    local mt = getmetatable(t)
    if mt == nil then
        mt = { __declared = {} }
        setmetatable( t, mt )
    elseif not mt.__declared then
        mt.__declared = {}
    end
    if write then
        -- *** blindly overwrites previous new-index function.
        mt.__newindex = function (t, n, v)
            if n == nil then return end
            if not mt.__declared[n] then
                local w = debug.getinfo(2, "S").what
                if w ~= 'C' then
                    error("assign to undeclared lua table member '"..n.."'", 2)
                end
                mt.__declared[n] = true
            end
            rawset(t, n, v)
        end
    else
        mt.__newindex = function( t, n, v )
            rawset( t, n, v )
        end
    end
    if read then    
        -- *** blindly overwrites previous index function.
        mt.__index = function (t, n)
            if n == nil then return nil end
            if not mt.__declared[n] then
                local w = debug.getinfo(2, "S").what
                if w ~= 'C' then
                    error("lua table member '"..n.."' is not declared", 2)
                end
            end
            return rawget(t, n)
        end
    else
        mt.__index = function( t, n )
            return rawget( t, n )
        end
    end
end



--- Failsafe way to add a member to a table that may already be closed for write access (strict write-access policy has been set).
--
--  @usage Subsequent accesses may be direct without error, even on closed table.
--
function Table:initVar( t, n, v, overwriteOk )
    if t == nil then error( "no table" ) end
    if n == nil then return end
    local mt = getmetatable( t )
    if not mt then
        mt = {}
        setmetatable( t, mt )
    end
    if not mt.__declared then
        mt.__declared = {}
    end
    if not overwriteOk then
        local value = rawget( t, n )
        if value then
            error( "Already declared: " .. str:to( n ) )
        end
    end
    -- note: its ok to overwrite nil value whether already declared or not.
    mt.__declared[n] = v
    rawset( t, n, v )        
end



--- Determines if two tables (or non-table values) are equivalent.
--
--  @return true iff equivalent members at same indexes, even if order returned by pairs is different.
--
function Table:isEquivalent( t1, t2 )
    if ( t1 == nil ) and ( t2 == nil ) then
        return true
    elseif t1 == nil then
        return false
    elseif t2 == nil then
        return false
    end
    if type( t1 ) ~= type( t2 ) then
        return false
    end
    if type( t1 ) == 'table' then
        for k, v in pairs( t1 ) do
            if not self:isEquivalent( v, t2[k] ) then
                return false
            end
        end
        return true
    else
        return t1 == t2
    end
    app:error( "how here?" )
end



return Table