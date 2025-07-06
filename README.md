# Intro

b2264644-3d77-4ab9-8a00-5e9ffb0ff964 is a fast entity component system for luau. It is fully unit-tested, and supports
modern features. B2 is still early in development (pre-1.0), so, expect breaking changes on updates to 0.X.0 versions.
This page is mostly based on [Jecs Documentation](https://ukendio.github.io/jecs/learn/overview.html).

## Installation

You can install b226 via [Wally](https://wally.run/package/hardlyardi/b226?version=0.1.0)

## Making an ECS

You need to create an ECS object to start using B2. This will store your entities, components, etc.

```luau
local b2 = require(path.to.b2)
local ecs = b2.ecs(false :: false)
```

## Entities

Entities represent things in a game. In a game there may be entities of characters, buildings, projectiles, particle
effects, etc.

By itself, an entity is just an unique entity identifier without any data. An entity identifier contains information
about the entity itself and its generation.

```luau
-- creates a new entity with no components and returns its identifier
local entity = ecs.entity()

-- deletes an entity and all its components
ecs.clear(entity, true)
```

## Components

A component is something that is added to an entity. Components can simply tag an entity (`"this entity is an Npc"`),
attach data to an entity (`"this entity is at Position Vector3.new(10, 20, 30)"`) and create relationships between
entities (`"bob Likes alice"`) that may also contain data (`"bob Eats 10 apples"`).

## Operations

### `ecs.clear(entity, delete?)`

Removes all references to this entity in the ECS storage. If `delete` is specified, the entity will have all of its
components removed, and be removed from the world. Entities which are not deleted will take up memory.

### `ecs.add(entity, Component)`

Adds a component to an entity. If the entity already has the component, this will do nothing.

### `ecs.remove(entity, Component)`

Removes a component from an entity. If the entity did not have the component, this will do nothing.

### `ecs.set(entity, Component, Value)`

Sets the value of a component for an entity. If the component does not exist on the entity, it will be added.

### `ecs.get(entity, Component, Components)`

Gets the value of components from an entity.

## Bulk Operations

Bulk operations have slightly more overhead, but can help you optimize certain operations. These operate on many
components at once, but generally, they behave the same as the base operations repeated.

### `ecs.bulk_add(entity, { Components })`

Adds a list of components to an entity.

### `ecs.bulk_remove(entity, { Components })`

Removes a list of components from an entity.

### `ecs.bulk_set(entity, { Components }, { Value })`

Sets the values for a list of components for an entity.

### `ecs.bulk_get(entity, { Components }): { Values }`

Gets a list of values from a list of components from an entity.

## Components Are Entities

In an ECS, components need to be uniquely identified. In B2, this is done by making each component its own unique
entity. This means that everything is customizable. Components are no exception and all of the APIs that apply to
regular entities also apply to component entities.

If a game has a component Position and Velocity, there will be two entities, one for each component. Component entities
can be distinguished from "regular" entities as they have a Component component.

```luau
local Position = ecs.component() :: b2.Entity<Vector3>
ecs.set(Position, b2.Name, "Position") -- Using regular apis to set metadata on component entities!

print(`{ecs.get(Position, b2.Name)} is a Component: {ecs.has(Position, b2.Component)}`);

-- Output:
--  Position is a Component: true
```

## Hooks

Component data generally need to adhere to a specific interface, and sometimes requires side effects to run upon certain
lifetime cycles. In b2, there are hooks which are traits (components which are used on other componnts), that can define
the behaviour of a component and enforce invariants, but can only be invoked through mutations on the component data.
You can only configure a single OnAdd, OnRemove and OnChange hook per component, just like you can only have a single
constructor and destructor.

```luau
local Transform = ecs.component()
ecs.set(Transform, b2.OnAdd, function(entity, id, data)
    -- A transform component `id` has been added with `data` to `entity`
end)
ecs.set(Transform, b2.OnChange, function(entity, id, data)
    -- A transform component `id` has been changed to `data` on `entity`
end)
ecs.set(Transform, b2.OnRemove, function(entity, id)
    -- A transform component `id` has been removed from `entity`
end)
```

## Relationships

Relationships makes it possible to describe entity graphs natively in ECS.

Adding/removing relationships is similar to adding/removing regular components, with as difference that instead of a
single component id, a relationship adds a pair of two things to an entity. In this pair, the first element represents
the relationship (e.g. "Eats"), and the second element represents the relationship target (e.g. "Apples").

Relationships can be used to describe many things, from hierarchies to inventory systems to trade relationships between
players in a game. More info can be found on the
[Jecs Documentation](https://ukendio.github.io/jecs/learn/overview.html#relationships)

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

## Cleanup Traits

When entities that are used as tags, components, relationships or relationship targets are deleted, cleanup traits
ensure that the store does not contain any dangling references. Any cleanup policy provides this guarantee, so while
they are configurable, games cannot configure traits that allows for dangling references.

To configure a cleanup policy for an entity, a (Condition, Action) pair can be added to it. If no policy is specified,
the id will be removed on cleanup.

Right now, there are two cleanup conditions:

- `CleanupOnClear`: the component, tag or relationship is cleared or deleted.
- `CleanupOnClearTarget`: a target used with the relationship is cleared or deleted.

And one cleanup action:

- `CleanupDelete`: When the condition is met, entities with this ID will be deleted.

### (CleanupOnClear, CleanupDelete)

```luau
local Archer = ecs.component()
ecs.add(Archer, b2.pair(b2.CleanupOnClear, b2.CleanupDelete))

local e = ecs.entity()
ecs.add(e, Archer)

-- This will delete e because Archer has an (OnDelete, Delete)
-- cleanup policy
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
