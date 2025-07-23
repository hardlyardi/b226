---
prev:
    text: 'Builtin Components'
    link: './builtin-components'
next:
    text: 'Home'
    link: './'
---
# Bulk Operations

Bulk operations are like the [base entity operations], except they may operate on multiple components at a time. There
is some overhead from executing a bulk operation, but it should generally be very fast. You can expect bulk operations
to mostly behave the same as regular entity operations being repeated.

## `ecs.bulk_add`

```luau
function bulk_add(
    entity: Ent,
    components: { Ent }
): ()
```

Adds a list of components to an entity.

## `ecs.bulk_remove`

```luau
function bulk_remove(
    entity: Ent,
    components: { Ent }
): ()
```

Removes a list of components from an entity.

## `ecs.bulk_set`

```luau
function bulk_set<Value>(
    entity: Ent,
    components: { Ent<Value> },
    values: { Value }
): ()
```

Sets the values for a list of components for an entity.

## `ecs.bulk_get`

```luau
function bulk_set<Value>(
    entity: Ent,
    components: { Ent<Value> }
): { Value }
```

Gets a list of values from a list of components from an entity.
