(*  Title:      HOL/HOL.thy
    ID:         $Id$
    Author:     Tobias Nipkow
    Copyright   1993  University of Cambridge

Higher-Order Logic.
*)

theory HOL = CPure
files ("HOL_lemmas.ML") ("cladata.ML") ("blastdata.ML") ("simpdata.ML"):


(** Core syntax **)

global

classes "term" < logic
defaultsort "term"

typedecl bool

arities
  bool :: "term"
  fun :: ("term", "term") "term"

consts

  (* Constants *)

  Trueprop      :: "bool => prop"                   ("(_)" 5)
  Not           :: "bool => bool"                   ("~ _" [40] 40)
  True          :: bool
  False         :: bool
  If            :: "[bool, 'a, 'a] => 'a"           ("(if (_)/ then (_)/ else (_))" 10)
  arbitrary     :: 'a

  (* Binders *)

  The           :: "('a => bool) => 'a"
  All           :: "('a => bool) => bool"           (binder "ALL " 10)
  Ex            :: "('a => bool) => bool"           (binder "EX " 10)
  Ex1           :: "('a => bool) => bool"           (binder "EX! " 10)
  Let           :: "['a, 'a => 'b] => 'b"

  (* Infixes *)

  "="           :: "['a, 'a] => bool"               (infixl 50)
  &             :: "[bool, bool] => bool"           (infixr 35)
  "|"           :: "[bool, bool] => bool"           (infixr 30)
  -->           :: "[bool, bool] => bool"           (infixr 25)

local


(* Overloaded Constants *)

axclass zero  < "term"
axclass plus  < "term"
axclass minus < "term"
axclass times < "term"
axclass inverse < "term"

global

consts
  "0"           :: "'a::zero"                       ("0")
  "+"           :: "['a::plus, 'a]  => 'a"          (infixl 65)
  -             :: "['a::minus, 'a] => 'a"          (infixl 65)
  uminus        :: "['a::minus] => 'a"              ("- _" [81] 80)
  *             :: "['a::times, 'a] => 'a"          (infixl 70)

local

consts
  abs           :: "'a::minus => 'a"
  inverse       :: "'a::inverse => 'a"
  divide        :: "['a::inverse, 'a] => 'a"        (infixl "'/" 70)

syntax (xsymbols)
  abs :: "'a::minus => 'a"    ("\<bar>_\<bar>")
syntax (HTML output)
  abs :: "'a::minus => 'a"    ("\<bar>_\<bar>")

axclass plus_ac0 < plus, zero
  commute: "x + y = y + x"
  assoc:   "(x + y) + z = x + (y + z)"
  zero:    "0 + x = x"


(** Additional concrete syntax **)

nonterminals
  letbinds  letbind
  case_syn  cases_syn

syntax
  ~=            :: "['a, 'a] => bool"                    (infixl 50)
  "_The"        :: "[pttrn, bool] => 'a"                 ("(3THE _./ _)" [0, 10] 10)

  (* Let expressions *)

  "_bind"       :: "[pttrn, 'a] => letbind"              ("(2_ =/ _)" 10)
  ""            :: "letbind => letbinds"                 ("_")
  "_binds"      :: "[letbind, letbinds] => letbinds"     ("_;/ _")
  "_Let"        :: "[letbinds, 'a] => 'a"                ("(let (_)/ in (_))" 10)

  (* Case expressions *)

  "_case_syntax":: "['a, cases_syn] => 'b"               ("(case _ of/ _)" 10)
  "_case1"      :: "['a, 'b] => case_syn"                ("(2_ =>/ _)" 10)
  ""            :: "case_syn => cases_syn"               ("_")
  "_case2"      :: "[case_syn, cases_syn] => cases_syn"  ("_/ | _")

translations
  "x ~= y"                == "~ (x = y)"
  "THE x. P"              == "The (%x. P)"
  "_Let (_binds b bs) e"  == "_Let b (_Let bs e)"
  "let x = a in e"        == "Let a (%x. e)"

syntax ("" output)
  "="           :: "['a, 'a] => bool"                    (infix 50)
  "~="          :: "['a, 'a] => bool"                    (infix 50)

syntax (symbols)
  Not           :: "bool => bool"                        ("\<not> _" [40] 40)
  "op &"        :: "[bool, bool] => bool"                (infixr "\<and>" 35)
  "op |"        :: "[bool, bool] => bool"                (infixr "\<or>" 30)
  "op -->"      :: "[bool, bool] => bool"                (infixr "\<midarrow>\<rightarrow>" 25)
  "op ~="       :: "['a, 'a] => bool"                    (infix "\<noteq>" 50)
  "ALL "        :: "[idts, bool] => bool"                ("(3\<forall>_./ _)" [0, 10] 10)
  "EX "         :: "[idts, bool] => bool"                ("(3\<exists>_./ _)" [0, 10] 10)
  "EX! "        :: "[idts, bool] => bool"                ("(3\<exists>!_./ _)" [0, 10] 10)
  "_case1"      :: "['a, 'b] => case_syn"                ("(2_ \<Rightarrow>/ _)" 10)
