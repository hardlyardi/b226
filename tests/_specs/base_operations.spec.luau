local TEST, DONE, PREFIX = require("@test/utils/spec")(...)

local ecs = require("@test/utils/ecs")

local internal = ecs.internal

local alive_ct = internal.eindex_alive_count

local A = ecs.component()
local B = ecs.component()
local C = ecs.component()
local e1 = ecs.entity()
local e2 = ecs.entity()

PREFIX("adding")

TEST("components", function(interface)
	ecs.add(e1, A)
	interface:expect_truthy(ecs.has(e1, A))
	ecs.add(e1, B)
	interface:expect_truthy(ecs.has(e1, A))
	interface:expect_truthy(ecs.has(e1, B))
end)

TEST("tags", function(interface)
	ecs.add(e1, e2)
	interface:expect_truthy(ecs.has(e1, e2))
end)

PREFIX("setting")

TEST("components", function(interface)
	ecs.set(e1, A, 1)
	ecs.set(e1, B, 2)
	interface:expect_truthy(ecs.has(e1, A))
	interface:expect_truthy(ecs.has(e1, B))
	interface:expect_equal(ecs.get(e1, A), 1)
	interface:expect_equal(ecs.get(e1, B), 2)
end)

PREFIX("removing")

TEST("components", function(interface)
	ecs.set(e1, A, 1)
	ecs.set(e1, B, 2)
	ecs.set(e1, C, 3)
	ecs.remove(e1, B)
	interface:expect_truthy(ecs.has(e1, A))
	interface:expect_falsy(ecs.has(e1, B))
	interface:expect_truthy(ecs.has(e1, C))
	interface:expect_equal(ecs.get(e1, A), 1)
	interface:expect_equal(ecs.get(e1, B), nil)
	interface:expect_equal(ecs.get(e1, C), 3)
end)

TEST("tags", function(interface)
	ecs.add(e1, A)
	ecs.remove(e1, A)
	interface:expect_falsy(ecs.has(e1, e2))
end)

PREFIX("clearing")

TEST("does not delete entity", function(interface)
	local starting_alive_count = alive_ct()
	ecs.clear(e1)
	interface:expect_truthy(ecs.contains(e1))
	interface:expect_equal(alive_ct(), starting_alive_count)
end)

TEST("tag removes", function(interface)
	local tag = ecs.entity()
	ecs.add(e1, tag)
	ecs.add(e2, tag)
	ecs.clear(tag)
	interface:expect_falsy(ecs.has(e1, tag))
	interface:expect_falsy(ecs.has(e2, tag))
end)

TEST("component removes", function(interface)
	ecs.add(e1, A)
	ecs.set(e2, A, 1)
	ecs.clear(A)
	interface:expect_falsy(ecs.has(e1, A))
	interface:expect_falsy(ecs.has(e2, A))
	interface:expect_equal(ecs.get(e2, A), nil)
end)

PREFIX("deletion")

TEST("removes entity", function(interface)
	local starting_alive_count = alive_ct()
	ecs.clear(e1, true)
	interface:expect_falsy(ecs.contains(e1))
	interface:expect_equal(alive_ct(), starting_alive_count - 1)
end)

TEST("removes components", function(interface)
	ecs.set(e1, A, 1)
	ecs.set(e1, B, 2)
	ecs.set(e1, C, 3)
	ecs.clear(e1, true)
	interface:expect_falsy(ecs.has(e1, A))
	interface:expect_falsy(ecs.has(e1, B))
	interface:expect_falsy(ecs.has(e1, C))
	interface:expect_equal(ecs.get(e1, A), nil)
	interface:expect_equal(ecs.get(e1, B), nil)
	interface:expect_equal(ecs.get(e1, C), nil)
end)

return DONE()
