(* find unitary metavariables *)
module Ast0 = Ast0_cocci
module Ast = Ast_cocci
module V0 = Visitor_ast0

let set_minus s minus = List.filter (function n -> not (List.mem n minus)) s

let rec nub = function
    [] -> []
  | (x::xs) when (List.mem x xs) -> nub xs
  | (x::xs) -> x::(nub xs)

(* ----------------------------------------------------------------------- *)
(* Find the variables that occur free and occur free in a unitary way *)

(* take everything *)
let minus_checker name = let id = Ast0.unwrap_mcode name in [id]

(* take only what is in the plus code *)
let plus_checker (nm,_,_,mc) =
  match mc with Ast0.PLUS -> [nm] | _ -> []  
      
let get_free checker t =
  let bind x y = x @ y in
  let option_default = [] in
  let donothing r k e = k e in
  let mcode _ = option_default in
  
  (* considers a single list *)
  let collect_unitary_nonunitary free_usage =
    let free_usage = List.sort compare free_usage in
    let rec loop1 todrop = function
	[] -> []
      | (x::xs) as all -> if x = todrop then loop1 todrop xs else all in
    let rec loop2 = function
	[] -> ([],[])
      | [x] -> ([x],[])
      | x::y::xs ->
	  if x = y
	  then
	    let (unitary,non_unitary) = loop2(loop1 x xs) in
	    (unitary,x::non_unitary)
	  else
	    let (unitary,non_unitary) = loop2 (y::xs) in
	    (x::unitary,non_unitary) in
    loop2 free_usage in
  
  (* considers a list of lists *)
  let detect_unitary_frees l =
    let (unitary,nonunitary) =
      List.split (List.map collect_unitary_nonunitary l) in
    let unitary = nub (List.concat unitary) in
    let nonunitary = nub (List.concat nonunitary) in
    let unitary =
      List.filter (function x -> not (List.mem x nonunitary)) unitary in
    unitary@nonunitary@nonunitary in
  
  let ident r k i =
    match Ast0.unwrap i with
      Ast0.MetaId(name,_) | Ast0.MetaFunc(name,_)
    | Ast0.MetaLocalFunc(name,_) -> checker name
    | _ -> k i in
  
  let expression r k e =
    match Ast0.unwrap e with
      Ast0.MetaErr(name,_) | Ast0.MetaExpr(name,_,_,_)
    | Ast0.MetaExprList(name,_) -> checker name
    | Ast0.DisjExpr(starter,expr_list,mids,ender) ->
	detect_unitary_frees(List.map r.V0.combiner_expression expr_list)
    | _ -> k e in
  
  let typeC r k t =
    match Ast0.unwrap t with
      Ast0.MetaType(name,_) -> checker name
    | Ast0.DisjType(starter,types,mids,ender) ->
	detect_unitary_frees(List.map r.V0.combiner_typeC types)
    | _ -> k t in
  
  let parameter r k p =
    match Ast0.unwrap p with
      Ast0.MetaParam(name,_) | Ast0.MetaParamList(name,_) -> checker name
    | _ -> k p in
  
  let declaration r k d =
    match Ast0.unwrap d with
      Ast0.DisjDecl(starter,decls,mids,ender) ->
	detect_unitary_frees(List.map r.V0.combiner_declaration decls)
    | _ -> k d in

  let statement r k s =
    match Ast0.unwrap s with
      Ast0.MetaStmt(name,_) | Ast0.MetaStmtList(name,_) -> checker name
    | Ast0.Disj(starter,stmt_list,mids,ender) ->
	detect_unitary_frees(List.map r.V0.combiner_statement_dots stmt_list)
    | _ -> k s in
  
  let res = V0.combiner bind option_default 
      mcode mcode mcode mcode mcode mcode mcode mcode mcode mcode mcode mcode
      mcode
      donothing donothing donothing donothing donothing donothing
      ident expression typeC donothing parameter declaration statement
      donothing donothing in
  
  collect_unitary_nonunitary
    (List.concat (List.map res.V0.combiner_top_level t))
    
(* ----------------------------------------------------------------------- *)
(* update the variables that are unitary *)
    
