(*  Title:      HOL/Library/Binomial.thy
    Author:     Lawrence C Paulson, Amine Chaieb
    Copyright   1997  University of Cambridge
*)

header {* Binomial Coefficients *}

theory Binomial
imports Complex_Main
begin

text {* This development is based on the work of Andy Gordon and
  Florian Kammueller. *}

primrec binomial :: "nat \<Rightarrow> nat \<Rightarrow> nat" (infixl "choose" 65)
where
  "0 choose k = (if k = 0 then 1 else 0)"
| "Suc n choose k = (if k = 0 then 1 else (n choose (k - 1)) + (n choose k))"

lemma binomial_n_0 [simp]: "(n choose 0) = 1"
  by (cases n) simp_all

lemma binomial_0_Suc [simp]: "(0 choose Suc k) = 0"
  by simp

lemma binomial_Suc_Suc [simp]: "(Suc n choose Suc k) = (n choose k) + (n choose Suc k)"
  by simp

lemma choose_reduce_nat: 
  "0 < (n::nat) \<Longrightarrow> 0 < k \<Longrightarrow>
    (n choose k) = ((n - 1) choose k) + ((n - 1) choose (k - 1))"
  by (metis Suc_diff_1 binomial.simps(2) nat_add_commute neq0_conv)

lemma binomial_eq_0: "n < k \<Longrightarrow> n choose k = 0"
  by (induct n arbitrary: k) auto

declare binomial.simps [simp del]

lemma binomial_n_n [simp]: "n choose n = 1"
  by (induct n) (simp_all add: binomial_eq_0)

lemma binomial_Suc_n [simp]: "Suc n choose n = Suc n"
  by (induct n) simp_all

lemma binomial_1 [simp]: "n choose Suc 0 = n"
  by (induct n) simp_all

lemma zero_less_binomial: "k \<le> n \<Longrightarrow> n choose k > 0"
  by (induct n k rule: diff_induct) simp_all

lemma binomial_eq_0_iff: "n choose k = 0 \<longleftrightarrow> n < k"
  by (metis binomial_eq_0 less_numeral_extra(3) not_less zero_less_binomial)

lemma zero_less_binomial_iff: "n choose k > 0 \<longleftrightarrow> k \<le> n"
  by (simp add: linorder_not_less binomial_eq_0_iff neq0_conv[symmetric] del: neq0_conv)

(*Might be more useful if re-oriented*)
lemma Suc_times_binomial_eq:
  "k \<le> n \<Longrightarrow> Suc n * (n choose k) = (Suc n choose Suc k) * Suc k"
  apply (induct n arbitrary: k)
   apply (simp add: binomial.simps)
   apply (case_tac k)
  apply (auto simp add: add_mult_distrib add_mult_distrib2 le_Suc_eq binomial_eq_0)
  done

text{*This is the well-known version, but it's harder to use because of the
  need to reason about division.*}
lemma binomial_Suc_Suc_eq_times:
    "k \<le> n \<Longrightarrow> (Suc n choose Suc k) = (Suc n * (n choose k)) div Suc k"
  by (simp add: Suc_times_binomial_eq del: mult_Suc mult_Suc_right)

text{*Another version, with -1 instead of Suc.*}
lemma times_binomial_minus1_eq:
  "k \<le> n \<Longrightarrow> 0 < k \<Longrightarrow> (n choose k) * k = n * ((n - 1) choose (k - 1))"
  using Suc_times_binomial_eq [where n = "n - 1" and k = "k - 1"]
  by (auto split add: nat_diff_split)


subsection {* Theorems about @{text "choose"} *}

text {*
  \medskip Basic theorem about @{text "choose"}.  By Florian
  Kamm\"uller, tidied by LCP.
*}

lemma card_s_0_eq_empty: "finite A \<Longrightarrow> card {B. B \<subseteq> A & card B = 0} = 1"
  by (simp cong add: conj_cong add: finite_subset [THEN card_0_eq])

lemma choose_deconstruct: "finite M \<Longrightarrow> x \<notin> M \<Longrightarrow>
    {s. s \<subseteq> insert x M \<and> card s = Suc k} =
    {s. s \<subseteq> M \<and> card s = Suc k} \<union> {s. \<exists>t. t \<subseteq> M \<and> card t = k \<and> s = insert x t}"
  apply safe
     apply (auto intro: finite_subset [THEN card_insert_disjoint])
  apply (drule_tac x = "xa - {x}" in spec)
  by (metis card_Diff_singleton_if card_infinite diff_Suc_1 in_mono insert_Diff_single insert_absorb lessI less_nat_zero_code subset_insert_iff)

