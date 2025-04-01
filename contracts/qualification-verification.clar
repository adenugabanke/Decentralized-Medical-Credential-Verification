;; qualification-verification.clar
;; Validates medical degrees and training

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map issuers
  { issuer-id: (string-ascii 36) }
  {
    name: (string-ascii 100),
    website: (string-utf8 256),
    is-verified: bool
  }
)

(define-map qualifications
  { qualification-id: (string-ascii 36) }
  {
    practitioner-id: (string-ascii 36),
    issuer-id: (string-ascii 36),
    qualification-type: (string-ascii 50),
    issue-date: uint,
    expiry-date: (optional uint),
    verification-hash: (buff 32),
    status: (string-ascii 10)
  }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_EXISTS u2)
(define-constant ERR_NOT_FOUND u3)
(define-constant ERR_INVALID_ISSUER u4)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a new issuer
(define-public (register-issuer
    (issuer-id (string-ascii 36))
    (name (string-ascii 100))
    (website (string-utf8 256))
    (is-verified bool))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? issuers { issuer-id: issuer-id }))
              (err ERR_ALREADY_EXISTS))

    (map-set issuers
      { issuer-id: issuer-id }
      {
        name: name,
        website: website,
        is-verified: is-verified
      }
    )
    (ok true)
  )
)

;; Add a qualification
(define-public (add-qualification
    (qualification-id (string-ascii 36))
    (practitioner-id (string-ascii 36))
    (issuer-id (string-ascii 36))
    (qualification-type (string-ascii 50))
    (issue-date uint)
    (expiry-date (optional uint))
    (verification-hash (buff 32)))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? qualifications { qualification-id: qualification-id }))
              (err ERR_ALREADY_EXISTS))
    (asserts! (is-some (map-get? issuers { issuer-id: issuer-id }))
              (err ERR_INVALID_ISSUER))

    (map-set qualifications
      { qualification-id: qualification-id }
      {
        practitioner-id: practitioner-id,
        issuer-id: issuer-id,
        qualification-type: qualification-type,
        issue-date: issue-date,
        expiry-date: expiry-date,
        verification-hash: verification-hash,
        status: "active"
      }
    )
    (ok true)
  )
)

;; Update qualification status
(define-public (update-qualification-status
    (qualification-id (string-ascii 36))
    (new-status (string-ascii 10)))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (match (map-get? qualifications { qualification-id: qualification-id })
      qualification (begin
        (map-set qualifications
          { qualification-id: qualification-id }
          (merge qualification { status: new-status })
        )
        (ok true)
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Get qualification details
(define-read-only (get-qualification (qualification-id (string-ascii 36)))
  (map-get? qualifications { qualification-id: qualification-id })
)

;; Get issuer details
(define-read-only (get-issuer (issuer-id (string-ascii 36)))
  (map-get? issuers { issuer-id: issuer-id })
)

;; Verify if a qualification is valid
(define-read-only (verify-qualification (qualification-id (string-ascii 36)))
  (match (map-get? qualifications { qualification-id: qualification-id })
    qualification (begin
      (match (map-get? issuers { issuer-id: (get issuer-id qualification) })
        issuer (ok {
          is-valid: (and
                      (is-eq (get status qualification) "active")
                      (get is-verified issuer)
                      (match (get expiry-date qualification)
                        expiry (> expiry block-height)
                        true)
                    ),
          issuer-name: (get name issuer)
        })
        (err ERR_NOT_FOUND)
      )
    )
    (err ERR_NOT_FOUND)
  )
)
