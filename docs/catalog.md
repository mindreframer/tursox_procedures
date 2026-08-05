# Procedure catalog and sources

A source resolves `%Tursox.Procedures.Procedure{}` records. Published identity is
immutable: procedure name, positive version, and SHA-256 source hash.

## In-memory source

`Tursox.Procedures.Source.Memory` is caller-supervised and useful for dynamic
application definitions, development, and tests. `publish/5` creates a new
version and disables the previous active version. `enable/3` can select a
historical version; `disable/2` leaves no active version.

## Database source

`Tursox.Procedures.Source.Database.install/2` explicitly creates the catalog.
The package never runs installation automatically. `publish/5`, `enable/4`, and
`disable/3` use parameterized SQL and an immediate transaction. A configurable
table name must be a simple validated SQL identifier.

Catalog metadata must be JSON-compatible. Source text must be valid UTF-8 and
within the configured source limit. Fetch verifies the stored SHA-256 hash and
rejects malformed/tampered rows.

Applications should authorize catalog administration separately from procedure
execution. Procedure Lua has no catalog administration capability unless the
application deliberately permits equivalent raw SQL.
