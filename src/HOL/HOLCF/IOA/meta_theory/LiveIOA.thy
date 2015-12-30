(*  Title:      HOL/HOLCF/IOA/meta_theory/LiveIOA.thy
    Author:     Olaf Müller
*)

section \<open>Live I/O automata -- specified by temproal formulas\<close>

theory LiveIOA
imports TLS
begin

default_sort type

type_synonym
  ('a, 's) live_ioa = "('a,'s)ioa * ('a,'s)ioa_temp"

definition
  validLIOA :: "('a,'s)live_ioa => ('a,'s)ioa_temp  => bool" where
  "validLIOA AL P = validIOA (fst AL) ((snd AL) \<^bold>\<longrightarrow> P)"

definition
  WF :: "('a,'s)ioa => 'a set => ('a,'s)ioa_temp" where
  "WF A acts = (\<diamond>\<box>\<langle>%(s,a,t). Enabled A acts s\<rangle> \<^bold>\<longrightarrow> \<box>\<diamond>\<langle>xt2 (plift (%a. a : acts))\<rangle>)"
definition
  SF :: "('a,'s)ioa => 'a set => ('a,'s)ioa_temp" where
  "SF A acts = (\<box>\<diamond>\<langle>%(s,a,t). Enabled A acts s\<rangle> \<^bold>\<longrightarrow> \<box>\<diamond>\<langle>xt2 (plift (%a. a : acts))\<rangle>)"

definition
  liveexecutions :: "('a,'s)live_ioa => ('a,'s)execution set" where
  "liveexecutions AP = {exec. exec : executions (fst AP) & (exec \<TTurnstile> (snd AP))}"
definition
  livetraces :: "('a,'s)live_ioa => 'a trace set" where
  "livetraces AP = {mk_trace (fst AP)$(snd ex) | ex. ex:liveexecutions AP}"
definition
  live_implements :: "('a,'s1)live_ioa => ('a,'s2)live_ioa => bool" where
  "live_implements CL AM = ((inp (fst CL) = inp (fst AM)) &
                            (out (fst CL) = out (fst AM)) &
                            livetraces CL <= livetraces AM)"
definition
  is_live_ref_map :: "('s1 => 's2) => ('a,'s1)live_ioa => ('a,'s2)live_ioa => bool" where
  "is_live_ref_map f CL AM =
           (is_ref_map f (fst CL ) (fst AM) &
            (! exec : executions (fst CL). (exec \<TTurnstile> (snd CL)) -->
                                           ((corresp_ex (fst AM) f exec) \<TTurnstile> (snd AM))))"


lemma live_implements_trans:
"!!LC. [| live_implements (A,LA) (B,LB); live_implements (B,LB) (C,LC) |]
      ==> live_implements (A,LA) (C,LC)"
apply (unfold live_implements_def)
apply auto
done


subsection "Correctness of live refmap"

lemma live_implements: "[| inp(C)=inp(A); out(C)=out(A);
                   is_live_ref_map f (C,M) (A,L) |]
                ==> live_implements (C,M) (A,L)"
apply (simp add: is_live_ref_map_def live_implements_def livetraces_def liveexecutions_def)
apply auto
apply (rule_tac x = "corresp_ex A f ex" in exI)
apply auto
  (* Traces coincide, Lemma 1 *)
  apply (tactic \<open>pair_tac @{context} "ex" 1\<close>)
  apply (erule lemma_1 [THEN spec, THEN mp])
  apply (simp (no_asm) add: externals_def)
  apply (auto)[1]
  apply (simp add: executions_def reachable.reachable_0)

  (* corresp_ex is execution, Lemma 2 *)
  apply (tactic \<open>pair_tac @{context} "ex" 1\<close>)
  apply (simp add: executions_def)
  (* start state *)
  apply (rule conjI)
  apply (simp add: is_ref_map_def corresp_ex_def)
  (* is-execution-fragment *)
  apply (erule lemma_2 [THEN spec, THEN mp])
  apply (simp add: reachable.reachable_0)

done

end
