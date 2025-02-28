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
(define-constant dispute-window-blocks u144) ;; 24 hours worth of blocks

;; Data Variables
(define-data-var platform-fee uint u25) ;; 2.5% fee
(define-data-var next-listing-id uint u1)

;; Data Maps
(define-map listings
    { id: uint }
    {
        seller: principal,
        title: (string-ascii 100),
        description: (string-utf8 500),
        price: uint,
        active: bool,
        category: (string-ascii 50)
    }
)

(define-map seller-profiles
    { seller: principal }
    {
        rating: uint,
        total-ratings: uint,
        items-sold: uint,
        total-proceeds: uint
    }
)

(define-map purchases
    { id: uint }
    {
        buyer: principal,
        seller: principal,
        listing-id: uint,
        amount: uint,
        status: (string-ascii 20),
        block-height: uint,
        dispute-reason: (optional (string-utf8 500))
    }
)

(define-map escrow-balances
    { purchase-id: uint }
    { amount: uint }
)

;; Initialize non-fungible token for listing IDs
(define-non-fungible-token listing-token uint)

;; Helper functions
(define-private (is-listing-owner (listing-id uint) (caller principal))
    (match (map-get? listings {id: listing-id})
        listing (is-eq (get seller listing) caller)
        false
    )
)

;; Enhanced Public Functions

(define-public (create-listing (title (string-ascii 100)) 
                            (description (string-utf8 500))
                            (price uint)
                            (category (string-ascii 50)))
    (let ((listing-id (var-get next-listing-id)))
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
                category: category
            }
        )
        (var-set next-listing-id (+ listing-id u1))
        (ok listing-id)
    )
)

(define-public (update-listing (listing-id uint)
                            (new-title (optional (string-ascii 100)))
                            (new-description (optional (string-utf8 500)))
                            (new-price (optional uint)))
    (let ((listing (unwrap! (map-get? listings {id: listing-id}) err-not-found)))
        (asserts! (is-listing-owner listing-id tx-sender) err-unauthorized)
        (asserts! (get active listing) err-not-found)
        (ok (map-set listings
            { id: listing-id }
            {
                seller: (get seller listing),
                title: (default-to (get title listing) new-title),
                description: (default-to (get description listing) new-description),
                price: (default-to (get price listing) new-price),
                active: true,
                category: (get category listing)
            }
        ))
    )
)

;; [Previous functions remain unchanged...]

(define-public (rate-seller (seller principal) (rating uint))
    (let (
        (current-profile (default-to 
            { rating: u0, total-ratings: u0, items-sold: u0, total-proceeds: u0 }
            (map-get? seller-profiles {seller: seller})))
    )
        (asserts! (and (>= rating u1) (<= rating u5)) err-invalid-rating)
        (map-set seller-profiles
            { seller: seller }
            {
                rating: (+ (get rating current-profile) rating),
                total-ratings: (+ (get total-ratings current-profile) u1),
                items-sold: (get items-sold current-profile),
                total-proceeds: (get total-proceeds current-profile)
            }
        )
        (ok true)
    )
)

(define-public (withdraw-proceeds)
    (let (
        (profile (unwrap! (map-get? seller-profiles {seller: tx-sender}) err-not-found))
        (proceeds (get total-proceeds profile))
    )
        (asserts! (> proceeds u0) err-insufficient-funds)
        (try! (as-contract (stx-transfer? proceeds (as-contract tx-sender) tx-sender)))
        (map-set seller-profiles
            { seller: tx-sender }
            (merge profile { total-proceeds: u0 })
        )
        (ok proceeds)
    )
)

;; Enhanced Read-only functions

(define-read-only (get-listings-by-seller (seller principal))
    (filter map-get? listings
        (lambda (id)
            (is-eq (get seller (unwrap! (map-get? listings {id: id}) false)) seller)
        )
    )
)

;; [Previous read-only functions remain unchanged...]
