--[[
--  Copyright (c) 2015 Patrick Werneck
-- 
--  See the file LICENSE for copying permission.
--]]

local scale = {}
scale.__index = scale

-- scale() creates (0,1) -> (0,1) domain
-- scale(a,b) creates (a,b) -> (0,1) domain
-- scale(a,b,c,d) creates (a,b) -> (c,d) domain
--
-- a,b resp. c,d can be packed to {lower=a, upper=b}

function scale.create(imin, imax, omin, omax)
	local self = setmetatable({}, scale)
	if type(imin) == "table" then
		self.inDomain = imin
		omin, omax = imax, omin
	elseif type(imin) ~= "number" or type(imax) ~= "number" then
		self:setInDomain(0, 1)
	else
		self:setInDomain(imin, imax)
	end

	if type(omin) == "table" then
		self.outDomain = omin
	elseif type(omin) ~= "number" or type(omax) ~= "number" then
		self:setOutDomain(0, 1)
	else
		self:setOutDomain(omin, omax)
	end
	return self
end

function scale:setInDomain(a, b)
	self.inDomain = {lower = a, upper = b}
end

function scale:setOutDomain(a, b)
	self.outDomain = {lower = a, upper = b}
end

function scale:scale(value)
	local id, od = self.inDomain, self.outDomain
	return (value - id.lower) / (id.upper - id.lower) * (od.upper - od.lower) + od.lower
end

function scale:unscale(scaled)
	local id, od = self.inDomain, self.outDomain
	return (scaled - od.lower) / (od.upper - od.lower) * (id.upper - id.lower) + id.lower
end

function scale:add(a, b)
	return self:scale(self:unscale(a) + self:unscale(b))
end

function scale:sub(a, b)
	return self:scale(self:unscale(a) - self:unscale(b))
end

function scale:mul(a, b)
	return self:scale(self:unscale(a) * self:unscale(b))
end

function scale:div(a, b)
	return self:scale(self:unscale(a) / self:unscale(b))
end


--[[
function axis:nice()
	-- TODO: implement
	error("not implemented")
	local strMin = tostring(min):match("%d+")
	local strMax = tostring(max):match("%d+")
	min = min - (min % 10 ^ ( tostring(min):len() - 2))
    max = max + (10 ^ ( tostring(max):len() - 2) - max % 10 ^ ( tostring(max):len() - 2))
end
]]--


return scale
