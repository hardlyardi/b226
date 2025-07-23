---
prev:
    text: 'Entity Relationships'
    link: './relationships'
next:
    text: 'Hooks'
    link: './hooks'
---
# Cleanup Traits

When entities that are used as tags, components, relationships or relationship targets are deleted, cleanup traits
ensure that the store does not contain any dangling references. Any cleanup policy provides this guarantee, so while
they are configurable, games cannot configure traits that allows for dangling references.

To configure a cleanup policy for an entity, a (Condition, Action) pair can be added to it. If no policy is specified,
the id will be removed on cleanup.

Right now, there are six cleanup conditions:

- `OnClear`: the component or tag is cleared or deleted.
- `OnClearTarget`: a target used with the relationship is cleared or deleted.
- `OnClearAsRelation`: this entity is the first part of a relationship pair, and is being cleared or deleted.
- `OnDelete`: the component or tag is deleted.
- `OnDeleteTarget`: a target used with the relationship is deleted.
- `OnDeleteAsRelation`: this entity is the first part of a relationship pair, and is being deleted.

And one cleanup action:

- `CleanupDelete`: When the condition is met, entities with this ID will be deleted.

## Examples

### pair(OnClear, CleanupDelete)

```luau
local Archer = ecs.component()
ecs.add(Archer, b2.pair(b2.OnClear, b2.CleanupDelete))

local e = ecs.entity()
ecs.add(e, Archer)

-- This will delete e because Archer has an (OnClear, CleanupDelete) trait.
ecs.clear(Archer, true)
```

### (CleanupOnClearTarget, CleanupDelete)

```luau
local ChildOf = ecs.component()
ecs.add(ChildOf, pair(b2.CleanupOnClearTarget, b2.CleanupDelete))
ecs.add(ChildOf, b2.Exclusive)

local parent = ecs.entity()
local child = ecs.entity()
ecs:add(child, pair(ChildOf, parent))

-- This will delete both parent and child
ecs.clear(parent, true)
```
