;; Waste Cleanup Coordination Smart Contract
;; Coordinate community waste cleanup efforts and track responsible pet waste disposal
;; Provides comprehensive cleanup event management, volunteer coordination, and waste tracking

;; ===== CONSTANTS =====
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_EVENT_NOT_FOUND (err u201))
(define-constant ERR_VOLUNTEER_NOT_FOUND (err u202))
(define-constant ERR_INVALID_STATUS (err u203))
(define-constant ERR_EVENT_FULL (err u204))
(define-constant ERR_ALREADY_REGISTERED (err u205))
(define-constant ERR_NOT_REGISTERED (err u206))
(define-constant ERR_EVENT_COMPLETED (err u207))
(define-constant ERR_INVALID_RATING (err u208))
(define-constant ERR_STATION_NOT_FOUND (err u209))

;; Event status types
(define-constant STATUS_SCHEDULED u1)
(define-constant STATUS_IN_PROGRESS u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_CANCELLED u4)

;; Volunteer role types
(define-constant ROLE_VOLUNTEER u1)
(define-constant ROLE_COORDINATOR u2)
(define-constant ROLE_SUPERVISOR u3)

;; Cleanup urgency levels
(define-constant URGENCY_LOW u1)
(define-constant URGENCY_MEDIUM u2)
(define-constant URGENCY_HIGH u3)
(define-constant URGENCY_CRITICAL u4)

;; Station condition levels
(define-constant CONDITION_EMPTY u1)
(define-constant CONDITION_LOW u2)
(define-constant CONDITION_HALF u3)
(define-constant CONDITION_FULL u4)
(define-constant CONDITION_OVERFLOWING u5)

;; ===== DATA VARIABLES =====
(define-data-var cleanup-event-counter uint u0)
(define-data-var volunteer-counter uint u0)
(define-data-var station-counter uint u0)
(define-data-var report-counter uint u0)
(define-data-var total-waste-collected uint u0)
(define-data-var total-volunteer-hours uint u0)

;; ===== DATA MAPS =====

;; Cleanup event registry
(define-map cleanup-events uint {
  title: (string-ascii 100),
  description: (string-ascii 300),
  facility-id: uint,
  organizer: principal,
  scheduled-date: uint,
  duration-hours: uint,
  max-volunteers: uint,
  current-volunteers: uint,
  status: uint,
  bags-collected: uint,
  total-volunteer-hours: uint,
  created-at: uint,
  completion-notes: (optional (string-ascii 200))
})

;; Volunteer registration and tracking
(define-map volunteers uint {
  address: principal,
  name: (string-ascii 50),
  email: (string-ascii 100),
  phone: (string-ascii 20),
  total-events: uint,
  total-hours: uint,
  total-bags-collected: uint,
  reliability-score: uint,
  registered-at: uint,
  last-active: uint,
  preferred-role: uint
})

;; Event volunteer assignments
(define-map event-volunteers {event-id: uint, volunteer-id: uint} {
  role: uint,
  hours-contributed: uint,
  bags-collected: uint,
  registered-at: uint,
  showed-up: bool,
  performance-rating: (optional uint)
})

;; Waste bag station monitoring
(define-map waste-stations uint {
  facility-id: uint,
  location-description: (string-ascii 100),
  station-type: (string-ascii 30),
  capacity: uint,
  current-level: uint,
  condition: uint,
  last-refilled: uint,
  next-refill-due: uint,
  total-refills: uint,
  maintenance-required: bool
})

;; Waste disposal reports
(define-map disposal-reports uint {
  facility-id: uint,
  station-id: (optional uint),
  reporter: principal,
  report-type: (string-ascii 20),
  description: (string-ascii 200),
  urgency: uint,
  reported-at: uint,
  resolved: bool,
  resolved-at: (optional uint),
  resolution-notes: (optional (string-ascii 150))
})

