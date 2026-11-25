open Import

let env_of_declaration ~sctx ~dir (_loc, deps) =
  let open Action_builder.O in
  if List.is_empty deps
  then Action_builder.return Env.empty
  else
    let* expander = Action_builder.of_memo (Super_context.expander sctx ~dir) in
    Dep_conf_eval.runtime ~expander deps
;;

let env_of_libraries ~sctx libraries =
  let open Action_builder.O in
  let declarations =
    List.filter_map libraries ~f:(fun lib ->
      let info = Lib.info lib in
      match Lib_info.runtime_deps info, Path.as_in_build_dir (Lib_info.src_dir info) with
      | Some deps, Some dir -> Some (dir, deps)
      | None, Some _ | (None | Some _), None -> None)
  in
  let+ envs =
    Action_builder.List.map declarations ~f:(fun (dir, deps) ->
      env_of_declaration ~sctx ~dir deps)
  in
  List.fold_left envs ~init:Env.empty ~f:Install.Roots.extend_env_concat_path_vars
;;

let executable_libraries ~dir (exes : Executables.t) =
  let open Resolve.Memo.O in
  let* scope = Resolve.Memo.lift_memo (Scope.DB.find_by_dir dir) in
  let project = Scope.project scope in
  let dune_version = Dune_project.dune_version project in
  let libs = Scope.libs scope in
  let* pps =
    Resolve.Memo.lift_memo
      (Lib.DB.pps_for_preprocessing libs exes.buildable.preprocess.config)
  in
  let compile_info =
    Lib.DB.resolve_user_written_deps
      libs
      (Executables.exe_target exes)
      exes.buildable.libraries
      ~allow_unused_libraries:exes.buildable.allow_unused_libraries
      ~pps
      ~dune_version
      ~forbidden_libraries:exes.forbidden_libraries
      ~allow_overlaps:exes.buildable.allow_overlapping_dependencies
  in
  let* direct = Lib.Compile.direct_requires compile_info ~for_:Ocaml in
  Lib.closure ~linking:true direct ~for_:Ocaml
;;

let find_executable ~dir basename =
  let open Memo.O in
  let+ dune_file = Dune_load.stanzas_in_dir dir in
  Option.bind dune_file ~f:(fun dune_file ->
    let name = Filename.remove_extension basename |> Filename.to_string in
    let matches (exes : Executables.t) =
      List.exists (Nonempty_list.to_list exes.names) ~f:(fun (_, candidate) ->
        String.equal candidate name)
    in
    Dune_file.static_stanzas dune_file
    |> List.find_map ~f:(fun stanza ->
      match Stanza.repr stanza with
      | Executables.T exes when matches exes -> Some exes
      | Tests.T tests when matches tests.exes -> Some tests.exes
      | _ -> None))
;;

let env_for_executable ~expander prog =
  let open Action_builder.O in
  match Path.as_in_build_dir prog with
  | None -> Action_builder.return Env.empty
  | Some prog ->
    let context, _ = Path.Build.extract_build_context_exn prog in
    let context = Context_name.of_string (Filename.to_string context) in
    if not (Context_name.equal context (Expander.context expander))
    then Action_builder.return Env.empty
    else (
      let dir = Path.Build.parent_exn prog in
      let basename = Path.Build.basename prog in
      let* exes = Action_builder.of_memo (find_executable ~dir basename) in
      match exes with
      | None -> Action_builder.return Env.empty
      | Some exes ->
        let* libraries = Resolve.Memo.read (executable_libraries ~dir exes) in
        let* sctx =
          Action_builder.of_memo (Super_context.find_exn (Expander.context expander))
        in
        let+ library_env = env_of_libraries ~sctx libraries
        and+ executable_env = env_of_declaration ~sctx ~dir exes.runtime_deps in
        Install.Roots.extend_env_concat_path_vars library_env executable_env)
;;
