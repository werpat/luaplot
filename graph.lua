--[[
--  Copyright (c) 2015 Patrick Werneck
-- 
--  See the file LICENSE for copying permission.
--]]

local utils = require "utils"
local hpdf = require "hpdf"
local axis = require "axis"
local series = require "series"
local legend = require "legend"

local graph = {}
graph.__index = graph

local marks = {"asterix", "plus", "cross", "diamond", "square", "circle", "triangle", "rtriangle"}
local colors = {
	{1, 	0, 		0},		--red
	{0, 	0.8, 	0},		--green
	{0.071,	0.251, 	0.671},	--blue
	{1,		0.667,	0},		--orange
	{0.608,	0,		0},		--darkred
	{0,		0.486,	0},		--darkgreen
	{0.031,	0.137,	0.408},	--darkblue
	{0.608, 0.408, 	0}		--darkorange
}

function graph.create(args)
	local self = setmetatable({}, graph)

	for k, v in pairs(args) do
		self[k] = v
	end

	if type(self.series) ~= "table" then
		self.series = {}
	end

	if type(self.axes) ~= "table" then
		self.axes = {}
	end

	if type(self.legend) ~= "table" then
		self.legends = {}
	end

	if type(self.frame) ~= "boolean" then
		self.frame = true
	end

	self.markIndex = 0
	self.colorIndex = 0

	return self
end

function graph:addAxis(axis)
	table.insert(self.axes, axis)
	return self
end

function graph:addSeries(series)
	table.insert(self.series, series)
	return self
end

function graph:getSeries()
	return self.series
end

function graph:addLegend(legend)
	table.insert(self.legends, legend)
	return self
end

function graph:addOffset(offset)
	self.drawOffset.north = self.drawOffset.north + offset.north
	self.drawOffset.east = self.drawOffset.east + offset.east
	self.drawOffset.south = self.drawOffset.south + offset.south
	self.drawOffset.west = self.drawOffset.west + offset.west
end

function graph:requestColor()
	local color = colors[self.colorIndex + 1]
	self.colorIndex = (self.colorIndex + 1) % #colors
	return color
end

function graph:requestMark()
	local mark = marks[self.markIndex + 1]
	self.markIndex = (self.markIndex + 1) % #marks
	return mark
end

function graph:requestMarkAndColor()
	return self:requestMark(), self:requestColor()
end

--
-- @width: approximal width in mm of resulting graph
-- @height: approximal height in mm of resulting graph
-- @filename: path to file where the resulting pdf should be written to
--
function graph:plot(filename, width, height, fontfile1, fontfile2)

	local minX, maxX = self.minX, self.maxX
	local pdf = hpdf.New()
    local page = hpdf.AddPage(pdf)
	local font = utils.loadFont(pdf, fontfile1, fontfile2)
    width = math.floor(width * 72 / 25.4)
	height = math.floor(height * 72 / 25.4)

	if type(self.offsets) ~= "table" then
		self.offsets = {north = 2, east = 2, south = 2, west = 2}
		for _, axis in pairs(self.axes) do
			axis:calcOffsets(page, font, width, height, self.offsets)
		end
	end
	
	hpdf.Page_SetHeight(page, height + self.offsets.south + self.offsets.north)
	hpdf.Page_SetWidth(page, width + self.offsets.west + self.offsets.east)

	hpdf.Page_SetRGBStroke(page, 0, 0, 0)
	hpdf.Page_SetLineWidth(page, 0.4)


	-- draw frame
	if self.frame then
		hpdf.Page_Rectangle(page, 
			self.offsets.west, 
			self.offsets.south, 
			width, 
			height)
		hpdf.Page_Stroke(page)
	end

	hpdf.Page_GSave(page)
	hpdf.Page_Concat(page, 1, 0, 0, 1, self.offsets.west, self.offsets.south)
	local sret = {}
	for _, series in pairs(self.series) do
		sret = series:draw(pdf, page, width, height, sret)
	end
	hpdf.Page_GRestore(page)


	for _, axis in pairs(self.axes) do
		axis:draw(pdf, page, font)
	end

	hpdf.Page_GSave(page)
	hpdf.Page_Concat(page, 1, 0, 0, 1, self.offsets.west, self.offsets.south)
	for _, legend in pairs(self.legends) do
		legend:draw(pdf, page, font, width, height)
	end
	hpdf.Page_GRestore(page)
		
	hpdf.SaveToFile(pdf, filename)
    hpdf.Free(pdf)
end
		
return graph


