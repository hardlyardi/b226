---
prev:
    text: 'Quickstart'
    link: './quick-start'
next:
    text: 'Entity Relationships'
    link: './relationships'
---
# ECS

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

### `ecs.add`

```luau
function add(
    entity: Ent,
    Id: Ent
): ()
```

Adds a component to an entity. If the entity already has the component, this will do nothing.

### `ecs.set`

```luau
function set<Value>(
    entity: Ent,
    Id: Ent<Value>,
    value: Value
): ()
```

Sets the value of a component for an entity. If the component does not exist on the entity, it will be added.

### `ecs.get`

```luau
function get<A, B>(
    entity: Ent,
    id: Ent<A>,
    ...: Ent<B> -- Type simplified for documentation
): (A?, ...B?)
```

Returns the value of each component passed from an entity.

### `ecs.remove`

```luau
function remove(
    entity: Ent,
    id: Ent
): ()
```

Removes a component from an entity. If the entity did not have the component, this will do nothing.

### `ecs.clear`

```luau
function clear(
    id: Ent,
    delete: true?
): ()
```

Removes all references to this entity in the ECS storage. If `delete` is specified, the entity will have all of its
components removed, and be removed from the world. Entities which are not deleted will take up memory.

## Components are Entities

In the ECS, Components need unique Identifiers, just like entities. In B2, this problem is solved by making each
component a [unique entity](./faq#what-is-the-difference-between-a-component-a-tag-and-a-pairrelationship) of its own.
Because components are entities, you can apply components to other components. You can use `ecs.has` with `b2.Component`
to check if an Id is a component:

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

Entities can also be used as a kind of component called a
['Tag'](./faq#what-is-the-difference-between-a-component-a-tag-and-a-pairrelationship). This is a component with no
data, but which can be checked with `ecs.has(e, Tag)`:

```luau
local IsAwesome = ecs.entity()

local bob = ecs.entity()
ecs.add(bob, IsAwesome)
ecs.has(bob, IsAwesome) --> true
```
