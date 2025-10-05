;; Dog Park Facility Registry Smart Contract
;; Tracks dog park facilities, equipment condition, and maintenance needs across community locations
;; Provides comprehensive facility management with equipment monitoring and maintenance coordination

;; ===== CONSTANTS =====
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_FACILITY_NOT_FOUND (err u101))
(define-constant ERR_EQUIPMENT_NOT_FOUND (err u102))
(define-constant ERR_INVALID_CONDITION (err u103))
(define-constant ERR_INVALID_STATUS (err u104))
(define-constant ERR_MAINTENANCE_NOT_FOUND (err u105))
(define-constant ERR_ALREADY_COMPLETED (err u106))

;; Equipment condition levels
(define-constant CONDITION_EXCELLENT u5)
(define-constant CONDITION_GOOD u4)
(define-constant CONDITION_FAIR u3)
(define-constant CONDITION_POOR u2)
(define-constant CONDITION_BROKEN u1)

;; Maintenance status types
(define-constant STATUS_REQUESTED u1)
(define-constant STATUS_IN_PROGRESS u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_CANCELLED u4)

;; ===== DATA VARIABLES =====
(define-data-var facility-counter uint u0)
(define-data-var equipment-counter uint u0)
(define-data-var maintenance-counter uint u0)

;; ===== DATA MAPS =====

;; Facility registry with comprehensive information
(define-map facilities uint {
  name: (string-ascii 100),
  address: (string-ascii 200),
  manager: principal,
  created-at: uint,
  last-updated: uint,
  total-equipment: uint,
  average-condition: uint,
  maintenance-requests: uint,
  is-active: bool
})

;; Equipment registry for each facility
(define-map equipment uint {
  facility-id: uint,
  equipment-type: (string-ascii 50),
  description: (string-ascii 200),
  condition: uint,
  installed-date: uint,
  last-maintenance: uint,
  next-maintenance: uint,
  replacement-cost: uint,
  is-critical: bool
})

;; Maintenance request tracking
(define-map maintenance-requests uint {
  facility-id: uint,
  equipment-id: (optional uint),
  description: (string-ascii 300),
  priority: uint,
  status: uint,
  requested-by: principal,
  requested-at: uint,
  assigned-to: (optional principal),
  estimated-cost: uint,
  actual-cost: (optional uint),
  completed-at: (optional uint),
  completion-notes: (optional (string-ascii 200))
})

;; Equipment types for standardization
(define-map equipment-types (string-ascii 50) {
  standard-lifespan: uint,
  maintenance-frequency: uint,
  average-cost: uint,
  is-critical: bool
})

;; Facility managers and permissions
(define-map facility-managers principal (list 20 uint))

;; Usage statistics tracking
(define-map facility-usage uint {
  daily-visitors: uint,
  peak-hours: (list 5 uint),
  safety-incidents: uint,
  last-inspection: uint,
  accessibility-rating: uint
})

;; ===== PRIVATE FUNCTIONS =====

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

;; Check if caller is facility manager
(define-private (is-facility-manager (facility-id uint))
  (match (map-get? facilities facility-id)
    facility (is-eq tx-sender (get manager facility))
    false
  )
)

;; Calculate average condition for facility
(define-private (calculate-average-condition (facility-id uint))
  ;; Simplified version that returns default condition
  ;; In a full implementation, this would aggregate equipment conditions
  u3 ;; Return fair condition as default
)

;; Helper function to get equipment condition
(define-private (get-equipment-condition (equipment-id uint))
  (match (map-get? equipment equipment-id)
    equip (get condition equip)
    u0
  )
)

;; Filter equipment by facility (simplified version)
(define-private (filter-equipment-by-facility (facility-id uint))
  ;; In a real implementation, this would iterate through all equipment
  ;; For simplicity, returning empty list
  (list)
)

;; Validate condition value
(define-private (is-valid-condition (condition uint))
  (and (>= condition CONDITION_BROKEN) (<= condition CONDITION_EXCELLENT))
)

