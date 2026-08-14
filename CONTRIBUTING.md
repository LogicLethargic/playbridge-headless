# Contributing

The project is intentionally small and evidence-driven.

## Workflow

1. Reproduce the behavior.
2. Record measurements and commands.
3. Inspect the relevant upstream source.
4. Prefer the smallest change that tests the hypothesis.
5. Pin the upstream revision used for validation.
6. Build and measure the patched result.
7. Document what was observed versus inferred.

## Validation

Run:

```bash
./scripts/verify.sh
```

Then build against a pinned upstream revision:

```bash
PLAYBRIDGE_REF=<revision> ./scripts/build.sh
```

For performance validation, capture before/after process and thread measurements and, when useful, a focused syscall trace. Avoid reporting an improvement unless it has actually been measured.

## Scope

Keep upstream source out of this repository unless there is a clear licensing and maintenance reason to include it. Prefer patches, scripts, tests, and documentation that make the downstream delta easy to review.
