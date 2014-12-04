Require Import Causality.
Require Import Advance.
Require Import FunctionalExtensionality.
Require Import Tactics.

(* Contextual syntactic causality. This syntactic notion of causality
is more permissive than plain syntactic causality. However, the
causality property that follows from this syntactic notion of
causality is slightly weaker. *)

Open Scope Z.


Definition TimeEnv := list Z.


Inductive CausalV : TimeEnv -> Z -> Var -> Prop :=
| time_var_1 t t' g  : t <= t' -> CausalV (t :: g) t' V1
| time_var_S g v t t' : CausalV g t v -> CausalV (t' :: g) t (VS v).


(* Lemma CausalV_open t t' ts ts' (v : Var) : forall_zip Z.le ts' ts -> t <= t' -> CausalV ts t v -> CausalV ts' t' v. *)
(* Proof. *)
(*   intros Is I P. generalize dependent t. generalize dependent t'. generalize dependent ts. generalize dependent ts'. *)
(*   induction v; intros; inversion P; subst. *)
(*   - inversion Is. subst. constructor. omega. *)
(*   - inversion Is. subst. constructor. eauto. *)
(* Qed. *)

Inductive CausalE : TimeEnv -> Z -> Exp -> Prop:= 
 | ce_op t ts op args : forall_list (CausalE ts t) args -> CausalE ts t (OpE op args)
 | ce_obs l t' t ts : t' <= t -> CausalE ts t (Obs l t')
 | ce_var t ts v : CausalV ts t v -> CausalE ts t (VarE v)
 | ce_acc t ts e1 e2 n : CausalE ts (t + Z.of_nat n) e2 -> CausalE ts t e1 -> CausalE ts t (Acc e1 n e2)
  .



Lemma CausalE_open t t' ts (e : Exp) : t <= t' -> CausalE ts t e -> CausalE ts t' e.
Proof.
  intros I P. generalize dependent t. generalize dependent t'. generalize dependent ts.
  induction e using Exp_ind'; intros;inversion P;subst;constructor.
  - induction args.
    * constructor.
    * inversion H3. inversion H. subst. constructor. eauto. apply IHargs. auto. constructor. auto. auto.
  - omega.
  - eapply CausalV_open; eauto.
  - eapply IHe2; eauto. omega.
  - eapply IHe1; eauto. 
Qed.


Reserved Notation "d 'B|-' c" (at level 20).

Inductive bpc : forall {V}, Z -> bexp' V -> Prop:=
| bpc_lit : forall V d b, d B|- BLit b (V:=V)
| rpc_ch : forall V d ch i, i <= d -> d B|- BChoice ch i (V:=V)
| bpc_cmp : forall V cmp (e1 e2 : rexp) d, d R|- e1 -> d R|- e2 -> d B|- RCmp cmp e1 e2 (V:=V)
| bpc_op : forall V op e1 e2 d, d B|- e1 -> d B|- e2 -> d B|- BOp op e1 e2 (V:=V)
| bpc_not : forall V e d, d B|- e -> d B|- BNot e (V:=V)
| bpc_var : forall d V q, d B|- BVar q (V:=V)
| bpc_acc : forall d V f m z, d  B|- f -> d B|- z -> d B|- BAcc f m z (V:=V)
                                         where "d 'B|-' e" := (bpc d e). 


Definition oplus (n : nat) : option nat -> option nat := option_map (plus n).
Lemma oplus_0 d : oplus 0 d = d.
Proof.
  destruct d; reflexivity.
Qed.
Definition omin (m n : option nat) : option nat := 
  match m with
      | Some m' => match n with
                     | Some n' => Some (min m' n')
                     | None => m
                   end
      | None => n
  end.

Open Scope nat.                  
   
Definition ole (m : nat) (n : option nat) : Prop := 
  match n with
     | Some n' => m <= n'
     | _ => True
  end.

Definition olt (m : nat) (n : option nat) : Prop := 
  match n with
     | Some n' => m < n'
     | _ => True
  end.

Reserved Notation "d '|-' c" (at level 20).

Inductive pc : option nat -> contract -> Prop :=
| pc_transl : forall d c b, b |- c -> oplus d b |- Transl d c
| pc_transf : forall cur p1 p2, Some 0 |- TransfOne cur p1 p2
| pc_scale : forall (e : rexp) c b d, ole d b ->  (Z.of_nat d) R|- e -> b |- c -> b |- Scale e c
| pc_both : forall c1 c2 d1 d2, d1 |- c1 -> d2 |- c2 -> omin d1 d2 |- Both c1 c2
| pc_zero : None |- Zero
| pc_if : forall c1 c2 b l d1 d2, 0 B|- b -> d1 |- c1 -> d2 |- c2 
                                     -> omin d1 (oplus l d2) |-  IfWithin b l c1 c2
                                            where "d '|-' c" := (pc d c). 



Open Scope Z.

Lemma rpc_inp_until' V (vars : Env (option R) V) (e : rexp' V) d r1 r2 : 
  d R|-e  -> inp_until d r1 r2 -> R'[|e|] vars r1 = R'[|e|] vars r2.
