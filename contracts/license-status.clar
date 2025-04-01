;; license-status.clar
;; Tracks active/suspended status of professionals

;; Define data variables
(define-data-var admin principal tx-sender)
(define-map licensing-authorities
  { authority-id: (string-ascii 36) }
  {
    name: (string-ascii 100),
    jurisdiction: (string-ascii 50),
    is-verified: bool
  }
)

(define-map licenses
  { license-id: (string-ascii 36) }
  {
    practitioner-id: (string-ascii 36),
    authority-id: (string-ascii 36),
    license-type: (string-ascii 50),
    issue-date: uint,
    expiry-date: uint,
    status: (string-ascii 20),
    last-updated: uint,
    verification-url: (optional (string-utf8 256))
  }
)

;; Error codes
(define-constant ERR_UNAUTHORIZED u1)
(define-constant ERR_ALREADY_EXISTS u2)
(define-constant ERR_NOT_FOUND u3)
(define-constant ERR_INVALID_AUTHORITY u4)

;; Check if caller is admin
(define-private (is-admin)
  (is-eq tx-sender (var-get admin))
)

;; Register a licensing authority
(define-public (register-authority
    (authority-id (string-ascii 36))
    (name (string-ascii 100))
    (jurisdiction (string-ascii 50))
    (is-verified bool))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? licensing-authorities { authority-id: authority-id }))
              (err ERR_ALREADY_EXISTS))

    (map-set licensing-authorities
      { authority-id: authority-id }
      {
        name: name,
        jurisdiction: jurisdiction,
        is-verified: is-verified
      }
    )
    (ok true)
  )
)

;; Register a new license
(define-public (register-license
    (license-id (string-ascii 36))
    (practitioner-id (string-ascii 36))
    (authority-id (string-ascii 36))
    (license-type (string-ascii 50))
    (issue-date uint)
    (expiry-date uint)
    (verification-url (optional (string-utf8 256))))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (asserts! (is-none (map-get? licenses { license-id: license-id }))
              (err ERR_ALREADY_EXISTS))
    (asserts! (is-some (map-get? licensing-authorities { authority-id: authority-id }))
              (err ERR_INVALID_AUTHORITY))

    (map-set licenses
      { license-id: license-id }
      {
        practitioner-id: practitioner-id,
        authority-id: authority-id,
        license-type: license-type,
        issue-date: issue-date,
        expiry-date: expiry-date,
        status: "active",
        last-updated: block-height,
        verification-url: verification-url
      }
    )
    (ok true)
  )
)

;; Update license status
(define-public (update-license-status
    (license-id (string-ascii 36))
    (new-status (string-ascii 20)))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (match (map-get? licenses { license-id: license-id })
      license (begin
        (map-set licenses
          { license-id: license-id }
          (merge license {
            status: new-status,
            last-updated: block-height
          })
        )
        (ok true)
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Renew a license
(define-public (renew-license
    (license-id (string-ascii 36))
    (new-expiry-date uint))
  (begin
    (asserts! (is-admin) (err ERR_UNAUTHORIZED))
    (match (map-get? licenses { license-id: license-id })
      license (begin
        (map-set licenses
          { license-id: license-id }
          (merge license {
            expiry-date: new-expiry-date,
            last-updated: block-height
          })
        )
        (ok true)
      )
      (err ERR_NOT_FOUND)
    )
  )
)

;; Get license details
(define-read-only (get-license (license-id (string-ascii 36)))
  (map-get? licenses { license-id: license-id })
)

;; Get authority details
(define-read-only (get-authority (authority-id (string-ascii 36)))
  (map-get? licensing-authorities { authority-id: authority-id })
)

;; Check if a license is valid
(define-read-only (is-license-valid (license-id (string-ascii 36)))
  (match (map-get? licenses { license-id: license-id })
    license (begin
      (and
        (is-eq (get status license) "active")
        (> (get expiry-date license) block-height)
      )
    )
    false
  )
)
