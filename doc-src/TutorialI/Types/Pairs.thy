(*<*)theory Pairs = Main:(*>*)

section{*Pairs*}

text{*\label{sec:products}
Pairs were already introduced in \S\ref{sec:pairs}, but only with a minimal
repertoire of operations: pairing and the two projections @{term fst} and
@{term snd}. In any nontrivial application of pairs you will find that this
quickly leads to unreadable formulae involvings nests of projections. This
section is concerned with introducing some syntactic sugar to overcome this
problem: pattern matching with tuples.
*}

subsection{*Notation*}

text{*
It is possible to use (nested) tuples as patterns in $\lambda$-abstractions,
for example @{text"\<lambda>(x,y,z).x+y+z"} and @{text"\<lambda>((x,y),z).x+y+z"}. In fact,
tuple patterns can be used in most variable binding constructs. Here are
some typical examples:
\begin{quote}
@{term"let (x,y) = f z in (y,x)"}\\
@{term"case xs of [] => 0 | (x,y)#zs => x+y"}\\
@{text"\<forall>(x,y)\<in>A. x=y"}\\
@{text"{(x,y). x=y}"}\\
@{term"\<Union>(x,y)\<in>A. {x+y}"}
\end{quote}
*}

text{*
The intuitive meaning of this notations should be pretty obvious.
Unfortunately, we need to know in more detail what the notation really stands
for once we have to reason about it. The fact of the matter is that abstraction
over pairs and tuples is merely a convenient shorthand for a more complex
internal representation.  Thus the internal and external form of a term may
differ, which can affect proofs. If you want to avoid this complication,
stick to @{term fst} and @{term snd} and write @{term"%p. fst p + snd p"}
instead of @{text"\<lambda>(x,y). x+y"} (which denote the same function but are quite
different terms).

Internally, @{term"%(x,y). t"} becomes @{text"split (\<lambda>x y. t)"}, where
@{term split} is the uncurrying function of type @{text"('a \<Rightarrow> 'b
\<Rightarrow> 'c) \<Rightarrow> 'a \<times> 'b \<Rightarrow> 'c"} defined as
\begin{center}
@{thm split_def}
\hfill(@{thm[source]split_def})
\end{center}
Pattern matching in
other variable binding constructs is translated similarly. Thus we need to
understand how to reason about such constructs.
*}

subsection{*Theorem proving*}

text{*
The most obvious approach is the brute force expansion of @{term split}:
*}

lemma "(\<lambda>(x,y).x) p = fst p"
by(simp add:split_def)

text{* This works well if rewriting with @{thm[source]split_def} finishes the
proof, as in the above lemma. But if it doesn't, you end up with exactly what
we are trying to avoid: nests of @{term fst} and @{term snd}. Thus this
approach is neither elegant nor very practical in large examples, although it
can be effective in small ones.

If we step back and ponder why the above lemma presented a problem in the
first place, we quickly realize that what we would like is to replace @{term
p} with some concrete pair @{term"(a,b)"}, in which case both sides of the
equation would simplify to @{term a} because of the simplification rules
@{thm Product_Type.split[no_vars]} and @{thm fst_conv[no_vars]}.  This is the
key problem one faces when reasoning about pattern matching with pairs: how to
convert some atomic term into a pair.

In case of a subterm of the form @{term"split f p"} this is easy: the split
rule @{thm[source]split_split} replaces @{term p} by a pair:
*}

lemma "(\<lambda>(x,y).y) p = snd p"
apply(simp only: split:split_split);

txt{*
@{subgoals[display,indent=0]}
This subgoal is easily proved by simplification. The @{text"only:"} above
merely serves to show the effect of splitting and to avoid solving the goal
outright.

Let us look at a second example:
*}

(*<*)by simp(*>*)
lemma "let (x,y) = p in fst p = x";
apply(simp only:Let_def)

txt{*
@{subgoals[display,indent=0]}
A paired @{text let} reduces to a paired $\lambda$-abstraction, which
can be split as above. The same is true for paired set comprehension:
*}

(*<*)by(simp split:split_split)(*>*)
lemma "p \<in> {(x,y). x=y} \<longrightarrow> fst p = snd p"
apply simp

txt{*
@{subgoals[display,indent=0]}
Again, simplification produces a term suitable for @{thm[source]split_split}
as above. If you are worried about the funny form of the premise:
@{term"split (op =)"} is the same as @{text"\<lambda>(x,y). x=y"}.
The same procedure works for
*}

(*<*)by(simp split:split_split)(*>*)
lemma "p \<in> {(x,y). x=y} \<Longrightarrow> fst p = snd p"

txt{*\noindent
except that we now have to use @{thm[source]split_split_asm}, because
@{term split} occurs in the assumptions.

However, splitting @{term split} is not always a solution, as no @{term split}
may be present in the goal. Consider the following function:
*}

(*<*)by(simp split:split_split_asm)(*>*)
consts swap :: "'a \<times> 'b \<Rightarrow> 'b \<times> 'a"
primrec
  "swap (x,y) = (y,x)"

text{*\noindent
Note that the above \isacommand{primrec} definition is admissible
because @{text"\<times>"} is a datatype. When we now try to prove
*}

lemma "swap(swap p) = p"

txt{*\noindent
simplification will do nothing, because the defining equation for @{term swap}
expects a pair. Again, we need to turn @{term p} into a pair first, but this
time there is no @{term split} in sight. In this case the only thing we can do
is to split the term by hand:
*}
apply(case_tac p)

txt{*\noindent
@{subgoals[display,indent=0]}
Again, @{text case_tac} is applicable because @{text"\<times>"} is a datatype.
The subgoal is easily proved by @{text simp}.

In case the term to be split is a quantified variable, there are more options.
You can split \emph{all} @{text"\<And>"}-quantified variables in a goal
with the rewrite rule @{thm[source]split_paired_all}:
*}

(*<*)by simp(*>*)
lemma "\<And>p q. swap(swap p) = q \<longrightarrow> p = q"
apply(simp only:split_paired_all)

txt{*\noindent
@{subgoals[display,indent=0]}
*}

apply simp
done

text{*\noindent
Note that we have intentionally included only @{thm[source]split_paired_all}
in the first simplification step. This time the reason was not merely
pedagogical:
@{thm[source]split_paired_all} may interfere with certain congruence
rules of the simplifier, i.e.
*}

(*<*)
lemma "\<And>p q. swap(swap p) = q \<longrightarrow> p = q"
(*>*)
apply(simp add:split_paired_all)
(*<*)done(*>*)
text{*\noindent
may fail (here it does not) where the above two stages succeed.

Finally, all @{text"\<forall>"} and @{text"\<exists>"}-quantified variables are split
automatically by the simplifier:
*}

lemma "\<forall>p. \<exists>q. swap p = swap q"
apply simp;
done

text{*\noindent
In case you would like to turn off this automatic splitting, just disable the
responsible simplification rules:
\begin{center}
@{thm split_paired_All}
\hfill
(@{thm[source]split_paired_All})\\
@{thm split_paired_Ex}
\hfill
(@{thm[source]split_paired_Ex})
\end{center}
*}
(*<*)
end
(*>*)
