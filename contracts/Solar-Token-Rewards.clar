(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-not-registered (err u105))
(define-constant err-invalid-energy (err u106))
(define-constant err-cooldown-active (err u107))
(define-constant err-achievement-exists (err u108))
(define-constant err-milestone-not-reached (err u109))
(define-constant err-carbon-credit-not-found (err u110))
(define-constant err-insufficient-energy-for-credit (err u111))
(define-constant err-carbon-credit-not-owned (err u112))
(define-constant err-invalid-price (err u113))
(define-constant err-listing-not-found (err u114))

(define-fungible-token solar-token)
(define-non-fungible-token achievement-nft {
    achievement-type: uint,
    producer: principal,
})

(define-non-fungible-token carbon-credit {
    credit-id: uint,
    energy-amount: uint,
    producer: principal,
})

(define-map solar-producers
    principal
    {
        registered-at: uint,
        total-energy-produced: uint,
        total-rewards-earned: uint,
        last-claim-block: uint,
        energy-rate: uint,
        is-active: bool,
    }
)

(define-map energy-submissions
    {
        producer: principal,
        submission-id: uint,
    }
    {
        energy-amount: uint,
        submitted-at: uint,
        verified: bool,
        reward-amount: uint,
    }
)

(define-map producer-submissions
    principal
    uint
)

(define-data-var total-energy-produced uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var base-reward-rate uint u10)
(define-data-var verification-required bool true)
(define-data-var claim-cooldown uint u144)
(define-data-var max-daily-energy uint u10000)
(define-data-var carbon-credit-counter uint u0)
(define-data-var energy-to-credit-rate uint u100)
(define-data-var min-energy-for-credit uint u500)

(define-map achievement-metadata
    uint
    {
        name: (string-ascii 50),
        description: (string-ascii 100),
        energy-threshold: uint,
        token-bonus: uint,
    }
)

(define-map producer-achievements
    {
        producer: principal,
        achievement-type: uint,
    }
    bool
)

(define-map carbon-credits
    uint
    {
        producer: principal,
        energy-amount: uint,
        created-at: uint,
        is-verified: bool,
        carbon-offset-tons: uint,
    }
)

(define-map carbon-credit-marketplace
    uint
    {
        seller: principal,
        price: uint,
        listed-at: uint,
        is-active: bool,
    }
)

(map-set achievement-metadata u1 {
    name: "Solar Pioneer",
    description: "First 1000 kWh produced",
    energy-threshold: u1000,
    token-bonus: u100,
})
(map-set achievement-metadata u2 {
    name: "Energy Champion",
    description: "Produced 5000+ kWh total",
    energy-threshold: u5000,
    token-bonus: u500,
})
(map-set achievement-metadata u3 {
    name: "Solar Legend",
    description: "Produced 10000+ kWh total",
    energy-threshold: u10000,
    token-bonus: u1000,
})
(map-set achievement-metadata u4 {
    name: "Green Guardian",
    description: "Produced 25000+ kWh total",
    energy-threshold: u25000,
    token-bonus: u2500,
})
(map-set achievement-metadata u5 {
    name: "Renewable Master",
    description: "Produced 50000+ kWh total",
    energy-threshold: u50000,
    token-bonus: u5000,
})

(define-public (register-producer (energy-rate uint))
    (let (
            (producer tx-sender)
            (current-block stacks-block-height)
        )
        (asserts! (> energy-rate u0) err-invalid-amount)
        (asserts! (is-none (map-get? solar-producers producer))
            err-already-exists
        )
        (map-set solar-producers producer {
            registered-at: current-block,
            total-energy-produced: u0,
            total-rewards-earned: u0,
            last-claim-block: u0,
            energy-rate: energy-rate,
            is-active: true,
        })
        (map-set producer-submissions producer u0)
        (ok true)
    )
)

