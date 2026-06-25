local MarketplaceService = game:GetService("MarketplaceService")
local VERSION = {}

VERSION.appVersion = "v0.1.0"
VERSION.latestVersion = nil :: string?

function VERSION.getLatestVersion(): string?
	local PlaceId = 139264398570518
	local latestVersion = VERSION.latestVersion
	if latestVersion then
		return latestVersion
	end
	local placeName = ""
	while true do
		local success, SleekProcessDetails = pcall(function()
			return MarketplaceService:GetProductInfoAsync(PlaceId)
		end)
		if success and SleekProcessDetails then
			placeName = SleekProcessDetails.Name
			break
		end
		task.wait(1)
	end
	latestVersion = string.match(placeName, "^Sleek (.*)$")
	if latestVersion then
		latestVersion = latestVersion:gsub("%s+", "")
	end
	VERSION.latestVersion = latestVersion
	return latestVersion
end

function VERSION.getAppVersion()
	return VERSION.appVersion
end

function VERSION.isUpToDate()
	local latestVersion = VERSION.getLatestVersion()
	local appVersion = VERSION.getAppVersion()
	return latestVersion ~= nil and latestVersion == appVersion
end



return VERSION