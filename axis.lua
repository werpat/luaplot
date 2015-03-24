--[[
--  Copyright (c) 2015 Patrick Werneck
-- 
--  See the file LICENSE for copying permission.
--]]

local hpdf = require "hpdf"
local utils = require "utils"
local scale = require "scale"


local axis = {}
axis.__index = axis

function axis.create(graph, args)
	local self = setmetatable({}, axis)
	self.graph = graph
	graph:addAxis(self)

	for k,v in pairs(args) do
		self[k] = v
	end

	if type(self.position) ~= "string" or self.position ~= "north" or self.position ~= "east" or self.position ~= "south" or self.position ~= "west" then
		self.position = args.position or "south"
	end
	
	if type(self.fontSize) ~= "number" then
		self.fontSize = 10
	end

	if type(self.labelMargin) ~= "number" then
		self.labelMargin = self.fontSize * 2 / 3
	end

	self.align = utils.parseAlign(self.align, "HPDF_TALIGN_CENTER")

	if type(self.tiks) ~= "number" then
		self.tiks = 4
	end

	if type(self.tikLength) ~= "number" then
		self.tikLength = 4
	end

	if type(self.grid) ~= "string" then
		self.grid = "dotted"
	end

	if type(self.lineWidth) ~= "number" then
		self.lineWidth = 0.4
	end

	self.autoMin = false
	if type(self.min) ~= "number" then
		self.min = math.huge
		self.autoMin = true
	end

	self.autoMax = false
	if type(self.max) ~= "number" then
		print("max not given")
		self.max = -math.huge
		self.autoMax = true
	end
	self.scale = scale.create(self.min, self.max)
	
	return self
end

--
-- Must be called for all series using this axis before using axis:scale()
-- otherwise values are scaled wrong
--
function axis:update(min, max)
	if self.autoMax then
		self.max = math.max(self.max, max)
		self.scale:setInDomain(self.max)
	end
	if self.autoMin then
		self.min = math.min(self.min, min)
		self.scale:setMin(self.min)
	end		
end

function axis:getScale()
	return self.scale
end

function axis:tickLabel(tik)
	-- TODO: shorten long decimals
	return tostring(self.min + tik * (self.max - self.min) / (self.tiks - 1)):sub(0,5)
end

function axis:calcOffsets(page, font, width, height, offsets)
	local max, labelLen = 0, utils.measureText(page, font, self.fontSize, self.label)

	if self.position == "north" or self.position == "south" then
		offsets[self.position] = math.max(offsets[self.position], self.fontSize +  math.ceil(labelLen / width) * self.fontSize + 2 * self.labelMargin)
		-- tik 0 and max are fontSize/2 longer than the axis, but if there is a label or tik on the axis perpendicular to this, there is no problem
		offsets["west"] = math.max(offsets["west"], self.fontSize / 2)
		offsets["east"] = math.max(offsets["east"], self.fontSize / 2)
	else
		local longestTikLabel
		for tik=1, self.tiks, 1 do
			local tikLabel = self:tickLabel(tik)
			local tikLen = tikLabel:len()
			longestTikLabel = (max < tikLen) and tikLabel or longestTikLabel
			max = (max < tikLen) and tikLen or max
		end
		tikLen = utils.measureText(page, font, self.fontSize, longestTikLabel)
		offsets[self.position] = math.max(offsets[self.position], tikLen + math.ceil(labelLen / height) * self.fontSize + 2 * self.labelMargin)
		offsets["north"] = math.max(offsets["north"], self.fontSize / 2)
		offsets["south"] = math.max(offsets["south"], self.fontSize / 2)
	end
end


function axis:drawTick(page, x, y)
	hpdf.Page_GSave(page)
	hpdf.Page_SetLineWidth(page, self.lineWidth)
	hpdf.Page_SetRGBStroke(page, 0.4, 0.4, 0.4)
	hpdf.Page_MoveTo(page, x, y)
	hpdf.Page_LineTo(page, x, y + self.tikLength)
	hpdf.Page_Stroke(page)
	hpdf.Page_GRestore(page)
end