(define-public (submit-energy-production (energy-amount uint))
    (let (
            (producer tx-sender)
            (producer-data (unwrap! (map-get? solar-producers producer) err-not-registered))
            (submission-id (+ (default-to u0 (map-get? producer-submissions producer)) u1))
            (current-block stacks-block-height)
        )
        (asserts! (get is-active producer-data) err-not-registered)
        (asserts! (> energy-amount u0) err-invalid-energy)
        (asserts! (<= energy-amount (var-get max-daily-energy))
            err-invalid-energy
        )
        (map-set energy-submissions {
            producer: producer,
            submission-id: submission-id,
        } {
            energy-amount: energy-amount,
            submitted-at: current-block,
            verified: (not (var-get verification-required)),
            reward-amount: (* energy-amount (var-get base-reward-rate)),
        })
        (map-set producer-submissions producer submission-id)
        (if (not (var-get verification-required))
            (begin
                (try! (process-reward producer submission-id))
                (ok submission-id)
            )
            (ok submission-id)
        )
    )
)

(define-public (verify-energy-submission
        (producer principal)
        (submission-id uint)
    )
    (let (
            (submission-key {
                producer: producer,
                submission-id: submission-id,
            })
            (submission-data (unwrap! (map-get? energy-submissions submission-key) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get verified submission-data)) err-already-exists)
        (map-set energy-submissions submission-key
            (merge submission-data { verified: true })
        )
        (try! (process-reward producer submission-id))
        (ok true)
    )
)

(define-private (process-reward
        (producer principal)
        (submission-id uint)
    )
    (let (
            (submission-key {
                producer: producer,
                submission-id: submission-id,
            })
            (submission-data (unwrap! (map-get? energy-submissions submission-key) err-not-found))
            (producer-data (unwrap! (map-get? solar-producers producer) err-not-registered))
            (energy-amount (get energy-amount submission-data))
            (reward-amount (get reward-amount submission-data))
        )
        (asserts! (get verified submission-data) err-not-found)
        (try! (ft-mint? solar-token reward-amount producer))
        (map-set solar-producers producer
            (merge producer-data {
                total-energy-produced: (+ (get total-energy-produced producer-data) energy-amount),
                total-rewards-earned: (+ (get total-rewards-earned producer-data) reward-amount),
            })
        )
        (var-set total-energy-produced
            (+ (var-get total-energy-produced) energy-amount)
        )
        (var-set total-rewards-distributed
            (+ (var-get total-rewards-distributed) reward-amount)
        )
        (try! (check-achievements producer))
        (ok reward-amount)
    )
)

(define-public (claim-bonus-rewards)
    (let (
            (producer tx-sender)
            (producer-data (unwrap! (map-get? solar-producers producer) err-not-registered))
            (current-block stacks-block-height)
            (last-claim (get last-claim-block producer-data))
            (blocks-since-claim (- current-block last-claim))
            (energy-produced (get total-energy-produced producer-data))
        )
        (asserts! (get is-active producer-data) err-not-registered)
        (asserts! (>= blocks-since-claim (var-get claim-cooldown))
            err-cooldown-active
        )
        (asserts! (> energy-produced u0) err-invalid-amount)
        (let ((bonus-amount (/ (* energy-produced blocks-since-claim) u1000)))
            (asserts! (> bonus-amount u0) err-invalid-amount)
            (try! (ft-mint? solar-token bonus-amount producer))
            (map-set solar-producers producer
                (merge producer-data {
                    last-claim-block: current-block,
                    total-rewards-earned: (+ (get total-rewards-earned producer-data) bonus-amount),
                })
            )
            (var-set total-rewards-distributed
                (+ (var-get total-rewards-distributed) bonus-amount)
            )
            (ok bonus-amount)
        )
    )
)

(define-public (transfer-tokens
        (amount uint)
        (recipient principal)
    )
    (ft-transfer? solar-token amount tx-sender recipient)
)

