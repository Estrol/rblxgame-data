local FS = require("@lune/fs")
local Net = require("@lune/net")
local Luau = require("@lune/luau")
local Roblox = require("@lune/roblox")

local Mod = require("modules")

local DirConvert = FS.readDir("./maps/Convert")
local DirMaps = FS.readDir("./maps/Maps")

for i,v in pairs(DirConvert) do
    local MapFS = FS.readDir("./maps/Convert/" .. v)
    for i2, v2 in pairs(MapFS) do
        if v2 ~= "Metadata.json" then
            local json = FS.readFile("./maps/Convert/" .. v .. "/" .. v2)
            local mapData = Net.jsonDecode(json)

            local starrating = { "0.75", "1.00", "1.50" }
            local starvalue = { 0.75, 1.00, 1.5 }
            local ratingCalc = Mod.RatingCalculator(mapData.HitObjects, 4)
            for i3 = 1, 3 do
                local rating = math.ceil(ratingCalc:ComputeDifficulty({}, starvalue[i3]).SR * 100)

                mapData.Rating[starrating[i3]] = rating
            end

            local stringData = Net.jsonEncode(mapData, true)
            FS.writeFile("./maps/Convert/" .. v .. "/" .. v2, stringData)
        end
    end
end

for i,v in pairs(DirMaps) do
    local MapFS = FS.readDir("./maps/Maps/" .. v)
    for i2, v2 in pairs(MapFS) do
        if v2 ~= "Metadata.json" then
            local json = FS.readFile("./maps/Maps/" .. v .. "/" .. v2)
            local mapData = Net.jsonDecode(json)

            local starrating = { "0.75", "1.00", "1.50" }
            local starvalue = { 0.75, 1.00, 1.5 }
            local ratingCalc = Mod.RatingCalculator(mapData.HitObjects, 4)
            for i3 = 1, 3 do
                local rating = math.ceil(ratingCalc:ComputeDifficulty({}, starvalue[i3]).SR * 100)

                mapData.Rating[starrating[i3]] = rating
            end

            local stringData = Net.jsonEncode(mapData, true)
            FS.writeFile("./maps/Maps/" .. v .. "/" .. v2, stringData)
        end
    end
end