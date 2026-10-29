; Current overlap replacement; neighbors are derived from the OLD Store word.
(set-option :timeout 60000)
(declare-const L (_ BitVec 32))
(declare-const S (_ BitVec 32))
(declare-const NL (_ BitVec 3))
(declare-const NS (_ BitVec 3))
(assert (or (= NL #b001) (= NL #b010) (= NL #b100)))
(assert (or (= NS #b001) (= NS #b010) (= NS #b100)))
(define-fun LW () (_ BitVec 30) ((_ extract 31 2) L))
(define-fun SW () (_ BitVec 30) ((_ extract 31 2) S))
(define-fun LO () (_ BitVec 3) (concat #b0 ((_ extract 1 0) L)))
(define-fun SO () (_ BitVec 3) (concat #b0 ((_ extract 1 0) S)))
(define-fun LE () (_ BitVec 3) (bvadd LO NL))
(define-fun SE () (_ BitVec 3) (bvadd SO NS))
(define-fun WD () (_ BitVec 30) (bvsub LW SW))
(define-fun SAME_BYTES () Bool (and (bvult LO SE) (bvult SO LE)))
(define-fun NEXT_BYTES () Bool (bvult (bvadd LO #b100) SE))
(define-fun PREV_BYTES () Bool (bvult (bvadd SO #b100) LE))
(define-fun OLD () Bool
 (ite (= WD (_ bv0 30)) SAME_BYTES
  (ite (and (= WD (_ bv1 30)) (not (= SW (_ bv1073741823 30)))) NEXT_BYTES
   (ite (and (= WD (_ bv1073741823 30)) (not (= LW (_ bv1073741823 30)))) PREV_BYTES false))))
(define-fun NEXT_WORD () (_ BitVec 30) (bvadd SW (_ bv1 30)))
(define-fun PREV_WORD () (_ BitVec 30) (bvsub SW (_ bv1 30)))
(define-fun NEW () Bool
 (or (and (= LW SW) SAME_BYTES)
     (and (= LW NEXT_WORD) (not (= SW (_ bv1073741823 30))) NEXT_BYTES)
     (and (= LW PREV_WORD) (not (= LW (_ bv1073741823 30))) PREV_BYTES)))
; All 32-bit addresses, including unsigned address boundaries: UNSAT.
(push)
(assert (xor OLD NEW))
(check-sat)
(pop)
; Negative controls: either omitted wrap guard changes the predicate: SAT/SAT.
(push)
(assert (xor OLD
 (or (and (= LW SW) SAME_BYTES) (and (= LW NEXT_WORD) NEXT_BYTES)
     (and (= LW PREV_WORD) (not (= LW (_ bv1073741823 30))) PREV_BYTES))))
(check-sat)
(pop)
(assert (xor OLD
 (or (and (= LW SW) SAME_BYTES)
     (and (= LW NEXT_WORD) (not (= SW (_ bv1073741823 30))) NEXT_BYTES)
     (and (= LW PREV_WORD) PREV_BYTES))))
(check-sat)
