package main

import (
	"bytes"
	"go/ast"
	"go/printer"
	"sort"
	"strings"
)

func printed(node ast.Node) string {
	var buffer bytes.Buffer
	must(printer.Fprint(&buffer, fileset, node))
	return buffer.String()
}

func assignments(node ast.Node) map[string]ast.Expr {
	bindings := map[string]ast.Expr{}
	ast.Inspect(node, func(n ast.Node) bool {
		if assignment, ok := n.(*ast.AssignStmt); ok && len(assignment.Rhs) == len(assignment.Lhs) {
			for i, lhs := range assignment.Lhs {
				bindings[printed(lhs)] = assignment.Rhs[i]
			}
		}
		return true
	})
	return bindings
}

func render(expr ast.Expr, bindings map[string]ast.Expr, seen map[string]bool) string {
	key := printed(expr)
	if value, ok := bindings[key]; ok && !seen[key] {
		copySeen := map[string]bool{}
		for k, v := range seen {
			copySeen[k] = v
		}
		copySeen[key] = true
		return render(value, bindings, copySeen)
	}
	switch value := expr.(type) {
	case *ast.CallExpr:
		args := []string{}
		for _, arg := range value.Args {
			args = append(args, render(arg, bindings, seen))
		}
		return render(value.Fun, bindings, seen) + "(" + strings.Join(args, ", ") + ")"
	case *ast.SelectorExpr:
		return render(value.X, bindings, seen) + "." + value.Sel.Name
	case *ast.CompositeLit:
		args := []string{}
		for _, arg := range value.Elts {
			args = append(args, render(arg, bindings, seen))
		}
		return render(value.Type, bindings, seen) + "{" + strings.Join(args, ", ") + "}"
	case *ast.KeyValueExpr:
		return printed(value.Key) + ": " + render(value.Value, bindings, seen)
	}
	return key
}

func fields(files []sourceFile) map[string]ast.Expr {
	bindings := map[string]ast.Expr{}
	for _, file := range files {
		ast.Inspect(file.Tree, func(n ast.Node) bool {
			literal, ok := n.(*ast.CompositeLit)
			if !ok || printed(literal.Type) != "topologyMutationHandlers" {
				return true
			}
			for _, element := range literal.Elts {
				if pair, ok := element.(*ast.KeyValueExpr); ok {
					bindings["handlers."+printed(pair.Key)] = pair.Value
				}
			}
			return true
		})
	}
	return bindings
}

func packages(expression string, files []sourceFile) []string {
	paths := map[string]bool{}
	for _, file := range files {
		for alias, path := range file.Imports {
			if strings.Contains(expression, alias+".") {
				paths[path] = true
			}
		}
	}
	result := []string{}
	for path := range paths {
		result = append(result, path)
	}
	sort.Strings(result)
	return result
}
