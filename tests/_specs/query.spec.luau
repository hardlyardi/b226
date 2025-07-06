local TEST, DONE, PREFIX = require("@test/utils/spec")(...)

local b2 = require("@b2/")
local ecs = require("@test/utils/ecs")

local pair = b2.pair
local Wildcard = b2.Wildcard
local ChildOf = b2.ChildOf
local Name = b2.Name

local A = ecs.component()
local B = ecs.component()
local C = ecs.component() :: b2.Id<boolean>
local D = ecs.component()

local e1 = ecs.entity()
local e2 = ecs.entity()
local e3 = ecs.entity()

PREFIX("ecs.each()")

TEST("covers all valid", function(interface)
	ecs.add(e1, A)
	ecs.add(e2, A)

	local covered = {}
	for entity in ecs.each(A) do
		covered[entity] = true
	end
	interface:expect_truthy(covered[e1])
	interface:expect_truthy(covered[e2])
end)

TEST("covers correctly", function(interface)
	ecs.add(e1, A)

	ecs.add(e2, A)
	ecs.add(e2, B)

	ecs.add(e3, A)
	ecs.add(e3, B)
	ecs.add(e3, C)

	local covered_a = {}
	for entity in ecs.each(A) do
		covered_a[entity] = true
	end
	local covered_b = {}
	for entity in ecs.each(B) do
		covered_b[entity] = true
	end
	local covered_c = {}
	for entity in ecs.each(C) do
		covered_c[entity] = true
	end

	interface:expect_truthy(covered_a[e1])
	interface:expect_truthy(covered_a[e2])
	interface:expect_truthy(covered_a[e3])

	interface:expect_falsy(covered_b[e1])
	interface:expect_truthy(covered_b[e2])
	interface:expect_truthy(covered_b[e3])

	interface:expect_falsy(covered_c[e1])
	interface:expect_falsy(covered_c[e2])
	interface:expect_truthy(covered_c[e3])
end)

PREFIX("ecs.query")

local q = ecs.query(A, B):without(C)

TEST("entities", function(interface)
	ecs.set(e1, A, true)
	ecs.set(e1, B, false)

	local iter_count = 0
	for ent, a, b in q:entities() do
		iter_count += 1
		interface:expect_equal(ent, e1)
		interface:expect_equal(a, true)
		interface:expect_equal(b, false)
	end
	interface:expect_equal(iter_count, 1)
	iter_count = 0
	for ent, a, b in q:entities() do
		iter_count += 1
		interface:expect_equal(ent, e1)
		interface:expect_equal(a, true)
		interface:expect_equal(b, false)
	end
	interface:expect_equal(iter_count, 1)
	ecs.set(e2, A, false)
	ecs.add(e2, D)
	ecs.set(e2, B, true)
	iter_count = 0
	for ent, a, b in q:entities() do
		iter_count += 1
		if ent == e1 then
			interface:expect_equal(a, true)
			interface:expect_equal(b, false)
		elseif ent == e2 then
			interface:expect_equal(a, false)
			interface:expect_equal(b, true)
		else
			interface:fail(debug.info(1, "l"))
		end
	end
	interface:expect_equal(iter_count, 2)
	ecs.set(e1, C, true)
	iter_count = 0
	for ent, a, b in q:entities() do
		iter_count += 1
		interface:expect_equal(ent, e2)
		interface:expect_equal(a, false)
		interface:expect_equal(b, true)
	end
	interface:expect_equal(iter_count, 1)
end)

TEST("cached_entities", function(interface)
	ecs.set(e1, A, true)
	ecs.set(e1, B, false)

	local iter_count = 0
	for ent, a, b in q:entities_cached() do
		iter_count += 1
		interface:expect_equal(ent, e1)
		interface:expect_equal(a, true)
		interface:expect_equal(b, false)
	end
	interface:expect_equal(iter_count, 1)
	iter_count = 0
	for ent, a, b in q:entities_cached() do
		iter_count += 1
		interface:expect_equal(ent, e1)
		interface:expect_equal(a, true)
		interface:expect_equal(b, false)
	end
	interface:expect_equal(iter_count, 1)
	ecs.set(e2, A, false)
	ecs.add(e2, D)
	ecs.set(e2, B, true)
	iter_count = 0
	for ent, a, b in q:entities_cached() do
		iter_count += 1
		if ent == e1 then
			interface:expect_equal(a, true)
			interface:expect_equal(b, false)
		elseif ent == e2 then
			interface:expect_equal(a, false)
			interface:expect_equal(b, true)
		else
			interface:fail(debug.info(1, "l"))
		end
	end
	interface:expect_equal(iter_count, 2)
	ecs.set(e1, C, true)
	iter_count = 0
	for ent, a, b in q:entities_cached() do
		iter_count += 1
		interface:expect_equal(ent, e2)
		interface:expect_equal(a, false)
		interface:expect_equal(b, true)
	end
	interface:expect_equal(iter_count, 1)
end)

