# Security policy

Report suspected vulnerabilities privately to the maintainer listed in
`mix.exs`. Do not include production procedure source, database contents,
bound values, credentials, or tenant data unless an encrypted channel has been
agreed first.

Tursox Procedures executes user-supplied Lua. Deflua's language sandbox blocks
host filesystem, network/process, environment, and module-loading access, but it
is not a database authorization boundary. Every deployment must choose a policy
appropriate to its procedure authors. `Policy.AllowAll` grants the configured
Tursox connection's raw SQL authority and is only appropriate for trusted code.

Keep finite execution, heap, statement, result, nesting, and wall-clock limits.
Do not expose procedure administration to unauthorized callers. Prefer separate
databases or domain-specific capabilities where authors must not access all
tables. Errors, inspection, and telemetry are designed to exclude source,
arguments, SQL parameters, rows, results, and caller secrets; reports should
still be reviewed before sharing.
