Library runtime dependencies are added to the environment of executables that
link them. They propagate through the library closure and can name either a
single binary or a whole package.

  $ cat > dune-project <<'EOF'
  > (lang dune 3.26)
  > (package (name tools))
  > (package (name app))
  > EOF
  $ touch tools.opam app.opam
  $ mkdir tools app
  $ cat > tools/one <<'EOF'
  > #!/bin/sh
  > exit 0
  > EOF
  $ cat > tools/two <<'EOF'
  > #!/bin/sh
  > exit 0
  > EOF
  $ chmod +x tools/one tools/two
  $ cat > tools/dune <<'EOF'
  > (install
  >  (section bin)
  >  (package tools)
  >  (files one two))
  > EOF

  $ cat > app/dune <<'EOF'
  > (library
  >  (name precise)
  >  (public_name app.precise)
  >  (modules precise)
  >  (runtime_deps %{bin:one}))
  > (library
  >  (name transitive)
  >  (public_name app.transitive)
  >  (modules transitive)
  >  (libraries app.precise))
  > (executable
  >  (name precise_consumer)
  >  (modules precise_consumer)
  >  (libraries app.transitive unix))
  > (library
  >  (name whole)
  >  (public_name app.whole)
  >  (modules whole)
  >  (runtime_deps (package tools)))
  > (executable
  >  (name whole_consumer)
  >  (modules whole_consumer)
  >  (libraries app.whole unix))
  > (library
  >  (name self_support)
  >  (public_name app.self_support)
  >  (modules self_support)
  >  (runtime_deps %{bin:self-helper}))
  > (executable
  >  (name self_helper)
  >  (public_name self-helper)
  >  (package app)
  >  (modules self_helper)
  >  (libraries app.self_support unix))
  > (library
  >  (name self_package_support)
  >  (public_name app.self_package_support)
  >  (modules self_package_support)
  >  (runtime_deps (package app)))
  > (executable
  >  (name self_package_consumer)
  >  (modules self_package_consumer)
  >  (libraries app.self_package_support unix))
  > (executable
  >  (name direct_precise)
  >  (modules direct_precise)
  >  (runtime_deps %{bin:one}))
  > (executable
  >  (name direct_whole)
  >  (modules direct_whole)
  >  (runtime_deps (package tools)))
  > (executable
  >  (name direct_combined)
  >  (modules direct_combined)
  >  (libraries app.precise)
  >  (runtime_deps %{bin:two}))
  > (executable
  >  (name direct_self)
  >  (public_name direct-self)
  >  (package app)
  >  (modules direct_self)
  >  (runtime_deps %{bin:direct-self}))
  > (executable
  >  (name direct_self_package)
  >  (modules direct_self_package)
  >  (runtime_deps (package app)))
  > (test
  >  (name direct_test)
  >  (modules direct_test)
  >  (runtime_deps %{bin:one}))
  > (rule
  >  (alias runtest)
  >  (action (run %{exe:precise_consumer.exe})))
  > (rule
  >  (alias runtest)
  >  (action (run %{exe:whole_consumer.exe})))
  > (rule
  >  (alias runtest)
  >  (action (run %{exe:self_helper.exe})))
  > (rule
  >  (alias runtest)
  >  (action (run %{exe:self_package_consumer.exe})))
  > (rule
  >  (alias runtest)
  >  (action (run %{exe:direct_precise.exe})))
  > (rule
  >  (alias runtest)
  >  (action (run %{exe:direct_whole.exe})))
  > (rule
  >  (alias runtest)
  >  (action (run %{exe:direct_combined.exe})))
  > (rule
  >  (alias runtest)
  >  (action (run %{exe:direct_self.exe})))
  > (rule
  >  (alias runtest)
  >  (action (run %{exe:direct_self_package.exe})))
  > (rule
  >  (alias runtest)
  >  (action
  >   (progn
  >    (run %{exe:whole_consumer.exe})
  >    (run %{exe:self_helper.exe}))))
  > EOF
  $ touch app/precise.ml app/transitive.ml app/whole.ml app/self_support.ml \
  >   app/self_package_support.ml
  $ cat > app/precise_consumer.ml <<'EOF'
  > let () =
  >   assert (Sys.command "one" = 0);
  >   assert (Sys.command "command -v two >/dev/null 2>&1" <> 0)
  > EOF
  $ cat > app/whole_consumer.ml <<'EOF'
  > let () =
  >   assert (Sys.command "one" = 0);
  >   assert (Sys.command "two" = 0)
  > EOF
  $ cat > app/self_helper.ml <<'EOF'
  > let () = assert (Sys.command "command -v self-helper >/dev/null 2>&1" = 0)
  > EOF
  $ cat > app/self_package_consumer.ml <<'EOF'
  > let () = assert (Sys.command "command -v self-helper >/dev/null 2>&1" = 0)
  > EOF
  $ cat > app/direct_precise.ml <<'EOF'
  > let () =
  >   assert (Sys.command "one" = 0);
  >   assert (Sys.command "command -v two >/dev/null 2>&1" <> 0)
  > EOF
  $ cat > app/direct_whole.ml <<'EOF'
  > let () =
  >   assert (Sys.command "one" = 0);
  >   assert (Sys.command "two" = 0)
  > EOF
  $ cat > app/direct_combined.ml <<'EOF'
  > let () =
  >   assert (Sys.command "one" = 0);
  >   assert (Sys.command "two" = 0)
  > EOF
  $ cat > app/direct_self.ml <<'EOF'
  > let () = assert (Sys.command "command -v direct-self >/dev/null 2>&1" = 0)
  > EOF
  $ cat > app/direct_self_package.ml <<'EOF'
  > let () = assert (Sys.command "command -v self-helper >/dev/null 2>&1" = 0)
  > EOF
  $ cat > app/direct_test.ml <<'EOF'
  > let () =
  >   assert (Sys.command "one" = 0);
  >   assert (Sys.command "command -v two >/dev/null 2>&1" <> 0)
  > EOF

  $ dune runtest
  $ dune exec ./app/precise_consumer.exe
  $ dune exec ./app/whole_consumer.exe
  $ dune exec ./app/self_helper.exe
  $ dune exec self-helper
  $ dune exec ./app/self_package_consumer.exe
  $ dune exec ./app/direct_precise.exe
  $ dune exec ./app/direct_whole.exe
  $ dune exec ./app/direct_combined.exe
  $ dune exec direct-self
  $ dune exec ./app/direct_self_package.exe
  $ dune exec ./app/direct_test.exe

Other dependency forms are rejected.

  $ mkdir invalid
  $ cat > invalid/dune <<'EOF'
  > (library
  >  (name invalid)
  >  (runtime_deps data-file))
  > EOF
  $ touch invalid/invalid.ml
  $ dune build invalid/invalid.cma 2>&1 | grep 'Runtime dependencies'
  Error: Runtime dependencies must be packages or binaries of the form
  [1]
