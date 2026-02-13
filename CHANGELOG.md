# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 0.3.X - Unreleased [<small>(Full Log)</small>](https://github.com/hardlyardi/b226/compare/0.2.3...0.3.X)

### Changed

- ✅ Renamed Query Observers -> Query Reporters
- ✅ Renamed Query Monitors -> Query Watchers
- ✅ Query Watchers now work with all currently available query terms, such as wildcard pairs. Watchers will be invoked
immediately after an entity moves and values have been assigned. They also now occupy ~4 bytes of memory for each
matching archetype.
- You can now use wildcard pairs with `ecs.remove`. Calling `ecs.get`, `ecs.has`, and reading values with queries is now
formally supported for wildcards.
- Relationship target order is no longer guaranteed after an entity has been moved.

### Added

- Storage Spectators: Spectate a specific archetype and callback when specific things happen in this archetype.
(Entity leaving or joining, base operations)
- New utility script: Entity Prefabs, allowing you to compose default shapes & values for an entity.
- `b2.Transitive` for reasoning about descendant trees. E.g., if bob has `(InsideOf, Seattle)` where Seattle has
`(InsideOf, Washington)` where InsideOf has `b2.Transitive`, then, querying or using
`ecs.has(bob, pair(InsideOf, Washington))` will return true. Giving a "leaf" entity a transitive relation incurs no
extra overhead for transited relations.
- new `ecs.on_add`, `ecs.on_remove`, and `ecs.on_change` signals.
- `b2.IsA` for constructing component / relationship inheritance.
- `ecs.ids_of(entity)` for retrieving every id an entity contains. Does not include implicit IDs such as Wildcards,
Inheritance, or Transitive Relationships.

### Fixed

- Fixed bugs with moving & ensuring dense archetypes which led to errors or getting undefined components returning
`false`.
- ✅ Fixed archetypes allocating 8x as much memory as necessary for paged bitset matching.

### Improved

- All write operations (add, set, remove) should now be slightly faster.
- Query matching now utilizes probabilistic data structures for Archetypal IDs. This can lead query matching to skip
computation on some archetypes partially or entirely.
- Query watchers have been algorithmically changed to store a cache of matching watchers for each archetype. If both
archetypes have watchers, add/removed watcher signals will be matched in linear time.
- Added test cases for entity recycling, and improved testing for relationships to be order-independent.

## 0.2.3 - 2025-07-17 [<small>(Full Log)</small>](https://github.com/hardlyardi/b226/compare/0.2.2...0.2.3)

### Improved

- Doubled performance

## 0.2.2 (0.2.X) - 2025-07-17 [<small>(Full Log)</small>](https://github.com/hardlyardi/b226/compare/0.1.0...0.2.2)

### Changed

- Changed naming for b2 cleanup traits:
<br>CleanupOnClear -> OnClear,
<br>CleanupOnClearTarget -> OnClearTarget,
<br>Cleanup actions (E.g., CleanupDelete) have retained their naming.
- Deleting an entity now clears its components after clearing references instead of before.
- You can now modify entities from inside hooks.

### Added

- ecs.in_use(entity) to check if it is safe to change the hooks on an id
- New cleanup conditions:
<br>OnClearAsRelation (cleans when this ID is used as the first item of a relationship, OnClear/OnDelete does not have this behavior)
<br>OnDelete, OnDeleteTarget, OnDeleteAsRelation
- Prebuilt Cleanup Trait Pairs:
<br>DeleteOnClear + DeleteOnDelete
<br>DeleteOnClearTarget + DeleteOnDeleteTarget
<br>DeleteOnClearAsRelation + DeleteOnDeleteAsRelation
- Query monitors:
<br>query:monitor_added(callback)
<br>query:monitor_removed(callback)
<br>query:monitor_added_row(callback)
<br>query:monitor_removed_row(callback)
<br>As of right now, query monitors do not support wildcard queries.

### Fixed

- Fixed multiple bugs with pairs
- Fixed a bug with ecs.bulk_set not changing values
- Fixed a bug with arch_ensure_dense / queries that could lead to UB
- Fixed a bug with removed observers that could lead to UB
- Fixed multiple bugs with ecs.clear

### Improved

- Proper README documentation
- Improved Unit Testing for Queries, Bulk API, Observers, Monitors, Graph Traversal, and more.
- Optimized memory efficiency for hooks on relations
- Optimized query matcher caching to inline the first fastpath
- Query match page tests are now stored in a sorted array (based on page ptr) for more predictable access patterns

## 0.1.0 (0.1.X) - 2025-07-05 <small>(Initial Release)</small>

### Highlights

- Bulk API
- Cached queries:
<br>query:entities_cached() [call multiple times]
<br>query:archetypes_cached() [readonly]
<br>query:observe_added(callback)
<br>query:observe_removed(callback)
- Exclusive Relationships
- Cleanup Traits
- Old & New Solver support:
<br>b2.ecs(new_solver)
