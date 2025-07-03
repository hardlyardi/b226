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
local spec_runner_types = require("@runtest/spec/runner/types")
local spec_types = require("@runtest/spec/types")
local test_types = require("@runtest/spec/test/types")

type TestInterface = test_types.TestInterface
type TestDefinition = test_types.TestDefinition
type SpecInterface = spec_types.SpecInterface
type LoadedSpec = spec_types.LoadedSpec
type SpecRunner = spec_runner_types.SpecRunner

local using_runner: SpecRunner
local initialized = false
local function init(passed_runner: SpecRunner): SpecInterface
	if initialized then error(debug.traceback("Cannot initialize spec; already initialized", 3), 2) end
	initialized = true

	using_runner = assert(passed_runner, "intended usage: init(...)")

	local is_initializing = using_runner.is_initializing
	local active_test = using_runner.active_test

	local test_case_constructor, collect

	if is_initializing then
		local test_names = {}

		function test_case_constructor(name: string, definiton: TestDefinition): ()
			table.insert(test_names, name)
		end

		function collect(): LoadedSpec
			return {
				kind = "init",
				test_names = test_names,
			}
		end
	else
		assert(active_test, "no active test provided, what the carp?")

		local output_definition: TestDefinition

		function test_case_constructor(name: string, definition: TestDefinition): ()
			if active_test ~= name then return end

			if output_definition then error(`tried to redefine test of name "{name}"`) end

			output_definition = definition
		end

		function collect(): LoadedSpec
			return {
				kind = "test",
				name = active_test,
				definition = assert(output_definition, "test got no definition, what the carp?"),
			}
		end
	end

	return {
		test = test_case_constructor,
		done = collect,
	}
end

return { init = init }
