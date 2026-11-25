Rocq theories can declare runtime dependencies on whole packages or on
individual binaries. These dependencies propagate through theory dependencies,
and precise binary dependencies do not expose unrelated binaries.

  $ make_rocq_project 3.26 0.15
  $ cat >> dune-project <<'EOF'
  > (package (name tools))
  > (package (name binary-dep))
  > (package (name package-dep))
  > (package (name self-bin))
  > (package (name self-package))
  > (package (name plugin-runtime))
  > (package (name consumer))
  > EOF
  $ for package in tools binary-dep package-dep self-bin self-package plugin-runtime consumer; do
  >   touch "$package.opam"
  > done

  $ mkdir tools
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

  $ cat > wrapper.sh <<'EOF'
  > #!/bin/sh
  > actual_rocq="$1"
  > shift
  > case "$*" in
  >   *binary_dep.v*)
  >     command -v one >/dev/null
  >     if command -v two >/dev/null; then
  >       echo "binary runtime dependency exposed an unrelated binary" >&2
  >       exit 1
  >     fi
  >     ;;
  >   *package_dep.v*)
  >     command -v one >/dev/null
  >     command -v two >/dev/null
  >     ;;
  >   *self_bin.v*)
  >     command -v self-bin-helper >/dev/null
  >     ;;
  >   *self_package.v*)
  >     command -v self-package-helper >/dev/null
  >     ;;
  >   *plugin_runtime.v*)
  >     command -v plugin-helper >/dev/null
  >     ;;
  >   *consumer.v*)
  >     command -v one >/dev/null
  >     command -v two >/dev/null
  >     command -v self-bin-helper >/dev/null
  >     command -v self-package-helper >/dev/null
  >     command -v plugin-helper >/dev/null
  >     ;;
  > esac
  > exec "$actual_rocq" "$@"
  > EOF
  $ chmod +x wrapper.sh
  $ cat > dune <<'EOF'
  > (env
  >  (_
  >   (rocq
  >    (wrapper ./wrapper.sh))))
  > EOF

  $ mkdir binary_dep package_dep self_bin self_package plugin_runtime consumer
  $ cat > binary_dep/dune <<'EOF'
  > (rocq.theory
  >  (name Binary_dep)
  >  (public_name binary-dep)
  >  (runtime_deps %{bin:one}))
  > EOF
  $ echo 'Definition binary_dep := 0.' > binary_dep/binary_dep.v

  $ cat > package_dep/dune <<'EOF'
  > (rocq.theory
  >  (name Package_dep)
  >  (public_name package-dep)
  >  (runtime_deps (package tools)))
  > EOF
  $ echo 'Definition package_dep := 0.' > package_dep/package_dep.v

A theory can refer to a binary or its whole package without introducing a cycle
through the theory's own installed rocq.d directory.

  $ cat > self_bin/self-bin-helper <<'EOF'
  > #!/bin/sh
  > exit 0
  > EOF
  $ chmod +x self_bin/self-bin-helper
  $ cat > self_bin/dune <<'EOF'
  > (install
  >  (section bin)
  >  (package self-bin)
  >  (files self-bin-helper))
  > (rocq.theory
  >  (name Self_bin)
  >  (public_name self-bin)
  >  (runtime_deps %{bin:self-bin-helper}))
  > EOF
  $ echo 'Definition self_bin := 0.' > self_bin/self_bin.v

  $ cat > self_package/self-package-helper <<'EOF'
  > #!/bin/sh
  > exit 0
  > EOF
  $ chmod +x self_package/self-package-helper
  $ cat > self_package/dune <<'EOF'
  > (install
  >  (section bin)
  >  (package self-package)
  >  (files self-package-helper))
  > (rocq.theory
  >  (name Self_package)
  >  (public_name self-package)
  >  (runtime_deps (package self-package)))
  > EOF
  $ echo 'Definition self_package := 0.' > self_package/self_package.v

Library runtime dependencies propagate through the linked library closure. The
runtime binary may be provided by the same package as the library and theory.

  $ cat > plugin_runtime/plugin-helper <<'EOF'
  > #!/bin/sh
  > exit 0
  > EOF
  $ chmod +x plugin_runtime/plugin-helper
  $ cat > plugin_runtime/dune <<'EOF'
  > (install
  >  (section bin)
  >  (package plugin-runtime)
  >  (files plugin-helper))
  > (library
  >  (name runtime_support)
  >  (public_name plugin-runtime.support)
  >  (modules runtime_support)
  >  (runtime_deps %{bin:plugin-helper}))
  > (library
  >  (name plugin)
  >  (public_name plugin-runtime.plugin)
  >  (modules runtime_plugin)
  >  (libraries plugin-runtime.support rocq-runtime.vernac))
  > (rocq.pp (modules runtime_plugin))
  > (rocq.theory
  >  (name Plugin_runtime)
  >  (public_name plugin-runtime)
  >  (plugins plugin-runtime.plugin))
  > EOF
  $ touch plugin_runtime/runtime_support.ml
  $ cat > plugin_runtime/runtime_plugin.mlg <<'EOF'
  > DECLARE PLUGIN "plugin-runtime.plugin"
  > {
  > }
  > EOF
  $ cat > plugin_runtime/plugin_runtime.v <<'EOF'
  > Declare ML Module "plugin-runtime.plugin".
  > EOF

  $ cat > consumer/dune <<'EOF'
  > (rocq.theory
  >  (name Consumer)
  >  (public_name consumer)
  >  (theories binary-dep package-dep self-bin self-package plugin-runtime))
  > EOF
  $ echo 'Definition consumer := 0.' > consumer/consumer.v

  $ dune build consumer/consumer.vo
