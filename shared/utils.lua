-- =====================================================================
-- Shared utilities (client + server)
--
-- Why this file exists:
--   `json.encode(vector3(1.0, 2.0, 3.0))` does NOT produce `{ x, y, z }`,
--   it produces a plain array `[1.0, 2.0, 3.0]`. When that JSON is decoded
--   again, `coords.x` is nil, which makes every native that needs a vector
--   (AddBlipForCoord, PolyZone, ox_target, TaskGoToCoordAnyMeans, ...) fail.
--
--   The same applies to coordinates sent through TriggerClientEvent /
--   TriggerServerEvent: depending on the serialiser a vector3 may arrive as
--   a real vector3 or as a table. Everything that stores a coordinate in
--   JSON or ships it over the network must therefore be normalised back into
--   a real vector3 on the receiving side.
--
-- config.lua is loaded as a shared script and declares the `OTGSaloons`
-- namespace, so these helpers are available on both sides at runtime.
-- =====================================================================

OTGSaloons = OTGSaloons or {}

--- Suffix used by every coordinate field of a saloon record
--- (coords, counterCoords, cashRegisterCoords, craftingCoords, musicCoords,
---  dancerCoords, ...). Keeping the check suffix based means new point types
--- added by the in-game creator are handled automatically.
local COORD_SUFFIX = 'Coords'

--- Returns true when a saloon field stores a coordinate.
--- @param key any
--- @return boolean
function OTGSaloons.IsCoordKey(key)
    if type(key) ~= 'string' then return false end
    if key == 'coords' then return true end
    return #key > #COORD_SUFFIX and key:sub(-#COORD_SUFFIX) == COORD_SUFFIX
end

--- Normalises any coordinate-like value into a real vector3.
--- Accepts vector3, vector4, { x =, y =, z = }, { [1], [2], [3] } and
--- { 1, 2, 3 } (array), because all of them can come back from JSON or an
--- event. Returns `fallback` when the value cannot be interpreted.
--- @param value any
--- @param fallback vector3|nil
--- @return vector3
function OTGSaloons.ToVector3(value, fallback)
    fallback = fallback or vector3(0.0, 0.0, 0.0)

    if value == nil then
        -- The fallback can itself still be an un-normalised value (saloon.coords
        -- straight out of JSON, for example). Returning a plain table here would
        -- break every native that expects a real vector, so normalise it too.
        if type(fallback) == 'vector3' then return fallback end
        return OTGSaloons.ToVector3(fallback, vector3(0.0, 0.0, 0.0))
    end

    local valueType = type(value)
    if valueType == 'vector3' then
        return value
    elseif valueType == 'vector4' then
        return vector3(value.x, value.y, value.z)
    elseif valueType ~= 'table' then
        return fallback
    end

    local x = value.x or value[1]
    local y = value.y or value[2]
    local z = value.z or value[3]

    if x == nil or y == nil or z == nil then return fallback end

    return vector3(tonumber(x) or 0.0, tonumber(y) or 0.0, tonumber(z) or 0.0)
end

--- Converts a coordinate into a plain table, which is what json.encode needs.
--- @param value any
--- @return table { x = number, y = number, z = number }
function OTGSaloons.CoordsToTable(value)
    local coords = OTGSaloons.ToVector3(value)
    return { x = coords.x, y = coords.y, z = coords.z }
end

--- Normalises every coordinate field of a saloon record in place.
--- @param saloon table
--- @return table
function OTGSaloons.NormalizeSaloon(saloon)
    if type(saloon) ~= 'table' then return saloon end

    -- The main position is the anchor for every other point, so resolve it
    -- before the loop: the fallback handed to ToVector3 has to be a real
    -- vector3, and `pairs` has no guaranteed order.
    saloon.coords = OTGSaloons.ToVector3(saloon.coords)

    for key, value in pairs(saloon) do
        if OTGSaloons.IsCoordKey(key) then
            saloon[key] = OTGSaloons.ToVector3(value, saloon.coords)
        end
    end

    saloon.zoneRadius = tonumber(saloon.zoneRadius) or 5.0

    return saloon
end

--- Normalises a list of saloon records in place.
--- @param list table
--- @return table
function OTGSaloons.NormalizeSaloons(list)
    if type(list) ~= 'table' then return {} end

    for _, saloon in pairs(list) do
        OTGSaloons.NormalizeSaloon(saloon)
    end

    return list
end

--- Returns a JSON-safe copy of a saloon record (coordinates as plain tables).
--- @param saloon table
--- @return table
function OTGSaloons.SaloonToJsonRecord(saloon)
    local record = {}

    for key, value in pairs(saloon) do
        record[key] = value
    end

    for key, value in pairs(record) do
        if OTGSaloons.IsCoordKey(key) then
            record[key] = OTGSaloons.CoordsToTable(value)
        end
    end

    return record
end

--- Builds the JSON-safe version of a saloon list for SaveResourceFile.
--- @param list table
--- @return table
function OTGSaloons.SaloonsToJson(list)
    local out = {}
    local index = 0

    for _, saloon in ipairs(list) do
        index = index + 1
        out[index] = OTGSaloons.SaloonToJsonRecord(saloon)
    end

    return out
end