function axis:draw(pdf, page, font)

	if self.hidden then
		return
	end

	local offsets = self.graph.offsets
	local height = hpdf.Page_GetHeight(page)
	local width = hpdf.Page_GetWidth(page)
	local axisLength = width - offsets.east - offsets.west
	local helperLength = height - offsets.north - offsets.south
	local direction = 1
	local text = nil
	local labelOffset = 0
	local pageOffset = 0

	--
	-- x, y: specifies the position of the draw matrix for the tiks and its label
	-- lx, ly: specifies the position of the draw matrix for the labels
	--
	local x, y, lx, ly = nil, nil, nil, nil

	-- TextMatrixes cannot be set outside of a text-block -> save it in a stack like table
	local matrixStack = {}

	
	hpdf.Page_GSave(page)
	if self.position == "north" then
		hpdf.Page_Concat(page, -1, 0, 0, -1, width - offsets.east, height - offsets.north)
		table.insert(matrixStack, { 1, 0, 0,  1, 0, 0})
		table.insert(matrixStack, {-1, 0, 0, -1, 0, 0})
		pageOffset = offsets.north
		x = function(tikX, len) 
			if tikX > 0 and tikX < axisLength then
				return axisLength - tikX + len / 2
			elseif tikX == 0 then
				return axisLength + self.fontSize / 3
			else
				return len - self.fontSize / 3
			end
		end
		y = function(tikX, len) return -self.fontSize / 3 end
		lx = function(labelOffset) return offsets.west end
		ly = function(labelOffset, txl) return height - offsets.north + (txl + 1) * self.fontSize + self.labelMargin end
	elseif self.position == "south" then
		hpdf.Page_Concat(page, 1, 0, 0, 1, offsets.west, offsets.south) 	
		table.insert(matrixStack, {1, 0, 0, 1, 0, 0})
		table.insert(matrixStack, {1, 0, 0, 1, 0, 0})
		pageOffset = offsets.south
		x = function(tikX, len) 
			if tikX > 0 and tikX < axisLength then
				return tikX - len / 2
			elseif tikX == 0 then
				return -self.fontSize / 3
			else
				return tikX - len + self.fontSize / 3
			end
		end
		y = function(tikX, len) return -self.fontSize end
		lx = function(labelOffset) return  offsets.west end
		ly = function(labelOffset) return offsets.south - self.fontSize - self.labelMargin end
	elseif self.position == "east" then
		hpdf.Page_Concat(page, 0, 1, -1, 0, width - offsets.east, offsets.south)
		table.insert(matrixStack, {0,  1, -1, 0, 0, 0})
		table.insert(matrixStack, {0, -1,  1, 0, 0, 0})
		axisLength, helperLength = helperLength, axisLength
		pageOffset = offsets.east
		x = function(tikX, len) return tikX - self.fontSize / 3 end
		y = function(tikX, len) return -self.fontSize / 3 end
		lx = function(labelOffset) return width - offsets.east + labelOffset + self.labelMargin + self.fontSize / 3 end
		ly = function(labelOffset) return offsets.south end
	else
		hpdf.Page_Concat(page, 0, -1, 1, 0, offsets.west, height - offsets.north)
		table.insert(matrixStack, {0, 1, -1, 0, 0, 0})
		table.insert(matrixStack, {0, 1, -1, 0, 0, 0})
		axisLength, helperLength = helperLength, axisLength
		pageOffset = offsets.west
		x = function(tikX, len) return axisLength - tikX + self.fontSize / 3 end
		y = function(tikX, len) return -(len + self.fontSize / 3) end
		lx = function(labelOffset, txl) return offsets.west - labelOffset - txl * self.fontSize - self.labelMargin - self.fontSize / 3 end
		ly = function(labelOffset) return offsets.south end
	end

	-- TODO: set manual tiks

	-- start drawing tiks and tikLabels
	local textMatrix = table.remove(matrixStack)
	for tik = 0, self.tiks - 1, 1 do
		local tikX = 0
		if self.tiks ~= 1 then
			tikX = tik * axisLength / (self.tiks - 1)
		end

		if not (tik == self.tiks - 1 and self.skipLast) then
			hpdf.Page_BeginText(page)
			hpdf.Page_SetTextMatrix(page, unpack(textMatrix)) 
			hpdf.Page_SetFontAndSize(page, font, self.fontSize)
			text = self:tickLabel(tik)
			local textLen = hpdf.Page_TextWidth(page, text)
			if textLen > labelOffset then
				labelOffset = textLen
			end
			hpdf.Page_TextOut(page, x(tikX, textLen), y(tikX, textLen), text)	
			hpdf.Page_EndText(page)
		end
		if tik > 0 and tik < self.tiks - 1 then
			hpdf.Page_GSave(page)
			hpdf.Page_SetRGBStroke(page, 0.4, 0.4, 0.4)
			if self.grid == "dotted" then
				utils.drawDottedLine(page, tikX, 0, tikX, helperLength, self.lineWidth)
			elseif self.grid == "dashed" then
				utils.drawDashedLine(page, tikX, 0, tikX, helperLength, self.lineWidth)
			end
			hpdf.Page_SetRGBStroke(page, 0, 0, 0)
			self:drawTick(page, tikX, 0)
			self:drawTick(page, tikX, helperLength - self.tikLength)
			hpdf.Page_GRestore(page)
		end
	end
	-- draw Axis
	utils.drawLine(page, 0, 0, axisLength, 0, self.lineWidth)

	-- Restore original draw matrix and save it
	hpdf.Page_GRestore(page)
	hpdf.Page_GSave(page)

	local txl = utils.measureText(page, font, self.fontSize, self.label)
	txl = math.ceil(txl / axisLength)

	local a,b,c,d = unpack(table.remove(matrixStack))
	hpdf.Page_Concat(page, a, b, c, d, lx(labelOffset, txl), ly(labelOffset, txl))
	
	--draw axisLabel
	hpdf.Page_BeginText(page)
	hpdf.Page_SetFontAndSize(page, font, self.fontSize)
	hpdf.Page_TextRect(page, 0, 0, axisLength, -txl * self.fontSize, self.label, self.align)
	hpdf.Page_EndText(page)

	-- Restore original draw matrix 
	hpdf.Page_GRestore(page)
end

return axis
