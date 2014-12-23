Require Export Bool.
Require Export Reals.
Require Export Syntax.
Require Export Utils.
Require Export Tactics.
Open Scope R.

Module FMap.

Parameter FMap : Type.

Definition key := (Party * Party * Asset)%type.

Definition key_eqb (k1 k2 : key) : bool := match k1, k2 with (p1,p1',a1), (p2,p2',a2) =>
                                           Party.eqb p1 p2 && Party.eqb p1' p2' && Asset.eqb a1 a2 end.

Lemma key_eqb_eq k1 k2: key_eqb k1 k2 = true <-> k1 = k2.
Proof. 
  unfold key_eqb. destruct k1, k2. destruct p, p0. simpl. split;intros.
  repeat rewrite andb_true_iff in H. decompose [and] H. 
  rewrite Party.eqb_eq in *. rewrite Asset.eqb_eq in *. subst. reflexivity.
  repeat rewrite andb_true_iff. inversion H. 
  repeat split; first [rewrite Party.eqb_eq|rewrite Asset.eqb_eq]; reflexivity.
Qed.

Lemma key_eqb_eq_false k1 k2: key_eqb k1 k2 = false <-> k1 <> k2.
Proof.
  split;intros. intro E. apply key_eqb_eq in E. rewrite E in H. inversion H.
  cases (key_eqb k1 k2). apply key_eqb_eq in Eq. tryfalse. reflexivity.
Qed.


Hint Resolve key_eqb_eq key_eqb_eq_false.

Parameter empty : FMap.

Parameter is_empty : FMap -> bool.

Parameter add : key -> R -> FMap -> FMap.

Parameter find : key -> FMap -> option R.

Parameter map : (R -> R) -> FMap -> FMap.

Parameter union_with : (R -> R -> option R) -> FMap -> FMap -> FMap.

Definition singleton k  r : FMap := add k r empty.


Axiom extensionality : forall m1 m2, (forall k, find k m1 = find k m2) -> m1 = m2.

Axiom empty_find : forall k, find k empty = None.

Axiom empty_is_empty : forall m, is_empty m = true <-> m = empty.

Axiom add_find_new : forall k v m, find k (add k v m) = Some v.

Axiom add_find_old : forall k k' v' m, k <> k' -> find k (add k' v' m) = find k m.

Axiom map_find : forall k m f,  find k (map f m) = liftM f (find k m).

Axiom union_find : forall k m1 m2 f,  
                         find k (union_with f m1 m2) = match find k m1, find k m2 with
                                                          | Some v1, Some v2 => f v1 v2
                                                          | Some v1, None => Some v1
                                                          | None, Some v2 => Some v2
                                                          | None, None => None
                                                      end.

Lemma empty_find' m : (forall k, find k m = None) -> m = empty.
Proof.
  intro A. apply extensionality. intro. rewrite empty_find. auto.
Qed.

Lemma map_empty f : map f empty = empty.
Proof.
  apply extensionality. intro. rewrite map_find. rewrite empty_find. reflexivity.
Qed.

Lemma union_empty f : union_with f empty empty = empty.
Proof.
  apply extensionality. intro. rewrite union_find. rewrite empty_find. reflexivity.
Qed.


Lemma union_empty_l f m : union_with f m empty = m.
Proof.
  apply extensionality. intro. rewrite union_find. rewrite empty_find. destruct (find k m) ;reflexivity.
Qed.

Lemma union_empty_r f m : union_with f empty m = m.
Proof.
  apply extensionality. intro. rewrite union_find. rewrite empty_find. destruct (find k m) ;reflexivity.
Qed.

