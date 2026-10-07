package main

import (
	"go/ast"
	"path/filepath"
	"strconv"
	"strings"
)

func extract(files []sourceFile) []route {
	var routes []route
	shared := fields(files)
	// Field bindings originate in the composing function, before helper calls.
	for _, file := range files {
		for _, decl := range file.Tree.Decls {
			fn, ok := decl.(*ast.FuncDecl)
			if !ok || fn.Body == nil {
				continue
			}
			if strings.Contains(printed(fn.Body), "topologyMutationHandlers{") {
				for key, value := range assignments(fn.Body) {
					shared[key] = value
				}
			}
		}
	}
	for _, file := range files {
		for _, decl := range file.Tree.Decls {
			fn, ok := decl.(*ast.FuncDecl)
			if !ok || fn.Body == nil {
				continue
			}
			bindings := assignments(fn.Body)
			for key, value := range shared {
				bindings[key] = value
			}
			ast.Inspect(fn.Body, func(n ast.Node) bool {
				call, ok := n.(*ast.CallExpr)
				if !ok || len(call.Args) != 2 {
					return true
				}
				selector, ok := call.Fun.(*ast.SelectorExpr)
				if !ok || (selector.Sel.Name != "Handle" && selector.Sel.Name != "HandleFunc") {
					return true
				}
				pattern := routePattern(call.Args[0], bindings)
				method, path, found := strings.Cut(pattern, " ")
				if !found {
					if pattern != "/api/v1/client-updates" {
						panic("unbounded method route: " + pattern)
					}
					method, path = "GET", pattern // Handler explicitly rejects non-GET.
				}
				expression := render(call.Args[1], bindings, map[string]bool{})
				// Local protection methods contain the actual session wrapper.
				for _, other := range files {
					for _, d := range other.Tree.Decls {
						if wrapper, ok := d.(*ast.FuncDecl); ok && wrapper.Recv != nil && strings.Contains(expression, "."+wrapper.Name.Name+"(") {
							expression += " " + printed(wrapper.Body)
						}
					}
				}
				deps := append(packages(expression, files), filepath.ToSlash(filepath.Dir(file.Path)))
				required := false
				for _, source := range files {
					for alias, path := range source.Imports {
						if path == "backend/internal/identity/authenticate_session/api" && strings.Contains(expression, alias+".Require(") {
							required = true
						}
					}
				}
				routes = append(routes, route{method, path, file.Path, expression, deps, required})
				return true
			})
		}
	}
	return routes
}

func routePattern(expr ast.Expr, bindings map[string]ast.Expr) string {
	if value, ok := bindings[printed(expr)]; ok {
		return routePattern(value, bindings)
	}
	switch value := expr.(type) {
	case *ast.BasicLit:
		text, err := strconv.Unquote(value.Value)
		must(err)
		return text
	case *ast.BinaryExpr:
		if value.Op.String() == "+" {
			return routePattern(value.X, bindings) + routePattern(value.Y, bindings)
		}
	}
	panic("unsupported route pattern: " + printed(expr))
}
