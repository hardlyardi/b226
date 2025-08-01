local TEST, DONE, PREFIX = require("@test/utils/spec")(...)
local b2 = require("@b2/")
local ecs = require("@test/utils/ecs")

local e1 = ecs.entity()
local e2 = ecs.entity()
local e3 = ecs.entity()

PREFIX("")

TEST("repro 1", function(interface)
	ecs.set(e2, b2.OnRemove, function(ent)
		ecs.remove(ent, e3)
	end)
	ecs.add(e1, e2)
	ecs.add(e1, e3)
	ecs.clear(e1, true)
end)

TEST("repro 2", function(interface) end)

return DONE()
