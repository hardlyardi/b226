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
local relation = ecs.entity()
local exclusive = ecs.entity()
local dummy = ecs.entity()
local dummy2 = ecs.entity()

ecs.add(Exclusive, b2.Exclusive)
ecs.add(exclusive, b2.Exclusive)

PREFIX("entity relation")

TEST("adding", function(interface)
	ecs.add(e1, pair(relation, dummy))
	interface:expect_truthy(ecs.has(e1, pair(relation, dummy)))
end)

TEST("targeting", function(interface)
	ecs.add(e1, pair(relation, dummy))
	interface:expect_equal(ecs.target(e1, relation), dummy)
end)

TEST("targeting index", function(interface)
	ecs.add(e1, pair(relation, dummy))
	ecs.add(e1, pair(relation, dummy2))
	interface:expect_equal(ecs.target(e1, relation, 0), dummy)
	interface:expect_equal(ecs.target(e1, relation, 1), dummy2)
end)

TEST("targeting outside range", function(interface)
	local target = ecs.target(e1, relation)
	interface:expect_equal(target, nil)
	ecs.add(e1, pair(relation, dummy))
	ecs.add(e1, pair(relation, dummy2))
	target = ecs.target(e1, relation, 2)
	interface:expect_equal(target, nil)
end)

TEST("errors on set", function(interface)
	local success = pcall(ecs.set, e1, pair(relation, dummy), true)
	interface:expect_falsy(success)
end)

TEST("removing", function(interface)
	ecs.add(e1, pair(relation, dummy))
	ecs.remove(e1, pair(relation, dummy))
	interface:expect_falsy(ecs.has(e1, pair(relation, dummy)))
end)

TEST("invokes OnAdd on add", function(interface): ()
	local on_add_triggered = false
	ecs.set(relation, b2.OnAdd, function(e, id): ()
		interface:expect_falsy(on_add_triggered)
		on_add_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(relation, dummy))
	end)
	ecs.add(e1, pair(relation, dummy))
	interface:expect_truthy(on_add_triggered)
end)

TEST("invokes OnRemove on remove", function(interface): ()
	local on_remove_triggered = false
	ecs.set(relation, b2.OnRemove, function(e, id): ()
		interface:expect_falsy(on_remove_triggered)
		on_remove_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(relation, dummy))
	end)
	ecs.add(e1, pair(relation, dummy))
	ecs.remove(e1, pair(relation, dummy))
	interface:expect_truthy(on_remove_triggered)
end)

TEST("loop until no target", function(interface)
	local targets = {}
	for i = 1, 10 do
		local target = ecs.entity()
		targets[i] = target
		ecs.add(e1, pair(relation, target))
	end

	local i = 0
	local target = ecs.target(e1, relation, 0)
	while target do
		i += 1
		interface:expect_equal(targets[i], target)
		target = ecs.target(e1, relation, i)
	end
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

TEST("inherits target if component", function(interface)
	ecs.set(e1, pair(dummy, A), true)
	interface:expect_truthy(ecs.has(e1, pair(dummy, A)))
	interface:expect_equal(ecs.get(e1, pair(dummy, A)), true)
end)

TEST("removing", function(interface)
	ecs.set(e1, pair(A, dummy), true)
	ecs.remove(e1, pair(A, dummy))
	interface:expect_falsy(ecs.has(e1, pair(A, dummy)))
	interface:expect_equal(ecs.get(e1, pair(A, dummy)), nil)
end)

TEST("invokes OnAdd on add", function(interface): ()
	local on_add_triggered = false
	ecs.set(A, b2.OnAdd, function(e, id): ()
		interface:expect_falsy(on_add_triggered)
		on_add_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(A, dummy))
	end)
	ecs.add(e1, pair(A, dummy))
	interface:expect_truthy(on_add_triggered)
end)

