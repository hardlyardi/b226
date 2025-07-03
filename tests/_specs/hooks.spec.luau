local TEST, DONE, PREFIX = require("@test/utils/spec")(...)

local b2 = require("@b2/")
local ecs = require("@test/utils/ecs")

local pair = b2.pair

local CleansOnClear = ecs.component()
local CleansOnClearTarget = ecs.component()
ecs.add(CleansOnClear, pair(b2.CleanupOnClear, b2.CleanupDelete))
ecs.add(CleansOnClearTarget, pair(b2.CleanupOnClearTarget, b2.CleanupDelete))

local A = ecs.component()
local B = ecs.component()

local e1 = ecs.entity()

PREFIX("OnAdd")

TEST("ecs.add", function(interface)
	local called
	ecs.set(A, b2.OnAdd, function(ent, id)
		interface:expect_equal(id, A)
		called = true
	end)
	ecs.add(e1, A)
	interface:expect_truthy(called)
end)

TEST("ecs.set", function(interface)
	local called
	ecs.set(A, b2.OnAdd, function(ent, id, data)
		interface:expect_equal(id, A)
		called = data
	end)
	ecs.set(e1, A, "meow")
	interface:expect_truthy(called)
	interface:expect_equal(called, "meow")
end)

TEST("errors on move", function(interface)
	ecs.set(A, b2.OnAdd, function(entity)
		ecs.add(entity, B)
	end)
	local success = pcall(ecs.set, e1, A)
	interface:expect_falsy(success)
end)

PREFIX("OnChange")

TEST("ecs.set", function(interface)
	local called_count = 0
	local called_data
	ecs.set(A, b2.OnChange, function(ent, id, data)
		called_count += 1
		called_data = data
	end)
	ecs.set(e1, A, "meow")
	ecs.set(e1, A, "mrrp")
	interface:expect_equal(called_count, 1)
	interface:expect_equal(called_data, "mrrp")
end)

TEST("errors on move", function(interface)
	ecs.set(A, b2.OnChange, function(entity)
		ecs.add(entity, B)
	end)
	local success1 = pcall(ecs.set, e1, A, "meow")
	local success2 = pcall(ecs.set, e1, A, "mrrp")
	interface:expect_truthy(success1)
	interface:expect_falsy(success2)
end)

return DONE()
