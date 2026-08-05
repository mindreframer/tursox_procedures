# Operations

Applications explicitly supervise each `Tursox.Procedures` service and choose
its Tursox pool, source, policy, limits, cache capacity, duplicate-column policy,
and transaction mode. There is no global default service and no dynamic atom is
created from procedure or tenant names.

`metadata/1` returns only active call count, finite limits, transaction mode,
and cache counters. `refresh/1` drops compiled chunks without changing source
versions. Normal calls fetch the active immutable identity, so database/memory
source updates become visible without unsafe in-place cache replacement.

Telemetry events use the `[:tursox_procedures, ...]` prefix:

- `[:call, :start | :stop]`
- `[:procedure, :stop]`
- `[:database, :stop]`
- `[:cache, :stop]`

Metadata includes names, versions/hashes where applicable, depth, operation,
and outcome classes. It excludes source, SQL parameters, rows, results, and
caller data.

A graceful supervisor shutdown stops the service and its cache. Active worker
processes are terminated; DBConnection owns checkout cleanup and rollback.
