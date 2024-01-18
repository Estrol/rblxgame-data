

local FS = require("@lune/fs")
local Net = require("@lune/net")
local Luau = require("@lune/luau")
local Roblox = require("@lune/roblox")

Roblox.implementMethod("HttpService", "JSONDecode", function(_, value)
	return Net.jsonDecode(value)
end)

local Mod = require("modules")

local InputModelContent = FS.readFile("./input.rbxmx")
local InputModel = Roblox.deserializeModel(InputModelContent)

local OutputDir = "./maps/Convert"
local ErrorDir = "./error"
local FixDir = "./fixme"

if FS.isDir(OutputDir) then
    FS.removeDir(OutputDir)
end

if FS.isDir(FixDir) then
    FS.removeDir(FixDir)
end

if FS.isDir(ErrorDir) then
    FS.removeDir(ErrorDir)
end

FS.writeDir(OutputDir)
FS.writeDir(FixDir)
FS.writeDir(ErrorDir)

for index, v in pairs(InputModel) do
    if v:IsA("Folder") then
        local dirName = v.Name
        dirName = string.gsub(dirName, "[<>:\"/\\|?*]", "")
        dirName = string.gsub(dirName, "%s+", "")
        dirName = string.gsub(dirName, "[^%z\1-\127\194-\244][^%z\1-\127]", "")
        dirName = string.gsub(dirName, "%.", "")
        
        local fixRequired = false
        for pos, codepoint in utf8.codes(dirName) do
            if codepoint > 127 then
                fixRequired = true
            end
        end

        local songNameSplit = string.split(v.Name, " - ")
        local songName = ""
        local artistName = ""
        if #songNameSplit >= 2 then
            songName = songNameSplit[2]
            artistName = songNameSplit[1]

            if #songNameSplit >= 3 then
                warn("Song name has more than 2 parts: " .. v.Name)
                fixRequired = true
            end
        end

        local outputDirFinal = ""
        if fixRequired then
            outputDirFinal = FixDir
        else
            outputDirFinal = OutputDir
        end

        FS.writeDir(outputDirFinal .. "/" .. dirName)

        local metadata = {
            FolderName = v.Name,
        }

        local metadataString = Net.jsonEncode(metadata, true)
        FS.writeFile(outputDirFinal .. "/" .. dirName .. "/Metadata.json", metadataString)

        for _, v2 in pairs(v:GetChildren()) do
            if v2:IsA("ModuleScript") then
                if string.len(v2.Source) == 0 then
                    continue
                end

                print("Converting: " .. v.Name .. " - " .. v2.Name)

                local source = v2.Source
                local pattern = "return%s+game:GetService%(\"HttpService\"%):JSONDecode"

                if string.find(source, pattern) ~= nil then
                    local append = "local Roblox = require(\"@lune/roblox\")\n"
                    append = append .. "local game = Roblox.Instance.new(\"DataModel\")\n"

                    source = append .. source
                end

                local bytecode = Luau.compile(source)
                local is_success, dataRaw = pcall(Luau.load, bytecode) --Luau.load(bytecode)
                if not is_success then
                    warn("Failed to load data")
                    FS.writeFile(ErrorDir .. "/" .. v.Name .. " - " .. v2.Name .. ".lua", source)
                    error(dataRaw)
                    continue
                end

                local is_success, data = pcall(dataRaw);
                if not is_success then
                    warn("Failed to parse data")
                    FS.writeFile(ErrorDir .. "/" .. v.Name .. " - " .. v2.Name .. ".lua", source)
                    error(dataRaw())
                    continue
                end

                local BPM = v.BPM.Value
                if v.BPM:IsA("StringValue") then
                    -- find the value between bracets in format: `value-value (value)`
                    local bpmString = v.BPM.Value
                    local bpmStringStart = string.find(bpmString, "%(")
                    if bpmStringStart then
                        local bpmStringEnd = string.find(bpmString, "%)")
                        if bpmStringEnd then
                            BPM = tonumber(string.sub(bpmString, bpmStringStart + 1, bpmStringEnd - 1))
                        end
                    else
                        BPM = tonumber(bpmString)
                    end
                end

                local BaseRate = 1
                if v:FindFirstChild("NormalizeRate") then
                    BaseRate = tonumber(v.NormalizeRate.Value)
                end

                if BaseRate == nil then
                    error("BaseRate is nil")
                end

                local mapData = {
                    Version = 3,

                    Name = v.Name,
                    Metadata = {
                        Title = songName,
                        Artist = artistName,
                        Mapper = v.Mapper.Value,
                        DifficultyName = v2.Name,
                    },

                    TimingPoints = {
                        SV = {},
                        BPM = {},
                    },
                    HitObjects = {},

                    AudioId = data.AudioAssetId,
                    BackgroundId = v.BG.Image,
                    Offset = data.AudioTimeOffset,
                    NoteOffset = 0,
                    PreviewTime = 0,
                    Rating = {
                        ["0.75"] = 0,
                        ["1.00"] = 0,
                        ["1.50"] = 0,
                    },
                    PrimaryBPM = BPM,
                    KeyCount = 4,
                    InitialSliderVelocity = 1,
                    SongRate = 1,
                    BaseRate = BaseRate,

                    AudioHash = "",
                }

                local Timings_BPM = {
                    [1] = {
                        StartTime = 0,
                        Inherrited = 0,
                        Value = 240,
                        Signature = 0
                    }
                }

                local Timings_SV = {}

                local HitObjects = {}

                for _, hit in pairs(data.HitObjects) do
                    if hit.Type == 1 then
                        hit.Duration = 0
                    end

                    local hitObj = {
                        StartTime = hit.Time,
                        EndTime = hit.Time + hit.Duration,
                        Lane = hit.Track,
                        Type = hit.Type,
                    }

                    table.insert(HitObjects, hitObj)
                end

                local InitialSliderVelocity, TimingPoints = Mod.Util.NormalizeSV(
                    HitObjects, 
                    {
                        BPM = Timings_BPM,
                        SV = Timings_SV
                    }
                )

                mapData.TimingPoints = TimingPoints
                mapData.HitObjects = HitObjects
                mapData.AudioHash = Mod.Util.generate_hash({ KeyCount = 4, SongRate = 1, HitObjects = data.HitObjects })

                local starrating = { "0.75", "1.00", "1.50" }
		        local starvalue = { 0.75, 1.00, 1.5 }

                local ratingCalc = Mod.RatingCalculator(HitObjects, 4)
                for i = 1, 3 do
                    local rating = math.ceil(ratingCalc:ComputeDifficulty({}, starvalue[i]).SR * 100)

                    mapData.Rating[starrating[i]] = rating
                end

                local stringData = Net.jsonEncode(mapData, true)

                local fileName = v2.Name
                fileName = string.gsub(fileName, "[<>:\"/\\|?*]", "")
                fileName = string.gsub(fileName, "[^%z\1-\127\194-\244][^%z\1-\127]", "")
                fileName = string.gsub(fileName, "%.", "")
                FS.writeFile(outputDirFinal .. "/" .. dirName .. "/" .. fileName .. ".json", stringData)
            end
        end
    end
end