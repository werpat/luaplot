--[[
--  Copyright (c) 2015 Patrick Werneck
-- 
--  See the file LICENSE for copying permission.
--]]

local hpdf = require "hpdf"

local legend = {}
legend.__index = legend

function legend.create(graph, args)
	local self = setmetatable({}, legend)
	self.graph = graph
	graph:addLegend(self)

	for k, v in pairs(args) do
		self[k] = v
	end

	return self
end

function legend:bestLabelPosition()
	-- TODO find good label position
	return margin, margin
end

function legend:draw(pdf, page, font, width, height)
	local margin, padding = 5, 5
	local series = self.graph:getSeries()
	local maxWidth = 100
	
	local usedWidth, usedHeight = 0, 0
	for _, s in pairs(series) do
		local w, h = s:measureLabelDimension(page, font, maxWidth)
		usedWidth, usedHeight = math.max(w, usedWidth), usedHeight + h
	end

	if type(self.position) ~= "string" or self.position == "auto" then
		x,y = self:bestLabelPosition()

	elseif self.position == "north" then
		x, y = (width - usedWidth) / 2 - padding, height - usedHeight - margin - 2 * padding

	elseif self.position == "north east" then
		x, y = width - usedWidth - margin - 2 * padding, height - usedHeight - margin - 2 * padding

	elseif self.position == "east" then
		x, y = width - usedWidth - margin - 2 * padding, (height - usedHeight) / 2 - padding

	elseif self.position == "south east" then
		x, y = width - usedWidth - margin - 2 * padding, margin

	elseif self.position == "south" then
		x, y = (width - usedWidth) / 2 - padding, margin

	elseif self.position == "west" then
		x, y = margin, (height - usedHeight) / 2 - padding

	elseif self.position == "south west" then
		x, y = margin, margin

	else --north west
		x, y = margin, height - usedHeight - margin - 2 * padding

	end
	
	hpdf.Page_GSave(page)
	hpdf.Page_SetRGBFill(page, 1, 1, 1)
	hpdf.Page_SetRGBStroke(page, 0, 0, 0)
	hpdf.Page_Rectangle(page, x, y, usedWidth + 2*padding, usedHeight + 2*padding)
	hpdf.Page_FillStroke(page)
	hpdf.Page_GRestore(page)

	
	local lx, ly = x + padding, y + padding
	for _, s in pairs(series) do
		local w, h = s:drawLabel(page, font, lx, ly, maxWidth)
		ly = ly + h
	end

end

return legend
