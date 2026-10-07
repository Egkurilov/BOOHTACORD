// Go AST evidence for the public API contract. No application code is executed.
package main

import (
	"encoding/json"
	"go/ast"
	"go/parser"
	"go/token"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

type sourceFile struct {
	Path    string
	Tree    *ast.File
	Imports map[string]string
}
type route struct {
	Method          string   `json:"method"`
	Path            string   `json:"path"`
	Source          string   `json:"source"`
	Expression      string   `json:"expression"`
	Packages        []string `json:"packages"`
	SessionRequired bool     `json:"session_required"`
}

var fileset = token.NewFileSet()
var cache = map[string][]sourceFile{}

func load(dir string) []sourceFile {
	if files, ok := cache[dir]; ok {
		return files
	}
	entries, err := os.ReadDir(dir)
	must(err)
	var files []sourceFile
	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".go") || strings.HasSuffix(entry.Name(), "_test.go") {
			continue
		}
		path := filepath.Join(dir, entry.Name())
		tree, err := parser.ParseFile(fileset, path, nil, 0)
		must(err)
		files = append(files, sourceFile{path, tree, map[string]string{}})
	}
	cache[dir] = files
	for i := range files {
		for _, imp := range files[i].Tree.Imports {
			path, err := strconv.Unquote(imp.Path.Value)
			must(err)
			if !strings.HasPrefix(path, "voice-platform/backend/") {
				continue
			}
			local := "backend/" + strings.TrimPrefix(path, "voice-platform/backend/")
			name := ""
			if imp.Name != nil {
				name = imp.Name.Name
			} else {
				deps := load(local)
				if len(deps) > 0 {
					name = deps[0].Tree.Name.Name
				}
			}
			files[i].Imports[name] = local
		}
	}
	cache[dir] = files
	return files
}

func must(err error) {
	if err != nil {
		panic(err)
	}
}

func main() {
	var routes []route
	seen := map[string]bool{}
	var visit func(string)
	visit = func(dir string) {
		if seen[dir] {
			return
		}
		seen[dir] = true
		files := load(dir)
		for _, file := range files {
			for _, imp := range file.Imports {
				if strings.HasPrefix(imp, "backend/internal/app/") || hasRegistration(load(imp)) {
					visit(imp)
				}
			}
		}
		routes = append(routes, extract(files)...)
	}
	visit("backend/internal/app/runtime")
	must(json.NewEncoder(os.Stdout).Encode(routes))
}

func hasRegistration(files []sourceFile) bool {
	for _, file := range files {
		for _, decl := range file.Tree.Decls {
			if fn, ok := decl.(*ast.FuncDecl); ok && fn.Name.Name == "RegisterRoutes" {
				return true
			}
		}
	}
	return false
}
