;; specialty-certification.clar
;; Records advanced medical qualifications

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map certification-bodies
  { body-id: (string-ascii 36) }
  {
    name: (string-ascii 100),
    specialty-area: (string-ascii 100),
    is-verified: bool
  }
)

(define-map certifications
  { certification-id: (string-ascii 36) }
  {
    practitioner-id: (string-ascii 36),
    body-id: (string-ascii 36),
    specialty-name: (string-ascii 100),
    certification-date: uint,
    expiry-date: (optional uint),
    status: (string-ascii 20),
    verification-code: (string-ascii 50)
  }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_EXISTS u2)
(define-constant ERR_NOT_FOUND u3)
(define-constant ERR_INVALID_BODY u4)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a certification body
(define-public (register-certification-body
    (body-id (string-ascii 36))
    (name (string-ascii 100))
    (specialty-area (string-ascii 100))
    (is-verified bool))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? certification-bodies { body-id: body-id }))
              (err ERR_ALREADY_EXISTS))

    (map-set certification-bodies
      { body-id: body-id }
      {
        name: name,
        specialty-area: specialty-area,
        is-verified: is-verified
      }
    )
    (ok true)
  )
)

;; Add a specialty certification
(define-public (add-certification
    (certification-id (string-ascii 36))
    (practitioner-id (string-ascii 36))
    (body-id (string-ascii 36))
    (specialty-name (string-ascii 100))
    (certification-date uint)
    (expiry-date (optional uint))
    (verification-code (string-ascii 50)))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? certifications { certification-id: certification-id }))
              (err ERR_ALREADY_EXISTS))
    (asserts! (is-some (map-get? certification-bodies { body-id: body-id }))
              (err ERR_INVALID_BODY))

    (map-set certifications
      { certification-id: certification-id }
      {
        practitioner-id: practitioner-id,
        body-id: body-id,
        specialty-name: specialty-name,
        certification-date: certification-date,
        expiry-date: expiry-date,
        status: "active",
        verification-code: verification-code
      }
    )
    (ok true)
  )
)

;; Update certification status
(define-public (update-certification-status
    (certification-id (string-ascii 36))
    (new-status (string-ascii 20)))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (match (map-get? certifications { certification-id: certification-id })
      certification (begin
        (map-set certifications
          { certification-id: certification-id }
          (merge certification { status: new-status })
        )
        (ok true)
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Renew a certification
(define-public (renew-certification
    (certification-id (string-ascii 36))
    (new-expiry-date uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (match (map-get? certifications { certification-id: certification-id })
      certification (begin
        (map-set certifications
          { certification-id: certification-id }
          (merge certification { expiry-date: (some new-expiry-date) })
        )
        (ok true)
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Get certification details
(define-read-only (get-certification (certification-id (string-ascii 36)))
  (map-get? certifications { certification-id: certification-id })
)

;; Get certification body details
(define-read-only (get-certification-body (body-id (string-ascii 36)))
  (map-get? certification-bodies { body-id: body-id })
)

;; Verify a certification
(define-read-only (verify-certification
    (certification-id (string-ascii 36))
    (verification-code (string-ascii 50)))
  (match (map-get? certifications { certification-id: certification-id })
    certification (begin
      (and
        (is-eq (get verification-code certification) verification-code)
        (is-eq (get status certification) "active")
        (match (get expiry-date certification)
          expiry (> expiry block-height)
          true)
      )
    )
    false
  )
)
