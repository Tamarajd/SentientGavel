;; Adaptive NFT Auction Price AI Contract
;; This contract manages NFT auctions where the minimum bid is dynamically adjusted
;; based on weighted market sentiment data provided by an AI-integrated oracle.
;; It includes advanced features like bid history tracking, collection whitelisting,
;; and complex post-auction performance analysis.

;; constants
;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-AUCTION-NOT-FOUND (err u101))
(define-constant ERR-BID-TOO-LOW (err u102))
(define-constant ERR-AUCTION-ENDED (err u103))
(define-constant ERR-AUCTION-ACTIVE (err u104))
(define-constant ERR-COLLECTION-NOT-WHITELISTED (err u105))
(define-constant ERR-BID-INCREMENT-TOO-SMALL (err u106))
(define-constant ERR-INVALID-DURATION (err u107))
(define-constant ERR-CANCELLATION-FORBIDDEN (err u108))

;; Ownership and Oracle
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ORACLE-ADDR 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; Configuration
(define-constant MIN-AUCTION-DURATION u10)   ;; blocks
(define-constant MAX-AUCTION-DURATION u10000) ;; blocks
(define-constant MIN-BID-INCREMENT u5)       ;; percent
(define-constant BASE-COMMISSION u25)        ;; 2.5%

;; data maps and vars

;; Auctions Map
;; Stores the core details of every auction created on the platform.
;; Includes metadata like collection-id and category for AI categorization.
(define-map auctions uint {
    seller: principal,
    nft-id: uint,
    collection-id: uint,
    base-price: uint,
    start-block: uint,
    end-block: uint,
    active: bool,
    category: (string-ascii 20)
})

;; Bids Map
;; Stores the current highest bid for a given auction ID.
(define-map bids uint {
    bidder: principal,
    amount: uint,
    block-height: uint
})

;; Market Sentiment Map
;; Stores the AI-derived sentiment score (0-100) for regular NFT collections.
;; Updated by the authorized ORACLE-ADDR.
(define-map market-sentiment uint uint)

;; Whitelisted Collections Map
;; Controls which collections are allowed to create auctions.
;; Key: Collection ID, Value: Allowed (bool)
(define-map whitelisted-collections uint bool)

;; Bid History Map
;; Tracks aggregate stats for auctions to feed back into the AI model.
;; Key: Auction ID, Value: { total-bids, last-bid-block }
(define-map bid-history uint {
    total-bids: uint,
    last-bid-block: uint,
    volume-multiplier: uint
})

;; Global Auction Counter
(define-data-var auction-counter uint u0)

;; private functions

;; Authorization check
(define-private (is-authorized)
    (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender ORACLE-ADDR)))

;; Calculate Adaptive Multiplier based on Sentiment
;; Returns a percentage (e.g., u120 for 120%) to adjust prices.
(define-read-only (get-adaptive-multiplier (collection-id uint))
    (let ((sentiment (default-to u50 (map-get? market-sentiment collection-id))))
        (if (> sentiment u80) u125      ;; Extremely Bullish: +25%
        (if (> sentiment u60) u110      ;; Bullish: +10%
        (if (< sentiment u20) u75       ;; Extremely Bearish: -25%
        (if (< sentiment u40) u90       ;; Bearish: -10%
        u100))))))                      ;; Neutral

;; Calculate Dynamic Commission Rate
;; Adjusts the platform fee based on sentiment to incentivize activity during downturns
;; and capture value during hype cycles.
(define-private (calculate-dynamic-commission (collection-id uint))
    (let ((sentiment (default-to u50 (map-get? market-sentiment collection-id))))
        (if (> sentiment u85) u50       ;; Hype: 5% fee
        (if (> sentiment u70) u40       ;; Strong: 4% fee
        (if (< sentiment u30) u10       ;; Weak: 1% fee (subsidy)
        BASE-COMMISSION)))))            ;; Standard: 2.5%

;; Calculate Adaptive Minimum Bid
(define-private (calculate-adaptive-price (current-price uint) (collection-id uint))
    (let (
        (sentiment-mult (get-adaptive-multiplier collection-id))
        (adjusted-price (/ (* current-price sentiment-mult) u100))
    )
    adjusted-price))

