(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-not-registered (err u105))
(define-constant err-invalid-energy (err u106))
(define-constant err-cooldown-active (err u107))

(define-fungible-token solar-token)

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
