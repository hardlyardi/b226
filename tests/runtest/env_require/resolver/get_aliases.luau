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
local filesystem_path = require("@runtest/utils/filesystem_path")
local process = require("@lune/process")
local resolver_types = require("./types")
local serdes = require("@lune/serde")

type RequireAliases = resolver_types.RequireAliases

local serdes_decode = serdes.decode
local filesystem_read_file = filesystem.readFile
local table_clone = table.clone
local fsp_normalize = filesystem_path.normalize
local fsp_to_nav = filesystem_path.to_nav
local fsp_from_nav = filesystem_path.from_nav
local fsp_matches_root = filesystem_path.matches_root
local fsp_navigate = filesystem_path.navigate
local fsp_file_eh = filesystem_path.file_eh

local process_cwd = process.cwd

local cache = {} :: { [string]: RequireAliases }
local function get_luaurc_aliases(file_directory: string): RequireAliases
	local normalized_file_directory = fsp_normalize(file_directory)
	local hash = normalized_file_directory
	do
		local cached = cache[hash]
		if cached ~= nil then return (table_clone(cached)) end
	end

	local nav = fsp_to_nav(normalized_file_directory)

	local all_aliases = {}

	while true do
		local removed = table.remove(nav, #nav)
		if not removed then break end

		local nav_str = fsp_from_nav(nav)
		local matches_cwd_root = fsp_matches_root(nav_str, process_cwd)
		if not matches_cwd_root then break end

		local luaurc_parent = nav_str
		local possible_luaurc = fsp_navigate(luaurc_parent, ".luaurc")

		local file_eh = fsp_file_eh(possible_luaurc)
		if not file_eh then continue end

		local luaurc_content = filesystem_read_file(possible_luaurc)
		local luaurc_data = serdes_decode("json", luaurc_content)

		local luaurc_aliases: { [string]: string }? = luaurc_data.aliases

		if luaurc_aliases == nil then continue end

		for alias, target in luaurc_aliases do
			if all_aliases[alias] ~= nil then continue end

			local full_target = fsp_normalize(fsp_navigate(luaurc_parent, target))

			local target_matches_cwd_root = fsp_matches_root(full_target, process_cwd)

			if not target_matches_cwd_root then
				error(
					`Problem registering alias "{alias}": "{target}" in luaurc "{possible_luaurc}",`
						.. ` path parent is beyond the scope of cwd`
				)
			end

			all_aliases[alias] = full_target
		end
	end

	cache[hash] = all_aliases

	return (table_clone(all_aliases))
end

return {
	from_luaurc = get_luaurc_aliases,
}
