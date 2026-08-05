# Security and limits

Procedure source is untrusted input. Tursox Procedures combines several
boundaries; none is sufficient alone.

## Language capabilities

Deflua is created sandboxed. Procedure code cannot use host filesystem I/O,
process execution, environment access, `require`, `load`, or arbitrary Elixir
modules. Only `db`, `procedures`, and `fail` are installed by this package.

## Database authorization

`Policy.AllowAll` grants raw parameterized SQL through the Tursox connection and
is suitable only for trusted authors. A custom policy receives safe caller,
procedure, stack, operation, callee, and SQL metadata before each call/query/write.
It returns `:ok` or `{:error, reason}`. Parameters and rows are never passed as
policy metadata or telemetry.

SQL policy based on strings is application policy, not a full SQL security
parser. Strong tenant isolation should use separate database files/connections
or domain-specific capabilities rather than attempting to filter arbitrary SQL.

## Resource limits

`Tursox.Procedures.Limits` supplies finite defaults for:

- wall-clock timeout and BEAM process heap;
- Lua instructions, Lua call depth, and string size;
- procedure source, arguments, and results;
- procedure nesting and total calls;
- database statements, rows, and transferred bytes.

The service runs each top-level call in a monitored process. Timeout or heap
termination rolls back the checkout and leaves the service available. Nested
fresh VMs share host aggregate budgets so composition cannot reset limits.

Default errors, inspection, and telemetry exclude procedure source, arguments,
parameters, rows, caller secrets, and database content.
