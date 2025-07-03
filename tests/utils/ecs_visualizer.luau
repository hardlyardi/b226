local b2 = require("@b2/")
local ecs = require("./ecs")
local runtest = require("@runtest/")

type Ent = b2.Ent

local style = runtest.util.style
local color = style.color
local b2internal = b2.internal
local ecsinternal = ecs.internal
local eindex_sparse = ecsinternal.eindex_sparse
local eindex_dense = ecsinternal.eindex_dense
local pretty_print = style.from_epsilon
-- local brightblue = color.blue_bright
-- local cyan = color.cyan
-- local grey = color.grey
local magenta = color.magenta

local function non_entity(value: any)
	return `NaE{magenta "<"}{pretty_print(value)}{magenta ">"}`
end

local id_any
local id_entity
local id_pair

function id_entity(entity: number): string
	local id = b2internal.ENT_LO(entity)
	local generation = b2internal.ENT_HI(entity)

	if not eindex_sparse[id] then return `NaE{magenta "<"}{entity}{magenta ">"}` end

	if ecsinternal.eindex_alive_eh(entity) then
		return `Ent{magenta "<"}{pretty_print(id)}{magenta "@"}{pretty_print(generation)}{magenta ">"}`
	else
		return `Ent{magenta "<"}{pretty_print(id)}{magenta "@"}dead-{pretty_print(generation)}{magenta ">"}`
	end
end

function id_pair(pair: number): string
	local first = b2internal.ENT_PAIR_HI(pair)
	local second = b2internal.ENT_PAIR_LO(pair)
	local first_record = ecsinternal.eindex_try_any_record(first)
	local second_record = ecsinternal.eindex_try_any_record(second)
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
	if b2internal.ENT_PAIR_EH(entity) then
		return id_pair(entity)
	else
		return id_entity(entity)
	end
end

local function ent_name(entity: number): string
	if type(entity) ~= "number" then return non_entity(entity) end
	local name = ecs.get(entity :: any, b2.Name)
	if name then
		return pretty_print(name)
	else
		return `${id_any(entity)}`
	end
end

local function ent_fullname(entity: any): string
	if type(entity) ~= "number" then return non_entity(entity) end
	local name = ecs.get(entity :: any, b2.Name)
	if name then
		return `{id_any(entity)}({pretty_print(name)})`
	else
		return `{id_any(entity)}(NoName)`
	end
end

return {
	entity = {
		id = id_any,
		name = ent_name,
		fullname = ent_fullname,
	},
}
