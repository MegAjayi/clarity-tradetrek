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
            (block-height block-height)
        )
            ;; Hold payment in escrow
            (try! (stx-transfer? price tx-sender (as-contract tx-sender)))
            (map-set escrow-balances 
                { purchase-id: listing-id }
                { amount: price }
            )
            (map-set purchases
                { id: listing-id }
                {
                    buyer: tx-sender,
                    seller: seller,
                    listing-id: listing-id,
                    amount: price,
                    status: "pending",
                    block-height: block-height,
                    dispute-reason: none
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

(define-public (confirm-delivery (purchase-id uint))
    (let (
        (purchase (unwrap! (map-get? purchases {id: purchase-id}) err-not-found))
        (escrow (unwrap! (map-get? escrow-balances {purchase-id: purchase-id}) err-not-found))
    )
        (asserts! (is-eq (get buyer purchase) tx-sender) err-not-buyer)
        (let (
            (amount (get amount escrow))
            (seller (get seller purchase))
            (fee (/ (* amount (var-get platform-fee)) u1000))
        )
            (try! (as-contract (stx-transfer? (- amount fee) (as-contract tx-sender) seller)))
            (try! (as-contract (stx-transfer? fee (as-contract tx-sender) contract-owner)))
            (map-delete escrow-balances {purchase-id: purchase-id})
            (map-set purchases
                { id: purchase-id }
                (merge purchase { status: "completed" })
            )
            (ok true)
        )
    )
)

(define-public (open-dispute (purchase-id uint) (reason (string-utf8 500)))
    (let (
        (purchase (unwrap! (map-get? purchases {id: purchase-id}) err-not-found))
    )
        (asserts! (is-eq (get buyer purchase) tx-sender) err-not-buyer)
        (asserts! (< (- block-height (get block-height purchase)) dispute-window-blocks) err-not-in-dispute)
        (map-set purchases
            { id: purchase-id }
            (merge purchase 
                { 
                    status: "disputed",
                    dispute-reason: (some reason)
                }
            )
        )
        (ok true)
    )
)

(define-public (resolve-dispute (purchase-id uint) (refund-buyer bool))
    (let (
        (purchase (unwrap! (map-get? purchases {id: purchase-id}) err-not-found))
        (escrow (unwrap! (map-get? escrow-balances {purchase-id: purchase-id}) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (asserts! (is-eq (get status purchase) "disputed") err-not-in-dispute)
        (if refund-buyer
            (begin
                (try! (as-contract (stx-transfer? (get amount escrow) (as-contract tx-sender) (get buyer purchase))))
                (map-set purchases
                    { id: purchase-id }
                    (merge purchase { status: "refunded" })
                )
            )
            (begin 
                (try! (as-contract (stx-transfer? (get amount escrow) (as-contract tx-sender) (get seller purchase))))
                (map-set purchases
                    { id: purchase-id }
                    (merge purchase { status: "completed" })
                )
            )
        )
        (map-delete escrow-balances {purchase-id: purchase-id})
        (ok true)
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

(define-read-only (get-escrow-balance (purchase-id uint))
    (map-get? escrow-balances {purchase-id: purchase-id})
)