(define-public (deactivate-producer)
    (let (
            (producer tx-sender)
            (producer-data (unwrap! (map-get? solar-producers producer) err-not-registered))
        )
        (map-set solar-producers producer
            (merge producer-data { is-active: false })
        )
        (ok true)
    )
)

(define-public (reactivate-producer)
    (let (
            (producer tx-sender)
            (producer-data (unwrap! (map-get? solar-producers producer) err-not-registered))
        )
        (map-set solar-producers producer
            (merge producer-data { is-active: true })
        )
        (ok true)
    )
)

(define-public (set-base-reward-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> new-rate u0) err-invalid-amount)
        (var-set base-reward-rate new-rate)
        (ok true)
    )
)

(define-public (set-verification-required (required bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set verification-required required)
        (ok true)
    )
)

(define-public (set-claim-cooldown (blocks uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set claim-cooldown blocks)
        (ok true)
    )
)

(define-public (set-max-daily-energy (max-energy uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> max-energy u0) err-invalid-amount)
        (var-set max-daily-energy max-energy)
        (ok true)
    )
)

(define-read-only (get-producer-info (producer principal))
    (map-get? solar-producers producer)
)

(define-read-only (get-energy-submission
        (producer principal)
        (submission-id uint)
    )
    (map-get? energy-submissions {
        producer: producer,
        submission-id: submission-id,
    })
)

(define-read-only (get-producer-submission-count (producer principal))
    (default-to u0 (map-get? producer-submissions producer))
)

(define-read-only (get-token-balance (account principal))
    (ft-get-balance solar-token account)
)

(define-read-only (get-total-supply)
    (ft-get-supply solar-token)
)

(define-read-only (get-contract-stats)
    {
        total-energy-produced: (var-get total-energy-produced),
        total-rewards-distributed: (var-get total-rewards-distributed),
        base-reward-rate: (var-get base-reward-rate),
        verification-required: (var-get verification-required),
        claim-cooldown: (var-get claim-cooldown),
        max-daily-energy: (var-get max-daily-energy),
    }
)

(define-read-only (calculate-potential-bonus (producer principal))
    (let ((producer-data (map-get? solar-producers producer)))
        (match producer-data
            data (let (
                    (current-block stacks-block-height)
                    (last-claim (get last-claim-block data))
                    (blocks-since-claim (- current-block last-claim))
                    (energy-produced (get total-energy-produced data))
                )
                (if (>= blocks-since-claim (var-get claim-cooldown))
                    (some (/ (* energy-produced blocks-since-claim) u1000))
                    none
                )
            )
            none
        )
    )
)

(define-read-only (get-producer-energy-rate (producer principal))
    (match (map-get? solar-producers producer)
        data (some (get energy-rate data))
        none
    )
)

(define-read-only (is-producer-active (producer principal))
    (match (map-get? solar-producers producer)
        data (get is-active data)
        false
    )
)

(define-private (check-achievements (producer principal))
    (let (
            (producer-data (unwrap! (map-get? solar-producers producer) err-not-registered))
            (total-energy (get total-energy-produced producer-data))
        )
        (try! (award-achievement-if-eligible producer u1 total-energy))
        (try! (award-achievement-if-eligible producer u2 total-energy))
        (try! (award-achievement-if-eligible producer u3 total-energy))
        (try! (award-achievement-if-eligible producer u4 total-energy))
        (try! (award-achievement-if-eligible producer u5 total-energy))
        (ok true)
    )
)

(define-private (award-achievement-if-eligible
        (producer principal)
        (achievement-type uint)
        (total-energy uint)
    )
    (let (
            (achievement-data (unwrap! (map-get? achievement-metadata achievement-type)
                err-not-found
            ))
            (threshold (get energy-threshold achievement-data))
            (bonus (get token-bonus achievement-data))
            (achievement-key {
                producer: producer,
                achievement-type: achievement-type,
            })
        )
        (if (and (>= total-energy threshold) (is-none (map-get? producer-achievements achievement-key)))
            (begin
                (map-set producer-achievements achievement-key true)
                (try! (nft-mint? achievement-nft {
                    achievement-type: achievement-type,
                    producer: producer,
                }
                    producer
                ))
                (try! (ft-mint? solar-token bonus producer))
                (ok true)
            )
            (ok false)
        )
    )
)