;; public functions

;; Administrative: Whitelist a collection
(define-public (add-to-whitelist (collection-id uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map-set whitelisted-collections collection-id true))))

;; Administrative: Remove from whitelist
(define-public (remove-from-whitelist (collection-id uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map-delete whitelisted-collections collection-id))))

;; Oracle: Update Market Sentiment
(define-public (update-market-sentiment (collection-id uint) (score uint))
    (begin
        (asserts! (is-authorized) ERR-NOT-AUTHORIZED)
        ;; Ensure score is within valid range 0-100
        (asserts! (<= score u100) (err u109)) 
        (ok (map-set market-sentiment collection-id score))))

;; Create Auction
;; Starts a new auction if the collection is whitelisted and parameters are valid.
(define-public (start-auction (nft-id uint) (collection-id uint) (base-price uint) (duration uint) (category (string-ascii 20)))
    (let ((new-id (+ (var-get auction-counter) u1)))
        (asserts! (default-to false (map-get? whitelisted-collections collection-id)) ERR-COLLECTION-NOT-WHITELISTED)
        (asserts! (and (>= duration MIN-AUCTION-DURATION) (<= duration MAX-AUCTION-DURATION)) ERR-INVALID-DURATION)
        
        (map-set auctions new-id {
            seller: tx-sender,
            nft-id: nft-id,
            collection-id: collection-id,
            base-price: base-price,
            start-block: block-height,
            end-block: (+ block-height duration),
            active: true,
            category: category
        })
        (map-set bid-history new-id {
            total-bids: u0,
            last-bid-block: block-height,
            volume-multiplier: u100
        })
        (var-set auction-counter new-id)
        (ok new-id)))

;; Place Bid
;; Allows users to place bids. Enforces adaptive minimums and updates history.
(define-public (place-bid (auction-id uint) (amount uint))
    (let (
        (auction (unwrap! (map-get? auctions auction-id) ERR-AUCTION-NOT-FOUND))
        (current-bid-data (map-get? bids auction-id))
        (current-price (default-to (get base-price auction) (get amount current-bid-data)))
        (collection-id (get collection-id auction))
        (min-bid (calculate-adaptive-price current-price collection-id))
        (history (unwrap! (map-get? bid-history auction-id) ERR-AUCTION-NOT-FOUND))
    )
    (begin
        (asserts! (get active auction) ERR-AUCTION-ENDED)
        (asserts! (< block-height (get end-block auction)) ERR-AUCTION-ENDED)
        (asserts! (>= amount min-bid) ERR-BID-TOO-LOW)
        
        ;; Ensure minimum increment over previous bid
        (asserts! (or (is-none current-bid-data) 
                      (>= amount (/ (* (unwrap-panic (get amount current-bid-data)) (+ u100 MIN-BID-INCREMENT)) u100)))
                  ERR-BID-INCREMENT-TOO-SMALL)

        ;; Refund previous bidder
        (match current-bid-data
            prev-bid (try! (as-contract (stx-transfer? (get amount prev-bid) (get bidder prev-bid) tx-sender)))
            true)

        ;; Lock new bid
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        ;; Update state
        (map-set bids auction-id { bidder: tx-sender, amount: amount, block-height: block-height })
        
        ;; Update history for AI analysis
        (map-set bid-history auction-id {
            total-bids: (+ (get total-bids history) u1),
            last-bid-block: block-height,
            volume-multiplier: (if (> (+ (get total-bids history) u1) u10) u120 u100) ;; Simple example logic
        })
        
        (ok true))))

;; Cancel Auction
;; Allows seller to cancel if no bids have been placed.
(define-public (cancel-auction (auction-id uint))
    (let (
        (auction (unwrap! (map-get? auctions auction-id) ERR-AUCTION-NOT-FOUND))
    )
    (begin
        (asserts! (is-eq tx-sender (get seller auction)) ERR-NOT-AUTHORIZED)
        (asserts! (get active auction) ERR-AUCTION-ENDED)
        (asserts! (is-none (map-get? bids auction-id)) ERR-CANCELLATION-FORBIDDEN)
        
        (map-set auctions auction-id (merge auction { active: false }))
        (ok true))))

