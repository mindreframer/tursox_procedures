# Security policy

Report suspected vulnerabilities privately to the maintainer listed in
`mix.exs`. Do not include production procedure source, database contents,
bound values, credentials, or tenant data unless an encrypted channel has been
agreed first.

The planned package executes user-supplied Lua and must not treat language
sandboxing as database authorization. Procedure calls require finite execution,
heap, statement, result, nesting, and wall-clock bounds. Host filesystem,
network, process, module-loading, and environment capabilities remain disabled.
Database capabilities must be explicitly authorized for the caller and
procedure; raw SQL access is equivalent to the privileges of the checked-out
Tursox connection.

Until ROADMAP001 is complete, this repository provides no production procedure
execution boundary.
