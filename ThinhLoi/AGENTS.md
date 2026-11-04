# Repository agent guidance

## Code intelligence

- For repository-scale coding, use CodeGraph first for semantic symbols, callers, call paths, and impact.
- Use ast-grep CLI for structural syntax evidence when available, then reconcile semantic and structural results before broad edits.
- Keep the index current after source changes with `codegraph sync D:\ThinhLoi`.
- The generated `.codegraph/` directory is local state and must not be committed.

## Supabase schema workflow

- Every schema change must be implemented as a new non-destructive file in `backend/supabase/migrations/`; never edit a migration already applied remotely.
- After changing schema, run `backend/scripts/push_schema.ps1` for migration status and production dry-run.
- Apply pending migrations with `backend/scripts/push_schema.ps1 -Apply` only when the current user request authorizes updating the linked Supabase project.
- After applying, verify local/remote versions with `npx supabase migration list --remote` and run relevant SQL/RLS/RPC tests in a disposable environment when available.
- Never expose service-role keys, database passwords, access tokens, or `.env.local`.
