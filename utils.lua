--[[
--  Copyright (c) 2015 Patrick Werneck
-- 
--  See the file license.txt for copying permission.
--]]

local utils = {}
local hpdf = require "hpdf"


local defaultLineWidth = 0.4
local defaultBoxWidth = 5
local defaultWhiskerT = 2
local defaultWhiskerAlpha = 0.5
local defaultMarkSize = 2

function utils.loadFont(pdf, fn1, fn2)
	if type(fn1) ~= "string" then
		return hpdf.GetFont(pdf, "Helvetica")
	elseif fn1:match(".*%.afm") then
		return utils.loadType1Font(pdf, fn1, fn2)
	elseif fn1:match(".*%.ttf") then
		return utils.loadTrueTypeFont(pdf, fn1)
	else
		return hpdf.GetFont(pdf, fn1)
	end
end

function utils.loadType1Font(pdf, afm, pfb)
	local fontName = hpdf.LoadType1FontFromFile(pdf, afm, pfb)
	return hpdf.GetFont(pdf, fontName)
end

function utils.loadTrueTypeFont(pdf, ttf)
	local fontName = hpdf.LoadTTFontFromFile(pdf, ttf, "HPDF_TRUE")
	return hpdf.GetFont(pdf, fontName)
end

function utils.parseAlign(align, default)
	if align == "left" then
		return "HPDF_TALIGN_LEFT"
	elseif align == "right" then
		return "HPDF_TALIGN_RIGHT"
	elseif align == "justify" then
		return "HPDF_TALIGN_JUSTIFY"
	elseif align == "center" then
		return "HPDF_TALIGN_CENTER"
	else 
		return default
	end
end

function utils.measureText(page, font, fontSize, text)
	local res = 0
	hpdf.Page_BeginText(page)
	hpdf.Page_SetFontAndSize(page, font, fontSize)
	res = hpdf.Page_TextWidth(page, text)
	hpdf.Page_EndText(page)
	return res
end

function utils.drawLine(page, x, y, xto, yto, lineWidth)
	lineWidth = lineWidth or defaultLineWidth

	hpdf.Page_GSave(page)
	hpdf.Page_SetLineWidth(page, lineWidth)
	hpdf.Page_MoveTo(page, x, y)
	hpdf.Page_LineTo(page, xto, yto)
	hpdf.Page_Stroke(page)
	hpdf.Page_GRestore(page)
end

function utils.drawDottedLine(page, x, y, xto, yto, lineWidth)
	-- hpdf offers no dotted feature so emulate it
	local dist = 6 * lineWidth
	local distx, disty, dotx, doty = 0, 0, 0, 0
	local deltax, deltay = xto - x, yto - y
	local parts = 0
	lineWidth = lineWidth or defaultLineWidth

	if deltax == 0 then
		disty, doty, parts = dist, lineWidth, deltay / (dist + lineWidth)
	elseif deltay == 0 then
		distx, dotx, parts = dist, lineWidth, deltax / (dist + lineWidth)
	else
		local diag = math.sqrt(deltax ^ 2 + deltay ^ 2)
		parts = diag / (dist + lineWidth)
		distx, disty = deltax / diag * dist, deltay / diag * dist
		dotx, doty = deltax / diag * lineWidth, deltay / diag * lineWidth
	end

	hpdf.Page_GSave(page)
	hpdf.Page_SetLineWidth(page, lineWidth)
	local i, currx, curry = 0, x, y
	while i < parts do
		hpdf.Page_MoveTo(page, currx, curry)
		currx, curry = currx + dotx, curry + doty
		hpdf.Page_LineTo(page, currx, curry)
		hpdf.Page_Stroke(page)
		currx, curry = currx + distx, curry + disty
		i = i + 1
	end
	hpdf.Page_GRestore(page)
end

function utils.drawDashedLine(page, x, y, xto, yto, lineWidth)
	lineWidth = lineWidth or defaultLineWidth

	hpdf.Page_GSave(page)
	hpdf.Page_SetLineWidth(page, lineWidth)
	hpdf.Page_SetDash(page, {4, 5}, 2, 0)
	hpdf.Page_MoveTo(page, x, y)
	hpdf.Page_LineTo(page, xto, yto)
	hpdf.Page_Stroke(page)
	hpdf.Page_GRestore(page)
end

function utils.brighter(color)
	local r, g, b = unpack(color)
	return 0.5 * r + 0.5, 0.5 * g + 0.5, 0.5 * b + 0.5 
end

function utils.setTransparency(pdf, page, alpha)
	local gstate = hpdf.CreateExtGState(pdf)
	hpdf.ExtGState_SetAlphaFill(gstate, alpha)
	hpdf.ExtGState_SetAlphaStroke(gstate, alpha)
	hpdf.Page_SetExtGState(page, gstate)
end

function print_r (t, indent, done)
	done = done or {}
	indent = indent or ''
	local nextIndent -- Storage for next indentation value
	for key, value in pairs (t) do
		if type (value) == "table" and not done [value] then	
			nextIndent = nextIndent or (indent .. string.rep(' ',string.len(tostring (key))+2))
			-- Shortcut conditional allocation
			done [value] = true
			print (indent .. "[" .. tostring (key) .. "] => Table {");
			print  (nextIndent .. "{");
			print_r (value, nextIndent .. string.rep(' ',2), done)
			print  (nextIndent .. "}");
		else
			print  (indent .. "[" .. tostring (key) .. "] => " .. tostring (value).."")
		end
	end
end


