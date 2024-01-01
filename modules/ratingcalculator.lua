local DOUBLE_EPSILON = 1e-7
local function DefinitelyBigger(value1, value2, acceptableDifference)
	if acceptableDifference == nil then acceptableDifference = DOUBLE_EPSILON end
	
	return value1 - acceptableDifference > value2
end

local function ApplyDecay(value, deltaTime, decayBase)
	return value * math.pow(decayBase, deltaTime / 1000)
end

local Strain = function(KeyCount: number)
    local HoldEndTimes = {}
    local individualStrains = {}

    for i=1, KeyCount do
        HoldEndTimes[i] = 0
        individualStrains[i] = 0
    end

    return {
        CONST_INDIVIDUAL_DECAY_BASE = 0.125;
		CONST_OVERALL_DECAY_BASE = 0.30;
		CONST_RELEASE_THRESHOLD = 24;
		
		DecayWeight = 0.9;
		StrainMultiplier = 1;
		StrainDecayBase = 1;
		
		m_HoldEndTimes = HoldEndTimes;
		m_individualStrains = individualStrains;
		
		individualStrain = 0;
		overallStrain = 1;
		
		currentSectionPeak = 0;
		currentStrain = 0;
		currentSectionEnd = 0;
		
		StrainPeaks = {};
		
		KeyCount = KeyCount;

        Process = function(self, current, index)
            if current == nil then
                warn("BREAKPOINT")
            end
            
            if current:Index() == 1 or current:Index() == 0 then
                self.currentSectionEnd = math.ceil(current:StartTime() / 400) * 400
            end
            
            while current:StartTime() > self.currentSectionEnd do
                self:SavePeaks()
                
                self:StartNewSectionFrom(self.currentSectionEnd, current)
                self.currentSectionEnd += 400
            end
            
            self.currentSectionPeak = math.max(self:StrainValueAt(current), self.currentSectionPeak)
        end,
        
        DifficultyValue = function(self)
            local difficulty = 0
            local weight = 1
            
            local peaks = {}
            for i, peak in self:GetCurrentStrainPeaks() do
                if peak > 0 then
                    table.insert(peaks, peak)
                end
            end
            
            table.sort(peaks, function(a,b) return a > b end)
            
            for i, peak in peaks do
                difficulty += (peak * weight)
                weight *= self.DecayWeight
            end
            
            return difficulty
        end,
        
        GetCurrentStrainPeaks = function(self)
            self:SavePeaks()
            return ipairs(self.StrainPeaks)
        end,
        
        SavePeaks = function(self)
            table.insert(self.StrainPeaks, self.currentSectionPeak)
        end,
        
        StartNewSectionFrom = function(self, offset, current)
            self.currentSectionPeak = self:CalculateInitialStrain(offset, current)
        end,
        
        StrainValueAt = function(self, current)
            local deltaTime = current:DeltaTime()
            if deltaTime == nil then
                warn"BREAKPOINT"
            end
            
            self.currentStrain *= math.pow(1, deltaTime / 1000) 
            self.currentStrain += self:StrainValueOf(current)
            
            return self.currentStrain
        end,
        
        StrainValueOf = function(self, current)
            local endTime = current:EndTime()
            local lane = current:BaseHitObject().Lane
            local Previous = current:LastHitObject();
            local closedEndTime = math.abs(endTime - Previous.StartTime)
            
            local holdFactor = 1.0
            local holdAddition = 0
            local isOverlapping = false
            
            for i=1, self.KeyCount do
                isOverlapping = DefinitelyBigger(self.m_HoldEndTimes[i], current:StartTime(), 1) and DefinitelyBigger(endTime, self.m_HoldEndTimes[i], 1)
                
                if DefinitelyBigger(self.m_HoldEndTimes[i], endTime, 1) then
                    holdFactor = 1.25
                end
                
                closedEndTime = math.min(closedEndTime, math.abs(endTime, self.m_HoldEndTimes[i]))
                
                self.m_individualStrains[i] = ApplyDecay(self.m_individualStrains[i], current:DeltaTime(), self.CONST_INDIVIDUAL_DECAY_BASE)
            end
            
            self.m_HoldEndTimes[lane] = endTime
            
            if isOverlapping then
                holdAddition = 1 / (1 + math.exp(0.5 * (self.CONST_RELEASE_THRESHOLD - closedEndTime)))
            end
            
            self.m_individualStrains[lane] += 2.0 * holdFactor
            self.individualStrain = self.m_individualStrains[lane]
            
            self.overallStrain = ApplyDecay(self.overallStrain, current:DeltaTime(), self.CONST_OVERALL_DECAY_BASE) + (1 + holdAddition) * holdFactor
            
            return self.individualStrain + self.overallStrain - self.currentStrain
        end,
        
        CalculateInitialStrain = function(self, offset, current)
            return ApplyDecay(self.individualStrain, offset - current:Previous(0):StartTime(), self.CONST_INDIVIDUAL_DECAY_BASE)
                + ApplyDecay(self.overallStrain, offset - current:Previous(0):StartTime(), self.CONST_OVERALL_DECAY_BASE)
        end,
    }
end

local DifficultyHitObject = function(hitObject: any, previous, clockRate, index)
    return {
        _Objects = {};
		_Index = index;
		_BaseHitObject = hitObject;
		_Previous = previous;
		
		_StartTime = hitObject.StartTime / clockRate;
		_EndTime = (if hitObject.Type == 2 then hitObject.EndTime else hitObject.StartTime) / clockRate;
		_DeltaTime = (hitObject.StartTime - previous.StartTime) / clockRate;

        Index = function(self)
            return self._Index
        end,
        
        StartTime = function(self)
            return self._StartTime
        end,
        
        EndTime = function(self)
            return self._EndTime
        end,
        
        BaseHitObject = function(self)
            return self._BaseHitObject
        end,
        
        LastHitObject = function(self)
            return self._Previous
        end,
        
        DeltaTime = function(self)
            return self._DeltaTime
        end,
        
        Previous = function(self, backwardsIndex)
            return self._Objects[self:Index() - (1 + backwardsIndex)]
        end,
        
        SetArrayObjects = function(self, _tbl)
            self._Objects = _tbl
        end,
        
        Get = function(self, index)
            return self._Objects[index]
        end,
    }
end

return function(HitObjects: any, KeyCount: number)
    return {
        _KeyCount = KeyCount,
        _HitObjects = HitObjects,

        ComputeDifficulty = function(self, mods, rate)
            local skills = self:CreateSkills()
            
            if #self._HitObjects == 0 then
                return { SR = 0, Mods = mods }
            end
            
            local DifficultyHitObjects = self:CreateDifficultyHitObjects(rate)
            for i, note in pairs(DifficultyHitObjects) do
                for i2, skill in pairs(skills) do
                    skill:Process(note, i)
                end
            end
            
            return {
                SR = skills[1]:DifficultyValue() * 0.018,
                Mods = mods
            }
        end,
        
        CreateDifficultyHitObjects = function(self, clockRate)
            table.sort(self._HitObjects, function(a, b)
                return a.StartTime < b.StartTime
            end)
            
            local result = {}
            for i=2, #self._HitObjects do
                table.insert(result, DifficultyHitObject(self._HitObjects[i], self._HitObjects[i-1], clockRate, #result + 1))
            end
            
            for i=1, #result do
                result[i]:SetArrayObjects(result)
            end
            
            return result
        end,
        
        CreateSkills = function(self)
            return { Strain(self._KeyCount) }
        end,
    }
end