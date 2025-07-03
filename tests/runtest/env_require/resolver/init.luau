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
local ALIAS_PATTERN = `^@(.+)`
local FILENAME_PATTERN = `[/\\]?([^/\\]+)$`

local filesystem_path = require("@runtest/utils/filesystem_path")
local get_aliases = require("@self/get_aliases")
local pretty_print = require("@runtest/utils/pretty_print/main")
local process = require("@lune/process")
local resolver_types = require("@self/types")

type RequireAliases = resolver_types.RequireAliases
type ResolverResult = resolver_types.ResolverResult

local SEPARATOR = filesystem_path.SEPARATOR
local get_aliases_from_luaurc = get_aliases.from_luaurc
local process_cwd = process.cwd
local string_match = string.match
local table_remove = table.remove
local fsp_normalize = filesystem_path.normalize
local fsp_to_nav = filesystem_path.to_nav
local fsp_from_nav = filesystem_path.from_nav
local fsp_matches_root = filesystem_path.matches_root
local fsp_navigate = filesystem_path.navigate
local fsp_file_eh = filesystem_path.file_eh
local fsp_exists = filesystem_path.exists
local fsp_directory_eh = filesystem_path.directory_eh

local resolver = {}
local metatable = { __index = resolver }

export type Identity = setmetatable<{
	_aliases: RequireAliases,
	_directory: string,
	_fallback_matches: { string },
}, typeof(metatable)>

local function resolver_from_path(
	requiring_path: string,
	fallback_match: (string | { string })?
): Identity
	requiring_path = requiring_path:gsub("[/\\]+", SEPARATOR)
	do
		local requiring_path_exists = fsp_exists(requiring_path)
		if not requiring_path_exists then
			error(`Problem constructing resolver for path "{requiring_path}", path does not exist.`)
		end
		local requiring_path_file_eh = fsp_file_eh(requiring_path)
		if not requiring_path_file_eh then
			error(`Problem constructing resolver for path "{requiring_path}", path is not a file.`)
		end
	end

	local requiring_dir = fsp_normalize(fsp_navigate(requiring_path, ".."))
	local requiring_dir_matches_cwd_root = fsp_matches_root(requiring_dir, process_cwd)

	if not requiring_dir_matches_cwd_root then
		error(
			`Problem constructing resolver for path "{requiring_path}", path parent is beyond the scope of cwd`
		)
	end

	local aliases = get_aliases_from_luaurc(requiring_dir)

	local filename: string? = string_match(requiring_path, FILENAME_PATTERN)
	if filename == nil then
		error(`Problem constructing resolver for path "{requiring_path}", could not match filename`)
	end

	if (filename == "init.luau") or (filename == "init.lua") then
		aliases.self = requiring_dir --
	end

	local fallback_matches: { string }?

	if fallback_match then
		if type(fallback_match) == "string" then
			fallback_matches = { fallback_match }
		elseif type(fallback_match) == "table" then
			fallback_matches = fallback_match
		else
			error("unreachable")
		end
	end

	local self = setmetatable({
		_aliases = aliases,
		_directory = requiring_dir,
		_fallback_matches = fallback_matches or {},
	}, metatable)

	return self
end

local resolver_result_fallback: ResolverResult = {
	use_fallback_resolver = true,
}

function resolver.resolve_path(self: Identity, path: string): ResolverResult
	local fallback_matches = self._fallback_matches
	local fallback_matches_len = #fallback_matches
	for fallback_matches_index = 1, fallback_matches_len do
		local fallback_match = fallback_matches[fallback_matches_index]
		if string_match(path, fallback_match) then return resolver_result_fallback end
	end

	local nav = fsp_to_nav(path)

	local path_begins = table_remove(nav, 1) :: index<typeof(nav), keyof<typeof(nav)>>
	local alias = string_match(path_begins, ALIAS_PATTERN)

	local resolve_root: string

	if alias ~= nil then
		local aliases = self._aliases

		local alias_target: string? = aliases[alias]

		if alias_target == nil then
			error(
				`Failed to resolve from filesystem path "{path}", could not find alias "{alias}".`
					.. ` Valid aliases: {pretty_print.from_epsilon(aliases)}`
			)
		end

		resolve_root = alias_target
	elseif path_begins == ".." then
		local directory_parent = fsp_normalize(fsp_navigate(self._directory, ".."))
		local directory_matches_cwd_root = fsp_matches_root(directory_parent, process_cwd)

		if not directory_matches_cwd_root then
			error(
				`Failed to resolve from filesystem path "{path}", directory's parent is beyond the scope of cwd`
			)
		end

		resolve_root = directory_parent
	elseif path_begins == "." then
		resolve_root = self._directory
	else
		print(path_begins)
		error(
			`Could not resolve module for "{path}".`
				.. ` Paths must begin with either "@<alias>/", "./", or "../"`
		)
	end

	local resolve_suffix = fsp_from_nav(nav)

	local full_resolve_path = fsp_normalize(fsp_navigate(resolve_root, resolve_suffix))

	local full_resolve_path_matches_cwd_root = fsp_matches_root(full_resolve_path, process_cwd)
	if not full_resolve_path_matches_cwd_root then
		error(
			`Failed to resolve from filesystem path "{path}", path is beyond the scope of cwd`
		)
	end

	local found_file: string

	--print(full_resolve_path:as_str())

	local full_resolve_path_directory_eh = fsp_directory_eh(full_resolve_path)

	--[[
	gigantic mess of nesting but i can't think of a more performant way to do this atm
	]]
	if full_resolve_path_directory_eh then
		do
			local try = fsp_navigate(full_resolve_path, "init.luau")
			--print(try:as_str())
			local file_eh = fsp_file_eh(try)
			if file_eh then found_file = try end
		end
		do
			local try = fsp_navigate(full_resolve_path, "init.lua")
			--print(try:as_str())
			local file_eh = fsp_file_eh(try)
			if file_eh then
				if found_file then
					--stylua: ignore
					error(
						`Could not resolve module for "{path}".`
							.. ` Found multiple matching paths "{found_file}" and "{try}"`
					)
				end
				found_file = try
			end
		end
	else
		local full_resolve_path_file_eh = fsp_file_eh(full_resolve_path)
		if full_resolve_path_file_eh then
			found_file = full_resolve_path --
		end
		do
			local try = `{full_resolve_path}.luau`
			--print(try:as_str())
			local file_eh = fsp_file_eh(try)
			if file_eh then
				if found_file then
					--stylua: ignore
					error(
						`Could not resolve module for "{path}".`
							.. ` Found multiple matching paths "{found_file}" and "{try}"`
					)
				end
				found_file = try
			end
		end
		do
			local try = `{full_resolve_path}.lua`
			--print(try:as_str())
			local file_eh = fsp_file_eh(try)
			if file_eh then
				if found_file then
					--stylua: ignore
					error(
						`Could not resolve module for "{path}".`
							.. ` Found multiple matching paths "{found_file}" and "{try}"`
					)
				end
				found_file = try
			end
		end
	end

	if not found_file then
		error(
			`Could not resolve module for "{path}".` .. ` Could not find a matching path."`
		)
	end

	return {
		use_fallback_resolver = false,
		path = found_file,
	}
end

return { from_path = resolver_from_path }
