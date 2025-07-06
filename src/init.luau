--!optimize 2
--!native
--[[
- U53:
	Represents a positive integer with a number (a.k.a., double, or F64) value. 2^53 is the maximum unsigned integer a
number in luau can accurately represent. Used primarily for entity Ids.
- U32:
	Represents a positive integer, and implies it can or should be used with bit32 or other 32-bit operations.
- U26:
	Represents a positive integer up to 2^26, which is the maximum size for an array in luau. Because of this, it's used
to signify a table indexer which is a "dense array".
- U24:
	Represents the maximum positive integer a float (F32) can accurately represent, but it is more relevant in this
library as the "low" portion of an entity ID.
- Ptr:
	Represents a position in a buffer.
- Set<Key, Value>:
	Specifically represents sparse mappings of keys and values. If no value is provided, it defaults to true.
- Sorted<Values>:
	Denotes an object will always have sorted values no matter what.
]]
type U53 = number
type U32 = number
type U26 = number
type U24 = number
type Ptr = number
type Set<Key, Value = true> = { [Key]: Value }
type Sorted<Tbl> = Tbl

-- List of entity IDs. Components are entities as well.
type IdList = { U53 }
-- Observable event ID
type ObservableEventId = U53

type ArchLocation = U26
type ArchHash = string
type Row = U26
type Column = { [Row]: any }
type Arch = {
	-- Location of the archetype in the dense list of archetypes.
	location: ArchLocation,
	-- ORDERED_HASH of the archetype's sorted Id list
	hash: ArchHash,

	--[[B2 Archetypes use of Bitsets
	A bitset is a list of single-bit flags. Archetypes in B2 are queried for components via bitsets, where every
	component maps to a specific bit. One way to check if a bitset contains another set of bits (I.e., the "filter") is
	to call bit32.band on the set along with the filter, and check if it is equal to the filter. This works because
	bitwise AND gets the shared bits between two sets - and if the set does not share all of the filter bits, it is
	invalid. Luau only has built-in bitmasking operations for 32-bit numbers, so, single set of bits would limit
	component count to 32. To get around this, we split the bitset into smaller pages which can be tested. Another
	bitset, a "page record" is also stored - which keeps record of which pages are nonzero. Since the record is a U32 as
	well, the paged bitset is limited to 32*32 bits, i.e., 1024 components. Component columns outside of this range are
	not stored as any part of this bitset.
	]]
	pages_record: U32,
	bitset_pages: buffer,

	ids: Sorted<IdList>,

	-- list of rows which are 'empty', - I.e., their value is false, they have been removed, and are waiting to be
	-- removed completely.
	empty_rows: { Row },
	-- entities
	ents: { [Row]: U53 | false },
	columns_dense: { [U26]: Column },
	-- map of component IDs to columns
	columns_map: Set<U53, Column>,
}

--[[Archetype Graph
The archetype graph maps one node to another by adding or removing an ID. Indexing with an ID that is present in this
node attempts to traverse removal, and indexing with an ID that is not present in this node attempts to traverse adding.
- ids:
	A sorted, exact-size buffer holding F64 IDs in this node.
- arch:
	An optional arch. This means a graph node can exist without having an archetype associated with it. Archetype hash is
generated from ids, so any archetype that exists is guaranteed to have a node, but not the other way around.
]]
type ArchGraphNode = {
	[U53]: ArchGraphNode,
	ids: buffer,
	arch: Arch?,
}

--[[ IdRecord
Stores all of the critical information relating to a component and archetypes it is a part of. For performance
purposes, the keys here are actually numbers. IdRecord["_*"] in the type maps to IdRecord[internal.idr_*].
- flags:
	Bitflags describing various pieces of metadata about a component

- arch_sparse:
	A sparse mapping from an archetype object to a dense index.
- arch_count:
	The number of dense indices. Each dense index represents an archetype.
- dense_cached:
	Dense list of archetypes for easy use in iteration.
- dense_column:
	Describes where this component can be found in each archetype.
- dense_counts:
	Used to describe how "many" of this component exist in each archetype. This is only important for relationships
	(a.k.a. pairs.) More info @ https://ajmmertens.medium.com/a-roadmap-to-entity-relationships-5b1d11ebb4eb

- hook_on_add:
	Triggered when the component is added to an entity which does not have it, but before the entity has actually been
modified.
- hook_on_change:
	Triggered when the component's value is set on an entity which already has it, but before the entity has been
modified.
- hook_on_rem:
	Triggered when the component's value is removed from an entity which already has it, but before the entity has been
modified.
]]
type IdRecord = {
	_flags: U32,

	_arch_sparse: Set<Arch, U26>,
	_arch_count: number,
	_dense_cached: { [U26]: Arch },
	_dense_column: { [U26]: number },
	_dense_counts: { [U26]: number },

	_hook_on_add: InternalOnAddHook?,
	_hook_on_change: InternalOnChangeHook?,
	_hook_on_rem: InternalOnRemoveHook?,
}
local idr_flags: "_flags" = 1 :: any
local idr_arch_sparse: "_arch_sparse" = 2 :: any
local idr_arch_count: "_arch_count" = 3 :: any
local idr_dense_cached: "_dense_cached" = 4 :: any
local idr_dense_column: "_dense_column" = 5 :: any
local idr_dense_counts: "_dense_counts" = 6 :: any
local idr_hook_on_add: "_hook_on_add" = 7 :: any
local idr_hook_on_change: "_hook_on_change" = 8 :: any
local idr_hook_on_rem: "_hook_on_rem" = 9 :: any
type InternalOnAddHook = (entity: U53, id: U53, data: any?) -> ()
type InternalOnChangeHook = (entity: U53, id: U53, data: any) -> ()
type InternalOnRemoveHook = (entity: U53, id: U53) -> ()

-- Queries assemble up to 5 filters:
-- - One bitset to check that the archetype's pages_record contains all of the **included** bitset pages of the query.
-- - One map of page Ptrs to included filter bitsets
-- - One list of "slow" components - i.e., components which do not fit into the paged bitset range, such as pairs or tags.
-- - A "without filter" counterpart to the previous two.
-- These are assembled into a "QueryMatcher" function, which checks archetypes against the filters in in the following
-- order:
-- - record filter, then:
-- - included pages, then:
-- - excluded pages, then:
-- - included (slow), then:
-- - excluded (slow).
-- This matcher function is cached in the query object, and is also cached globally based on an ordered hash of the
-- filter components, and, furthermore, if the query is exclusively "fast" - i.e., only checks bitset pages, it will be
-- cached based on the bitset of included and excluded values as a binary string.
type QueryMatcher = (Arch) -> boolean
type QueryInner = () -> (U53, ...any)
type QueryOuter = (QueryMatcher) -> ({ Arch }, { number })

--[[
Runs callback(s) when a certain event happens.
]]
type ArchObserver = {
	callback: (Arch) -> (),
	match: QueryMatcher,
}

type ArchObserverCache = {ArchObserver}

type Observable = Set<ObservableEventId, Set<U53, ArchObserverCache>>

type EntRecord = {
	arch: Arch,
	-- A lack of row signifies the entity is currently 'empty' - i.e., in the root archetype.
	row: Row?,
	dense: U26,
}

local function INDEX<Indexable, Index>(indexable: Indexable, index: Index): index<Indexable, Index>
	return (indexable::any)[index]
end

local function NOOP(): ...any end
local NULL_ARRAY: { any } = table.freeze(table.create(0))
local NULLPTR = buffer.create(0)
local F64_BYTES = 8

--stylua: ignore start
local IDFLAG_TAG            = 2^0
local IDFLAG_DELETE_ONCLEAR = 2^1
local IDFLAG_EXCLUSIVE      = 2^2

local EMASK_LO = 0b10 ^ 24
local EMASK_GENERATION = 0b10^16
local EPAIR_OFFSET = 0b10 ^ 48
local COMPONENT_PAGE_SIZE = 32
local COMPONENT_PAGE_RECORD_SIZE = 32
local MAX_PAGED_COMPONENT = COMPONENT_PAGE_SIZE * COMPONENT_PAGE_RECORD_SIZE
local MAX_COMPONENT = MAX_PAGED_COMPONENT - 64
--[[ecs builtins]]
local B2Component            = MAX_COMPONENT + 1
local B2Name                 = MAX_COMPONENT + 2
local B2Exclusive            = MAX_COMPONENT + 4
local B2Wildcard             = MAX_COMPONENT + 5
local B2ChildOf              = MAX_COMPONENT + 6
--[[cleanup conditons]]
local B2CleanupOnClear       = MAX_COMPONENT + 7
local B2CleanupOnClearTarget = MAX_COMPONENT + 8
--[[cleanup actions]]
local B2CleanupDelete        = MAX_COMPONENT + 9
--[[hooks]]
local B2OnAdd                = MAX_COMPONENT + 10
local B2OnRemove             = MAX_COMPONENT + 11
local B2OnChange             = MAX_COMPONENT + 12
--[[observer events]]
local EventOnArchAdded       = MAX_COMPONENT + 13
local EventOnArchRemoved     = MAX_COMPONENT + 14
--stylua: ignore end

local function ASSERT<Condition>(condition: Condition, msg: string?): typeof(assert(... :: Condition))
	if condition then return condition end
	error(msg, 2)
end

local function ORDERED_HASH(tbl: { any })
	local hashed = table.concat(tbl, "|")
	return hashed
end

local function ENT_LO(entity: U53): U24
	return entity % EMASK_LO
end

local function ENT_HI(entity: U53): number
	return entity // EMASK_LO
end

local function ENT_PAIR(hi: U53, lo: U53): U53
	hi %= EMASK_LO
	hi *= EMASK_LO
	lo %= EMASK_LO
	return hi + lo + EPAIR_OFFSET
end

local function ENT_PAIR_EH(ent: U53): boolean
	return ent > EPAIR_OFFSET
end

local function ENT_PAIR_HI(pair: U53): U24
	return (pair - EPAIR_OFFSET) // EMASK_LO
end

local function ENT_PAIR_LO(pair: U53): U24
	return (pair - EPAIR_OFFSET) % EMASK_LO
end

local function ARCH_APPEND(entity: U53, arch: Arch): number
	local ents = arch.ents
	local ents_top = #ents + 1
	ents[ents_top] = entity
	return ents_top
end

local function ENT_INCREMENT_GENERATION(entity: U53): U53
	if entity > EMASK_LO then
		local id = entity % EMASK_LO
		local generation = entity // EMASK_LO

		local next_gen = generation + 1
		if next_gen >= EMASK_GENERATION then return id end

		return entity + next_gen * EMASK_LO
	end
	return entity + EMASK_LO
end

local function RECORD_ENSURE_ROW(record: EntRecord, record_arch: Arch, entity: U53): Row
	local row = record.row
	if row then return row end
	row = ARCH_APPEND(entity, record_arch)
	record.row = row
	return row
end

