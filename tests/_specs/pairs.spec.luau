local TEST, DONE, PREFIX = require("@test/utils/spec")(...)

local b2 = require("@b2/")
local ecs = require("@test/utils/ecs")

local pair = b2.pair

local CleansOnClear = ecs.component()
local CleansOnClearTarget = ecs.component()
ecs.add(CleansOnClear, pair(b2.CleanupOnClear, b2.CleanupDelete))
ecs.add(CleansOnClearTarget, pair(b2.CleanupOnClearTarget, b2.CleanupDelete))

local A = ecs.component()
local Exclusive = ecs.component()

local e1 = ecs.entity()
local e2 = ecs.entity()
local exclusive = ecs.entity()
local dummy = ecs.entity()

ecs.add(Exclusive, b2.Exclusive)
ecs.add(exclusive, b2.Exclusive)

PREFIX("entity relation")

TEST("adding", function(interface)
	ecs.add(e1, pair(e2, dummy))
	interface:expect_truthy(ecs.has(e1, pair(e2, dummy)))
end)

TEST("targeting", function(interface)
	ecs.add(e1, pair(e2, dummy))
	interface:expect_equal(ecs.target(e1, e2), dummy)
end)

TEST("errors on set", function(interface)
	local success = pcall(ecs.set, e1, pair(e2, dummy), true)
	interface:expect_falsy(success)
end)

TEST("removing", function(interface)
	ecs.add(e1, pair(e2, dummy))
	ecs.remove(e1, pair(e2, dummy))
	interface:expect_falsy(ecs.has(e1, pair(e2, dummy)))
end)

PREFIX("component relation")

TEST("adding", function(interface)
	ecs.add(e1, pair(A, dummy))
	interface:expect_truthy(ecs.has(e1, pair(A, dummy)))
end)

TEST("targeting", function(interface)
	ecs.add(e1, pair(A, dummy))
	interface:expect_equal(ecs.target(e1, A), dummy)
end)

TEST("setting", function(interface)
	ecs.set(e1, pair(A, dummy), true)
	interface:expect_truthy(ecs.has(e1, pair(A, dummy)))
	interface:expect_equal(ecs.get(e1, pair(A, dummy)), true)
end)

TEST("removing", function(interface)
	ecs.set(e1, pair(A, dummy), true)
	ecs.remove(e1, pair(A, dummy))
	interface:expect_falsy(ecs.has(e1, pair(A, dummy)))
	interface:expect_equal(ecs.get(e1, pair(A, dummy)), nil)
end)

PREFIX("exclusive entity relation")

TEST("adding", function(interface)
	ecs.add(e1, pair(exclusive, dummy))
	interface:expect_truthy(ecs.has(e1, pair(exclusive, dummy)))
end)

TEST("overwriting", function(interface)
	ecs.add(e1, pair(exclusive, dummy))
	ecs.add(e1, pair(exclusive, e2))
	interface:expect_falsy(ecs.has(e1, pair(exclusive, dummy)))
	interface:expect_truthy(ecs.has(e1, pair(exclusive, e2)))
end)

TEST("errors on set", function(interface)
	local success = pcall(ecs.set, e1, pair(exclusive, dummy), true)
	interface:expect_falsy(success)
end)

TEST("removing", function(interface)
	ecs.add(e1, pair(exclusive, dummy))
	ecs.remove(e1, pair(exclusive, dummy))
	interface:expect_falsy(ecs.has(e1, pair(exclusive, dummy)))
end)

PREFIX("pair(CleanupOnClear, CleanupDelete)")

TEST("clear deletes entity", function(interface)
	ecs.add(e1, CleansOnClear)
	ecs.clear(CleansOnClear)
	interface:expect_falsy(ecs.contains(e1))
end)

TEST("clear target doesn't delete entity", function(interface)
	ecs.add(e1, pair(CleansOnClear, dummy))
	ecs.clear(dummy)
	interface:expect_truthy(ecs.contains(e1))
end)

TEST("delete deletes entity", function(interface)
	ecs.add(e1, CleansOnClear)
	ecs.clear(CleansOnClear, true)
	interface:expect_falsy(ecs.contains(e1))
end)

TEST("delete target doesn't delete entity", function(interface)
	ecs.add(e1, pair(CleansOnClear, dummy))
	ecs.clear(dummy, true)
	interface:expect_truthy(ecs.contains(e1))
end)

PREFIX("pair(CleanupOnClearTarget, CleanupDelete)")

TEST("clear target deletes entity", function(interface)
	ecs.add(e1, pair(CleansOnClearTarget, dummy))
	ecs.clear(dummy)
	interface:expect_falsy(ecs.contains(e1))
end)

TEST("clear doesn't delete entity", function(interface)
	ecs.add(e1, CleansOnClearTarget)
	ecs.clear(dummy)
	interface:expect_truthy(ecs.contains(e1))
end)

TEST("delete target deletes entity", function(interface)
	ecs.add(e1, pair(CleansOnClearTarget, dummy))
	ecs.clear(dummy, true)
	interface:expect_falsy(ecs.contains(e1))
end)

TEST("delete doesn't delete entity", function(interface)
	ecs.add(e1, CleansOnClearTarget)
	ecs.clear(dummy, true)
	interface:expect_truthy(ecs.contains(e1))
end)

return DONE()
