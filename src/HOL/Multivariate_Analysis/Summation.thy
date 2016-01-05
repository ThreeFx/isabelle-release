(*  Title:    HOL/Multivariate_Analysis/Summation.thy
    Author:   Manuel Eberl, TU München
*)
  
section \<open>Rounded dual logarithm\<close>

theory Summation
imports
  Complex_Main
  "~~/src/HOL/Library/Extended_Real" 
  "~~/src/HOL/Library/Liminf_Limsup"
begin

text \<open>
  The definition of the radius of convergence of a power series, 
  various summability tests, lemmas to compute the radius of convergence etc.
\<close>

(* This is required for the Cauchy condensation criterion *)

definition "natlog2 n = (if n = 0 then 0 else nat \<lfloor>log 2 (real_of_nat n)\<rfloor>)"

lemma natlog2_0 [simp]: "natlog2 0 = 0" by (simp add: natlog2_def)
lemma natlog2_1 [simp]: "natlog2 1 = 0" by (simp add: natlog2_def)
lemma natlog2_eq_0_iff: "natlog2 n = 0 \<longleftrightarrow> n < 2" by (simp add: natlog2_def)

lemma natlog2_power_of_two [simp]: "natlog2 (2 ^ n) = n"
  by (simp add: natlog2_def log_nat_power)

lemma natlog2_mono: "m \<le> n \<Longrightarrow> natlog2 m \<le> natlog2 n"
  unfolding natlog2_def by (simp_all add: nat_mono floor_mono)

lemma pow_natlog2_le: "n > 0 \<Longrightarrow> 2 ^ natlog2 n \<le> n"
proof -
  assume n: "n > 0"
  from n have "of_nat (2 ^ natlog2 n) = 2 powr real_of_nat (nat \<lfloor>log 2 (real_of_nat n)\<rfloor>)"
    by (subst powr_realpow) (simp_all add: natlog2_def)
  also have "\<dots> = 2 powr of_int \<lfloor>log 2 (real_of_nat n)\<rfloor>" using n by simp
  also have "\<dots> \<le> 2 powr log 2 (real_of_nat n)" by (intro powr_mono) (linarith, simp_all)
  also have "\<dots> = of_nat n" using n by simp
  finally show ?thesis by simp
qed

lemma pow_natlog2_gt: "n > 0 \<Longrightarrow> 2 * 2 ^ natlog2 n > n"
  and pow_natlog2_ge: "n > 0 \<Longrightarrow> 2 * 2 ^ natlog2 n \<ge> n"
proof -
  assume n: "n > 0"
  from n have "of_nat n = 2 powr log 2 (real_of_nat n)" by simp
  also have "\<dots> < 2 powr (1 + of_int \<lfloor>log 2 (real_of_nat n)\<rfloor>)" 
    by (intro powr_less_mono) (linarith, simp_all)
  also from n have "\<dots> = 2 powr (1 + real_of_nat (nat \<lfloor>log 2 (real_of_nat n)\<rfloor>))" by simp
  also from n have "\<dots> = of_nat (2 * 2 ^ natlog2 n)"
    by (simp_all add: natlog2_def powr_real_of_int powr_add)
  finally show "2 * 2 ^ natlog2 n > n" by (rule of_nat_less_imp_less)
  thus "2 * 2 ^ natlog2 n \<ge> n" by simp
qed

lemma natlog2_eqI:
  assumes "n > 0" "2^k \<le> n" "n < 2 * 2^k"
  shows   "natlog2 n = k"
proof -
  from assms have "of_nat (2 ^ k) \<le> real_of_nat n"  by (subst of_nat_le_iff) simp_all
  hence "real_of_int (int k) \<le> log (of_nat 2) (real_of_nat n)"
    by (subst le_log_iff) (simp_all add: powr_realpow assms del: of_nat_le_iff)
  moreover from assms have "real_of_nat n < of_nat (2 ^ Suc k)" by (subst of_nat_less_iff) simp_all
  hence "log 2 (real_of_nat n) < of_nat k + 1"
    by (subst log_less_iff) (simp_all add: assms powr_realpow powr_add)
  ultimately have "\<lfloor>log 2 (real_of_nat n)\<rfloor> = of_nat k" by (intro floor_unique) simp_all
  with assms show ?thesis by (simp add: natlog2_def)
qed

lemma natlog2_rec: 
  assumes "n \<ge> 2"
  shows   "natlog2 n = 1 + natlog2 (n div 2)"
proof (rule natlog2_eqI)
  from assms have "2 ^ (1 + natlog2 (n div 2)) \<le> 2 * (n div 2)" 
    by (simp add: pow_natlog2_le)
  also have "\<dots> \<le> n" by simp
  finally show "2 ^ (1 + natlog2 (n div 2)) \<le> n" .
next
  from assms have "n < 2 * (n div 2 + 1)" by simp 
  also from assms have "(n div 2) < 2 ^ (1 + natlog2 (n div 2))" 
    by (simp add: pow_natlog2_gt)
  hence "2 * (n div 2 + 1) \<le> 2 * (2 ^ (1 + natlog2 (n div 2)))" 
    by (intro mult_left_mono) simp_all
  finally show "n < 2 * 2 ^ (1 + natlog2 (n div 2))" .
qed (insert assms, simp_all)

fun natlog2_aux where
  "natlog2_aux n acc = (if (n::nat) < 2 then acc else natlog2_aux (n div 2) (acc + 1))"

lemma natlog2_aux_correct:
  "natlog2_aux n acc = acc + natlog2 n"
  by (induction n acc rule: natlog2_aux.induct) (auto simp: natlog2_rec natlog2_eq_0_iff)
  
lemma natlog2_code [code]: "natlog2 n = natlog2_aux n 0"
  by (subst natlog2_aux_correct) simp


subsection \<open>Convergence tests for infinite sums\<close>

subsubsection \<open>Root test\<close>

lemma limsup_root_powser:
  fixes f :: "nat \<Rightarrow> 'a :: {banach, real_normed_div_algebra}"
  shows "limsup (\<lambda>n. ereal (root n (norm (f n * z ^ n)))) = 
             limsup (\<lambda>n. ereal (root n (norm (f n)))) * ereal (norm z)"
proof -
  have A: "(\<lambda>n. ereal (root n (norm (f n * z ^ n)))) = 
              (\<lambda>n. ereal (root n (norm (f n))) * ereal (norm z))" (is "?g = ?h")
  proof
    fix n show "?g n = ?h n"
    by (cases "n = 0") (simp_all add: norm_mult real_root_mult real_root_pos2 norm_power)
  qed
  show ?thesis by (subst A, subst limsup_ereal_mult_right) simp_all
qed

lemma limsup_root_limit:
  assumes "(\<lambda>n. ereal (root n (norm (f n)))) \<longlonglongrightarrow> l" (is "?g \<longlonglongrightarrow> _")
  shows   "limsup (\<lambda>n. ereal (root n (norm (f n)))) = l"
proof -
  from assms have "convergent ?g" "lim ?g = l"
    unfolding convergent_def by (blast intro: limI)+
  with convergent_limsup_cl show ?thesis by force
qed

lemma limsup_root_limit':
  assumes "(\<lambda>n. root n (norm (f n))) \<longlonglongrightarrow> l"
  shows   "limsup (\<lambda>n. ereal (root n (norm (f n)))) = ereal l"
  by (intro limsup_root_limit tendsto_ereal assms)

lemma root_test_convergence':
  fixes f :: "nat \<Rightarrow> 'a :: banach"
  defines "l \<equiv> limsup (\<lambda>n. ereal (root n (norm (f n))))"
  assumes l: "l < 1"
  shows   "summable f"