;; Finalize Auction - Core AI Logic and Settlement
;; This function handles the logic for closing an auction, validating the highest bid,
;; adjusting the commission based on AI sentiment, and settling the transaction.
(define-public (finalize-auction (auction-id uint))
    (let (
        (auction (unwrap! (map-get? auctions auction-id) ERR-AUCTION-NOT-FOUND))
        (highest-bid (unwrap! (map-get? bids auction-id) ERR-BID-TOO-LOW))
        (collection-id (get collection-id auction))
        (sentiment (default-to u50 (map-get? market-sentiment collection-id)))
        
        ;; Dynamic commission logic based on AI market sentiment
        (commission-rate (calculate-dynamic-commission collection-id))
        (commission (/ (* (get amount highest-bid) commission-rate) u1000))
        (payout (- (get amount highest-bid) commission))
    )
    (begin
        ;; Security checks
        (asserts! (get active auction) ERR-AUCTION-ENDED)
        (asserts! (>= block-height (get end-block auction)) ERR-AUCTION-ACTIVE)
        
        ;; Deactivate auction before processing to prevent double settlement
        (map-set auctions auction-id (merge auction { active: false }))
        
        ;; Log the transfer (simulation)
        (print { 
            event: "nft-transfer", 
            to: (get bidder highest-bid), 
            nft-id: (get nft-id auction),
            price: (get amount highest-bid),
            commission: commission
        })
        
        ;; Payout to seller
        (try! (as-contract (stx-transfer? payout tx-sender (get seller auction))))
        
        ;; Payout commission to contract owner
        (if (> commission u0)
            (try! (as-contract (stx-transfer? commission tx-sender CONTRACT-OWNER)))
            true)
            
        (ok {
            winner: (get bidder highest-bid),
            amount: (get amount highest-bid),
            commission-paid: commission,
            final-sentiment: sentiment
        }))))

;; Analyze Auction Performance (New Feature: 25+ lines)
;; This function provides a detailed post-mortem analysis of an auction.
;; It calculates various potential metrics that an AI oracle could use
;; to adjust future sentiment scores. It aggregates data from the auction params,
;; final bid, history, and current sentiment to produce a "performance report".
(define-read-only (analyze-auction-performance (auction-id uint))
    (let (
        (auction (unwrap! (map-get? auctions auction-id) ERR-AUCTION-NOT-FOUND))
        (bid-info (map-get? bids auction-id))
        (history (unwrap! (map-get? bid-history auction-id) ERR-AUCTION-NOT-FOUND))
        (sentiment (default-to u50 (map-get? market-sentiment (get collection-id auction))))
        
        ;; Calculated Metrics
        (final-price (default-to u0 (get amount bid-info)))
        (price-delta (if (> final-price (get base-price auction))
                         (- final-price (get base-price auction))
                         u0))
        (duration-blocks (- (get end-block auction) (get start-block auction)))
        (bids-per-100-blocks (/ (* (get total-bids history) u100) duration-blocks))
        
        ;; Performance classification
        (performance-rating 
            (if (and (> price-delta u0) (> bids-per-100-blocks u5))
                "HOT"
                (if (> price-delta u0)
                    "STEADY"
                    (if (is-some bid-info) "WEAK" "FAILED"))))
                    
        ;; AI Feedback Score (Hypothetical future input)
        (ai-feedback-score 
             (+ 
                (/ sentiment u2) ;; 50% weight on sentiment
                (/ (* bids-per-100-blocks u5) u2) ;; Weight on activity
             ))
    )
    (ok {
        auction-id: auction-id,
        category: (get category auction),
        final-result: {
            sold: (is-some bid-info),
            price: final-price,
            delta-from-reserve: price-delta
        },
        engagement-metrics: {
            total-bids: (get total-bids history),
            velocity: bids-per-100-blocks,
            last-bid-block: (get last-bid-block history)
        },
        market-context: {
            sentiment-at-close: sentiment,
            implied-performance: performance-rating,
            projected-ai-score: ai-feedback-score
        },
        recommendation: (if (is-eq performance-rating "HOT") 
                            "INCREASE_SENTIMENT" 
                            (if (is-eq performance-rating "FAILED") 
                                "DECREASE_SENTIMENT" 
                                "MAINTAIN"))
    })))


