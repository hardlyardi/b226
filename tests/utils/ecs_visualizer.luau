local b2 = require("@b2/")
local ecs = require("./ecs")
local runtest = require("@runtest/")

type Ent = b2.Ent

local style = runtest.util.style
local color = style.color
local b2i = b2.internal
local ecsi = ecs.internal
local pretty_print = style.from_epsilon
local indent_newlines = style.indent_newlines
-- local brightblue = color.blue_bright
-- local cyan = color.cyan
-- local grey = color.grey
local magenta = color.magenta

local INDEX = b2i.INDEX
local eindex_sparse = ecsi.eindex_sparse
local eindex_dense = ecsi.eindex_dense

local function non_entity(value: any)
	return `NaE{magenta "<"}{pretty_print(value)}{magenta ">"}`
end

local id_any
local id_entity
local id_pair

function id_entity(entity: number): string
	local id = b2i.ENT_LO(entity)
	local generation = b2i.ENT_HI(entity)

	if not eindex_sparse[id] then return `NaE{magenta "<"}{entity}{magenta ">"}` end

	if ecsi.eindex_alive_eh(entity) then
		return `Ent{magenta "<"}{pretty_print(id)}{magenta "@"}{pretty_print(generation)}{magenta ">"}`
	else
		return `Ent{magenta "<"}{pretty_print(id)}{magenta "@"}dead-{pretty_print(generation)}{magenta ">"}`
	end
end

function id_pair(pair: number): string
	local first = b2i.ENT_PAIR_HI(pair)
	local second = b2i.ENT_PAIR_LO(pair)
	local first_record = ecsi.eindex_try_any_record(first)
	local second_record = ecsi.eindex_try_any_record(second)
	local first_str: string
	local second_str: string
	if first_record then
		first_str = id_entity(eindex_dense[first_record.dense])
	else
		first_str = `NaE{magenta "<"}{pretty_print(first)}{magenta ">"}`
	end
	if second_record then
		second_str = id_entity(eindex_dense[second_record.dense])
	else
		second_str = `NaE{magenta "<"}{pretty_print(second)}{magenta ">"}`
	end

	return `Pair{magenta "<"}{first_str}{magenta ":"}{second_str}{magenta ">"}`
end

function id_any(entity: any): string
	if type(entity) ~= "number" then return non_entity(entity) end
	if b2i.ENT_PAIR_EH(entity) then
		return id_pair(entity)
	else
		return id_entity(entity)
	end
end

local function ent_name(entity: any): string
	if type(entity) ~= "number" then return `{magenta "$"}{non_entity(entity)}` end
	local name = ecs.get(entity :: any, b2.Name)
	if name then
		return name
	else
		if b2i.ENT_PAIR_EH(entity) then
			return `Pair{magenta "<"}{ent_name(b2i.ENT_PAIR_HI(entity))}{magenta ":"}{ent_name(b2i.ENT_PAIR_LO(entity))}{magenta ">"}`
		end
		return `{magenta "$"}{id_any(entity)}`
	end
end

local function ent_fullname(entity: any): string
	if type(entity) ~= "number" then return non_entity(entity) end
	local name = ecs.get(entity :: any, b2.Name)
	if name then
		return `{id_any(entity)}({name})`
	else
		return `{id_any(entity)}(NoName)`
	end
end

local function ent_data(entity: any): string
	if type(entity) ~= "number" then return `{non_entity(entity)} \{!NO RECORD!}` end
	local erecord = ecsi.eindex_try_matching_record(entity :: number)
	local output_str = `{id_any(entity)} \{`
	if erecord then
		local arch = erecord.arch
		local row = erecord.row
		if row then
			for id, column in arch.columns_map do
				output_str ..= indent_newlines(`\n[{ent_name(id)}] = {pretty_print(column[row])}`)
			end
		end
		output_str ..= "\n}"
	else
		output_str ..= "!NO RECORD!}"
	end
	return output_str
end

local function ent_location(entity: any): string
	if type(entity) ~= "number" then return `{non_entity(entity)} \{!NO RECORD!}` end
	local erecord = ecsi.eindex_try_matching_record(entity :: number)
	local output_str: string
	if erecord then
		local arch = erecord.arch
		local row = erecord.row
		output_str = `{id_any(entity)} row {row} of arch_{arch.location}`
	else
		output_str = `{id_any(entity)} \{!NO RECORD!}`
	end
	return output_str
end

local function component_record(component: number | Ent): string
	local id_record = ecsi.cindex[component :: number]
	if not id_record then return `{ent_name(component)} Record \{!NO RECORD!}` end
	local id_record_flags = INDEX(id_record, b2i.idr_flags)
	local flags_list = {}
	if bit32.btest(id_record_flags, b2i.IDFLAG_TAG) then
		table.insert(flags_list, "DATALESS")
	else
		table.insert(flags_list, "HAS DATA")
	end
	if bit32.btest(id_record_flags, b2i.IDFLAG_DELETE_ONCLEAR) then table.insert(flags_list, "DELETES ON CLEAR") end
	if bit32.btest(id_record_flags, b2i.IDFLAG_DELETE_ONDELETE) then table.insert(flags_list, "DELETES ON DELETE") end
	if bit32.btest(id_record_flags, b2i.IDFLAG_DELETE_ONCLEARTARGET) then
		table.insert(flags_list, "DELETES ON CLEAR TARGET")
	end
	if bit32.btest(id_record_flags, b2i.IDFLAG_DELETE_ONDELETETARGET) then
		table.insert(flags_list, "DELETES ON DELETE TARGET")
	end
	if bit32.btest(id_record_flags, b2i.IDFLAG_EXCLUSIVE) then table.insert(flags_list, "EXCLUSIVE RELATION") end
	if bit32.btest(id_record_flags, b2i.IDFLAG_HOOK_ONADD) then table.insert(flags_list, "HOOK_ONADD") end
	if bit32.btest(id_record_flags, b2i.IDFLAG_HOOK_ONCHANGE) then table.insert(flags_list, "HOOK_ONCHANGE") end
	if bit32.btest(id_record_flags, b2i.IDFLAG_HOOK_ONREM) then table.insert(flags_list, "HOOK_ONREM") end
	return `{ent_name(component)} Record {pretty_print(flags_list)}`
end

local function component_cache(component: number | Ent): string
	local id_record = ecsi.cindex[component :: number]
	if not id_record then return `{ent_name(component)} Cache \{!NO RECORD!}` end
	local id_record_dense_cached = INDEX(id_record, b2i.idr_dense_cached)
	local list = {}
	for _, arch in id_record_dense_cached do
		table.insert(list, `loc = {arch.location}, cols = {#arch.columns_dense}, rows = {#arch.ents}`)
	end
	return pretty_print(list)
end

return {
	entity = {
		id = id_any,
		name = ent_name,
		fullname = ent_fullname,
		data = ent_data,
		location = ent_location,
	},
	component = {
		record = component_record,
		cache = component_cache,
	},
}
