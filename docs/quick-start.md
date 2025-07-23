---
prev:
    text: 'Frequently Asked Questions'
    link: './faq'
next:
    text: 'ECS, Entities & Components'
    link: './ecs-entities-and-components'
---
# Installation

If using Roblox Studio, prebuilt `.rbxm` files are available in B2's <a href="https://github.com/hardlyardi/b226/releases" target="_blank">github releases</a>.

You can also install b226 through <a href="https://wally.run/" target="_blank">Wally</a> in `wally.toml`:

```toml
b2 = "hardlyardi/b226@0.1.0"
```

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

In the ECS, there are five base operations which can act on a single entity. These operations are:

- `add(ent, Id)`
- `set(ent, Id, value)`
- `get(ent, Id)`
- `remove(ent, Id)`
- `clear(ent, delete?)`

You'll learn more about these operations in the [Next Section](./ecs-entities-and-components.md)