;; Community compliance tracking
(define-map facility-compliance uint {
  total-reports: uint,
  resolved-reports: uint,
  average-resolution-time: uint,
  compliance-score: uint,
  last-inspection: uint,
  violations: uint,
  improvements: uint
})

;; Volunteer performance history
(define-map volunteer-history {volunteer-id: uint, event-id: uint} {
  attendance: bool,
  punctuality-score: uint,
  effort-rating: uint,
  teamwork-rating: uint,
  bags-contributed: uint,
  hours-worked: uint,
  supervisor-notes: (optional (string-ascii 100))
})

;; Cleanup schedule coordination
(define-map cleanup-schedule {facility-id: uint, month: uint, year: uint} {
  scheduled-events: uint,
  completed-events: uint,
  total-volunteers: uint,
  total-bags-collected: uint,
  coverage-score: uint,
  maintenance-needs: (list 10 (string-ascii 50))
})

;; ===== PRIVATE FUNCTIONS =====

;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT_OWNER)
)

;; Check if caller is event organizer
(define-private (is-event-organizer (event-id uint))
  (match (map-get? cleanup-events event-id)
    event (is-eq tx-sender (get organizer event))
    false
  )
)

;; Check if volunteer is registered for event
(define-private (is-volunteer-registered (event-id uint) (volunteer-id uint))
  (is-some (map-get? event-volunteers {event-id: event-id, volunteer-id: volunteer-id}))
)

;; Validate event status
(define-private (is-valid-status (status uint))
  (and (>= status STATUS_SCHEDULED) (<= status STATUS_CANCELLED))
)

;; Validate volunteer role
(define-private (is-valid-role (role uint))
  (and (>= role ROLE_VOLUNTEER) (<= role ROLE_SUPERVISOR))
)

;; Validate rating (1-5 scale)
(define-private (is-valid-rating (rating uint))
  (and (>= rating u1) (<= rating u5))
)

;; Calculate reliability score based on attendance history
(define-private (calculate-reliability-score (total-events uint) (attended-events uint))
  (if (> total-events u0)
      (/ (* attended-events u100) total-events)
      u100
  )
)

;; Update volunteer statistics
(define-private (update-volunteer-stats (volunteer-id uint) (hours uint) (bags uint))
  (match (map-get? volunteers volunteer-id)
    volunteer-data (
      map-set volunteers volunteer-id (merge volunteer-data {
        total-hours: (+ (get total-hours volunteer-data) hours),
        total-bags-collected: (+ (get total-bags-collected volunteer-data) bags),
        last-active: stacks-block-height
      })
    )
    false
  )
)

;; ===== PUBLIC FUNCTIONS =====

;; Register a new volunteer
(define-public (register-volunteer
  (name (string-ascii 50))
  (email (string-ascii 100))
  (phone (string-ascii 20))
  (preferred-role uint)
)
  (let (
    (new-volunteer-id (+ (var-get volunteer-counter) u1))
  )
    (begin
      (asserts! (is-valid-role preferred-role) ERR_INVALID_STATUS)
      
      (map-set volunteers new-volunteer-id {
        address: tx-sender,
        name: name,
        email: email,
        phone: phone,
        total-events: u0,
        total-hours: u0,
        total-bags-collected: u0,
        reliability-score: u100,
        registered-at: stacks-block-height,
        last-active: stacks-block-height,
        preferred-role: preferred-role
      })
      
      (var-set volunteer-counter new-volunteer-id)
      (ok new-volunteer-id)
    )
  )
)

;; Create a new cleanup event
(define-public (create-cleanup-event
  (title (string-ascii 100))
  (description (string-ascii 300))
  (facility-id uint)
  (scheduled-date uint)
  (duration-hours uint)
  (max-volunteers uint)
)
  (let (
    (new-event-id (+ (var-get cleanup-event-counter) u1))
  )
    (begin
      (map-set cleanup-events new-event-id {
        title: title,
        description: description,
        facility-id: facility-id,
        organizer: tx-sender,
        scheduled-date: scheduled-date,
        duration-hours: duration-hours,
        max-volunteers: max-volunteers,
        current-volunteers: u0,
        status: STATUS_SCHEDULED,
        bags-collected: u0,
        total-volunteer-hours: u0,
        created-at: stacks-block-height,
        completion-notes: none
      })
      
      (var-set cleanup-event-counter new-event-id)
      (ok new-event-id)
    )
  )
)

