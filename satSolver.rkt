#lang racket

(require "utilities.rkt")

(define assign #hash())

; Fill in your code here. Should finally define a function
; called dpll which returns true or false. Should additionally
; store the satisfying assignment in the variable assign.



(define (list-unit-lit t)
  (cond [(And? t) (begin (list-unit-lit (And-x t))
                         (list-unit-lit (And-y t))
                         (void))]
        [(Var? t) (set! assign (dict-set assign (Var-lit t) #t))]
        [(Not? t) (set! assign (dict-set assign (Var-lit (Not-e t)) #f))]
        [else '()]))

(define n 0)

(define (OR-sagar t1 t2)
  (cond [(Const? t1)(cond [(Const-bool t1) (begin (set! n 1) t1)]
                          [(Const? t2) (if (Const-bool t2) (begin (set! n 1) t1) t2)]
                          [(Or? t2) (OR-sagar (Or-x t2) (Or-y t2))]
                          [else  t2])]
        [(Const? t2)(cond [(Const-bool t2)(begin (set! n 1) t1)]
                          [else t1])]
        [(Or? t2) (Or t1 (OR-sagar (Or-x t2) (Or-y t2)))]
        [else (Or t1 t2)]))


;;removes unit-literals
;;along with removing any other hash feeded into ans
(define (unit-prop t ans)
  (define (unit-prop-h t ans) 
    (cond[(And? t) (let* ([t1 (And-x t)]
                          [t2 (And-y t)]
                          [res1 (unit-prop-h t1 ans)] 
                          [res2 (unit-prop-h t2 ans)])
                     (cond [(and (Const? res1) (Const? res2))(if (and (Const-bool res1)
                                                                     (Const-bool res2)) (Const #t) (Const #f))]
                           [(Const? res1) (if (Const-bool res1) res2 (Const #f))]
                           [(Const? res2) (if (Const-bool res2) res1 (Const #f))]
                           [else (And res1 res2)]))]
          [(Or? t) (let* ([t1 (Or-x t)]
                          [t2 (Or-y t)]
                          [res1 (unit-prop-h t1 ans )] 
                          [res2 (unit-prop-h t2 ans )])
                     (cond [(and (Const? res1) (Const? res2))(if (or (Const-bool res1)
                                                                     (Const-bool res2)) (Const #t) (Const #f))]
                           [(Const? res1) (if (Const-bool res1) (Const #t) res2)]
                           [(Const? res2) (if (Const-bool res2) (Const #t) res1)]
                           [else (Or res1 res2)]))]
          [(Var? t) (if (hash-has-key? ans (Var-lit t))
                        (if (hash-ref ans (Var-lit t)) (Const #t) (Const #f)) t)]
          [(Not? t) (if (hash-has-key? ans (Var-lit (Not-e t)))
                        (if (hash-ref ans (Var-lit (Not-e t))) (Const #f) (Const #t)) t)]
          [(Const? t) t]))
  (unit-prop-h t ans))

;;returns the same tree
;;updates the position of var's that need to be #t now
(define (elim t posh negh)
  (cond [(And? t) (And (elim (And-x t) posh negh )
                       (elim (And-y t) posh negh))]
        [(Or? t) (Or (elim (Or-x t) posh negh)
                     (elim (Or-y t) posh negh))]
        [(Var? t) (let* ([v (Var-lit t)])
                    (begin
                      (if (hash-has-key? posh v) ;whether #t #f nothing to do
                          t (begin (set! posh (dict-set posh v #t)) t))
                      (if (hash-has-key? negh v) 
                          (if (hash-ref negh v)
                              (begin (set! negh (dict-set negh v #f)) t) t)
                          (begin (set! negh (dict-set negh v #f)) t))))]
        [(Not? t) (let* ([v (Var-lit(Not-e t))])
                    (begin
                      (if (hash-has-key? posh v)
                          (if (hash-ref posh v)
                              (begin (set! posh (dict-set posh v #f)) t) t)
                          (begin (set! posh (dict-set posh v #f)) t))
                      (if (hash-has-key? negh v)
                          t
                          (begin (set! negh (dict-set negh v #t)) t))))]
        [(Const? t) t]))

(define (fir t)
  (cond [(And? t) (let*([x (fir (And-x t))]
                        [y (fir (And-y t))])
                    (if (not (Const? x)) x y))]
        [(Or? t) (let*([x (fir (Or-x t))]
                       [y (fir (Or-y t))])
                   (if (not (Const? x)) x y))]
        [(Var? t) (Var-lit t)]
        [(Not? t) (Var-lit(Not-e t))]
        [else t]))

(define (hash-keys-ret h val)
  (append*(hash-map h (lambda(x y) (if (equal? y val) (list x) '())))))



(define (dpll tree)
  (set! assign #hash())
  (define posh #hash())
  (define negh #hash())
  (define tempo #hash())
  (define (ass-h tree)
    (set! posh #hash()) (set! negh #hash())
    (list-unit-lit tree) ;;assign update
    (elim tree posh negh)
    (let* ([l1 (hash-keys-ret posh #t)]
           [l2 (hash-keys-ret negh #t)])
      (cond [(only-const? tree) (const-type? tree)]
            [(and (null? l1) (null? l2))
             (let* ([t2 tree]
                    [r (fir tree)]
                    [badass1 (hash-copy assign)])
               (begin 
                 (set! assign (dict-set assign r #t))       
                 (let*([t (unit-prop tree assign)]
                       [a (only-const? t)]
                       [b (if a (const-type? t) (ass-h t))])  
                   (if b b
                       (begin (set! assign (make-immutable-hash (hash->list badass1)))
                              (set! assign (dict-set assign r #f))
                              (ass-h (unit-prop t2 assign)))))))]
            [else(begin
                   (map (lambda (x) (set! assign (dict-set assign x #t))) l1)
                   (map (lambda (x) (set! assign (dict-set assign x #f))) l2)
                   (let* ([t (unit-prop tree assign)])
                     (if (only-const? t) (const-type? t) (ass-h t))))])))
  (let* ([result(ass-h (unit-prop tree assign))])
    (if result result (begin (set! assign #hash()) result))))

(define (only-const? tree)
  (cond [(And? tree) (and (only-const? (And-x tree))
                          (only-const? (And-y tree)))]
        [(Or? tree) (and (only-const? (Or-x tree)) 
                         (only-const? (Or-y tree)))]
        [(Var? tree) #f]
        {(Not? tree) #f}
        [else #t]));;edit1

(define (const-type? tree)
  (cond [(And? tree) (and (const-type? (And-x tree))
                          (const-type? (And-y tree)))]
        [(Or? tree) (and (const-type? (Or-x tree))  
                         (const-type? (Or-y tree)))]
        [(Const? tree) (Const-bool tree)]
        [else #f])) ;;not expected though

                            
                          


        
            


                  
           








   