local function ecs_new(_: any, disable_auto_ensure_dense: boolean?)
	local ROOT_ARCHETYPE: Arch
	local agraph_root: ArchGraphNode = { ids = NULLPTR }
	local agraph: Set<ArchHash, ArchGraphNode> = { [""] = agraph_root }
	local arch_has_empty_rows: { [Arch]: true } = {}
	local arch_scheduled_for_deletion: { [Arch]: true } = {}
	local archetypes: { [ArchLocation]: Arch } = {}
	local archetypes_count = 0
	local observable: Observable = {}

	local cindex: Set<U53, IdRecord> = {}

	local eindex_dense: Set<number, U53> = {}
	local eindex_sparse: Set<U24, EntRecord> = {}
	local eindex_alive_count: number = 0
	local eindex_id_top: number = 0

	local user_components_count: number = 0

	local function find_observers(event: ObservableEventId, component: U53): { ArchObserver }?
		local cache = observable[event]
		if not cache then
			return nil
		end
		return cache[component]
	end

	--[=[
	Gets a record for an entity if one exists. Runs no safety checks, so, it may retrieve a record from a dead entity or
	from an entirely different generation.
	]=]
	local function eindex_try_any_record(entity: U53): EntRecord?
		return eindex_sparse[ENT_LO(entity)]
	end

	--[[
	Retrieves record for an entity if that entity matches the recorded entity. This guarantees the generation matches,
	but, will not check if the entity is alive. If a generation is incremented manually or a rogue number happens to
	match the entity low portion and full ID including generation.
	]]
	local function eindex_try_matching_record(entity: U53): EntRecord?
		local record = eindex_try_any_record(entity)
		if record and eindex_dense[record.dense] ~= entity then return nil end
		return record
	end

	-- --[[
	-- Retrieves record for an entity if that entity is alive and matches the recorded entity. This guarantees generation
	-- matches and that the id given is alive.
	-- ]]
	-- local function eindex_try_alive_record(entity: U53): EntRecord?
	-- 	local record = eindex_try_any_record(entity)
	-- 	if record then
	-- 		local record_dense = record.dense
	-- 		local dead_eh = record_dense > eindex_alive_count
	-- 		if dead_eh or (eindex_dense[record_dense] ~= entity) then return nil end
	-- 	end
	-- 	return record
	-- end

	local function eindex_alive_eh(entity: U53): boolean
		local record = eindex_try_any_record(entity)
		if record then
			local record_dense = record.dense
			return (record_dense <= eindex_alive_count) and (eindex_dense[record_dense] == entity)
		end
		return false
	end

	local function ecs_existed(entity: U53): boolean
		return eindex_try_any_record(entity) ~= nil
	end

	local function ecs_contains(entity: U53): boolean
		return eindex_alive_eh(entity)
	end

	--[=[
	Gets the latest alive generation of an entity if one exists.
	]=]
	local function ent_try_latest_alive(entity: U53): U53?
		local record = eindex_try_any_record(entity)
		if record then
			return eindex_dense[record.dense] --
		end
		return nil
	end

	-- local function ent_try_latest_alive_safe(entity: U53): U53?
	-- 	local record = eindex_try_any_record(entity)
	-- 	if record then
	-- 		local record_dense = record.dense
	-- 		if (record_dense <= eindex_alive_count) and (eindex_dense[record_dense] == entity) then return entity end
	--
	-- 		if entity > EMASK_LO then return nil end
	--
	-- 		return eindex_dense[record.dense]
	-- 	end
	--
	-- 	return nil
	-- end

	local function eindex_new_id_alive(): U53
		if eindex_alive_count < eindex_id_top then
			eindex_alive_count += 1
			return eindex_dense[eindex_alive_count]
		end

		eindex_id_top += 1
		local id = eindex_id_top

		eindex_alive_count += 1
		eindex_dense[eindex_alive_count] = id
		eindex_sparse[id] = {
			dense = eindex_alive_count,
			arch = ROOT_ARCHETYPE,
		}

		return id
	end

	local function ecs_entity(): U53
		return (eindex_new_id_alive())
	end

	local function arch_ensure_dense(arch: Arch): ()
		local entities = arch.ents
		local columns = arch.columns_dense
		local columns_count = #columns
		local empty_rows = arch.empty_rows
		local empty_rows_count = #empty_rows
		local last_row = #entities
		if empty_rows_count == last_row then
			table.clear(arch.ents)
			for col_index = 1, columns_count do
				local column = columns[col_index]
				if column == NULL_ARRAY then continue end
				table.clear(column)
			end
			arch.empty_rows = {}
			return
		end
		table.sort(empty_rows)
		-- reverse iter so that we're filling the furthest rows last
		for empty_row_index = empty_rows_count, 1, -1 do
			local empty_row = empty_rows[empty_row_index]
			empty_rows[empty_row_index] = nil

			local occupied_entity = entities[last_row]

			if occupied_entity then
				entities[empty_row], entities[last_row] = occupied_entity, nil

				for col_index = 1, columns_count do
					local column = columns[col_index]
					if column == NULL_ARRAY then continue end
					column[empty_row], column[last_row] = column[last_row], nil
				end

				local record = eindex_sparse[ENT_LO(occupied_entity)]
				record.row = empty_row
			else
				--[[
				iterating unoccupied rows from high to low means any empty entity at the end should be **this** entity
				]]
				entities[last_row] = nil
				last_row -= 1
				for col_index = 1, columns_count do
					local column = columns[col_index]
					if column == NULL_ARRAY then continue end
					column[last_row] = nil
				end
			end
		end
	end

	local function find_insert_lo2hi(sorted_list: Sorted<{ number }>, insert: number): U26
		local list_count = #sorted_list
		for list_index = 1, list_count do
			local value = sorted_list[list_index]
			if value > insert then return list_index end
		end
		return list_count + 1
	end

	--[=[
	src_row should always be an occupied row in the src archetype
	]=]
	local function arch_move(src: Arch, src_entity: U53, src_row: Row, dst: Arch, dst_row: Row): ()
		local src_columns = src.columns_dense
		local src_entities = src.ents
		local src_ids = src.ids
		local src_empty_rows = src.empty_rows
		local dst_entities = dst.ents
		local dst_columns_map = dst.columns_map

		local src_columns_count = #src_columns
		src_entities[src_row], dst_entities[dst_row] = false, src_entity

		table.insert(src_empty_rows, src_row)
		arch_has_empty_rows[src] = true

		for columns_index = 1, src_columns_count do
			local src_column = src_columns[columns_index]

			-- tags are given a null array column
			if src_column == NULL_ARRAY then continue end

			local dst_column = dst_columns_map[src_ids[columns_index]]

			-- dst archetype might not have this column
			if dst_column then dst_column[dst_row] = src_column[src_row] end

			-- since this row is unused until made dense, set the src column value to false so the column does not hold a
			-- hard reference to its previous value.
			src_column[src_row] = false
		end

		-- src entity should always be occupied when moved
		local moved_record = eindex_sparse[ENT_LO(src_entity :: U53)]
		moved_record.row = dst_row
		moved_record.arch = dst
	end

	local function ent_move(entity: U53, record: EntRecord, src: Arch, dst: Arch): Row
		local src_row = RECORD_ENSURE_ROW(record, src, entity)
		local dst_row = ARCH_APPEND(entity, dst)
		arch_move(src, entity, src_row, dst, dst_row)
		return dst_row
	end

	local function fetch_at_row(columns_map: index<Arch, "columns_map">, id: U53, row: Row): any?
		local column = columns_map[id]
		if column then return column[row] end
		return column
	end

	local function ecs_get(entity: U53, A: U53, B: U53?, C: U53?, D: U53?, ...: U53): ...any
		local record = eindex_try_matching_record(entity)
		if not record then return end

		local record_arch = record.arch
		local row = RECORD_ENSURE_ROW(record, record_arch, entity)

		local column_map = record_arch.columns_map

		local a = fetch_at_row(column_map, A, row)
		if B then
			local b = fetch_at_row(column_map, B, row)
			if C then
				local c = fetch_at_row(column_map, C, row)
				if D then
					local d = fetch_at_row(column_map, D, row)
					local E = ...
					if E then
						local rest: { any } = { ... }
						for index = 1, #rest do
							rest[index] = fetch_at_row(column_map, rest[index], row)
						end
						return a, b, c, d, table.unpack(rest)
					else
						return a, b, c, d
					end
				else
					return a, b, c
				end
			else
				return a, b
			end
		else
			return a
		end
	end

	local function ecs_bulk_get(entity: U53, ids: { U53 }): { any }?
		local record = eindex_try_matching_record(entity)
		if not record then return nil end

		local record_arch = record.arch
		local row = RECORD_ENSURE_ROW(record, record_arch, entity)

		local column_map = record_arch.columns_map

		local ids_count = #ids
		local data = table.create(ids_count) :: { any }
		for ids_index = 1, ids_count do
			local id = ids[ids_index]
			data[ids_index] = fetch_at_row(column_map, id, row)
		end
		return data
	end

	local function ecs_has(entity: U53, A: U53, B: U53?, C: U53?, D: U53?, ...: U53): boolean
		local record = eindex_try_matching_record(entity)
		if not record then return false end

		local column_map = record.arch.columns_map

		local has_all = column_map[A]
		if has_all then
			if B then
				has_all = column_map[B]
				if has_all then
					if C then
						has_all = column_map[C]
						if has_all then
							if D then
								has_all = column_map[D]
								if has_all then
									local E = ...
									if E then
										local rest: { any } = { ... }
										local rest_count = #rest
										for rest_index = 1, rest_count do
											if column_map[rest_index] then continue end
											has_all = false
											break
										end
										return not not has_all
									else
										return true
									end
								else
									return false
								end
							else
								return true
							end
						else
							return false
						end
					else
						return true
					end
				else
					return false
				end
			else
				return true
			end
		else
			return false
		end
	end

	local function ent_has_inline(entity: U53, id: U53): boolean
		local record = eindex_try_matching_record(entity)
		if not record then return false end

		if record.arch.columns_map[id] then
			return true
		else
			return false
		end
	end

	local function ecs_target(entity: U53, relation: U24, index: number?): U24?
		local record = eindex_try_matching_record(entity)
		if not record then return nil end

		local arch = record.arch
		local wildcard_relation = ENT_PAIR(relation, B2Wildcard)
		local id_record = cindex[wildcard_relation]

		if not id_record then return nil end

		local dense_location = INDEX(id_record, idr_arch_sparse)[arch]
		local count = INDEX(id_record, idr_dense_counts)[dense_location]

		if not count then return nil end

		local column_start = INDEX(id_record, idr_dense_column)[dense_location]

		local id_target_index = column_start
		if index then
			if index > count - 1 then
				return nil
			else
				id_target_index += index
			end
		end

		local id_target = arch.ids[id_target_index]

		if not id_target then return nil end

		local alive = ent_try_latest_alive(ENT_PAIR_LO(id_target))

		return alive
	end

	local function id_record_new(id: U53): IdRecord
		local flags = 0

		local relation = id
		local target: U53?
		if ENT_PAIR_EH(id) then
			-- Luau
			relation = ent_try_latest_alive(ENT_PAIR_HI(id)) :: U53
			target = ent_try_latest_alive(ENT_PAIR_LO(id))
			ASSERT(relation and target, "Internal Error")

			if ecs_target(relation, B2CleanupOnClearTarget) == B2CleanupDelete then
				flags += IDFLAG_DELETE_ONCLEAR
			end
			if ecs_has(relation, B2Exclusive) then
				flags += IDFLAG_EXCLUSIVE
			end
		else
			if ecs_target(relation, B2CleanupOnClear) == B2CleanupDelete then
				flags += IDFLAG_DELETE_ONCLEAR
			end
		end

		local component_eh = ent_has_inline(relation, B2Component) or target and ent_has_inline(target, B2Component)
		if not component_eh then
			flags += IDFLAG_TAG
		end

		local on_add, on_change, on_remove = ecs_get(relation, B2OnAdd, B2OnChange, B2OnRemove)

		local id_record: IdRecord = {
			[idr_flags] = flags,

			[idr_arch_sparse] = {},
			[idr_arch_count] = 0,
			[idr_dense_cached] = {},
			[idr_dense_counts] = {},
			[idr_dense_column] = {},

			[idr_hook_on_add] = on_add,
			[idr_hook_on_change] = on_change,
			[idr_hook_on_rem] = on_remove,
		} :: {
			_flags: typeof(flags),
			_arch_sparse: typeof({}),
			_arch_count: typeof(0),
			_dense_cached: typeof({}),
			_dense_counts: typeof({}),
			_dense_column: typeof({}),
			_hook_on_add: typeof(on_add),
			_hook_on_change: typeof(on_change),
			_hook_on_rem: typeof(on_remove),
		}
		cindex[id] = id_record

		return id_record
	end

	local function id_record_ensure(id: U53): IdRecord
		do
			local id_record = cindex[id]
			if id_record then return id_record end
		end

		return (id_record_new(id))
	end

	local function id_record_arch_append(id_record: IdRecord, id: U53, arch: Arch, count: number): ()
		local id_record_arch_sparse = INDEX(id_record, idr_arch_sparse)
		local id_record_dense_counts = INDEX(id_record, idr_dense_counts)

		local dense_location = id_record_arch_sparse[arch]
		-- id record already contains arch, increment count
		if dense_location then
			local id_record_dense_count = id_record_dense_counts[dense_location] + 1
			id_record_dense_counts[dense_location] = id_record_dense_count
		else
			local id_record_arch_count = INDEX(id_record, idr_arch_count) + 1
			id_record_arch_sparse[arch] = id_record_arch_count;
			(id_record::{[typeof(idr_arch_count)]: index<IdRecord, typeof(idr_arch_count)>})[idr_arch_count] = id_record_arch_count

			INDEX(id_record, idr_dense_cached)[id_record_arch_count] = arch
			INDEX(id_record, idr_dense_column)[id_record_arch_count] = count
			id_record_dense_counts[id_record_arch_count] = 1
		end
	end

	local function ids_pages(ids: Sorted<IdList>): (IdList, { [Ptr]: U32 }, number)
		local unpaged: { U53 } = {}
		local unpaged_count = 0
		local pages_record = 0
		local bitset_pages: { [number]: U32 } = {}
		local ids_count = #ids
		for ids_index = 1, ids_count do
			local id = ids[ids_index]
			if id > COMPONENT_PAGE_SIZE then
				unpaged_count += 1
				unpaged[unpaged_count] = id
				continue
			end

			local id_page = id // COMPONENT_PAGE_SIZE
			local id_page_position = id % COMPONENT_PAGE_SIZE
			local id_page_memory_location = id_page * COMPONENT_PAGE_SIZE

			pages_record = bit32.bor(pages_record, 2 ^ id_page)

			local bitset_page = bitset_pages[id_page_memory_location]
			if bitset_page then
				bitset_page = bit32.bor(bitset_page, 2 ^ id_page_position)
			else
				bitset_page = 2 ^ id_page_position
			end
			bitset_pages[id_page_memory_location] = bitset_page
		end
		return unpaged, bitset_pages, pages_record
	end

	local function pagebuff_from_set(bitset_pages: { [Ptr]: U32 }): buffer
		local buf = buffer.create(MAX_PAGED_COMPONENT)
		for cursor, page in bitset_pages do
			buffer.writeu32(buf, cursor, page)
		end
		return buf
	end

	local function list_from_buff(id_buffer: buffer): { U53 }
		local buff_len = buffer.len(id_buffer)
		local list = table.create(buff_len / F64_BYTES) :: { U53 }
		local list_count = 0
		for ptr = 0, buffer.len(id_buffer) - F64_BYTES, F64_BYTES do
			list_count += 1
			list[list_count] = buffer.readf64(id_buffer, ptr)
		end
		return list
	end

	local function arch_new(agraph_node: ArchGraphNode): Arch
		local ids = agraph_node.ids
		local hash = buffer.tostring(ids)
		local ids_list = list_from_buff(ids)
		local _, pages, pages_record = ids_pages(ids_list)
		local pages_buff = pagebuff_from_set(pages)

		local arch_location = archetypes_count + 1
		archetypes_count = arch_location

		local id_count = #ids_list
		local arch_columns_dense = table.create(id_count) :: { Column }
		local arch_columns_map = {} :: Set<U53, Column>

		local arch: Arch = {
			location = arch_location,
			hash = hash,

			pages_record = pages_record,
			bitset_pages = pages_buff,

			ids = ids_list,

			empty_rows = {},

			columns_map = arch_columns_map,
			columns_dense = arch_columns_dense,
			ents = {},
		}
		archetypes[archetypes_count] = arch
		agraph_node.arch = arch

		for ids_index = 1, id_count do
			local id = ids_list[ids_index]
			local observer_list = find_observers(EventOnArchAdded, id)
			if observer_list then
				local observer_list_count = #observer_list
				for observer_list_index = 1, observer_list_count do
					local observer = observer_list[observer_list_index]
					if observer.match(arch) then
						observer.callback(arch)
					end
				end
			end
			local id_record = id_record_ensure(id)
			local column = if bit32.btest(INDEX(id_record, idr_flags), IDFLAG_TAG) then NULL_ARRAY else {}
			arch_columns_dense[ids_index] = column
			arch_columns_map[id] = column
			id_record_arch_append(id_record, id, arch, ids_index)

			if ENT_PAIR_EH(id) then
				local relation = ENT_PAIR_HI(id)
				local object = ENT_PAIR_LO(id)
				local relation_wildcard = ENT_PAIR(relation, B2Wildcard)
				local relation_wildcard_id_record = id_record_ensure(relation_wildcard)
				id_record_arch_append(relation_wildcard_id_record, relation_wildcard, arch, ids_index)
				arch_columns_map[relation_wildcard] = column

				local wildcard_object = ENT_PAIR(B2Wildcard, object)
				local wildcard_object_id_record = id_record_ensure(wildcard_object)
				id_record_arch_append(wildcard_object_id_record, wildcard_object, arch, ids_index)
				arch_columns_map[wildcard_object] = column
			end
		end

		return arch
	end

	local function agraph_ensure(ids: buffer): ArchGraphNode
		local hash = buffer.tostring(ids)
		do
			local cached = agraph[hash]
			if cached then return cached end
		end

		local node: ArchGraphNode = {
			ids = ids,
		}
		agraph[hash] = node

		return node
	end

	local function agraph_ensure_arch(node: ArchGraphNode): Arch
		do
			local arch = node.arch
			if arch then return arch end
		end

		local arch = arch_new(node)

		return arch
	end

	local function binary_search(buff: buffer, find: number): number?
		local lower = 0
		local upper = (buffer.len(buff) - 8) / 8
		local middle: number
		while lower <= upper do
			middle = lower + ((upper - lower) // 2)
			local ptr = middle * 8
			local id = buffer.readf64(buff, ptr)

			if id < find then
				lower = middle + 1
			elseif id > find then
				upper = middle - 1
			else
				return ptr
			end
		end
		return nil
	end

	local function binary_insert(buff: buffer, search: number): number
		local len = buffer.len(buff)
		local lower = 0
		local upper = (len - 8) / 8
		local ptr = 0
		while lower <= upper do
			if upper <= lower then
				ptr = lower * 8
				if search > buffer.readf64(buff, ptr) then
					ptr += 8
				end
				break
			end

			local middle = lower + ((upper - lower) // 2)
			ptr = middle * 8
			local id = buffer.readf64(buff, ptr)

			if id < search then
				lower = middle + 1
			elseif id > search then
				upper = middle - 1
			else
				return ptr
			end
		end
		return ptr
	end

	local function agraph_traverse_add(src: ArchGraphNode, id: U53): ArchGraphNode
		local src_ids = src.ids
		local src_ids_len = buffer.len(src_ids)

		local traversed_ids_len = src_ids_len + F64_BYTES
		local traversed_ids = buffer.create(traversed_ids_len)
		local insert_ptr = binary_insert(src_ids, id)

		if insert_ptr == src_ids_len then
			buffer.copy(traversed_ids, 0, src_ids)
			buffer.writef64(traversed_ids, insert_ptr, id)
		else
			buffer.copy(traversed_ids, 0, src_ids, 0, insert_ptr)
			buffer.writef64(traversed_ids, insert_ptr, id)
			local second_copy_begin = insert_ptr + F64_BYTES
			if second_copy_begin <= src_ids_len then buffer.copy(traversed_ids, second_copy_begin, src_ids, insert_ptr) end
		end

		local hash = buffer.tostring(traversed_ids)
		do
			local traversed = agraph[hash]
			if traversed then
				traversed[id] = src
				src[id] = traversed
				return traversed
			end
		end

		local traversed: ArchGraphNode = {
			ids = traversed_ids,
			[id] = src,
		}
		src[id] = traversed
		agraph[hash] = traversed

		return traversed
	end

	local function agraph_traverse_add_ensure(src: ArchGraphNode, id: U53): ArchGraphNode
		do
			local traversed = src[id]
			if traversed then return traversed end
		end

		return (agraph_traverse_add(src, id))
	end

	local function agraph_traverse_rem(src: ArchGraphNode, id: U53): ArchGraphNode
		local src_ids = src.ids
		local src_ids_len = buffer.len(src_ids)
		local src_ids_top: Ptr = src_ids_len - F64_BYTES

		local traversed_ids_len = src_ids_len - F64_BYTES
		local traversed_ids = buffer.create(traversed_ids_len)
		local remove_ptr = binary_search(src_ids, id) :: number

		if remove_ptr == src_ids_top then
			buffer.copy(traversed_ids, 0, src_ids)
		else
			buffer.copy(traversed_ids, 0, src_ids, 0, remove_ptr) --
			buffer.copy(traversed_ids, remove_ptr, src_ids, remove_ptr + F64_BYTES) --
		end

		local hash = buffer.tostring(traversed_ids)
		do
			local traversed = agraph[hash]
			if traversed then
				traversed[id] = src
				src[id] = traversed
				return traversed
			end
		end

		local traversed: ArchGraphNode = {
			ids = traversed_ids,
			[id] = src,
		}
		src[id] = traversed
		agraph[hash] = traversed

		return traversed
	end

	local function agraph_traverse_rem_ensure(src: ArchGraphNode, id: U53): ArchGraphNode
		do
			local traversed = src[id]
			if traversed then return traversed end
		end

		return (agraph_traverse_rem(src, id))
	end

	local function arch_traverse_rem_ensure(src: Arch, id: U53): _Arch
		local src_node = agraph[src.hash]
		local dst_node = agraph_traverse_rem_ensure(src_node, id)
		return (agraph_ensure_arch(dst_node))
	end

	local function ecs_add(entity: U53, id: U53): ()
		local record = eindex_try_matching_record(entity)
		if not record then return end

		local record_arch = record.arch
		local didnt_move = record_arch.columns_map[id]
		if didnt_move then return end

		local id_record = id_record_ensure(id)
		local dst_node = agraph[record_arch.hash]
		if ENT_PAIR_EH(id) and bit32.btest(INDEX(id_record, idr_flags), IDFLAG_EXCLUSIVE) then
			local relation = ENT_HI(id)
			local target = ecs_target(entity, relation)
			if target then
				local pair = ENT_PAIR(relation, target)
				dst_node = agraph_traverse_rem_ensure(dst_node, pair) --
				local hook_on_rem = INDEX(id_record, idr_hook_on_rem)
				if hook_on_rem then
					hook_on_rem(entity, pair)
					if record.arch ~= record_arch then
						error("modified entity from inside hook", 2) --
					end
				end
			end
		end

		dst_node = agraph_traverse_add_ensure(dst_node, id)
		local hook_on_add = INDEX(id_record, idr_hook_on_add)
		if hook_on_add then
			hook_on_add(entity, id)
			if record.arch ~= record_arch then
				error("modified entity from inside hook", 2) --
			end
		end

		local dst_arch = agraph_ensure_arch(dst_node)
		ent_move(entity, record, record_arch, dst_arch)
	end

	local function ecs_bulk_add(entity: U53, add_ids: { U53 }): ()
		local record = eindex_try_matching_record(entity)
		if not record then return end

		local record_arch = record.arch
		local record_column_map = record_arch.columns_map

		local add_ids_count = #add_ids

		local dst_node = agraph[record_arch.hash]
		for add_ids_index = 1, add_ids_count do
			local id = add_ids[add_ids_index]
			local id_record = id_record_ensure(id)

			if record_column_map[id] then continue end

			if ENT_PAIR_EH(id) and bit32.btest(INDEX(id_record, idr_flags), IDFLAG_EXCLUSIVE) then
				local relation = ENT_PAIR_HI(id)
				local target = ecs_target(entity, relation)
				if target then
					local pair = ENT_PAIR(relation, target)
					dst_node = agraph_traverse_rem_ensure(dst_node, pair) --
					local hook_on_rem = INDEX(id_record, idr_hook_on_rem)
					if hook_on_rem then hook_on_rem(entity, pair) end
				end
			end

			dst_node = agraph_traverse_add_ensure(dst_node, id)
			local hook_on_add = INDEX(id_record, idr_hook_on_add)
			if hook_on_add then hook_on_add(entity, id) end
		end

		if record.arch ~= record_arch then
			error(
				"modified entity from inside hook"
					.. " (if an exclusive relationship was added, a remove hook may have been triggered)",
				2
			) --
		end

		local dst_arch = agraph_ensure_arch(dst_node)
		ent_move(entity, record, record_arch, dst_arch)
	end

	local function ecs_component(): U53
		local id = user_components_count + 1
		if id > MAX_COMPONENT then error(`Cannot create component above {MAX_COMPONENT}`, 2) end
		user_components_count = id
		ecs_add(id, B2Component)

		return id
	end

	local function ecs_set(entity: U53, id: U53, data: any): ()
		local record = eindex_try_matching_record(entity)
		if not record then return end

		local record_arch = record.arch
		local record_column_map = record_arch.columns_map
		local column: IdList = record_column_map[id]
		local record_row: number
		if column then
			record_row = RECORD_ENSURE_ROW(record, record_arch, entity)
			local id_record = cindex[id]
			local hook_on_change = INDEX(id_record, idr_hook_on_change)
			if hook_on_change then
				hook_on_change(entity, id, data)
				if record.arch ~= record_arch then
					error("modified entity from inside hook", 2) --
				end
			end
		else
			local id_record = id_record_ensure(id)
			local dst_node = agraph[record_arch.hash]
			if ENT_PAIR_EH(id) and bit32.btest(INDEX(id_record, idr_flags), IDFLAG_EXCLUSIVE) then
				local relation = ENT_PAIR_HI(id)
				local target = ecs_target(entity, relation)
				if target then
					local pair = ENT_PAIR(relation, target)
					dst_node = agraph_traverse_rem_ensure(dst_node, pair) --
					local hook_on_rem = INDEX(id_record, idr_hook_on_rem)
					if hook_on_rem then
						hook_on_rem(entity, pair)
						if record.arch ~= record_arch then
							error("modified entity from inside a remove hook (triggered by exclusive relation)", 2) --
						end
					end
				end
			end

			dst_node = agraph_traverse_add_ensure(dst_node, id)
			local hook_on_add = INDEX(id_record, idr_hook_on_add)
			if hook_on_add then
				hook_on_add(entity, id, data)
				if record.arch ~= record_arch then
					error("modified entity from inside an add hook", 2) --
				end
			end

			local dst_arch = agraph_ensure_arch(dst_node)
			record_row = ent_move(entity, record, record_arch, dst_arch)
			column = dst_arch.columns_map[id]
		end
		column[record_row] = data
	end

	local function ecs_bulk_set(entity: U53, set_ids: { U53 }, data: { any }): ()
		local record = eindex_try_matching_record(entity)
		if not record then return end

		local record_arch = record.arch
		local record_column_map = record_arch.columns_map

		local set_ids_count = #set_ids

		local dst_node = agraph[record_arch.hash]
		for set_ids_index = 1, set_ids_count do
			local id = set_ids[set_ids_index]
			local id_record = id_record_ensure(id)
			if record_column_map[id] then
				local hook_on_change = INDEX(id_record, idr_hook_on_change)
				if hook_on_change then hook_on_change(entity, id, data[set_ids_index]) end
				continue
			end
			dst_node = agraph_traverse_add_ensure(dst_node, id)
			local hook_on_add = INDEX(id_record, idr_hook_on_add)
			if hook_on_add then hook_on_add(entity, id, data[set_ids_index]) end
		end

		if record.arch ~= record_arch then
			error("modified entity from inside hook", 2) --
		end

		local dst_arch = agraph_ensure_arch(dst_node)

		local dst_row = ent_move(entity, record, record_arch, dst_arch)
		local dst_column_map = dst_arch.columns_map

		for ids_index = 1, set_ids_count do
			local id = set_ids[ids_index]
			local column = dst_column_map[id]
			if column == NULL_ARRAY then continue end

			local id_data = data[ids_index]
			column[dst_row] = id_data
		end
	end

	local function ecs_remove(entity: U53, id: U53): ()
		local record = eindex_try_matching_record(entity)
		if not record then return end

		local record_arch = record.arch
		local record_column_map = record_arch.columns_map
		local column = record_column_map[id]
		if not column then return end

		local id_record = id_record_ensure(id)
		local hook_on_remove = INDEX(id_record, idr_hook_on_rem)
		if hook_on_remove then
			hook_on_remove(entity, id)
			if record.arch ~= record_arch then
				error("modified entity from inside remove hook", 2) --
			end
		end

		local dst_node = agraph_traverse_rem_ensure(agraph[record_arch.hash], id)
		local dst_arch = agraph_ensure_arch(dst_node)
		ent_move(entity, record, record_arch, dst_arch)
	end

	local function ecs_bulk_remove(entity: U53, remove_ids: { U53 }): ()
		local record = eindex_try_matching_record(entity)
		if not record then return end

		local record_arch = record.arch
		local record_column_map = record_arch.columns_map

		local dst_node = agraph[record_arch.hash]
		for remove_ids_index = #remove_ids, 1, -1 do
			local id = remove_ids[remove_ids_index]

			if not record_column_map[id] then continue end
			local id_record = id_record_ensure(id)

			dst_node = agraph_traverse_rem_ensure(dst_node, id)

			local hook_on_remove = INDEX(id_record, idr_hook_on_rem)
			if hook_on_remove then hook_on_remove(entity, id) end
		end

		if record.arch ~= record_arch then
			error("modified entity from inside hook", 2) --
		end

		local dst_arch = agraph_ensure_arch(dst_node)
		ent_move(entity, record, record_arch, dst_arch)
	end

	--[=[
	this function does not handle firing hooks
	]=]
	local function arch_delete_row(arch: Arch, row: Row): ()
		local columns = arch.columns_dense
		local ents = arch.ents

		local empty_rows = arch.empty_rows
		table.insert(empty_rows, row)
		arch_has_empty_rows[arch] = true

		ents[row] = false

		for columns_index = 1, #columns do
			local column = columns[columns_index]

			-- tags are given a null array column
			if column == NULL_ARRAY then continue end

			-- since this row is unused until made dense at an arbitrary time - i.e., the time of the next query, set the
			-- src column value to false so the column does not hold a hard reference to its previous value.
			column[row] = false
		end
	end

	local function ecs_clear(entity: U53, delete: boolean?): ()
		local record = eindex_try_matching_record(entity)
		if not record then return end

		local relation_wildcard = ENT_PAIR(entity, B2Wildcard)
		local wildcard_object = ENT_PAIR(B2Wildcard, entity)

		if delete then
			local entity_arch = record.arch
			local entity_arch_ids = entity_arch.ids
			for entity_arch_ids_index = 1, #entity_arch_ids do
				local id = entity_arch_ids[entity_arch_ids_index]
				local id_record = cindex[id]
				local hook_on_remove = INDEX(id_record, idr_hook_on_rem)
				if hook_on_remove then
					hook_on_remove(entity, id)
					if record.arch ~= entity_arch then
						error(`entity {entity} was modified while firing hook for {id}`) --
					end
				end
			end
		end

		local id_record = cindex[entity]
		if id_record then
			local dense_cached = INDEX(id_record, idr_dense_cached)
			local arch_count = INDEX(id_record, idr_arch_count)

			if bit32.btest(INDEX(id_record, idr_flags), IDFLAG_DELETE_ONCLEAR) then
				for dense_index = 1, arch_count do
					local cached_arch = dense_cached[dense_index]
					local entities = cached_arch.ents
					for entities_index = 1, #entities do
						local deleting_entity = entities[entities_index]
						if not deleting_entity then continue end
						ecs_clear(deleting_entity, true)
					end
					arch_scheduled_for_deletion[cached_arch] = true
				end
			else
				--[[
				inlining ecs_remove logic in this branch, because we can make a lot of good assumptions:
				- Every entity is alive, and has an Entity Record, because we're iterating archetypes' entity lists.
				- We know the archetype for every entity without looking it up, because the entity is pulled from an
				archetype known to us.
				- We can compute the destination archetype only once for each archetype, avoiding a graph traversal on every
				entity.
				- We can put the check for a remove hook outside of the loop, because we already have the id record for the
				component.
				]]
				local hook_on_remove = INDEX(id_record, idr_hook_on_rem)
				if hook_on_remove then
					for dense_index = 1, arch_count do
						local cached_arch = dense_cached[dense_index]
						local dst = arch_traverse_rem_ensure(cached_arch, entity)

						local entities = cached_arch.ents
						for entities_index = 1, #entities do
							local removing_from = entities[entities_index]
							if not removing_from then continue end
							local entity_record = eindex_try_any_record(removing_from) :: EntRecord
							hook_on_remove(removing_from, entity)
							ent_move(removing_from, entity_record, cached_arch, dst)
						end
						arch_scheduled_for_deletion[cached_arch] = true
					end
				else
					for dense_index = 1, arch_count do
						local cached_arch = dense_cached[dense_index]
						local dst = arch_traverse_rem_ensure(cached_arch, entity)

						local entities = cached_arch.ents
						for entities_index = 1, #entities do
							local removing_from = entities[entities_index]
							if not removing_from then continue end
							local entity_record = eindex_try_any_record(removing_from) :: EntRecord
							ent_move(removing_from, entity_record, cached_arch, dst)
						end
						arch_scheduled_for_deletion[cached_arch] = true
					end
				end
			end
		end

		local wildcard_object_id_record = cindex[wildcard_object]
		if wildcard_object_id_record then
			local dense_cached = INDEX(wildcard_object_id_record, idr_dense_cached)
			local dense_counts = INDEX(wildcard_object_id_record, idr_dense_counts)
			local dense_column = INDEX(wildcard_object_id_record, idr_dense_column)

			local arch_removals: { [Arch]: { U53 } } = {}
			do
				local rem: { U53 } = {}
				local rem_count = 0
				for dense_index = 1, #dense_cached do
					local cached_arch = dense_cached[dense_index]
					local arch_ids = cached_arch.ids
					local count = dense_counts[dense_index]
					local column_start = dense_column[dense_index]

					for columns_index = column_start, column_start + count - 1 do
						local rem_id = arch_ids[columns_index]
						local rem_id_record = cindex[rem_id]
						if bit32.btest(INDEX(rem_id_record, idr_flags), IDFLAG_DELETE_ONCLEAR) then
							local entities = cached_arch.ents
							for entities_index = 1, #entities do
								local deleting = entities[entities_index]
								if not deleting then continue end
								ecs_clear(deleting, true)
							end
							arch_scheduled_for_deletion[cached_arch] = true

							rem_count = 0
							table.clear(rem)
							break
						end
						rem_count += 1
						rem[rem_count] = rem_id
					end

					if rem_count == 0 then continue end

					arch_removals[cached_arch] = rem
					rem = {}
					rem_count = 0
				end
			end
			for arch, removes in arch_removals do
				local dst_node = agraph[arch.hash]
				local removes_count = #removes

				local entities = arch.ents
				local entities_count = #entities

				for removes_index = 1, removes_count do
					local rem_id = removes[removes_index]
					dst_node = agraph_traverse_rem_ensure(dst_node, rem_id)
					local rem_id_record = cindex[rem_id]
					local hook_on_remove = INDEX(rem_id_record, idr_hook_on_rem)
					if hook_on_remove then
						for entities_index = 1, entities_count do
							local removing_from = entities[entities_index]
							if not removing_from then continue end
							hook_on_remove(removing_from, rem_id)
						end
					end
				end

				local dst_arch = agraph_ensure_arch(dst_node)

				for entities_index = 1, entities_count do
					local removing_from = entities[entities_index]
					if not removing_from then continue end
					local entity_record = eindex_try_any_record(removing_from) :: EntRecord
					ent_move(removing_from, entity_record, arch, dst_arch)
				end
				arch_scheduled_for_deletion[arch] = true
			end
		end

		local relation_wildcard_id_record = cindex[relation_wildcard]
		if relation_wildcard_id_record then
			local dense_cached = INDEX(relation_wildcard_id_record, idr_dense_cached)
			local dense_counts = INDEX(relation_wildcard_id_record, idr_dense_counts)
			local dense_column = INDEX(relation_wildcard_id_record, idr_dense_column)

			if bit32.btest(INDEX(relation_wildcard_id_record, idr_flags), IDFLAG_DELETE_ONCLEAR) then
				for dense_index = 1, #dense_cached do
					local cached_arch = dense_cached[dense_index]

					local arch_ids = cached_arch.ids
					local count = dense_counts[dense_index]
					local column_start = dense_column[dense_index]

					for columns_index = column_start, column_start + count do
						local id = arch_ids[columns_index]
						local object = ent_try_latest_alive(ENT_PAIR_LO(id))
						if object ~= entity then continue end

						local entities = cached_arch.ents
						local entities_count = #entities
						for entities_index = entities_count, 1, -1 do
							local deleting_entity = entities[entities_index]
							if not deleting_entity then continue end
							ecs_clear(deleting_entity, true)
						end
						arch_scheduled_for_deletion[cached_arch] = true
						break
					end
				end
			else
				local arch_removals: { [Arch]: { U53 } } = {}
				do
					local rem: { U53 } = {}
					local rem_count = 0
					for dense_index = 1, #dense_cached do
						local cached_arch = dense_cached[dense_index]

						local arch_ids = cached_arch.ids
						for arch_ids_index = 1, #arch_ids do
							local id = arch_ids[arch_ids_index]
							if not ENT_PAIR_EH(id) then continue end

							local relation = ent_try_latest_alive(ENT_PAIR_HI(id))
							local relation_deleting_eh = relation == entity
							if not relation_deleting_eh then continue end

							rem_count += 1
							rem[rem_count] = id
						end

						if rem_count == 0 then continue end

						arch_removals[cached_arch] = rem
						rem = {}
						rem_count = 0
					end
				end
				local hook_on_remove = INDEX(relation_wildcard_id_record, idr_hook_on_rem)
				if hook_on_remove then
					for arch, removes in arch_removals do
						local dst_node = agraph[arch.hash]
						local removes_count = #removes
						for removes_index = 1, removes_count do
							dst_node = agraph_traverse_rem_ensure(dst_node, removes[removes_index])
						end
						local dst = agraph_ensure_arch(dst_node)

						local entities = arch.ents
						local entities_count = #entities
						for entities_index = entities_count, 1, -1 do
							local removing_from = entities[entities_index]
							if not removing_from then continue end
							local entity_record = eindex_try_any_record(removing_from) :: EntRecord
							for removes_index = 1, removes_count do
								hook_on_remove(removing_from, removes[removes_index])
							end
							ent_move(removing_from, entity_record, arch, dst)
						end
						arch_scheduled_for_deletion[arch] = true
					end
				else
					for arch, removes in arch_removals do
						local dst_node = agraph[arch.hash]
						local removes_count = #removes
						for removes_index = 1, removes_count do
							dst_node = agraph_traverse_rem_ensure(dst_node, removes[removes_index])
						end
						local dst = agraph_ensure_arch(dst_node)

						local entities = arch.ents
						local entities_count = #entities
						for entities_index = entities_count, 1, -1 do
							local removing_from = entities[entities_index]
							if not removing_from then continue end
							local entity_record = eindex_try_any_record(removing_from) :: EntRecord
							ent_move(removing_from, entity_record, arch, dst)
						end
						arch_scheduled_for_deletion[arch] = true
					end
				end
			end
		end

		if not delete then return end

		local row = record.row

		if row then
			arch_delete_row(record.arch, row) --
		end

		local dense = record.dense
		local swap_index = eindex_alive_count
		eindex_alive_count = swap_index - 1

		local swap_entity = eindex_dense[swap_index]
		local swap_record = eindex_try_any_record(swap_entity) :: EntRecord

		swap_record.dense = dense
		record.dense = swap_index
		record.arch = ROOT_ARCHETYPE
		record.row = nil

		entity = ENT_INCREMENT_GENERATION(entity)

		eindex_dense[dense] = swap_entity
		eindex_dense[swap_index] = entity
	end

	local function arch_delete(arch: Arch): ()
		if arch == ROOT_ARCHETYPE then return end

		local hash = arch.hash
		local graph_node = agraph[hash]
		for id, node in graph_node do
			if type(id) ~= "number" then continue end
			node[id] = nil
		end
		agraph[hash] = nil

		local arch_location = arch.location
		arch.location = 0
		local swap_location = archetypes_count
		archetypes_count = swap_location - 1

		if arch_location ~= swap_location then
			archetypes[arch_location] = archetypes[swap_location] --
		end

		archetypes[swap_location] = nil

		local ids = arch.ids
		local ids_count = #ids
		for ids_index = 1, ids_count do
			local id = ids[ids_index]
			local observer_list = find_observers(EventOnArchRemoved, id)
			if observer_list then
				local observer_list_count = #observer_list
				for observer_list_index = 1, observer_list_count do
					local observer = observer_list[observer_list_index]
					if observer.match(arch) then
						observer.callback(arch)
					end
				end
			end
			local id_record = cindex[id]

			local arch_sparse = INDEX(id_record, idr_arch_sparse)
			local arch_dense = arch_sparse[arch]
			local dense_cached, dense_column, dense_counts =
				INDEX(id_record, idr_dense_cached), INDEX(id_record, idr_dense_column), INDEX(id_record, idr_dense_counts)

			local arch_count = INDEX(id_record, idr_arch_count)
			local new_arch_count = arch_count - 1
			if new_arch_count == 0 then
				cindex[id] = nil
				continue
			end
			(id_record::{[typeof(idr_arch_count)]: index<IdRecord, typeof(idr_arch_count)>})[idr_arch_count] = new_arch_count

			if arch_dense ~= arch_count then
				local cached = dense_cached[arch_count]
				dense_cached[arch_dense] = cached
				dense_column[arch_dense] = dense_column[arch_count]
				dense_counts[arch_dense] = dense_counts[arch_count]
				arch_sparse[cached] = arch_dense
			end
			dense_cached[arch_count] = nil
			dense_column[arch_count] = nil
			dense_counts[arch_count] = nil
			arch_sparse[arch] = nil
		end
	end

	local function ecs_cleanup(): ()
		for archetypes_index = 1, archetypes_count do
			local arch = archetypes[archetypes_index]
			arch_ensure_dense(arch)
			if arch.ents[1] then continue end
			arch_delete(arch)
		end
	end

	local function ecs_ensure_dense_archetypes(): ()
		for arch in arch_has_empty_rows do
			arch_ensure_dense(arch)
		end
		for arch in arch_scheduled_for_deletion do
			if arch.ents[1] == nil then arch_delete(arch) end
		end
		arch_has_empty_rows = {}
		arch_scheduled_for_deletion = {}
	end

	local query_matcher_cache: { [string]: QueryMatcher } = setmetatable({}, { __mode = "v" })
	local function query_matcher_hash(query_with: IdList, query_without: IdList): string
		local with_hash = ORDERED_HASH(query_with)
		local without_hash = ORDERED_HASH(query_without)
		local hashed = `{with_hash}\127{without_hash}`
		return hashed
	end
	local function query_matcher(query_with: IdList, query_without: IdList): QueryMatcher
		local hashed_fast = query_matcher_hash(query_with, query_without)
		do
			local cached = query_matcher_cache[hashed_fast]
			if cached then return cached end
		end

		local query_with_slow, query_with_pages, with_pages_record = ids_pages(query_with)
		local query_without_slow, query_without_pages = ids_pages(query_without)

		local query_with_slow_count = #query_with_slow
		local query_without_slow_count = #query_without_slow

		local has_wisl = query_with_slow_count ~= 0
		local has_wosl = query_without_slow_count ~= 0
		local has_wipg = next(query_with_pages)
		local has_wopg = next(query_without_pages)

		local hash_bitset: string?

		if not (has_wisl or has_wosl) then
			local wigtset = if has_wipg then pagebuff_from_set(query_with_pages) else NULLPTR
			local wogtset = if has_wopg then pagebuff_from_set(query_without_pages) else NULLPTR
			hash_bitset = `{buffer.tostring(wigtset)}{buffer.tostring(wogtset)}`
			local cached = query_matcher_cache[hash_bitset]
			if cached then return cached end
		end

		local query_match
		if has_wipg then
			if has_wopg then
				if has_wisl then
					if has_wosl then
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_with_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local match_eh = bit32.band(arch_type, test) == test

								if not match_eh then return false end
							end

							for cursor, test in query_without_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local arch_contains_excluded_fast = bit32.btest(arch_type, test)

								if arch_contains_excluded_fast then return false end
							end

							local columns_sparse = arch.columns_map

							for slow_index = 1, query_with_slow_count do
								local with = query_with_slow[slow_index]
								if not columns_sparse[with] then return false end
							end

							for slow_index = 1, query_without_slow_count do
								local without = query_without_slow[slow_index]
								if columns_sparse[without] then return false end
							end

							return true
						end
					else
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_with_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local match_eh = bit32.band(arch_type, test) == test

								if not match_eh then return false end
							end

							for cursor, test in query_without_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local arch_contains_excluded_fast = bit32.btest(arch_type, test)

								if arch_contains_excluded_fast then return false end
							end

							local columns_sparse = arch.columns_map

							for slow_index = 1, query_with_slow_count do
								local with = query_with_slow[slow_index]
								if not columns_sparse[with] then return false end
							end

							return true
						end
					end
				else
					if has_wosl then
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_with_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local match_eh = bit32.band(arch_type, test) == test

								if not match_eh then return false end
							end

							for cursor, test in query_without_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local arch_contains_excluded_fast = bit32.btest(arch_type, test)

								if arch_contains_excluded_fast then return false end
							end

							local columns_sparse = arch.columns_map

							for slow_index = 1, query_without_slow_count do
								local without = query_without_slow[slow_index]
								if columns_sparse[without] then return false end
							end

							return true
						end
					else
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_with_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local match_eh = bit32.band(arch_type, test) == test

								if not match_eh then return false end
							end

							for cursor, test in query_without_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local arch_contains_excluded_fast = bit32.btest(arch_type, test)

								if arch_contains_excluded_fast then return false end
							end

							return true
						end
					end
				end
			else
				if has_wisl then
					if has_wosl then
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_with_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local match_eh = bit32.band(arch_type, test) == test

								if not match_eh then return false end
							end

							local columns_sparse = arch.columns_map

							for slow_index = 1, query_with_slow_count do
								local with = query_with_slow[slow_index]
								if not columns_sparse[with] then return false end
							end

							for slow_index = 1, query_without_slow_count do
								local without = query_without_slow[slow_index]
								if columns_sparse[without] then return false end
							end

							return true
						end
					else
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_with_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local match_eh = bit32.band(arch_type, test) == test

								if not match_eh then return false end
							end

							local columns_sparse = arch.columns_map

							for slow_index = 1, query_with_slow_count do
								local with = query_with_slow[slow_index]
								if not columns_sparse[with] then return false end
							end

							return true
						end
					end
				else
					if has_wosl then
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_with_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local match_eh = bit32.band(arch_type, test) == test

								if not match_eh then return false end
							end

							local columns_sparse = arch.columns_map

							for slow_index = 1, query_without_slow_count do
								local without = query_without_slow[slow_index]
								if columns_sparse[without] then return false end
							end

							return true
						end
					else
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_with_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local match_eh = bit32.band(arch_type, test) == test

								if not match_eh then return false end
							end

							return true
						end
					end
				end
			end
		else
			if has_wopg then
				if has_wisl then
					if has_wosl then
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_without_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local arch_contains_excluded_fast = bit32.btest(arch_type, test)

								if arch_contains_excluded_fast then return false end
							end

							local columns_sparse = arch.columns_map

							for slow_index = 1, query_with_slow_count do
								local with = query_with_slow[slow_index]
								if not columns_sparse[with] then return false end
							end

							for slow_index = 1, query_without_slow_count do
								local without = query_without_slow[slow_index]
								if columns_sparse[without] then return false end
							end

							return true
						end
					else
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_without_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local arch_contains_excluded_fast = bit32.btest(arch_type, test)

								if arch_contains_excluded_fast then return false end
							end

							local columns_sparse = arch.columns_map

							for slow_index = 1, query_with_slow_count do
								local with = query_with_slow[slow_index]
								if not columns_sparse[with] then return false end
							end

							return true
						end
					end
				else
					if has_wosl then
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_without_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local arch_contains_excluded_fast = bit32.btest(arch_type, test)

								if arch_contains_excluded_fast then return false end
							end

							local columns_sparse = arch.columns_map

							for slow_index = 1, query_without_slow_count do
								local without = query_without_slow[slow_index]
								if columns_sparse[without] then return false end
							end

							return true
						end
					else
						function query_match(arch: Arch): boolean
							do
								local match_fast = bit32.band(arch.pages_record, with_pages_record) == with_pages_record
								if not match_fast then return false end
							end

							local arch_bitset = arch.bitset_pages

							for cursor, test in query_without_pages do
								local arch_type = buffer.readu32(arch_bitset, cursor)

								local arch_contains_excluded_fast = bit32.btest(arch_type, test)

								if arch_contains_excluded_fast then return false end
							end

							return true
						end
					end
				end
			else
				if has_wisl then
					if has_wosl then
						function query_match(arch: Arch): boolean
							local columns_sparse = arch.columns_map

							for slow_index = 1, query_with_slow_count do
								local with = query_with_slow[slow_index]
								if not columns_sparse[with] then return false end
							end

							for slow_index = 1, query_without_slow_count do
								local without = query_without_slow[slow_index]
								if columns_sparse[without] then return false end
							end

							return true
						end
					else
						function query_match(arch: Arch): boolean
							local columns_sparse = arch.columns_map

							for slow_index = 1, query_with_slow_count do
								local with = query_with_slow[slow_index]
								if not columns_sparse[with] then return false end
							end

							return true
						end
					end
				else
					if has_wosl then
						function query_match(arch: Arch): boolean
							local columns_sparse = arch.columns_map

							for slow_index = 1, query_without_slow_count do
								local without = query_without_slow[slow_index]
								if columns_sparse[without] then return false end
							end

							return true
						end
					else
						function query_match(arch: Arch): boolean
							return true
						end
					end
				end
			end
		end

		query_matcher_cache[hashed_fast] = query_match
		if hash_bitset then query_matcher_cache[hash_bitset] = query_match end

		return query_match
	end

	local function ecs_each(id: U53): () -> (U53?)
		local id_record = cindex[id]
		if not id_record then return NOOP :: () -> (U53?) end

		local arch_count = INDEX(id_record, idr_arch_count)
		if arch_count == 0 then
			return NOOP :: () -> (U53?)
		end
		local dense_cached = INDEX(id_record, idr_dense_cached)
		local dense_ent_count = table.create(arch_count) :: { number }
		for dense_index = 1, arch_count do
			dense_ent_count[dense_index] = #dense_cached[dense_index].ents
		end

		local arch = dense_cached[arch_count]
		local row = dense_ent_count[arch_count]
		local entities = arch.ents

		local function ecs_each_iterator(): U53?
			local entity = entities[row]
			while not entity do
				row -= 1
				if row <= 0 then
					arch_count -= 1
					
					if arch_count == 0 then return nil end

					arch = dense_cached[arch_count]
					entities = arch.ents
					row = dense_ent_count[arch_count]
				end
				entity = entities[row]
			end
			row -= 1
			-- while loop condition should have handled this typestate
			return entity :: typeof(assert(entity))
		end

		return ecs_each_iterator
	end

	local queryobj = {}
	local queryobj_metatable = { __index = queryobj }
	type QueryIdentityInternal = setmetatable<{
		_reads: { U53 },
		_sparse: { [U53]: number },
		_with_dense: { U53 },
		_without_dense: { U53 },
		_observed_archs: { Arch }?,
		_matcher: QueryMatcher?,
	}, typeof(queryobj_metatable)>
	local function ecs_query(...: U53): QueryIdentityInternal
		local sparse = {}
		local with_dense = { ... }
		for dense, id in with_dense do
			sparse[id] = dense
		end
		local self = setmetatable({
			_reads = table.clone(with_dense),
			_sparse = sparse,
			_with_dense = with_dense,
			_without_dense = {},
			_matcher = nil :: QueryMatcher?,
			_observed_archs = nil :: { Arch }?,
		}, queryobj_metatable)
		return self
	end

	function queryobj.with(self: QueryIdentityInternal, ...: U53): QueryIdentityInternal
		local dense = self._with_dense
		local dense_count = #dense
		local sparse = self._sparse
		local add_with = { ... }
		local add_with_count = #add_with
		for add_with_index = 1, add_with_count do
			local add = add_with[add_with_index]
			if sparse[add] then error(`query already contains id {add}`, 2) end
			dense_count += 1
			dense[dense_count] = add
			sparse[add] = dense_count
		end
		return self
	end

	function queryobj.without(self: QueryIdentityInternal, ...: U53): QueryIdentityInternal
		local dense = self._without_dense
		local dense_count = #dense
		local sparse = self._sparse
		local add_without = { ... }
		local add_without_count = #add_without
		for add_without_index = 1, add_without_count do
			local add = add_without[add_without_index]
			if sparse[add] then error(`query already contains id {add}`, 2) end
			dense_count += 1
			dense[dense_count] = add
			sparse[add] = dense_count
		end
		return self
	end

	function queryobj.match(self: QueryIdentityInternal): QueryMatcher
		local matcher = self._matcher :: typeof(assert(self._matcher))
		if not matcher then
			matcher = query_matcher(self._with_dense, self._without_dense)
			self._matcher = matcher
		end
		return matcher
	end

	function queryobj.archetypes(self: QueryIdentityInternal): { Arch }
		local with_dense = self._with_dense
		local without_dense = self._without_dense
		local matcher = self._matcher :: typeof(assert(self._matcher))
		if not matcher then
			matcher = query_matcher(with_dense, without_dense)
			self._matcher = matcher
		end

		--[[
		IdRecord stores a cache of which archetypes an Id is a part of. Go through each Ids record, and select the one
		with the smallest number of cached archetypes. This optimization alone can make queries for large numbers of
		components incredibly optimized.
		]]
		local cached_archs = archetypes
		local cached_count = archetypes_count
		local maximally_exclusive_id_record: IdRecord?
		for with_dense_index = 1, #with_dense do
			local id = with_dense[with_dense_index]
			local id_record = cindex[id]

			if not id_record then continue end

			local arch_count = INDEX(id_record, idr_arch_count)

			if arch_count > cached_count then continue end

			maximally_exclusive_id_record = id_record
			cached_count = arch_count
		end
		if maximally_exclusive_id_record then
			cached_archs = INDEX(maximally_exclusive_id_record, idr_dense_cached)
		end

		local compatible = {}
		local compatible_count = 0
		for cached_archs_index = 1, cached_count do
			local cached_arch = cached_archs[cached_archs_index]
			if matcher(cached_arch) then
				compatible_count += 1
				compatible[compatible_count] = cached_arch
			end
		end

		return compatible
	end

	function queryobj.entities(self: QueryIdentityInternal): () -> (U53?, ...any)
		if not disable_auto_ensure_dense then ecs_ensure_dense_archetypes() end
		local compatible_archs = self:archetypes()
		local compatible_count = #compatible_archs

		if compatible_count == 0 then
			return NOOP :: () -> (U53?)
		end

		local reads = self._reads
		local reads_count = #reads

		local compatible_ent_counts: {U26} = {}
		local compatible_reads: {{Column}} = {}
		for compatible_index = 1, compatible_count do
			local compatible_arch = compatible_archs[compatible_index]
			local columns_map = compatible_arch.columns_map
			compatible_ent_counts[compatible_index] = #compatible_arch.ents

			local reads_list = table.create(reads_count) :: {Column}
			for reads_index = 1, reads_count do
				local read_id = reads[reads_index]
				reads_list[read_id] = columns_map[read_id] or NULL_ARRAY
			end
			compatible_reads[compatible_index] = reads_list
		end

		local arch = compatible_archs[compatible_count]
		local entities = arch.ents
		local columns_map_init = arch.columns_map
		local row = compatible_ent_counts[compatible_count]

		local query_iter: () -> (U53?, ...any)
		if reads_count == 1 then
			local A = reads[1]
			local col1 = columns_map_init[A] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row]
			end
		elseif reads_count == 2 then
			local A = reads[1]
			local B = reads[2]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row]
			end
		elseif reads_count == 3 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row]
			end
		elseif reads_count == 4 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row]
			end
		elseif reads_count == 5 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local E = reads[5]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			local col5 = columns_map_init[E] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
						col5 = columns_map[E] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row], col5[read_row]
			end
		elseif reads_count == 6 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local E = reads[5]
			local F = reads[6]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			local col5 = columns_map_init[E] or NULL_ARRAY
			local col6 = columns_map_init[F] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
						col5 = columns_map[E] or NULL_ARRAY
						col6 = columns_map[F] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row], col5[read_row], col6[read_row]
			end
		elseif reads_count == 7 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local E = reads[5]
			local F = reads[6]
			local G = reads[7]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			local col5 = columns_map_init[E] or NULL_ARRAY
			local col6 = columns_map_init[F] or NULL_ARRAY
			local col7 = columns_map_init[G] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
						col5 = columns_map[E] or NULL_ARRAY
						col6 = columns_map[F] or NULL_ARRAY
						col7 = columns_map[G] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row], col5[read_row], col6[read_row], col7[read_row]
			end
		elseif reads_count == 8 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local E = reads[5]
			local F = reads[6]
			local G = reads[7]
			local H = reads[8]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			local col5 = columns_map_init[E] or NULL_ARRAY
			local col6 = columns_map_init[F] or NULL_ARRAY
			local col7 = columns_map_init[G] or NULL_ARRAY
			local col8 = columns_map_init[H] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
						col5 = columns_map[E] or NULL_ARRAY
						col6 = columns_map[F] or NULL_ARRAY
						col7 = columns_map[G] or NULL_ARRAY
						col8 = columns_map[H] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row], col5[read_row], col6[read_row], col7[read_row], col8[read_row]
			end
		elseif reads_count == 0 then
			error("needs to read at least 1 component", 2)
		else
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local E = reads[5]
			local F = reads[6]
			local G = reads[7]
			local H = reads[8]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			local col5 = columns_map_init[E] or NULL_ARRAY
			local col6 = columns_map_init[F] or NULL_ARRAY
			local col7 = columns_map_init[G] or NULL_ARRAY
			local col8 = columns_map_init[H] or NULL_ARRAY
			local colrest_count = reads_count - 8
			local colrest = table.create(colrest_count) :: {Column}
			for colrest_index = 1, colrest_count do
				local Id = reads[8 + colrest_index]
				colrest[colrest_index] = columns_map_init[Id] or NULL_ARRAY
			end
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
						col5 = columns_map[E] or NULL_ARRAY
						col6 = columns_map[F] or NULL_ARRAY
						col7 = columns_map[G] or NULL_ARRAY
						col8 = columns_map[H] or NULL_ARRAY
						colrest = table.create(colrest_count) :: {Column}
						for colrest_index = 1, colrest_count do
							local Id = reads[8 + colrest_index]
							colrest[colrest_index] = columns_map[Id] or NULL_ARRAY
						end
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				local read_rest = table.create(colrest_count)
				for colrest_index = 1, colrest_count do
					read_rest[colrest_index] = colrest[colrest_index][read_row]
				end
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row], col5[read_row], col6[read_row], col7[read_row], col8[read_row], table.unpack(read_rest)
			end
		end

		return query_iter
	end

	function queryobj.observe_added(self: QueryIdentityInternal, callback: (Arch) -> ()): ()
		local added_event = observable[EventOnArchAdded]
		if not added_event then
			added_event = {} :: index<typeof(observable), ObservableEventId>
		end

		local with_dense = self._with_dense
		local First = ASSERT(with_dense[1], "Internal Error")

		local added_cached: index<typeof(added_event), U53>
		for with_index = 1, #with_dense do
			local cache = added_event[with_dense[with_index]]
			if cache then
				added_cached = cache
				break
			end
		end
		if not added_cached then
			added_cached = {} :: index<typeof(added_event), U53>
			added_event[First] = added_cached
		end
	end

	function queryobj.observe_removed(self: QueryIdentityInternal, callback: (Arch) -> ()): ()
		local removed_event = observable[EventOnArchRemoved]
		if not removed_event then
			removed_event = {} :: index<typeof(observable), ObservableEventId>
		end

		local with_dense = self._with_dense
		local First = ASSERT(with_dense[1], "Internal Error")

		local removed_cached: index<typeof(removed_event), U53>
		for with_index = 1, #with_dense do
			local cache = removed_event[with_dense[with_index]]
			if cache then
				removed_cached = cache
				break
			end
		end
		local observer: ArchObserver = {
			match = self:match(),
			callback = callback,
		}
		if not removed_cached then
			removed_cached = {observer} :: index<typeof(removed_event), U53>
			removed_event[First] = removed_cached
		else
			table.insert(removed_cached, observer)
		end
	end

	function queryobj.archetypes_cached(self: QueryIdentityInternal): { Arch }
		do
			local cached = self._observed_archs
			if cached then return cached end
		end
		local with_dense = self._with_dense
		local First = with_dense[1]
		if not First then
			error("cannot get archetype cache from blank query")
		end

		local added_event = observable[EventOnArchAdded]
		if not added_event then
			added_event = {} :: index<typeof(observable), ObservableEventId>
		end
		local added_cached: index<typeof(added_event), U53>
		for with_index = 1, #with_dense do
			local cache = added_event[with_dense[with_index]]
			if cache then
				added_cached = cache
				break
			end
		end
		if not added_cached then
			added_cached = {} :: index<typeof(added_event), U53>
			added_event[First] = added_cached
		end

		local removed_event = observable[EventOnArchRemoved]
		if not removed_event then
			removed_event = {} :: index<typeof(observable), ObservableEventId>
		end
		local removed_cached: index<typeof(removed_event), U53>
		for with_index = 1, #with_dense do
			local cache = removed_event[with_dense[with_index]]
			if cache then
				removed_cached = cache
				break
			end
		end
		if not removed_cached then
			removed_cached = {} :: index<typeof(removed_event), U53>
			removed_event[First] = removed_cached
		end

		local arch_cache_dense: {[U26]: Arch} = self:archetypes()
		local arch_cache_dense_count = #arch_cache_dense
		local arch_cache_sparse: Set<Arch, U26> = {}
		for dense_index = 1, arch_cache_dense_count do
			local arch = arch_cache_dense[dense_index]
			arch_cache_sparse[arch] = dense_index
		end

		local function observing_added(arch: Arch): ()
			local dense_location = arch_cache_dense_count + 1
			arch_cache_dense_count = dense_location
			arch_cache_dense[arch_cache_dense_count] = arch
		end

		local function observing_removed(arch: Arch): ()
			local dense_location = arch_cache_sparse[arch]
			local dense_swap = arch_cache_dense_count
			arch_cache_dense_count = dense_swap - 1
			arch_cache_sparse[arch] = nil
			if dense_location == dense_swap then
				arch_cache_dense[dense_location] = nil
			else
				local swap_arch = arch_cache_dense[dense_swap]
				arch_cache_dense[dense_swap] = nil

				arch_cache_sparse[swap_arch] = dense_location
				arch_cache_dense[dense_location] = swap_arch
			end
		end

		self:observe_added(observing_added)
		self:observe_removed(observing_removed)

		return arch_cache_dense
	end

	function queryobj.entities_cached(self: QueryIdentityInternal): () -> (U53?, ...any)
		if not disable_auto_ensure_dense then ecs_ensure_dense_archetypes() end
		local compatible_archs = self:archetypes_cached()
		local compatible_count = #compatible_archs

		if compatible_count == 0 then
			return NOOP :: () -> (U53?)
		end

		local reads = self._reads
		local reads_count = #reads

		local compatible_ent_counts: {U26} = {}
		local compatible_reads: {{Column}} = {}
		for compatible_index = 1, compatible_count do
			local compatible_arch = compatible_archs[compatible_index]
			local columns_map = compatible_arch.columns_map
			compatible_ent_counts[compatible_index] = #compatible_arch.ents

			local reads_list = table.create(reads_count) :: {Column}
			for reads_index = 1, reads_count do
				local read_id = reads[reads_index]
				reads_list[read_id] = columns_map[read_id] or NULL_ARRAY
			end
			compatible_reads[compatible_index] = reads_list
		end

		local arch = compatible_archs[compatible_count]
		local entities = arch.ents
		local columns_map_init = arch.columns_map
		local row = compatible_ent_counts[compatible_count]

		local query_iter: () -> (U53?, ...any)
		if reads_count == 1 then
			local A = reads[1]
			local col1 = columns_map_init[A] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row]
			end
		elseif reads_count == 2 then
			local A = reads[1]
			local B = reads[2]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row]
			end
		elseif reads_count == 3 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row]
			end
		elseif reads_count == 4 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row]
			end
		elseif reads_count == 5 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local E = reads[5]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			local col5 = columns_map_init[E] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
						col5 = columns_map[E] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row], col5[read_row]
			end
		elseif reads_count == 6 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local E = reads[5]
			local F = reads[6]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			local col5 = columns_map_init[E] or NULL_ARRAY
			local col6 = columns_map_init[F] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
						col5 = columns_map[E] or NULL_ARRAY
						col6 = columns_map[F] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row], col5[read_row], col6[read_row]
			end
		elseif reads_count == 7 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local E = reads[5]
			local F = reads[6]
			local G = reads[7]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			local col5 = columns_map_init[E] or NULL_ARRAY
			local col6 = columns_map_init[F] or NULL_ARRAY
			local col7 = columns_map_init[G] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
						col5 = columns_map[E] or NULL_ARRAY
						col6 = columns_map[F] or NULL_ARRAY
						col7 = columns_map[G] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row], col5[read_row], col6[read_row], col7[read_row]
			end
		elseif reads_count == 8 then
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local E = reads[5]
			local F = reads[6]
			local G = reads[7]
			local H = reads[8]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			local col5 = columns_map_init[E] or NULL_ARRAY
			local col6 = columns_map_init[F] or NULL_ARRAY
			local col7 = columns_map_init[G] or NULL_ARRAY
			local col8 = columns_map_init[H] or NULL_ARRAY
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
						col5 = columns_map[E] or NULL_ARRAY
						col6 = columns_map[F] or NULL_ARRAY
						col7 = columns_map[G] or NULL_ARRAY
						col8 = columns_map[H] or NULL_ARRAY
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row], col5[read_row], col6[read_row], col7[read_row], col8[read_row]
			end
		elseif reads_count == 0 then
			error("needs to read at least 1 component", 2)
		else
			local A = reads[1]
			local B = reads[2]
			local C = reads[3]
			local D = reads[4]
			local E = reads[5]
			local F = reads[6]
			local G = reads[7]
			local H = reads[8]
			local col1 = columns_map_init[A] or NULL_ARRAY
			local col2 = columns_map_init[B] or NULL_ARRAY
			local col3 = columns_map_init[C] or NULL_ARRAY
			local col4 = columns_map_init[D] or NULL_ARRAY
			local col5 = columns_map_init[E] or NULL_ARRAY
			local col6 = columns_map_init[F] or NULL_ARRAY
			local col7 = columns_map_init[G] or NULL_ARRAY
			local col8 = columns_map_init[H] or NULL_ARRAY
			local colrest_count = reads_count - 8
			local colrest = table.create(colrest_count) :: {Column}
			for colrest_index = 1, colrest_count do
				local Id = reads[8 + colrest_index]
				colrest[colrest_index] = columns_map_init[Id] or NULL_ARRAY
			end
			function query_iter(): (U53?, ...any)
				local read_row = row
				local ent = entities[read_row]
				while not ent do
					read_row -= 1
					if read_row <= 0 then
						compatible_count -= 1
						if compatible_count == 0 then return nil end

						arch = compatible_archs[compatible_count]
						entities = arch.ents
						local columns_map = arch.columns_map
						read_row = compatible_ent_counts[compatible_count]
						col1 = columns_map[A] or NULL_ARRAY
						col2 = columns_map[B] or NULL_ARRAY
						col3 = columns_map[C] or NULL_ARRAY
						col4 = columns_map[D] or NULL_ARRAY
						col5 = columns_map[E] or NULL_ARRAY
						col6 = columns_map[F] or NULL_ARRAY
						col7 = columns_map[G] or NULL_ARRAY
						col8 = columns_map[H] or NULL_ARRAY
						colrest = table.create(colrest_count) :: {Column}
						for colrest_index = 1, colrest_count do
							local Id = reads[8 + colrest_index]
							colrest[colrest_index] = columns_map[Id] or NULL_ARRAY
						end
					end
					ent = entities[read_row]
				end
				row = read_row - 1
				local read_rest = table.create(colrest_count)
				for colrest_index = 1, colrest_count do
					read_rest[colrest_index] = colrest[colrest_index][read_row]
				end
				return ent :: U53, col1[read_row], col2[read_row], col3[read_row], col4[read_row], col5[read_row], col6[read_row], col7[read_row], col8[read_row], table.unpack(read_rest)
			end
		end

		return query_iter
	end

	ROOT_ARCHETYPE = agraph_ensure_arch(agraph_root)

	for _ = 1, MAX_PAGED_COMPONENT do
		eindex_new_id_alive()
	end

	ecs_add(B2Name, B2Component)
	ecs_set(B2Component, B2Name, "B2Component")
	ecs_set(B2Name, B2Name, "B2Name")
	ecs_set(B2Wildcard, B2Name, "B2Wildcard")
	ecs_set(B2ChildOf, B2Name, "B2ChildOf")
	ecs_set(B2CleanupOnClear, B2Name, "B2CleanupOnClear")
	ecs_set(B2CleanupOnClearTarget, B2Name, "B2CleanupOnClearTarget")
	ecs_set(B2CleanupDelete, B2Name, "B2CleanupDelete")
	ecs_set(B2OnAdd, B2Name, "B2OnAdd")
	ecs_set(B2OnChange, B2Name, "B2OnChange")
	ecs_set(B2OnRemove, B2Name, "B2OnRemove")
	ecs_add(B2OnChange, B2Component)
	ecs_add(B2OnAdd, B2Component)
	ecs_add(B2OnRemove, B2Component)
	ecs_add(B2ChildOf, ENT_PAIR(B2CleanupOnClearTarget, B2CleanupDelete))
	ecs_add(B2ChildOf, B2Exclusive)

	--stylua: ignore
	return {
		contains = ecs_contains,
		ecs_existed = ecs_existed,
		each = ecs_each,
		entity = ecs_entity,
		component = ecs_component,
		ensure_dense_archetypes = ecs_ensure_dense_archetypes,
		cleanup = ecs_cleanup,
		target = ecs_target,
		has = ecs_has,
		add = ecs_add,
		set = ecs_set,
		get = ecs_get,
		remove = ecs_remove,
		ecs_target = ecs_target,
		bulk_add = ecs_bulk_add,
		bulk_set = ecs_bulk_set,
		bulk_get = ecs_bulk_get,
		bulk_remove = ecs_bulk_remove,
		clear = ecs_clear,
		query = ecs_query,

		internal = {
			idr_flags = idr_flags,
			idr_arch_sparse = idr_arch_sparse,
			idr_arch_count = idr_arch_count,
			idr_dense_cached = idr_dense_cached,
			idr_dense_column = idr_dense_column,
			idr_dense_counts = idr_dense_counts,
			idr_hook_on_add = idr_hook_on_add,
			idr_hook_on_change = idr_hook_on_change,
			idr_hook_on_rem = idr_hook_on_rem,

			ROOT_ARCHETYPE = ROOT_ARCHETYPE,
			agraph_root = agraph_root,
			agraph = agraph,
			arch_has_empty_rows = arch_has_empty_rows,
			arch_scheduled_for_deletion = arch_scheduled_for_deletion,
			archetypes = archetypes,
			archetypes_count = function() return archetypes_count end,
			observable = observable,
			cindex = cindex,
			eindex_dense = eindex_dense,
			eindex_sparse = eindex_sparse,
			eindex_alive_count = function() return eindex_alive_count end,
			eindex_id_top = function() return eindex_id_top end,
			user_components_count = function() return user_components_count end,
			find_observers = find_observers,
			eindex_try_any_record = eindex_try_any_record,
			eindex_try_matching_record = eindex_try_matching_record,
			eindex_alive_eh = eindex_alive_eh,
			ecs_existed = ecs_existed,
			ecs_contains = ecs_contains,
			ent_try_latest_alive = ent_try_latest_alive,
			eindex_new_id_alive = eindex_new_id_alive,
			ecs_entity = ecs_entity,
			arch_ensure_dense = arch_ensure_dense,
			find_insert_lo2hi = find_insert_lo2hi,
			arch_move = arch_move,
			ent_move = ent_move,
			fetch_at_row = fetch_at_row,
			ecs_get = ecs_get,
			ecs_bulk_get = ecs_bulk_get,
			ecs_has = ecs_has,
			ent_has_inline = ent_has_inline,
			ecs_target = ecs_target,
			id_record_ensure = id_record_ensure,
			id_record_arch_append = id_record_arch_append,
			ids_pages = ids_pages,
			pagebuff_from_set = pagebuff_from_set,
			list_from_buff = list_from_buff,
			arch_new = arch_new,
			agraph_ensure = agraph_ensure,
			agraph_ensure_arch = agraph_ensure_arch,
			binary_search = binary_search,
			binary_insert = binary_insert,
			agraph_traverse_add = agraph_traverse_add,
			agraph_traverse_add_ensure = agraph_traverse_add_ensure,
			agraph_traverse_rem = agraph_traverse_rem,
			agraph_traverse_rem_ensure = agraph_traverse_rem_ensure,
			arch_traverse_rem_ensure = arch_traverse_rem_ensure,
			ecs_add = ecs_add,
			ecs_bulk_add = ecs_bulk_add,
			ecs_component = ecs_component,
			ecs_set = ecs_set,
			ecs_bulk_set = ecs_bulk_set,
			ecs_remove = ecs_remove,
			ecs_bulk_remove = ecs_bulk_remove,
			arch_delete_row = arch_delete_row,
			ecs_clear = ecs_clear,
			arch_delete = arch_delete,
			ecs_cleanup = ecs_cleanup,
			ecs_ensure_dense_archetypes = ecs_ensure_dense_archetypes,
			query_matcher_cache = query_matcher_cache,
			query_matcher_hash = query_matcher_hash,
			query_matcher = query_matcher,
			ecs_each = ecs_each,
			queryobj = queryobj,
			queryobj_metatable = queryobj_metatable,
			ecs_query = ecs_query,
		},
	}
