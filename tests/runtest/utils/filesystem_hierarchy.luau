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
local filesystem = require("@lune/fs")

export type Identity<T = true> = { [string]: Identity<T> | T }

local function hierarchy(directory: string): Identity
	local created_hierarchy: Identity = {}

	local children = filesystem.readDir(directory)

	for _, path in children do
		if filesystem.isDir(`{directory}/{path}`) then
			local child_contents = hierarchy(`{directory}/{path}`)

			created_hierarchy[path] = child_contents
		else
			created_hierarchy[path] = true
		end
	end

	return created_hierarchy
end

local function files_under_hierarchy(
	hierarchy: Identity,
	parent_directory: string?
): () -> (string?, Identity)
	parent_directory = parent_directory or ""
	local output = {} :: { [string]: Identity }

	for child_name, child_hierarchy in hierarchy do
		local child_fullname = `{parent_directory}/{child_name}`
		if type(child_hierarchy) == "table" then
			for grandchild_full_name in files_under_hierarchy(child_hierarchy, child_fullname) do
				output[grandchild_full_name] = child_hierarchy
			end
			continue
		end
		output[child_fullname] = hierarchy
		continue
	end

	local full_name: string?, parent_hierarchy
	return function()
		full_name, parent_hierarchy = next(output, full_name)
		return full_name, parent_hierarchy
	end
end

local function filter_paths(
	parent_hierarchy: Identity,
	match_patterns: { string },
	parent_directory: string?
): Identity
	parent_directory = parent_directory or ""
	local output = {}

	for child_name, child_hierarchy in parent_hierarchy do
		local child_fullname = `{parent_directory}/{child_name}`

		if type(child_hierarchy) == "table" then
			local child_filtered = filter_paths(child_hierarchy, match_patterns, child_fullname)

			if not next(child_filtered) then continue end

			output[child_name] = child_filtered
			continue
		end

		local found_matches = false
		for _, match in match_patterns do
			if child_fullname:match(match) then
				found_matches = true
				break
			end
		end

		if found_matches then output[child_name] = true end
	end

	return output
end

return {
	new = hierarchy,
	files = files_under_hierarchy,
	filter = filter_paths,
}
