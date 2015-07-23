(*  Title:      FOL/ex/Intro.thy
    Author:     Lawrence C Paulson, Cambridge University Computer Laboratory
    Copyright   1992  University of Cambridge

Derives some inference rules, illustrating the use of definitions.
*)

section \<open>Examples for the manual ``Introduction to Isabelle''\<close>

theory Intro
imports FOL
begin

subsubsection \<open>Some simple backward proofs\<close>

lemma mythm: "P|P --> P"
apply (rule impI)
apply (rule disjE)
prefer 3 apply (assumption)
prefer 2 apply (assumption)
apply assumption
done

lemma "(P & Q) | R --> (P | R)"
apply (rule impI)
apply (erule disjE)
apply (drule conjunct1)
apply (rule disjI1)
apply (rule_tac [2] disjI2)
apply assumption+
done

(*Correct version, delaying use of "spec" until last*)
lemma "(ALL x y. P(x,y)) --> (ALL z w. P(w,z))"
apply (rule impI)
apply (rule allI)
apply (rule allI)
apply (drule spec)
apply (drule spec)
apply assumption
done


subsubsection \<open>Demonstration of @{text "fast"}\<close>

lemma "(EX y. ALL x. J(y,x) <-> ~J(x,x))
        -->  ~ (ALL x. EX y. ALL z. J(z,y) <-> ~ J(z,x))"
apply fast
done


lemma "ALL x. P(x,f(x)) <->
        (EX y. (ALL z. P(z,y) --> P(z,f(x))) & P(x,y))"
apply fast
done


subsubsection \<open>Derivation of conjunction elimination rule\<close>

lemma
  assumes major: "P&Q"
    and minor: "[| P; Q |] ==> R"
  shows R
apply (rule minor)
apply (rule major [THEN conjunct1])
apply (rule major [THEN conjunct2])
done


subsection \<open>Derived rules involving definitions\<close>

text \<open>Derivation of negation introduction\<close>

lemma
  assumes "P ==> False"
  shows "~ P"
apply (unfold not_def)
apply (rule impI)
apply (rule assms)
apply assumption
done

lemma
  assumes major: "~P"
    and minor: P
  shows R
apply (rule FalseE)
apply (rule mp)
apply (rule major [unfolded not_def])
apply (rule minor)
done

text \<open>Alternative proof of the result above\<close>
lemma
  assumes major: "~P"
    and minor: P
  shows R
apply (rule minor [THEN major [unfolded not_def, THEN mp, THEN FalseE]])
done

end
