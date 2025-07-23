---
prev:
    text: 'Cleanup Traits'
    link: './cleanup-traits'
next:
    text: 'Queries'
    link: './queries'
---
# Hooks

Sometimes you may want to ensure certain things are true of your components. For example, you may want to make sure that
any entity which recieves an Interactable component also creates a ProximityPrompt and has a component to represent it.
This is where hooks come in.

There are three typs of hooks. `OnAdd`, `OnChange`, and `OnRemove`. You can set traits for a components' hooks via
`ecs.set(Component, On*, callback)`. Hook callbacks should never yield. The callback is defined for each as:

```luau
type OnAdd<Data> = (entity: Ent, id: Ent<Data>, data: Data) -> ()
type OnChange<Data> = (entity: Ent, id: Ent<Data>, data: Data) -> ()
type OnRemove<Data> = (entity: Ent, id: Ent<Data>) -> ()
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

ecs.set(Player, b2.OnAdd, function(entity)
    local group_rank = ...
    ecs.set(entity, GroupRank, group_rank)
end)
```
