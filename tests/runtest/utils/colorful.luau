--[[
Copyright 2024 ffrostfall

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
]]
--!nocheck
local ESCAPE = string.char(27)
local ANSI_16 = `{ESCAPE}[%dm`

export type Styler = (text: string) -> string

local function createStylerFunction(opener: number, closer: number): Styler
	local open = string.format(ANSI_16, opener)
	local close = string.format(ANSI_16, closer)

	return function(text: string)
		return `{open}{text}{close}`
	end
end

local function combineStyles(styleArray: { (text: string) -> string }): Styler
	return function(text: string)
		local result = text

		for _, style in styleArray do
			result = style(result)
		end

		return result
	end
end

return {
	combineStyles = combineStyles,

	modifier = {
		dim = createStylerFunction(2, 22),
		reset = createStylerFunction(0, 0),
		bold = createStylerFunction(1, 22),
		italic = createStylerFunction(3, 23),
		hidden = createStylerFunction(8, 28),
		inverse = createStylerFunction(7, 27),
		underline = createStylerFunction(4, 24),
		overline = createStylerFunction(53, 55),
		strikethrough = createStylerFunction(9, 29),
	},

	color = {
		red = createStylerFunction(31, 39),
		blue = createStylerFunction(34, 39),
		cyan = createStylerFunction(36, 39),
		gray = createStylerFunction(90, 39),
		grey = createStylerFunction(90, 39),
		black = createStylerFunction(30, 39),
		green = createStylerFunction(32, 39),
		white = createStylerFunction(37, 39),
		yellow = createStylerFunction(33, 39),
		magenta = createStylerFunction(35, 39),
		red_bright = createStylerFunction(91, 39),
		blue_bright = createStylerFunction(94, 39),
		cyan_bright = createStylerFunction(96, 39),
		black_bright = createStylerFunction(90, 39),
		green_bright = createStylerFunction(92, 39),
		white_bright = createStylerFunction(97, 39),
		yellow_bright = createStylerFunction(93, 39),
		magenta_bright = createStylerFunction(95, 39),
	},
}
