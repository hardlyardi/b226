---
prev:
    text: 'Documentation'
    link: './documentation'
next:
    text: 'Quickstart'
    link: './quick-start'
---
# FAQ

Frequently asked questions.

## What is an ECS?

See [ECS FAQ](https://github.com/SanderMertens/ecs-faq) by Sander Mertens.

## Can you set components to tables / modify them?

Yes. Mutability in components exists, but keep in mind that changing values in a table will not trigger hooks,
monitors, etc. by default.

## Can you set components to `nil`?

Yes. Component values can be set to anything and `has(e, Component)` will return true.

## What is the difference between `add` and `set`?

`add` adds a component without assigning it a value. `set` assigns a value to the component. Only `add` can be used on
tags, whereas set should be used for Components.

## What is the difference between a Component, a Tag, and a Pair/Relationship?

Components, Tags, and Relationships are all Ids, which makes them unique from other Ids. Any Id can be `add`ed to any
entity. A Tag is an Id which cannot be `set`, but can be `add`ed to an entity with no value. A Component is an Id which
can be `add`ed and `set`. A pair is a combination of two Ids (Relation, Target). A pair is a Component (i.e., it can
hold data) if either the Relation or the Target is a Component.

## Is there any built-in way to create tags?

Any Id created in the world works as a tag by default. So, no, there is no special way to create tags. You can just use
`ecs.entity` and add it to other Ids.

## Can you combine pairs? E.g., `pair(pair(A, B), pair(C, D))`?

No. Using a pair inside of a pair will use the target, so, `pair(pair(A, B), pair(C, D))` will return the
same result as `pair(B, D)`.

## What is the difference between the types `b2.Id<T>` and `b2.Ent<T>`?

`b2.Id` and `b2.Ent` have the same type as of right now. The only difference between the two is that `Id`'s type
defaults to `nil`, and `Ent` defaults to `any`.

## What is an archetype?

Entities' data in B2 is represented by Archetypes stored in the world. An archetype stores all entities with the same
shape (i.e., the same set of components) together. This is a [cache-friendly](https://vimeo.com/97337258) pattern, and
promotes fast query matching / iteration.

Other examples of Archetype ECS on roblox include [Jecs](https://github.com/ukendio/jecs).

## How does Archetype performance compare with a sparse-set implementation, e.g., [ECR](https://github.com/centau/ECR)?

- Add/remove (moving) operations are faster with sparse-sets.
- Single component queries are faster with sparse-sets.
- Multi-component queries are faster with archetypes.
- Iterating a single entity's components is faster with archetypes.

## Why are my queries slow?

Creating a new query has a nontrivial amount of overhead. Queries are the fastest way to match and iterate entities, but
are slow to create, so you should create them in advance:

```luau
local q = ecs.query(Position)

RunService.PostSimulation:Connect(function()
    for ent, position in q:entities() do
        -- ...
    end
end)
```

### A note on Caching

Queries can be 'cached' for faster iteration, but lead to slower archetype creation. Iterating a cached query is simple,
just pass in `true` to `entities()`:

```luau
local q = ecs.query(Position)

RunService.PostSimulation:Connect(function()
    -- this query will cache its archetypes
    for ent, position in q:entities(true) do
        -- ...
    end
end)
```

## Why are my entity ids so large?

When you inspect an entity Identifier directly, you might see a very large value. This is not a bug, but means that the
entity Id has been recycled. Here's an example:

```luau
local e1 = ecs.entity() -- 1025
-- delete e1, making it available for recycling
ecs.clear(e1, true)
local e2 = ecs.entity() -- 16778241
```

## Are relationships just a component with an entity value?

No, relationships are a first-class feature with multiple optimizations inside the ECS storage. Relationships can have
multiple target indices as well as multiple values - whereas a component can only have a value.
