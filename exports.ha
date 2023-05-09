// License: MPL-2.0
// (c) 2023 Zachary Yedidia

use hare::ast;

type expinfo = struct {
	types: []ast::ident,
	funcs: []ast::ident,
	globals: []ast::ident,
	consts: []ast::ident,
};

fn getexp(exp: *expinfo, unit: ast::subunit) void = {
	for (let i = 0z; i < len(unit.decls); i += 1) {
		exp_decl(exp, unit.decls[i]);
	};
};

fn exp_decl(exp: *expinfo, decl: ast::decl) void = {
	match (decl.decl) {
	case let d: []ast::decl_const =>
		for (let i = 0z; i < len(d); i += 1) {
			append(exp.consts, d[i].ident);
		};
	case let d: []ast::decl_global =>
		for (let i = 0z; i < len(d); i += 1) {
			append(exp.globals, d[i].ident);
		};
	case let d: []ast::decl_type =>
		for (let i = 0z; i < len(d); i += 1) {
			append(exp.types, d[i].ident);
		};
	case let d: ast::decl_func =>
		append(exp.funcs, d.ident);
	};
};
