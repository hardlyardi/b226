# Contributing

Thanks for considering contributing to b2! Your help is appreciated.

## Questions

If you have a question, there are three places you can reach me, in order of most to least preferred. Please only use my
discord for critical bug reports or important issues:

- [Github Issues](https://light.ardi.gg/github_issues)

- [The Roblox OSS Server](https://discord.com/invite/5KjV64PA3d)

- [My Discord](https://discord.com/users/331399684415553538/)

## Setup

For VSCode users, open the `b2.code-workspace` code workspace. Afterwards, B2's tools can be set up locally by
installing [Rokit](https://github.com/rojo-rbx/rokit) and running the following command in the project's root directory:

```bash
rokit install
```

See [Tools](#tools) for more info.

## Style

For preferred inline documentation rules, general practices, etc., see [STYLE.md](./STYLE.md).

## Bugs & Feature Requests

If something isn't right (Unprecedented warnings, errors, etc.), please check if your issue has already been reported
before opening a [Github Issue](https://light.ardi.gg/github_issues). After an issue has been made, you're welcome to
open a [PR](https://light.ardi.gg/github_pull_request) for bugfixes or feature requests.

## PR Standards

- Modifiable

    All PRs should allow edits by maintainers. PRs that do not follow this rule will be closed.

The code should typecheck, and be formatted with [Stylua](https://github.com/JohnnyMorganz/StyLua). A typechecker pass
as well as Stylua will be run automatically on PRs.

## Performance Enhancements

Performance enhancements are always welcome as an [Issue](https://light.ardi.gg/github_issues), or
[Pull Requet](https://light.ardi.gg/github_pull_request). You will be expected to answer these questions to prove the
optimization is worthwhile:

- What is being optimized? What parts of the library does it affect?
- Is it an algorithmic (asymptotic) improvement?
- What are the drawbacks to optimizing this?
- (For pull requests) How does it perform in benchmarks?

## Tools

B2 requires a minimal set of external tools to make contributing smooth:

[NPM](https://www.npmjs.com/) (For authoring roblox-ts modifications)

[Luau LSP](https://github.com/JohnnyMorganz/luau-lsp) For luau autocomplete & editor typechecking

[MarkdownLint](https://marketplace.visualstudio.com/items?itemName=DavidAnson.vscode-markdownlint) (VSCode Plugin for linting .md files if working on docs)

[Rokit](https://github.com/rojo-rbx/rokit) For installing and using the folloiwng CLI tools:

- [Lune](https://github.com/lune-org/lune) (For running a test environment)

- [Stylua](https://github.com/JohnnyMorganz/StyLua) (For styling luau code)

## Testing / Benchmarking

Tests and benchmarks can be found in luau scripts under `tests/.specs/**.spec.luau` and
`tests/.benchmarks/**.bench.luau` respectively. The commands `lune run tests` and `lune run bench` are available. A
quick set of CLI options are provided if `-h` is passed to either command. Test / Bench result files will be generated
in the project's root under `_TESTSUITE` and `_BENCHSUITE`. There are also quick-to-access code workspace tasks for
testing and benchmarking. To access them, use a keybind, or open vscode's command palette - then type `Tasks: Run Task`.
Tasks for tests and benchmarks should show up.

## Licensing

By contributing changes to this repository, you license your contribution under the MIT License, and you agree that you
have the right to license your contribution under those terms.
