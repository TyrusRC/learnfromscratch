---
title: "Welcome to Learn From Scratch"
date: 2026-05-22 10:00:00 +0700
categories: [Meta]
tags: [welcome]
---

This is the first post on *Learn From Scratch* — a place to keep my
notes as I learn programming topics from the ground up.

## What lives here

- **Categories** group posts by broad area (e.g. `Python`, `Security`,
  `DevOps`). Each post belongs to one category.
- **Tags** are flat labels — `asyncio`, `decorators`, `xss`, `nginx` —
  and a post can have as many as it needs.
- The **sidebar** is the main way to navigate: home, categories, tags,
  archives, and About.

## Front-matter template

Every post starts with a block like this:

```yaml
---
title: "Post title here"
date: 2026-05-22 10:00:00 +0700
categories: [Python, Async]
tags: [asyncio, coroutines]
---
```

## Hello, code

Code blocks use fenced syntax with a language hint so Rouge can
highlight them:

```python
def greet(name: str) -> str:
    return f"Hello, {name}!"

print(greet("world"))
```

That's it — more posts coming as I learn.