end

local b2264644_3d77_4ab9_8a00_5e9ffb0ff964 = {
	internal = {
		idr_flags = idr_flags,
		idr_arch_sparse = idr_arch_sparse,
		idr_arch_count = idr_arch_count,
		idr_dense_cached = idr_dense_cached,
		idr_dense_column = idr_dense_column,
		idr_dense_counts = idr_dense_counts,
		idr_hook_on_add = idr_hook_on_add,
		idr_hook_on_change = idr_hook_on_change,
		idr_hook_on_rem = idr_hook_on_rem,

		NOOP = NOOP,
		NULL_ARRAY = NULL_ARRAY,
		NULLPTR = NULLPTR,
		F64_BYTES = F64_BYTES,
		IDFLAG_TAG = IDFLAG_TAG,
		IDFLAG_DELETE = IDFLAG_DELETE_ONCLEAR,
		IDFLAG_EXCLUSIVE = IDFLAG_EXCLUSIVE,
		EMASK_LO = EMASK_LO,
		EMASK_GENERATION = EMASK_GENERATION,
		EPAIR_OFFSET = EPAIR_OFFSET,
		COMPONENT_PAGE_SIZE = COMPONENT_PAGE_SIZE,
		COMPONENT_PAGE_RECORD_SIZE = COMPONENT_PAGE_RECORD_SIZE,
		MAX_PAGED_COMPONENT = MAX_PAGED_COMPONENT,
		MAX_COMPONENT = MAX_COMPONENT,
		Component = B2Component,
		Name = B2Name,
		Exclusive = B2Exclusive,
		Wildcard = B2Wildcard,
		ChildOf = B2ChildOf,
		CleanupOnClear = B2CleanupOnClear,
		CleanupOnClearTarget = B2CleanupOnClearTarget,
		CleanupDelete = B2CleanupDelete,
		OnAdd = B2OnAdd,
		OnRemove = B2OnRemove,
		OnChange = B2OnChange,
		EventOnArchAdded = EventOnArchAdded,
		EventOnArchRemoved = EventOnArchRemoved,
		ASSERT = ASSERT,
		ORDERED_HASH = ORDERED_HASH,
		ENT_LO = ENT_LO,
		ENT_HI = ENT_HI,
		ENT_PAIR = ENT_PAIR,
		ENT_PAIR_EH = ENT_PAIR_EH,
		ENT_PAIR_HI = ENT_PAIR_HI,
		ENT_PAIR_LO = ENT_PAIR_LO,
		ARCH_APPEND = ARCH_APPEND,
		ENT_INCREMENT_GENERATION = ENT_INCREMENT_GENERATION,
		RECORD_ENSURE_ROW = RECORD_ENSURE_ROW,
		ecs_new = ecs_new,
	},

	ecs = ecs_new :: (disable_auto_ensure_dense: boolean?) -> OldSolverECS,
	pair = ENT_PAIR :: (hi: Ent, lo: Ent) -> Ent,
	Component = B2Component :: any,
	Name = B2Name :: any,
	Wildcard = B2Wildcard :: any,
	ChildOf = B2ChildOf :: any,
	CleanupOnClear = B2CleanupOnClear :: any,
	CleanupOnClearTarget = B2CleanupOnClearTarget :: any,
	CleanupDelete = B2CleanupDelete :: any,
	OnAdd = B2OnAdd :: any,
	OnChange = B2OnChange :: any,
	OnRemove = B2OnRemove :: any,
	Exclusive = B2Exclusive :: any,
}

