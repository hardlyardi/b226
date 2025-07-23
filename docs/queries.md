---
prev:
    text: 'Hooks'
    link: './hooks'
next:
    text: 'Builtin Components'
    link: './builtin-components'
---
# Queries

## Introduction

Queries are the main method for you to look for a group of entities based on context/shape and operate on them.

You can create a query with `ecs.query(Terms...)`:

```lua
function query<ReadTerms>(
    ...: Ent<ReadTerms> -- Type simplified for docs
): Query<...ReadTerms>
```

Queries are used for a lot of things, but a simple example is looking for entities which have a specific Component.

```luau
local alice = ecs.entity()
local bob = ecs.entity()
ecs.set(alice, Name, "Alice")
ecs.set(bob, Name, "Bob")

for entity, name in ecs.query(Name):entities() do
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
local q = ecs.query(Tag)
for e in q:entities() do
    print(e) -- outputs only e1
end
ecs.add(e2, Tag)
for e in q:entities() do
    print(e) -- outputs e1 and e2
end
```

## Wildcard Queries

With [Wildcard Pairs](./relationships.md#wildcard-pairs) you can query for less Specific relationships.
`pair(relation, Wildcard)` and `pair(Wildcard, target)` are both valid for queries.

```luau
for entity in ecs.query(pair(Likes, b2.Wildcard)):entities() do
    print(`entity {entity} likes {ecs.target(entity, Likes)}`)
end
```

## Monitors

Monitors are similar to [Hooks](./hooks.md), but with a few key differences. Monitors are query-based, so they allow you
to broadly percieve structural changes. Monitors will inform you when an entity starts, or stops matching a query. Many
monitors can exist for one component or query - whereas only one Hook of each kind can exist per Component. Monitors can
be created or destroyed at any time - whereas hooks cannot be modified or removed once the Id is in use. In a monitor's
callback, you cannot safely modify an entity's data - whereas hooks allow you to add/set/remove components as you
please. You can also safely expect monitors to take a glug more frametime than hooks, because they need to run checks
any time you move a query term for any entity.

You can create a new monitor with `query:monitor_added(callback)` or `query:monitor_removed(callback)`.

### `query:monitor_added`

```luau
function monitor_added<Reads...>(
    self: Query<Reads...>,
    callback: (Entity, Reads...) -> ()
): () -> ()
```

Calls when an entity has started matching the query, as well as all of the data which a query normally reads. Returns a
destructor.

### `query:monitor_removed`

```luau
function monitor_removed(
    self: Query,
    callback: (Entity) -> ()
): ()
```

Calls when an entity has stopped matching the query. Returns a destructor.

## Query Builder Methods

These methods are intended to be called before any [Matching Methods](#query-matching-methods).

### `query:with`

```luau
function with<Reads...>(
    self: Query<Reads...>,
    term: Entity,
    ...: Entity
): Query<Reads...>
```

Ensures the query will only match entities which satisfy the provided terms.

### `query:without`

```luau
function with<Reads...>(
    self: Query<Reads...>,
    term: Entity,
    ...: Entity
): Query<Reads...>
```

Ensures the query will never match entities which satisfy the provided terms.

## Query Matching Methods

### `query:entities`

```luau
function entities<Reads...>(
    self: Query<Reads...>,
    cached: true?
): () -> (Ent, Reads...)
```

Returns an iterator for each entity and the value of components.

### `query:monitor_added`

```luau
function monitor_added<Reads...>(
    self: Query<Reads...>,
    callback: (Entity, Reads...) -> ()
): () -> ()
```

Calls when an entity has started matching the query, as well as all of the data which a query normally reads. Returns a
destructor.

### `query:monitor_removed`

```luau
function monitor_removed(
    self: Query,
    callback: (Entity) -> ()
): ()
```

Calls when an entity has stopped matching the query. Returns a destructor.

### `query:archetypes`

```luau
function archetypes(
    self: Query,
): { Arch }
```

Returns all archetypes that match a query. See [What is an Archetype?](./faq.md#what-is-an-archetype)

### `query:match`

```luau
function match(
    self: Query,
    archetype: Arch,
): boolean
```

Returns whether or not an archetype matches a given query.

### `query:archetypes_cached`

```luau
function archetypes_cached(
    self: Query
): { Arch }
```

Returns a **READONLY** list of archetypes which match the query with [caching](./queries.md#queryarchetypes_cached)

### `query:observe_added`

```luau
function observe_added(
    self: Query,
    callback: (Arch) -> ()
): () -> ()
```

Calls when an archetype is created which matches the query. Returns a destructor.

### `query:observe_removed`

```luau
function observe_removed(
    self: Query,
    callback: (Arch) -> ()
): () -> ()
```

Calls when an archetype which matches the query is deleted. Returns a destructor.

### `query:monitor_added_row`

```luau
function monitor_added_row(
    self: Query,
    callback: (Ent, Arch, number) -> ()
): () -> ()
```

Calls when an entity starts matching a query without reading any data.

### `query:monitor_removed_row`

```luau
function monitor_removed_row(
    self: Query,
    callback: (Ent, Arch, number) -> ()
): () -> ()
```

Calls when an entity stops matching a query without reading any data.
