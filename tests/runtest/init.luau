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
--[[runtest
A flexible, robust testing framework built with lune.
v0.1.1
]]
do
end
local colorful = require("@runtest/utils/colorful")
local filesystem_hierarchy = require("@runtest/utils/filesystem_hierarchy")
local filesystem_path = require("@runtest/utils/filesystem_path")
local pretty_print = require("@runtest/utils/pretty_print/main")
local profile = require("@runtest/bench/profile/main")
local profile_types = require("@runtest/bench/profile/types")
local spec_runner = require("@runtest/spec/runner/main")
local spec_runner_types = require("@runtest/spec/runner/types")
local spec_types = require("@runtest/spec/types")
local table_merge = require("@runtest/utils/table_merge")
local test = require("@runtest/spec/test/main")
local test_types = require("@runtest/spec/test/types")

export type SpecRunner = spec_runner_types.SpecRunner
export type LoadedSpec = spec_types.LoadedSpec
export type SpecInterface = spec_types.SpecInterface
export type TestInterface = test_types.TestInterface
export type CompletedSpec = spec_runner_types.CompletedSpec

export type ProfileInterface = profile_types.ProfileInterface

return {
	run = {
		spec = spec_runner.new,
		bench = nil,
	},
	test = {
		spec = {
			init = test.init,
		},
		bench = {
			init = profile.init,
		},
	},
	util = {
		style = table_merge.union(pretty_print, table.clone(colorful)),
		filesystem_path = filesystem_path,
		filesystem_hierarchy = filesystem_hierarchy,
	},
}
