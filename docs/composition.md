# Procedure composition

`procedures.call(name, arguments)` invokes an immutable resolved procedure on
the existing execution context. The public service is not called recursively,
so a pool of size one remains sufficient for arbitrary sequential composition.

The initial contract is strict:

- one top-level checkout and transaction;
- fresh Lua VM for every procedure;
- one aggregate deadline and resource budget;
- exact call-order trace with name/version/hash only;
- cycles rejected;
- finite depth and total calls;
- child policy authorization repeated at every boundary;
- any child failure permanently marks the transaction failed.

`pcall` can be useful for formatting a Lua-level response, but cannot restore
commit eligibility after a child or host capability fails. This prevents a
child's writes before failure from being accidentally committed. Savepoint-based
recoverable children are intentionally deferred.
