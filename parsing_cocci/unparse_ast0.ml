open Format
module Ast0 = Ast0_cocci
module U = Pretty_print_cocci

let quiet = ref true (* true = no decoration on - context, etc *)

let start_block str =
  force_newline(); print_string "  "; open_box 0

let end_block str =
  close_box(); force_newline ()

let print_option = Common.do_option
let print_between = Common.print_between

(* --------------------------------------------------------------------- *)
(* Modified code *)

let mcodekind brackets fn x info = function
    Ast0.MINUS(plus_stream) ->
      let (lb,rb) =
	if !quiet
	then ("","")
	else
	  match brackets with
	    Some x -> ("[","]^"^(string_of_int x))
	  | None -> ("","") in
      let (plus_stream,_) = !plus_stream in
      if !quiet
      then fn x
      else (print_string "-";
	    print_string lb; fn x; print_string rb);
      U.print_anything ">>> " plus_stream
  | Ast0.CONTEXT(plus_streams) ->
      let (lb,rb) =
	if !quiet
	then ("","")
	else
	  match brackets with
	    Some x -> ("[",("]^"^(string_of_int x))) | None -> ("","") in
      let (plus_streams,t1,t2) = !plus_streams in
      U.print_around
	(function x ->
	  print_string lb; fn x; print_string rb)
	x plus_streams
  | Ast0.PLUS ->
      List.iter (function s -> print_string s; force_newline())
	info.Ast0.strings_before;
      fn x;
      List.iter (function s -> force_newline(); print_string s)
	info.Ast0.strings_after
  | Ast0.MIXED(plus_streams) ->
      let (lb,rb) =
	if !quiet
	then ("","")
	else
	  let n = 
	    match brackets with Some x -> "^"^(string_of_int x) | None -> "" in
	  ("§","½"^n) in
      let (plus_streams,_,_) = !plus_streams in
      U.print_around (function x -> print_string lb; fn x; print_string rb)
	x plus_streams

let mcode fn (x,_,info,mc) =
  mcodekind (Some info.Ast0.line_start)(*None*) fn x info mc

let print_context x fn =
  mcodekind (Some (Ast0.get_line x)) fn () (Ast0.get_info x)
    (Ast0.get_mcodekind x)

let print_meta (_,name) = print_string name

(* --------------------------------------------------------------------- *)
(* --------------------------------------------------------------------- *)
(* Dots *)

let dots between fn d =
  print_context d
    (function _ ->
      match Ast0.unwrap d with
	Ast0.DOTS(l) -> print_between between fn l
      | Ast0.CIRCLES(l) -> print_between between fn l
      | Ast0.STARS(l) -> print_between between fn l)

(* --------------------------------------------------------------------- *)

let print_types = function
    None -> ()
  | Some ty ->
      print_string "/* ";
      Format.print_flush();
      print_between (function _ -> print_string ", ") Type_cocci.typeC ty;
      Format.print_flush();
      print_string " */"

(* --------------------------------------------------------------------- *)
(* Identifier *)

let rec ident i =
  print_context i
    (function _ ->
      match Ast0.unwrap i with
	Ast0.Id(name) -> mcode print_string name
      | Ast0.MetaId(name,_,_) -> mcode print_meta name
      | Ast0.MetaFunc(name,_,_) -> mcode print_meta name
      | Ast0.MetaLocalFunc(name,_,_) -> mcode print_meta name
      | Ast0.OptIdent(id) -> print_string "?"; ident id
      | Ast0.UniqueIdent(id) -> print_string "!"; ident id)

(* --------------------------------------------------------------------- *)
(* Expression *)

let print_string_box s = print_string s; open_box 0

