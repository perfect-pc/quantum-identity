;; Quantum-Resistant Identity System (QRIS)
;; Phase 1: PQC Key Registration + Identity Upgrade

;; Constants
(define-constant ERR-ALREADY-REGISTERED (err u100))
(define-constant ERR-NOT-REGISTERED (err u101))
(define-constant ERR-ALREADY-UPGRADED (err u102))
(define-constant ERR-NOT-OWNER (err u103))

;; Data Structures
(define-map pqc-identity-registry
  { classical-owner: principal }
  {
    pqc-key-hash: (buff 64),
    registered-at: uint,
    upgraded: bool
  }
)

(define-map pqc-hash-to-owner
  { pqc-key-hash: (buff 64) }
  {
    classical-owner: principal,
    upgraded: bool
  }
)

;; Register a new identity with a quantum-safe public key hash
(define-public (register-pqc-identity (pqc-hash (buff 64)))
  (begin
    (asserts! (is-none (map-get? pqc-identity-registry { classical-owner: tx-sender })) ERR-ALREADY-REGISTERED)

    (map-set pqc-identity-registry
      { classical-owner: tx-sender }
      {
        pqc-key-hash: pqc-hash,
        registered-at: stacks-block-height,
        upgraded: false
      })

    (map-set pqc-hash-to-owner
      { pqc-key-hash: pqc-hash }
      {
        classical-owner: tx-sender,
        upgraded: false
      })

    (ok true)
  )
)

;; Upgrade the identity to quantum-safe mode
(define-public (upgrade-identity (pqc-hash (buff 64)))
  (let (
    (identity (map-get? pqc-identity-registry { classical-owner: tx-sender }))
  )
    (begin
      (asserts! (is-some identity) ERR-NOT-REGISTERED)
      (let ((data (unwrap-panic identity)))
        (asserts! (not (get upgraded data)) ERR-ALREADY-UPGRADED)
        (asserts! (is-eq (get pqc-key-hash data) pqc-hash) ERR-NOT-OWNER)

        ;; Update upgraded flag
        (map-set pqc-identity-registry
          { classical-owner: tx-sender }
          (merge data { upgraded: true })
        )

        (map-set pqc-hash-to-owner
          { pqc-key-hash: pqc-hash }
          {
            classical-owner: tx-sender,
            upgraded: true
          }
        )

        (ok true)
      )
    )
  )
)

;; Read-only: Check identity status
(define-read-only (get-identity-status (owner principal))
  (match (map-get? pqc-identity-registry { classical-owner: owner })
    data (ok data)
    (err ERR-NOT-REGISTERED)
  )
)

;; Read-only: Check who owns a given PQC hash
(define-read-only (get-owner-by-pqc-hash (pqc-hash (buff 64)))
  (match (map-get? pqc-hash-to-owner { pqc-key-hash: pqc-hash })
    data (ok data)
    (err ERR-NOT-REGISTERED)
  )
)

;; Read-only: Check if upgraded
(define-read-only (is-upgraded (owner principal))
  (match (map-get? pqc-identity-registry { classical-owner: owner })
    data (get upgraded data) 
    false                   
  )
)

;; Read-only: Get PQC key hash of owner
(define-read-only (get-pqc-hash (owner principal))
  (match (map-get? pqc-identity-registry { classical-owner: owner })
    data (ok (get pqc-key-hash data))
    (err ERR-NOT-REGISTERED)
  )
)