;; Register volunteer for cleanup event
(define-public (register-for-event (event-id uint) (volunteer-id uint) (role uint))
  (let (
    (event-data (unwrap! (map-get? cleanup-events event-id) ERR_EVENT_NOT_FOUND))
    (volunteer-data (unwrap! (map-get? volunteers volunteer-id) ERR_VOLUNTEER_NOT_FOUND))
  )
    (begin
      (asserts! (< (get current-volunteers event-data) (get max-volunteers event-data)) ERR_EVENT_FULL)
      (asserts! (not (is-volunteer-registered event-id volunteer-id)) ERR_ALREADY_REGISTERED)
      (asserts! (is-eq (get status event-data) STATUS_SCHEDULED) ERR_EVENT_COMPLETED)
      (asserts! (is-valid-role role) ERR_INVALID_STATUS)
      (asserts! (is-eq tx-sender (get address volunteer-data)) ERR_UNAUTHORIZED)
      
      ;; Register volunteer for event
      (map-set event-volunteers {event-id: event-id, volunteer-id: volunteer-id} {
        role: role,
        hours-contributed: u0,
        bags-collected: u0,
        registered-at: stacks-block-height,
        showed-up: false,
        performance-rating: none
      })
      
      ;; Update event volunteer count
      (map-set cleanup-events event-id (merge event-data {
        current-volunteers: (+ (get current-volunteers event-data) u1)
      }))
      
      ;; Update volunteer event count
      (map-set volunteers volunteer-id (merge volunteer-data {
        total-events: (+ (get total-events volunteer-data) u1)
      }))
      
      (ok true)
    )
  )
)

;; Record volunteer attendance and contribution
(define-public (record-volunteer-contribution
  (event-id uint)
  (volunteer-id uint)
  (hours-worked uint)
  (bags-collected uint)
  (showed-up bool)
)
  (let (
    (event-data (unwrap! (map-get? cleanup-events event-id) ERR_EVENT_NOT_FOUND))
    (assignment-data (unwrap! (map-get? event-volunteers {event-id: event-id, volunteer-id: volunteer-id}) ERR_NOT_REGISTERED))
  )
    (begin
      (asserts! (or (is-event-organizer event-id) (is-contract-owner)) ERR_UNAUTHORIZED)
      
      ;; Update volunteer assignment
      (map-set event-volunteers {event-id: event-id, volunteer-id: volunteer-id} (merge assignment-data {
        hours-contributed: hours-worked,
        bags-collected: bags-collected,
        showed-up: showed-up
      }))
      
      ;; Update volunteer statistics if they showed up
      (if showed-up
        (update-volunteer-stats volunteer-id hours-worked bags-collected)
        true
      )
      
      (ok true)
    )
  )
)

;; Complete cleanup event
(define-public (complete-cleanup-event
  (event-id uint)
  (total-bags uint)
  (completion-notes (string-ascii 200))
)
  (let (
    (event-data (unwrap! (map-get? cleanup-events event-id) ERR_EVENT_NOT_FOUND))
  )
    (begin
      (asserts! (or (is-event-organizer event-id) (is-contract-owner)) ERR_UNAUTHORIZED)
      (asserts! (is-eq (get status event-data) STATUS_IN_PROGRESS) ERR_INVALID_STATUS)
      
      (map-set cleanup-events event-id (merge event-data {
        status: STATUS_COMPLETED,
        bags-collected: total-bags,
        completion-notes: (some completion-notes)
      }))
      
      ;; Update global statistics
      (var-set total-waste-collected (+ (var-get total-waste-collected) total-bags))
      
      (ok true)
    )
  )
)