(*"_case2"      :: "[case_syn, cases_syn] => cases_syn"  ("_/ \\<orelse> _")*)

syntax (symbols output)
  "op ~="       :: "['a, 'a] => bool"                    (infix "\<noteq>" 50)

syntax (xsymbols)
  "op -->"      :: "[bool, bool] => bool"                (infixr "\<longrightarrow>" 25)

syntax (HTML output)
  Not           :: "bool => bool"                        ("\<not> _" [40] 40)

syntax (HOL)
  "ALL "        :: "[idts, bool] => bool"                ("(3! _./ _)" [0, 10] 10)
  "EX "         :: "[idts, bool] => bool"                ("(3? _./ _)" [0, 10] 10)
  "EX! "        :: "[idts, bool] => bool"                ("(3?! _./ _)" [0, 10] 10)



(** Rules and definitions **)

axioms

  eq_reflection: "(x=y) ==> (x==y)"

  (* Basic Rules *)

  refl:         "t = (t::'a)"
  subst:        "[| s = t; P(s) |] ==> P(t::'a)"

  (*Extensionality is built into the meta-logic, and this rule expresses
    a related property.  It is an eta-expanded version of the traditional
    rule, and similar to the ABS rule of HOL.*)
  ext:          "(!!x::'a. (f x ::'b) = g x) ==> (%x. f x) = (%x. g x)"

  the_eq_trivial: "(THE x. x = a) = (a::'a)"

  impI:         "(P ==> Q) ==> P-->Q"
  mp:           "[| P-->Q;  P |] ==> Q"

defs

  True_def:     "True      == ((%x::bool. x) = (%x. x))"
  All_def:      "All(P)    == (P = (%x. True))"
  Ex_def:       "Ex(P)     == !Q. (!x. P x --> Q) --> Q"
  False_def:    "False     == (!P. P)"
  not_def:      "~ P       == P-->False"
  and_def:      "P & Q     == !R. (P-->Q-->R) --> R"
  or_def:       "P | Q     == !R. (P-->R) --> (Q-->R) --> R"
  Ex1_def:      "Ex1(P)    == ? x. P(x) & (! y. P(y) --> y=x)"

axioms
  (* Axioms *)

  iff:          "(P-->Q) --> (Q-->P) --> (P=Q)"
  True_or_False:  "(P=True) | (P=False)"

defs
  (*misc definitions*)
  Let_def:      "Let s f == f(s)"
  if_def:       "If P x y == THE z::'a. (P=True --> z=x) & (P=False --> z=y)"

  (*arbitrary is completely unspecified, but is made to appear as a
    definition syntactically*)
  arbitrary_def:  "False ==> arbitrary == (THE x. False)"



(* theory and package setup *)

use "HOL_lemmas.ML"
theorems case_split = case_split_thm [case_names True False]

declare trans [trans]  (*overridden in theory Calculation*)

lemma atomize_all: "(!!x. P x) == Trueprop (ALL x. P x)"
proof (rule equal_intr_rule)
  assume "!!x. P x"
  show "ALL x. P x" by (rule allI)
next
  assume "ALL x. P x"
  thus "!!x. P x" by (rule allE)
qed

lemma atomize_imp: "(A ==> B) == Trueprop (A --> B)"
proof (rule equal_intr_rule)
  assume r: "A ==> B"
  show "A --> B" by (rule impI) (rule r)
next
  assume "A --> B" and A
  thus B by (rule mp)
qed

lemma atomize_eq: "(x == y) == Trueprop (x = y)"
proof (rule equal_intr_rule)
  assume "x == y"
  show "x = y" by (unfold prems) (rule refl)
next
  assume "x = y"
  thus "x == y" by (rule eq_reflection)
qed

lemmas atomize = atomize_all atomize_imp
lemmas atomize' = atomize atomize_eq

use "cladata.ML"
setup hypsubst_setup
setup Classical.setup
setup clasetup

use "blastdata.ML"
setup Blast.setup

use "simpdata.ML"
setup Simplifier.setup
setup "Simplifier.method_setup Splitter.split_modifiers" setup simpsetup
setup Splitter.setup setup Clasimp.setup

end
