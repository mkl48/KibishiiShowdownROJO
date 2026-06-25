task.defer(function()
	local RunService = game:GetService("RunService")
	local VERSION = require(script.Parent.VERSION)
	local appVersion = VERSION.getAppVersion()
	local latestVersion = VERSION.getLatestVersion()
	local isOutdated = not VERSION.isUpToDate()
	if not RunService:IsStudio() then
		print(`🍍 Running Sleek {appVersion} by @TheRealKr3ative`)
	end
	if isOutdated then
		warn(`A new version of Sleek ({latestVersion}) is available: [DevForum]`)
	end
end)

return {}