(define-public (claim-achievement (achievement-type uint))
    (let (
            (producer tx-sender)
            (producer-data (unwrap! (map-get? solar-producers producer) err-not-registered))
            (achievement-data (unwrap! (map-get? achievement-metadata achievement-type)
                err-not-found
            ))
            (total-energy (get total-energy-produced producer-data))
            (threshold (get energy-threshold achievement-data))
            (bonus (get token-bonus achievement-data))
            (achievement-key {
                producer: producer,
                achievement-type: achievement-type,
            })
        )
        (asserts! (>= total-energy threshold) err-milestone-not-reached)
        (asserts! (is-none (map-get? producer-achievements achievement-key))
            err-achievement-exists
        )
        (map-set producer-achievements achievement-key true)
        (try! (nft-mint? achievement-nft {
            achievement-type: achievement-type,
            producer: producer,
        }
            producer
        ))
        (try! (ft-mint? solar-token bonus producer))
        (ok true)
    )
)

(define-read-only (get-achievement-info (achievement-type uint))
    (map-get? achievement-metadata achievement-type)
)

(define-read-only (has-achievement
        (producer principal)
        (achievement-type uint)
    )
    (is-some (map-get? producer-achievements {
        producer: producer,
        achievement-type: achievement-type,
    }))
)

(define-read-only (get-producer-achievements (producer principal))
    {
        pioneer: (has-achievement producer u1),
        champion: (has-achievement producer u2),
        legend: (has-achievement producer u3),
        guardian: (has-achievement producer u4),
        master: (has-achievement producer u5),
    }
)

(define-read-only (get-nft-owner
        (achievement-type uint)
        (producer principal)
    )
    (nft-get-owner? achievement-nft {
        achievement-type: achievement-type,
        producer: producer,
    })
)

(define-public (transfer-achievement
        (achievement-type uint)
        (original-producer principal)
        (recipient principal)
    )
    (nft-transfer? achievement-nft {
        achievement-type: achievement-type,
        producer: original-producer,
    }
        tx-sender recipient
    )
)

;; Carbon Credit Trading Functions

(define-public (mint-carbon-credit (energy-amount uint))
    (let (
            (producer tx-sender)
            (producer-data (unwrap! (map-get? solar-producers producer) err-not-registered))
            (current-block stacks-block-height)
            (credit-id (+ (var-get carbon-credit-counter) u1))
            (carbon-tons (/ energy-amount (var-get energy-to-credit-rate)))
        )
        (asserts! (get is-active producer-data) err-not-registered)
        (asserts! (>= energy-amount (var-get min-energy-for-credit))
            err-insufficient-energy-for-credit
        )
        (asserts! (>= (get total-energy-produced producer-data) energy-amount)
            err-insufficient-energy-for-credit
        )
        (var-set carbon-credit-counter credit-id)
        (map-set carbon-credits credit-id {
            producer: producer,
            energy-amount: energy-amount,
            created-at: current-block,
            is-verified: true,
            carbon-offset-tons: carbon-tons,
        })
        (try! (nft-mint? carbon-credit {
            credit-id: credit-id,
            energy-amount: energy-amount,
            producer: producer,
        }
            producer
        ))
        (ok credit-id)
    )
)

(define-public (transfer-carbon-credit
        (credit-id uint)
        (recipient principal)
    )
    (let (
            (credit-data (unwrap! (map-get? carbon-credits credit-id)
                err-carbon-credit-not-found
            ))
        )
        (asserts! (is-eq tx-sender (get producer credit-data))
            err-carbon-credit-not-owned
        )
        (try! (nft-transfer? carbon-credit {
            credit-id: credit-id,
            energy-amount: (get energy-amount credit-data),
            producer: (get producer credit-data),
        }
            tx-sender recipient
        ))
        (map-set carbon-credits credit-id
            (merge credit-data { producer: recipient })
        )
        (ok true)
    )
)