let rec expression e =
  print_option Type_cocci.typeC (Ast0.get_type e);
  print_context e
    (function _ ->
      match Ast0.unwrap e with
	Ast0.Ident(id) -> ident id
      | Ast0.Constant(const) -> mcode U.constant const
      | Ast0.FunCall(fn,lp,args,rp) ->
	  expression fn; mcode print_string_box lp;
	  let _ = dots (function _ -> ()) expression args in
	  close_box(); mcode print_string rp
      | Ast0.Assignment(left,op,right,_) ->
	  expression left; print_string " "; mcode U.assignOp op;
	  print_string " "; expression right
      | Ast0.CondExpr(exp1,why,exp2,colon,exp3) ->
	  expression exp1; print_string " "; mcode print_string why;
	  print_option (function e -> print_string " "; expression e) exp2;
	  print_string " "; mcode print_string colon; expression exp3
      | Ast0.Postfix(exp,op) -> expression exp; mcode U.fixOp op
      | Ast0.Infix(exp,op) -> mcode U.fixOp op; expression exp
      | Ast0.Unary(exp,op) -> mcode U.unaryOp op; expression exp
      | Ast0.Binary(left,op,right) ->
	  print_string "(";
	  expression left; print_string " "; mcode U.binaryOp op;
	  print_string " "; expression right;
	  print_string ")"
      | Ast0.Paren(lp,exp,rp) ->
	  mcode print_string_box lp; expression exp; close_box();
	  mcode print_string rp
      | Ast0.ArrayAccess(exp1,lb,exp2,rb) ->
	  expression exp1; mcode print_string_box lb; expression exp2;
	  close_box(); mcode print_string rb
      | Ast0.RecordAccess(exp,pt,field) ->
	  expression exp; mcode print_string pt; ident field
      | Ast0.RecordPtAccess(exp,ar,field) ->
	  expression exp; mcode print_string ar; ident field
      | Ast0.Cast(lp,ty,rp,exp) ->
	  mcode print_string_box lp; typeC ty; close_box();
	  mcode print_string rp; expression exp
      | Ast0.SizeOfExpr(szf,exp) ->
	  mcode print_string szf; expression exp
      | Ast0.SizeOfType(szf,lp,ty,rp) ->
          mcode print_string szf;
	  mcode print_string_box lp; typeC ty; close_box();
	  mcode print_string rp
      | Ast0.TypeExp(ty) -> typeC ty
      | Ast0.MetaErr(name,_,_) -> mcode print_meta name
      | Ast0.MetaExpr(name,_,ty,_,_) ->
	  mcode print_meta name; print_types ty
      | Ast0.MetaExprList(name,_,_) -> mcode print_meta name
      | Ast0.EComma(cm) -> mcode print_string cm; print_space()
      | Ast0.DisjExpr(_,exp_list,_,_) ->
	  print_string "\n("; force_newline();
	  print_between
	    (function _ -> print_string "\n|"; force_newline())
	    expression exp_list;
	  print_string "\n)"
      | Ast0.NestExpr(starter,expr_dots,ender,None,multi) ->
	  mcode print_string starter;
	  start_block(); dots force_newline expression expr_dots; end_block();
	  mcode print_string ender
      | Ast0.NestExpr(starter,expr_dots,ender,Some whencode,multi) ->
	  mcode print_string starter; print_string "   WHEN != ";
	  expression whencode;
	  start_block(); dots force_newline expression expr_dots; end_block();
	  mcode print_string ender
      | Ast0.Edots(dots,Some whencode)
      | Ast0.Ecircles(dots,Some whencode)
      | Ast0.Estars(dots,Some whencode) ->
	  mcode print_string dots; print_string "   WHEN != ";
	  expression whencode
      | Ast0.Edots(dots,None)
      | Ast0.Ecircles(dots,None)
      | Ast0.Estars(dots,None) -> mcode print_string dots
      | Ast0.OptExp(exp) -> print_string "?"; expression exp
      | Ast0.UniqueExp(exp) -> print_string "!"; expression exp)

and expression_dots x = dots (function _ -> ()) expression x

(* --------------------------------------------------------------------- *)
(* Types *)

and print_function_pointer (ty,lp1,star,rp1,lp2,params,rp2) fn =
  typeC ty; mcode print_string lp1; mcode print_string star; fn();
  mcode print_string rp1; mcode print_string lp2;
  parameter_list params; mcode print_string rp2

and print_function_type (ty,lp1,params,rp1) fn =
  print_option typeC ty; fn(); mcode print_string lp1;
  parameter_list params; mcode print_string rp1

