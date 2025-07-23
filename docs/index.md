---
# https://vitepress.dev/reference/default-theme-home-page
layout: home

hero:
  name: "B2264644-3D77-4AB9-8A00-5E9FFB0FF964"
  text: "An entity component system for Luau."
  tagline: "0.2.X"
  image:
    src: /b2logo.png
    alt: B2 Logo Globally Unique Identifier
  actions:
    - theme: brand
      text: Get Started
      link: ./quick-start
    - theme: alt
      text: API Reference
      link: ./documentation

features:
  - title: Entity Relationships
    details:
        Entity relationships make it easy and lightning ⚡ fast to describe links 🔗 between entities. Exclusive
        relationships 💑 allow you to represent hierarchies directly in the ECS.
  - title: Fast Querying
    details:
        Queries are blazingly 🔥 fast and have caching, optimized 🤖 around querying many components at a time
        performantly.
  - title: Component Hooks & Cleanup Traits
    details:
        Component Hooks 🪝 & Cleanup Traits allow you to enforce 👮 invariants and attach lifecycles 🧬 to your
        entities.
  - title: First-Class Monitors / Observers
    details:
        Query monitors 🖥️ let you track entities and when they change shape in an efficient 🚀 way, enabling you to
        track changes or store data swiftly 💨 and safely 👷 outside of the ECS.
  - title: Zero Dependency API
    details:
        B2's API has zero dependencies, making it lightweight 🪶 and portable 💼.
  - title: Strictly Typed
    details:
        Internal APIs are typechecked, and the library has Luau & Typescript typings for breakneck 🤸 development pace
        and safe 🦺 code.
---
