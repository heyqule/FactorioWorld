require "map_compressed_terrain_8100"

local scale = settings.global["map-gen-scale"].value
local spawn = {
    x = scale * settings.global["spawn-x"].value,
    y = scale * settings.global["spawn-y"].value
}

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    if not event then return end
    --Should prevent user from changing the settings, but will still get through if he changes it and restarts factorio :(
    if event.setting == "map-gen-scale" then settings.global["map-gen-scale"].value = scale end
    if event.setting == "spawn-x" then settings.global["spawn-x"].value = spawn.x end
    if event.setting == "spawn-y" then settings.global["spawn-y"].value = spawn.y end

    game.print("You shouldn't change the world-gen settings after you started a savegame. This will break the generating for new parts of the map.")
    game.print("I haven't found a good way to prevent you changing them yet, so for new they are just ignored, but will take effect when restarting.")
    game.print("Reset them to what they were, or risk fucking up your save!")
    game.print("Your settings were: ")
    game.print("Scale = " .. scale)
    game.print("spawn: x = " .. spawn.x .. ", y = " .. spawn.y)
end)

----
--Don't touch anything under this, unless you know what you're doing
----
--Terrain codes should be in sync with the ConvertMap code
local terrain_codes = {
    ["_"] = "out-of-map",
    ["o"] = "deepwater",--ocean
    ["O"] = "deepwater-green",
    ["w"] = "water",
    ["W"] = "water-green",
    ["g"] = "grass-1",
    ["m"] = "grass-3",
    ["G"] = "grass-2",
    ["d"] = "dirt-3",
    ["D"] = "dirt-6",
    ["s"] = "sand-1",
    ["S"] = "sand-3"
}

local decompressed_map_data = {}
local width = nil
local height = #terrain_types
for y = 0, #terrain_types-1 do
    decompressed_map_data[y] = {}
end

local function decrompress_line(y)
    local decompressed_line = decompressed_map_data[y]
    if(#decompressed_line == 0) then
        game.print("Decompressing line " .. y)
        --do decompression of this line
        local total_count = 0
        local line = terrain_types[y+1]
        for letter, count in string.gmatch(line, "(%a+)(%d+)") do
            for x = total_count, total_count + count do
                decompressed_line[x] = letter
            end
            total_count = total_count + count
        end
        --check width (all lines must the equal in length)
        if width == nil then
            width = total_count
        elseif width ~= total_count then
            error("Mismatching width: " .. width .. " vs " .. total_count)
        end
    end
end

local function add_to_total(totals, weight, code)
    if totals[code] == nil then
        totals[code] = {code=code, weight=weight}
    else
        totals[code].weight = totals[code].weight + weight
    end
end

local function get_world_tile_name(x, y)
    --safezone
    if x > -5 and x < 5 and y > -5 and y < 5 then
        return "sand-1"
    end
    --spawn
    x = x + spawn.x
    y = y + spawn.y
    --scaling
    x = x / scale
    y = y / scale
    --get cells you're between
    local top = math.floor(y)
    local bottom = (top + 1)
    local left = math.floor(x)
    local right = (left + 1)
    --calc weights
    local sqrt2 = math.sqrt(2)
    local w_top_left = 1 - math.sqrt((top - y)*(top - y) + (left - x)*(left - x)) / sqrt2
    local w_top_right = 1 - math.sqrt((top - y)*(top - y) + (right - x)*(right - x)) / sqrt2
    local w_bottom_left = 1 - math.sqrt((bottom - y)*(bottom - y) + (left - x)*(left - x)) / sqrt2
    local w_bottom_right = 1 - math.sqrt((bottom - y)*(bottom - y) + (right - x)*(right - x)) / sqrt2
    w_top_left = w_top_left * w_top_left + math.random() / math.max(scale / 2, 10)
    w_top_right = w_top_right * w_top_right + math.random() / math.max(scale / 2, 10)
    w_bottom_left = w_bottom_left * w_bottom_left + math.random() / math.max(scale / 2, 10)
    w_bottom_right = w_bottom_right * w_bottom_right + math.random() / math.max(scale / 2, 10)
    --get codes
    local c_top_left_y = top % height
    local c_top_right_y = top % height
    local c_bottom_left_y = bottom % height
    local c_bottom_right_y = bottom % height
    decrompress_line(c_top_left_y)
    decrompress_line(c_top_right_y)
    decrompress_line(c_bottom_left_y)
    decrompress_line(c_bottom_right_y)
    local c_top_left = decompressed_map_data[c_top_left_y][left % width]
    local c_top_right = decompressed_map_data[c_top_right_y][right % width]
    local c_bottom_left = decompressed_map_data[c_bottom_left_y][left % width]
    local c_bottom_right = decompressed_map_data[c_bottom_right_y][right % width]
    --calculate total weights for codes
    local totals = {}
    add_to_total(totals, w_top_left, c_top_left)
    add_to_total(totals, w_top_right, c_top_right)
    add_to_total(totals, w_bottom_left, c_bottom_left)
    add_to_total(totals, w_bottom_right, c_bottom_right)
    --choose final code
    local code = nil
    local weight = 0
    for _, total in pairs(totals) do
        if total.weight > weight then
            code = total.code
            weight = total.weight
        end
    end
    return terrain_codes[code]
end

local function on_chunk_generated(event)
    local surface = event.surface
    local lt = event.area.left_top
    local rb = event.area.right_bottom

    local w = rb.x - lt.x
    local h = rb.y - lt.y
    print("Chunk generated: ", lt.x, lt.y, w, h)

    local tiles = {}
    for y = lt.y-1, rb.y do
        for x = lt.x-1, rb.x do
            table.insert(tiles, {name=get_world_tile_name(x, y), position={x,y}})
        end
    end
    surface.set_tiles(tiles)
end

script.on_event(defines.events.on_chunk_generated, on_chunk_generated)
