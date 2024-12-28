;; TradeTrek Marketplace Contract

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-price (err u102))
(define-constant err-already-listed (err u103))
(define-constant err-not-seller (err u104))
(define-constant err-insufficient-funds (err u105))

;; Data Variables
(define-data-var platform-fee uint u25) ;; 2.5% fee

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
        items-sold: uint
    }
)

(define-map purchases
    { id: uint }
    {
        buyer: principal,
        seller: principal,
        listing-id: uint,
        amount: uint,
        status: (string-ascii 20)
    }
)

;; Initialize non-fungible token for listing IDs
(define-non-fungible-token listing-token uint)

;; Counter for listing IDs
(define-data-var next-listing-id uint u1)

;; Public Functions

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

(define-public (purchase-item (listing-id uint))
    (let (
        (listing (unwrap! (map-get? listings {id: listing-id}) err-not-found))
        (price (get price listing))
    )
        (asserts! (get active listing) err-not-found)
        (let (
            (seller (get seller listing))
            (fee (/ (* price (var-get platform-fee)) u1000))
        )
            (try! (stx-transfer? price tx-sender seller))
            (try! (stx-transfer? fee seller contract-owner))
            (map-set purchases
                { id: listing-id }
                {
                    buyer: tx-sender,
                    seller: seller,
                    listing-id: listing-id,
                    amount: price,
                    status: "completed"
                }
            )
            (map-set listings
                { id: listing-id }
                (merge listing { active: false })
            )
            (ok true)
        )
    )
)

(define-public (rate-seller (seller principal) (rating uint))
    (let (
        (current-profile (default-to 
            { rating: u0, total-ratings: u0, items-sold: u0 }
            (map-get? seller-profiles {seller: seller})))
    )
        (asserts! (<= rating u5) (err u106))
        (map-set seller-profiles
            { seller: seller }
            {
                rating: (+ (get rating current-profile) rating),
                total-ratings: (+ (get total-ratings current-profile) u1),
                items-sold: (get items-sold current-profile)
            }
        )
        (ok true)
    )
)

;; Read-only functions

(define-read-only (get-listing (listing-id uint))
    (map-get? listings {id: listing-id})
)

(define-read-only (get-seller-profile (seller principal))
    (map-get? seller-profiles {seller: seller})
)

(define-read-only (get-purchase (purchase-id uint))
    (map-get? purchases {id: purchase-id})
)