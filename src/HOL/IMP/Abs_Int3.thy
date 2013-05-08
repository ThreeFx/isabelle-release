(* Author: Tobias Nipkow *)

theory Abs_Int3
imports Abs_Int2_ivl
begin


subsection "Widening and Narrowing"

class widen =
fixes widen :: "'a \<Rightarrow> 'a \<Rightarrow> 'a" (infix "\<nabla>" 65)

class narrow =
fixes narrow :: "'a \<Rightarrow> 'a \<Rightarrow> 'a" (infix "\<triangle>" 65)

class WN = widen + narrow + order +
assumes widen1: "x \<le> x \<nabla> y"
assumes widen2: "y \<le> x \<nabla> y"
assumes narrow1: "y \<le> x \<Longrightarrow> y \<le> x \<triangle> y"
assumes narrow2: "y \<le> x \<Longrightarrow> x \<triangle> y \<le> x"
begin

lemma narrowid[simp]: "x \<triangle> x = x"
by (metis eq_iff narrow1 narrow2)

end

lemma top_widen_top[simp]: "\<top> \<nabla> \<top> = (\<top>::_::{WN,top})"
by (metis eq_iff top_greatest widen2)

instantiation ivl :: WN
begin

definition "widen_rep p1 p2 =
  (if is_empty_rep p1 then p2 else if is_empty_rep p2 then p1 else
   let (l1,h1) = p1; (l2,h2) = p2
   in (if l2 < l1 then Minf else l1, if h1 < h2 then Pinf else h1))"

lift_definition widen_ivl :: "ivl \<Rightarrow> ivl \<Rightarrow> ivl" is widen_rep
by(auto simp: widen_rep_def eq_ivl_iff)

definition "narrow_rep p1 p2 =
  (if is_empty_rep p1 \<or> is_empty_rep p2 then empty_rep else
   let (l1,h1) = p1; (l2,h2) = p2
   in (if l1 = Minf then l2 else l1, if h1 = Pinf then h2 else h1))"

lift_definition narrow_ivl :: "ivl \<Rightarrow> ivl \<Rightarrow> ivl" is narrow_rep
by(auto simp: narrow_rep_def eq_ivl_iff)

instance
proof
qed (transfer, auto simp: widen_rep_def narrow_rep_def le_iff_subset \<gamma>_rep_def subset_eq is_empty_rep_def empty_rep_def eq_ivl_def split: if_splits extended.splits)+

end

instantiation st :: ("{top,WN}")WN
begin

lift_definition widen_st :: "'a st \<Rightarrow> 'a st \<Rightarrow> 'a st" is "map2_st_rep (op \<nabla>)"
by(auto simp: eq_st_def)

lift_definition narrow_st :: "'a st \<Rightarrow> 'a st \<Rightarrow> 'a st" is "map2_st_rep (op \<triangle>)"
by(auto simp: eq_st_def)

instance
proof
  case goal1 thus ?case
    by transfer (simp add: less_eq_st_rep_iff widen1)
next
  case goal2 thus ?case
    by transfer (simp add: less_eq_st_rep_iff widen2)
next
  case goal3 thus ?case
    by transfer (simp add: less_eq_st_rep_iff narrow1)
next
  case goal4 thus ?case
    by transfer (simp add: less_eq_st_rep_iff narrow2)
qed

end


instantiation option :: (WN)WN
begin

fun widen_option where
"None \<nabla> x = x" |
"x \<nabla> None = x" |
"(Some x) \<nabla> (Some y) = Some(x \<nabla> y)"

fun narrow_option where
"None \<triangle> x = None" |
"x \<triangle> None = None" |
"(Some x) \<triangle> (Some y) = Some(x \<triangle> y)"

instance
proof
  case goal1 thus ?case
    by(induct x y rule: widen_option.induct)(simp_all add: widen1)
next
  case goal2 thus ?case
    by(induct x y rule: widen_option.induct)(simp_all add: widen2)
next
  case goal3 thus ?case
    by(induct x y rule: narrow_option.induct) (simp_all add: narrow1)
next
  case goal4 thus ?case
    by(induct x y rule: narrow_option.induct) (simp_all add: narrow2)
qed

end

