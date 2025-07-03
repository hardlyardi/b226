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
do
end
local env_require = require("@runtest/env_require")
local filesystem = require("@lune/fs")
local luau = require("@lune/luau")
local pretty_print = require("@runtest/utils/pretty_print/main")
local process = require("@lune/process")
local spec_runner_types = require("@runtest/spec/runner/types")
local spec_types = require("@runtest/spec/types")
local task = require("@lune/task")
local test_interface = require("@runtest/spec/test/interface")

type LoadedSpec = spec_types.LoadedSpec
type SpecRunner = spec_runner_types.SpecRunner
type SpecTimer = spec_runner_types.SpecTimer
type CompletedTest = spec_runner_types.CompletedTest
type CompletedSpec = spec_runner_types.CompletedSpec

local os_clock = os.clock
local indent_newlines = pretty_print.indent_newlines

local function spec_run_tests(self: SpecRunner): CompletedSpec
	local completed_spec: CompletedSpec = {
		result = "PASS",
		tests = {} :: index<CompletedSpec, "tests">,
		timer = {
			time_began = os_clock(),
		} :: index<CompletedSpec, "timer">,
		log = "",
		amount_pass = 0,
		amount_fail = 0,
		amount_error = 0,
	}

	local spec_path = self._spec_path
	local spec_name = self._spec_name

	local readfile_success, readfile_result = pcall(filesystem.readFile, spec_path)
	if not readfile_success then
		completed_spec.log ..= "\n"
		completed_spec.log ..= debug.traceback(
			`Failed to import spec "{spec_name}" from path "{spec_path}".`
				.. ` Lune's Filesystem API errored:\n{readfile_result}`,
			2
		)

		completed_spec.result = "ERROR"

		return completed_spec
	end

	local compile_success, compile_result = xpcall(function()
		return luau.compile(readfile_result)
	end, function(err: string): ()
		completed_spec.result = "ERROR"
		completed_spec.log ..= `\nFailed to import spec "{spec_name}" from path "{spec_path}". Luau's compiler errored:\n{err}`
	end)

	if not compile_success then return completed_spec end

	local env_require_path = process.cwd .. spec_path

	self.is_initializing = true

	local loaded_spec = luau.load(compile_result, {
		debugName = `[SPEC "{spec_name}" (Initialization)]`,
		environment = {
			require = env_require.new(env_require_path),
		},
	})
	local initialize_success, initialized_spec: LoadedSpec = xpcall(function()
		return loaded_spec(self)
	end, function(err: string): ()
		completed_spec.result = "ERROR"
		--stylua: ignore
		completed_spec.log ..= `\nFailed to initialize. The spec errored on startup:`
			.. `\n{debug.traceback(err, 2)}`
	end)

	if not initialize_success then return completed_spec end

	self.is_initializing = false

	completed_spec.timer.time_initialized = os_clock()

	if initialized_spec.kind ~= "init" then
		completed_spec.log ..= "\n"
		completed_spec.log ..= debug.traceback(
			`Initialization return type wrong from spec path "{spec_path}".`
				.. ` Did you forget to call spec.done()?`,
			2
		)

		completed_spec.result = "ERROR"

		return completed_spec
	end

	local test_names = initialized_spec.test_names

	local awaiting = {} :: { [thread]: true? }

	for _, test_name in test_names do
		local completed_test: CompletedTest = {
			result = "PASS",
			timer = {
				time_began = os_clock(),
			},
			log = "",
		}

		self.active_test = test_name

		local loaded_test = luau.load(compile_result, {
			debugName = `[SPEC "{spec_name}" (Test "{test_name}")]`,
			environment = {
				require = env_require.new(env_require_path),
			},
		})

		local test_initialize_success, spec_test: LoadedSpec = xpcall(function()
			return loaded_test(self)
		end, function(err: string): ()
			completed_spec.result = "FAIL"
			completed_test.log ..= debug.traceback(err, 2)
		end)

		self.active_test = nil

		if not test_initialize_success then
			completed_spec.log ..= `\nFailed to initialize test "{test_name}". The test errored on startup.`

			completed_spec.tests[test_name] = completed_test

			continue
		end

		completed_test.timer.time_initialized = os_clock()

		if spec_test.kind ~= "test" then
			completed_spec.log ..= "\n"
			completed_spec.log ..= debug.traceback(
				`Failed to load test "{test_name}" because spec kind was not "test", bug?`,
				2
			)

			completed_spec.result = "ERROR"

			return completed_spec
		elseif spec_test.name ~= test_name then
			completed_spec.log ..= "\n"
			completed_spec.log ..= debug.traceback(
				`Failed to load test "{test_name}" due to mismatch loaded: "{spec_test.name}", bug?`,
				2
			)

			completed_spec.result = "ERROR"

			return completed_spec
		end

		local definition = spec_test.definition

		if not definition then
			completed_spec.log ..= "\n"
			completed_spec.log ..= debug.traceback(
				`Failed to load definition for test "{test_name}", bug?`,
				2
			)

			completed_spec.result = "ERROR"

			return completed_spec
		end

		local interface = test_interface.new()

		local case_thread = task.spawn(function(): ()
			local didnt_error, err_msg = xpcall(function()
				definition(interface)
				return nil :: string?
			end, function(err: string)
				return debug.traceback(err, 2)
			end)

			completed_test.timer.time_finished = os_clock()

			if not didnt_error then
				interface:fail(`\n{indent_newlines(`Error in test case:\n{err_msg}\n`)}`)

				completed_test.result = "ERROR"
			elseif interface._failed then
				completed_test.result = "FAIL"
			end

			completed_test.log ..= `\n{interface._output}`

			completed_spec.tests[test_name] = completed_test
		end)

		if coroutine.status(case_thread) ~= "dead" then
			interface._break:once(function(): ()
				if coroutine.status(case_thread) == "dead" then return end

				interface:fail("\nCase was ended early.")
				-- Luau
				if completed_test.result == "SUCCESS" then (completed_test :: any).result = "FAIL" end

				completed_test.log ..= `\n{interface._output}`

				task.cancel(case_thread)
			end)

			awaiting[case_thread] = true
		end
	end

	local next_awaiting = next(awaiting)
	while next_awaiting do
		if coroutine.status(next_awaiting) == "dead" then
			awaiting[next_awaiting] = nil
		else
			task.wait()
		end
		next_awaiting = next(awaiting)
	end

	for _, completed_test in completed_spec.tests do
		if completed_test.result == "PASS" then
			completed_spec.amount_pass += 1
			continue
		elseif completed_test.result == "FAIL" then
			completed_spec.amount_fail += 1
		elseif completed_test.result == "ERROR" then
			completed_spec.amount_error += 1
		else
			completed_spec.log ..= `\nEncountered bugged test result kind: "{completed_test.result}"`
		end
		completed_spec.result = "FAIL"
	end

	completed_spec.timer.time_finished = os_clock()

	return completed_spec
end

local function constructor(path: string, name: string?): SpecRunner
	name = name or `path '{path}'`

	return {
		_spec_path = path,
		_spec_name = name,
		is_initializing = false,
		active_test = nil :: string?,

		test = spec_run_tests,
	}
end

return { new = constructor }
