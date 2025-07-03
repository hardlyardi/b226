--[[
simple util for creating specs
]]
local runtest = require("@runtest/")

type SpecRunner = runtest.SpecRunner
type SpecInterface = runtest.SpecInterface
type TestInterface = runtest.TestInterface
type LoadedSpec = runtest.LoadedSpec

local function serve(PASSED: SpecRunner)
	local spec = runtest.test.spec.init(PASSED)

	local scriptname = debug.info(2, "s")
	local test_prefix: string

	local function PREFIX(prefix: string?): ()
		prefix = prefix or scriptname
		if prefix == "" then
			test_prefix = ""
		else
			test_prefix = `[{prefix}] `
		end
	end
	local function TEST(label: string, test: (TestInterface) -> ()): ()
		spec.test(`{test_prefix}{label}`, test)
	end
	local function DONE(): LoadedSpec
		return spec.done()
	end

	return TEST, DONE, PREFIX
end

return serve
