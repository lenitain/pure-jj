# pure-jj

A complete Jujutsu segment for [pure](https://github.com/pure-fish/pure), extracted as a standalone project.

Pure's git segment shows branch, dirty state, stash, and upstream ahead/behind. `pure-jj` provides the same level of information for jj, plus the pieces that only make sense in jj: the nearest bookmark, bookmark push state, and jj's conflict/divergence/empty states.

```
k feature~2⇡1* ×
```

- `k` — working-copy change id
- `feature~2` — the nearest useful local bookmark; `@` is 2 changes past it
- `⇡1` — one commit to push to the bookmark's tracked remote
- `*` — the working-copy change is non-empty
- `×` — the change has conflicts

## Display

```
<change-id> [<reference>] [<working-copy marker>] [<state markers>] [<stats>] [<description>]
```

### Reference

The reference is the closest local bookmark, or `trunk()` when no local bookmark is nearby.

- `main` — `@` is exactly on the bookmark.
- `main~3` — `@` is three changes past the bookmark.
- `main+3` — `@` is three commits before the bookmark (the bookmark is a descendant).
- `main~20+` — the search depth was reached; the real distance is 20 or more.
- Multiple bookmarks on the reference commit are comma-separated: `release~2,main~2`.
- If no local bookmark is within `pure_jj_search_depth`, the trunk bookmark is used, e.g. `main~4`. An unnamed trunk falls back to `trunk`.

The empty working-copy commit is not counted when measuring an ancestor distance. A brand-new empty `@` directly on `main` shows `main (empty)`, not `main~1`.

### Upstream sync

Sync state is attached to each displayed bookmark:

| Suffix | Meaning |
| --- | --- |
| `⇡2` | Local bookmark is 2 commits ahead of its tracked remote (2 to push) |
| `⇣1` | Local bookmark is 1 commit behind its tracked remote (1 to pull) |
| `⇡2⇣1` | Local and remote have diverged |
| `20+` | The count is a lower bound reported by jj |
| `?` | There is no tracked upstream (local-only bookmark, or the remote is untracked) |
| `!` | The local bookmark itself is conflicted |

When `pure_show_numbered_git_indicator` is `false`, only the arrows are shown. With multiple tracked remotes, the largest ahead/behind counts are shown.

### Working-copy and state markers

| Marker | Meaning |
| --- | --- |
| `(empty)` | The current change modifies no files |
| `*` | The current change is non-empty |
| `×` | The change has unresolved conflicts |
| `≠` | The change is divergent |
| `🔒` | The change is immutable (opt-in) |
| `∅` | Non-empty change without a description (opt-in) |

`*` is jj's closest equivalent to git's dirty marker: the working-copy change contains content. Unlike git, jj keeps that content in `@`; use `jj commit`/`jj new` when you want an empty `@`.

### Optional extras

- File statistics (`+added -removed ~modified`) from `@`'s diff, counts included.
- Trunk distance (`↥2 ↧1`): how far `@` is from `trunk()` even when the displayed reference is another bookmark.
- The current change description, truncated to a configurable width.

## Installation

Requirements:

- fish 4.x (fish 3.5+ may work)
- [pure](https://github.com/pure-fish/pure) 4.x
- jj with bookmark tracking template methods; tested with jj 0.46.0

### Fisher

```fish
fisher install lenitain/pure-jj
```

Until the repository is published, install from a local checkout:

```fish
fisher install ~/.projects/pure-jj
```

### Manual / development

Put the `functions/` directory ahead of pure's vendor directory and source the defaults:

```fish
set --global --prepend fish_function_path ~/.projects/pure-jj/functions
source ~/.projects/pure-jj/conf.d/pure_jj.fish
```

This is how the author's dotfiles wire it, so the plugin source stays outside the dotfiles repository. Do not load another `_pure_prompt_git` override at the same time.

## Configuration

All options are read at prompt time; set them as universal or global fish variables.

| Variable | Default | Description |
| --- | --- | --- |
| `pure_enable_jj` | `true` | Set to `false` to fall back to pure's git segment in jj repositories |
| `pure_jj_show_bookmarks` | `true` | Show the nearest bookmark/trunk reference |
| `pure_jj_show_commit_id` | `false` | Show the shortest commit id after the change id |
| `pure_jj_search_depth` | `20` | Maximum commits walked for bookmark/trunk distance (capped at 100) |
| `pure_jj_show_bookmark_distance` | `true` | Show `~N` / `+N` distances |
| `pure_jj_show_bookmark_sync` | `true` | Show `⇡`/`⇣`/`?` bookmark sync markers |
| `pure_jj_show_bookmark_conflict` | `true` | Show `!` on conflicted bookmarks |
| `pure_jj_show_empty` | `true` | Show `(empty)` for an empty working-copy change |
| `pure_jj_show_dirty` | `true` | Show `*` for a non-empty working-copy change |
| `pure_jj_show_conflict` | `true` | Show `×` for conflicted changes |
| `pure_jj_show_divergent` | `true` | Show `≠` for divergent changes |
| `pure_jj_show_immutable` | `false` | Show `🔒` for immutable changes |
| `pure_jj_show_trunk_distance` | `false` | Show `↥`/`↧` distance from `trunk()` when the reference is a bookmark |
| `pure_jj_show_statistics` | `false` | Show `+added -removed ~modified` file counts |
| `pure_jj_show_description` | `false` | Show the current change description |
| `pure_jj_description_max_length` | `40` | Description truncation width |
| `pure_jj_show_no_description` | `false` | Show `∅` for a non-empty change without a description |
| `pure_jj_trunk_label` | `trunk` | Label used when `trunk()` has no bookmark name |

`pure_show_numbered_git_indicator` (pure's existing option) controls whether sync counts are printed; distances are always printed.

### Symbols

`pure_symbol_jj_dirty` (`*`), `pure_symbol_jj_empty` (`(empty)`), `pure_symbol_jj_conflict` (`×`), `pure_symbol_jj_divergent` (`≠`), `pure_symbol_jj_no_upstream` (`?`), `pure_symbol_jj_bookmark_conflict` (`!`), `pure_symbol_jj_immutable` (`🔒`), `pure_symbol_jj_no_description` (`∅`), `pure_symbol_jj_ahead` (`⇡`), `pure_symbol_jj_behind` (`⇣`), `pure_symbol_jj_ancestor` (`~`), `pure_symbol_jj_descendant` (`+`), `pure_symbol_jj_trunk_ahead` (`↥`), `pure_symbol_jj_trunk_behind` (`↧`), `pure_symbol_jj_stats_added` (`+`), `pure_symbol_jj_stats_removed` (`-`), `pure_symbol_jj_stats_modified` (`~`).

### Colors

`pure_color_jj_change_id`, `pure_color_jj_bookmark`, `pure_color_jj_commit_id`, `pure_color_jj_dirty`, `pure_color_jj_empty`, `pure_color_jj_conflict`, `pure_color_jj_divergent`, `pure_color_jj_no_upstream`, `pure_color_jj_bookmark_conflict`, `pure_color_jj_immutable`, `pure_color_jj_ahead`, `pure_color_jj_behind`, `pure_color_jj_trunk_ahead`, `pure_color_jj_trunk_behind`, `pure_color_jj_description`, `pure_color_jj_no_description`, `pure_color_jj_stats_added`, `pure_color_jj_stats_removed`, `pure_color_jj_stats_modified`.

They default to pure's palette (`pure_color_mute`, `pure_color_info`, `pure_color_danger`, ...).

## How it works

1. `_pure_jj_repo_root` walks up from `$PWD` looking for `.jj` using fish builtins only (no fork).
2. `_pure_prompt_jj` runs one depth-bounded `jj log` with a template that returns `@`, the nearest ancestor/descendant bookmark paths, and trunk distance in one pass.
3. If a bookmark is displayed, a second `jj bookmark list -r @ -r ... --all-remotes` call reads ahead/behind counts for its tracked remotes.
4. `_pure_prompt_git` tries jj first, then falls back to pure's existing git helpers. The git fallback duplicates only pure's small dispatcher, not its branch/dirty/stash logic.

Both jj calls use `--ignore-working-copy`, so opening a prompt never snapshots the working copy, takes a repo lock, or writes an operation.

Typical cost: one jj process (~15-20 ms) when no bookmark is displayed, two (~30-40 ms) when bookmark sync is shown. This is comparable to pure's git segment, which runs several git processes.

## Limitations

- **Working-copy state is from the last snapshot.** `--ignore-working-copy` deliberately does not scan the filesystem. After editing files, `(empty)`, `*`, conflict flags, and file statistics can lag until the next jj command snapshots the working copy. This is the price for a prompt that never mutates the repository.
- **No stash marker.** jj has no stash; use `jj undo`, `jj op restore`, or abandoned/parked changes instead.
- **Depth is bounded.** `pure_jj_search_depth` defaults to 20 and is capped at 100. A truncated distance is shown as `N+`.
- **Only local bookmarks are references.** Remote-only bookmarks are visible only through the `trunk()` fallback.
- **Multiple tracked remotes** are reduced to the largest ahead and behind counts; the counts may come from different remotes.
- **Merges.** A nearest bookmark can be reachable through multiple paths; the distance is the size of the union of those paths. Normal linear stacks are exact.
- **No snapshot toggle.** If you want a live working-copy mirror, run `jj status` (or use a filesystem watcher) separately.
- **Overrides pure's dispatcher.** The git fallback mirrors pure 4.19's `_pure_prompt_git` ordering. If pure adds a new git component, update `functions/_pure_prompt_git.fish`.

## Status

Tested with jj 0.46.0, pure 4.19.0, and fish 4.9.3 on Linux.

## License

MIT