text_raw{*\snip{maptwoacomdef}{2}{2}{% *}
fun map2_acom :: "('a \<Rightarrow> 'a \<Rightarrow> 'a) \<Rightarrow> 'a acom \<Rightarrow> 'a acom \<Rightarrow> 'a acom"
where
"map2_acom f (SKIP {a\<^isub>1}) (SKIP {a\<^isub>2}) = (SKIP {f a\<^isub>1 a\<^isub>2})" |
"map2_acom f (x ::= e {a\<^isub>1}) (x' ::= e' {a\<^isub>2}) = (x ::= e {f a\<^isub>1 a\<^isub>2})" |
"map2_acom f (C\<^isub>1;C\<^isub>2) (D\<^isub>1;D\<^isub>2)
  = (map2_acom f C\<^isub>1 D\<^isub>1; map2_acom f C\<^isub>2 D\<^isub>2)" |
"map2_acom f (IF b THEN {p\<^isub>1} C\<^isub>1 ELSE {p\<^isub>2} C\<^isub>2 {a\<^isub>1})
  (IF b' THEN {q\<^isub>1} D\<^isub>1 ELSE {q\<^isub>2} D\<^isub>2 {a\<^isub>2})
  = (IF b THEN {f p\<^isub>1 q\<^isub>1} map2_acom f C\<^isub>1 D\<^isub>1
     ELSE {f p\<^isub>2 q\<^isub>2} map2_acom f C\<^isub>2 D\<^isub>2 {f a\<^isub>1 a\<^isub>2})" |
"map2_acom f ({a\<^isub>1} WHILE b DO {p} C {a\<^isub>2})
  ({a\<^isub>3} WHILE b' DO {q} D {a\<^isub>4})
  = ({f a\<^isub>1 a\<^isub>3} WHILE b DO {f p q} map2_acom f C D {f a\<^isub>2 a\<^isub>4})"
text_raw{*}%endsnip*}

lemma annos_map2_acom[simp]: "strip C2 = strip C1 \<Longrightarrow>
  annos(map2_acom f C1 C2) = map (%(x,y).f x y) (zip (annos C1) (annos C2))"
by(induction f C1 C2 rule: map2_acom.induct)(simp_all add: size_annos_same2)

instantiation acom :: (widen)widen
begin
definition "widen_acom = map2_acom (op \<nabla>)"
instance ..
end

instantiation acom :: (narrow)narrow
begin
definition "narrow_acom = map2_acom (op \<triangle>)"
instance ..
end

lemma strip_map2_acom[simp]:
 "strip C1 = strip C2 \<Longrightarrow> strip(map2_acom f C1 C2) = strip C1"
by(induct f C1 C2 rule: map2_acom.induct) simp_all

lemma strip_widen_acom[simp]:
  "strip C1 = strip C2 \<Longrightarrow> strip(C1 \<nabla> C2) = strip C1"
by(simp add: widen_acom_def)

lemma strip_narrow_acom[simp]:
  "strip C1 = strip C2 \<Longrightarrow> strip(C1 \<triangle> C2) = strip C1"
by(simp add: narrow_acom_def)

lemma narrow1_acom: "C2 \<le> C1 \<Longrightarrow> C2 \<le> C1 \<triangle> (C2::'a::WN acom)"
by(induct C1 C2 rule: less_eq_acom.induct)(simp_all add: narrow_acom_def narrow1)

lemma narrow2_acom: "C2 \<le> C1 \<Longrightarrow> C1 \<triangle> (C2::'a::WN acom) \<le> C1"
by(induct C1 C2 rule: less_eq_acom.induct)(simp_all add: narrow_acom_def narrow2)


subsubsection "Post-fixed point computation"

definition iter_widen :: "('a \<Rightarrow> 'a) \<Rightarrow> 'a \<Rightarrow> ('a::{order,widen})option"
where "iter_widen f = while_option (\<lambda>x. \<not> f x \<le> x) (\<lambda>x. x \<nabla> f x)"

definition iter_narrow :: "('a \<Rightarrow> 'a) \<Rightarrow> 'a \<Rightarrow> ('a::{order,narrow})option"
where "iter_narrow f = while_option (\<lambda>x. x \<triangle> f x < x) (\<lambda>x. x \<triangle> f x)"

definition pfp_wn :: "('a::{order,widen,narrow} \<Rightarrow> 'a) \<Rightarrow> 'a \<Rightarrow> 'a option"
where "pfp_wn f x =
  (case iter_widen f x of None \<Rightarrow> None | Some p \<Rightarrow> iter_narrow f p)"


lemma iter_widen_pfp: "iter_widen f x = Some p \<Longrightarrow> f p \<le> p"
by(auto simp add: iter_widen_def dest: while_option_stop)

lemma iter_widen_inv:
assumes "!!x. P x \<Longrightarrow> P(f x)" "!!x1 x2. P x1 \<Longrightarrow> P x2 \<Longrightarrow> P(x1 \<nabla> x2)" and "P x"
and "iter_widen f x = Some y" shows "P y"
using while_option_rule[where P = "P", OF _ assms(4)[unfolded iter_widen_def]]
by (blast intro: assms(1-3))

lemma strip_while: fixes f :: "'a acom \<Rightarrow> 'a acom"
assumes "\<forall>C. strip (f C) = strip C" and "while_option P f C = Some C'"
shows "strip C' = strip C"
using while_option_rule[where P = "\<lambda>C'. strip C' = strip C", OF _ assms(2)]
by (metis assms(1))

lemma strip_iter_widen: fixes f :: "'a::{order,widen} acom \<Rightarrow> 'a acom"
assumes "\<forall>C. strip (f C) = strip C" and "iter_widen f C = Some C'"
shows "strip C' = strip C"
proof-
  have "\<forall>C. strip(C \<nabla> f C) = strip C"
    by (metis assms(1) strip_map2_acom widen_acom_def)
  from strip_while[OF this] assms(2) show ?thesis by(simp add: iter_widen_def)
qed

lemma iter_narrow_pfp:
assumes mono: "!!x1 x2::_::WN acom. P x1 \<Longrightarrow> P x2 \<Longrightarrow> x1 \<le> x2 \<Longrightarrow> f x1 \<le> f x2"
and Pinv: "!!x. P x \<Longrightarrow> P(f x)" "!!x1 x2. P x1 \<Longrightarrow> P x2 \<Longrightarrow> P(x1 \<triangle> x2)"
and "P p0" and "f p0 \<le> p0" and "iter_narrow f p0 = Some p"
shows "P p \<and> f p \<le> p"
proof-
  let ?Q = "%p. P p \<and> f p \<le> p \<and> p \<le> p0"
  { fix p assume "?Q p"
    note P = conjunct1[OF this] and 12 = conjunct2[OF this]
    note 1 = conjunct1[OF 12] and 2 = conjunct2[OF 12]
    let ?p' = "p \<triangle> f p"
    have "?Q ?p'"
    proof auto
      show "P ?p'" by (blast intro: P Pinv)
      have "f ?p' \<le> f p" by(rule mono[OF `P (p \<triangle> f p)`  P narrow2_acom[OF 1]])
      also have "\<dots> \<le> ?p'" by(rule narrow1_acom[OF 1])
      finally show "f ?p' \<le> ?p'" .
      have "?p' \<le> p" by (rule narrow2_acom[OF 1])
      also have "p \<le> p0" by(rule 2)
      finally show "?p' \<le> p0" .
    qed
  }
  thus ?thesis
    using while_option_rule[where P = ?Q, OF _ assms(6)[simplified iter_narrow_def]]
    by (blast intro: assms(4,5) le_refl)
qed

lemma pfp_wn_pfp:
assumes mono: "!!x1 x2::_::WN acom. P x1 \<Longrightarrow> P x2 \<Longrightarrow> x1 \<le> x2 \<Longrightarrow> f x1 \<le> f x2"
and Pinv: "P x"  "!!x. P x \<Longrightarrow> P(f x)"
  "!!x1 x2. P x1 \<Longrightarrow> P x2 \<Longrightarrow> P(x1 \<nabla> x2)"
  "!!x1 x2. P x1 \<Longrightarrow> P x2 \<Longrightarrow> P(x1 \<triangle> x2)"
and pfp_wn: "pfp_wn f x = Some p" shows "P p \<and> f p \<le> p"
proof-
  from pfp_wn obtain p0
    where its: "iter_widen f x = Some p0" "iter_narrow f p0 = Some p"
    by(auto simp: pfp_wn_def split: option.splits)
  have "P p0" by (blast intro: iter_widen_inv[where P="P"] its(1) Pinv(1-3))
  thus ?thesis
    by - (assumption |
          rule iter_narrow_pfp[where P=P] mono Pinv(2,4) iter_widen_pfp its)+
qed

lemma strip_pfp_wn:
  "\<lbrakk> \<forall>C. strip(f C) = strip C; pfp_wn f C = Some C' \<rbrakk> \<Longrightarrow> strip C' = strip C"
by(auto simp add: pfp_wn_def iter_narrow_def split: option.splits)
  (metis (mono_tags) strip_iter_widen strip_narrow_acom strip_while)


locale Abs_Int2 = Abs_Int1_mono where \<gamma>=\<gamma>
  for \<gamma> :: "'av::{WN,bounded_lattice} \<Rightarrow> val set"
begin

definition AI_wn :: "com \<Rightarrow> 'av st option acom option" where
"AI_wn c = pfp_wn (step' \<top>) (bot c)"

lemma AI_wn_sound: "AI_wn c = Some C \<Longrightarrow> CS c \<le> \<gamma>\<^isub>c C"
proof(simp add: CS_def AI_wn_def)
  assume 1: "pfp_wn (step' \<top>) (bot c) = Some C"
  have 2: "strip C = c \<and> step' \<top> C \<le> C"
    by(rule pfp_wn_pfp[where x="bot c"]) (simp_all add: 1 mono_step'_top)
  have pfp: "step (\<gamma>\<^isub>o \<top>) (\<gamma>\<^isub>c C) \<le> \<gamma>\<^isub>c C"
  proof(rule order_trans)
    show "step (\<gamma>\<^isub>o \<top>) (\<gamma>\<^isub>c C) \<le>  \<gamma>\<^isub>c (step' \<top> C)"
      by(rule step_step')
    show "... \<le> \<gamma>\<^isub>c C"
      by(rule mono_gamma_c[OF conjunct2[OF 2]])
  qed
  have 3: "strip (\<gamma>\<^isub>c C) = c" by(simp add: strip_pfp_wn[OF _ 1])
  have "lfp c (step (\<gamma>\<^isub>o \<top>)) \<le> \<gamma>\<^isub>c C"
    by(rule lfp_lowerbound[simplified,where f="step (\<gamma>\<^isub>o \<top>)", OF 3 pfp])
  thus "lfp c (step UNIV) \<le> \<gamma>\<^isub>c C" by simp
qed

end

interpretation Abs_Int2
where \<gamma> = \<gamma>_ivl and num' = num_ivl and plus' = "op +"
and test_num' = in_ivl
and constrain_plus' = constrain_plus_ivl and constrain_less' = constrain_less_ivl
defines AI_ivl' is AI_wn
..


subsubsection "Tests"

definition "step_up_ivl n = ((\<lambda>C. C \<nabla> step_ivl \<top> C)^^n)"
definition "step_down_ivl n = ((\<lambda>C. C \<triangle> step_ivl \<top> C)^^n)"

text{* For @{const test3_ivl}, @{const AI_ivl} needed as many iterations as
the loop took to execute. In contrast, @{const AI_ivl'} converges in a
constant number of steps: *}

value "show_acom (step_up_ivl 1 (bot test3_ivl))"
value "show_acom (step_up_ivl 2 (bot test3_ivl))"
value "show_acom (step_up_ivl 3 (bot test3_ivl))"
value "show_acom (step_up_ivl 4 (bot test3_ivl))"
value "show_acom (step_up_ivl 5 (bot test3_ivl))"
value "show_acom (step_up_ivl 6 (bot test3_ivl))"
value "show_acom (step_up_ivl 7 (bot test3_ivl))"
value "show_acom (step_up_ivl 8 (bot test3_ivl))"
value "show_acom (step_down_ivl 1 (step_up_ivl 8 (bot test3_ivl)))"
value "show_acom (step_down_ivl 2 (step_up_ivl 8 (bot test3_ivl)))"
value "show_acom (step_down_ivl 3 (step_up_ivl 8 (bot test3_ivl)))"
value "show_acom (step_down_ivl 4 (step_up_ivl 8 (bot test3_ivl)))"
value "show_acom_opt (AI_ivl' test3_ivl)"


text{* Now all the analyses terminate: *}

value "show_acom_opt (AI_ivl' test4_ivl)"
value "show_acom_opt (AI_ivl' test5_ivl)"
value "show_acom_opt (AI_ivl' test6_ivl)"


subsubsection "Generic Termination Proof"

lemma top_on_opt_widen:
  "top_on_opt o1 X \<Longrightarrow> top_on_opt o2 X \<Longrightarrow> top_on_opt (o1 \<nabla> o2 :: _ st option) X"
apply(induct o1 o2 rule: widen_option.induct)
apply (auto)
by transfer simp

lemma top_on_opt_narrow:
  "top_on_opt o1 X \<Longrightarrow> top_on_opt o2 X \<Longrightarrow> top_on_opt (o1 \<triangle> o2 :: _ st option) X"
apply(induct o1 o2 rule: narrow_option.induct)
apply (auto)
by transfer simp

lemma top_on_acom_widen:
  "\<lbrakk>top_on_acom C1 X; strip C1 = strip C2; top_on_acom C2 X\<rbrakk>
  \<Longrightarrow> top_on_acom (C1 \<nabla> C2 :: _ st option acom) X"
by(auto simp add: widen_acom_def top_on_acom_def)(metis top_on_opt_widen in_set_zipE)

lemma top_on_acom_narrow:
  "\<lbrakk>top_on_acom C1 X; strip C1 = strip C2; top_on_acom C2 X\<rbrakk>
  \<Longrightarrow> top_on_acom (C1 \<triangle> C2 :: _ st option acom) X"
by(auto simp add: narrow_acom_def top_on_acom_def)(metis top_on_opt_narrow in_set_zipE)

text{* The assumptions for widening and narrowing differ because during
narrowing we have the invariant @{prop"y \<le> x"} (where @{text y} is the next
iterate), but during widening there is no such invariant, there we only have
that not yet @{prop"y \<le> x"}. This complicates the termination proof for
widening. *}

locale Measure_WN = Measure1 where m=m
  for m :: "'av::{top,WN} \<Rightarrow> nat" +
fixes n :: "'av \<Rightarrow> nat"
assumes m_anti_mono: "x \<le> y \<Longrightarrow> m x \<ge> m y"
assumes m_widen: "~ y \<le> x \<Longrightarrow> m(x \<nabla> y) < m x"
assumes n_narrow: "y \<le> x \<Longrightarrow> x \<triangle> y < x \<Longrightarrow> n(x \<triangle> y) < n x"

begin

lemma m_s_anti_mono_rep: assumes "\<forall>x. S1 x \<le> S2 x"
shows "(\<Sum>x\<in>X. m (S2 x)) \<le> (\<Sum>x\<in>X. m (S1 x))"
proof-
  from assms have "\<forall>x. m(S1 x) \<ge> m(S2 x)" by (metis m_anti_mono)
  thus "(\<Sum>x\<in>X. m (S2 x)) \<le> (\<Sum>x\<in>X. m (S1 x))" by (metis setsum_mono)
qed

lemma m_s_anti_mono: "S1 \<le> S2 \<Longrightarrow> m_s S1 X \<ge> m_s S2 X"
unfolding m_s_def
apply (transfer fixing: m)
apply(simp add: less_eq_st_rep_iff eq_st_def m_s_anti_mono_rep)
done

lemma m_s_widen_rep: assumes "finite X" "S1 = S2 on -X" "\<not> S2 x \<le> S1 x"
  shows "(\<Sum>x\<in>X. m (S1 x \<nabla> S2 x)) < (\<Sum>x\<in>X. m (S1 x))"
proof-
  have 1: "\<forall>x\<in>X. m(S1 x) \<ge> m(S1 x \<nabla> S2 x)"
    by (metis m_anti_mono WN_class.widen1)
  have "x \<in> X" using assms(2,3)
    by(auto simp add: Ball_def)
  hence 2: "\<exists>x\<in>X. m(S1 x) > m(S1 x \<nabla> S2 x)"
    using assms(3) m_widen by blast
  from setsum_strict_mono_ex1[OF `finite X` 1 2]
  show ?thesis .
qed

lemma m_s_widen: "finite X \<Longrightarrow> fun S1 = fun S2 on -X ==>
  ~ S2 \<le> S1 \<Longrightarrow> m_s (S1 \<nabla> S2) X < m_s S1 X"
apply(auto simp add: less_st_def m_s_def)
apply (transfer fixing: m)
apply(auto simp add: less_eq_st_rep_iff m_s_widen_rep)
done

lemma m_o_anti_mono: "finite X \<Longrightarrow> top_on_opt o1 (-X) \<Longrightarrow> top_on_opt o2 (-X) \<Longrightarrow>
  o1 \<le> o2 \<Longrightarrow> m_o o1 X \<ge> m_o o2 X"
proof(induction o1 o2 rule: less_eq_option.induct)
  case 1 thus ?case by (simp add: m_o_def)(metis m_s_anti_mono)
next
  case 2 thus ?case
    by(simp add: m_o_def le_SucI m_s_h split: option.splits)
next
  case 3 thus ?case by simp
qed

lemma m_o_widen: "\<lbrakk> finite X; top_on_opt S1 (-X); top_on_opt S2 (-X); \<not> S2 \<le> S1 \<rbrakk> \<Longrightarrow>
  m_o (S1 \<nabla> S2) X < m_o S1 X"
by(auto simp: m_o_def m_s_h less_Suc_eq_le m_s_widen split: option.split)

lemma m_c_widen:
  "strip C1 = strip C2  \<Longrightarrow> top_on_acom C1 (-vars C1) \<Longrightarrow> top_on_acom C2 (-vars C2)
   \<Longrightarrow> \<not> C2 \<le> C1 \<Longrightarrow> m_c (C1 \<nabla> C2) < m_c C1"
apply(auto simp: m_c_def widen_acom_def listsum_setsum_nth)
apply(subgoal_tac "length(annos C2) = length(annos C1)")
 prefer 2 apply (simp add: size_annos_same2)
apply (auto)
apply(rule setsum_strict_mono_ex1)
 apply(auto simp add: m_o_anti_mono vars_acom_def top_on_acom_def top_on_opt_widen widen1 le_iff_le_annos listrel_iff_nth)
apply(rule_tac x=i in bexI)
 apply (auto simp: vars_acom_def m_o_widen top_on_acom_def)
done


definition n_s :: "'av st \<Rightarrow> vname set \<Rightarrow> nat" ("n\<^isub>s") where
"n\<^isub>s S X = (\<Sum>x\<in>X. n(fun S x))"

lemma n_s_narrow_rep:
assumes "finite X"  "S1 = S2 on -X"  "\<forall>x. S2 x \<le> S1 x"  "\<forall>x. S1 x \<triangle> S2 x \<le> S1 x"
  "S1 x \<noteq> S1 x \<triangle> S2 x"
shows "(\<Sum>x\<in>X. n (S1 x \<triangle> S2 x)) < (\<Sum>x\<in>X. n (S1 x))"
proof-
  have 1: "\<forall>x. n(S1 x \<triangle> S2 x) \<le> n(S1 x)"
      by (metis assms(3) assms(4) eq_iff less_le_not_le n_narrow)
  have "x \<in> X" by (metis Compl_iff assms(2) assms(5) narrowid)
  hence 2: "\<exists>x\<in>X. n(S1 x \<triangle> S2 x) < n(S1 x)"
    by (metis assms(3-5) eq_iff less_le_not_le n_narrow)
  show ?thesis
    apply(rule setsum_strict_mono_ex1[OF `finite X`]) using 1 2 by blast+
qed

lemma n_s_narrow: "finite X \<Longrightarrow> fun S1 = fun S2 on -X \<Longrightarrow> S2 \<le> S1 \<Longrightarrow> S1 \<triangle> S2 < S1
  \<Longrightarrow> n\<^isub>s (S1 \<triangle> S2) X < n\<^isub>s S1 X"
apply(auto simp add: less_st_def n_s_def)
apply (transfer fixing: n)
apply(auto simp add: less_eq_st_rep_iff eq_st_def fun_eq_iff n_s_narrow_rep)
done

definition n_o :: "'av st option \<Rightarrow> vname set \<Rightarrow> nat" ("n\<^isub>o") where
"n\<^isub>o opt X = (case opt of None \<Rightarrow> 0 | Some S \<Rightarrow> n\<^isub>s S X + 1)"

lemma n_o_narrow:
  "top_on_opt S1 (-X) \<Longrightarrow> top_on_opt S2 (-X) \<Longrightarrow> finite X
  \<Longrightarrow> S2 \<le> S1 \<Longrightarrow> S1 \<triangle> S2 < S1 \<Longrightarrow> n\<^isub>o (S1 \<triangle> S2) X < n\<^isub>o S1 X"
apply(induction S1 S2 rule: narrow_option.induct)
apply(auto simp: n_o_def n_s_narrow)
done


definition n_c :: "'av st option acom \<Rightarrow> nat" ("n\<^isub>c") where
"n\<^isub>c C = listsum (map (\<lambda>a. n\<^isub>o a (vars C)) (annos C))"

lemma less_annos_iff: "(C1 < C2) = (C1 \<le> C2 \<and>
  (\<exists>i<length (annos C1). annos C1 ! i < annos C2 ! i))"
by(metis (hide_lams, no_types) less_le_not_le le_iff_le_annos size_annos_same2)

lemma n_c_narrow: "strip C1 = strip C2
  \<Longrightarrow> top_on_acom C1 (- vars C1) \<Longrightarrow> top_on_acom C2 (- vars C2)
  \<Longrightarrow> C2 \<le> C1 \<Longrightarrow> C1 \<triangle> C2 < C1 \<Longrightarrow> n\<^isub>c (C1 \<triangle> C2) < n\<^isub>c C1"
apply(auto simp: n_c_def narrow_acom_def listsum_setsum_nth)
apply(subgoal_tac "length(annos C2) = length(annos C1)")
prefer 2 apply (simp add: size_annos_same2)
apply (auto)
apply(simp add: less_annos_iff le_iff_le_annos)
apply(rule setsum_strict_mono_ex1)
apply (auto simp: vars_acom_def top_on_acom_def)
apply (metis n_o_narrow nth_mem finite_cvars less_imp_le le_less order_refl)
apply(rule_tac x=i in bexI)
prefer 2 apply simp
apply(rule n_o_narrow[where X = "vars(strip C2)"])
apply (simp_all)
done

end


lemma iter_widen_termination:
fixes m :: "'a::WN acom \<Rightarrow> nat"
assumes P_f: "\<And>C. P C \<Longrightarrow> P(f C)"
and P_widen: "\<And>C1 C2. P C1 \<Longrightarrow> P C2 \<Longrightarrow> P(C1 \<nabla> C2)"
and m_widen: "\<And>C1 C2. P C1 \<Longrightarrow> P C2 \<Longrightarrow> ~ C2 \<le> C1 \<Longrightarrow> m(C1 \<nabla> C2) < m C1"
and "P C" shows "EX C'. iter_widen f C = Some C'"
proof(simp add: iter_widen_def,
      rule measure_while_option_Some[where P = P and f=m])
  show "P C" by(rule `P C`)
next
  fix C assume "P C" "\<not> f C \<le> C" thus "P (C \<nabla> f C) \<and> m (C \<nabla> f C) < m C"
    by(simp add: P_f P_widen m_widen)
qed

lemma iter_narrow_termination:
fixes n :: "'a::WN acom \<Rightarrow> nat"
assumes P_f: "\<And>C. P C \<Longrightarrow> P(f C)"
and P_narrow: "\<And>C1 C2. P C1 \<Longrightarrow> P C2 \<Longrightarrow> P(C1 \<triangle> C2)"
and mono: "\<And>C1 C2. P C1 \<Longrightarrow> P C2 \<Longrightarrow> C1 \<le> C2 \<Longrightarrow> f C1 \<le> f C2"
and n_narrow: "\<And>C1 C2. P C1 \<Longrightarrow> P C2 \<Longrightarrow> C2 \<le> C1 \<Longrightarrow> C1 \<triangle> C2 < C1 \<Longrightarrow> n(C1 \<triangle> C2) < n C1"
and init: "P C" "f C \<le> C" shows "EX C'. iter_narrow f C = Some C'"
proof(simp add: iter_narrow_def,
      rule measure_while_option_Some[where f=n and P = "%C. P C \<and> f C \<le> C"])
  show "P C \<and> f C \<le> C" using init by blast
next
  fix C assume 1: "P C \<and> f C \<le> C" and 2: "C \<triangle> f C < C"
  hence "P (C \<triangle> f C)" by(simp add: P_f P_narrow)
  moreover then have "f (C \<triangle> f C) \<le> C \<triangle> f C"
    by (metis narrow1_acom narrow2_acom 1 mono order_trans)
  moreover have "n (C \<triangle> f C) < n C" using 1 2 by(simp add: n_narrow P_f)
  ultimately show "(P (C \<triangle> f C) \<and> f (C \<triangle> f C) \<le> C \<triangle> f C) \<and> n(C \<triangle> f C) < n C"
    by blast
qed

locale Abs_Int2_measure = Abs_Int2 where \<gamma>=\<gamma> + Measure_WN where m=m
  for \<gamma> :: "'av::{WN,bounded_lattice} \<Rightarrow> val set" and m :: "'av \<Rightarrow> nat"


subsubsection "Termination: Intervals"

definition m_rep :: "eint2 \<Rightarrow> nat" where
"m_rep p = (if is_empty_rep p then 3 else
  let (l,h) = p in (case l of Minf \<Rightarrow> 0 | _ \<Rightarrow> 1) + (case h of Pinf \<Rightarrow> 0 | _ \<Rightarrow> 1))"

lift_definition m_ivl :: "ivl \<Rightarrow> nat" is m_rep
by(auto simp: m_rep_def eq_ivl_iff)

lemma m_ivl_nice: "m_ivl[l\<dots>h] = (if [l\<dots>h] = \<bottom> then 3 else
   (if l = Minf then 0 else 1) + (if h = Pinf then 0 else 1))"
unfolding bot_ivl_def
by transfer (auto simp: m_rep_def eq_ivl_empty split: extended.split)

lemma m_ivl_height: "m_ivl iv \<le> 3"
by transfer (simp add: m_rep_def split: prod.split extended.split)

lemma m_ivl_anti_mono: "y \<le> x \<Longrightarrow> m_ivl x \<le> m_ivl y"
by transfer
   (auto simp: m_rep_def is_empty_rep_def \<gamma>_rep_cases le_iff_subset
         split: prod.split extended.splits if_splits)

lemma m_ivl_widen:
  "~ y \<le> x \<Longrightarrow> m_ivl(x \<nabla> y) < m_ivl x"
by transfer
   (auto simp: m_rep_def widen_rep_def is_empty_rep_def \<gamma>_rep_cases le_iff_subset
         split: prod.split extended.splits if_splits)

definition n_ivl :: "ivl \<Rightarrow> nat" where
"n_ivl ivl = 3 - m_ivl ivl"

lemma n_ivl_narrow:
  "x \<triangle> y < x \<Longrightarrow> n_ivl(x \<triangle> y) < n_ivl x"
unfolding n_ivl_def
apply(subst (asm) less_le_not_le)
apply transfer
by(auto simp add: m_rep_def narrow_rep_def is_empty_rep_def empty_rep_def \<gamma>_rep_cases le_iff_subset
         split: prod.splits if_splits extended.split)


interpretation Abs_Int2_measure
where \<gamma> = \<gamma>_ivl and num' = num_ivl and plus' = "op +"
and test_num' = in_ivl
and constrain_plus' = constrain_plus_ivl and constrain_less' = constrain_less_ivl
and m = m_ivl and n = n_ivl and h = 3
proof
  case goal2 thus ?case by(rule m_ivl_anti_mono)
next
  case goal1 thus ?case by(rule m_ivl_height)
next
  case goal3 thus ?case by(rule m_ivl_widen)
next
  case goal4 from goal4(2) show ?case by(rule n_ivl_narrow)
  -- "note that the first assms is unnecessary for intervals"
qed

lemma iter_winden_step_ivl_termination:
  "\<exists>C. iter_widen (step_ivl \<top>) (bot c) = Some C"
apply(rule iter_widen_termination[where m = "m_c" and P = "%C. strip C = c \<and> top_on_acom C (- vars C)"])
apply (auto simp add: m_c_widen top_on_bot top_on_step'[simplified comp_def vars_acom_def]
  vars_acom_def top_on_acom_widen)
done

lemma iter_narrow_step_ivl_termination:
  "top_on_acom C0 (- vars C0) \<Longrightarrow> step_ivl \<top> C0 \<le> C0 \<Longrightarrow>
  \<exists>C. iter_narrow (step_ivl \<top>) C0 = Some C"
apply(rule iter_narrow_termination[where n = "n_c" and P = "%C. strip C0 = strip C \<and> top_on_acom C (-vars C)"])
apply(auto simp: top_on_step'[simplified comp_def vars_acom_def]
        mono_step'_top n_c_narrow vars_acom_def top_on_acom_narrow)
done

theorem AI_ivl'_termination:
  "\<exists>C. AI_ivl' c = Some C"
apply(auto simp: AI_wn_def pfp_wn_def iter_winden_step_ivl_termination
           split: option.split)
apply(rule iter_narrow_step_ivl_termination)
apply(rule conjunct2)
apply(rule iter_widen_inv[where f = "step' \<top>" and P = "%C. c = strip C & top_on_acom C (- vars C)"])
apply(auto simp: top_on_acom_widen top_on_step'[simplified comp_def vars_acom_def]
  iter_widen_pfp top_on_bot vars_acom_def)
done

(*unused_thms Abs_Int_init - *)

subsubsection "Counterexamples"

text{* Widening is increasing by assumption, but @{prop"x \<le> f x"} is not an invariant of widening.
It can already be lost after the first step: *}

lemma assumes "!!x y::'a::WN. x \<le> y \<Longrightarrow> f x \<le> f y"
and "x \<le> f x" and "\<not> f x \<le> x" shows "x \<nabla> f x \<le> f(x \<nabla> f x)"
nitpick[card = 3, expect = genuine, show_consts]
(*
1 < 2 < 3,
f x = 2,
x widen y = 3 -- guarantees termination with top=3
x = 1
Now f is mono, x <= f x, not f x <= x
but x widen f x = 3, f 3 = 2, but not 3 <= 2
*)
oops

text{* Widening terminates but may converge more slowly than Kleene iteration.
In the following model, Kleene iteration goes from 0 to the least pfp
in one step but widening takes 2 steps to reach a strictly larger pfp: *}
lemma assumes "!!x y::'a::WN. x \<le> y \<Longrightarrow> f x \<le> f y"
and "x \<le> f x" and "\<not> f x \<le> x" and "f(f x) \<le> f x"
shows "f(x \<nabla> f x) \<le> x \<nabla> f x"
nitpick[card = 4, expect = genuine, show_consts]
(*

   0 < 1 < 2 < 3
f: 1   1   3   3

0 widen 1 = 2
2 widen 3 = 3
and x widen y arbitrary, eg 3, which guarantees termination

Kleene: f(f 0) = f 1 = 1 <= 1 = f 1

but

because not f 0 <= 0, we obtain 0 widen f 0 = 0 wide 1 = 2,
which is again not a pfp: not f 2 = 3 <= 2
Another widening step yields 2 widen f 2 = 2 widen 3 = 3
*)
oops

end