Proof.
  intros R. generalize dependent r1. generalize dependent r2. 
  induction R; intros r2 r1 O; simpl; try solve [f_equal; auto].

  unfold inp_until in O. simpl. rewrite O. reflexivity. auto.
  remember (adv_inp (- Z.of_nat m) r1) as r1'.
  remember (adv_inp (- Z.of_nat m) r2) as r2'.
  assert (inp_until (Z.of_nat m + d) r1' r2') as I.
  subst. rewrite inp_until_adv. 
  assert (- Z.of_nat m + (Z.of_nat m + d) = d) as L.
  omega. rewrite L. assumption.
  clear Heqr1' Heqr2'.

  induction m.
  - simpl. auto.
  - simpl. rewrite IHm. apply  IHR1. rewrite inp_until_adv.
    eapply inp_until_le. eassumption.
    rewrite Nat2Z.inj_succ. rewrite Zpos_P_of_succ_nat. omega.
    eapply inp_until_le. apply I. rewrite Nat2Z.inj_succ.  omega.
Qed.

Corollary rpc_inp_until (e : rexp) d r1 r2 : 
  d R|-e  -> inp_until d r1 r2 -> R[|e|] r1 = R[|e|] r2.
Proof. apply rpc_inp_until'. Qed.

Lemma bpc_ext_until {V} (e : bexp' V) d vars r1 r2 :
  d B|-e -> ext_until d r1 r2 -> B'[|e|] vars r1 = B'[|e|] vars r2.
Proof.
  intros R O. generalize dependent r1. generalize dependent r2. 
  induction R; intros; simpl; try solve [f_equal; auto].
  - destruct O. unfold inp_until in *. rewrite H1. reflexivity.
    remember (0 <=? i)%Z as L. omega. 
  - destruct O. 
    eapply rpc_inp_until in H.
    eapply rpc_inp_until in H0. rewrite H. rewrite H0.
    reflexivity. auto. auto.
  - remember (adv_ext (- Z.of_nat m) r1) as r1'.
    remember (adv_ext (- Z.of_nat m) r2) as r2'.
    assert (ext_until (Z.of_nat m + d) r1' r2') as I.
    subst. rewrite ext_until_adv. 
    assert (- Z.of_nat m + (Z.of_nat m + d) = d) as L.
    omega. rewrite L. assumption.
    clear Heqr1' Heqr2'. 
    induction m.
    + simpl. auto.
    + simpl. rewrite IHm. apply  IHR1. rewrite ext_until_adv.
      eapply ext_until_le. eassumption.
      rewrite Nat2Z.inj_succ. rewrite Zpos_P_of_succ_nat. omega.
      eapply ext_until_le. apply I. rewrite Nat2Z.inj_succ.  omega.  
Qed.

Lemma delay_trace_empty d : delay_trace d (const_trace empty_trans) = const_trace empty_trans.
Proof.
  apply functional_extensionality. intros. unfold delay_trace, const_trace.
  remember (leb d x) as L. destruct L; reflexivity.
Qed.

Open Scope nat.                  

Definition wcausal (c : contract) : Prop :=
  forall d r1 r2,  ext_until (Z.of_nat d) r1 r2 -> 
                   (C[|c|]r1) d = None \/ (C[|c|]r2) d = None \/ (C[|c|]r1) d = (C[|c|]r2) d.

Lemma rpc_indep' c r d N : N = None -> 
                            N |- c -> (C[|c|]r) d = None \/ (C[|c|]r) d = empty_trans.
Proof.
  assert (@None nat = None) as NeN by auto.
  intros NN H. generalize dependent r. generalize dependent d. induction H; intros.
  
  destruct b. inversion NN. 
  simpl. unfold delay_trace. remember (leb d d0) as L.
  destruct L. 
  pose (IHpc NeN (d0 - d) (adv_ext (Z.of_nat d) r)) as IH. destruct IH; auto.
  auto.

  inversion NN.

  simpl. pose (IHpc NN d0 r) as IH. destruct IH. left.
  destruct (R[|e|](fst r)); simpl. rewrite H2. reflexivity. reflexivity.
  destruct (R[|e|](fst r)); simpl. rewrite H2. simpl. right. apply scale_empty_trans. auto.

  simpl. destruct d1; destruct d2; try inversion NN.
  
  pose (IHpc1 NeN d r) as IH1. pose (IHpc2 NeN d r) as IH2. unfold add_trace.
  destruct IH1. left. rewrite H1. reflexivity.
  destruct IH2. left. rewrite H2. destruct (C[|c1|] r d); reflexivity.
  right.  rewrite H1. rewrite H2. auto.

  right. reflexivity.

  simpl. destruct d1; destruct d2; try inversion NN.

  pose (IHpc1 NeN d r) as IH1. pose (IHpc2 NeN d r) as IH2. 
  generalize dependent r. generalize dependent d.
  induction l; intros; simpl; remember (B[|b|]r) as bl; destruct bl.
  destruct b0. destruct IH1; auto. destruct IH2; auto.
  left. reflexivity. destruct b0. destruct IH1; auto. unfold delay_trace.
  remember (leb 1 d) as L. destruct L. apply IHl. reflexivity. auto. auto.
Qed.
  
Lemma olt_omin d d1 d2 : olt d (omin d1 d2) -> olt d d1 /\ olt d d2.
Proof.
  intros. destruct d1; destruct d2; simpl in *; try auto.
  unfold "<" in *. split. eapply Min.min_glb_l. eauto.
  eapply Min.min_glb_r. eauto.
Qed.

Lemma olt_minus d b : olt d b -> olt (d-1) b.
Proof.
  intros. destruct b; simpl in *. omega. auto.
Qed.



Lemma rpc_indep c r d B :  B |- c -> olt d B -> (C[|c|]r) d = None \/ (C[|c|]r) d = empty_trans.
Proof.
  intros H. generalize dependent r. generalize dependent d.
  induction H; intros; simpl in *.
  
  unfold delay_trace. remember (leb d d0) as L. destruct L.
  simpl. apply IHpc. destruct b; simpl in *. symmetry in HeqL. 
  apply leb_complete in HeqL. omega. auto. 

  auto.

  unfold singleton_trace. inversion H.

  unfold scale_trace, scale_trans, compose. 
  pose (IHpc d0 r H2) as IH.
  destruct IH as [IH|IH]. left. rewrite IH. apply option_map2_none.
  rewrite IH. remember (R[|e|](fst r)) as R. destruct R. simpl. right. apply scale_empty_trans.
  left. reflexivity.

  apply olt_omin in H1. destruct H1. eapply IHpc1 in H1.
  eapply IHpc2 in H2. unfold add_trace. destruct H1.
  left. erewrite H1. reflexivity. destruct H2.
  left. erewrite H2. apply option_map2_none.
  right. rewrite H1. rewrite H2. auto.

  auto.

  apply olt_omin in H2. destruct H2.
  pose (IHpc1 d r H2) as IH1. 
  generalize dependent r. generalize dependent d.
  induction l; intros; simpl; remember (B[|b|]r) as bl; destruct bl.
  destruct b0. destruct IH1; auto. 
  rewrite oplus_0 in H3. apply IHpc2. assumption.
  auto. destruct b0. destruct IH1; auto. unfold delay_trace.
  remember (leb 1 d) as L. destruct L. pose (olt_minus _ _ H2) as H2'.
  apply IHl with (H2:=H2'). destruct d2; simpl in *. destruct d. tryfalse. 
  omega. auto. auto. auto.
Qed.

Lemma ole_olt d b : ole d b -> olt d b \/ b = Some d.
Proof.
  intros. destruct b; simpl in *. apply le_lt_or_eq in H. destruct H; auto. auto.
Qed.

Lemma ole_lt a b c : a < b -> ole b c -> olt a c.
Proof.
  intros. destruct c; simpl in *. omega. auto.
Qed.

Lemma le_dle a b c : a <= b -> ole b c -> ole a c.
Proof.
  intros. destruct c; simpl in *. omega. auto.
Qed.


Theorem pc_causal d c : d |- c -> wcausal c.
Proof.
  intros. induction H; unfold wcausal in *; intros; simpl.

  unfold delay_trace.
  remember (leb d d0) as C. destruct C.
    symmetry in HeqC. apply leb_complete in HeqC.
    apply IHpc. rewrite ext_until_adv. assert (Z.of_nat d + Z.of_nat (d0 - d) = Z.of_nat d0)%Z as D.
    rewrite <- Nat2Z.inj_add. f_equal. omega.
    rewrite D. assumption. auto.
    
    auto.
    
  unfold scale_trace, scale_trans, compose. 
  remember (R[|e|](fst r1)) as R1; remember (R[|e|](fst r2)) as R2; 
  destruct R1; destruct R2; try auto. 
  remember (leb d d0) as D. symmetry in HeqD. destruct D. rewrite leb_iff in HeqD.
  inversion H2 as [H2' H2'']. apply inj_le in HeqD.
  pose (inp_until_le _ _ _ _ H2' HeqD ) as O.
  pose (IHpc _ _ _ H2) as IH. destruct IH. left.
  rewrite H3. reflexivity. destruct H3. right. left. rewrite H3.
  reflexivity. right. right. rewrite H3. simpl. 
  remember (C[|c|] r2 d0) as C. destruct C; try reflexivity. 
  pose (rpc_inp_until e _ (fst r1) (fst r2) H0 O) as RE. rewrite RE in HeqR1. rewrite <- HeqR1 in HeqR2.
  inversion_clear HeqR2. reflexivity.
  
  rewrite leb_iff_conv in HeqD.
  eapply ole_lt in H; try apply HeqD. pose (rpc_indep c r2 d0 _ H1 H) as P. destruct P.
  right. left. rewrite H3. apply option_map2_none. pose (rpc_indep c r1 d0 _ H1 H) as P.
  destruct P. left. rewrite H4. apply option_map2_none. right. right.
  rewrite H3. rewrite H4. do 2 rewrite scale_empty_trans. reflexivity.

  unfold add_trace, add_trans. 
  pose (IHpc1 d r1 r2 H1) as IH1. pose (IHpc2 d r1 r2 H1) as IH2.
  destruct IH1; first [rewrite H2| destruct H2; rewrite H2; auto]; auto.
  destruct IH2. rewrite H3. left. apply option_map2_none. destruct H3.
  rewrite H3. right. left. apply option_map2_none. right. right. rewrite H3.
  reflexivity.

  auto.

  assert (ext_until 0 r1 r2). eapply ext_until_le. eassumption. omega. 
  generalize dependent d. generalize dependent r1. generalize dependent r2. 
  induction l; intros; simpl.
  
 
  erewrite bpc_ext_until by eassumption. 
  remember (B[|b|]r2) as bl. destruct bl. destruct b0. eapply IHpc1; eassumption. 
  eapply IHpc2; eassumption. auto.

  erewrite bpc_ext_until by eassumption.
  remember (B[|b|]r2) as bl. destruct bl. destruct b0.  eapply IHpc1; eassumption. 
  unfold delay_trace. remember (leb 1 d) as L. destruct L. 
  symmetry in HeqL. rewrite leb_iff in HeqL. apply IHl. apply ext_until_adv. simpl.  
  apply inj_le in HeqL. eapply ext_until_le; eassumption. rewrite Nat2Z.inj_sub. apply ext_until_adv_1.
  apply inj_le in HeqL. assumption. auto. auto. auto. auto.
Qed.
