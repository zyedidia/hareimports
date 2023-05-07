use bufio;
use encoding::utf8;
use fmt;
use fs;
use hare::ast;
use hare::lex;
use hare::parse;
use hare::unparse;
use io;
use os;
use sort;
use types;

export fn main() void = {
	if (len(os::args) <= 1) {
		fmt::fatalf("no input");
	};

	for (let i = 1z; i < len(os::args); i += 1) {
		const file = match (os::open(os::args[i])) {
		case let f: io::file =>
			yield f;
		case let err: fs::error =>
			fmt::fatalf("unable to open {}: {}", os::args[i], fs::strerror(err));
		};
		check_file(file, os::args[i]);
		io::close(file)!;
	};
};

fn check_file(file: io::handle, name: str) void = {
	let lexer = lex::init(file, name, lex::flags::COMMENTS);

	let unit = match (parse::subunit(&lexer)) {
	case let unit: ast::subunit =>
		yield unit;
	case let err: parse::error =>
		fmt::fatalf("{}: error while parsing: {}", name, parse::strerror(err));
	};

	let imp = impinfo { ... };
	getimp(&imp, unit.imports);

	for (let i = 0z; i < len(unit.decls); i += 1) {
		visit_decl(&imp, unit.decls[i]);
	};

	// TODO: have a diagnostic option
	// for (let i = 0z; i < len(imp.modules); i += 1) {
	// 	if (!imp.modules[i].used) {
	// 		fmt::printfln("{}: unused import: {}", name, unparse::identstr(imp.modules[i].path))!;
	// 	};
	// };

	io::seek(file, 0, io::whence::SET)!;
	let scan = bufio::newscanner(file, types::SIZE_MAX);

	// TODO: check if there are no modules
	let first = imp.modules[0].imp.start.line;
	let last = imp.modules[len(imp.modules)-1].imp.end.line;

	let line = 0z;
	for (true) match (bufio::scan_line(&scan)) {
	case let err: io::error =>
		fmt::fatalf("{}: error while scanning: {}", name, io::strerror(err));
	case io::EOF =>
		break;
	case utf8::invalid =>
		break;
	case let s: const str =>
		line += 1;
		if (line == first) {
			sort::sort(imp.modules, size(import), &cmpimport);

			for (let i = 0z; i < len(imp.modules); i += 1) {
				if (!imp.modules[i].used) {
					continue;
				};

				unparse::import(os::stdout, imp.modules[i].imp)!;
				fmt::fprintln(os::stdout)!;
			};
		} else if (line > last) {
			fmt::fprintln(os::stdout, s)!;
		};
	};

	ast::subunit_finish(unit);
};

fn visit_decl(imp: *impinfo, decl: ast::decl) void = {
	match (decl.decl) {
	case let d: []ast::decl_const =>
		for (let i = 0z; i < len(d); i += 1) {
			visit_decl_const(imp, d[i]);
		};
	case let d: []ast::decl_global =>
		for (let i = 0z; i < len(d); i += 1) {
			visit_decl_global(imp, d[i]);
		};
	case let d: []ast::decl_type =>
		for (let i = 0z; i < len(d); i += 1) {
			visit_decl_type(imp, d[i]);
		};
	case let d: ast::decl_func =>
		visit_decl_func(imp, d);
	};
};

fn visit_decl_const(imp: *impinfo, decl: ast::decl_const) void = {
	match (decl._type) {
	case let t: *ast::_type =>
		visit_type(imp, t);
	case => void;
	};
	visit_expr(imp, decl.init);
};

fn visit_decl_global(imp: *impinfo, decl: ast::decl_global) void = {
	match (decl._type) {
	case let t: *ast::_type =>
		visit_type(imp, t);
	case => void;
	};
	match (decl.init) {
	case let e: *ast::expr =>
		visit_expr(imp, e);
	case => void;
	};
};

fn visit_decl_type(imp: *impinfo, decl: ast::decl_type) void = {
	visit_type(imp, &decl._type);
};

fn visit_decl_func(imp: *impinfo, decl: ast::decl_func) void = {
	visit_type(imp, &decl.prototype);
	match (decl.body) {
	case let e: ast::expr =>
		visit_expr(imp, &e);
	case => void;
	};
};

