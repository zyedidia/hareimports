use hare::ast;

type import = struct {
	path: ast::ident,
	alias: str,
};

type impinfo = struct {
	modules: []import,
};

fn getimp(imp: *impinfo, imports: []ast::import) void = {
	for (let i = 0z; i < len(imports); i += 1) {
		append(imp.modules, import {
			path = imports[i].ident,
			alias = imports[i].alias,
		});
	};
};