and typeC t =
  print_context t
    (function _ ->
      match Ast0.unwrap t with
	Ast0.ConstVol(cv,ty) ->
	  mcode U.const_vol cv; print_string " "; typeC ty
      |	Ast0.BaseType(ty,sgn) ->
	  print_option (mcode U.sign) sgn; mcode U.baseType ty
      |	Ast0.ImplicitInt(sgn) -> mcode U.sign sgn
      | Ast0.Pointer(ty,star) -> typeC ty; mcode print_string star
      | Ast0.FunctionPointer(ty,lp1,star,rp1,lp2,params,rp2) ->
	  print_function_pointer (ty,lp1,star,rp1,lp2,params,rp2)
	    (function _ -> ())
      | Ast0.FunctionType(ty,lp1,params,rp1) ->
	  print_function_type (ty,lp1,params,rp1) (function _ -> ())
      | Ast0.Array(ty,lb,size,rb) ->
	  typeC ty; mcode print_string lb; print_option expression size;
	  mcode print_string rb
      | Ast0.StructUnionName(kind,name) ->
	  mcode U.structUnion kind;
	  print_option (function x -> ident x; print_string " ") name
      | Ast0.StructUnionDef(ty,lb,decls,rb) ->
	  typeC ty; mcode print_string lb;
	  dots force_newline declaration decls;
	  mcode print_string rb
      | Ast0.TypeName(name)-> mcode print_string name; print_string " "
      | Ast0.MetaType(name,_)-> mcode print_meta name; print_string " "
      | Ast0.DisjType(lp,types,mids,rp) ->
	  print_string "\n"; mcode print_string lp; force_newline();
	  print_between
	    (function _ -> print_string "\n|"; force_newline())
	    typeC types;
	  print_string "\n"; mcode print_string rp
      | Ast0.OptType(ty) -> print_string "?"; typeC ty
      | Ast0.UniqueType(ty) -> print_string "!"; typeC ty)

(* --------------------------------------------------------------------- *)
(* Variable declaration *)
(* Even if the Cocci program specifies a list of declarations, they are
   split out into multiple declarations of a single variable each. *)

and print_named_type ty id =
  match Ast0.unwrap ty with
    Ast0.FunctionPointer(ty,lp1,star,rp1,lp2,params,rp2) ->
      print_function_pointer (ty,lp1,star,rp1,lp2,params,rp2)
	(function _ -> print_string " "; ident id)
  | Ast0.FunctionType(ty,lp1,params,rp1) ->
      print_function_type (ty,lp1,params,rp1)
	(function _ -> print_string " "; ident id)
  | Ast0.Array(ty,lb,size,rb) ->
      let rec loop ty k =
	match Ast0.unwrap ty with
	  Ast0.Array(ty,lb,size,rb) ->
	    loop ty
	      (function _ ->
		k ();
		mcode print_string lb;
		print_option expression size;
		mcode print_string rb)
	| _ -> typeC ty; ident id; k () in
      loop ty (function _ -> ())
  | _ -> typeC ty; ident id

and declaration d =
  print_context d
    (function _ ->
      match Ast0.unwrap d with
	Ast0.Init(stg,ty,id,eq,ini,sem) ->
	  print_option (mcode U.storage) stg;
	  print_named_type ty id;
	  print_string " ";
	  mcode print_string eq; print_string " "; initialiser ini;
	  mcode print_string sem
      | Ast0.UnInit(stg,ty,id,sem) ->
	  print_option (mcode U.storage) stg; print_named_type ty id;
	  mcode print_string sem
      | Ast0.MacroDecl(name,lp,args,rp,sem) ->
	  mcode print_string name; mcode print_string_box lp;
	  let _ = dots (function _ -> ()) expression args in
	  close_box(); mcode print_string rp; mcode print_string sem
      | Ast0.TyDecl(ty,sem) -> typeC ty; mcode print_string sem
      | Ast0.Typedef(stg,ty,id,sem) ->
	  mcode print_string stg; typeC ty; typeC id;
	  mcode print_string sem
      | Ast0.DisjDecl(_,decls,_,_) ->
	  print_string "\n("; force_newline();
	  print_between
	    (function _ -> print_string "\n|"; force_newline())
	    declaration decls;
	  print_string "\n)"
      | Ast0.Ddots(dots,Some whencode) -> 
	  mcode print_string dots; print_string "   when != ";
	  declaration whencode
      | Ast0.Ddots(dots,None) -> mcode print_string dots
      | Ast0.OptDecl(decl) -> print_string "?"; declaration decl
      | Ast0.UniqueDecl(decl) -> print_string "!"; declaration decl)

and declaration_dots l = dots (function _ -> ()) declaration l

(* --------------------------------------------------------------------- *)
(* Initialiser *)

