A Rocq wrapper receives the actual Rocq executable as its first argument,
followed by the regular Rocq arguments. Configuration queries bypass the
wrapper.

  $ make_rocq_project 3.26 0.15

  $ cat > foo.v <<'EOF'
  > Definition foo := 0.
  > EOF

  $ cat > wrapper.sh <<'EOF'
  > #!/bin/sh
  > actual_rocq="$1"
  > shift
  > case "$(basename "$actual_rocq")" in
  >   rocq|rocq.exe) ;;
  >   *) echo "unexpected Rocq executable: $actual_rocq" >&2; exit 1 ;;
  > esac
  > printf '%s\n' "$1" >> "$DUNE_SOURCEROOT/wrapper.log"
  > exec "$actual_rocq" "$@"
  > EOF
  $ chmod +x wrapper.sh

  $ cat > dune <<'EOF'
  > (env
  >  (_
  >   (rocq
  >    (wrapper ./wrapper.sh))))
  > 
  > (rocq.theory
  >  (name basic))
  > EOF

  $ dune build foo.vo
  $ cat wrapper.log
  dep
  compile
