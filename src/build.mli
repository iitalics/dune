(** The build arrow *)

open! Import

type ('a, 'b) t

val arr : ('a -> 'b) -> ('a, 'b) t

val return : 'a -> (unit, 'a) t

module Vspec : sig
  type 'a t = T : Path.t * 'a Vfile_kind.t -> 'a t
end

val store_vfile : 'a Vspec.t -> ('a, Action.t) t

module O : sig
  val ( >>> ) : ('a, 'b) t -> ('b, 'c) t -> ('a, 'c) t
  val ( ^>> ) : ('a -> 'b) -> ('b, 'c) t -> ('a, 'c) t
  val ( >>^ ) : ('a, 'b) t -> ('b -> 'c) -> ('a, 'c) t
  val ( *** ) : ('a, 'b) t -> ('c, 'd) t -> ('a * 'c, 'b * 'd) t
  val ( &&& ) : ('a, 'b) t -> ('a, 'c) t -> ('a, 'b * 'c) t
end

val first  : ('a, 'b) t -> ('a * 'c, 'b * 'c) t
val second : ('a, 'b) t -> ('c * 'a, 'c * 'b) t

(** Same as [O.(&&&)]. Sends the input to both argument arrows and combine their output.

    The default definition may be overridden with a more efficient version if desired. *)
val fanout  : ('a, 'b) t -> ('a, 'c) t -> ('a, 'b * 'c) t
val fanout3 : ('a, 'b) t -> ('a, 'c) t -> ('a, 'd) t ->  ('a, 'b * 'c * 'd) t
val fanout4 : ('a, 'b) t -> ('a, 'c) t -> ('a, 'd) t -> ('a, 'e) t -> ('a, 'b * 'c * 'd * 'e) t

val all : ('a, 'b) t list -> ('a, 'b list) t

(* CR-someday diml: this API is not great, what about:

   {[
     module Action_with_deps : sig
       type t
       val add_file_dependency : t -> Path.t -> t
     end

     (** Same as [t >>> arr (fun x -> Action_with_deps.add_file_dependency x p)]
         but better as [p] is statically known *)
     val record_dependency
       :  Path.t
       -> ('a, Action_with_deps.t) t
       -> ('a, Action_with_deps.t) t
   ]}
*)
(** [path p] records [p] as a file that is read by the action produced by the
    build arrow. *)
val path  : Path.t -> ('a, 'a) t

val paths : Path.t list -> ('a, 'a) t
val path_set : Path.Set.t -> ('a, 'a) t

(** Evaluate a glob and record all the matched files as dependencies
    of the action produced by the build arrow. *)
val paths_glob : loc:Loc.t -> dir:Path.t -> Re.re -> ('a, Path.t list) t

(* CR-someday diml: rename to [source_files_recursively_in] *)
(** Compute the set of source of all files present in the sub-tree
    starting at [dir] and record them as dependencies. *)
val files_recursively_in
  :  dir:Path.t
  -> file_tree:File_tree.t
  -> ('a, Path.Set.t) t

(** Record dynamic dependencies *)
val dyn_paths : ('a, Path.t list) t -> ('a, 'a) t
val dyn_path_set : ('a, Path.Set.t) t -> ('a, 'a) t

val vpath : 'a Vspec.t  -> (unit, 'a) t

(** [catch t ~on_error] evaluates to [on_error exn] if exception [exn] is
    raised during the evaluation of [t]. *)
val catch : ('a, 'b) t -> on_error:(exn -> 'b) -> ('a, 'b) t

(** [contents path] returns an arrow that when run will return the contents of
    the file at [path]. *)
val contents : Path.t -> ('a, string) t

(** [lines_of path] returns an arrow that when run will return the contents of
    the file at [path] as a list of lines. *)
val lines_of : Path.t -> ('a, string list) t

(** [strings path] is like [lines_of path] except each line is unescaped using
    the OCaml conventions. *)
val strings : Path.t -> ('a, string list) t

(** Load an S-expression from a file *)
val read_sexp : Path.t -> (unit, Sexp.Ast.t) t

(** Evaluates to [true] if the file is present on the file system or is the target of a
    rule. *)
val file_exists : Path.t -> ('a, bool)  t

(** [if_file_exists p ~then ~else] is an arrow that behaves like [then_] if [file_exists
    p] evaluates to [true], and [else_] otherwise. *)
val if_file_exists : Path.t -> then_:('a, 'b) t -> else_:('a, 'b) t -> ('a, 'b) t

(** [file_exists_opt p t] is:

    {[
      if_file_exists p ~then_:(t >>^ fun x -> Some x) ~else_:(arr (fun _ -> None))
    ]}
*)
val file_exists_opt : Path.t -> ('a, 'b) t -> ('a, 'b option) t

(** Always fail when executed. We pass a function rather than an
    exception to get a proper backtrace *)
val fail : ?targets:Path.t list -> fail -> (_, _) t

val of_result
  :  ?targets:Path.t list
  -> ('a, 'b) t Or_exn.t
  -> ('a, 'b) t

val of_result_map
  : ?targets:Path.t list
  -> 'a Or_exn.t
  -> f:('a -> ('b, 'c) t)
  -> ('b, 'c) t

(** [memoize name t] is an arrow that behaves like [t] except that its
    result is computed only once. *)
val memoize : string -> (unit, 'a) t -> (unit, 'a) t

val run
  :  context:Context.t
  -> ?dir:Path.t (* default: [context.build_dir] *)
  -> ?stdout_to:Path.t
  -> ?extra_targets:Path.t list
  -> Action.Prog.t
  -> 'a Arg_spec.t list
  -> ('a, Action.t) t

val action
  :  ?dir:Path.t
  -> targets:Path.t list
  -> Action.t
  -> (_, Action.t) t

val action_dyn
  :  ?dir:Path.t
  -> targets:Path.t list
  -> unit
  -> (Action.t, Action.t) t

(** Create a file with the given contents. *)
val write_file : Path.t -> string -> (unit, Action.t) t
val write_file_dyn : Path.t -> (string, Action.t) t

val copy : src:Path.t -> dst:Path.t -> (unit, Action.t) t
val copy_and_add_line_directive : src:Path.t -> dst:Path.t -> (unit, Action.t) t

val symlink : src:Path.t -> dst:Path.t -> (unit, Action.t) t

val create_file : Path.t -> (_, Action.t) t
val remove_tree : Path.t -> (_, Action.t) t
val mkdir : Path.t -> (_, Action.t) t

(** Merge a list of actions *)
val progn : ('a, Action.t) t list -> ('a, Action.t) t

type lib_dep_kind =
  | Optional
  | Required

val record_lib_deps
  :  kind:lib_dep_kind
  -> Jbuild.Lib_dep.t list
  -> ('a, 'a) t

type lib_deps = lib_dep_kind String_map.t

val record_lib_deps_simple : lib_deps -> ('a, 'a) t

(**/**)


module Repr : sig
  type ('a, 'b) t =
    | Arr : ('a -> 'b) -> ('a, 'b) t
    | Targets : Path.t list -> ('a, 'a) t
    | Store_vfile : 'a Vspec.t -> ('a, Action.t) t
    | Compose : ('a, 'b) t * ('b, 'c) t -> ('a, 'c) t
    | First : ('a, 'b) t -> ('a * 'c, 'b * 'c) t
    | Second : ('a, 'b) t -> ('c * 'a, 'c * 'b) t
    | Split : ('a, 'b) t * ('c, 'd) t -> ('a * 'c, 'b * 'd) t
    | Fanout : ('a, 'b) t * ('a, 'c) t -> ('a, 'b * 'c) t
    | Paths : Path.Set.t -> ('a, 'a) t
    | Paths_for_rule : Path.Set.t -> ('a, 'a) t
    | Paths_glob : glob_state ref -> ('a, Path.t list) t
    | If_file_exists : Path.t * ('a, 'b) if_file_exists_state ref -> ('a, 'b) t
    | Contents : Path.t -> ('a, string) t
    | Lines_of : Path.t -> ('a, string list) t
    | Vpath : 'a Vspec.t -> (unit, 'a) t
    | Dyn_paths : ('a, Path.Set.t) t -> ('a, 'a) t
    | Record_lib_deps : lib_deps -> ('a, 'a) t
    | Fail : fail -> (_, _) t
    | Memo : 'a memo -> (unit, 'a) t
    | Catch : ('a, 'b) t * (exn -> 'b) -> ('a, 'b) t

  and 'a memo =
    { name          : string
    ; t             : (unit, 'a) t
    ; mutable state : 'a memo_state
    }

  and 'a memo_state =
    | Unevaluated
    | Evaluating
    | Evaluated of 'a * Path.Set.t (* dynamic dependencies *)

  and ('a, 'b) if_file_exists_state =
    | Undecided of ('a, 'b) t * ('a, 'b) t
    | Decided   of bool * ('a, 'b) t

  and glob_state =
    | G_unevaluated of Loc.t * Path.t * Re.re
    | G_evaluated   of Path.t list

  val get_if_file_exists_exn : ('a, 'b) if_file_exists_state ref -> ('a, 'b) t
  val get_glob_result_exn : glob_state ref -> Path.t list
end

val repr : ('a, 'b) t -> ('a, 'b) Repr.t

val merge_lib_deps : lib_deps -> lib_deps -> lib_deps

(**/**)
val paths_for_rule : Path.Set.t -> ('a, 'a) t
