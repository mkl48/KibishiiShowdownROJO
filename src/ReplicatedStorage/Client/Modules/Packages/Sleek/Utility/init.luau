local Utility = {}

Utility.attributeKeys = {
	Variant = true,
	Elevation = true,
	TextRole = true,
	FontWeight = true,
	TextSize = true,
	Roundness = true,
	Badge = true,
	Input = true,
	TintRole = true,
	IgnoreTheme = true,
	IgnorePrimaryColor = true,
}

Utility.uiLayoutTypes = {
	UIListLayout = true,
	UIGridLayout = true,
	UITableLayout = true,
	UIPageLayout = true,
	UIPadding = true,
	UICorner = true,
	UIStroke = true,
	UIGradient = true,
	UIScale = true,
	UIFlexItem = true,
	UISizeConstraint = true,
	UITextSizeConstraint = true,
	UIAspectRatioConstraint = true,
}

local chars = {
	"a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
	"A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
	"0","1","2","3","4","5","6","7","8","9",
}
local charCount = #chars
local rng = Random.new()

function Utility.generateUID(length : number?) : string
	length = length or 8
	local parts = table.create(length)
	for i = 1, length do
		parts[i] = chars[rng:NextInteger(1, charCount)]
	end
	return table.concat(parts)
end

function Utility.countTable(tbl : { [any]: any }) : number
	local count = 0
	for _ in tbl do count += 1 end
	return count
end

function Utility.shallowCopy(tbl : { [any]: any }) : { [any]: any }
	local copy = {}
	for k, v in tbl do copy[k] = v end
	return copy
end

function Utility.deepCopy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = (type(v) == "table") and Utility.deepCopy(v) or v
    end
    return copy
end

return Utility