export type Ent<T = any> = { _B2: T }
export type Id<T = nil> = Ent<T>

export type Query<Reads...> = {
	with: (self: Query<Reads...>, ...Ent) -> Query<Reads...>,
	without: (self: Query<Reads...>, ...Ent) -> Query<Reads...>,
	match: (self: Query<Reads...>) -> (Arch) -> boolean,
	archetypes: (self: Query<Reads...>) -> { Arch },
	entities: (self: Query<Reads...>) -> () -> (Ent, Reads...),
	archetypes_cached: (self: Query<Reads...>) -> {Arch},
	entities_cached: (self: Query<Reads...>) -> () -> (Ent, Reads...),
	observe_added: (self: Query<Reads...>, callback: (Arch) -> ()) -> (),
	observe_removed: (self: Query<Reads...>, callback: (Arch) -> ()) -> (),
}

export type OnAddHook = <Data>(entity: Ent, id: Ent<Data>, data: Data) -> ()
export type OnChangeHook = <Data>(entity: Ent, id: Ent<Data>, data: Data) -> ()
export type OnRemoveHook = <Data>(entity: U53, id: Ent<Data>) -> ()

export type OldSolverECS = {
	internal: typeof(ecs_new().internal),

	target: (entity: Ent, rel: Ent, idx: number?) -> Ent?,
	parent: (entity: Ent) -> (Ent?),
	-- does an entity with this ID exist, and is it alive?
	contains: (entity: Ent) -> boolean,
	-- has an entity with this ID ever existed under any generation?
	existed: (entity: Ent) -> boolean,
	entity: () -> Ent,
	component: <Data>() -> Ent<Data>,
	ensure_dense_archetypes: () -> (),
	has: (entity: Ent, A: Ent, ...Ent) -> boolean,
	add: (entity: Ent, A: Ent, ...Ent) -> (),
	set: <Data>(entity: Ent, component: Ent<Data>, data: Data) -> (),
	get: <Data>(entity: Ent, component: Ent<Data>) -> Data,
	remove: (entity: Ent, component: Ent) -> (),
	bulk_add: (entity: Ent, components: { Ent }) -> (),
	bulk_set: (entity: Ent, components: { Ent }, values: { any }) -> (),
	bulk_get: (entity: Ent, components: { Ent }) -> { any },
	bulk_remove: (entity: Ent, components: { Ent }) -> (),
	clear: (entity: Ent, delete: boolean?) -> (),
	each: (id: Ent) -> () -> (Ent?),
	query: (() -> Query<>)
		& (<A>(A: Ent<A>) -> Query<A>)
		& (<A, B>(A: Ent<A>, B: Ent<B>) -> Query<A, B>)
		& (<A, B, C>(A: Ent<A>, B: Ent<B>, C: Ent<C>) -> Query<A, B, C>)
		& (<A, B, C, D>(A: Ent<A>, B: Ent<B>, C: Ent<C>, D: Ent<D>) -> Query<A, B, C, D>)
		& (<A, B, C, D, E>(A: Ent<A>, B: Ent<B>, C: Ent<C>, D: Ent<D>, E: Ent<E>) -> Query<A, B, C, D, E>)
		& (<A, B, C, D, E, F>(
			A: Ent<A>,
			B: Ent<B>,
			C: Ent<C>,
			D: Ent<D>,
			E: Ent<E>,
			F: Ent<F>
		) -> Query<A, B, C, D, E, F>)
		& (<A, B, C, D, E, F, G>(
			A: Ent<A>,
			B: Ent<B>,
			C: Ent<C>,
			D: Ent<D>,
			E: Ent<E>,
			F: Ent<F>,
			G: Ent<G>
		) -> Query<A, B, C, D, E, F, G>)
		& (<A, B, C, D, E, F, G, H>(
			A: Ent<A>,
			B: Ent<B>,
			C: Ent<C>,
			D: Ent<D>,
			E: Ent<E>,
			F: Ent<F>,
			G: Ent<G>,
			...Ent<H>
		) -> Query<A, B, C, D, E, F, G, ...H>),
}

