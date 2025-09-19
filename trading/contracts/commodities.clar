;; Commodities Trading Contract
;; A robust smart contract for trading physical commodities

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-insufficient-balance (err u104))
(define-constant err-trade-not-active (err u105))
(define-constant err-already-exists (err u106))
(define-constant err-invalid-status (err u107))
(define-constant err-delivery-failed (err u108))
(define-constant err-invalid-input (err u109))

;; Data Variables
(define-data-var next-trade-id uint u1)
(define-data-var contract-active bool true)
(define-data-var total-volume uint u0)
(define-data-var platform-fee uint u25) ;; 0.25% in basis points

;; Data Maps
(define-map trades
  { trade-id: uint }
  {
    seller: principal,
    buyer: (optional principal),
    commodity: (string-ascii 50),
    quantity: uint,
    price-per-unit: uint,
    total-value: uint,
    status: (string-ascii 20),
    created-at: uint,
    expires-at: uint,
    quality-grade: (string-ascii 10),
    delivery-location: (string-ascii 100)
  }
)

(define-map user-balances
  { user: principal }
  { balance: uint }
)

(define-map commodity-inventory
  { user: principal, commodity: (string-ascii 50) }
  { quantity: uint }
)

(define-map authorized-inspectors
  { inspector: principal }
  { authorized: bool }
)

;; Private Functions
(define-private (is-contract-owner)
  (is-eq tx-sender contract-owner)
)

(define-private (calculate-fee (amount uint))
  (/ (* amount (var-get platform-fee)) u10000)
)

(define-private (transfer-funds (from principal) (to principal) (amount uint))
  (let ((from-balance (default-to u0 (get balance (map-get? user-balances {user: from}))))
        (to-balance (default-to u0 (get balance (map-get? user-balances {user: to})))))
    (if (>= from-balance amount)
      (begin
        (map-set user-balances {user: from} {balance: (- from-balance amount)})
        (map-set user-balances {user: to} {balance: (+ to-balance amount)})
        (ok true))
      (err u104)))
)

(define-private (update-inventory (user principal) (commodity (string-ascii 50)) (quantity-change int))
  (let ((current-qty (default-to u0 (get quantity (map-get? commodity-inventory {user: user, commodity: commodity}))))
        (new-qty (+ (to-int current-qty) quantity-change)))
    (if (>= new-qty 0)
      (begin
        (map-set commodity-inventory 
          {user: user, commodity: commodity} 
          {quantity: (to-uint new-qty)})
        (ok true))
      (err u104)))
)

(define-private (validate-commodity-string (commodity (string-ascii 50)))
  (and (> (len commodity) u0) (<= (len commodity) u50))
)

(define-private (validate-quality-grade (grade (string-ascii 10)))
  (and (> (len grade) u0) (<= (len grade) u10))
)

(define-private (validate-delivery-location (location (string-ascii 100)))
  (and (> (len location) u0) (<= (len location) u100))
)

(define-private (validate-resolution (resolution (string-ascii 20)))
  (and (> (len resolution) u0) (<= (len resolution) u20))
)

;; Public Functions - Admin
(define-public (set-contract-status (active bool))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    ;; Validate boolean input explicitly
    (asserts! (or (is-eq active true) (is-eq active false)) err-invalid-input)
    (var-set contract-active active)
    (ok true))
)

(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    (asserts! (<= new-fee u1000) err-invalid-amount) ;; Max 10%
    (var-set platform-fee new-fee)
    (ok true))
)

(define-public (authorize-inspector (inspector principal))
  (begin
    (asserts! (is-contract-owner) err-owner-only)
    ;; Validate principal is not contract owner to prevent conflicts
    (asserts! (not (is-eq inspector contract-owner)) err-invalid-input)
    (map-set authorized-inspectors {inspector: inspector} {authorized: true})
    (ok true))
)

;; Public Functions - User Operations
(define-public (deposit (amount uint))
  (let ((current-balance (default-to u0 (get balance (map-get? user-balances {user: tx-sender})))))
    (begin
      (asserts! (var-get contract-active) err-invalid-status)
      (asserts! (> amount u0) err-invalid-amount)
      (map-set user-balances {user: tx-sender} {balance: (+ current-balance amount)})
      (ok true)))
)

(define-public (withdraw (amount uint))
  (let ((current-balance (default-to u0 (get balance (map-get? user-balances {user: tx-sender})))))
    (begin
      (asserts! (var-get contract-active) err-invalid-status)
      (asserts! (>= current-balance amount) err-insufficient-balance)
      (map-set user-balances {user: tx-sender} {balance: (- current-balance amount)})
      (ok true)))
)