fn visit_ident(imp: *impinfo, id: ast::ident) void = {
	if (!register(imp, id)) {
		// TODO: detecting if a package needs to be imported is more complicated
		// fmt::println("use of unimported package:", unparse::identstr(id))!;
		void;
	};
};

fn visit_type(imp: *impinfo, _type: *ast::_type) void = {
	match (_type.repr) {
	case let t: ast::alias_type =>
		visit_ident(imp, t.ident);
	case let t: ast::builtin_type => void;
	case let t: ast::enum_type =>
		for (let i = 0z; i < len(t.values); i += 1) {
			visit_expr_nullable(imp, t.values[i].value);
		};
	case let t: ast::func_type =>
		visit_type(imp, t.result);
		for (let i = 0z; i < len(t.params); i += 1) {
			visit_type(imp, t.params[i]._type);
		};
	case let t: ast::list_type =>
		match (t.length) {
		case let e: *ast::expr =>
			visit_expr(imp, e);
		case => void;
		};
		visit_type(imp, t.members);
	case let t: ast::pointer_type =>
		visit_type(imp, t.referent);
	case let t: ast::struct_type =>
		for (let i = 0z; i < len(t.members); i += 1) {
			visit_struct_member(imp, &t.members[i]);
		};
	case let t: ast::union_type =>
		for (let i = 0z; i < len(t); i += 1) {
			visit_struct_member(imp, &t[i]);
		};
	case let t: ast::tagged_type =>
		for (let i = 0z; i < len(t); i += 1) {
			visit_type(imp, t[i]);
		};
	case let t: ast::tuple_type =>
		for (let i = 0z; i < len(t); i += 1) {
			visit_type(imp, t[i]);
		};
	};
};

fn visit_struct_member(imp: *impinfo, member: *ast::struct_member) void = {
	visit_expr_nullable(imp, member._offset);
	match (member.member) {
	case let m: ast::struct_field =>
		visit_type(imp, m._type);
	case let m: ast::struct_embedded =>
		visit_type(imp, m);
	case let m: ast::struct_alias =>
		visit_ident(imp, m);
	};
};

