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
--[[filesystem_path (🇨🇦)
A performant OS agnostic filesystem path object written in luau.
v0.1.0
]]
local NAVIGATE_BACK = ".."
local NAVIGATE_HERE = "."
local ROOT_PATTERN = "^([/\\]?[^/\\]+[/\\])"
local GOLDEN_RATIO = 1.61803398875

local filesystem = require("@lune/fs")
local process = require("@lune/process")

local SEPARATOR = if process.os == "windows" then "\\" else "/"

export type PathNav = { string }

local string_gsub = string.gsub
local string_split = string.split
local table_concat = table.concat
local table_create = table.create
local table_clone = table.clone
local filesystem_metadata = filesystem.metadata

local to_nav
local from_nav
local parent
local len
local normalize
local exists
local file_eh
local directory_eh

do
	local cache = {} :: { [string]: PathNav }
	function to_nav(input: string): PathNav
		do
			local cached = cache[input]
			if cached ~= nil then return table_clone(cached) end
		end
		local corrected_separator = string_gsub(input, "[/\\]", SEPARATOR)
		local nav = string_split(corrected_separator, SEPARATOR)
		cache[input] = nav
		return (table_clone(nav))
	end
end

do
	function from_nav(input: PathNav): string
		local output = table_concat(input, SEPARATOR)

		return output
	end
end

function navigate(input: string, navigation: string): string
	return `{input}{SEPARATOR}{navigation}`
end

function parent(input: string): string
	return `{input}{SEPARATOR}..{SEPARATOR}`
end

do
	local cache = {} :: { [string]: number }
	function len(input: string): number
		do
			local cached = cache[input]
			if cached ~= nil then return cached end
		end
		local nav = to_nav(input)
		local output = #nav
		cache[input] = output
		return output
	end
end

do
	local cache = {} :: { [string]: string }
	function normalize(input: string): string
		do
			local cached = cache[input]
			if cached ~= nil then return cached end
		end

		local backslashed = string_gsub(input, "[/\\]+", SEPARATOR)

		local original_nav = to_nav(backslashed)
		local original_len = len(backslashed)

		-- Output nav stack
		-- Assume shrink factor close to the golden ratio
		local output_nav = table_create(original_len // GOLDEN_RATIO) :: { string }
		local output_nav_top = 0

		for nav_index = 1, original_len do
			local nav_item = original_nav[nav_index]

			if nav_item == NAVIGATE_BACK then
			--stylua: ignore
			local should_pop =
				-- don't pop if there are no items to pop
				if output_nav_top == 0 then false else
				-- don't pop if the top of output_nav is a backwards nav
				-- (only possible if everything prior is also backwards nav)
				if output_nav[output_nav_top] == NAVIGATE_BACK then false else true

				if should_pop then
					output_nav[output_nav_top] = nil
					output_nav_top -= 1
					continue
				end
			elseif nav_item == NAVIGATE_HERE then
				continue
			end

			--[[
			push
			]]
			output_nav_top += 1
			output_nav[output_nav_top] = nav_item
		end

		local output = from_nav(output_nav)
		cache[input] = output
		return output
	end
end

do
	local cache = {} :: { [string]: boolean }
	function exists(input: string): boolean
		do
			local cached = cache[input]
			if cached ~= nil then return cached end
		end

		local success, metadata = pcall(filesystem_metadata, input)
		if not success then
			cache[input] = false
			return false
		end

		local metadata_exists = metadata.exists
		cache[input] = metadata_exists

		return metadata_exists
	end
end

do
	local cache = {} :: { [string]: boolean }
	function file_eh(input: string): boolean
		do
			local cached = cache[input]
			if cached ~= nil then return cached end
		end

		local input_exists = exists(input)
		if not input_exists then
			cache[input] = false
			return false
		end

		local metadata = filesystem_metadata(input)

		local metadata_kind = metadata.kind

		local metadata_kind_file_eh = metadata_kind == "file"
		cache[input] = metadata_kind_file_eh

		return metadata_kind_file_eh
	end
end

do
	local cache = {} :: { [string]: boolean }
	function directory_eh(input: string): boolean
		do
			local cached = cache[input]
			if cached ~= nil then return cached end
		end

		local input_exists = exists(input)
		if not input_exists then
			cache[input] = false
			return false
		end

		local metadata = filesystem_metadata(input)

		local metadata_kind = metadata.kind

		local metadata_kind_is_directory = metadata_kind == "dir"
		cache[input] = metadata_kind_is_directory

		return metadata_kind_is_directory
	end
end

function matches_root(input: string, cwd: string): boolean
	local input_root = normalize(input):match(ROOT_PATTERN)
	local cwd_root = normalize(cwd):match(ROOT_PATTERN)
	return input_root == cwd_root
end

return {
	SEPARATOR = SEPARATOR,
	to_nav = to_nav,
	from_nav = from_nav,
	navigate = navigate,
	parent = parent,
	len = len,
	normalize = normalize,
	exists = exists,
	file_eh = file_eh,
	directory_eh = directory_eh,
	matches_root = matches_root,
}