;; Validate maintenance status
(define-private (is-valid-status (status uint))
  (and (>= status STATUS_REQUESTED) (<= status STATUS_CANCELLED))
)

;; ===== PUBLIC FUNCTIONS =====

;; Register a new dog park facility
(define-public (register-facility 
  (name (string-ascii 100))
  (address (string-ascii 200))
  (manager principal)
)
  (let (
    (new-id (+ (var-get facility-counter) u1))
    (current-time stacks-block-height)
  )
    (begin
      (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
      (map-set facilities new-id {
        name: name,
        address: address,
        manager: manager,
        created-at: current-time,
        last-updated: current-time,
        total-equipment: u0,
        average-condition: u0,
        maintenance-requests: u0,
        is-active: true
      })
      ;; Initialize usage statistics
      (map-set facility-usage new-id {
        daily-visitors: u0,
        peak-hours: (list u9 u10 u11 u15 u16),
        safety-incidents: u0,
        last-inspection: current-time,
        accessibility-rating: u3
      })
      (var-set facility-counter new-id)
      (ok new-id)
    )
  )
)

;; Add equipment to a facility
(define-public (add-equipment
  (facility-id uint)
  (equipment-type (string-ascii 50))
  (description (string-ascii 200))
  (condition uint)
  (replacement-cost uint)
  (is-critical bool)
)
  (let (
    (new-equipment-id (+ (var-get equipment-counter) u1))
    (current-time stacks-block-height)
  )
    (begin
      (asserts! (is-some (map-get? facilities facility-id)) ERR_FACILITY_NOT_FOUND)
      (asserts! (or (is-facility-manager facility-id) (is-contract-owner)) ERR_UNAUTHORIZED)
      (asserts! (is-valid-condition condition) ERR_INVALID_CONDITION)
      
      (map-set equipment new-equipment-id {
        facility-id: facility-id,
        equipment-type: equipment-type,
        description: description,
        condition: condition,
        installed-date: current-time,
        last-maintenance: current-time,
        next-maintenance: (+ current-time u52560), ;; Approximately 1 year
        replacement-cost: replacement-cost,
        is-critical: is-critical
      })
      
      ;; Update facility stats
      (update-facility-equipment-stats facility-id)
      (var-set equipment-counter new-equipment-id)
      (ok new-equipment-id)
    )
  )
)

;; Update equipment condition
(define-public (update-equipment-condition (equipment-id uint) (new-condition uint))
  (let (
    (equipment-data (unwrap! (map-get? equipment equipment-id) ERR_EQUIPMENT_NOT_FOUND))
    (facility-id (get facility-id equipment-data))
  )
    (begin
      (asserts! (or (is-facility-manager facility-id) (is-contract-owner)) ERR_UNAUTHORIZED)
      (asserts! (is-valid-condition new-condition) ERR_INVALID_CONDITION)
      
      (map-set equipment equipment-id (merge equipment-data {
        condition: new-condition,
        last-maintenance: stacks-block-height
      }))
      
      ;; Update facility average condition
      (update-facility-equipment-stats facility-id)
      (ok true)
    )
  )
)

;; Create maintenance request
(define-public (create-maintenance-request
  (facility-id uint)
  (equipment-id (optional uint))
  (description (string-ascii 300))
  (priority uint)
  (estimated-cost uint)
)
  (let (
    (new-request-id (+ (var-get maintenance-counter) u1))
  )
    (begin
      (asserts! (is-some (map-get? facilities facility-id)) ERR_FACILITY_NOT_FOUND)
      ;; Verify equipment exists if specified
      (if (is-some equipment-id)
        (asserts! (is-some (map-get? equipment (unwrap-panic equipment-id))) ERR_EQUIPMENT_NOT_FOUND)
        true
      )
      
      (map-set maintenance-requests new-request-id {
        facility-id: facility-id,
        equipment-id: equipment-id,
        description: description,
        priority: priority,
        status: STATUS_REQUESTED,
        requested-by: tx-sender,
        requested-at: stacks-block-height,
        assigned-to: none,
        estimated-cost: estimated-cost,
        actual-cost: none,
        completed-at: none,
        completion-notes: none
      })
      
      ;; Update facility maintenance request count
      (increment-facility-maintenance-count facility-id)
      (var-set maintenance-counter new-request-id)
      (ok new-request-id)
    )
  )
)

;; Complete maintenance request
(define-public (complete-maintenance-request
  (request-id uint)
  (actual-cost uint)
  (completion-notes (string-ascii 200))
)
  (let (
    (request-data (unwrap! (map-get? maintenance-requests request-id) ERR_MAINTENANCE_NOT_FOUND))
    (facility-id (get facility-id request-data))
  )
    (begin
      (asserts! (or (is-facility-manager facility-id) (is-contract-owner)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status request-data) STATUS_IN_PROGRESS) ERR_ALREADY_COMPLETED)
      
      (map-set maintenance-requests request-id (merge request-data {
        status: STATUS_COMPLETED,
        actual-cost: (some actual-cost),
        completed-at: (some stacks-block-height),
        completion-notes: (some completion-notes)
      }))
      
      ;; If equipment-specific, update maintenance date
      (match (get equipment-id request-data)
        equipment-id (update-equipment-maintenance-date equipment-id)
        true
      )
      
      (ok true)
    )
  )
)