lemma finite_bex_subset [simp]:
  assumes "finite B"
    and "\<And>A. A \<subseteq> B \<Longrightarrow> finite {x. P x A}"
  shows "finite {x. \<exists>A \<subseteq> B. P x A}"
proof -
  have "{x. \<exists>A\<subseteq>B. P x A} = (\<Union>A \<in> Pow B. {x. P x A})" by blast
  with assms show ?thesis by simp
qed

text{*There are as many subsets of @{term A} having cardinality @{term k}
 as there are sets obtained from the former by inserting a fixed element
 @{term x} into each.*}
lemma constr_bij:
   "finite A \<Longrightarrow> x \<notin> A \<Longrightarrow>
    card {B. \<exists>C. C \<subseteq> A \<and> card C = k \<and> B = insert x C} =
    card {B. B \<subseteq> A & card(B) = k}"
  apply (rule card_bij_eq [where f = "\<lambda>s. s - {x}" and g = "insert x"])
  apply (auto elim!: equalityE simp add: inj_on_def)
  apply (metis card_Diff_singleton_if finite_subset in_mono)
  done

text {*
  Main theorem: combinatorial statement about number of subsets of a set.
*}

theorem n_subsets: "finite A \<Longrightarrow> card {B. B \<subseteq> A \<and> card B = k} = (card A choose k)"
proof (induct k arbitrary: A)
  case 0 then show ?case by (simp add: card_s_0_eq_empty)
next
  case (Suc k)
  show ?case using `finite A`
  proof (induct A)
    case empty show ?case by (simp add: card_s_0_eq_empty)
  next
    case (insert x A)
    then show ?case using Suc.hyps
      apply (simp add: card_s_0_eq_empty choose_deconstruct)
      apply (subst card_Un_disjoint)
         prefer 4 apply (force simp add: constr_bij)
        prefer 3 apply force
       prefer 2 apply (blast intro: finite_Pow_iff [THEN iffD2]
         finite_subset [of _ "Pow (insert x F)", standard])
      apply (blast intro: finite_Pow_iff [THEN iffD2, THEN [2] finite_subset])
      done
  qed
qed


text{* The binomial theorem (courtesy of Tobias Nipkow): *}