(define-public (list-carbon-credit-for-sale
        (credit-id uint)
        (price uint)
    )
    (let (
            (credit-data (unwrap! (map-get? carbon-credits credit-id)
                err-carbon-credit-not-found
            ))
            (current-block stacks-block-height)
        )
        (asserts! (is-eq tx-sender (get producer credit-data))
            err-carbon-credit-not-owned
        )
        (asserts! (> price u0) err-invalid-price)
        (map-set carbon-credit-marketplace credit-id {
            seller: tx-sender,
            price: price,
            listed-at: current-block,
            is-active: true,
        })
        (ok true)
    )
)

(define-public (purchase-carbon-credit (credit-id uint))
    (let (
            (listing (unwrap! (map-get? carbon-credit-marketplace credit-id)
                err-listing-not-found
            ))
            (credit-data (unwrap! (map-get? carbon-credits credit-id)
                err-carbon-credit-not-found
            ))
            (buyer tx-sender)
            (seller (get seller listing))
            (price (get price listing))
        )
        (asserts! (get is-active listing) err-listing-not-found)
        (asserts! (>= (ft-get-balance solar-token buyer) price)
            err-insufficient-balance
        )
        (try! (ft-transfer? solar-token price buyer seller))
        (try! (nft-transfer? carbon-credit {
            credit-id: credit-id,
            energy-amount: (get energy-amount credit-data),
            producer: (get producer credit-data),
        }
            seller buyer
        ))
        (map-set carbon-credits credit-id
            (merge credit-data { producer: buyer })
        )
        (map-set carbon-credit-marketplace credit-id
            (merge listing { is-active: false })
        )
        (ok true)
    )
)

(define-public (cancel-carbon-credit-listing (credit-id uint))
    (let (
            (listing (unwrap! (map-get? carbon-credit-marketplace credit-id)
                err-listing-not-found
            ))
        )
        (asserts! (is-eq tx-sender (get seller listing))
            err-carbon-credit-not-owned
        )
        (map-set carbon-credit-marketplace credit-id
            (merge listing { is-active: false })
        )
        (ok true)
    )
)

;; Carbon Credit Read-Only Functions

(define-read-only (get-carbon-credit-info (credit-id uint))
    (map-get? carbon-credits credit-id)
)

(define-read-only (get-carbon-credit-listing (credit-id uint))
    (map-get? carbon-credit-marketplace credit-id)
)

(define-read-only (get-carbon-credit-owner (credit-id uint))
    (match (map-get? carbon-credits credit-id)
        data (some (get producer data))
        none
    )
)

(define-read-only (get-carbon-credit-stats)
    {
        total-credits-minted: (var-get carbon-credit-counter),
        energy-to-credit-rate: (var-get energy-to-credit-rate),
        min-energy-for-credit: (var-get min-energy-for-credit),
    }
)

(define-read-only (calculate-carbon-offset (energy-amount uint))
    (/ energy-amount (var-get energy-to-credit-rate))
)

(define-read-only (get-nft-carbon-credit-owner
        (credit-id uint)
        (energy-amount uint)
        (producer principal)
    )
    (nft-get-owner? carbon-credit {
        credit-id: credit-id,
        energy-amount: energy-amount,
        producer: producer,
    })
)

;; Owner-only functions for carbon credits

(define-public (set-energy-to-credit-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> new-rate u0) err-invalid-amount)
        (var-set energy-to-credit-rate new-rate)
        (ok true)
    )
)

(define-public (set-min-energy-for-credit (min-energy uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> min-energy u0) err-invalid-amount)
        (var-set min-energy-for-credit min-energy)
        (ok true)
    )
)