local cts = {}
for components_count = 1, 9 do
	TEST(`{components_count} components no filter`, function(interface)
		for iter = 1, components_count do
			local Component = ecs.component()
			ecs.set(e1, Component, 2 ^ iter)
			table.insert(cts, Component)
		end

		local query = ecs.query(unpack(cts))

		local count = 0
		for ent, a, b, c, d, e, f, g, h, i, j in (query :: any):entities() do
			count += 1
			interface:expect_equal(ent, e1)
			interface:expect_equal(a, 2 ^ 1)
			if components_count < 2 then
				interface:expect_equal(b, nil)
				continue
			end
			interface:expect_equal(b, 2 ^ 2)
			if components_count < 3 then
				interface:expect_equal(c, nil)
				continue
			end
			interface:expect_equal(c, 2 ^ 3)
			if components_count < 4 then
				interface:expect_equal(d, nil)
				continue
			end
			interface:expect_equal(d, 2 ^ 4)
			if components_count < 5 then
				interface:expect_equal(e, nil)
				continue
			end
			interface:expect_equal(e, 2 ^ 5)
			if components_count < 6 then
				interface:expect_equal(f, nil)
				continue
			end
			interface:expect_equal(f, 2 ^ 6)
			if components_count < 7 then
				interface:expect_equal(g, nil)
				continue
			end
			interface:expect_equal(g, 2 ^ 7)
			if components_count < 8 then
				interface:expect_equal(h, nil)
				continue
			end
			interface:expect_equal(h, 2 ^ 8)
			if components_count < 9 then
				interface:expect_equal(i, nil)
				continue
			end
			interface:expect_equal(i, 2 ^ 9)
			if components_count < 10 then
				interface:expect_equal(j, nil)
				continue
			end
			error("wtf")
		end
		interface:expect_equal(count, 1)

		ecs.remove(e1, cts[1])
		count = 0
		for ent, a, b, c, d, e, f, g, h, i, j, k in (query :: any):entities() do
			count += 1
		end
		interface:expect_equal(count, 0)

		ecs.set(e1, cts[1], 2 ^ 1)

		count = 0
		for ent, a, b, c, d, e, f, g, h, i, j, k in (query :: any):entities() do
			count += 1
			interface:expect_equal(ent, e1)
			interface:expect_equal(a, 2 ^ 1)
			if components_count < 2 then
				interface:expect_equal(b, nil)
				continue
			end
			interface:expect_equal(b, 2 ^ 2)
			if components_count < 3 then
				interface:expect_equal(c, nil)
				continue
			end
			interface:expect_equal(c, 2 ^ 3)
			if components_count < 4 then
				interface:expect_equal(d, nil)
				continue
			end
			interface:expect_equal(d, 2 ^ 4)
			if components_count < 5 then
				interface:expect_equal(e, nil)
				continue
			end
			interface:expect_equal(e, 2 ^ 5)
			if components_count < 6 then
				interface:expect_equal(f, nil)
				continue
			end
			interface:expect_equal(f, 2 ^ 6)
			if components_count < 7 then
				interface:expect_equal(g, nil)
				continue
			end
			interface:expect_equal(g, 2 ^ 7)
			if components_count < 8 then
				interface:expect_equal(h, nil)
				continue
			end
			interface:expect_equal(h, 2 ^ 8)
			if components_count < 9 then
				interface:expect_equal(i, nil)
				continue
			end
			interface:expect_equal(i, 2 ^ 9)
			if components_count < 10 then
				interface:expect_equal(j, nil)
				continue
			end
			error("wtf")
		end
		interface:expect_equal(count, 1)
	end)

	TEST(`{components_count} components + filter`, function(interface)
		for iter = 1, components_count do
			local Component = ecs.component()
			ecs.set(e1, Component, 2 ^ iter)
			table.insert(cts, Component)
		end

		local filter_without = ecs.component()

		local query = ecs.query(unpack(cts)):without(filter_without)

		local count = 0
		for ent, a, b, c, d, e, f, g, h, i, j in (query :: any):entities() do
			count += 1
			interface:expect_equal(ent, e1)
			interface:expect_equal(a, 2 ^ 1)
			if components_count < 2 then
				interface:expect_equal(b, nil)
				continue
			end
			interface:expect_equal(b, 2 ^ 2)
			if components_count < 3 then
				interface:expect_equal(c, nil)
				continue
			end
			interface:expect_equal(c, 2 ^ 3)
			if components_count < 4 then
				interface:expect_equal(d, nil)
				continue
			end
			interface:expect_equal(d, 2 ^ 4)
			if components_count < 5 then
				interface:expect_equal(e, nil)
				continue
			end
			interface:expect_equal(e, 2 ^ 5)
			if components_count < 6 then
				interface:expect_equal(f, nil)
				continue
			end
			interface:expect_equal(f, 2 ^ 6)
			if components_count < 7 then
				interface:expect_equal(g, nil)
				continue
			end
			interface:expect_equal(g, 2 ^ 7)
			if components_count < 8 then
				interface:expect_equal(h, nil)
				continue
			end
			interface:expect_equal(h, 2 ^ 8)
			if components_count < 9 then
				interface:expect_equal(i, nil)
				continue
			end
			interface:expect_equal(i, 2 ^ 9)
			if components_count < 10 then
				interface:expect_equal(j, nil)
				continue
			end
			error("wtf")
		end
		interface:expect_equal(count, 1)

		ecs.add(e1, filter_without)

		count = 0
		for ent, a, b, c, d, e, f, g, h, i, j, k in query:entities() :: any do
			count += 1
		end
		interface:expect_equal(count, 0)

		ecs.remove(e1, filter_without)

		count = 0
		for ent, a, b, c, d, e, f, g, h, i, j, k in query:entities() :: any do
			count += 1
			interface:expect_equal(ent, e1)
			interface:expect_equal(a, 2 ^ 1)
			if components_count < 2 then
				interface:expect_equal(b, nil)
				continue
			end
			interface:expect_equal(b, 2 ^ 2)
			if components_count < 3 then
				interface:expect_equal(c, nil)
				continue
			end
			interface:expect_equal(c, 2 ^ 3)
			if components_count < 4 then
				interface:expect_equal(d, nil)
				continue
			end
			interface:expect_equal(d, 2 ^ 4)
			if components_count < 5 then
				interface:expect_equal(e, nil)
				continue
			end
			interface:expect_equal(e, 2 ^ 5)
			if components_count < 6 then
				interface:expect_equal(f, nil)
				continue
			end
			interface:expect_equal(f, 2 ^ 6)
			if components_count < 7 then
				interface:expect_equal(g, nil)
				continue
			end
			interface:expect_equal(g, 2 ^ 7)
			if components_count < 8 then
				interface:expect_equal(h, nil)
				continue
			end
			interface:expect_equal(h, 2 ^ 8)
			if components_count < 9 then
				interface:expect_equal(i, nil)
				continue
			end
			interface:expect_equal(i, 2 ^ 9)
			if components_count < 10 then
				interface:expect_equal(j, nil)
				continue
			end
			error("wtf")
		end
		interface:expect_equal(count, 1)
	end)
