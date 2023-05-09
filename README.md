# hareimports

hareimports is a tool for automatically managing imports in Hare programs. It
will sort imports and remove unused imports. In the future it may also add
imports automatically (not implemented yet).

Limitations that may be fixed in the future:

* Does not automatically add imports.
* Does not handle non-basic imports (e.g., of the form `use x::y::{a, b, c}`).
* May be fooled into thinking an import is used if there is an enum with the
  same name.

If you are interested in contributing, please open a PR. If you find any bugs,
please open an issue.

Usage:

```
Usage: hareimports [-hiw] [file...]

-h: print this help text
-i: perform changes in-place
-w: provide warning diagnostics
```
