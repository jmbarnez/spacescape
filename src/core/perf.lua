local perf = {}

local simSeconds = 0
local simStepsThisSecond = 0
local simUps = 0
local simStepsLastFrame = 0

function perf.beginFrame()
	simStepsLastFrame = 0
end

function perf.onSimStep()
	simStepsLastFrame = simStepsLastFrame + 1
	simStepsThisSecond = simStepsThisSecond + 1
end

function perf.update(dt)
	simSeconds = simSeconds + (dt or 0)
	if simSeconds >= 1 then
		simUps = simStepsThisSecond / simSeconds
		simSeconds = 0
		simStepsThisSecond = 0
	end
end

function perf.getSimUps()
	return simUps
end

function perf.getSimStepsLastFrame()
	return simStepsLastFrame
end

return perf