Lemma find_singleton1 k k' r r' : find k (singleton k' r) = Some r' -> k' = k.
Proof.
  unfold singleton. intros. cases (key_eqb k' k). rewrite key_eqb_eq in Eq. assumption.
  rewrite add_find_old in H. rewrite empty_find in H. inversion H.
  apply not_eq_sym. apply key_eqb_eq_false. auto.
Qed.
Lemma find_singleton2 k k' r r' : find k (singleton k' r) = Some r' -> r' = r.
Proof.
  intro H. pose H as H'. apply find_singleton1 in H'. subst. unfold singleton in H. rewrite add_find_new in H.
  inversion H. reflexivity.
Qed.

Lemma find_singleton k k' r r' : find k (singleton k' r) = Some r' -> k' = k /\ r' = r .
Proof.
  intros. split; eauto using find_singleton1,find_singleton2.
Qed.



Lemma find_singleton_not k k' r : find k (singleton k' r) = None -> k' <> k.
Proof.
  unfold singleton. intros. cases (key_eqb k' k). rewrite key_eqb_eq in Eq. 
  subst. rewrite add_find_new in H.  inversion H. apply key_eqb_eq_false. auto.
Qed.

End FMap.

Parameter compare : Party -> Party -> comparison.
Axiom compare_eq : forall p1 p2, compare p1 p2 = Eq <-> p1 = p2.
Axiom compare_lt_gt : forall p1 p2, compare p1 p2 = Lt <-> compare p2 p1 = Gt.


Module SMap.
  Definition SMap := FMap.FMap.

  Definition add p1 p2 a v m := match compare p1 p2 with
                                | Lt => FMap.add (p1,p2,a) v m
                                | Gt => FMap.add (p2,p1,a) (-v) m
                                | Eq => m
                              end.

  Definition empty := FMap.empty.
  Definition find p1 p2 a m := match compare p1 p2 with
                                 | Lt => default 0 (FMap.find (p1,p2,a) m)
                                 | Gt => match FMap.find (p2,p1,a) m with
                                             | Some r => - r
                                             | None => 0
                                         end
                                 | Eq => 0
                               end.

  Definition map := FMap.map.
  Definition union_with f := FMap.union_with (fun x y => let r := f x y
                                                        in if Reqb r 0 then None else Some r) .

  Definition singleton p1 p2 a r := match compare p1 p2 with
                                | Lt => FMap.singleton (p1,p2,a) r
                                | Gt => FMap.singleton (p2,p1,a) (-r)
                                | Eq => FMap.empty
                              end.

  Definition is_empty := FMap.is_empty.

  Lemma empty_is_empty m : is_empty m = true <-> m = empty.
  Proof.
    unfold is_empty, empty. apply FMap.empty_is_empty.
  Qed.

  Lemma empty_is_empty': is_empty empty = true.
  Proof.
    rewrite empty_is_empty. reflexivity.
  Qed.


  Lemma empty_find : forall p1 p2 a, find p1 p2 a empty = 0.
  Proof.
    intros. unfold find. destruct (compare p1 p2); try rewrite FMap.empty_find; reflexivity. 
  Qed.

  Definition Compact m := (forall p1 p2 a, FMap.find (p1, p2, a) m <> Some 0) /\ 
                          (forall p1 p2 a, compare p1 p2 <> Lt -> FMap.find (p1,p2,a) m = None).
  
  Lemma compact_empty : Compact empty.
  Proof. 
    unfold Compact,empty. split. intros. rewrite FMap.empty_find. intro C. inversion C.
    intros. apply FMap.empty_find.
  Qed.

  Lemma compact_singleton p1 p2 a r : r <> 0 -> Compact (singleton p1 p2 a r).
  Proof.
    unfold Compact, singleton. intros. 
    cases (compare p1 p2). split. intros. rewrite FMap.empty_find. intro C. inversion C. 
    intros. apply FMap.empty_find.
    split;intros.
    intro C. apply FMap.find_singleton2 in C. subst. tryfalse. 
    unfold FMap.singleton. rewrite FMap.add_find_old. apply FMap.empty_find.
    intro C. inversion C. rewrite <- compare_eq in H2. tryfalse.
    split;intros. intro C. apply FMap.find_singleton2 in C. symmetry in C. 
    apply Ropp_eq_0_compat in C. rewrite Ropp_involutive in C. tryfalse.
    unfold FMap.singleton. rewrite FMap.add_find_old. apply FMap.empty_find.
    intro C. inversion C. rewrite <- compare_eq in H2. tryfalse.
    rewrite compare_eq in H2. subst. rewrite <- compare_lt_gt in Eq. tryfalse.
  Qed.

  Lemma map_empty f : map f empty = empty.
  Proof.
    unfold map, empty. apply FMap.map_empty.
  Qed.

  Lemma union_empty_l f m : union_with f m empty = m.
  Proof.
    unfold union_with, empty. apply FMap.union_empty_l.
  Qed.

  Lemma union_empty_r f m : union_with f empty m = m.
  Proof.
    unfold union_with, empty. apply FMap.union_empty_r.
  Qed.

  Lemma zip_empty f : union_with f empty empty = empty.
  Proof.
    unfold union_with, empty. apply FMap.union_empty.
  Qed.

  Lemma union_find p1 p2 a m1 m2 :  find p1 p2 a (union_with Rplus m1 m2) = find p1 p2 a m1 + find p1 p2 a m2.
  Proof.
    unfold find, union_with. cases (compare p1 p2).
    rewrite Rplus_0_l. reflexivity. rewrite FMap.union_find.
    cases (FMap.find (p1, p2, a) m1) as F1; cases (FMap.find (p1, p2, a) m2) as F2;
    try (cases (Reqb (r + r0) 0) as R; try rewrite Reqb_iff in R); auto using Rplus_0_l,Rplus_0_r.
    rewrite FMap.union_find.
    cases (FMap.find (p2, p1, a) m1) as F1; cases (FMap.find (p2, p1, a) m2) as F2;
    try (cases (Reqb (r + r0) 0) as R; try rewrite Reqb_iff in R); auto using Rplus_0_l,Rplus_0_r;
    rewrite <- Ropp_plus_distr. rewrite R. rewrite Ropp_0. reflexivity. reflexivity.
  Qed.

  Lemma compact_union m1 m2 f : Compact m1 -> Compact m2 -> Compact (union_with f m1 m2).
  Proof.

    intros C1 C2.
    unfold Compact, union_with in *. 
    destruct C1 as [C11 C12]. destruct C2 as [C21 C22].
    split.
    - intros. intro C.
      rewrite FMap.union_find in C.
      cases (FMap.find (p1, p2, a) m1) as F1;
        cases (FMap.find (p1, p2, a) m2) as F2; try solve[inversion C; subst; tryfalse].
      cases (Reqb (f r r0) 0) as E. tryfalse.
      inversion C. rewrite <- Reqb_iff in H0. tryfalse.
    - intros. rewrite FMap.union_find. rewrite C12 by assumption. rewrite C22 by assumption. reflexivity.
  Qed.


  Lemma compact_map m f : (forall x, f x = 0 -> x = 0) -> Compact m -> Compact (map f m).
  Proof.
    intros F C. destruct C as [C1 C2].
    unfold Compact, map in *. intros. split;intros.
    - intro O.
      rewrite FMap.map_find in O. option_inv_auto.
      symmetry in H1. apply F in H1. subst. tryfalse.
    - rewrite FMap.map_find. rewrite C2 by auto. reflexivity.
  Qed.

  Lemma empty_find_compact m : Compact m -> (forall p1 p2 a, find p1 p2 a m = 0) -> m = empty.
  Proof.
    intros C Z. unfold Compact in *. destruct C as [C1 C2].
    unfold empty. apply FMap.empty_find'. intros.
    destruct k. destruct p. specialize (Z p p0 a). 
    unfold find in Z. 

    cases (compare p p0) as  P. apply C2. rewrite P. intro C; inversion C.
    cases (FMap.find (p, p0, a) m). simpl in *. subst. tryfalse. reflexivity.
    apply C2. rewrite P. intro C; inversion C.

  Qed.

  Lemma map_find : forall p1 p2 a m f,  f 0 = 0 -> (forall r, - f r = f (- r)) 
                                        -> find p1 p2 a (map f m) = f (find p1 p2 a m).
  Proof. 
    unfold find, map. intros. cases (compare p1 p2); auto; rewrite FMap.map_find.
    destruct (FMap.find (p1, p2, a) m);auto.
    destruct (FMap.find (p2, p1, a) m);auto. apply H0.
  Qed.
End SMap.

