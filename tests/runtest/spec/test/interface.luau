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
local DEFAULT_EPSILON = 0.0001

local colorful = require("@runtest/utils/colorful")
local epsilon_eq = require("@runtest/utils/equality/from_epsilon")
local luau_eq = require("@runtest/utils/equality/from_luau")
local luausignal = require("@runtest/utils/luausignal")
local pretty_print = require("@runtest/utils/pretty_print/main")
local test_types = require("@runtest/spec/test/types")

type TestInterface = test_types.TestInterface

local color = colorful.color
local indent = pretty_print.indent
local indent_newlines = pretty_print.indent_newlines
local style_str = pretty_print.from_epsilon

local red_bright = color.red_bright
local green_bright = color.green_bright
local yellow_bright = color.yellow_bright

local INDENT = indent("")
local LEFT = green_bright("Left:")
local RIGHT = yellow_bright("Right:")

local test_interface = {}
local metatable = { __index = test_interface }

local function constructor(): TestInterface
	local output = setmetatable({
		_output = "",
		_failed = false,
		_break = luausignal(),
	}, metatable)

	return output
end

--[=[
Cause the test to fail. Optional message will be appended directly to the current test output with no newline.
]=]
function test_interface.fail(self: TestInterface, message: string?): ()
	self._failed = true
	if message then
		self._output ..= message
	end
end

--[=[
Checks equality with `left == right`
]=]
function test_interface.expect_exactly_equal<Left, Right>(self: TestInterface, left: Left, right: Right): ()
	if luau_eq.check(left, right) then return end

	local line = debug.info(2, "l")
	self:fail(
		red_bright(`\n[{line}]: Expected left to exactly equal right.`)
			--[[
			Luau
			]]
			.. `\n{LEFT}\n{INDENT}{indent_newlines(style_str(left :: any))}`
			.. `\n{RIGHT}\n{INDENT}{indent_newlines(style_str(right :: any))}`
	)
end

--[=[
Checks equality with `not(left == right)`
]=]
function test_interface.expect_not_exactly_equal<Left, Right>(self: TestInterface, left: Left, right: Right): ()
	if not luau_eq.check(left, right) then return end

	local line = debug.info(2, "l")
	self:fail(
		red_bright(`\n[{line}]: Expected left to NOT exactly equal right.`)
			--[[
			Luau
			]]
			.. `\n{LEFT}\n{INDENT}{indent_newlines(style_str(left :: any))}`
			.. `\n{RIGHT}\n{INDENT}{indent_newlines(style_str(right :: any))}`
	)
end

--[=[
epsilon defualt 0.0001

tables: recursively check each key
numbers: abs(left - right) < epsilon
vectors: vector.magnitude(left - right) < epsilon
other: left == right
]=]
function test_interface.expect_equal<Left, Right>(self: TestInterface, left: Left, right: Right, epsilon: number?): ()
	epsilon = epsilon or DEFAULT_EPSILON
	if epsilon_eq.check(left, right, epsilon) then return end

	local line = debug.info(2, "l")
	self:fail(
		red_bright(`\n[{line}]: Expected left to differ from right within a threshold of {epsilon}.`)
			--[[
			Luau
			]]
			.. `\n{LEFT}\n{INDENT}{indent_newlines(style_str(left :: any, epsilon))}`
			.. `\n{RIGHT}\n{INDENT}{indent_newlines(style_str(right :: any, epsilon))}`
	)
end

--[=[
epsilon defualt 0.0001

tables: recursively check each key
numbers: not ( abs(left - right) < epsilon )
vectors: not ( vector.magnitude(left - right) < epsilon )
other: not ( left == right )
]=]
function test_interface.expect_not_equal<Left, Right>(self: TestInterface, left: Left, right: Right, epsilon: number?): ()
	if not epsilon_eq.check(left, right, epsilon or DEFAULT_EPSILON) then return end

	local line = debug.info(2, "l")
	self:fail(
		red_bright(`\n[{line}]: nExpected left to have more than {epsilon} difference from right.`)
			--[[
			Luau
			]]
			.. `\n{LEFT}\n{INDENT}{indent_newlines(style_str(left :: any, epsilon))}`
			.. `\n{RIGHT}\n{INDENT}{indent_newlines(style_str(right :: any, epsilon))}`
	)
end

--[=[
nil: false
false: false
other: true
]=]
function test_interface.expect_truthy<Value>(self: TestInterface, value: Value): ()
	if value then return end
	local line = debug.info(2, "l")
	self:fail(
		red_bright(`\n[{line}]: Expected value to be truthy.`)
			.. ` VALUE:\n{INDENT}{indent_newlines(style_str(value :: any))}`
	)
end

--[=[
nil: true
false: true
other: false
]=]
function test_interface.expect_falsy<Value>(self: TestInterface, value: Value): ()
	if not value then return end
	local line = debug.info(2, "l")
	self:fail(
		red_bright(`\n[{line}]: Expected value to be falsy.`)
			.. ` VALUE:\n{INDENT}{indent_newlines(style_str(value :: any))}`
	)
end

--[=[
End the test early.
]=]
function test_interface.early_end(self: TestInterface): ()
	self._break:fire()
end

--[=[
Concats a message to the logs for a test without causing any failure.
]=]
function test_interface.output(self: TestInterface, message: string): ()
	self._output = `{self._output}\n{message}`
end

--[=[
Concats a message to the logs for a test without causing any failure or inserting a newline.
]=]
function test_interface.output_no_newline(self: TestInterface, message: string): ()
	self._output ..= message
end

return {
	new = constructor,
}