proof -
  have "0 = limsup (\<lambda>n. 0)" by (simp add: Limsup_const)
  also have "... \<le> l" unfolding l_def by (intro Limsup_mono) (simp_all add: real_root_ge_zero)
  finally have "l \<ge> 0" by simp
  with l obtain l' where l': "l = ereal l'" by (cases l) simp_all

  def c \<equiv> "(1 - l') / 2"
  from l and `l \<ge> 0` have c: "l + c > l" "l' + c \<ge> 0" "l' + c < 1" unfolding c_def 
    by (simp_all add: field_simps l')
  have "\<forall>C>l. eventually (\<lambda>n. ereal (root n (norm (f n))) < C) sequentially"
    by (subst Limsup_le_iff[symmetric]) (simp add: l_def)
  with c have "eventually (\<lambda>n. ereal (root n (norm (f n))) < l + ereal c) sequentially" by simp
  with eventually_gt_at_top[of "0::nat"]
    have "eventually (\<lambda>n. norm (f n) \<le> (l' + c) ^ n) sequentially"
  proof eventually_elim
    fix n :: nat assume n: "n > 0" 
    assume "ereal (root n (norm (f n))) < l + ereal c"
    hence "root n (norm (f n)) \<le> l' + c" by (simp add: l')
    with c n have "root n (norm (f n)) ^ n \<le> (l' + c) ^ n"
      by (intro power_mono) (simp_all add: real_root_ge_zero)
    also from n have "root n (norm (f n)) ^ n = norm (f n)" by simp
    finally show "norm (f n) \<le> (l' + c) ^ n" by simp
  qed
  thus ?thesis
    by (rule summable_comparison_test_ev[OF _ summable_geometric]) (simp add: c)
qed

lemma root_test_divergence:
  fixes f :: "nat \<Rightarrow> 'a :: banach"
  defines "l \<equiv> limsup (\<lambda>n. ereal (root n (norm (f n))))"
  assumes l: "l > 1"
  shows   "\<not>summable f"
proof
  assume "summable f"
  hence bounded: "Bseq f" by (simp add: summable_imp_Bseq)

  have "0 = limsup (\<lambda>n. 0)" by (simp add: Limsup_const)
  also have "... \<le> l" unfolding l_def by (intro Limsup_mono) (simp_all add: real_root_ge_zero)
  finally have l_nonneg: "l \<ge> 0" by simp

  def c \<equiv> "if l = \<infinity> then 2 else 1 + (real_of_ereal l - 1) / 2"
  from l l_nonneg consider "l = \<infinity>" | "\<exists>l'. l = ereal l'" by (cases l) simp_all
  hence c: "c > 1 \<and> ereal c < l" by cases (insert l, auto simp: c_def field_simps)

  have unbounded: "\<not>bdd_above {n. root n (norm (f n)) > c}"
  proof
    assume "bdd_above {n. root n (norm (f n)) > c}"
    then obtain N where "\<forall>n. root n (norm (f n)) > c \<longrightarrow> n \<le> N" unfolding bdd_above_def by blast
    hence "\<exists>N. \<forall>n\<ge>N. root n (norm (f n)) \<le> c"
      by (intro exI[of _ "N + 1"]) (force simp: not_less_eq_eq[symmetric])
    hence "eventually (\<lambda>n. root n (norm (f n)) \<le> c) sequentially"
      by (auto simp: eventually_at_top_linorder)
    hence "l \<le> c" unfolding l_def by (intro Limsup_bounded) simp_all
    with c show False by auto
  qed
  
  from bounded obtain K where K: "K > 0" "\<And>n. norm (f n) \<le> K" using BseqE by blast
  def n \<equiv> "nat \<lceil>log c K\<rceil>"
  from unbounded have "\<exists>m>n. c < root m (norm (f m))" unfolding bdd_above_def
    by (auto simp: not_le)
  then guess m by (elim exE conjE) note m = this
  from c K have "K = c powr log c K" by (simp add: powr_def log_def)
  also from c have "c powr log c K \<le> c powr real n" unfolding n_def
    by (intro powr_mono, linarith, simp)
  finally have "K \<le> c ^ n" using c by (simp add: powr_realpow)
  also from c m have "c ^ n < c ^ m" by simp
  also from c m have "c ^ m < root m (norm (f m)) ^ m" by (intro power_strict_mono) simp_all
  also from m have "... = norm (f m)" by simp
  finally show False using K(2)[of m]  by simp
qed


subsection \<open>Cauchy's condensation test\<close>

context
fixes f :: "nat \<Rightarrow> real"
begin

private lemma condensation_inequality:
  assumes mono: "\<And>m n. 0 < m \<Longrightarrow> m \<le> n \<Longrightarrow> f n \<le> f m"
  shows   "(\<Sum>k=1..<n. f k) \<ge> (\<Sum>k=1..<n. f (2 * 2 ^ natlog2 k))" (is "?thesis1")
          "(\<Sum>k=1..<n. f k) \<le> (\<Sum>k=1..<n. f (2 ^ natlog2 k))" (is "?thesis2")
  by (intro setsum_mono mono pow_natlog2_ge pow_natlog2_le, simp, simp)+

private lemma condensation_condense1: "(\<Sum>k=1..<2^n. f (2 ^ natlog2 k)) = (\<Sum>k<n. 2^k * f (2 ^ k))"
proof (induction n)
  case (Suc n)
  have "{1..<2^Suc n} = {1..<2^n} \<union> {2^n..<(2^Suc n :: nat)}" by auto  
  also have "(\<Sum>k\<in>\<dots>. f (2 ^ natlog2 k)) = 
                 (\<Sum>k<n. 2^k * f (2^k)) + (\<Sum>k = 2^n..<2^Suc n. f (2^natlog2 k))" 
    by (subst setsum.union_disjoint) (insert Suc, auto)
  also have "natlog2 k = n" if "k \<in> {2^n..<2^Suc n}" for k using that by (intro natlog2_eqI) simp_all
  hence "(\<Sum>k = 2^n..<2^Suc n. f (2^natlog2 k)) = (\<Sum>(_::nat) = 2^n..<2^Suc n. f (2^n))"
    by (intro setsum.cong) simp_all
  also have "\<dots> = 2^n * f (2^n)" by (simp add: of_nat_power)
  finally show ?case by simp
qed simp

private lemma condensation_condense2: "(\<Sum>k=1..<2^n. f (2 * 2 ^ natlog2 k)) = (\<Sum>k<n. 2^k * f (2 ^ Suc k))"
proof (induction n)
  case (Suc n)
  have "{1..<2^Suc n} = {1..<2^n} \<union> {2^n..<(2^Suc n :: nat)}" by auto  
  also have "(\<Sum>k\<in>\<dots>. f (2 * 2 ^ natlog2 k)) = 
                 (\<Sum>k<n. 2^k * f (2^Suc k)) + (\<Sum>k = 2^n..<2^Suc n. f (2 * 2^natlog2 k))" 
    by (subst setsum.union_disjoint) (insert Suc, auto)
  also have "natlog2 k = n" if "k \<in> {2^n..<2^Suc n}" for k using that by (intro natlog2_eqI) simp_all
  hence "(\<Sum>k = 2^n..<2^Suc n. f (2*2^natlog2 k)) = (\<Sum>(_::nat) = 2^n..<2^Suc n. f (2^Suc n))"
    by (intro setsum.cong) simp_all
  also have "\<dots> = 2^n * f (2^Suc n)" by (simp add: of_nat_power)
  finally show ?case by simp
qed simp

lemma condensation_test:
  assumes mono: "\<And>m. 0 < m \<Longrightarrow> f (Suc m) \<le> f m"
  assumes nonneg: "\<And>n. f n \<ge> 0"
  shows "summable f \<longleftrightarrow> summable (\<lambda>n. 2^n * f (2^n))"
proof -
  def f' \<equiv> "\<lambda>n. if n = 0 then 0 else f n"
  from mono have mono': "decseq (\<lambda>n. f (Suc n))" by (intro decseq_SucI) simp
  hence mono': "f n \<le> f m" if "m \<le> n" "m > 0" for m n 
    using that decseqD[OF mono', of "m - 1" "n - 1"] by simp
  
  have "(\<lambda>n. f (Suc n)) = (\<lambda>n. f' (Suc n))" by (intro ext) (simp add: f'_def)
  hence "summable f \<longleftrightarrow> summable f'"
    by (subst (1 2) summable_Suc_iff [symmetric]) (simp only:)
  also have "\<dots> \<longleftrightarrow> convergent (\<lambda>n. \<Sum>k<n. f' k)" unfolding summable_iff_convergent ..
  also have "monoseq (\<lambda>n. \<Sum>k<n. f' k)" unfolding f'_def
    by (intro mono_SucI1) (auto intro!: mult_nonneg_nonneg nonneg)
  hence "convergent (\<lambda>n. \<Sum>k<n. f' k) \<longleftrightarrow> Bseq (\<lambda>n. \<Sum>k<n. f' k)"
    by (rule monoseq_imp_convergent_iff_Bseq)
  also have "\<dots> \<longleftrightarrow> Bseq (\<lambda>n. \<Sum>k=1..<n. f' k)" unfolding One_nat_def
    by (subst setsum_shift_lb_Suc0_0_upt) (simp_all add: f'_def atLeast0LessThan)
  also have "\<dots> \<longleftrightarrow> Bseq (\<lambda>n. \<Sum>k=1..<n. f k)" unfolding f'_def by simp
  also have "\<dots> \<longleftrightarrow> Bseq (\<lambda>n. \<Sum>k=1..<2^n. f k)"
    by (rule nonneg_incseq_Bseq_subseq_iff[symmetric])
       (auto intro!: setsum_nonneg incseq_SucI nonneg simp: subseq_def)
  also have "\<dots> \<longleftrightarrow> Bseq (\<lambda>n. \<Sum>k<n. 2^k * f (2^k))"
  proof (intro iffI)
    assume A: "Bseq (\<lambda>n. \<Sum>k=1..<2^n. f k)"
    have "eventually (\<lambda>n. norm (\<Sum>k<n. 2^k * f (2^Suc k)) \<le> norm (\<Sum>k=1..<2^n. f k)) sequentially"
    proof (intro always_eventually allI)
      fix n :: nat
      have "norm (\<Sum>k<n. 2^k * f (2^Suc k)) = (\<Sum>k<n. 2^k * f (2^Suc k))" unfolding real_norm_def
        by (intro abs_of_nonneg setsum_nonneg ballI mult_nonneg_nonneg nonneg) simp_all
      also have "\<dots> \<le> (\<Sum>k=1..<2^n. f k)"
        by (subst condensation_condense2 [symmetric]) (intro condensation_inequality mono')
      also have "\<dots> = norm \<dots>" unfolding real_norm_def
        by (intro abs_of_nonneg[symmetric] setsum_nonneg ballI mult_nonneg_nonneg nonneg)
      finally show "norm (\<Sum>k<n. 2 ^ k * f (2 ^ Suc k)) \<le> norm (\<Sum>k=1..<2^n. f k)" .
    qed
    from this and A have "Bseq (\<lambda>n. \<Sum>k<n. 2^k * f (2^Suc k))" by (rule Bseq_eventually_mono)
    from Bseq_mult[OF Bfun_const[of 2] this] have "Bseq (\<lambda>n. \<Sum>k<n. 2^Suc k * f (2^Suc k))"
      by (simp add: setsum_right_distrib setsum_left_distrib mult_ac)
    hence "Bseq (\<lambda>n. (\<Sum>k=Suc 0..<Suc n. 2^k * f (2^k)) + f 1)"
      by (intro Bseq_add, subst setsum_shift_bounds_Suc_ivl) (simp add: atLeast0LessThan)
    hence "Bseq (\<lambda>n. (\<Sum>k=0..<Suc n. 2^k * f (2^k)))"
      by (subst setsum_head_upt_Suc) (simp_all add: add_ac)
    thus "Bseq (\<lambda>n. (\<Sum>k<n. 2^k * f (2^k)))" 
      by (subst (asm) Bseq_Suc_iff) (simp add: atLeast0LessThan)
  next
    assume A: "Bseq (\<lambda>n. (\<Sum>k<n. 2^k * f (2^k)))"
    have "eventually (\<lambda>n. norm (\<Sum>k=1..<2^n. f k) \<le> norm (\<Sum>k<n. 2^k * f (2^k))) sequentially"
    proof (intro always_eventually allI)
      fix n :: nat
      have "norm (\<Sum>k=1..<2^n. f k) = (\<Sum>k=1..<2^n. f k)" unfolding real_norm_def
        by (intro abs_of_nonneg setsum_nonneg ballI mult_nonneg_nonneg nonneg)
      also have "\<dots> \<le> (\<Sum>k<n. 2^k * f (2^k))"
        by (subst condensation_condense1 [symmetric]) (intro condensation_inequality mono')
      also have "\<dots> = norm \<dots>" unfolding real_norm_def
        by (intro abs_of_nonneg [symmetric] setsum_nonneg ballI mult_nonneg_nonneg nonneg) simp_all
      finally show "norm (\<Sum>k=1..<2^n. f k) \<le> norm (\<Sum>k<n. 2^k * f (2^k))" .
    qed
    from this and A show "Bseq (\<lambda>n. \<Sum>k=1..<2^n. f k)" by (rule Bseq_eventually_mono)
  qed
  also have "monoseq (\<lambda>n. (\<Sum>k<n. 2^k * f (2^k)))"
    by (intro mono_SucI1) (auto intro!: mult_nonneg_nonneg nonneg)
  hence "Bseq (\<lambda>n. (\<Sum>k<n. 2^k * f (2^k))) \<longleftrightarrow> convergent (\<lambda>n. (\<Sum>k<n. 2^k * f (2^k)))"
    by (rule monoseq_imp_convergent_iff_Bseq [symmetric])
  also have "\<dots> \<longleftrightarrow> summable (\<lambda>k. 2^k * f (2^k))" by (simp only: summable_iff_convergent)
  finally show ?thesis .
qed

end


subsection \<open>Summability of powers\<close>

lemma abs_summable_complex_powr_iff: 
    "summable (\<lambda>n. norm (exp (of_real (ln (of_nat n)) * s))) \<longleftrightarrow> Re s < -1"
proof (cases "Re s \<le> 0")
  let ?l = "\<lambda>n. complex_of_real (ln (of_nat n))"
  case False
  with eventually_gt_at_top[of "0::nat"]
    have "eventually (\<lambda>n. norm (1 :: real) \<le> norm (exp (?l n * s))) sequentially" 
    by (auto intro!: ge_one_powr_ge_zero elim!: eventually_mono)
  from summable_comparison_test_ev[OF this] False show ?thesis by (auto simp: summable_const_iff)
next
  let ?l = "\<lambda>n. complex_of_real (ln (of_nat n))"
  case True
  hence "summable (\<lambda>n. norm (exp (?l n * s))) \<longleftrightarrow> summable (\<lambda>n. 2^n * norm (exp (?l (2^n) * s)))"
    by (intro condensation_test) (auto intro!: mult_right_mono_neg)
  also have "(\<lambda>n. 2^n * norm (exp (?l (2^n) * s))) = (\<lambda>n. (2 powr (Re s + 1)) ^ n)"
  proof
    fix n :: nat
    have "2^n * norm (exp (?l (2^n) * s)) = exp (real n * ln 2) * exp (real n * ln 2 * Re s)"
      using True by (subst exp_of_nat_mult) (simp add: ln_realpow algebra_simps) 
    also have "\<dots> = exp (real n * (ln 2 * (Re s + 1)))"
      by (simp add: algebra_simps exp_add)
    also have "\<dots> = exp (ln 2 * (Re s + 1)) ^ n" by (subst exp_of_nat_mult) simp
    also have "exp (ln 2 * (Re s + 1)) = 2 powr (Re s + 1)" by (simp add: powr_def)
    finally show "2^n * norm (exp (?l (2^n) * s)) = (2 powr (Re s + 1)) ^ n" .
  qed
  also have "summable \<dots> \<longleftrightarrow> 2 powr (Re s + 1) < 2 powr 0"
    by (subst summable_geometric_iff) simp
  also have "\<dots> \<longleftrightarrow> Re s < -1" by (subst powr_less_cancel_iff) (simp, linarith)
  finally show ?thesis .
qed

lemma summable_complex_powr_iff: 
  assumes "Re s < -1"
  shows   "summable (\<lambda>n. exp (of_real (ln (of_nat n)) * s))"
  by (rule summable_norm_cancel, subst abs_summable_complex_powr_iff) fact

lemma summable_real_powr_iff: "summable (\<lambda>n. of_nat n powr s :: real) \<longleftrightarrow> s < -1"
proof -
  from eventually_gt_at_top[of "0::nat"]
    have "summable (\<lambda>n. of_nat n powr s) \<longleftrightarrow> summable (\<lambda>n. exp (ln (of_nat n) * s))"
    by (intro summable_cong) (auto elim!: eventually_mono simp: powr_def)
  also have "\<dots> \<longleftrightarrow> s < -1" using abs_summable_complex_powr_iff[of "of_real s"] by simp
  finally show ?thesis .
qed

lemma inverse_power_summable:
  assumes s: "s \<ge> 2"
  shows "summable (\<lambda>n. inverse (of_nat n ^ s :: 'a :: {real_normed_div_algebra,banach}))"
proof (rule summable_norm_cancel, subst summable_cong)
  from eventually_gt_at_top[of "0::nat"]
    show "eventually (\<lambda>n. norm (inverse (of_nat n ^ s:: 'a)) = real_of_nat n powr (-real s)) at_top"
    by eventually_elim (simp add: norm_inverse norm_power powr_minus powr_realpow)
qed (insert s summable_real_powr_iff[of "-s"], simp_all)

lemma not_summable_harmonic: "\<not>summable (\<lambda>n. inverse (of_nat n) :: 'a :: real_normed_field)"
proof
  assume "summable (\<lambda>n. inverse (of_nat n) :: 'a)"
  hence "convergent (\<lambda>n. norm (of_real (\<Sum>k<n. inverse (of_nat k)) :: 'a))" 
    by (simp add: summable_iff_convergent convergent_norm)
  hence "convergent (\<lambda>n. abs (\<Sum>k<n. inverse (of_nat k)) :: real)" by (simp only: norm_of_real)
  also have "(\<lambda>n. abs (\<Sum>k<n. inverse (of_nat k)) :: real) = (\<lambda>n. \<Sum>k<n. inverse (of_nat k))"
    by (intro ext abs_of_nonneg setsum_nonneg) auto
  also have "convergent \<dots> \<longleftrightarrow> summable (\<lambda>k. inverse (of_nat k) :: real)"
    by (simp add: summable_iff_convergent)
  finally show False using summable_real_powr_iff[of "-1"] by (simp add: powr_minus)
qed


subsection \<open>Kummer's test\<close>

lemma kummers_test_convergence:
  fixes f p :: "nat \<Rightarrow> real"
  assumes pos_f: "eventually (\<lambda>n. f n > 0) sequentially" 
  assumes nonneg_p: "eventually (\<lambda>n. p n \<ge> 0) sequentially"
  defines "l \<equiv> liminf (\<lambda>n. ereal (p n * f n / f (Suc n) - p (Suc n)))"
  assumes l: "l > 0"
  shows   "summable f"
  unfolding summable_iff_convergent'
proof -
  def r \<equiv> "(if l = \<infinity> then 1 else real_of_ereal l / 2)"
  from l have "r > 0 \<and> of_real r < l" by (cases l) (simp_all add: r_def)
  hence r: "r > 0" "of_real r < l" by simp_all
  hence "eventually (\<lambda>n. p n * f n / f (Suc n) - p (Suc n) > r) sequentially"
    unfolding l_def by (force dest: less_LiminfD)
  moreover from pos_f have "eventually (\<lambda>n. f (Suc n) > 0) sequentially" 
    by (subst eventually_sequentially_Suc)
  ultimately have "eventually (\<lambda>n. p n * f n - p (Suc n) * f (Suc n) > r * f (Suc n)) sequentially"
    by eventually_elim (simp add: field_simps)
  from eventually_conj[OF pos_f eventually_conj[OF nonneg_p this]]
    obtain m where m: "\<And>n. n \<ge> m \<Longrightarrow> f n > 0" "\<And>n. n \<ge> m \<Longrightarrow> p n \<ge> 0"
        "\<And>n. n \<ge> m \<Longrightarrow> p n * f n - p (Suc n) * f (Suc n) > r * f (Suc n)"
    unfolding eventually_at_top_linorder by blast

  let ?c = "(norm (\<Sum>k\<le>m. r * f k) + p m * f m) / r"
  have "Bseq (\<lambda>n. (\<Sum>k\<le>n + Suc m. f k))"
  proof (rule BseqI')
    fix k :: nat
    def n \<equiv> "k + Suc m"
    have n: "n > m" by (simp add: n_def)

    from r have "r * norm (\<Sum>k\<le>n. f k) = norm (\<Sum>k\<le>n. r * f k)"
      by (simp add: setsum_right_distrib[symmetric] abs_mult)
    also from n have "{..n} = {..m} \<union> {Suc m..n}" by auto
    hence "(\<Sum>k\<le>n. r * f k) = (\<Sum>k\<in>{..m} \<union> {Suc m..n}. r * f k)" by (simp only:)
    also have "\<dots> = (\<Sum>k\<le>m. r * f k) + (\<Sum>k=Suc m..n. r * f k)"
      by (subst setsum.union_disjoint) auto
    also have "norm \<dots> \<le> norm (\<Sum>k\<le>m. r * f k) + norm (\<Sum>k=Suc m..n. r * f k)"
      by (rule norm_triangle_ineq)
    also from r less_imp_le[OF m(1)] have "(\<Sum>k=Suc m..n. r * f k) \<ge> 0" 
      by (intro setsum_nonneg) auto
    hence "norm (\<Sum>k=Suc m..n. r * f k) = (\<Sum>k=Suc m..n. r * f k)" by simp
    also have "(\<Sum>k=Suc m..n. r * f k) = (\<Sum>k=m..<n. r * f (Suc k))"
     by (subst setsum_shift_bounds_Suc_ivl [symmetric])
          (simp only: atLeastLessThanSuc_atLeastAtMost)
    also from m have "\<dots> \<le> (\<Sum>k=m..<n. p k * f k - p (Suc k) * f (Suc k))"
      by (intro setsum_mono[OF less_imp_le]) simp_all
    also have "\<dots> = -(\<Sum>k=m..<n. p (Suc k) * f (Suc k) - p k * f k)"
      by (simp add: setsum_negf [symmetric] algebra_simps)
    also from n have "\<dots> = p m * f m - p n * f n"
      by (cases n, simp, simp only: atLeastLessThanSuc_atLeastAtMost, subst setsum_Suc_diff) simp_all
    also from less_imp_le[OF m(1)] m(2) n have "\<dots> \<le> p m * f m" by simp
    finally show "norm (\<Sum>k\<le>n. f k) \<le> (norm (\<Sum>k\<le>m. r * f k) + p m * f m) / r" using r
      by (subst pos_le_divide_eq[OF r(1)]) (simp only: mult_ac)
  qed
  moreover have "(\<Sum>k\<le>n. f k) \<le> (\<Sum>k\<le>n'. f k)" if "Suc m \<le> n" "n \<le> n'" for n n'
    using less_imp_le[OF m(1)] that by (intro setsum_mono2) auto
  ultimately show "convergent (\<lambda>n. \<Sum>k\<le>n. f k)" by (rule Bseq_monoseq_convergent'_inc)
qed


lemma kummers_test_divergence:
  fixes f p :: "nat \<Rightarrow> real"
  assumes pos_f: "eventually (\<lambda>n. f n > 0) sequentially" 
  assumes pos_p: "eventually (\<lambda>n. p n > 0) sequentially"
  assumes divergent_p: "\<not>summable (\<lambda>n. inverse (p n))"
  defines "l \<equiv> limsup (\<lambda>n. ereal (p n * f n / f (Suc n) - p (Suc n)))"
  assumes l: "l < 0"
  shows   "\<not>summable f"
proof
  assume "summable f"
  from eventually_conj[OF pos_f eventually_conj[OF pos_p Limsup_lessD[OF l[unfolded l_def]]]]
    obtain N where N: "\<And>n. n \<ge> N \<Longrightarrow> p n > 0" "\<And>n. n \<ge> N \<Longrightarrow> f n > 0"
                      "\<And>n. n \<ge> N \<Longrightarrow> p n * f n / f (Suc n) - p (Suc n) < 0"
    by (auto simp: eventually_at_top_linorder)
  hence A: "p n * f n < p (Suc n) * f (Suc n)" if "n \<ge> N" for n using that N[of n] N[of "Suc n"] 
    by (simp add: field_simps)
  have "p n * f n \<ge> p N * f N" if "n \<ge> N" for n using that and A
      by (induction n rule: dec_induct) (auto intro!: less_imp_le elim!: order.trans)
  from eventually_ge_at_top[of N] N this
    have "eventually (\<lambda>n. norm (p N * f N * inverse (p n)) \<le> f n) sequentially"
    by (auto elim!: eventually_mono simp: field_simps abs_of_pos)
  from this and \<open>summable f\<close> have "summable (\<lambda>n. p N * f N * inverse (p n))"
    by (rule summable_comparison_test_ev)
  from summable_mult[OF this, of "inverse (p N * f N)"] N[OF le_refl] 
    have "summable (\<lambda>n. inverse (p n))" by (simp add: divide_simps)
  with divergent_p show False by contradiction
qed


subsection \<open>Ratio test\<close>

lemma ratio_test_convergence:
  fixes f :: "nat \<Rightarrow> real"
  assumes pos_f: "eventually (\<lambda>n. f n > 0) sequentially" 
  defines "l \<equiv> liminf (\<lambda>n. ereal (f n / f (Suc n)))"
  assumes l: "l > 1"
  shows   "summable f"
proof (rule kummers_test_convergence[OF pos_f])
  note l
  also have "l = liminf (\<lambda>n. ereal (f n / f (Suc n) - 1)) + 1" 
    by (subst Liminf_add_ereal_right[symmetric]) (simp_all add: minus_ereal_def l_def one_ereal_def)
  finally show "liminf (\<lambda>n. ereal (1 * f n / f (Suc n) - 1)) > 0"
    by (cases "liminf (\<lambda>n. ereal (1 * f n / f (Suc n) - 1))") simp_all
qed simp

lemma ratio_test_divergence:
  fixes f :: "nat \<Rightarrow> real"
  assumes pos_f: "eventually (\<lambda>n. f n > 0) sequentially" 
  defines "l \<equiv> limsup (\<lambda>n. ereal (f n / f (Suc n)))"
  assumes l: "l < 1"
  shows   "\<not>summable f"
proof (rule kummers_test_divergence[OF pos_f])
  have "limsup (\<lambda>n. ereal (f n / f (Suc n) - 1)) + 1 = l" 
    by (subst Limsup_add_ereal_right[symmetric]) (simp_all add: minus_ereal_def l_def one_ereal_def)
  also note l
  finally show "limsup (\<lambda>n. ereal (1 * f n / f (Suc n) - 1)) < 0"
    by (cases "limsup (\<lambda>n. ereal (1 * f n / f (Suc n) - 1))") simp_all
qed (simp_all add: summable_const_iff)


subsection \<open>Raabe's test\<close>

lemma raabes_test_convergence:
fixes f :: "nat \<Rightarrow> real"
  assumes pos: "eventually (\<lambda>n. f n > 0) sequentially"
  defines "l \<equiv> liminf (\<lambda>n. ereal (of_nat n * (f n / f (Suc n) - 1)))"
  assumes l: "l > 1"
  shows   "summable f"
proof (rule kummers_test_convergence)
  let ?l' = "liminf (\<lambda>n. ereal (of_nat n * f n / f (Suc n) - of_nat (Suc n)))"
  have "1 < l" by fact
  also have "l = liminf (\<lambda>n. ereal (of_nat n * f n / f (Suc n) - of_nat (Suc n)) + 1)"
    by (simp add: l_def algebra_simps)
  also have "\<dots> = ?l' + 1" by (subst Liminf_add_ereal_right) simp_all
  finally show "?l' > 0" by (cases ?l') (simp_all add: algebra_simps)
qed (simp_all add: pos)

lemma raabes_test_divergence:
fixes f :: "nat \<Rightarrow> real"
  assumes pos: "eventually (\<lambda>n. f n > 0) sequentially"
  defines "l \<equiv> limsup (\<lambda>n. ereal (of_nat n * (f n / f (Suc n) - 1)))"
  assumes l: "l < 1"
  shows   "\<not>summable f"
proof (rule kummers_test_divergence)
  let ?l' = "limsup (\<lambda>n. ereal (of_nat n * f n / f (Suc n) - of_nat (Suc n)))"
  note l
  also have "l = limsup (\<lambda>n. ereal (of_nat n * f n / f (Suc n) - of_nat (Suc n)) + 1)"
    by (simp add: l_def algebra_simps)
  also have "\<dots> = ?l' + 1" by (subst Limsup_add_ereal_right) simp_all
  finally show "?l' < 0" by (cases ?l') (simp_all add: algebra_simps)
qed (insert pos eventually_gt_at_top[of "0::nat"] not_summable_harmonic, simp_all)



subsection \<open>Radius of convergence\<close>

text \<open>
  The radius of convergence of a power series. This value always exists, ranges from
  @{term "0::ereal"} to @{term "\<infinity>::ereal"}, and the power series is guaranteed to converge for 
  all inputs with a norm that is smaller than that radius and to diverge for all inputs with a
  norm that is greater. 
\<close>
definition conv_radius :: "(nat \<Rightarrow> 'a :: banach) \<Rightarrow> ereal" where
  "conv_radius f = inverse (limsup (\<lambda>n. ereal (root n (norm (f n)))))"

lemma conv_radius_nonneg: "conv_radius f \<ge> 0"
proof -
  have "0 = limsup (\<lambda>n. 0)" by (subst Limsup_const) simp_all
  also have "\<dots> \<le> limsup (\<lambda>n. ereal (root n (norm (f n))))"
    by (intro Limsup_mono) (simp_all add: real_root_ge_zero)
  finally show ?thesis
    unfolding conv_radius_def by (auto simp: ereal_inverse_nonneg_iff)
qed

lemma conv_radius_zero [simp]: "conv_radius (\<lambda>_. 0) = \<infinity>"
  by (auto simp: conv_radius_def zero_ereal_def [symmetric] Limsup_const)

lemma conv_radius_cong:
  assumes "eventually (\<lambda>x. f x = g x) sequentially"
  shows   "conv_radius f = conv_radius g"
proof -
  have "eventually (\<lambda>n. ereal (root n (norm (f n))) = ereal (root n (norm (g n)))) sequentially"
    using assms by eventually_elim simp
  from Limsup_eq[OF this] show ?thesis unfolding conv_radius_def by simp
qed

lemma conv_radius_altdef:
  "conv_radius f = liminf (\<lambda>n. inverse (ereal (root n (norm (f n)))))"
  by (subst Liminf_inverse_ereal) (simp_all add: real_root_ge_zero conv_radius_def)


lemma abs_summable_in_conv_radius:
  fixes f :: "nat \<Rightarrow> 'a :: {banach, real_normed_div_algebra}"
  assumes "ereal (norm z) < conv_radius f"
  shows   "summable (\<lambda>n. norm (f n * z ^ n))"
proof (rule root_test_convergence')
  def l \<equiv> "limsup (\<lambda>n. ereal (root n (norm (f n))))"
  have "0 = limsup (\<lambda>n. 0)" by (simp add: Limsup_const)
  also have "... \<le> l" unfolding l_def by (intro Limsup_mono) (simp_all add: real_root_ge_zero)
  finally have l_nonneg: "l \<ge> 0" .

  have "limsup (\<lambda>n. root n (norm (f n * z^n))) = l * ereal (norm z)" unfolding l_def
    by (rule limsup_root_powser)
  also from l_nonneg consider "l = 0" | "l = \<infinity>" | "\<exists>l'. l = ereal l' \<and> l' > 0"
    by (cases "l") (auto simp: less_le)
  hence "l * ereal (norm z) < 1"
  proof cases
    assume "l = \<infinity>"
    hence "conv_radius f = 0" unfolding conv_radius_def l_def by simp
    with assms show ?thesis by simp
  next
    assume "\<exists>l'. l = ereal l' \<and> l' > 0"
    then guess l' by (elim exE conjE) note l' = this
    hence "l \<noteq> \<infinity>" by auto
    have "l * ereal (norm z) < l * conv_radius f"
      by (intro ereal_mult_strict_left_mono) (simp_all add: l' assms)
    also have "conv_radius f = inverse l" by (simp add: conv_radius_def l_def)
    also from l' have "l * inverse l = 1" by simp
    finally show ?thesis .
  qed simp_all
  finally show "limsup (\<lambda>n. ereal (root n (norm (norm (f n * z ^ n))))) < 1" by simp
qed

lemma summable_in_conv_radius:
  fixes f :: "nat \<Rightarrow> 'a :: {banach, real_normed_div_algebra}"
  assumes "ereal (norm z) < conv_radius f"
  shows   "summable (\<lambda>n. f n * z ^ n)"
  by (rule summable_norm_cancel, rule abs_summable_in_conv_radius) fact+

lemma not_summable_outside_conv_radius:
  fixes f :: "nat \<Rightarrow> 'a :: {banach, real_normed_div_algebra}"
  assumes "ereal (norm z) > conv_radius f"
  shows   "\<not>summable (\<lambda>n. f n * z ^ n)"
proof (rule root_test_divergence)
  def l \<equiv> "limsup (\<lambda>n. ereal (root n (norm (f n))))"
  have "0 = limsup (\<lambda>n. 0)" by (simp add: Limsup_const)
  also have "... \<le> l" unfolding l_def by (intro Limsup_mono) (simp_all add: real_root_ge_zero)
  finally have l_nonneg: "l \<ge> 0" .
  from assms have l_nz: "l \<noteq> 0" unfolding conv_radius_def l_def by auto

  have "limsup (\<lambda>n. ereal (root n (norm (f n * z^n)))) = l * ereal (norm z)"
    unfolding l_def by (rule limsup_root_powser)
  also have "... > 1"
  proof (cases l)
    assume "l = \<infinity>"
    with assms conv_radius_nonneg[of f] show ?thesis
      by (auto simp: zero_ereal_def[symmetric])
  next
    fix l' assume l': "l = ereal l'"
    from l_nonneg l_nz have "1 = l * inverse l" by (auto simp: l' field_simps)
    also from l_nz have "inverse l = conv_radius f" 
      unfolding l_def conv_radius_def by auto
    also from l' l_nz l_nonneg assms have "l * \<dots> < l * ereal (norm z)"
      by (intro ereal_mult_strict_left_mono) (auto simp: l')
    finally show ?thesis .
  qed (insert l_nonneg, simp_all)
  finally show "limsup (\<lambda>n. ereal (root n (norm (f n * z^n)))) > 1" .
qed


lemma conv_radius_geI:
  assumes "summable (\<lambda>n. f n * z ^ n :: 'a :: {banach, real_normed_div_algebra})"
  shows   "conv_radius f \<ge> norm z"
  using not_summable_outside_conv_radius[of f z] assms by (force simp: not_le[symmetric])

lemma conv_radius_leI:
  assumes "\<not>summable (\<lambda>n. norm (f n * z ^ n :: 'a :: {banach, real_normed_div_algebra}))"
  shows   "conv_radius f \<le> norm z"
  using abs_summable_in_conv_radius[of z f] assms by (force simp: not_le[symmetric])

lemma conv_radius_leI':
  assumes "\<not>summable (\<lambda>n. f n * z ^ n :: 'a :: {banach, real_normed_div_algebra})"
  shows   "conv_radius f \<le> norm z"
  using summable_in_conv_radius[of z f] assms by (force simp: not_le[symmetric])

lemma conv_radius_geI_ex:
  fixes f :: "nat \<Rightarrow> 'a :: {banach, real_normed_div_algebra}"
  assumes "\<And>r. 0 < r \<Longrightarrow> ereal r < R \<Longrightarrow> \<exists>z. norm z = r \<and> summable (\<lambda>n. f n * z^n)"
  shows   "conv_radius f \<ge> R"
proof (rule linorder_cases[of "conv_radius f" R])
  assume R: "conv_radius f < R"
  with conv_radius_nonneg[of f] obtain conv_radius' 
    where [simp]: "conv_radius f = ereal conv_radius'"
    by (cases "conv_radius f") simp_all
  def r \<equiv> "if R = \<infinity> then conv_radius' + 1 else (real_of_ereal R + conv_radius') / 2"
  from R conv_radius_nonneg[of f] have "0 < r \<and> ereal r < R \<and> ereal r > conv_radius f" 
    unfolding r_def by (cases R) (auto simp: r_def field_simps)
  with assms(1)[of r] obtain z where "norm z > conv_radius f" "summable (\<lambda>n. f n * z^n)" by auto
  with not_summable_outside_conv_radius[of f z] show ?thesis by simp
qed simp_all

lemma conv_radius_geI_ex':
  fixes f :: "nat \<Rightarrow> 'a :: {banach, real_normed_div_algebra}"
  assumes "\<And>r. 0 < r \<Longrightarrow> ereal r < R \<Longrightarrow> summable (\<lambda>n. f n * of_real r^n)"
  shows   "conv_radius f \<ge> R"
proof (rule conv_radius_geI_ex)
  fix r assume "0 < r" "ereal r < R"
  with assms[of r] show "\<exists>z. norm z = r \<and> summable (\<lambda>n. f n * z ^ n)"
    by (intro exI[of _ "of_real r :: 'a"]) auto
qed

lemma conv_radius_leI_ex:
  fixes f :: "nat \<Rightarrow> 'a :: {banach, real_normed_div_algebra}"
  assumes "R \<ge> 0"
  assumes "\<And>r. 0 < r \<Longrightarrow> ereal r > R \<Longrightarrow> \<exists>z. norm z = r \<and> \<not>summable (\<lambda>n. norm (f n * z^n))"
  shows   "conv_radius f \<le> R"
proof (rule linorder_cases[of "conv_radius f" R])
  assume R: "conv_radius f > R"
  from R assms(1) obtain R' where R': "R = ereal R'" by (cases R) simp_all
  def r \<equiv> "if conv_radius f = \<infinity> then R' + 1 else (R' + real_of_ereal (conv_radius f)) / 2"
  from R conv_radius_nonneg[of f] have "r > R \<and> r < conv_radius f" unfolding r_def
    by (cases "conv_radius f") (auto simp: r_def field_simps R')
  with assms(1) assms(2)[of r] R' 
    obtain z where "norm z < conv_radius f" "\<not>summable (\<lambda>n. norm (f n * z^n))" by auto
  with abs_summable_in_conv_radius[of z f] show ?thesis by auto
qed simp_all

lemma conv_radius_leI_ex':
  fixes f :: "nat \<Rightarrow> 'a :: {banach, real_normed_div_algebra}"
  assumes "R \<ge> 0"
  assumes "\<And>r. 0 < r \<Longrightarrow> ereal r > R \<Longrightarrow> \<not>summable (\<lambda>n. f n * of_real r^n)"
  shows   "conv_radius f \<le> R"
proof (rule conv_radius_leI_ex)
  fix r assume "0 < r" "ereal r > R"
  with assms(2)[of r] show "\<exists>z. norm z = r \<and> \<not>summable (\<lambda>n. norm (f n * z ^ n))"
    by (intro exI[of _ "of_real r :: 'a"]) (auto dest: summable_norm_cancel)
qed fact+

lemma conv_radius_eqI:
  fixes f :: "nat \<Rightarrow> 'a :: {banach, real_normed_div_algebra}"
  assumes "R \<ge> 0"
  assumes "\<And>r. 0 < r \<Longrightarrow> ereal r < R \<Longrightarrow> \<exists>z. norm z = r \<and> summable (\<lambda>n. f n * z^n)"
  assumes "\<And>r. 0 < r \<Longrightarrow> ereal r > R \<Longrightarrow> \<exists>z. norm z = r \<and> \<not>summable (\<lambda>n. norm (f n * z^n))"
  shows   "conv_radius f = R"
  by (intro antisym conv_radius_geI_ex conv_radius_leI_ex assms)

lemma conv_radius_eqI':
  fixes f :: "nat \<Rightarrow> 'a :: {banach, real_normed_div_algebra}"
  assumes "R \<ge> 0"
  assumes "\<And>r. 0 < r \<Longrightarrow> ereal r < R \<Longrightarrow> summable (\<lambda>n. f n * (of_real r)^n)"
  assumes "\<And>r. 0 < r \<Longrightarrow> ereal r > R \<Longrightarrow> \<not>summable (\<lambda>n. norm (f n * (of_real r)^n))"
  shows   "conv_radius f = R"
proof (intro conv_radius_eqI[OF assms(1)])
  fix r assume "0 < r" "ereal r < R" with assms(2)[OF this] 
    show "\<exists>z. norm z = r \<and> summable (\<lambda>n. f n * z ^ n)" by force
next
  fix r assume "0 < r" "ereal r > R" with assms(3)[OF this] 
    show "\<exists>z. norm z = r \<and> \<not>summable (\<lambda>n. norm (f n * z ^ n))" by force  
qed

lemma conv_radius_zeroI:
  fixes f :: "nat \<Rightarrow> 'a :: {banach,real_normed_div_algebra}"
  assumes "\<And>z. z \<noteq> 0 \<Longrightarrow> \<not>summable (\<lambda>n. f n * z^n)"
  shows   "conv_radius f = 0"
proof (rule ccontr)
  assume "conv_radius f \<noteq> 0"
  with conv_radius_nonneg[of f] have pos: "conv_radius f > 0" by simp
  def r \<equiv> "if conv_radius f = \<infinity> then 1 else real_of_ereal (conv_radius f) / 2"
  from pos have r: "ereal r > 0 \<and> ereal r < conv_radius f" 
    by (cases "conv_radius f") (simp_all add: r_def)
  hence "summable (\<lambda>n. f n * of_real r ^ n)" by (intro summable_in_conv_radius) simp
  moreover from r and assms[of "of_real r"] have "\<not>summable (\<lambda>n. f n * of_real r ^ n)" by simp
  ultimately show False by contradiction
qed

lemma conv_radius_inftyI':
  fixes f :: "nat \<Rightarrow> 'a :: {banach,real_normed_div_algebra}"
  assumes "\<And>r. r > c \<Longrightarrow> \<exists>z. norm z = r \<and> summable (\<lambda>n. f n * z^n)"
  shows   "conv_radius f = \<infinity>"
proof -
  {
    fix r :: real
    have "max r (c + 1) > c" by (auto simp: max_def)
    from assms[OF this] obtain z where "norm z = max r (c + 1)" "summable (\<lambda>n. f n * z^n)" by blast
    from conv_radius_geI[OF this(2)] this(1) have "conv_radius f \<ge> r" by simp
  }
  from this[of "real_of_ereal (conv_radius f + 1)"] show "conv_radius f = \<infinity>"
    by (cases "conv_radius f") simp_all
qed

lemma conv_radius_inftyI:
  fixes f :: "nat \<Rightarrow> 'a :: {banach,real_normed_div_algebra}"
  assumes "\<And>r. \<exists>z. norm z = r \<and> summable (\<lambda>n. f n * z^n)"
  shows   "conv_radius f = \<infinity>"
  using assms by (rule conv_radius_inftyI')

lemma conv_radius_inftyI'':
  fixes f :: "nat \<Rightarrow> 'a :: {banach,real_normed_div_algebra}"
  assumes "\<And>z. summable (\<lambda>n. f n * z^n)"
  shows   "conv_radius f = \<infinity>"
proof (rule conv_radius_inftyI')
  fix r :: real assume "r > 0"
  with assms show "\<exists>z. norm z = r \<and> summable (\<lambda>n. f n * z^n)"
    by (intro exI[of _ "of_real r"]) simp
qed

lemma conv_radius_ratio_limit_ereal:
  fixes f :: "nat \<Rightarrow> 'a :: {banach,real_normed_div_algebra}"
  assumes nz:  "eventually (\<lambda>n. f n \<noteq> 0) sequentially"
  assumes lim: "(\<lambda>n. ereal (norm (f n) / norm (f (Suc n)))) \<longlonglongrightarrow> c"
  shows   "conv_radius f = c"
proof (rule conv_radius_eqI')
  show "c \<ge> 0" by (intro Lim_bounded2_ereal[OF lim]) simp_all
next
  fix r assume r: "0 < r" "ereal r < c"
  let ?l = "liminf (\<lambda>n. ereal (norm (f n * of_real r ^ n) / norm (f (Suc n) * of_real r ^ Suc n)))"
  have "?l = liminf (\<lambda>n. ereal (norm (f n) / (norm (f (Suc n)))) * ereal (inverse r))"
    using r by (simp add: norm_mult norm_power divide_simps)
  also from r have "\<dots> = liminf (\<lambda>n. ereal (norm (f n) / (norm (f (Suc n))))) * ereal (inverse r)"
    by (intro Liminf_ereal_mult_right) simp_all
  also have "liminf (\<lambda>n. ereal (norm (f n) / (norm (f (Suc n))))) = c"
    by (intro lim_imp_Liminf lim) simp
  finally have l: "?l = c * ereal (inverse r)" by simp
  from r have  l': "c * ereal (inverse r) > 1" by (cases c) (simp_all add: field_simps)
  show "summable (\<lambda>n. f n * of_real r^n)"
    by (rule summable_norm_cancel, rule ratio_test_convergence)
       (insert r nz l l', auto elim!: eventually_mono)
next
  fix r assume r: "0 < r" "ereal r > c"
  let ?l = "limsup (\<lambda>n. ereal (norm (f n * of_real r ^ n) / norm (f (Suc n) * of_real r ^ Suc n)))"
  have "?l = limsup (\<lambda>n. ereal (norm (f n) / (norm (f (Suc n)))) * ereal (inverse r))"
    using r by (simp add: norm_mult norm_power divide_simps)
  also from r have "\<dots> = limsup (\<lambda>n. ereal (norm (f n) / (norm (f (Suc n))))) * ereal (inverse r)"
    by (intro Limsup_ereal_mult_right) simp_all
  also have "limsup (\<lambda>n. ereal (norm (f n) / (norm (f (Suc n))))) = c"
    by (intro lim_imp_Limsup lim) simp
  finally have l: "?l = c * ereal (inverse r)" by simp
  from r have  l': "c * ereal (inverse r) < 1" by (cases c) (simp_all add: field_simps)
  show "\<not>summable (\<lambda>n. norm (f n * of_real r^n))"
    by (rule ratio_test_divergence) (insert r nz l l', auto elim!: eventually_mono)
qed

lemma conv_radius_ratio_limit_ereal_nonzero:
  fixes f :: "nat \<Rightarrow> 'a :: {banach,real_normed_div_algebra}"
  assumes nz:  "c \<noteq> 0"
  assumes lim: "(\<lambda>n. ereal (norm (f n) / norm (f (Suc n)))) \<longlonglongrightarrow> c"
  shows   "conv_radius f = c"
proof (rule conv_radius_ratio_limit_ereal[OF _ lim], rule ccontr)
  assume "\<not>eventually (\<lambda>n. f n \<noteq> 0) sequentially"
  hence "frequently (\<lambda>n. f n = 0) sequentially" by (simp add: frequently_def)
  hence "frequently (\<lambda>n. ereal (norm (f n) / norm (f (Suc n))) = 0) sequentially"
    by (force elim!: frequently_elim1)
  hence "c = 0" by (intro limit_frequently_eq[OF _ _ lim]) auto
  with nz show False by contradiction
qed 

lemma conv_radius_ratio_limit:
  fixes f :: "nat \<Rightarrow> 'a :: {banach,real_normed_div_algebra}"
  assumes "c' = ereal c"
  assumes nz:  "eventually (\<lambda>n. f n \<noteq> 0) sequentially"
  assumes lim: "(\<lambda>n. norm (f n) / norm (f (Suc n))) \<longlonglongrightarrow> c"
  shows   "conv_radius f = c'"
  using assms by (intro conv_radius_ratio_limit_ereal) simp_all
  
lemma conv_radius_ratio_limit_nonzero:
  fixes f :: "nat \<Rightarrow> 'a :: {banach,real_normed_div_algebra}"
  assumes "c' = ereal c"
  assumes nz:  "c \<noteq> 0"
  assumes lim: "(\<lambda>n. norm (f n) / norm (f (Suc n))) \<longlonglongrightarrow> c"
  shows   "conv_radius f = c'"
  using assms by (intro conv_radius_ratio_limit_ereal_nonzero) simp_all

lemma conv_radius_mult_power: 
  assumes "c \<noteq> (0 :: 'a :: {real_normed_div_algebra,banach})"
  shows   "conv_radius (\<lambda>n. c ^ n * f n) = conv_radius f / ereal (norm c)"
proof - 
  have "limsup (\<lambda>n. ereal (root n (norm (c ^ n * f n)))) =
          limsup (\<lambda>n. ereal (norm c) * ereal (root n (norm (f n))))" 
    using eventually_gt_at_top[of "0::nat"]
    by (intro Limsup_eq) 
       (auto elim!: eventually_mono simp: norm_mult norm_power real_root_mult real_root_power)
  also have "\<dots> = ereal (norm c) * limsup (\<lambda>n. ereal (root n (norm (f n))))"
    using assms by (subst Limsup_ereal_mult_left[symmetric]) simp_all
  finally have A: "limsup (\<lambda>n. ereal (root n (norm (c ^ n * f n)))) = 
                       ereal (norm c) * limsup (\<lambda>n. ereal (root n (norm (f n))))" .
  show ?thesis using assms
    apply (cases "limsup (\<lambda>n. ereal (root n (norm (f n)))) = 0")
    apply (simp add: A conv_radius_def)
    apply (unfold conv_radius_def A divide_ereal_def, simp add: mult.commute ereal_inverse_mult)
    done
qed

lemma conv_radius_mult_power_right: 
  assumes "c \<noteq> (0 :: 'a :: {real_normed_div_algebra,banach})"
  shows   "conv_radius (\<lambda>n. f n * c ^ n) = conv_radius f / ereal (norm c)"
  using conv_radius_mult_power[OF assms, of f]
  unfolding conv_radius_def by (simp add: mult.commute norm_mult)

lemma conv_radius_divide_power: 
  assumes "c \<noteq> (0 :: 'a :: {real_normed_div_algebra,banach})"
  shows   "conv_radius (\<lambda>n. f n / c^n) = conv_radius f * ereal (norm c)"
proof - 
  from assms have "inverse c \<noteq> 0" by simp
  from conv_radius_mult_power_right[OF this, of f] show ?thesis
    by (simp add: divide_inverse divide_ereal_def assms norm_inverse power_inverse)
qed


lemma conv_radius_add_ge: 
  "min (conv_radius f) (conv_radius g) \<le> 
       conv_radius (\<lambda>x. f x + g x :: 'a :: {banach,real_normed_div_algebra})"
  by (rule conv_radius_geI_ex')
     (auto simp: algebra_simps intro!: summable_add summable_in_conv_radius)

lemma conv_radius_mult_ge:
  fixes f g :: "nat \<Rightarrow> ('a :: {banach,real_normed_div_algebra})"
  shows "conv_radius (\<lambda>x. \<Sum>i\<le>x. f i * g (x - i)) \<ge> min (conv_radius f) (conv_radius g)"
proof (rule conv_radius_geI_ex')
  fix r assume r: "r > 0" "ereal r < min (conv_radius f) (conv_radius g)"
  from r have "summable (\<lambda>n. (\<Sum>i\<le>n. (f i * of_real r^i) * (g (n - i) * of_real r^(n - i))))"
    by (intro summable_Cauchy_product abs_summable_in_conv_radius) simp_all
  thus "summable (\<lambda>n. (\<Sum>i\<le>n. f i * g (n - i)) * of_real r ^ n)"
    by (simp add: algebra_simps of_real_def scaleR_power power_add [symmetric] scaleR_setsum_right)
qed

end
