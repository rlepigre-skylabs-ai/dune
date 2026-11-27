`dune rocq top` must use the stanza's Rocq language version when computing
Corelib dependencies. In Rocq language 0.15, Corelib comes from the
`rocq-core` findlib package rather than the legacy `theories` directory.

  $ make_rocq_project 3.26 0.15
  $ cat > dune <<'EOF'
  > (rocq.theory
  >  (name Test))
  > EOF
  $ echo 'Check I.' > Test.v

Create a modern Corelib installation with no legacy layout and a Rocq wrapper
that reports it as the compiler's installation prefix.

  $ real_rocq=$(command -v rocq)
  $ mkdir -p fake/bin fake/lib/rocq-core/rocq.d/Init
  $ touch fake/lib/rocq-core/rocq.d/Init/Prelude.vo
  $ cat > fake/lib/rocq-core/META <<'EOF'
  > description = "Rocq Corelib"
  > rocqpath = "Corelib"
  > EOF
  $ cat > fake/bin/rocq <<EOF
  > #!/bin/sh
  > if [ "\$1" = c ] && [ "\$2" = --config ]; then
  >   "$real_rocq" "\$@" | sed 's|^COQLIB=.*|COQLIB=$PWD/fake/lib/rocq-core/|'
  > else
  >   exec "$real_rocq" "\$@"
  > fi
  > EOF
  $ chmod +x fake/bin/rocq

  $ PATH="$PWD/fake/bin:$PATH" OCAMLPATH="$PWD/fake/lib${OCAMLPATH:+:$OCAMLPATH}" \
  >   dune rocq top --toplevel=true Test.v
