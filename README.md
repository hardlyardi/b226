# B2?

b2264644-3d77-4ab9-8a00-5e9ffb0ff964 is a robust, fast, and lightweight entity component system for Luau. It is fully
unit-tested, and supports modern features on-par with similar libraries. B2 is still early in development (pre-1.0), so,
expect breaking changes on updates to 0.**X**.0 versions.

## Why not B2?

B2 is still very early in development. Naturally, this comes with bugs, breaking changes, and an immature ecosystem.
I try my best to mitigate the former two with thorough unit tests, and a clear versioning scheme. However, if you choose
to start using B2, beware the challenges that face early adopters of new software. Additionally, B2 includes (some)
guarantees regarding querying safety which may hurt performance (benchmarks yet-to-be-seen).

## Installation

You can install b226 via [Wally](https://wally.run/package/hardlyardi/b226?version=0.2.3)

## Special Thanks

Special thanks to [Marcus](https://github.com/ukendio/), [Sona](https://github.com/SolarScuffle-Bot), and others for
making B2 possible. If you haven't seen [Jecs](https://github.com/ukendio/jecs) or you like B2, I think you should
check it out. I learnt a lot about ECS from Jecs, and it's an awesome project.

# Concepts

## ECS

You need to create an ECS object to start using B2. It acts as storage for entities and their components, allows you to
query for state, and more. There is no limit to how many ECS objects you can create.

```luau
local b2 = require(path.to.b2)
-- first argument is whether or not you're using the new solver
local ecs = b2.ecs(false)
```

## Entities

Entities represent containers for data in a game. Your game might have entities which look like characters, map objects,
projectiles, particles, etc. To give life to this entity, you'll need to add Components. For now, I'll use the built-in
component `b2.Name` as an example.

```luau
-- creates a new entity with no components and returns its identifier
local alice = ecs.entity()

ecs.set(entity, b2.Name, "Alice")
ecs.get(entity, b2.Name) --> "Alice"
```

By itself, an entity is just a unique number, and has no data. Using `ecs.contains`, you can check if an identifier
exists as a valid entity.

```luau
ecs.contains(alice) --> true
```

## Base Operations

In the ECS, there are five base operations which can act on a single entity. These operations are `add`, `set`, `get`,
`remove`, and `clear`.

### `ecs.add(entity, Component)`

Adds a component to an entity. If the entity already has the component, this will do nothing.

### `ecs.set(entity, Component, Value)`

Sets the value of a component for an entity. If the component does not exist on the entity, it will be added.

### `ecs.get(entity, Component, Components...)`

Gets the value of components from an entity.

### `ecs.remove(entity, Component)`

Removes a component from an entity. If the entity did not have the component, this will do nothing.

### `ecs.clear(entity, delete?)`

Removes all references to this entity in the ECS storage. If `delete` is specified, the entity will have all of its
components removed, and be removed from the world. Entities which are not deleted will take up memory.

## Bulk Operations

Bulk operations are like the base entity operations mentioned before, except they may operate on multiple components at
a time. There is some overhead from executing a bulk operation, but it should generally be very fast. You can expect
bulk operations to mostly behave the same as regular entity operations being repeated.

### `ecs.bulk_add(entity, { Components })`

Adds a list of components to an entity.

### `ecs.bulk_remove(entity, { Components })`

Removes a list of components from an entity.

### `ecs.bulk_set(entity, { Components }, { Value })`

Sets the values for a list of components for an entity.

### `ecs.bulk_get(entity, { Components }): { Values }`

Gets a list of values from a list of components from an entity.

## Components are Entities

In the ECS, Components need unique Identifiers, just like entities. In B2, this problem is solved by making each
component a unique entity of its own. Because components are entities, you can apply components to other components. You
can use `ecs.has` with `b2.Component` to check if an Id is a component:

```luau
local entity = ecs.entity()
local Component = ecs.component()
ecs.has(entity, b2.Component) --> false
ecs.has(Component, b2.Component) --> true
```

If a game has a component, that means that component is an entity, and you can give it metadata. Components which are
applied to components will be referred to as 'traits' from here on.

```luau
local Position = ecs.component() :: b2.Id<Vector3>
-- Using regular APIs to set traits on components!
ecs.set(Position, b2.Name, "Position")

print(`{ecs.get(Position, b2.Name)} is a Component: {ecs.has(Position, b2.Component)}`);
```

### Entities are Components (Tags)

Entities can also be used as a kind of component called a 'Tag'. This is a component with no data, but which can be
checked with `ecs.has(e, Tag)`:

```luau
local IsAwesome = ecs.entity()

local bob = ecs.entity()
ecs.add(bob, IsAwesome)
ecs.has(bob, IsAwesome) --> true
```

## Queries

Queries are the main method for you to look for a group of entities and operate on them. Queries are used for a lot of
things, but a simple example is looking for a single component.

```luau
local Tag = ecs.entity()
local alice = ecs.entity()
local bob = ecs.entity()
ecs.set(alice, Name, "Alice")
ecs.add(alice, Tag)
ecs.set(bob, Name, "Bob")
ecs.add(bob, Tag)

for entity, name in ecs.query(Name):with(Tag):entities() do
    print(entity, name)
end
-- Output:
--  1026 Alice
--  1027 Bob
```

`query:entities()` can be run multiple times and the query will remain accurate. E.g.,

```luau
local Tag = ecs.entity()
local e1 = ecs.entity()
local e2 = ecs.entity()
ecs.add(e1, Tag)
local q = ecs.query(Tag):without(Name)
for e in q:entities() do
    print(e) -- outputs only e1
end
ecs.add(e2, Tag)
for e in q:entities() do
    print(e) -- outputs e1 and e2
end
```

## Relationships

Entity relationships make it possible to describe a graph of entities efficiently in your data.

Adding/removing relationships is similar to adding/removing regular components, with as difference that instead of a
single component id, a relationship adds a pair of two things to an entity. In this pair, the first element represents
the relationship (e.g. "Eats"), and the second element represents the target (e.g. "Apples").

Relationships can be used to describe many things, from hierarchies, to status effects, to even transactions between
player inventories. They can be created with `b2.pair(relationship, target)`. To get the target of a relationship, use
`ecs.target`:

### `ecs.target(e, rel, idx?)`

Gets the target of a relationship. A relationship is nonexclusive, meaning it can have multiple targets. Because of
this, `target` has an optional index - which starts at and will default to zero. This could be used to iterate all
targets of a relationship for an entity.

More info can be found on the
[Jecs Documentation](https://ukendio.github.io/jecs/learn/overview.html#relationships).

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

## Wildcards

`b2.Wildcard` pairs allow you to query for less 'Specific' relationships. `pair(relation, Wildcard)` and
`pair(Wildcard, target)` are both valid for queries.

```luau
for entity in ecs.query(pair(Likes, b2.Wildcard)):entities() do
    print(`entity {entity} likes {ecs.target(entity, Likes)}`)
end
```

## Cleanup Traits

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

## Hooks

Sometimes you may want to ensure certain things are true of your components. For example, you may want to make sure that
any entity which recieves an Interactable component also creates a ProximityPrompt and has a component to represent it.
This is where hooks come in.

There are three typs of hooks. `OnAdd`, `OnChange`, and `OnRemove`. You can set traits for a components' hooks via
`ecs.set(Component, On*, callback)`. The callback is defined for each as:

```luau
type OnAdd<Data> = (entity: Ent, id: Ent<Data>, data: Data) -> ()
type OnChange<Data> = (entity: Ent, id: Ent<Data>, data: Data) -> ()
type OnRemove<Data> = (entity: U53, id: Ent<Data>) -> ()
```

Once a Component exists on any entity, hook callbacks for that Component cannot ever be safely added, changed, or
removed. To check if modifying a Component's hooks is 'safe', you may use `ecs.in_use(Component)`:

```luau
local Component = ecs.component()
local entity = ecs.entity()
ecs.in_use(Component) --> false
ecs.add(entity, Component)
ecs.in_use(Component) --> true
ecs.remove(entity, Component)
ecs.in_use(Component) --> true
```

Because only one component hook kind can exist per Component, it's important that hooks be used correctly. Hooks are
intended for enforcing invariants, I.e., ensuring that something is always true under certain conditions. Here's an
example of how you could use hooks:

```luau
local Player = ecs.component()
local PlayerSaveData = ecs.component()

ecs.set(Player, b2.OnAdd, function(entity)
    ecs.set(entity, PlayerSaveData, ...)
end)
```

## Monitors

Monitors are similar to Hooks, but with a few key differences. Only one Hook of each kind can exist per Component, and
hooks cannot be changed or removed. You can modify an entity from inside a hook. Monitors are the contrary - multiple of
them can exist, they can be added or removed at any time, and you cannot modify entities safely from inside monitors.
That all said, you can also expect monitors to be significantly slower than listening with hooks.

Another difference is that monitors allow you to broadly percieve structural changes based on queries. You can create a
new monitor with `query:monitor_added(callback)` or `query:monitor_removed(callback)`. Monitors will inform you when an
entity starts, or stops matching a query.

### `query:monitor_added<Reads...>(callback: (entity, Reads...) -> ())`

Calls when an entity has started matching the query, as well as all of the data which a query normally reads.

### `query:monitor_removed(callback: (entity) -> ())`

Calls when an entity has stopped matching the query.

## Each

Sometimes you may need to iterate through every entity which has a single component without reading its value. This can
be achieved with `ecs.each`:

```luau
local e1 = ecs.entity()
local e2 = ecs.entity()
ecs.add(e1, Name "Alice")
ecs.set(e2, Name, "Bob")

local has_name = {}
for entity in ecs.each(Name) do
    has_name[entity] = true
end
```

## Builtin Components

These components are properties of `b2`. User-facing builtin components include:

- Component
- Name
- Wildcard
- ChildOf
- DeleteOnClear
- DeleteOnDelete
- DeleteOnClearTarget
- DeleteOnDeleteTarget
- DeleteOnClearAsRelation
- DeleteOnDeleteAsRelation
- OnClear
- OnDelete
- OnClearTarget
- OnDeleteTarget
- CleanupDelete
- OnAdd
- OnChange
- OnRemove
- Exclusive