-- export type function greedy(Type: type): type
-- 	return Type
-- end

type function _query(pack: type): type
	local b2_id = types.singleton("_B2")
	local params = pack:parameters()
	local head = params.head
	if head then
		local head_count = #head
		local id_types = table.create(head_count) :: {type}
		for head_index = 1, head_count do
			local id = head[head_index]
			local id_tag = id.tag
			if id_tag ~= "table" then
				id_types[head_index] = types.any
				continue
			end
			local prop = id:readproperty(b2_id)
			if not prop then
				id_types[head_index] = types.any
				continue
			end
			id_types[head_index] = prop
		end
		return (Query(table.unpack(id_types)))
	end
	return Query()
end

export type NewSolverECS = {
	internal: typeof(ecs_new().internal),

	target: (entity: Ent, rel: Ent, idx: number?) -> Ent?,
	parent: (entity: Ent) -> (Ent?),
	-- does an entity with this ID exist, and is it alive?
	contains: (entity: Ent) -> boolean,
	-- has an entity with this ID ever existed under any generation?
	existed: (entity: Ent) -> boolean,
	entity: () -> Ent,
	component: <Data>() -> Ent<Data>,
	ensure_dense_archetypes: () -> (),
	has: (entity: Ent, A: Ent, ...Ent) -> boolean,
	add: (entity: Ent, A: Ent, ...Ent) -> (),
	set: <Data>(entity: Ent, component: Ent<Data>, data: Data) -> (),
	get: <Data>(entity: Ent, component: Ent<Data>) -> Data,
	remove: (entity: Ent, component: Ent) -> (),
	bulk_add: (entity: Ent, components: { Ent }) -> (),
	bulk_set: (entity: Ent, components: { Ent }, values: { any }) -> (),
	bulk_get: (entity: Ent, components: { Ent }) -> { any },
	bulk_remove: (entity: Ent, components: { Ent }) -> (),
	clear: (entity: Ent, delete: boolean?) -> (),
	each: (id: Ent) -> () -> (Ent?),
	query: (() -> Query<>)
		& (<A>(A: Ent<A>) -> Query<A>)
		& (<A, B>(A: Ent<A>, B: Ent<B>) -> Query<A, B>)
		& (<A, B, C>(A: Ent<A>, B: Ent<B>, C: Ent<C>) -> Query<A, B, C>)
		& (<A, B, C, D>(A: Ent<A>, B: Ent<B>, C: Ent<C>, D: Ent<D>) -> Query<A, B, C, D>)
		& (<A, B, C, D, E>(A: Ent<A>, B: Ent<B>, C: Ent<C>, D: Ent<D>, E: Ent<E>) -> Query<A, B, C, D, E>)
		& (<A, B, C, D, E, F>(
			A: Ent<A>,
			B: Ent<B>,
			C: Ent<C>,
			D: Ent<D>,
			E: Ent<E>,
			F: Ent<F>
		) -> Query<A, B, C, D, E, F>)
		& (<A, B, C, D, E, F, G>(
			A: Ent<A>,
			B: Ent<B>,
			C: Ent<C>,
			D: Ent<D>,
			E: Ent<E>,
			F: Ent<F>,
			G: Ent<G>
		) -> Query<A, B, C, D, E, F, G>)
		& (<A, B, C, D, E, F, G, H>(
			A: Ent<A>,
			B: Ent<B>,
			C: Ent<C>,
			D: Ent<D>,
			E: Ent<E>,
			F: Ent<F>,
			G: Ent<G>,
			...Ent<H>
		) -> Query<A, B, C, D, E, F, G, ...H>),
}

