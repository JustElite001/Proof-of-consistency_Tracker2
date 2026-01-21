;; ---------------------------------------------------------
;; Proof-of-Consistency Tracker
;; Tracks repeated actions over time to prove consistency
;; ---------------------------------------------------------

(define-constant ERR-NOT-AUTHORIZED u100)
(define-constant ERR-TOO-SOON u101)
(define-constant ERR-NOT-FOUND u102)

;; Minimum blocks required between valid actions
(define-constant MIN-BLOCK-GAP u144) ;; ~1 day on Stacks

;; ---------------------------------------------------------
;; Data Maps
;; ---------------------------------------------------------

;; Stores user consistency data
;; last-block  -> last valid action block height
;; streak      -> consecutive valid actions
;; total       -> total valid actions ever
(define-map consistency
  principal
  {
    last-block: uint,
    streak: uint,
    total: uint
  }
)

;; Optional admin (can be removed if undesired)
(define-data-var admin principal tx-sender)

;; ---------------------------------------------------------
;; Read-Only Functions
;; ---------------------------------------------------------

(define-read-only (get-consistency (user principal))
  (match (map-get? consistency user)
    data (ok data)
    (err ERR-NOT-FOUND)
  )
)

(define-read-only (get-streak (user principal))
  (match (map-get? consistency user)
    data (ok (get streak data))
    (err ERR-NOT-FOUND)
  )
)

(define-read-only (get-total (user principal))
  (match (map-get? consistency user)
    data (ok (get total data))
    (err ERR-NOT-FOUND)
  )
)

;; ---------------------------------------------------------
;; Public Functions
;; ---------------------------------------------------------

;; Record a consistency action
;; Fails if called too soon
(define-public (record-action)
  (match (map-get? consistency tx-sender)

    ;; Existing user
    user-data
    (let (
          (last (get last-block user-data))
          (streak (get streak user-data))
          (total (get total user-data))
         )
      (if (< (- burn-block-height last) MIN-BLOCK-GAP)
          (err ERR-TOO-SOON)
          (begin
            (map-set consistency tx-sender
              {
                last-block: burn-block-height,
                streak: (+ streak u1),
                total: (+ total u1)
              }
            )
            (ok true)
          )
      )
    )

    ;; First-time user
    (begin
      (map-set consistency tx-sender
        {
          last-block: burn-block-height,
          streak: u1,
          total: u1
        }
      )
      (ok true)
    )
  )
)

;; ---------------------------------------------------------
;; Admin Utilities (Optional)
;; ---------------------------------------------------------

;; Reset a user's streak (for penalties or moderation)
(define-public (reset-streak (user principal))
  (if (is-eq tx-sender (var-get admin))
      (match (map-get? consistency user)
        data
        (begin
          (map-set consistency user
            {
              last-block: (get last-block data),
              streak: u0,
              total: (get total data)
            }
          )
          (ok true)
        )
        (err ERR-NOT-FOUND)
      )
      (err ERR-NOT-AUTHORIZED)
  )
)

;; Change admin
(define-public (set-admin (new-admin principal))
  (if (is-eq tx-sender (var-get admin))
      (begin
        (var-set admin new-admin)
        (ok true)
      )
      (err ERR-NOT-AUTHORIZED)
  )
)