end

TEST("wildcard query", function(interface)
	ecs.set(e1, pair(A, e2), "meow")

	local covered_count = 0
	for entity, data in ecs.query(pair(A, Wildcard)):entities() do
		covered_count += 1
		interface:expect_equal(entity, e1)
		interface:expect_equal(data, "meow")
	end
	interface:expect_equal(covered_count, 1)
	covered_count = 0
	for entity, data in ecs.query(pair(Wildcard, e2)):entities() do
		covered_count += 1
		interface:expect_equal(entity, e1)
		interface:expect_equal(data, "meow")
	end
	interface:expect_equal(covered_count, 1)
end)

TEST("query children", function(interface)
	ecs.add(e2, pair(ChildOf, e1))
	ecs.add(e3, pair(ChildOf, e1))
	ecs.set(e2, Name, "alice")
	ecs.set(e3, Name, "bob")

	local count = 0
	local covered = {}
	for ent, name in ecs.query(Name):with(pair(ChildOf, e1)):entities() do
		count += 1
		covered[ent] = true
		if name == "alice" then
			interface:expect_equal(ent, e2)
		elseif name == "bob" then
			interface:expect_equal(ent, e3)
		else
			interface:fail(`[{debug.info(1, "l")}] uh oh`)
		end
	end

	interface:expect_falsy(covered[e1])
	interface:expect_truthy(covered[e2])
	interface:expect_truthy(covered[e3])

	interface:expect_equal(count, 2)
end)

TEST("clearing while iterating", function(interface)
	ecs.add(e1, A)
	ecs.add(e2, A)
	ecs.add(e3, A)
	ecs.add(e3, B)

	local count = 0
	for ent in ecs.query(A):entities() do
		ecs.clear(ent)
		count += 1
	end
	interface:expect_equal(count, 3)
end)

TEST("deleting while iterating", function(interface)
	ecs.add(e1, A)
	ecs.add(e2, A)
	ecs.add(e3, A)
	ecs.add(e3, B)

	local count = 0
	for ent in ecs.query(A):entities() do
		ecs.clear(ent, true)
		count += 1
	end
	interface:expect_equal(count, 3)
end)

return DONE()