(define-public (create-trade (commodity (string-ascii 50)) (quantity uint) (price-per-unit uint) 
                           (expires-at uint) (quality-grade (string-ascii 10)) 
                           (delivery-location (string-ascii 100)))
  (let ((trade-id (var-get next-trade-id))
        (total-value (* quantity price-per-unit)))
    (begin
      (asserts! (var-get contract-active) err-invalid-status)
      (asserts! (> quantity u0) err-invalid-amount)
      (asserts! (> price-per-unit u0) err-invalid-amount)
      (asserts! (> expires-at block-height) err-invalid-amount)
      (asserts! (validate-commodity-string commodity) err-invalid-input)
      (asserts! (validate-quality-grade quality-grade) err-invalid-input)
      (asserts! (validate-delivery-location delivery-location) err-invalid-input)
      (try! (update-inventory tx-sender commodity (- (to-int quantity))))
      (map-set trades
        {trade-id: trade-id}
        {
          seller: tx-sender,
          buyer: none,
          commodity: commodity,
          quantity: quantity,
          price-per-unit: price-per-unit,
          total-value: total-value,
          status: "ACTIVE",
          created-at: block-height,
          expires-at: expires-at,
          quality-grade: quality-grade,
          delivery-location: delivery-location
        })
      (var-set next-trade-id (+ trade-id u1))
      (var-set total-volume (+ (var-get total-volume) total-value))
      (ok trade-id)))
)

(define-public (accept-trade (trade-id uint))
  (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-not-found))
        (total-value (get total-value trade))
        (fee (calculate-fee total-value))
        (seller-amount (- total-value fee)))
    (begin
      (asserts! (var-get contract-active) err-invalid-status)
      (asserts! (> trade-id u0) err-invalid-input)
      (asserts! (< trade-id (var-get next-trade-id)) err-not-found)
      (asserts! (is-eq (get status trade) "ACTIVE") err-trade-not-active)
      (asserts! (< block-height (get expires-at trade)) err-trade-not-active)
      (asserts! (not (is-eq tx-sender (get seller trade))) err-unauthorized)
      (try! (transfer-funds tx-sender (get seller trade) seller-amount))
      (try! (transfer-funds tx-sender contract-owner fee))
      (try! (update-inventory tx-sender (get commodity trade) (to-int (get quantity trade))))
      (map-set trades
        {trade-id: trade-id}
        (merge trade {buyer: (some tx-sender), status: "PENDING_DELIVERY"}))
      (ok true)))
)

(define-public (confirm-delivery (trade-id uint))
  (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-not-found)))
    (begin
      (asserts! (var-get contract-active) err-invalid-status)
      (asserts! (> trade-id u0) err-invalid-input)
      (asserts! (< trade-id (var-get next-trade-id)) err-not-found)
      (asserts! (is-eq (get status trade) "PENDING_DELIVERY") err-invalid-status)
      (asserts! (is-eq tx-sender (unwrap! (get buyer trade) err-unauthorized)) err-unauthorized)
      (map-set trades
        {trade-id: trade-id}
        (merge trade {status: "DELIVERED"}))
      (ok true)))
)

(define-public (cancel-trade (trade-id uint))
  (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-not-found)))
    (begin
      (asserts! (var-get contract-active) err-invalid-status)
      (asserts! (> trade-id u0) err-invalid-input)
      (asserts! (< trade-id (var-get next-trade-id)) err-not-found)
      (asserts! (is-eq tx-sender (get seller trade)) err-unauthorized)
      (asserts! (is-eq (get status trade) "ACTIVE") err-invalid-status)
      (try! (update-inventory tx-sender (get commodity trade) (to-int (get quantity trade))))
      (map-set trades
        {trade-id: trade-id}
        (merge trade {status: "CANCELLED"}))
      (ok true)))
)

(define-public (dispute-trade (trade-id uint))
  (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-not-found)))
    (begin
      (asserts! (var-get contract-active) err-invalid-status)
      (asserts! (> trade-id u0) err-invalid-input)
      (asserts! (< trade-id (var-get next-trade-id)) err-not-found)
      (asserts! (is-eq (get status trade) "PENDING_DELIVERY") err-invalid-status)
      (asserts! (or (is-eq tx-sender (get seller trade))
                    (is-eq tx-sender (unwrap! (get buyer trade) err-unauthorized))) err-unauthorized)
      (map-set trades
        {trade-id: trade-id}
        (merge trade {status: "DISPUTED"}))
      (ok true)))
)

(define-public (resolve-dispute (trade-id uint) (resolution (string-ascii 20)))
  (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-not-found)))
    (begin
      (asserts! (default-to false (get authorized (map-get? authorized-inspectors {inspector: tx-sender}))) err-unauthorized)
      (asserts! (> trade-id u0) err-invalid-input)
      (asserts! (< trade-id (var-get next-trade-id)) err-not-found)
      (asserts! (validate-resolution resolution) err-invalid-input)
      (asserts! (is-eq (get status trade) "DISPUTED") err-invalid-status)
      (map-set trades
        {trade-id: trade-id}
        (merge trade {status: resolution}))
      (ok true)))
)

;; Read-Only Functions
(define-read-only (get-trade (trade-id uint))
  (map-get? trades {trade-id: trade-id})
)

(define-read-only (get-user-balance (user principal))
  (default-to u0 (get balance (map-get? user-balances {user: user})))
)

(define-read-only (get-inventory (user principal) (commodity (string-ascii 50)))
  (default-to u0 (get quantity (map-get? commodity-inventory {user: user, commodity: commodity})))
)

(define-read-only (get-contract-stats)
  {
    total-trades: (- (var-get next-trade-id) u1),
    total-volume: (var-get total-volume),
    platform-fee: (var-get platform-fee),
    contract-active: (var-get contract-active)
  }
)

(define-read-only (is-inspector-authorized (inspector principal))
  (default-to false (get authorized (map-get? authorized-inspectors {inspector: inspector})))
)