# B2 Style Guide

## Rule No.1

The best style guide is your own discretion. The hope of this guide is that any potential contributor to this project
will get a "vibe" for the values it holds in regards to styling code. If you're thinking about the guide too much while
writing, don't worry about it. Additionally, PRs to change the style guide or improve code styling are always welcome.

## Code

### Column Width

The column width limit for this project is and always will be `120`. This limit is consistent for markdown, code,
comments, etc. Thinking about variable column limits is more confusing than keeping the same for all cases. Wrapping
should always and only happen at the furthest applicable boundary that does not harm readability. If a portion of
documentation is in parenthesis and requires a line break, it is recommended to put the line break at the beginning of
the parenthesis. A ruler is enabled in the project's `settings.json` to make sure that the column width limit is easy to
see and wrap. Never exceed this limit unless an ignore comment is written for a formatter and / or reader. The limit
should only be exceeded for extreme boilerplate, or cases where reading after the column width isn't remotely important.

### Formatting

All code must abide by the Stylua formatter. Ignore flags are acceptable, but should not be excessive.

### Casing

All code should use `snake_case` for types, variables, etc.

## Documentation

### Moonwave

B2 isn't designed for moonwave or other docgen in mind This is done to decouple source code (internal) documentation,
inline (user-facing) documentation, and the site which hosts documentation. This decoupling involves more work; however,
each source serves a different purpose:

- Documentation Site

    The documentation site can be found on [b2.ardi.gg](https://b2.ardi.gg/). The goal of the site is to explain how you
can use b2. It needs to be quick to grasp for anyone. As such, the site requires a friendly ground for beginners, people
browsing, or people trying to understand the API. It also needs to have examples of how the API *should* be used, and
how it is commonly *mis*-used.

- Inline Documentation

    The goal of inline documentation is to communicate to people, in their editor, about types and inputs in places they
may not need to open the site. Inline documentation should be sb2ly more terse than the site, although often based
upon it. This can include function signatures placed earlier, and less warnings / examples.

- Source Code Documentation

    Source code documentation is found in the form of code comments. Usually, the goal for a comment is to explain why
something was done in a certain way to anyone reading a portion of code. It's unknown whether someone is reading
code to debug their code, to debug b2's code, to modify code, or to understand b2 for any reason including, but
not limited to the former two. If the code does not or can not speak for itself, a comment should speak to the *why*
rather than the what.

### General Rules

- Place comments on the preceding line(s) to a portion of code.

    Always putting a comment line(s) prior to code line(s) makes the location of a comment consistent for readers, and
putting it on the line of code can push [column width](#column-width) a bit far. As an exception, it is okay to put very
simple comments on or after a line of control flow. E.g.,

    ```luau
    if foo then --fast-path
        return 123
    else --slow-path
        make_new()
    end
    ```

This is because putting a comment after a `#!luau return`, `#!luau break`, `#!luau continue`, etc. can look bad for
indentation, and an `else` statement will not push the [column width](#column-width) by much.

- Block Comments use `--[[`

    Block comments should generally always be styled with `--[[`, although there are some exceptions. Keeps block
comment style consistent and allows for additions to this style guide to include other kinds of block comment styling.

### "Why" over "What"

When code does not or can not explain itself, comments should be focused on *why* the code is, not *what* the code is.

- Prior Context

    If an explanation for a comment does not make sense without prior context or other code, it is bad. Any comment
should be "self-contained" in a way that anyone can comprehend *why* as long as they're familiar with a high level
representation of *what* the problem being solved is. If you need to explain something that cannot follow this rule,
(as much as I would encourage avoiding this), a separate commit should be made for the comment, and it should include a
link to a commit's blob under a specific line of code.

- Legacy Comments

    Comments for general segments of code that do not or might not make sense after future changes are bad. **DO NOT
EXPLAIN WHY SOMETHING WAS REMOVED IN A COMMENT!**

- Data Structures & Patterns

    Data structures and code patterns are somewhat unique in how they follow this ideal, because often the *why* of a
pattern is closely tied to *what* it is. Make sure the explanation for code patterns or data structures are immediate
relative to the code, and independant of any consumer. E.g., a comment above a sparse set should not say *what* happens
in some other code gets an index from it, or when another file imports it. Instead, it should explain why accessing a
sparse set is more advantageous compared to alternatives such as a dense array. This is primarily to avoid
[Legacy Comments](#why-over-what), as well as [Prior Context](#why-over-what) violations.

- Documentation Exception

    Inline docs intended for hover and autocomplete hints often need to explain *what* rather than why. Generally, this
kind of documentation should be restricted to inline documentation. If you are writing documentation for a function, or
otherwise need to explain *what* rather than why, use a `--[=[` block comment as opposed to `--[[`.

### Distinction

This section exists to make sure certain portions and kinds of code are distinct in their comment explanations.

- Use of single comments vs. multi-line comments.

    All lines explaining a line of code, specific control flow, individual expression, or type/alias should use multiple
comments. E.g.,

    ```luau
    --- Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna
    --- aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
    --- Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur
    --- sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
    local foo = "test"
    ```

    In contrast, explanations for multiple portions of code must be enclosed in a multiline comment `--[[` or `--[=[` even
    if the explanation is only a single line. E.g.,

    ```luau
    --[[
    Get imports from foo
    ]]
    local a = foo.a
    local b = foo.b
    local c = foo.c
    ```

    Doing this makes it a lot more clear where the scope of a comment begins and ends, it should be immediately clear from
    the use of single-line comments that you're explaining the single proceeding portion of code. A multiline comment is
    broader, and should always be used for function documentation.

- Function Documentation Uses `--[=[`

    If it was unclear before, documented functions should be immediately preceded by their `--[=[` block comment. This
makes sure it is immediately obvious you are explaining what a function is and does, as opposed to why it exists. If you
are explaining why it exists or is used locally in a file, use a `--[[` block above the doc comment.

- Separate Boundaries

    If there is a boundary between the purpose of multiple sections / blocks of comments, they should not be combined
into one comment. E.g., a function's inline justification should not be in the same block as its doc comment:

    ```luau
    --[[
    Performance; Calling CFrame * CFrame has some slight overhead from metatable access, which we can eliminate by causing
    an error in a C-implemented function and retrieving it with xpcall and debug.info
    ]]
    --[=[
    Multiply `cframe_a` by `cframe_b`.
    ]=]
    local _, CFrame__mult: (cframe_a: CFrame, cframe_b: CFrame) -> (CFrame) = xpcall(function()
        return (CFrame.identity :: any) * nil
    end, function()
        return debug.info(2, "f")
    end)
    ```

    Or, as another example, an explanation for a file should not be in the same comment as the constants.

    ```luau
    --[[foo.luau
    This file exists to lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut
    labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex
    ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla
    pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est
    laborum.
    ]]
    --[[CONSTANTS
    FOO:
        Lorem ipsum dolor sit amet
    BAR:
        consectetur adipiscing elit
    BAZ:
        sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    ]]
    ```