function utils.whisker(pdf, page, x, yls, yle, yus, yue, tLen, lineWidth, alpha)
	alpha = alpha or defaultWhiskerAlpha
	tLen = tLen or defaultWhiskerT
	
	hpdf.Page_GSave(page)
	utils.setTransparency(pdf, page, alpha)
	-- lower whisker
	utils.drawLine(page, x, yls, x, yle, lineWidth)
	utils.drawLine(page, x - tLen, yle, x + tLen, yle, lineWidth)
	-- upper whisker
	utils.drawLine(page, x, yus, x, yue, lineWidth)
	utils.drawLine(page, x - tLen, yue, x + tLen, yue, lineWidth)
	hpdf.Page_GRestore(page)
end

function utils.boxPlot(pdf, page, x, y, lQ, uQ, lAnt, uAnt, boxWidth, boxMid, tLen, lineWidth)
	boxWidth = boxWidth or 5

	hpdf.Page_GSave(page)
	hpdf.Page_SetLineWidth(page, lineWidth or defaultLineWidth)
	hpdf.Page_Rectangle(page, x - boxWidth, lQ, 2 * boxWidth, uQ - lQ)
	hpdf.Page_Stroke(page)
	if boxMid then
		utils.drawLine(page, x - boxWidth, y, x + boxWidth, y, lineWidth)
	end
	utils.whisker(pdf, page, x, lQ , lAnt, uQ, uAnt, tLen, lineWidth)
	hpdf.Page_GRestore(page)
end


function utils.drawMark(page, mark, x, y, size)
	size = size or defaultMarkSize
	local r, lineWidth = size / 2, size / 5
	local success = true

	hpdf.Page_GSave(page)
	
	if mark == "asterix" then
		for i=0, 5, 1 do
			utils.drawLine(page, x, y, x + r * math.sin(i * 0.4 * math.pi), y + r * math.cos(i * 0.4 * math.pi), lineWidth)
		end		

	elseif mark == "plus" then
		utils.drawLine(page, x - r, y, x + r, y, lineWidth)
		utils.drawLine(page, x, y - r, x, y + r, lineWidth)

	elseif mark == "cross" then
		local rad = 0.25 * math.pi
		utils.drawLine(page, 
			x + r * math.sin(rad), y + r * math.cos(rad), 
			x + r * math.sin(rad + math.pi), y + r * math.cos(rad + math.pi), lineWidth)
		rad = 0.75 * math.pi
		utils.drawLine(page, 
			x + r * math.sin(rad), y + r * math.cos(rad), 
			x + r * math.sin(rad + math.pi), y + r * math.cos(rad + math.pi), lineWidth)

	elseif mark == "diamond" then
		hpdf.Page_MoveTo(page, x, y + r)
		hpdf.Page_LineTo(page, x - r / 2, y)
		hpdf.Page_LineTo(page, x, y - r)
		hpdf.Page_LineTo(page, x + r / 2, y)
		hpdf.Page_Fill(page)

	elseif mark == "square" then
		hpdf.Page_Rectangle(page, x - size / 3, y - size / 3, size * 2 / 3, size * 2 / 3)
		hpdf.Page_Fill(page)

	elseif mark == "circle" then
		hpdf.Page_Circle(page, x, y, r)
		hpdf.Page_Fill(page)

	elseif mark == "triangle" then
		hpdf.Page_MoveTo(page, x, y + math.sqrt(3) * size / 3)
		hpdf.Page_LineTo(page, x - r, y - math.sqrt(3) * size / 6)
		hpdf.Page_LineTo(page, x + r, y - math.sqrt(3) * size / 6)
		hpdf.Page_Fill(page)

	elseif mark == "rtriangle" then
		hpdf.Page_MoveTo(page, x, y - math.sqrt(3) * size / 3)
		hpdf.Page_LineTo(page, x - r, y + math.sqrt(3) * size / 6)
		hpdf.Page_LineTo(page, x + r, y + math.sqrt(3) * size / 6)
		hpdf.Page_Fill(page)

	else
		success = false
	end

	hpdf.Page_GRestore(page)
	return true
end

math.randomseed(os.time())
function utils.randomNormalDistributed(mean, variance)
	local u1, u2, q = 0, 0, 0
	while q == 0 or q > 1 do
		u1, u2 = math.random()*2-1, math.random()*2-1
		q = u1 ^ 2 + u2 ^ 2
	end
	q = math.sqrt(-2 * math.log(q) / q) * math.sqrt(variance)
	return mean + q * u1, mean + q * u2
end

function utils.genSmoothSeries(minx, maxx, numx, miny, maxy)
	local data = {}
	local max = (maxy - miny) / numx * 4
	local last = miny + math.random()*(maxy - miny)
	local rnd = 0
	for x = minx, maxx, (maxx - minx) / numx do
		rnd = math.random() * 2 * max - max
		if last + rnd > maxy or last + rnd < miny then
			rnd = -rnd
		end
		data[x] = {last + rnd }
		last = last + rnd
	end
	return data
end

function utils.genRandomSeries(minx, maxx, numx, miny, maxy, numy)
	local data = {}
	local diff = (maxy - miny) / 5
	for x = minx, maxx, (maxx - minx) / numx do
		data[x] = {}
		local rnd1, rnd2 = miny + diff + math.random() * (maxy - miny - 2*diff) , math.random(miny, maxy)
		for i=1, numy, 2 do
			data[x][i], data[x][i+1] = utils.randomNormalDistributed(rnd1, math.abs(rnd2))
		end
	end
	return data
end

function utils.genNormalDistributedSeries(sigma, mu, minx, maxx, numx, scale)
	local data = {}
	for x = minx, maxx, (maxx - minx) / numx do
		data[x] = {scale / (sigma * math.sqrt( 2 * math.pi)) * math.exp(-0.5 * (( x - mu) / sigma) ^ 2 )}
	end
	return data
end


return utils
