local TEST, DONE, PREFIX = require("@test/utils/spec")(...)
local b2 = require("@b2/")
local ecs = require("@test/utils/ecs")
local runtest = require("@runtest")

type TestInterface = runtest.TestInterface

local function EN(input: b2.Ent): number
	return input :: any
end

local ecsi = ecs.internal
local archetypes = ecsi.archetypes
local eindex_sparse = ecsi.eindex_sparse

local A = ecs.component()
local B = ecs.component()
local e1 = ecs.entity()
local e2 = ecs.entity()

ecs.cleanup()

local starting_arch_count = #archetypes

PREFIX("")

TEST("adding creates an archetype", function(interface)
	ecs.add(e1, A)
	interface:expect_equal(#archetypes, starting_arch_count + 1)
end)

TEST("removing does not create an archetype", function(interface)
	ecs.add(e1, A)
	ecs.remove(e1, A)
	interface:expect_equal(#archetypes, starting_arch_count + 1)
end)

TEST("divergence", function(interface)
	local e2 = ecs.entity()

	ecs.add(e1, A)
	ecs.add(e2, B)

	if eindex_sparse[EN(e1)].arch == eindex_sparse[EN(e2)].arch then
		interface:fail("archetypes did not diverge") --
	end
end)

TEST("divergent convergence", function(interface)
	ecs.add(e1, A)
	ecs.add(e2, B)
	ecs.add(e1, B)
	ecs.add(e2, A)

	if eindex_sparse[EN(e1)].arch ~= eindex_sparse[EN(e2)].arch then
		interface:fail("archetypes diverged") --
	end
end)

TEST("clearing & ensure_dense_archetypes removes an archetype", function(interface)
	ecs.add(e1, A)
	ecs.clear(A)
	ecs.ensure_dense_archetypes()
	interface:expect_equal(#archetypes, starting_arch_count)
end)

TEST("deleting & ensure_dense_archetypes removes an archetype", function(interface)
	ecs.add(e1, A)
	ecs.clear(A, true)
	ecs.ensure_dense_archetypes()
	interface:expect_equal(#archetypes, starting_arch_count)
end)

TEST("clearing & cleanup removes an archetype", function(interface)
	ecs.add(e1, A)
	ecs.clear(A)
	ecs.cleanup()
	interface:expect_equal(#archetypes, starting_arch_count)
end)

TEST("deleting & cleanup removes an archetype", function(interface)
	ecs.add(e1, A)
	ecs.clear(A, true)
	ecs.cleanup()
	interface:expect_equal(#archetypes, starting_arch_count)
end)

TEST("removing & cleanup removes an archetype", function(interface)
	ecs.add(e1, A)
	ecs.remove(e1, A)
	ecs.cleanup()
	interface:expect_equal(#archetypes, starting_arch_count)
end)

return DONE()