TEST("invokes OnAdd on first set", function(interface)
	local on_add_triggered = false
	ecs.set(A, b2.OnAdd, function(e, id, data): ()
		interface:expect_falsy(on_add_triggered)
		on_add_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(A, dummy))
		interface:expect_equal(data, 1)
	end)
	ecs.set(e1, pair(A, dummy), 1)
	interface:expect_truthy(on_add_triggered)
end)

TEST("invokes OnChange on set", function(interface)
	local on_change_triggered = false
	ecs.set(A, b2.OnChange, function(e, id, data): ()
		interface:expect_falsy(on_change_triggered)
		on_change_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(A, dummy))
		interface:expect_equal(data, 2)
	end)
	ecs.set(e1, pair(A, dummy), 1)
	ecs.set(e1, pair(A, dummy), 2)
	interface:expect_truthy(on_change_triggered)
end)

TEST("invokes OnRemove on remove", function(interface): ()
	local on_remove_triggered = false
	ecs.set(A, b2.OnRemove, function(e, id): ()
		interface:expect_falsy(on_remove_triggered)
		on_remove_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(A, dummy))
	end)
	ecs.add(e1, pair(A, dummy))
	ecs.remove(e1, pair(A, dummy))
	interface:expect_truthy(on_remove_triggered)
end)

PREFIX("exclusive entity relation")

TEST("adding", function(interface)
	ecs.add(e1, pair(exclusive, dummy))
	interface:expect_truthy(ecs.has(e1, pair(exclusive, dummy)))
end)

TEST("overwriting", function(interface)
	ecs.add(e1, pair(exclusive, dummy))
	ecs.add(e1, pair(exclusive, relation))
	interface:expect_falsy(ecs.has(e1, pair(exclusive, dummy)))
	interface:expect_truthy(ecs.has(e1, pair(exclusive, relation)))
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

TEST("invokes OnAdd on add", function(interface): ()
	local on_add_triggered = false
	ecs.set(exclusive, b2.OnAdd, function(e, id): ()
		interface:expect_falsy(on_add_triggered)
		on_add_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(exclusive, dummy))
	end)
	ecs.add(e1, pair(exclusive, dummy))
	interface:expect_truthy(on_add_triggered)
end)

TEST("invokes OnRemove on remove", function(interface): ()
	local on_remove_triggered = false
	ecs.set(exclusive, b2.OnRemove, function(e, id): ()
		interface:expect_falsy(on_remove_triggered)
		on_remove_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(exclusive, dummy))
	end)
	ecs.add(e1, pair(exclusive, dummy))
	ecs.remove(e1, pair(exclusive, dummy))
	interface:expect_truthy(on_remove_triggered)
end)

TEST("invokes on override", function(interface)
	ecs.add(e1, pair(exclusive, dummy))
	local on_add_triggered: number?
	local on_remove_triggered: number?
	ecs.set(exclusive, b2.OnRemove, function(e, id): ()
		interface:expect_falsy(on_remove_triggered)
		on_remove_triggered = os.clock()
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(exclusive, dummy))
	end)
	ecs.set(exclusive, b2.OnAdd, function(e, id): ()
		interface:expect_falsy(on_add_triggered)
		on_add_triggered = os.clock()
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(exclusive, dummy2))
	end)
	ecs.add(e1, pair(exclusive, dummy2))
	interface:expect_truthy(on_add_triggered)
	interface:expect_truthy(on_remove_triggered)
	if on_add_triggered and on_remove_triggered then
		interface:expect_truthy(on_remove_triggered < on_add_triggered) --
	end
end)

PREFIX("exclusive component relation")

TEST("adding", function(interface)
	ecs.add(e1, pair(Exclusive, dummy))
	interface:expect_truthy(ecs.has(e1, pair(Exclusive, dummy)))
end)

TEST("overwriting", function(interface)
	ecs.add(e1, pair(Exclusive, dummy))
	ecs.add(e1, pair(Exclusive, relation))
	interface:expect_falsy(ecs.has(e1, pair(Exclusive, dummy)))
	interface:expect_truthy(ecs.has(e1, pair(Exclusive, relation)))
end)

