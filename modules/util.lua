local Helper = require("helper")
local HashLib = require("hashlib")

local generate_hash = function(map)
    local str_base = string.format("k%dr%.2f", map.KeyCount, map.SongRate)

    local count = 0;
    for i=#map.HitObjects, 1, -1 do
        local note = map.HitObjects[i]

        if note.Type == 2 then
            str_base = str_base .. string.format("h%s", tostring(i))
        else
            str_base = str_base .. string.format("s%s", tostring(i))
        end

        if count >= 300 then
            break
        end

        count += 1
    end

    local hash = HashLib.md5(str_base)
    return hash
end

local function calculateStringValueInstances(stringData)
    local stringDataSize = #stringData
    local stringValueLimit = 195000 -- bytes
    local stringValueInstancesNeeded = math.ceil(stringDataSize / stringValueLimit)
    return stringValueInstancesNeeded
end

local function GetCommonBPM(HitObjects, TimingPoints)
	if #TimingPoints.BPM == 0 then
		return 0;
	end

	local Durations = {}

	local lastHitObject = HitObjects[#HitObjects]
	local lastTime = if lastHitObject.Type == 2 then lastHitObject.EndTime else lastHitObject.StartTime

	local index = #TimingPoints.BPM
	while true do
		if index >= 1 then
			local point = TimingPoints.BPM[index]

			if point.StartTime > lastTime then
				index -= 1
				continue
			end

			local duration = lastTime - (if index == 1 then 0 else point.StartTime)
			lastTime = point.StartTime

			local tp_exist = Helper:TableFind(Durations, function(tp)
				return tp.BPM == point.Value
			end)

			if tp_exist ~= -1 then
				Durations[tp_exist].Duration += duration
			else
				Durations[#Durations + 1] = {
					BPM = point.Value,
					Duration = duration
				}
			end
		else
			break
		end

		index -= 1
	end

	if #Durations == 0 then
		return 0
	end

	table.sort(Durations, function(tp1, tp2)
		return tp1.Duration > tp2.Duration
	end)

	local result = Durations[1].BPM;
	if result == 0 then
		warn("BREAK")
	end

	return result
end

function NormalizeSV(HitObjects, TimingPoints)
	local NormalizedSVResults = {}
	local BaseBPM = GetCommonBPM(HitObjects, TimingPoints)

	local CurrentBPM = TimingPoints.BPM[1].Value
	local CurrentSvIndex = 1

	local CurrentSVStartTime = nil
	local CurrentSVMultiplier = 1
	local CurrentAdjustedMultiplier = nil
	local InitialSVMultiplier = nil

	for i=1, #TimingPoints.BPM do
		local timing = TimingPoints.BPM[i]
		local nextTimingHasSameTimestamp = false
		if (i+1) <= #TimingPoints.BPM and TimingPoints.BPM[i+1].StartTime == timing.StartTime then
			nextTimingHasSameTimestamp = true
		end
		
		while true do
			if CurrentSvIndex > #TimingPoints.SV then
				break
			end
			
			local sv = TimingPoints.SV[CurrentSvIndex]
			if sv.StartTime > timing.StartTime then
				break
			end
			
			if nextTimingHasSameTimestamp and sv.StartTime == timing.StartTime then
				break
			end
			
			if sv.StartTime < timing.StartTime then
				local multiplier = sv.Value * (CurrentBPM / BaseBPM)
				if CurrentAdjustedMultiplier == nil then
					CurrentAdjustedMultiplier = multiplier
					InitialSVMultiplier = multiplier
				end
				
				if multiplier ~= CurrentAdjustedMultiplier then
					NormalizedSVResults[#NormalizedSVResults+1] = {
						StartTime = sv.StartTime,
						Value = multiplier
					}
					
					CurrentAdjustedMultiplier = multiplier
				end
			end
			
			CurrentSVStartTime = sv.StartTime
			CurrentSVMultiplier = sv.Value
			CurrentSvIndex += 1
		end
		
		if CurrentSVStartTime == nil or CurrentSVStartTime < timing.StartTime then
			CurrentSVMultiplier = 1
		end
		
		CurrentBPM = timing.Value
		
		local multiplier1 = CurrentSVMultiplier * (CurrentBPM / BaseBPM) 
		
		if CurrentAdjustedMultiplier == nil then
			CurrentAdjustedMultiplier = multiplier1
			InitialSVMultiplier = multiplier1
		end
		
		if multiplier1 ~= CurrentAdjustedMultiplier then
			NormalizedSVResults[#NormalizedSVResults+1] = {
				StartTime = timing.StartTime,
				Value = multiplier1
			}
			
			CurrentAdjustedMultiplier = multiplier1
		end
	end
	
	while CurrentSvIndex <= #TimingPoints.SV do
		local sv = TimingPoints.SV[CurrentSvIndex]
		local multiplier = sv.Value * (CurrentBPM / BaseBPM)
		
		if CurrentAdjustedMultiplier == nil then
			error("CurrentAdjustedMultiplier:null != null")
		end
		
		if multiplier ~= CurrentAdjustedMultiplier then
			NormalizedSVResults[#NormalizedSVResults+1] = {
				StartTime = sv.StartTime,
				Value = multiplier
			}
			
			CurrentAdjustedMultiplier = multiplier
		end
		
		CurrentSvIndex += 1
	end

	local InitialSliderVelocity = InitialSVMultiplier or 1
	TimingPoints.SV = NormalizedSVResults

    return InitialSliderVelocity, TimingPoints
end

return {
    generate_hash = generate_hash,
    calculateStringValueInstances = calculateStringValueInstances,
    NormalizeSV = NormalizeSV
}