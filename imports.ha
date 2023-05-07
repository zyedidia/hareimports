use strings;
use hare::ast;
use hare::unparse;

type import = struct {
	imp: ast::import,
	path: ast::ident,
	alias: str,
	used: bool,
};

fn cmpimport(a: const *void, b: const *void) int = {
	let a = a: const *import;
	let b = b: const *import;
	return strings::compare(unparse::identstr(a.path), unparse::identstr(b.path));
};

type impinfo = struct {
	modules: []import,
};

fn getimp(imp: *impinfo, imports: []ast::import) void = {
	for (let i = 0z; i < len(imports); i += 1) {
		if (imports[i].mode == ast::import_mode::IDENT) {
			append(imp.modules, import {
				imp = imports[i],
				path = imports[i].ident,
				alias = imports[i].alias,
				used = false,
			});
		};
	};
};

fn match_full_qual(imp: import, ident: ast::ident) bool = {
	for (let i = 0z; i < len(imp.path); i += 1) {
		if (i >= len(ident) - 1) {
			return false;
		};
		if (imp.path[i] != ident[i]) {
			return false;
		};
	};
	return true;
};

fn check_import(imp: import, ident: ast::ident) bool = {
	if (match_full_qual(imp, ident)) {
		return true;
	};

	return ident[0] == imp.path[len(imp.path) - 1];
};

// Registers the use of [[ident]] with the existing imports, and returns false
// if [[ident]] comes from a module that has not been imported.
fn register(imp: *impinfo, ident: ast::ident) bool = {
	if (len(ident) <= 1) {
		return true;
	};
	let valid = false;
	for (let i = 0z; i < len(imp.modules); i += 1) {
		if (check_import(imp.modules[i], ident)) {
			valid = true;
			imp.modules[i].used = true;
		};
	};
	return valid;
};