TEST("setting", function(interface)
	ecs.set(e1, pair(Exclusive, dummy), true)
	interface:expect_truthy(ecs.has(e1, pair(Exclusive, dummy)))
	interface:expect_equal(ecs.get(e1, pair(Exclusive, dummy)), true)
end)

TEST("overwriting setting", function(interface)
	ecs.set(e1, pair(Exclusive, dummy), true)
	ecs.set(e1, pair(Exclusive, relation), 1)
	interface:expect_truthy(ecs.has(e1, pair(Exclusive, relation)))
	interface:expect_equal(ecs.get(e1, pair(Exclusive, relation)), 1)
	interface:expect_falsy(ecs.has(e1, pair(Exclusive, dummy)))
	interface:expect_equal(ecs.get(e1, pair(Exclusive, dummy)), nil)
end)

TEST("removing", function(interface)
	ecs.add(e1, pair(Exclusive, dummy))
	ecs.remove(e1, pair(Exclusive, dummy))
	interface:expect_falsy(ecs.has(e1, pair(Exclusive, dummy)))
end)

TEST("invokes OnAdd on add", function(interface): ()
	local on_add_triggered = false
	ecs.set(Exclusive, b2.OnAdd, function(e, id): ()
		interface:expect_falsy(on_add_triggered)
		on_add_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(Exclusive, dummy))
	end)
	ecs.add(e1, pair(Exclusive, dummy))
	interface:expect_truthy(on_add_triggered)
end)

TEST("invokes OnAdd on set", function(interface): ()
	local on_add_triggered = false
	ecs.set(Exclusive, b2.OnAdd, function(e, id, data): ()
		interface:expect_falsy(on_add_triggered)
		on_add_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(Exclusive, dummy))
		interface:expect_equal(data, 1)
	end)
	ecs.set(e1, pair(Exclusive, dummy), 1)
	interface:expect_truthy(on_add_triggered)
end)

TEST("invokes OnRemove on remove", function(interface): ()
	local on_remove_triggered = false
	ecs.set(Exclusive, b2.OnRemove, function(e, id): ()
		interface:expect_falsy(on_remove_triggered)
		on_remove_triggered = true
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(Exclusive, dummy))
	end)
	ecs.add(e1, pair(Exclusive, dummy))
	ecs.remove(e1, pair(Exclusive, dummy))
	interface:expect_truthy(on_remove_triggered)
end)

TEST("invokes on override", function(interface)
	ecs.set(e1, pair(Exclusive, dummy), 1)
	local on_add_triggered: number?
	local on_remove_triggered: number?
	ecs.set(Exclusive, b2.OnRemove, function(e, id): ()
		interface:expect_falsy(on_remove_triggered)
		on_remove_triggered = os.clock()
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(Exclusive, dummy))
		interface:expect_equal(ecs.get(e, pair(Exclusive, dummy)), 1)
	end)
	ecs.set(Exclusive, b2.OnAdd, function(e, id, data): ()
		interface:expect_falsy(on_add_triggered)
		on_add_triggered = os.clock()
		interface:expect_equal(e, e1)
		interface:expect_equal(id, pair(Exclusive, dummy2))
		interface:expect_equal(data, 2)
	end)
	ecs.set(e1, pair(Exclusive, dummy2), 2)
	interface:expect_truthy(on_add_triggered)
	interface:expect_truthy(on_remove_triggered)
	if on_add_triggered and on_remove_triggered then
		interface:expect_truthy(on_remove_triggered < on_add_triggered) --
	end
end)

TEST("inherits target if component", function(interface)
	ecs.set(e1, pair(exclusive, Exclusive), true)
	interface:expect_truthy(ecs.has(e1, pair(exclusive, Exclusive)))
	interface:expect_equal(ecs.get(e1, pair(exclusive, Exclusive)), true)
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