and initialiser i =
  print_context i
    (function _ ->
      match Ast0.unwrap i with
	Ast0.InitExpr(exp) -> expression exp
      | Ast0.InitList(lb,initlist,rb) ->
	  mcode print_string lb; open_box 0;
	  let _ = dots (function _ -> ()) initialiser initlist in
	  close_box(); mcode print_string rb
      | Ast0.InitGccDotName(dot,name,eq,ini) ->
	  mcode print_string dot; ident name; print_string " ";
	  mcode print_string eq; print_string " "; initialiser ini
      | Ast0.InitGccName(name,eq,ini) ->
	  ident name; mcode print_string eq; initialiser ini
      | Ast0.InitGccIndex(lb,exp,rb,eq,ini) ->
	  mcode print_string lb; expression exp; mcode print_string rb;
	  print_string " "; mcode print_string eq; print_string " ";
	  initialiser ini
      | Ast0.InitGccRange(lb,exp1,dots,exp2,rb,eq,ini) ->
	  mcode print_string lb; expression exp1; mcode print_string dots;
	  expression exp2; mcode print_string rb;
	  print_string " "; mcode print_string eq; print_string " ";
	  initialiser ini
      | Ast0.IComma(cm) -> mcode print_string cm; force_newline()
      | Ast0.Idots(d,Some whencode) ->
	  mcode print_string d; print_string "   WHEN != ";
	  initialiser whencode
      | Ast0.Idots(d,None) -> mcode print_string d
      | Ast0.OptIni(ini) -> print_string "?"; initialiser ini
      | Ast0.UniqueIni(ini) -> print_string "!"; initialiser ini)

and initialiser_list l = dots (function _ -> ()) initialiser l

(* --------------------------------------------------------------------- *)
(* Parameter *)

and parameterTypeDef p =
  print_context p
    (function _ ->
      match Ast0.unwrap p with
	Ast0.VoidParam(ty) -> typeC ty
      | Ast0.Param(ty,Some id) -> print_named_type ty id
      |	Ast0.Param(ty,None) -> typeC ty
      | Ast0.MetaParam(name,_) -> mcode print_meta name
      | Ast0.MetaParamList(name,_,_) -> mcode print_meta name
      | Ast0.PComma(cm) -> mcode print_string cm; print_space()
      | Ast0.Pdots(dots) -> mcode print_string dots
      | Ast0.Pcircles(dots) -> mcode print_string dots
      | Ast0.OptParam(param) -> print_string "?"; parameterTypeDef param
      | Ast0.UniqueParam(param) -> print_string "!"; parameterTypeDef param)

and parameter_list l = dots (function _ -> ()) parameterTypeDef l

(* --------------------------------------------------------------------- *)
(* Top-level code *)