;; Report waste station status
(define-public (report-station-status
  (station-id uint)
  (current-level uint)
  (condition uint)
  (maintenance-required bool)
)
  (let (
    (station-data (unwrap! (map-get? waste-stations station-id) ERR_STATION_NOT_FOUND))
  )
    (begin
      (map-set waste-stations station-id (merge station-data {
        current-level: current-level,
        condition: condition,
        maintenance-required: maintenance-required
      }))
      
      (ok true)
    )
  )
)

;; Create waste disposal report
(define-public (create-disposal-report
  (facility-id uint)
  (station-id (optional uint))
  (report-type (string-ascii 20))
  (description (string-ascii 200))
  (urgency uint)
)
  (let (
    (new-report-id (+ (var-get report-counter) u1))
  )
    (begin
      (map-set disposal-reports new-report-id {
        facility-id: facility-id,
        station-id: station-id,
        reporter: tx-sender,
        report-type: report-type,
        description: description,
        urgency: urgency,
        reported-at: stacks-block-height,
        resolved: false,
        resolved-at: none,
        resolution-notes: none
      })
      
      (var-set report-counter new-report-id)
      (ok new-report-id)
    )
  )
)

;; Resolve disposal report
(define-public (resolve-disposal-report
  (report-id uint)
  (resolution-notes (string-ascii 150))
)
  (let (
    (report-data (unwrap! (map-get? disposal-reports report-id) ERR_EVENT_NOT_FOUND))
  )
    (begin
      (asserts! (is-contract-owner) ERR_UNAUTHORIZED)
      
      (map-set disposal-reports report-id (merge report-data {
        resolved: true,
        resolved-at: (some stacks-block-height),
        resolution-notes: (some resolution-notes)
      }))
      
      (ok true)
    )
  )
)

;; Rate volunteer performance
(define-public (rate-volunteer-performance
  (event-id uint)
  (volunteer-id uint)
  (performance-rating uint)
)
  (let (
    (assignment-data (unwrap! (map-get? event-volunteers {event-id: event-id, volunteer-id: volunteer-id}) ERR_NOT_REGISTERED))
  )
    (begin
      (asserts! (or (is-event-organizer event-id) (is-contract-owner)) ERR_UNAUTHORIZED)
      (asserts! (is-valid-rating performance-rating) ERR_INVALID_RATING)
      
      (map-set event-volunteers {event-id: event-id, volunteer-id: volunteer-id} (merge assignment-data {
        performance-rating: (some performance-rating)
      }))
      
      (ok true)
    )
  )
)

;; ===== READ-ONLY FUNCTIONS =====

;; Get cleanup event information
(define-read-only (get-cleanup-event (event-id uint))
  (map-get? cleanup-events event-id)
)

;; Get volunteer information
(define-read-only (get-volunteer (volunteer-id uint))
  (map-get? volunteers volunteer-id)
)

;; Get volunteer assignment for event
(define-read-only (get-volunteer-assignment (event-id uint) (volunteer-id uint))
  (map-get? event-volunteers {event-id: event-id, volunteer-id: volunteer-id})
)

;; Get waste station information
(define-read-only (get-waste-station (station-id uint))
  (map-get? waste-stations station-id)
)

;; Get disposal report
(define-read-only (get-disposal-report (report-id uint))
  (map-get? disposal-reports report-id)
)

;; Get facility compliance data
(define-read-only (get-facility-compliance (facility-id uint))
  (map-get? facility-compliance facility-id)
)

;; Get total counters
(define-read-only (get-cleanup-event-count)
  (var-get cleanup-event-counter)
)

(define-read-only (get-volunteer-count)
  (var-get volunteer-counter)
)

(define-read-only (get-total-waste-collected)
  (var-get total-waste-collected)
)

(define-read-only (get-total-volunteer-hours)
  (var-get total-volunteer-hours)
)