export type B2 = {
	internal: typeof(b2264644_3d77_4ab9_8a00_5e9ffb0ff964.internal),

	ecs: ((new_solver: false, disable_auto_ensure_dense: boolean?) -> OldSolverECS) & ((new_solver: true, disable_auto_ensure_dense: boolean?) -> NewSolverECS),
	pair: (hi: Ent, lo: Ent) -> Ent,
	Component: Id,
	Name: Id<string>,
	Wildcard: Id,
	ChildOf: Id,
	CleanupOnClear: Id,
	CleanupOnClearTarget: Id,
	CleanupDelete: Id,
	Exclusive: Id,
	OnAdd: Id<OnAddHook>,
	OnChange: Id<OnChangeHook>,
	OnRemove: Id<OnRemoveHook>,
}

--[[
internal type exports
]]
export type _U53 = U53
export type _U32 = U32
export type _U26 = U26
export type _U24 = U24
export type _Ptr = Ptr
export type _IdList = IdList
export type _ArchLocation = ArchLocation
export type _ArchHash = ArchHash
export type _Row = Row
export type _Column = Column
export type _Arch = Arch
export type _ArchObserver = ArchObserver
export type _ArchObserverCache = ArchObserverCache
export type _Observable = Observable
export type _IdRecord = IdRecord
export type _OnAddHook = InternalOnAddHook
export type _OnChangeHook = InternalOnChangeHook
export type _OnRemoveHook = InternalOnRemoveHook
export type _QueryMatcher = QueryMatcher
export type _QueryInner = QueryInner
export type _QueryOuter = QueryOuter
export type _ArchGraphNode = ArchGraphNode
export type _EntRecord = EntRecord

return (b2264644_3d77_4ab9_8a00_5e9ffb0ff964::any) :: B2
