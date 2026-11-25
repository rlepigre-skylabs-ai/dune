open Import

val env_of_libraries : sctx:Super_context.t -> Lib.t list -> Env.t Action_builder.t
val env_for_executable : expander:Expander.t -> Path.t -> Env.t Action_builder.t
