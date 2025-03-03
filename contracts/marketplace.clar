;; TradeTrek Marketplace Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-price (err u102))
(define-constant err-already-listed (err u103))
(define-constant err-not-seller (err u104))
(define-constant err-insufficient-funds (err u105))
(define-constant err-not-in-dispute (err u106))
(define-constant err-not-buyer (err u107))
(define-constant err-invalid-rating (err u108))
(define-constant err-unauthorized (err u109))
(define-constant err-expired (err u110))
(define-constant dispute-window-blocks u144) ;; 24 hours worth of blocks

;; Data Variables
(define-data-var platform-fee uint u25) ;; 2.5% fee
(define-data-var next-listing-id uint u1)
(define-data-var next-transaction-id uint u1)

;; Listing Status Enum
(define-data-var listing-status (string-ascii 20))

;; Enhanced Data Maps
(define-map listings
    { id: uint }
    {
        seller: principal,
        title: (string-ascii 100),
        description: (string-utf8 500),
        price: uint,
        active: bool,
        category: (string-ascii 50),
        created-at: uint,
        expires-at: uint,
        status: (string-ascii 20)
    }
)

(define-map transaction-history
    { id: uint }
    {
        type: (string-ascii 20),
        listing-id: uint,
        from: principal,
        to: principal,
        amount: uint,
        timestamp: uint
    }
)

;; [Previous maps remain unchanged...]

;; Enhanced Helper Functions
(define-private (create-transaction (type (string-ascii 20)) (listing-id uint) (from principal) (to principal) (amount uint))
    (let ((tx-id (var-get next-transaction-id)))
        (map-set transaction-history
            { id: tx-id }
            {
                type: type,
                listing-id: listing-id,
                from: from,
                to: to,
                amount: amount,
                timestamp: block-height
            }
        )
        (var-set next-transaction-id (+ tx-id u1))
        (ok tx-id)
    )
)

(define-private (validate-listing-active (listing-id uint))
    (match (map-get? listings {id: listing-id})
        listing (and (get active listing) 
                   (< block-height (get expires-at listing)))
        false
    )
)

;; Enhanced Public Functions
(define-public (create-listing (title (string-ascii 100)) 
                            (description (string-utf8 500))
                            (price uint)
                            (category (string-ascii 50)))
    (let (
        (listing-id (var-get next-listing-id))
        (expiration (+ block-height u8640)) ;; 60 days worth of blocks
    )
        (asserts! (> price u0) err-invalid-price)
        (try! (nft-mint? listing-token listing-id tx-sender))
        (map-set listings
            { id: listing-id }
            {
                seller: tx-sender,
                title: title,
                description: description,
                price: price,
                active: true,
                category: category,
                created-at: block-height,
                expires-at: expiration,
                status: "active"
            }
        )
        (var-set next-listing-id (+ listing-id u1))
        (try! (create-transaction "create" listing-id tx-sender tx-sender u0))
        (ok listing-id)
    )
)

;; [Previous functions updated with transaction tracking...]

;; New Read-only Functions
(define-read-only (get-transaction-history (page uint))
    (let ((start (* page u10))
          (end (+ start u10)))
        (filter map-get? transaction-history
            (lambda (id)
                (and (>= id start) (< id end))
            )
        )
    )
)

(define-read-only (get-active-listings (page uint))
    (let ((start (* page u10))
          (end (+ start u10)))
        (filter map-get? listings
            (lambda (id)
                (and 
                    (>= id start) 
                    (< id end)
                    (validate-listing-active id)
                )
            )
        )
    )
)
