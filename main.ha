use fmt;
use os;
use io;
use fs;
use hare::lex;
use hare::parse;
use hare::ast;
use hare::unparse;

export fn main() void = {
	if (len(os::args) <= 1) {
		fmt::fatalf("No input");
	};
	const file = match (os::open(os::args[1])) {
	case let f: io::file =>
		yield f;
	case let err: fs::error =>
		fmt::fatalf("Unable to open {}: {}", os::args[1], fs::strerror(err));
	};

	let lexer = lex::init(file, os::args[1], lex::flags::COMMENTS);

	let unit = match (parse::subunit(&lexer)) {
	case let unit: ast::subunit =>
		yield unit;
	case let err: parse::error =>
		fmt::fatalf("{}: Error while parsing: {}", os::args[1], parse::strerror(err));
	};

	let exp = expinfo { ... };
	getexp(&exp, unit);
	let imp = impinfo { ... };
	getimp(&imp, unit.imports);

	for (let i = 0z; i < len(exp.funcs); i += 1) {
		unparse::ident(os::stdout, exp.funcs[i])!;
		fmt::println()!;
	};

	unparse::subunit(os::stdout, unit)!;
	fmt::println()!;

	ast::subunit_finish(unit);
};

fn visit_type(imp: *impinfo, _type: ast::_type) void = {
	match (_type.repr) {
	case let t: ast::alias_type =>
		fmt::println("alias type")!;
	case ast::builtin_type =>
		fmt::println("builtin_type")!;
	case ast::enum_type =>
		fmt::println("enum_type")!;
	case ast::func_type =>
		fmt::println("func_type")!;
	case ast::list_type =>
		fmt::println("list_type")!;
	case ast::pointer_type =>
		fmt::println("pointer_type")!;
	case ast::struct_type =>
		fmt::println("struct_type")!;
	case ast::union_type =>
		fmt::println("union_type")!;
	case ast::tagged_type =>
		fmt::println("tagged_type")!;
	case ast::tuple_type =>
		fmt::println("tuple_type")!;
	case =>
		fmt::println("default")!;
	};
};