;; Update facility usage statistics
(define-public (update-facility-usage
  (facility-id uint)
  (daily-visitors uint)
  (safety-incidents uint)
  (accessibility-rating uint)
)
  (let (
    (usage-data (unwrap! (map-get? facility-usage facility-id) ERR_FACILITY_NOT_FOUND))
  )
    (begin
      (asserts! (or (is-facility-manager facility-id) (is-contract-owner)) ERR_UNAUTHORIZED)
      
      (map-set facility-usage facility-id (merge usage-data {
        daily-visitors: daily-visitors,
        safety-incidents: safety-incidents,
        accessibility-rating: accessibility-rating,
        last-inspection: stacks-block-height
      }))
      
      (ok true)
    )
  )
)

;; ===== HELPER FUNCTIONS =====

;; Update facility equipment statistics
(define-private (update-facility-equipment-stats (facility-id uint))
  (match (map-get? facilities facility-id)
    facility-data (
      begin
        (map-set facilities facility-id (merge facility-data {
          last-updated: stacks-block-height,
          average-condition: (calculate-average-condition facility-id)
        }))
        true
      )
    false
  )
)

;; Increment maintenance request count for facility
(define-private (increment-facility-maintenance-count (facility-id uint))
  (match (map-get? facilities facility-id)
    facility-data (
      map-set facilities facility-id (merge facility-data {
        maintenance-requests: (+ (get maintenance-requests facility-data) u1)
      })
    )
    false
  )
)

;; Update equipment maintenance date
(define-private (update-equipment-maintenance-date (equipment-id uint))
  (match (map-get? equipment equipment-id)
    equipment-data (
      map-set equipment equipment-id (merge equipment-data {
        last-maintenance: stacks-block-height,
        next-maintenance: (+ stacks-block-height u52560) ;; Next year
      })
    )
    false
  )
)

;; ===== READ-ONLY FUNCTIONS =====

;; Get facility information
(define-read-only (get-facility (facility-id uint))
  (map-get? facilities facility-id)
)

;; Get equipment information
(define-read-only (get-equipment (equipment-id uint))
  (map-get? equipment equipment-id)
)

;; Get maintenance request
(define-read-only (get-maintenance-request (request-id uint))
  (map-get? maintenance-requests request-id)
)

;; Get facility usage statistics
(define-read-only (get-facility-usage (facility-id uint))
  (map-get? facility-usage facility-id)
)

;; Get total facility count
(define-read-only (get-facility-count)
  (var-get facility-counter)
)

;; Get total equipment count
(define-read-only (get-equipment-count)
  (var-get equipment-counter)
)

;; Get total maintenance request count
(define-read-only (get-maintenance-count)
  (var-get maintenance-counter)
)
