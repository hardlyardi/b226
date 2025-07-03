local SPEC_DIRECTORY = "./tests/_specs"
local MATCH_SPEC_FILE = "%.spec%.luau$"
local RESULTS_DIRECTORY = "./_SUITE"

local filesystem = require("@lune/fs")
local filesystem_hierarchy = require("@runtest/utils/filesystem_hierarchy")
local process = require("@lune/process")
local runtest = require("@runtest/")
local serdes = require("@lune/serde")

type CompletedSpec = runtest.CompletedSpec
type FilesystemHierarchy<T = true> = filesystem_hierarchy.Identity<T>

local run = runtest.run
local style = runtest.util.style

local color = style.color

local blue = color.blue
local green_bright = color.green_bright
local red_bright = color.red_bright

local function complete_spec(filename: string, name: string): CompletedSpec
	print(blue(`Running Spec "{name}"`))

	local spec = run.spec(filename, name)
	local completed_spec = spec:test()

	if completed_spec.result ~= "PASS" then
		print(red_bright(`Ended with result "{completed_spec.result}". Log:`) .. completed_spec.log)
	end

	if completed_spec.amount_pass > 0 then
		print(green_bright(`{completed_spec.amount_pass} Tests passed!`))
	else
		print(green_bright(`No tests passed.`))
	end

	if completed_spec.amount_fail > 0 then
		print(red_bright(`{completed_spec.amount_fail} Tests failed!`))
		for test_name, completed_test in completed_spec.tests do
			if completed_test.result ~= "FAIL" then continue end
			print(red_bright(`-  "{test_name}" failed:`) .. `{completed_test.log}`)
		end
	else
		print(green_bright(`No tests failed.`))
	end

	if completed_spec.amount_error > 0 then
		print(red_bright(`{completed_spec.amount_error} Tests errored!`))
		for test_name, completed_test in completed_spec.tests do
			if completed_test.result ~= "ERROR" then continue end
			print(red_bright(`-  "{test_name}" errored:`) .. `{completed_test.log}`)
		end
	else
		print(green_bright(`No tests errored.`))
	end

	return completed_spec
end

local function complete_specs(
	spec_hierarchy: FilesystemHierarchy,
	parent_name: string
): FilesystemHierarchy<CompletedSpec>
	local completed_specs = {} :: FilesystemHierarchy<CompletedSpec>
	for child_name, child in spec_hierarchy do
		local child_full_name = `{parent_name}/{child_name}`
		if type(child) == "table" then
			completed_specs[child_name] = complete_specs(child, child_full_name)
			continue
		end
		completed_specs[child_name] = complete_spec(child_full_name, child_full_name)
	end
	return completed_specs
end

-- this is so hacky lmao im not making a command line parser
local user_allows = ".*"
if process.args[1] == "--match" then user_allows = process.args[2] end

local spec_hierarchy = filesystem_hierarchy.new(SPEC_DIRECTORY)
spec_hierarchy = filesystem_hierarchy.filter(spec_hierarchy, { MATCH_SPEC_FILE })
spec_hierarchy = filesystem_hierarchy.filter(spec_hierarchy, { user_allows })

local completed_specs = complete_specs(spec_hierarchy, SPEC_DIRECTORY)

local any_didnt_pass = false

if filesystem.isDir(RESULTS_DIRECTORY) then filesystem.removeDir(RESULTS_DIRECTORY) end
filesystem.writeDir(RESULTS_DIRECTORY)

for filename, completed_spec in completed_specs do
	local encoded_spec = serdes.encode("json", completed_spec, true)

	if completed_spec.result ~= "PASS" then any_didnt_pass = true end

	filesystem.writeFile(`{RESULTS_DIRECTORY}/{filename}.testresult.json`, encoded_spec)
end

if any_didnt_pass then
	print(red_bright("\nSome specs did not succeed."))
	process.exit(1)
end

print(green_bright("\nAll specs passed."))
process.exit(0)
