--[[MIT License Copyright (c) 2025 @hardlyardi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]
--[[
--FOR DESCRIPTIONS OF API & CODE FUNCTION, ETC: https://light.ardi.gg/
--FOR ISSUES, BUG REPORTS, OR FEATURE REQUESTS: https://light.ardi.gg/github
--ROBLOX OSS SERVER: https://discord.com/invite/5KjV64PA3d
--MY DISCORD (please only contact for important questions): https://discord.com/users/331399684415553538/
]]
local INDENT = "   "
local DEFAULT_PRETTY_PRINT_DECIMALS = 4
-- scientific notation is in base 10, this is the closest power of 10 above 2^53 which is the max integer an f64 (luau
-- number) can accurately represent.
local SCIENTIFIC_NOTATION_THRESHOLD = 10 ^ 16

local colorful = require("@runtest/utils/colorful")

local color = colorful.color
local modifier = colorful.modifier

local brightblue = color.blue_bright
local cyan = color.cyan
local grey = color.grey
local magenta = color.magenta
local underline = modifier.underline

type UnknownTbl = { [unknown]: unknown }

local pretty_print_digits_precision = 4
local indent_print
local pretty_print_from_precision
local _pretty_print
local indent_newlines
local pretty_print_nil
local pretty_print_str
local pretty_print_tbl
local pretty_print_bool
local pretty_print_func
local pretty_print_number
local pretty_print_thread
local pretty_print_vector
local pretty_print_unknown

function indent_newlines(str: string): string
	local indented = str:gsub("\n", `\n{INDENT}`)
	return indented
end

function indent_print(input: unknown): string
	return indent_newlines(_pretty_print(input))
end

do
	local comma_value
	function pretty_print_number(num: number): string
		-- Luau
		local string_format = string.format :: any

		local as_str: string

		if num >= SCIENTIFIC_NOTATION_THRESHOLD then
			local formatted_round = string_format(`%.{pretty_print_digits_precision}e`, num)

			as_str = formatted_round
		else
			local remainder = num % (10 ^ -pretty_print_digits_precision)
			local rounded = num - remainder

			as_str = `{comma_value(rounded)}`
		end

		return brightblue(as_str)
	end
	function comma_value(amount: number): string
		-- radix matches can be 0 or 1, because the match is greedy and anchored to the beginning of the string.
		-- once it's zero, there are no more groups of three digits to separate by comma.
		local formatted, radix_matches = tostring(amount):gsub("^(%d+)(%d%d%d)", "%1,%2")
		while radix_matches ~= 0 do
			-- Luau
			formatted, radix_matches = (formatted :: string):gsub("^(%d+)(%d%d%d)", "%1,%2")
		end
		return formatted
	end
end

function pretty_print_str(str: string): string
	if str:match("\n") then
		return magenta("[[\n") .. indent_newlines(str) .. magenta("\n]]") --
	end
	return `{magenta('"')}{brightblue(str)}{magenta('"')}`
end

function pretty_print_nil(nothing: nil): string
	return brightblue(underline("nil"))
end

function pretty_print_bool(bool: boolean): string
	return brightblue(underline(`{bool}`))
end

function pretty_print_vector(vector: vector): string
	return "vector"
		.. `{magenta("<")}`
		.. `{pretty_print_number(vector.x)}`
		.. `, {pretty_print_number(vector.y)}`
		.. `, {pretty_print_number(vector.z)}`
		.. `{magenta(">")}`
end

function pretty_print_func<Params..., Returns...>(func: (Params...) -> Returns...): string
	local address = tostring(func):gsub(".* ", "")

	local name = debug.info(func, "n")

	if (name == nil) or (name == "") then
		return magenta("<") .. `function ({address})` .. magenta(">")
	else
		return magenta("<") .. `function "{name}" ({address})` .. magenta(">")
	end
end

function pretty_print_thread(thread: thread): string
	local STATUS = coroutine.status(thread)
	STATUS = STATUS:upper()

	local output = magenta("<") .. `{tostring(thread)} {STATUS} @ ` .. magenta("[")

	output ..= indent_newlines(`\n{debug.traceback(thread)}`)

	-- weird hack to remove ending newline
	output = output:gsub(`\n{INDENT}$`, "")

	output ..= "\n" .. magenta("]") .. magenta(">")

	return output
end

function pretty_print_tbl(tbl: UnknownTbl): string
	local output = magenta(`\{\n`)

	for key, value in tbl do
		output ..= `{INDENT}{cyan("[")}{indent_print(key)}{cyan("]")} = {indent_print(value)}\n`
	end

	output ..= magenta("}")

	return output
end

function pretty_print_unknown(value: unknown): string
	local typeof_value = typeof(value)

	-- remove any potential interfering beginning/ending chevrons
	local stringified = tostring(value):gsub("^<", ""):gsub(">$", "")

	-- if value's tostring contains its type, don't include it in the stringification
	if stringified:lower():match(typeof_value:lower()) then
		stringified = magenta("<") .. grey(stringified) .. magenta(">")
	else
		stringified = magenta("<") .. grey(`{typeof_value}: {stringified}`) .. magenta(">")
	end

	return stringified
end

function _pretty_print(value: any): string
	if type(value) == "number" then return pretty_print_number(value) end
	if type(value) == "string" then return pretty_print_str(value) end
	if type(value) == "nil" then return pretty_print_nil(value) end
	if type(value) == "boolean" then return pretty_print_bool(value) end
	if type(value) == "vector" then return pretty_print_vector(value) end
	if type(value) == "function" then return pretty_print_func(value :: (...any) -> ...any) end
	if type(value) == "thread" then return pretty_print_thread(value) end
	if type(value) == "table" then return pretty_print_tbl(value :: UnknownTbl) end
	return pretty_print_unknown(value)
end

function pretty_print_from_precision(value: any, digits_precision: number?): string
	if not digits_precision then return _pretty_print(value) end

	pretty_print_digits_precision = digits_precision
	local output = _pretty_print(value)
	pretty_print_digits_precision = DEFAULT_PRETTY_PRINT_DECIMALS

	return output
end

function pretty_print_from_epsilon(value: any, epsilon: number?): string
	if not epsilon then return _pretty_print(value) end

	pretty_print_digits_precision = math.max(math.clamp(-math.log10(epsilon), 0, 100))
	local output = _pretty_print(value)
	pretty_print_digits_precision = DEFAULT_PRETTY_PRINT_DECIMALS

	return output
end

local function indent(str: string): string
	return `{INDENT}{str}`
end

return {
	from_precision = pretty_print_from_precision,
	from_epsilon = pretty_print_from_epsilon,
	indent_newlines = indent_newlines,
	indent = indent,
}
