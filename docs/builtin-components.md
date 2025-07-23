---
prev:
    text: 'Queries'
    link: './queries'
next:
    text: 'Bulk Operations'
    link: './bulk-operations'
---
# Builtin Components

B2 provides a library of built-in Ids for the User to interact with. Some of them are used internally for logic,
such as `b2.Component`, and some are mere convenience - such as `b2.Name`. Here's the list:

## `Component`

This tag indicates whether a given entity is a component.

## `Name`

This Id holds a string 'name' for an entity.

## `ChildOf`

This Id is intended to describe exclusive parent-child relationships between entities.

## `Wildcard`

This Id is intended for use in [pairs](./relationships.md#wildcard-pairs) and [queries](./queries.md#wildcard-queries).

## `OnClear`

This Id is intended for use as the condition for a [cleanup trait](./cleanup-traits.md). It will apply to all entities
with this Id when this Id is cleared or deleted.

## `OnDelete`

This Id is intended for use as the condition for a [cleanup trait](./cleanup-traits.md). It will apply to all entities
with this Id when this Id is deleted.

## `OnClearAsRelation`

This Id is intended for use as the condition for a [cleanup trait](./cleanup-traits.md). It will apply to all entities
using this Id as a relation when this Id is cleared or deleted.

## `OnDeleteAsRelation`

This Id is intended for use as the condition for a [cleanup trait](./cleanup-traits.md). It will apply to all entities
using this Id as a relation when this Id is deleted.

## `OnClearTarget`

This Id is intended for use as the condition for a [cleanup trait](./cleanup-traits.md). It will apply to all entities
when the target of this Id for that entity is cleared or deleted.

## `OnDeleteTarget`

This Id is intended for use as the condition for a [cleanup trait](./cleanup-traits.md). It will apply to all entities
when the target of this Id for that entity is deleted.

## `CleanupDelete`

This Id is intended for use as the action for a [cleanup trait](./cleanup-traits.md). It will delete an entity with this
Id if the condition is met.

## Builtin Cleanup Traits

`DeleteOnClear`, `DeleteOnDelete`, `DeleteOnClearTarget`, `DeleteOnDeleteTarget`, `DeleteOnClearAsRelation`,
and `DeleteOnDeleteAsRelation`.
`DeleteOn*` == pair(On*, CleanupDelete)

## `OnAdd`

This Id is used to set a hook for when an Id is added to an entity.

## `OnChange`

This Id is used to set a hook for when an Id is changed for an entity.

## `OnRemove`

This Id is used to set a hook for when an Id is removed from an entity.

## `Exclusive`

This Id indicates a relationship is [Exclusive](./relationships.md#exclusive-relationships).
