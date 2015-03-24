--[[
--  Copyright (c) 2015 Patrick Werneck
-- 
--  See the file LICENSE for copying permission.
--]]

local hpdf = require "hpdf"
local utils = require "utils"

local series = {}
series.__index = series

function series.create(graph, xaxis, yaxis, args)
	local self = setmetatable({}, series)
	self.graph = graph
	graph:addSeries(self)
	self.xScale = xaxis:getScale()
	self.yScale = yaxis:getScale()

	for k, v in pairs(args) do
		self[k] = v
	end

	if type(self.data) == "table" then
		self:parseData(self.data)
	else
		self.data = {}
	end

	if type(self.color) == "string" then
		self.color = utils.parseColor(self.color)
	else
		self.color = graph:requestColor()
	end

	if type(self.mark) ~= "string" then
		self.mark = graph:requestMark()
	end

	self.labelAlign = utils.parseAlign(self.labelAlign, "HPDF_TALIGN_LEFT")
	self.fontSize = self.fontSize or 10
	self.boxLineWidth = self.boxLineWidth or self.lineWidth
	self.whiskerLineWidth = self.whiskerLineWidth or self.lineWidth
	
	return self
end

--
-- @data: order of xi's is irrelevant
--
-- set data in internal data format
-- x and avg needed if not specified differently by an option
-- sorted by x
--
-- @result: self.data is updated and xi < xi+1 is always satisfied
--          self.min, self.max are set
--
-- data = {
-- 	 {x = x1, avg=, min=, max=, lowerQ=, median=, upperQ=, stdDev=},
-- 	 {x = x2, ...},
--   ...
-- 	 {x = xn, ...},
-- }
--
function series:setData(data, min, max)
	self.data = data
	table.sort(self.data, function(e1, e2) return e1.x < e2.x end)
	self.min = { x = self.data[1].x, 			y = nil}
	self.max = { x = self.data[#self.data].x,	y = nil}

	if type(min) ~= "number" or type(max) ~= "number" then
		min, max = math.huge, -math.huge
		for k, v in pairs(data) do
			min, max = math.min(min, v.min), math.max(max, v.max)
		end
	end
	self.min.y = min
	self.max.y = max
end

-- @data: input data to be parsed.
--        must be a table of the format
--        the order or the xi's is irrelevant
-- data = { 
--    [x1] = {y11, y12, ..., y1n}, 
--    [x2] = {y21, y22, ..., y2n}
--    ...
--    [xn] = {yn1, yn2m ..., ynn}
--  }
function series:parseData(data)
	local numSamples = 0
	local avg = 0
	local stdDev = 0
	local median = 0
	local sortedVals = nil
	local min, max

	local parsedData = {}
    for x, vals in pairs(data) do
		min, max = math.huge, -math.huge
		avg, stdDev, numSamples = 0, 0, 0
		sortedVals = {}
		for _, sample in pairs(vals) do
			min, max = math.min(min, sample), math.max(max, sample)
			table.insert(sortedVals, sample)
			avg = avg + sample
			numSamples = numSamples + 1
		end
		table.sort(sortedVals)
		avg = avg / numSamples
		for _, sample in pairs(vals) do
			stdDev = stdDev + (sample - avg) ^ 2
		end
		stdDev = math.sqrt(stdDev / numSamples)
		if numSamples % 2  == 0 then
			median = (sortedVals[numSamples / 2] + sortedVals[numSamples / 2 + 1]) / 2
        else
            median = sortedVals[(numSamples + 1) / 2]
        end		

        table.insert(parsedData, { 
			x = x, 
			avg = avg, 
			min = min, 
			max = max, 
			lowerQ = sortedVals[math.floor((numSamples + 1) * 0.25 + 0.5)],
			median = median,
			upperQ = sortedVals[math.floor((numSamples + 1) * 0.75 + 0.5)],
			stdDev = stdDev
		})
    end
	self:setData(parsedData)
end


function series:whiskerPlot(pdf, page)
	local xScale, yScale = self.xScale, self.yScale

	for _, sample in ipairs(self.data) do
		local x, y = xScale:scale(sample.x), yScale:scale(sample.median)
		local lAnt, uAnt =  yScale:scale(sample.avg - sample.stdDev), yScale:scale(sample.avg + sample.stdDev)
		utils.whisker(pdf, page, x, y, lAnt, y, uAnt, self.tLen, self.lineWidth)
	end
end

function series:boxPlot(pdf, page)
	local xScale, yScale = self.xScale, self.yScale

	for _, sample in ipairs(self.data) do
		local x, y = xScale:scale(sample.x), yScale:scale(sample.median)
		local lAnt, uAnt =  yScale:scale(sample.avg - sample.stdDev), yScale:scale(sample.avg + sample.stdDev)
		local lQ, uQ = yScale:scale(sample.lowerQ), yScale:scale(sample.upperQ)
		utils.boxPlot(pdf, page, x, y,lQ, uQ, lAnt, uAnt, self.boxWidth, not self.noBoxMid,  self.tLen, self.lineWidth)
	end
end

function series:linePlot(pdf, page)
	local xScale, yScale = self.xScale, self.yScale
	local lastX, lastY

	hpdf.Page_GSave(page)
	hpdf.Page_SetLineWidth(page, self.lineWidth or 0.4)

	if type(self.startAt) == "table" then
		hpdf.Page_MoveTo(page, xScale:scale(self.startAt.x), yScale:scale(self.startAt.y))
	else
		hpdf.Page_MoveTo(page, xScale:scale(self.data[1].x), yScale:scale(self.data[1].median))
	end
    for _, sample in ipairs(self.data) do
		local x, y = xScale:scale(sample.x), yScale:scale(sample.median)
		hpdf.Page_LineTo(page, x, y)
     end
	 hpdf.Page_Stroke(page)
	 hpdf.Page_GRestore(page)
end

function series:markPlot(pdf, page)
	local xScale, yScale = self.xScale, self.yScale
	local warned = false

	for _, sample in ipairs(self.data) do
		local x, y = xScale:scale(sample.x), yScale:scale(sample.median)
		if not utils.drawMark(page, self.mark, x, y, self.markSize) and not warned then
			utils.warn(string.format("Unknown mark %s", self.mark))
			warned = true
		end
	end
end

function series:draw(pdf, page, width, height, stacked)
	local xScale, yScale = self.xScale, self.yScale


	hpdf.Page_GSave(page)
	hpdf.Page_SetRGBStroke(page, unpack(self.color))
	hpdf.Page_SetRGBFill(page, unpack(self.color))

	xScale:setOutDomain(0, width)
	yScale:setOutDomain(0, height)

	if self.whiskers then
		self:whiskerPlot(pdf, page)
	end

	if self.boxes then
		self:boxPlot(pdf, page)
	end

	if self.line ~= "none" then
		self:linePlot(pdf, page)
	end

	if not self.marks then
		self:markPlot(pdf, page, mark)
	end

	hpdf.Page_GRestore(page)
end

function series:drawStacked(page, offset)
	-- TODO
end

local labelLineLength, labelMargin = 15, 5
function series:drawLabel(page, font, x, y, maxWidth)
	if type(self.label) ~= "string" or self.label == "none" then
		return 0, 0
	end
	
	local width = utils.measureText(page, font, self.fontSize, self.label)
	local lines = math.ceil(width / (maxWidth - labelLineLength - labelMargin))
	local labelHeight = lines * self.fontSize

	hpdf.Page_GSave(page)
	hpdf.Page_SetRGBStroke(page, unpack(self.color))
	hpdf.Page_SetRGBFill(page, unpack(self.color))

	utils.drawLine(page, x, y + labelHeight / 2, x + labelLineLength, y + labelHeight / 2)
	utils.drawMark(page, self.mark, x + labelLineLength / 2, y + labelHeight / 2, self.markSize)

	hpdf.Page_SetRGBFill(page, 0, 0, 0)
	hpdf.Page_SetRGBStroke(page, 0, 0, 0)
	hpdf.Page_BeginText(page)
	hpdf.Page_TextRect(page, x + labelLineLength + labelMargin, y + labelHeight, x + maxWidth, y, self.label, self.labelAlign)
	hpdf.Page_EndText(page)

	hpdf.Page_GRestore(page)
	
	width = lines > 1 and maxWidth or width + labelLineLength + labelMargin
	return width, labelHeight
end

function series:measureLabelDimension(page, font, maxWidth)
	if type(self.label) ~= "string" or self.label == "none" then
		return 0, 0
	end

	local width, height = utils.measureText(page, font, self.fontSize, self.label), self.fontSize
	if width > maxWidth then
		height = math.ceil(width / (maxWidth - labelLineLength - labelMargin)) * self.fontSize
		width = maxWidth 
	end

	return width + labelLineLength + labelMargin, height
end

return series	