let update_unitary unitary =
  let donothing r k e = k e in
  let mcode x = x in
  
  let is_unitary name =
    if List.mem (Ast0.unwrap_mcode name) unitary
    then Ast0.Context
    else Ast0.Impure in

  let ident r k i =
    match Ast0.unwrap i with
      Ast0.MetaId(name,_) ->
	Ast0.rewrap i (Ast0.MetaId(name,is_unitary name))
    | Ast0.MetaFunc(name,_) ->
	Ast0.rewrap i (Ast0.MetaFunc(name,is_unitary name))
    | Ast0.MetaLocalFunc(name,_) ->
	Ast0.rewrap i (Ast0.MetaLocalFunc(name,is_unitary name))
    | _ -> k i in

  let expression r k e =
    match Ast0.unwrap e with
      Ast0.MetaErr(name,_) ->
	Ast0.rewrap e (Ast0.MetaErr(name,is_unitary name))
    | Ast0.MetaExpr(name,ty,form,_) ->
	Ast0.rewrap e (Ast0.MetaExpr(name,ty,form,is_unitary name))
    | Ast0.MetaExprList(name,_) ->
	Ast0.rewrap e (Ast0.MetaExprList(name,is_unitary name))
    | _ -> k e in
  
  let typeC r k t =
    match Ast0.unwrap t with
      Ast0.MetaType(name,_) ->
	Ast0.rewrap t (Ast0.MetaType(name,is_unitary name))
    | _ -> k t in
  
  let parameter r k p =
    match Ast0.unwrap p with
      Ast0.MetaParam(name,_) ->
	Ast0.rewrap p (Ast0.MetaParam(name,is_unitary name))
    | Ast0.MetaParamList(name,_) ->
	Ast0.rewrap p (Ast0.MetaParamList(name,is_unitary name))
    | _ -> k p in
  
  let statement r k s =
    match Ast0.unwrap s with
      Ast0.MetaStmt(name,_) ->
	Ast0.rewrap s (Ast0.MetaStmt(name,is_unitary name))
    | Ast0.MetaStmtList(name,_) ->
	Ast0.rewrap s (Ast0.MetaStmtList(name,is_unitary name))
    | _ -> k s in
  
  let res = V0.rebuilder
      mcode mcode mcode mcode mcode mcode mcode mcode mcode mcode mcode mcode
      mcode
      donothing donothing donothing donothing donothing donothing
      ident expression typeC donothing parameter donothing statement
      donothing donothing in

  List.map res.V0.rebuilder_top_level

(* ----------------------------------------------------------------------- *)

let rec split3 = function
    [] -> ([],[],[])
  | (a,b,c)::xs -> let (l1,l2,l3) = split3 xs in (a::l1,b::l2,c::l3)

let rec combine3 = function
    ([],[],[]) -> []
  | (a::l1,b::l2,c::l3) -> (a,b,c) :: combine3 (l1,l2,l3)
  | _ -> failwith "not possible"

(* ----------------------------------------------------------------------- *)
(* process all rules *)

let do_unitary minus plus =
  let (minus,metavars,chosen_isos) = split3 minus in
  let (plus,_) = List.split plus in
  let rec loop = function
      ([],[],[]) -> ([],[])
    | (mm1::metavars,m1::minus,p1::plus) ->
	let mm1 = List.map Ast.get_meta_name mm1 in
	let (used_after,rest) = loop (metavars,minus,plus) in
	let (m_unitary,m_nonunitary) = get_free minus_checker m1 in
	let (p_unitary,p_nonunitary) = get_free plus_checker p1 in
	let p_free =
	  if !Flag.sgrep_mode2
	  then []
	  else p_unitary @ p_nonunitary in
	let (in_p,m_unitary) =
	  List.partition (function x -> List.mem x p_free) m_unitary in
	let m_nonunitary = in_p@m_nonunitary in
	let (m_unitary,not_local) =
	  List.partition (function x -> List.mem x mm1) m_unitary in
	let m_unitary =
	  List.filter (function x -> not(List.mem x used_after)) m_unitary in
	let rebuilt = update_unitary m_unitary m1 in
	(set_minus (m_nonunitary @ used_after) mm1,
	 rebuilt::rest)
    | _ -> failwith "not possible" in
  let (_,rules) = loop (metavars,minus,plus) in
  combine3 (rules,metavars,chosen_isos)