fn visit_expr(imp: *impinfo, expr: *ast::expr) void = {
	match (expr.expr) {
	case let e: ast::access_expr =>
		match (e) {
		case let a: ast::access_identifier =>
			visit_ident(imp, a);
		case let a: ast::access_index =>
			visit_expr(imp, a.object);
			visit_expr(imp, a.index);
		case let a: ast::access_field =>
			visit_expr(imp, a.object);
		case let a: ast::access_tuple =>
			visit_expr(imp, a.object);
			visit_expr(imp, a.value);
		};
	case let e: ast::alloc_expr =>
		visit_expr(imp, e.init);
		visit_expr_nullable(imp, e.capacity);
	case let e: ast::append_expr =>
		visit_expr(imp, e.object);
		visit_expr_nullable(imp, e.variadic);
		for (let i = 0z; i < len(e.values); i += 1) {
			visit_expr(imp, e.values[i]);
		};
	case let e: ast::assert_expr =>
		visit_expr_nullable(imp, e.cond);
		visit_expr_nullable(imp, e.message);
	case let e: ast::assign_expr =>
		visit_expr(imp, e.object);
		visit_expr(imp, e.value);
	case let e: ast::binarithm_expr =>
		visit_expr(imp, e.lvalue);
		visit_expr(imp, e.rvalue);
	case let e: ast::binding_expr =>
		for (let i = 0z; i < len(e.bindings); i += 1) {
			visit_type_nullable(imp, e.bindings[i]._type);
			visit_expr(imp, e.bindings[i].init);
		};
	case let e: ast::break_expr => void;
	case let e: ast::call_expr =>
		visit_expr(imp, e.lvalue);
		for (let i = 0z; i < len(e.args); i += 1) {
			visit_expr(imp, e.args[i]);
		};
	case let e: ast::cast_expr =>
		visit_expr(imp, e.value);
		visit_type(imp, e._type);
	case let e: ast::constant_expr =>
		match (e) {
		case let e: ast::array_constant =>
			for (let i = 0z; i < len(e.values); i += 1) {
				visit_expr(imp, e.values[i]);
			};
		case let e: ast::struct_constant =>
			visit_struct_constant(imp, &e);
		case let e: ast::tuple_constant =>
			for (let i = 0z; i < len(e); i += 1) {
				visit_expr(imp, e[i]);
			};
		case => void;
		};
	case let e: ast::continue_expr => void;
	case let e: ast::defer_expr =>
		visit_expr(imp, e);
	case let e: ast::delete_expr =>
		visit_expr(imp, e.object);
	case let e: ast::for_expr =>
		visit_expr_nullable(imp, e.bindings);
		visit_expr(imp, e.cond);
		visit_expr_nullable(imp, e.afterthought);
		visit_expr(imp, e.body);
	case let e: ast::free_expr =>
		visit_expr(imp, e);
	case let e: ast::if_expr =>
		visit_expr(imp, e.cond);
		visit_expr(imp, e.tbranch);
		visit_expr_nullable(imp, e.fbranch);
	case let e: ast::insert_expr =>
		visit_expr(imp, e.object);
		visit_expr_nullable(imp, e.variadic);
		for (let i = 0z; i < len(e.values); i += 1) {
			visit_expr(imp, e.values[i]);
		};
	case let e: ast::compound_expr =>
		for (let i = 0z; i < len(e.exprs); i += 1) {
			visit_expr(imp, e.exprs[i]);
		};
	case let e: ast::match_expr =>
		visit_expr(imp, e.value);
		for (let i = 0z; i < len(e.cases); i += 1) {
			visit_type_nullable(imp, e.cases[i]._type);
			for (let j = 0z; j < len(e.cases[i].exprs); j += 1) {
				visit_expr(imp, e.cases[i].exprs[j]);
			};
		};
		for (let i = 0z; i < len(e.default); i += 1) {
			visit_expr(imp, e.default[i]);
		};
	case let e: ast::len_expr =>
		visit_expr(imp, e);
	case let e: ast::size_expr =>
		visit_type(imp, e);
	case let e: ast::offset_expr =>
		visit_expr(imp, e);
	case let e: ast::propagate_expr =>
		visit_expr(imp, e.expr);
	case let e: ast::return_expr =>
		visit_expr_nullable(imp, e);
	case let e: ast::slice_expr =>
		visit_expr(imp, e.object);
		visit_expr_nullable(imp, e.start);
		visit_expr_nullable(imp, e.end);
	case let e: ast::switch_expr =>
		visit_expr(imp, e.value);
		for (let i = 0z; i < len(e.cases); i += 1) {
			for (let j = 0z; j < len(e.cases[i].options); j += 1) {
				visit_expr(imp, e.cases[i].options[j]);
			};
			for (let j = 0z; j < len(e.cases[i].exprs); j += 1) {
				visit_expr(imp, e.cases[i].exprs[j]);
			};
		};
	case let e: ast::unarithm_expr =>
		visit_expr(imp, e.operand);
	case let e: ast::variadic_expr =>
		match (e) {
		case let v: ast::vaarg_expr =>
			visit_expr(imp, v);
		case => void;
		};
	case let e: ast::yield_expr =>
		visit_expr_nullable(imp, e.value);
	case => void;
	};
};

fn visit_expr_nullable(imp: *impinfo, expr: nullable *ast::expr) void = {
	match (expr) {
	case let e: *ast::expr =>
		visit_expr(imp, e);
	case => void;
	};
};

fn visit_type_nullable(imp: *impinfo, _type: nullable *ast::_type) void = {
	match (_type) {
	case let e: *ast::_type =>
		visit_type(imp, e);
	case => void;
	};
};

fn visit_struct_constant(imp: *impinfo, constant: *ast::struct_constant) void = {
	for (let i = 0z; i < len(constant.fields); i += 1) {
		match (constant.fields[i]) {
		case let f: ast::struct_value =>
			visit_type_nullable(imp, f._type);
			visit_expr(imp, f.init);
		case let f: *ast::struct_constant =>
			visit_struct_constant(imp, f);
		};
	};
};
