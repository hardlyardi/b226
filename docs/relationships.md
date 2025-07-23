---
prev:
    text: 'Ecs, Entities & Components'
    link: './ecs-entities-and-components.md'
next:
    text: 'Cleanup Traits'
    link: './cleanup-traits'
---
# Relationships

## Introduction

Entity relationships (pairs) make it possible to describe a graph of entities efficiently in your data.

Adding/removing pairs is similar to adding/removing regular Ids, with as difference that instead of a single Id, a
relationship adds a pair of two Ids to an entity. In this pair, the first element represents the relationship
(e.g. "Eats"), and the second element represents the target (e.g. "Apples").

Relationships can be used to describe many things, from hierarchies, to status effects, to even transactions between
player inventories. They can be created with `b2.pair(relationship, target)`. To get the target of a relationship, use
`ecs.target`:

### `ecs.target(e, rel, idx?)`

Gets the target of a relationship. A relationship is nonexclusive, meaning it can have multiple targets. Because of
this, `target` has an optional index - which starts at and will default to zero. This could be used to iterate all
targets of a relationship for an entity.

```lua
local alice = ecs.entity()
ecs.add(alice, pair(Eats, Strawberry))
ecs.add(alice, pair(Eats, HazelnutMilkChocolate))
ecs.add(alice, pair(Eats, Cheese))

local index = 0
local target = ecs.target(alice, Eats, index)
while target do
    print(ecs.get(target, b2.Name))
    index += 1
    target = ecs.target(alice, Eats, index)
end
--[[
Strawberry
HazelnutMilkChocolate
Cheese
]]
```

## Pair Components

A pair Id can be a Component too if either its relation or target are Components. E.g., pair(Component, e) and
pair(e, Component) can be set:

```luau
local Likes = ecs.component()
local Eats = ecs.entity()
local apples = ecs.entity()
local alice = ecs.entity()
local bob = ecs.entity()

ecs.set(alice, pair(Likes, bob), "somewhat")
ecs.add(alice, pair(Eats, apples))
-- This will error, because neither Eats nor apples are Components.
ecs.set(alice, pair(Eats, apples), "a lot")
```

## Exclusive Relationships

You can mark a tag or component as an exclusive relationship (i.e., it may only have one target at a time) with
`b2.Exclusive`:

```luau
local ChildOf = ecs.component()
ecs.add(ChildOf, b2.Exclusive)

local e1 = ecs.entity()
local e2 = ecs.entity()
local e3 = ecs.entity()

ecs.add(e3, pair(ChildOf, e1))
-- Removes the previous pair from e3, and sets a new target
ecs.add(e3, pair(ChildOf, e2))
```

## Wildcard Pairs

`b2.Wildcard` pairs allow you to check for a less specific version of relationships. `pair(relation, Wildcard)` and
`pair(Wildcard, target)` are both valid for queries.

```luau
local alice = ecs.entity()
local bob = ecs.entity()
ecs.add(alice, pair(Likes, bob))
ecs.has(alice, pair(Likes, b2.Wildcard)) -- true
```
