--[[
--  Copyright (c) 2015 Patrick Werneck
-- 
--  See the file LICENSE for copying permission.
--]]

local graph = require "graph"
local axis = require "axis"
local series = require "series"
local legend = require "legend"

local utils = require "utils"

local g = graph.create({})
local xaxis1 = axis.create(g, {
	min=0, max=1536, 
	label="imaginary thing A", 
	position="south", skipLast = true, grid="dashed"
})
local xaxis2 = axis.create(g, {
	min=10, max=20, 
	label="imaginary thing B", 
	position="north", grid="none"
})
local yaxis1 = axis.create(g, {
	min=64, max=256, 
	label="interesting property 1 [unit]", 
	position="west", grid="none"
})
local yaxis2 = axis.create(g, {
	min=0, max=0.2, tiks=5,
	label="interesting property 2 or maybe its not so interesting", 
	position="east", grid="dotted"
})


local s1 = series.create(g, xaxis1, yaxis1, {
	data = utils.genRandomSeries(20, 1516, 20, 64, 256, 100),
	boxes=true, boxWidth=2, startAt={x=0,y=80}, label="series 1 label", line="none", mark="none"
})

local s2 = series.create(g, xaxis1, yaxis2, {
	data=utils.genNormalDistributedSeries(256, 768, 0, 1536, 150, 100), 
	lines = true, label="series 2 label"
})

local s3 = series.create(g, xaxis2, yaxis1, {
	data=utils.genSmoothSeries(10, 20, 150, 64, 256), 
	lines = true, label="series 3 label"
})

local l = legend.create(g, {position = "south"})

g:plot("boxplot.pdf", 80, 60, "fonts/cmr10.ttf")

