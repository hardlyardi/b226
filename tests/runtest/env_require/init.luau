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
local luau = require("@lune/luau")
local resolver = require("@runtest/env_require/resolver")
local resolver_types = require("@self/resolver/types")

type RequireAliases = resolver_types.RequireAliases

local resolver_from_path = resolver.from_path

local function _require_constructor(
	requiring_path: string,
	result_cache: { [string]: any }
): (string) -> any
	local require_resolver = resolver_from_path(requiring_path, {
		"@lune/",
		"@runtest/env_require",
		"@runtest/utils",
	})

	local function TEST_require(requested_path: string): any
		local resolved = require_resolver:resolve_path(requested_path)

		if resolved.use_fallback_resolver then
			return (require)(requested_path) --
		end

		local resolved_path = resolved.path

		local resolved_file = resolved_path

		do
			local cached = result_cache[resolved_file]
			if cached ~= nil then return cached end
		end

		local resolved_code = filesystem.readFile(resolved_file)
		local resolved_bytecode = luau.compile(resolved_code)
		local resolved_module = luau.load(resolved_bytecode, {
			debugName = resolved_file,
			injectGlobals = true,
			environment = {
				require = _require_constructor(resolved_path, result_cache),
			},
		})

		local success, result = xpcall(resolved_module, function(err)
			return debug.traceback(err, 2)
		end)

		if not success then
			error(`{result}\nRequested module experienced an error while loading.`, 2)
		end

		result_cache[resolved_file] = result

		return result
	end

	return TEST_require
end

local function require_constructor(module: string): (string) -> any
	return _require_constructor(module, {})
end

return {
	new = require_constructor,
}