and statement arity s =
  print_context s
    (function _ ->
      match Ast0.unwrap s with
	Ast0.FunDecl(_,fninfo,name,lp,params,rp,lbrace,body,rbrace) ->
	  print_string arity;
	  List.iter print_fninfo fninfo;
	  ident name; mcode print_string_box lp;
	  parameter_list params; close_box(); mcode print_string rp;
	  print_string " ";
	  print_string arity; mcode print_string lbrace; start_block();
	  dots force_newline (statement arity) body;
	  end_block(); print_string arity; mcode print_string rbrace
      | Ast0.Decl(_,decl) -> print_string arity; declaration decl
      | Ast0.Seq(lbrace,body,rbrace) ->
	  print_string arity; mcode print_string lbrace; start_block();
	  dots force_newline (statement arity) body;
	  end_block(); print_string arity; mcode print_string rbrace
      | Ast0.ExprStatement(exp,sem) ->
	  print_string arity; expression exp; mcode print_string sem
      | Ast0.IfThen(iff,lp,exp,rp,branch1,(info,aft)) ->
	  print_string arity;
	  mcode print_string iff; print_string " "; mcode print_string_box lp;
	  expression exp; close_box(); mcode print_string rp; print_string " ";
	  statement arity branch1;
	  mcode (function _ -> ()) ((),(),info,aft)
      | Ast0.IfThenElse(iff,lp,exp,rp,branch1,els,branch2,(info,aft)) ->
	  print_string arity;
	  mcode print_string iff; print_string " "; mcode print_string_box lp;
	  expression exp; close_box(); mcode print_string rp; print_string " ";
	  statement arity branch1;
	  print_string arity; mcode print_string els; print_string " ";
	  statement arity branch2;
	  mcode (function _ -> ()) ((),(),info,aft)
      | Ast0.While(whl,lp,exp,rp,body,(info,aft)) ->
	  print_string arity;
	  mcode print_string whl; print_string " "; mcode print_string_box lp;
	  expression exp; close_box(); mcode print_string rp; print_string " ";
	  statement arity body;
	  mcode (function _ -> ()) ((),(),info,aft)
      | Ast0.Do(d,body,whl,lp,exp,rp,sem) ->
	  print_string arity; mcode print_string d; print_string " ";
	  statement arity body;
	  print_string arity;
	  mcode print_string whl; print_string " "; mcode print_string_box lp;
	  expression exp; close_box(); mcode print_string rp;
	  mcode print_string sem
      | Ast0.For(fr,lp,e1,sem1,e2,sem2,e3,rp,body,(info,aft)) ->
	  print_string arity;
	  mcode print_string fr; mcode print_string_box lp;
	  print_option expression e1; mcode print_string sem1;
	  print_option expression e2; mcode print_string sem2;
	  print_option expression e3; close_box();
	  mcode print_string rp; print_string " "; statement arity body;
	  mcode (function _ -> ()) ((),(),info,aft)
      | Ast0.Iterator(nm,lp,args,rp,body,(info,aft)) ->
	  print_string arity;
	  mcode print_string nm; print_string " "; mcode print_string_box lp;
	  let _ = dots (function _ -> ()) expression args in
	  close_box(); mcode print_string rp; print_string " ";
	  statement arity body;
	  mcode (function _ -> ()) ((),(),info,aft)
      |	Ast0.Switch(switch,lp,exp,rp,lb,cases,rb) ->
	  print_string arity;
	  mcode print_string switch; print_string " ";
	  mcode print_string_box lp; expression exp; close_box();
	  mcode print_string rp; print_string " "; mcode print_string lb;
	  dots force_newline (case_line arity) cases;
	  mcode print_string rb
      | Ast0.Break(br,sem) ->
	  print_string arity; mcode print_string br; mcode print_string sem
      | Ast0.Continue(cont,sem) ->
	  print_string arity; mcode print_string cont; mcode print_string sem
      | Ast0.Return(ret,sem) ->
	  print_string arity; mcode print_string ret; mcode print_string sem
      | Ast0.ReturnExpr(ret,exp,sem) ->
	  print_string arity; mcode print_string ret; print_string " ";
	  expression exp; mcode print_string sem
      | Ast0.MetaStmt(name,pure) ->
	  print_string arity; mcode print_meta name;(*
	  print_string "^";
	  (match pure with
	    Ast0.Pure -> print_string "pure"
	  | Ast0.Impure -> print_string "impure"
	  | Ast0.Context -> print_string "context"
	  | Ast0.PureContext -> print_string "pure_context")*)
      | Ast0.MetaStmtList(name,_) ->
	  print_string arity;  mcode print_meta name
      | Ast0.Disj(_,statement_dots_list,_,_) ->
	  print_string arity;
	  print_string "\n("; force_newline();
	  print_between
	    (function _ -> print_string "\n|"; force_newline())
	    (dots force_newline (statement arity))
	    statement_dots_list;
	  print_string "\n)"
      | Ast0.Nest(starter,stmt_dots,ender,whencode,multi) ->
	  print_string arity;
	  mcode print_string starter;
	  open_box 0;
	  List.iter
	    (function x ->
	      print_string "   WHEN != "; open_box 0;
	      dots force_newline (statement "") x)
	    whencode;
	  close_box();
	  start_block();
	  dots force_newline (statement arity) stmt_dots;
	  end_block();
	  mcode print_string ender
      | Ast0.Exp(exp) -> print_string arity; expression exp
      | Ast0.TopExp(exp) -> print_string arity; expression exp
      | Ast0.Ty(ty) -> print_string arity; typeC ty
      | Ast0.Dots(d,whn) | Ast0.Circles(d,whn) | Ast0.Stars(d,whn) ->
	  print_string arity; mcode print_string d;
	  List.iter
	    (whencode (dots force_newline (statement "")) (statement ""))
	    whn
      | Ast0.Include(inc,s) ->
	  mcode print_string inc; print_string " "; mcode U.inc_file s
      | Ast0.Define(def,id,params,body) ->
	  mcode print_string def; print_string " "; ident id;
	  print_define_parameters params;
	  print_string " ";
	  dots force_newline (statement arity) body
      | Ast0.OptStm(re) -> statement "?" re
      | Ast0.UniqueStm(re) -> statement "!" re)

