local _, ns = ...
local Private = ns.pUF.Private

function Private.argcheck(value, num, ...)
	assert(type(num) == "number", "Bad argument #2 to 'argcheck' (number expected, got " .. type(num) .. ")")

	for i = 1, select("#", ...) do
		if (type(value) == select(i, ...)) then
			return
		end
	end

	local types = strjoin(", ", ...)
	local name = debugstack(2, 2, 0):match(": in function [`<](.-)['>]")
	error(string.format("Bad argument #%d to '%s' (%s expected, got %s)", num, name, types, type(value)), 3)
end

function Private.print(...)
	print("|cff33ff99pUF:|r", ...)
end

function Private.error(...)
	Private.print("|cffff0000Error:|r " .. string.format(...))
end

function Private.petExists(petOwner, petIndex)
	local customName, speciesName = C_PetBattles.GetName(petOwner, petIndex)

	return speciesName ~= nil
end
