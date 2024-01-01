local FS = require("@lune/fs")
local Net = require("@lune/net")
local Roblox = require("@lune/roblox")


local Mod = require("modules")

local Output = Roblox.Instance.new("Model")
Output.Name = "Beatmaps"

local Dir = FS.readDir("./maps")

for _,folder in pairs(Dir) do
    local categoryInstance = Roblox.Instance.new("Folder")
    categoryInstance.Name = folder
    categoryInstance.Parent = Output

    local maps = FS.readDir("./maps/" .. folder)
    for i,v in pairs(maps) do
        local metadata = FS.readFile("./maps/" .. folder .. "/" .. v .. "/Metadata.json")
        local map = Net.jsonDecode(metadata)

        local mapInstance = Roblox.Instance.new("Folder")
        mapInstance.Name = map.FolderName
        mapInstance.Parent = categoryInstance

        local mapFS = FS.readDir("./maps/" .. folder .. "/" .. v)

        for i2,v2 in pairs(mapFS) do
            if v2 ~= "Metadata.json" then
                local diffName = v2
                diffName = string.gsub(diffName, ".json", "")

                print(diffName)

                local diffFolder = Roblox.Instance.new("Folder")
                diffFolder.Name = diffName
                diffFolder.Parent = mapInstance

                -- Convert from inline to multiple string values
                local success, data = pcall(FS.readFile, "./maps/" .. folder .. "/" .. v .. "/" .. v2)
                if not success then
                    warn("Failed to read file: " .. "./maps/" .. folder .. "/" .. v .. "/" .. v2)
                    continue
                end
                
                local inlineData = Net.jsonDecode(data)
                inlineData = Net.jsonEncode(inlineData, false) -- re-encode again to remove whitespace
                
                for t=1, Mod.Util.calculateStringValueInstances(inlineData) do
                    local stringValue = Roblox.Instance.new("StringValue")
                    stringValue.Name = tostring(t)
                    stringValue.Value = string.sub(inlineData, (t - 1) * 195000 + 1, t * 195000)
                    stringValue.Parent = diffFolder
                end
            end
        end
    end
end

local OutputModel = Roblox.serializeModel({ Output })
FS.writeFile("./output.rbxm", OutputModel)