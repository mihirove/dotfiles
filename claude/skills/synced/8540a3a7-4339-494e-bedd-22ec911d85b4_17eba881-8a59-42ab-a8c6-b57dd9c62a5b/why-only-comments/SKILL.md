---
name: why-only-comments
description: Comment discipline for any code Claude writes or edits. Comments explain WHY the code is the way it is, never WHAT it does. Use this skill every time you are about to create, modify, refactor, or fix code in a repository, prepare a commit or pull request, or apply a patch, in any language, even if the user never mentions comments. Also use it when reviewing a diff before it is committed.
---

# Why-only comments

AI-written code tends to be full of comments that narrate the code line by line
(`# Loop through users`, `// Return the result`). They add noise to reviews, drift out of
date as the code changes, and bury the few comments that actually matter. The goal of this
skill is that every comment left in a diff earns its place by telling the reader something
the code itself cannot.

## The rule

A comment should explain **why**: the reason, constraint, or context behind the code.
It should not explain **what**: anything a competent reader can see by reading the code.

Before writing a comment, ask: *"If I deleted this comment, would a reader who knows the
language lose information?"* If not, don't write it.

### Worth a comment (why)

- A non-obvious constraint: an external API quirk, a rate limit, an ordering requirement
- A workaround and what it works around (ideally with an issue/ticket link)
- A business or domain rule the code encodes (`# Contracts signed before 2020 use the old fee schedule`)
- A deliberate tradeoff or a rejected obvious alternative (`# Not using a JOIN here: the table is sharded and cross-shard joins time out`)
- A surprising value (`timeout=90  # upstream batch job p99 is ~70s`)
- Why a lint rule or type check is suppressed
- Security or concurrency reasoning that isn't visible locally

### Not worth a comment (what)

- Restating the next line: `# increment retry count` above `retries += 1`
- Section labels for obvious steps: `# Initialize variables`, `# Main logic`, `# Return response`
- Describing a function name that already says it: `# Get user by id` above `get_user_by_id()`
- Narrating control flow: `# If the list is empty, return early`
- Changelog-style notes: `# Added error handling`, `# Updated to use new API`, `# Fixed bug`. That history belongs in the commit message, not the code.
- Commented-out code

When a "what" comment feels necessary because the code is hard to follow, that is usually a
sign to improve the code instead: rename a variable, extract a well-named function, or
introduce a named constant. Only if the code genuinely can't be made clearer (a dense
regex, bit manipulation) is a short explanation acceptable.

## Docstrings and API documentation

Keep docstrings, JSDoc, KDoc, godoc, and similar documentation on functions, classes, and
modules. They document the contract (parameters, return values, errors, side effects) for
callers who won't read the implementation, so they serve a different purpose from inline
comments. Write them following the project's existing conventions. Inside a docstring, still
avoid narrating the implementation step by step.

## Scope: what to touch

- **Comments you write**: apply the rule fully.
- **Existing comments on lines you change** (or the comment directly attached to a block you
  rewrite): remove the ones that are redundant, and update any why-comment your change made
  inaccurate.
- **Existing comments elsewhere in the file**: leave them alone. Unrelated edits make diffs
  harder to review and aren't what the user asked for. If there are many, you can mention
  it to the user instead.

## Before finishing

Once your code changes are done, and before committing or handing the work back, review the
diff (`git diff`, or the edits you made) and check every added or modified comment against
the rule above. Delete or rewrite anything that describes *what*. Don't mention this cleanup
in the code itself.

Match the language and style of the existing comments in the repository (e.g. if the
codebase comments in Japanese, write why-comments in Japanese).

## Example

Before:
```python
# Get the organization usage
def get_usage(org_id, month):
    # Build the query
    query = build_query(org_id, month)
    # Retry 5 times
    for attempt in range(5):
        try:
            # Execute the query
            return client.query(query).result()
        except TransientError:
            # Raise on the last attempt
            if attempt == 4:
                raise
            # Sleep before retrying
            time.sleep(2 ** attempt)
```

After:
```python
def get_usage(org_id, month):
    """Return the monthly usage rows for an organization.

    Raises TransientError if BigQuery is still unavailable after all retries.
    """
    query = build_query(org_id, month)
    # BigQuery intermittently returns 503s during the nightly snapshot window,
    # so short exponential backoff is enough; longer outages should fail loudly.
    for attempt in range(5):
        try:
            return client.query(query).result()
        except TransientError:
            if attempt == 4:
                raise
            time.sleep(2 ** attempt)
```
