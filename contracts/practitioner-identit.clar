;; practitioner-identity.clar
;; Manages healthcare provider identities

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map practitioners
  { practitioner-id: (string-ascii 36) }
  {
    principal: principal,
    full-name: (string-ascii 100),
    date-registered: uint,
    status: (string-ascii 10),
    metadata-url: (optional (string-utf8 256))
  }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_REGISTERED u2)
(define-constant ERR_NOT_FOUND u3)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new practitioner
(define-public (register-practitioner
    (practitioner-id (string-ascii 36))
    (full-name (string-ascii 100))
    (metadata-url (optional (string-utf8 256))))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? practitioners { practitioner-id: practitioner-id }))
              (err ERR_ALREADY_REGISTERED))

    (map-set practitioners
      { practitioner-id: practitioner-id }
      {
        principal: tx-sender,
        full-name: full-name,
        date-registered: block-height,
        status: "active",
        metadata-url: metadata-url
      }
    )
    (ok true)
  )
)

;; Update practitioner status
(define-public (update-status
    (practitioner-id (string-ascii 36))
    (new-status (string-ascii 10)))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (match (map-get? practitioners { practitioner-id: practitioner-id })
      practitioner (begin
        (map-set practitioners
          { practitioner-id: practitioner-id }
          (merge practitioner { status: new-status })
        )
        (ok true)
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Get practitioner details
(define-read-only (get-practitioner (practitioner-id (string-ascii 36)))
  (map-get? practitioners { practitioner-id: practitioner-id })
)

;; Transfer admin rights
(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (var-set admin new-admin)
    (ok true)
  )
)
