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

--!nolint LocalShadow
--!optimize 2

--- Merge properties of `from` into table `into`, unioning overlaps.
export type function table_merge_union(from: type, into: type): type
	assert(from:is("table"), [[Expected "from" to be table when merging.]])
	assert(into:is("table"), [[Expected "to" to be table when merging.]])

	local output = types.copy(into)

	local from_props = from:properties()

	local into_props = {} :: { [string]: { read: type?, write: type? } }

	for into_field, into_readwrite in output:properties() do
		local into_field_name = into_field:value()

		if type(into_field_name) ~= "string" then continue end

		into_props[into_field_name] = into_readwrite
	end

	for from_field, from_readwrite in from_props do
		local into_readwrite
		local from_value = from_field:value()
		if type(from_value) == "string" then into_readwrite = into_props[from_value] end

		local from_read, from_write = from_readwrite.read, from_readwrite.write

		if from_read then
			local into_read = into_readwrite and into_readwrite.read

			local to_set = if into_read then types.unionof(from_read, into_read) else from_read

			output:setreadproperty(from_field, to_set)
		end

		if from_write then
			local into_write = into_readwrite and into_readwrite.write

			local to_set = if into_write then types.unionof(from_write, into_write) else from_write

			output:setwriteproperty(from_field, to_set)
		end
	end

	local from_indexer = from:indexer()
	local into_indexer = output:indexer()

	if from_indexer and into_indexer then
		local union_read = types.unionof(from_indexer.readresult, into_indexer.readresult)
		local union_write = types.unionof(from_indexer.writeresult, into_indexer.writeresult)
		output:setreadindexer(from_indexer.index, union_read)
		output:setwriteindexer(from_indexer.index, union_write)
	elseif from_indexer then
		output:setreadindexer(from_indexer.index, from_indexer.readresult)
		output:setwriteindexer(from_indexer.index, from_indexer.writeresult)
	end

	return output
end

--[=[
Merge properties of table `from` into table `into`, unioning overlaps.
Does not clone `into`.
]=]
function table_merge_union<From, Into>(from: From, into: Into): table_merge_union<From, Into>
	local from = from :: { [unknown]: unknown }
	local into = into :: { [unknown]: unknown }

	for field, value in from do
		into[field] = value
	end

	-- Luau
	return into :: any
end

return {
	union = table_merge_union,
}