(* Avigad's version, generalized to any commutative semiring *)
theorem binomial: "(a+b::'a::{comm_ring_1,power})^n = 
  (\<Sum>k=0..n. (of_nat (n choose k)) * a^k * b^(n-k))" (is "?P n")
proof (induct n)
  case 0 then show "?P 0" by simp
next
  case (Suc n)
  have decomp: "{0..n+1} = {0} Un {n+1} Un {1..n}"
    by auto
  have decomp2: "{0..n} = {0} Un {1..n}"
    by auto
  have "(a+b)^(n+1) = 
      (a+b) * (\<Sum>k=0..n. of_nat (n choose k) * a^k * b^(n-k))"
    using Suc.hyps by simp
  also have "\<dots> = a*(\<Sum>k=0..n. of_nat (n choose k) * a^k * b^(n-k)) +
                   b*(\<Sum>k=0..n. of_nat (n choose k) * a^k * b^(n-k))"
    by (rule distrib)
  also have "\<dots> = (\<Sum>k=0..n. of_nat (n choose k) * a^(k+1) * b^(n-k)) +
                  (\<Sum>k=0..n. of_nat (n choose k) * a^k * b^(n-k+1))"
    by (auto simp add: setsum_right_distrib mult_ac)
  also have "\<dots> = (\<Sum>k=0..n. of_nat (n choose k) * a^k * b^(n+1-k)) +
                  (\<Sum>k=1..n+1. of_nat (n choose (k - 1)) * a^k * b^(n+1-k))"
    by (simp add:setsum_shift_bounds_cl_Suc_ivl Suc_diff_le field_simps  
        del:setsum_cl_ivl_Suc)
  also have "\<dots> = a^(n+1) + b^(n+1) +
                  (\<Sum>k=1..n. of_nat (n choose (k - 1)) * a^k * b^(n+1-k)) +
                  (\<Sum>k=1..n. of_nat (n choose k) * a^k * b^(n+1-k))"
    by (simp add: decomp2)
  also have
      "\<dots> = a^(n+1) + b^(n+1) + 
            (\<Sum>k=1..n. of_nat(n+1 choose k) * a^k * b^(n+1-k))"
    by (auto simp add: field_simps setsum_addf [symmetric] choose_reduce_nat)
  also have "\<dots> = (\<Sum>k=0..n+1. of_nat (n+1 choose k) * a^k * b^(n+1-k))"
    using decomp by (simp add: field_simps)
  finally show "?P (Suc n)" by simp
qed

subsection{* Pochhammer's symbol : generalized raising factorial*}

definition "pochhammer (a::'a::comm_semiring_1) n =
  (if n = 0 then 1 else setprod (\<lambda>n. a + of_nat n) {0 .. n - 1})"

lemma pochhammer_0 [simp]: "pochhammer a 0 = 1"
  by (simp add: pochhammer_def)

lemma pochhammer_1 [simp]: "pochhammer a 1 = a"
  by (simp add: pochhammer_def)

lemma pochhammer_Suc0 [simp]: "pochhammer a (Suc 0) = a"
  by (simp add: pochhammer_def)

lemma pochhammer_Suc_setprod: "pochhammer a (Suc n) = setprod (\<lambda>n. a + of_nat n) {0 .. n}"
  by (simp add: pochhammer_def)

lemma setprod_nat_ivl_Suc: "setprod f {0 .. Suc n} = setprod f {0..n} * f (Suc n)"
proof -
  have "{0..Suc n} = {0..n} \<union> {Suc n}" by auto
  then show ?thesis by (simp add: field_simps)
qed

lemma setprod_nat_ivl_1_Suc: "setprod f {0 .. Suc n} = f 0 * setprod f {1.. Suc n}"
proof -
  have "{0..Suc n} = {0} \<union> {1 .. Suc n}" by auto
  then show ?thesis by simp
qed


lemma pochhammer_Suc: "pochhammer a (Suc n) = pochhammer a n * (a + of_nat n)"
proof (cases n)
  case 0
  then show ?thesis by simp
next
  case (Suc n)
  show ?thesis unfolding Suc pochhammer_Suc_setprod setprod_nat_ivl_Suc ..
qed

lemma pochhammer_rec: "pochhammer a (Suc n) = a * pochhammer (a + 1) n"
proof (cases "n = 0")
  case True
  then show ?thesis by (simp add: pochhammer_Suc_setprod)
next
  case False
  have *: "finite {1 .. n}" "0 \<notin> {1 .. n}" by auto
  have eq: "insert 0 {1 .. n} = {0..n}" by auto
  have **: "(\<Prod>n\<in>{1\<Colon>nat..n}. a + of_nat n) = (\<Prod>n\<in>{0\<Colon>nat..n - 1}. a + 1 + of_nat n)"
    apply (rule setprod_reindex_cong [where f = Suc])
    using False
    apply (auto simp add: fun_eq_iff field_simps)
    done
  show ?thesis
    apply (simp add: pochhammer_def)
    unfolding setprod_insert [OF *, unfolded eq]
    using ** apply (simp add: field_simps)
    done
qed

lemma pochhammer_fact: "of_nat (fact n) = pochhammer 1 n"
  unfolding fact_altdef_nat
  apply (cases n)
   apply (simp_all add: of_nat_setprod pochhammer_Suc_setprod)
  apply (rule setprod_reindex_cong[where f=Suc])
    apply (auto simp add: fun_eq_iff)
  done

lemma pochhammer_of_nat_eq_0_lemma:
  assumes "k > n"
  shows "pochhammer (- (of_nat n :: 'a:: idom)) k = 0"
proof (cases "n = 0")
  case True
  then show ?thesis
    using assms by (cases k) (simp_all add: pochhammer_rec)
next
  case False
  from assms obtain h where "k = Suc h" by (cases k) auto
  then show ?thesis
    apply (simp add: pochhammer_Suc_setprod)
    apply (rule_tac x="n" in bexI)
    using assms
    apply auto
    done
qed

lemma pochhammer_of_nat_eq_0_lemma':
  assumes kn: "k \<le> n"
  shows "pochhammer (- (of_nat n :: 'a:: {idom,ring_char_0})) k \<noteq> 0"
proof (cases k)
  case 0
  then show ?thesis by simp
next
  case (Suc h)
  then show ?thesis
    apply (simp add: pochhammer_Suc_setprod)
    using Suc kn apply (auto simp add: algebra_simps)
    done
qed

lemma pochhammer_of_nat_eq_0_iff:
  shows "pochhammer (- (of_nat n :: 'a:: {idom,ring_char_0})) k = 0 \<longleftrightarrow> k > n"
  (is "?l = ?r")
  using pochhammer_of_nat_eq_0_lemma[of n k, where ?'a='a]
    pochhammer_of_nat_eq_0_lemma'[of k n, where ?'a = 'a]
  by (auto simp add: not_le[symmetric])


lemma pochhammer_eq_0_iff: "pochhammer a n = (0::'a::field_char_0) \<longleftrightarrow> (\<exists>k < n. a = - of_nat k)"
  apply (auto simp add: pochhammer_of_nat_eq_0_iff)
  apply (cases n)
   apply (auto simp add: pochhammer_def algebra_simps group_add_class.eq_neg_iff_add_eq_0)
  apply (rule_tac x=x in exI)
  apply auto
  done


lemma pochhammer_eq_0_mono:
  "pochhammer a n = (0::'a::field_char_0) \<Longrightarrow> m \<ge> n \<Longrightarrow> pochhammer a m = 0"
  unfolding pochhammer_eq_0_iff by auto

lemma pochhammer_neq_0_mono:
  "pochhammer a m \<noteq> (0::'a::field_char_0) \<Longrightarrow> m \<ge> n \<Longrightarrow> pochhammer a n \<noteq> 0"
  unfolding pochhammer_eq_0_iff by auto

lemma pochhammer_minus:
  assumes kn: "k \<le> n"
  shows "pochhammer (- b) k = ((- 1) ^ k :: 'a::comm_ring_1) * pochhammer (b - of_nat k + 1) k"
proof (cases k)
  case 0
  then show ?thesis by simp
next
  case (Suc h)
  have eq: "((- 1) ^ Suc h :: 'a) = setprod (%i. - 1) {0 .. h}"
    using setprod_constant[where A="{0 .. h}" and y="- 1 :: 'a"]
    by auto
  show ?thesis
    unfolding Suc pochhammer_Suc_setprod eq setprod_timesf[symmetric]
    apply (rule strong_setprod_reindex_cong[where f = "%i. h - i"])
    using Suc
    apply (auto simp add: inj_on_def image_def)
    apply (rule_tac x="h - x" in bexI)
    apply (auto simp add: fun_eq_iff of_nat_diff)
    done
qed

lemma pochhammer_minus':
  assumes kn: "k \<le> n"
  shows "pochhammer (b - of_nat k + 1) k = ((- 1) ^ k :: 'a::comm_ring_1) * pochhammer (- b) k"
  unfolding pochhammer_minus[OF kn, where b=b]
  unfolding mult_assoc[symmetric]
  unfolding power_add[symmetric]
  by simp

lemma pochhammer_same: "pochhammer (- of_nat n) n =
    ((- 1) ^ n :: 'a::comm_ring_1) * of_nat (fact n)"
  unfolding pochhammer_minus[OF le_refl[of n]]
  by (simp add: of_nat_diff pochhammer_fact)


subsection{* Generalized binomial coefficients *}

definition gbinomial :: "'a::field_char_0 \<Rightarrow> nat \<Rightarrow> 'a" (infixl "gchoose" 65)
  where "a gchoose n =
    (if n = 0 then 1 else (setprod (\<lambda>i. a - of_nat i) {0 .. n - 1}) / of_nat (fact n))"

lemma gbinomial_0 [simp]: "a gchoose 0 = 1" "0 gchoose (Suc n) = 0"
  apply (simp_all add: gbinomial_def)
  apply (subgoal_tac "(\<Prod>i\<Colon>nat\<in>{0\<Colon>nat..n}. - of_nat i) = (0::'b)")
   apply (simp del:setprod_zero_iff)
  apply simp
  done

lemma gbinomial_pochhammer: "a gchoose n = (- 1) ^ n * pochhammer (- a) n / of_nat (fact n)"
proof (cases "n = 0")
  case True
  then show ?thesis by simp
next
  case False
  from this setprod_constant[of "{0 .. n - 1}" "- (1:: 'a)"]
  have eq: "(- (1\<Colon>'a)) ^ n = setprod (\<lambda>i. - 1) {0 .. n - 1}"
    by auto
  from False show ?thesis
    by (simp add: pochhammer_def gbinomial_def field_simps
      eq setprod_timesf[symmetric])
qed

lemma binomial_fact_lemma: "k \<le> n \<Longrightarrow> fact k * fact (n - k) * (n choose k) = fact n"
proof (induct n arbitrary: k rule: nat_less_induct)
  fix n k assume H: "\<forall>m<n. \<forall>x\<le>m. fact x * fact (m - x) * (m choose x) =
                      fact m" and kn: "k \<le> n"
  let ?ths = "fact k * fact (n - k) * (n choose k) = fact n"
  { assume "n=0" then have ?ths using kn by simp }
  moreover
  { assume "k=0" then have ?ths using kn by simp }
  moreover
  { assume nk: "n=k" then have ?ths by simp }
  moreover
  { fix m h assume n: "n = Suc m" and h: "k = Suc h" and hm: "h < m"
    from n have mn: "m < n" by arith
    from hm have hm': "h \<le> m" by arith
    from hm h n kn have km: "k \<le> m" by arith
    have "m - h = Suc (m - Suc h)" using  h km hm by arith
    with km h have th0: "fact (m - h) = (m - h) * fact (m - k)"
      by simp
    from n h th0
    have "fact k * fact (n - k) * (n choose k) =
        k * (fact h * fact (m - h) * (m choose h)) + 
        (m - h) * (fact k * fact (m - k) * (m choose k))"
      by (simp add: field_simps)
    also have "\<dots> = (k + (m - h)) * fact m"
      using H[rule_format, OF mn hm'] H[rule_format, OF mn km]
      by (simp add: field_simps)
    finally have ?ths using h n km by simp }
  moreover have "n=0 \<or> k = 0 \<or> k = n \<or> (\<exists>m h. n = Suc m \<and> k = Suc h \<and> h < m)"
    using kn by presburger
  ultimately show ?ths by blast
qed

lemma binomial_fact:
  assumes kn: "k \<le> n"
  shows "(of_nat (n choose k) :: 'a::field_char_0) =
    of_nat (fact n) / (of_nat (fact k) * of_nat (fact (n - k)))"
  using binomial_fact_lemma[OF kn]
  by (simp add: field_simps of_nat_mult [symmetric])

lemma binomial_gbinomial: "of_nat (n choose k) = of_nat n gchoose k"
proof -
  { assume kn: "k > n"
    from kn binomial_eq_0[OF kn] have ?thesis
      by (simp add: gbinomial_pochhammer field_simps  pochhammer_of_nat_eq_0_iff) }
  moreover
  { assume "k=0" then have ?thesis by simp }
  moreover
  { assume kn: "k \<le> n" and k0: "k\<noteq> 0"
    from k0 obtain h where h: "k = Suc h" by (cases k) auto
    from h
    have eq:"(- 1 :: 'a) ^ k = setprod (\<lambda>i. - 1) {0..h}"
      by (subst setprod_constant) auto
    have eq': "(\<Prod>i\<in>{0..h}. of_nat n + - (of_nat i :: 'a)) = (\<Prod>i\<in>{n - h..n}. of_nat i)"
      apply (rule strong_setprod_reindex_cong[where f="op - n"])
        using h kn
        apply (simp_all add: inj_on_def image_iff Bex_def set_eq_iff)
        apply clarsimp
        apply presburger
       apply presburger
      apply (simp add: fun_eq_iff field_simps of_nat_add[symmetric] del: of_nat_add)
      done
    have th0: "finite {1..n - Suc h}" "finite {n - h .. n}"
        "{1..n - Suc h} \<inter> {n - h .. n} = {}" and
        eq3: "{1..n - Suc h} \<union> {n - h .. n} = {1..n}"
      using h kn by auto
    from eq[symmetric]
    have ?thesis using kn
      apply (simp add: binomial_fact[OF kn, where ?'a = 'a]
        gbinomial_pochhammer field_simps pochhammer_Suc_setprod)
      apply (simp add: pochhammer_Suc_setprod fact_altdef_nat h
        of_nat_setprod setprod_timesf[symmetric] eq' del: One_nat_def power_Suc)
      unfolding setprod_Un_disjoint[OF th0, unfolded eq3, of "of_nat:: nat \<Rightarrow> 'a"] eq[unfolded h]
      unfolding mult_assoc[symmetric]
      unfolding setprod_timesf[symmetric]
      apply simp
      apply (rule strong_setprod_reindex_cong[where f= "op - n"])
        apply (auto simp add: inj_on_def image_iff Bex_def)
       apply presburger
      apply (subgoal_tac "(of_nat (n - x) :: 'a) = of_nat n - of_nat x")
       apply simp
      apply (rule of_nat_diff)
      apply simp
      done
  }
  moreover
  have "k > n \<or> k = 0 \<or> (k \<le> n \<and> k \<noteq> 0)" by arith
  ultimately show ?thesis by blast
qed

lemma gbinomial_1[simp]: "a gchoose 1 = a"
  by (simp add: gbinomial_def)

lemma gbinomial_Suc0[simp]: "a gchoose (Suc 0) = a"
  by (simp add: gbinomial_def)

lemma gbinomial_mult_1:
  "a * (a gchoose n) =
    of_nat n * (a gchoose n) + of_nat (Suc n) * (a gchoose (Suc n))"  (is "?l = ?r")
proof -
  have "?r = ((- 1) ^n * pochhammer (- a) n / of_nat (fact n)) * (of_nat n - (- a + of_nat n))"
    unfolding gbinomial_pochhammer
      pochhammer_Suc fact_Suc of_nat_mult right_diff_distrib power_Suc
    by (simp add:  field_simps del: of_nat_Suc)
  also have "\<dots> = ?l" unfolding gbinomial_pochhammer
    by (simp add: field_simps)
  finally show ?thesis ..
qed

lemma gbinomial_mult_1':
    "(a gchoose n) * a = of_nat n * (a gchoose n) + of_nat (Suc n) * (a gchoose (Suc n))"
  by (simp add: mult_commute gbinomial_mult_1)

lemma gbinomial_Suc:
    "a gchoose (Suc k) = (setprod (\<lambda>i. a - of_nat i) {0 .. k}) / of_nat (fact (Suc k))"
  by (simp add: gbinomial_def)

lemma gbinomial_mult_fact:
  "(of_nat (fact (Suc k)) :: 'a) * ((a::'a::field_char_0) gchoose (Suc k)) =
    (setprod (\<lambda>i. a - of_nat i) {0 .. k})"
  by (simp_all add: gbinomial_Suc field_simps del: fact_Suc)

lemma gbinomial_mult_fact':
  "((a::'a::field_char_0) gchoose (Suc k)) * (of_nat (fact (Suc k)) :: 'a) =
    (setprod (\<lambda>i. a - of_nat i) {0 .. k})"
  using gbinomial_mult_fact[of k a]
  by (subst mult_commute)


lemma gbinomial_Suc_Suc:
  "((a::'a::field_char_0) + 1) gchoose (Suc k) = a gchoose k + (a gchoose (Suc k))"
proof (cases k)
  case 0
  then show ?thesis by simp
next
  case (Suc h)
  have eq0: "(\<Prod>i\<in>{1..k}. (a + 1) - of_nat i) = (\<Prod>i\<in>{0..h}. a - of_nat i)"
    apply (rule strong_setprod_reindex_cong[where f = Suc])
      using Suc
      apply auto
    done

  have "of_nat (fact (Suc k)) * (a gchoose k + (a gchoose (Suc k))) =
    ((a gchoose Suc h) * of_nat (fact (Suc h)) * of_nat (Suc k)) + (\<Prod>i\<in>{0\<Colon>nat..Suc h}. a - of_nat i)"
    apply (simp add: Suc field_simps del: fact_Suc)
    unfolding gbinomial_mult_fact'
    apply (subst fact_Suc)
    unfolding of_nat_mult
    apply (subst mult_commute)
    unfolding mult_assoc
    unfolding gbinomial_mult_fact
    apply (simp add: field_simps)
    done
  also have "\<dots> = (\<Prod>i\<in>{0..h}. a - of_nat i) * (a + 1)"
    unfolding gbinomial_mult_fact' setprod_nat_ivl_Suc
    by (simp add: field_simps Suc)
  also have "\<dots> = (\<Prod>i\<in>{0..k}. (a + 1) - of_nat i)"
    using eq0
    by (simp add: Suc setprod_nat_ivl_1_Suc)
  also have "\<dots> = of_nat (fact (Suc k)) * ((a + 1) gchoose (Suc k))"
    unfolding gbinomial_mult_fact ..
  finally show ?thesis by (simp del: fact_Suc)
qed


lemma binomial_symmetric:
  assumes kn: "k \<le> n"
  shows "n choose k = n choose (n - k)"
proof-
  from kn have kn': "n - k \<le> n" by arith
  from binomial_fact_lemma[OF kn] binomial_fact_lemma[OF kn']
  have "fact k * fact (n - k) * (n choose k) =
    fact (n - k) * fact (n - (n - k)) * (n choose (n - k))" by simp
  then show ?thesis using kn by simp
qed

(* Contributed by Manuel Eberl *)
(* Alternative definition of the binomial coefficient as \<Prod>i<k. (n - i) / (k - i) *)
lemma binomial_altdef_of_nat:
  fixes n k :: nat
    and x :: "'a :: {field_char_0,field_inverse_zero}"
  assumes "k \<le> n"
  shows "of_nat (n choose k) = (\<Prod>i<k. of_nat (n - i) / of_nat (k - i) :: 'a)"
proof (cases "0 < k")
  case True
  then have "(of_nat (n choose k) :: 'a) = (\<Prod>i<k. of_nat n - of_nat i) / of_nat (fact k)"
    unfolding binomial_gbinomial gbinomial_def
    by (auto simp: gr0_conv_Suc lessThan_Suc_atMost atLeast0AtMost)
  also have "\<dots> = (\<Prod>i<k. of_nat (n - i) / of_nat (k - i) :: 'a)"
    using `k \<le> n` unfolding fact_eq_rev_setprod_nat of_nat_setprod
    by (auto simp add: setprod_dividef intro!: setprod_cong of_nat_diff[symmetric])
  finally show ?thesis .
next
  case False
  then show ?thesis by simp
qed

lemma binomial_ge_n_over_k_pow_k:
  fixes k n :: nat
    and x :: "'a :: linordered_field_inverse_zero"
  assumes "0 < k"
    and "k \<le> n"
  shows "(of_nat n / of_nat k :: 'a) ^ k \<le> of_nat (n choose k)"
proof -
  have "(of_nat n / of_nat k :: 'a) ^ k = (\<Prod>i<k. of_nat n / of_nat k :: 'a)"
    by (simp add: setprod_constant)
  also have "\<dots> \<le> of_nat (n choose k)"
    unfolding binomial_altdef_of_nat[OF `k\<le>n`]
  proof (safe intro!: setprod_mono)
    fix i :: nat
    assume  "i < k"
    from assms have "n * i \<ge> i * k" by simp
    then have "n * k - n * i \<le> n * k - i * k" by arith
    then have "n * (k - i) \<le> (n - i) * k"
      by (simp add: diff_mult_distrib2 nat_mult_commute)
    then have "of_nat n * of_nat (k - i) \<le> of_nat (n - i) * (of_nat k :: 'a)"
      unfolding of_nat_mult[symmetric] of_nat_le_iff .
    with assms show "of_nat n / of_nat k \<le> of_nat (n - i) / (of_nat (k - i) :: 'a)"
      using `i < k` by (simp add: field_simps)
  qed (simp add: zero_le_divide_iff)
  finally show ?thesis .
qed

lemma binomial_le_pow:
  assumes "r \<le> n"
  shows "n choose r \<le> n ^ r"
proof -
  have "n choose r \<le> fact n div fact (n - r)"
    using `r \<le> n` by (subst binomial_fact_lemma[symmetric]) auto
  with fact_div_fact_le_pow [OF assms] show ?thesis by auto
qed

lemma binomial_altdef_nat: "(k::nat) \<le> n \<Longrightarrow>
    n choose k = fact n div (fact k * fact (n - k))"
 by (subst binomial_fact_lemma [symmetric]) auto

end
