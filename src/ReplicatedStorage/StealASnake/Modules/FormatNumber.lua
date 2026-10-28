--!strict
local FormatNumber = {}

local suffixes = {
	{ 1e12, "T" },
	{ 1e9, "B" },
	{ 1e6, "M" },
	{ 1e3, "K" },
}

function FormatNumber.short(n: number): string
	local sign = if n < 0 then "-" else ""
	n = math.abs(n)
	for _, s in suffixes do
		if n >= s[1] then
			return string.format("%s%.1f%s", sign, n / s[1], s[2])
		end
	end
	if n >= 100 or n == math.floor(n) then
		return sign .. tostring(math.floor(n + 0.5))
	end
	return string.format("%s%.1f", sign, n)
end

return FormatNumber