and print_define_parameters params =
  match Ast0.unwrap params with
    Ast0.NoParams -> ()
  | Ast0.DParams(lp,params,rp) ->
      mcode print_string lp;
      dots (function _ -> ()) print_define_param params; mcode print_string rp

and print_define_param param =
  match Ast0.unwrap param with
    Ast0.DParam(id) -> ident id
  | Ast0.DPComma(comma) -> mcode print_string comma
  | Ast0.DPdots(dots) -> mcode print_string dots
  | Ast0.DPcircles(circles) -> mcode print_string circles
  | Ast0.OptDParam(dp) -> print_string "?"; print_define_param dp
  | Ast0.UniqueDParam(dp) -> print_string "!"; print_define_param dp

and print_fninfo = function
    Ast0.FStorage(stg) -> mcode U.storage stg
  | Ast0.FType(ty) -> typeC ty
  | Ast0.FInline(inline) -> mcode print_string inline
  | Ast0.FAttr(attr) -> mcode print_string attr

and whencode notfn alwaysfn = function
    Ast0.WhenNot a ->
      print_string "   WHEN != "; open_box 0; notfn a; close_box()
  | Ast0.WhenAlways a ->
      print_string "   WHEN = "; open_box 0; alwaysfn a; close_box()
  | Ast0.WhenAny -> print_string "   WHEN ANY"

and case_line arity c =
  print_context c
    (function _ ->
      match Ast0.unwrap c with
	Ast0.Default(def,colon,code) ->
	  print_string arity;
	  mcode print_string def; mcode print_string colon; print_string " ";
	  dots force_newline (statement arity) code
      | Ast0.Case(case,exp,colon,code) ->
	  print_string arity;
	  mcode print_string case; print_string " "; expression exp;
	  mcode print_string colon; print_string " ";
	  dots force_newline (statement arity) code
      | Ast0.OptCase(case) -> case_line "?" case)

and statement_dots l = dots (function _ -> ()) (statement "") l
and case_dots l = dots (function _ -> ()) (case_line "") l

(* --------------------------------------------------------------------- *)
(* Top level code *)

let top_level t =
  print_context t
    (function _ ->
      match Ast0.unwrap t with
	Ast0.FILEINFO(old_file,new_file) ->
	  print_string "--- "; mcode print_string old_file; force_newline();
	  print_string "+++ "; mcode print_string new_file
      | Ast0.DECL(stmt) -> statement "" stmt
      | Ast0.CODE(stmt_dots) ->
	  dots force_newline (statement "") stmt_dots
      | Ast0.ERRORWORDS(exps) ->
	  print_string "error words = [";
	  print_between (function _ -> print_string ", ") expression exps;
	  print_string "]"
      | Ast0.OTHER(s) ->
	  print_string "OTHER("; statement "" s; print_string ")")

let rule =
  print_between (function _ -> force_newline(); force_newline()) top_level

let unparse_anything x =
  let q = !quiet in
  quiet := true;
  (match x with
    Ast0.DotsExprTag(d) ->
      expression_dots d
  | Ast0.DotsParamTag(d) ->
      parameter_list d
  | Ast0.DotsInitTag(d) ->
      initialiser_list d
  | Ast0.DotsStmtTag(d) ->
      statement_dots d
  | Ast0.DotsDeclTag(d) ->
      declaration_dots d
  | Ast0.DotsCaseTag(d) ->
      case_dots d
  | Ast0.IdentTag(d) ->
      ident d
  | Ast0.ExprTag(d) | Ast0.ArgExprTag(d) | Ast0.TestExprTag(d) ->
      expression d
  | Ast0.TypeCTag(d) ->
      typeC d
  | Ast0.ParamTag(d) ->
      parameterTypeDef d
  | Ast0.InitTag(d) ->
      initialiser d
  | Ast0.DeclTag(d) ->
      declaration d
  | Ast0.StmtTag(d) ->
      statement "" d
  | Ast0.CaseLineTag(d) ->
      case_line "" d
  | Ast0.TopTag(d) ->
      top_level d
  | Ast0.AnyTag -> print_string "any");
  quiet := q;
  print_newline()

let unparse x =
  print_string "\n@@\n@@";
  force_newline();
  force_newline();
  rule x;
  print_newline()

let unparse_to_string x = Common.format_to_string (function _ -> unparse x)
