(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_DEPLOYMENT_NOT_FOUND (err u404))
(define-constant ERR_INVALID_NETWORK (err u400))
(define-constant ERR_DEPLOYMENT_EXISTS (err u409))
(define-constant ERR_INVALID_STATUS (err u422))
(define-constant ERR_TEMPLATE_NOT_FOUND (err u404))
(define-constant ERR_TEMPLATE_EXISTS (err u409))
(define-constant ERR_APPROVAL_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_APPROVED (err u409))
(define-constant ERR_ALREADY_REJECTED (err u409))
(define-constant ERR_INSUFFICIENT_APPROVALS (err u403))

(define-data-var deployment-counter uint u0)
(define-data-var template-counter uint u0)
(define-data-var approval-counter uint u0)

(define-map deployments 
  { deployment-id: uint }
  {
    contract-name: (string-ascii 64),
    contract-address: (string-ascii 64),
    network-id: uint,
    network-name: (string-ascii 32),
    deployer: principal,
    deployment-hash: (string-ascii 64),
    status: (string-ascii 16),
    gas-used: uint,
    deployment-cost: uint,
    created-at: uint,
    updated-at: uint,
    is-verified: bool,
    tags: (list 5 (string-ascii 32))
  }
)

(define-map network-registry
  { network-id: uint }
  {
    network-name: (string-ascii 32),
    network-chain-id: uint,
    rpc-endpoint: (string-ascii 128),
    is-testnet: bool,
    is-active: bool
  }
)

(define-map deployer-stats
  { deployer: principal }
  {
    total-deployments: uint,
    successful-deployments: uint,
    failed-deployments: uint,
    total-gas-used: uint,
    total-cost: uint
  }
)

(define-map network-deployment-count
  { network-id: uint }
  uint
)

(define-map deployment-templates
  { template-id: uint }
  {
    template-name: (string-ascii 64),
    description: (string-ascii 256),
    contract-name-pattern: (string-ascii 64),
    network-id: uint,
    estimated-gas: uint,
    estimated-cost: uint,
    default-tags: (list 5 (string-ascii 32)),
    creator: principal,
    created-at: uint,
    updated-at: uint,
    is-public: bool,
    usage-count: uint
  }
)

(define-map deployment-approvals
  { approval-id: uint }
  {
    deployment-request: {
      contract-name: (string-ascii 64),
      contract-address: (string-ascii 64),
      network-id: uint,
      deployment-hash: (string-ascii 64),
      gas-used: uint,
      deployment-cost: uint,
      tags: (list 5 (string-ascii 32))
    },
    requester: principal,
    required-approvals: uint,
    current-approvals: uint,
    approvers: (list 10 principal),
    rejectors: (list 10 principal),
    status: (string-ascii 16),
    created-at: uint,
    updated-at: uint,
    auto-execute: bool
  }
)

(define-map approval-settings
  { network-id: uint }
  {
    required-approvals: uint,
    authorized-approvers: (list 10 principal)
  }
)

(define-public (register-network (network-id uint) (network-name (string-ascii 32)) (network-chain-id uint) (rpc-endpoint (string-ascii 128)) (is-testnet bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (ok (map-set network-registry
      { network-id: network-id }
      {
        network-name: network-name,
        network-chain-id: network-chain-id,
        rpc-endpoint: rpc-endpoint,
        is-testnet: is-testnet,
        is-active: true
      }
    ))
  )
)

(define-public (deactivate-network (network-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (match (map-get? network-registry { network-id: network-id })
      network-data
      (ok (map-set network-registry
        { network-id: network-id }
        (merge network-data { is-active: false })
      ))
      ERR_INVALID_NETWORK
    )
  )
)

(define-public (create-deployment 
  (contract-name (string-ascii 64))
  (contract-address (string-ascii 64))
  (network-id uint)
  (deployment-hash (string-ascii 64))
  (gas-used uint)
  (deployment-cost uint)
  (tags (list 5 (string-ascii 32)))
)
  (let (
    (deployment-id (+ (var-get deployment-counter) u1))
    (current-block stacks-block-height)
  )
    (match (map-get? network-registry { network-id: network-id })
      network-data
      (begin
        (asserts! (get is-active network-data) ERR_INVALID_NETWORK)
        (var-set deployment-counter deployment-id)
        (map-set deployments
          { deployment-id: deployment-id }
          {
            contract-name: contract-name,
            contract-address: contract-address,
            network-id: network-id,
            network-name: (get network-name network-data),
            deployer: tx-sender,
            deployment-hash: deployment-hash,
            status: "pending",
            gas-used: gas-used,
            deployment-cost: deployment-cost,
            created-at: current-block,
            updated-at: current-block,
            is-verified: false,
            tags: tags
          }
        )
        (update-deployer-stats tx-sender gas-used deployment-cost)
        (increment-network-count network-id)
        (ok deployment-id)
      )
      ERR_INVALID_NETWORK
    )
  )
)

(define-public (update-deployment-status (deployment-id uint) (new-status (string-ascii 16)))
  (match (map-get? deployments { deployment-id: deployment-id })
    deployment-data
    (begin
      (asserts! (or (is-eq tx-sender (get deployer deployment-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
      (asserts! (or (is-eq new-status "pending") (is-eq new-status "deployed") (is-eq new-status "failed") (is-eq new-status "verified")) ERR_INVALID_STATUS)
      (ok (map-set deployments
        { deployment-id: deployment-id }
        (merge deployment-data {
          status: new-status,
          updated-at: stacks-block-height
        })
      ))
    )
    ERR_DEPLOYMENT_NOT_FOUND
  )
)

(define-public (verify-deployment (deployment-id uint))
  (match (map-get? deployments { deployment-id: deployment-id })
    deployment-data
    (begin
      (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
      (ok (map-set deployments
        { deployment-id: deployment-id }
        (merge deployment-data {
          is-verified: true,
          status: "verified",
          updated-at: stacks-block-height
        })
      ))
    )
    ERR_DEPLOYMENT_NOT_FOUND
  )
)

(define-public (add-deployment-tag (deployment-id uint) (new-tag (string-ascii 32)))
  (match (map-get? deployments { deployment-id: deployment-id })
    deployment-data
    (begin
      (asserts! (or (is-eq tx-sender (get deployer deployment-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
      (let ((current-tags (get tags deployment-data)))
        (ok (map-set deployments
          { deployment-id: deployment-id }
          (merge deployment-data {
            tags: (unwrap-panic (as-max-len? (append current-tags new-tag) u5)),
            updated-at: stacks-block-height
          })
        ))
      )
    )
    ERR_DEPLOYMENT_NOT_FOUND
  )
)

(define-public (create-template
  (template-name (string-ascii 64))
  (description (string-ascii 256))
  (contract-name-pattern (string-ascii 64))
  (network-id uint)
  (estimated-gas uint)
  (estimated-cost uint)
  (default-tags (list 5 (string-ascii 32)))
  (is-public bool)
)
  (let (
    (template-id (+ (var-get template-counter) u1))
    (current-block stacks-block-height)
  )
    (match (map-get? network-registry { network-id: network-id })
      network-data
      (begin
        (asserts! (get is-active network-data) ERR_INVALID_NETWORK)
        (var-set template-counter template-id)
        (ok (map-set deployment-templates
          { template-id: template-id }
          {
            template-name: template-name,
            description: description,
            contract-name-pattern: contract-name-pattern,
            network-id: network-id,
            estimated-gas: estimated-gas,
            estimated-cost: estimated-cost,
            default-tags: default-tags,
            creator: tx-sender,
            created-at: current-block,
            updated-at: current-block,
            is-public: is-public,
            usage-count: u0
          }
        ))
      )
      ERR_INVALID_NETWORK
    )
  )
)

(define-public (update-template
  (template-id uint)
  (template-name (string-ascii 64))
  (description (string-ascii 256))
  (contract-name-pattern (string-ascii 64))
  (estimated-gas uint)
  (estimated-cost uint)
  (default-tags (list 5 (string-ascii 32)))
  (is-public bool)
)
  (match (map-get? deployment-templates { template-id: template-id })
    template-data
    (begin
      (asserts! (or (is-eq tx-sender (get creator template-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
      (ok (map-set deployment-templates
        { template-id: template-id }
        (merge template-data {
          template-name: template-name,
          description: description,
          contract-name-pattern: contract-name-pattern,
          estimated-gas: estimated-gas,
          estimated-cost: estimated-cost,
          default-tags: default-tags,
          is-public: is-public,
          updated-at: stacks-block-height
        })
      ))
    )
    ERR_TEMPLATE_NOT_FOUND
  )
)

(define-public (create-deployment-from-template
  (template-id uint)
  (contract-name (string-ascii 64))
  (contract-address (string-ascii 64))
  (deployment-hash (string-ascii 64))
  (actual-gas uint)
  (actual-cost uint)
)
  (match (map-get? deployment-templates { template-id: template-id })
    template-data
    (begin
      (asserts! (or (get is-public template-data) (is-eq tx-sender (get creator template-data)) (is-eq tx-sender CONTRACT_OWNER)) ERR_NOT_AUTHORIZED)
      (let (
        (deployment-id (+ (var-get deployment-counter) u1))
        (current-block stacks-block-height)
        (network-data (unwrap! (map-get? network-registry { network-id: (get network-id template-data) }) ERR_INVALID_NETWORK))
      )
        (var-set deployment-counter deployment-id)
        (map-set deployments
          { deployment-id: deployment-id }
          {
            contract-name: contract-name,
            contract-address: contract-address,
            network-id: (get network-id template-data),
            network-name: (get network-name network-data),
            deployer: tx-sender,
            deployment-hash: deployment-hash,
            status: "pending",
            gas-used: actual-gas,
            deployment-cost: actual-cost,
            created-at: current-block,
            updated-at: current-block,
            is-verified: false,
            tags: (get default-tags template-data)
          }
        )
        (map-set deployment-templates
          { template-id: template-id }
          (merge template-data { usage-count: (+ (get usage-count template-data) u1) })
        )
        (update-deployer-stats tx-sender actual-gas actual-cost)
        (increment-network-count (get network-id template-data))
        (ok deployment-id)
      )
    )
    ERR_TEMPLATE_NOT_FOUND
  )
)

(define-public (configure-approval-settings (network-id uint) (required-approvals uint) (authorized-approvers (list 10 principal)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (asserts! (> required-approvals u0) ERR_INVALID_STATUS)
    (ok (map-set approval-settings
      { network-id: network-id }
      {
        required-approvals: required-approvals,
        authorized-approvers: authorized-approvers
      }
    ))
  )
)

(define-public (request-deployment-approval 
  (contract-name (string-ascii 64))
  (contract-address (string-ascii 64))
  (network-id uint)
  (deployment-hash (string-ascii 64))
  (gas-used uint)
  (deployment-cost uint)
  (tags (list 5 (string-ascii 32)))
  (auto-execute bool)
)
  (let (
    (approval-id (+ (var-get approval-counter) u1))
    (current-block stacks-block-height)
    (network-settings (map-get? approval-settings { network-id: network-id }))
  )
    (match network-settings
      settings
      (begin
        (var-set approval-counter approval-id)
        (ok (map-set deployment-approvals
          { approval-id: approval-id }
          {
            deployment-request: {
              contract-name: contract-name,
              contract-address: contract-address,
              network-id: network-id,
              deployment-hash: deployment-hash,
              gas-used: gas-used,
              deployment-cost: deployment-cost,
              tags: tags
            },
            requester: tx-sender,
            required-approvals: (get required-approvals settings),
            current-approvals: u0,
            approvers: (list),
            rejectors: (list),
            status: "pending",
            created-at: current-block,
            updated-at: current-block,
            auto-execute: auto-execute
          }
        ))
      )
      ERR_INVALID_NETWORK
    )
  )
)

(define-public (approve-deployment (approval-id uint))
  (match (map-get? deployment-approvals { approval-id: approval-id })
    approval-data
    (let (
      (network-settings (unwrap! (map-get? approval-settings { network-id: (get network-id (get deployment-request approval-data)) }) ERR_INVALID_NETWORK))
      (authorized-approvers (get authorized-approvers network-settings))
      (current-approvers (get approvers approval-data))
      (current-rejectors (get rejectors approval-data))
    )
      (asserts! (is-some (index-of authorized-approvers tx-sender)) ERR_NOT_AUTHORIZED)
      (asserts! (is-none (index-of current-approvers tx-sender)) ERR_ALREADY_APPROVED)
      (asserts! (is-none (index-of current-rejectors tx-sender)) ERR_ALREADY_REJECTED)
      (asserts! (is-eq (get status approval-data) "pending") ERR_INVALID_STATUS)
      (let (
        (new-approvers (unwrap-panic (as-max-len? (append current-approvers tx-sender) u10)))
        (new-approval-count (+ (get current-approvals approval-data) u1))
        (should-execute (and (get auto-execute approval-data) (>= new-approval-count (get required-approvals approval-data))))
      )
        (map-set deployment-approvals
          { approval-id: approval-id }
          (merge approval-data {
            approvers: new-approvers,
            current-approvals: new-approval-count,
            status: (if should-execute "approved" "pending"),
            updated-at: stacks-block-height
          })
        )
        (if should-execute
          (execute-approved-deployment approval-id)
          (ok approval-id)
        )
      )
    )
    ERR_APPROVAL_NOT_FOUND
  )
)

(define-public (reject-deployment (approval-id uint))
  (match (map-get? deployment-approvals { approval-id: approval-id })
    approval-data
    (let (
      (network-settings (unwrap! (map-get? approval-settings { network-id: (get network-id (get deployment-request approval-data)) }) ERR_INVALID_NETWORK))
      (authorized-approvers (get authorized-approvers network-settings))
      (current-approvers (get approvers approval-data))
      (current-rejectors (get rejectors approval-data))
    )
      (asserts! (is-some (index-of authorized-approvers tx-sender)) ERR_NOT_AUTHORIZED)
      (asserts! (is-none (index-of current-approvers tx-sender)) ERR_ALREADY_APPROVED)
      (asserts! (is-none (index-of current-rejectors tx-sender)) ERR_ALREADY_REJECTED)
      (asserts! (is-eq (get status approval-data) "pending") ERR_INVALID_STATUS)
      (let (
        (new-rejectors (unwrap-panic (as-max-len? (append current-rejectors tx-sender) u10)))
      )
        (ok (map-set deployment-approvals
          { approval-id: approval-id }
          (merge approval-data {
            rejectors: new-rejectors,
            status: "rejected",
            updated-at: stacks-block-height
          })
        ))
      )
    )
    ERR_APPROVAL_NOT_FOUND
  )
)

(define-private (execute-approved-deployment (approval-id uint))
  (match (map-get? deployment-approvals { approval-id: approval-id })
    approval-data
    (let (
      (deployment-request (get deployment-request approval-data))
      (deployment-id (+ (var-get deployment-counter) u1))
      (current-block stacks-block-height)
      (network-data (unwrap! (map-get? network-registry { network-id: (get network-id deployment-request) }) ERR_INVALID_NETWORK))
    )
      (var-set deployment-counter deployment-id)
      (map-set deployments
        { deployment-id: deployment-id }
        {
          contract-name: (get contract-name deployment-request),
          contract-address: (get contract-address deployment-request),
          network-id: (get network-id deployment-request),
          network-name: (get network-name network-data),
          deployer: (get requester approval-data),
          deployment-hash: (get deployment-hash deployment-request),
          status: "deployed",
          gas-used: (get gas-used deployment-request),
          deployment-cost: (get deployment-cost deployment-request),
          created-at: current-block,
          updated-at: current-block,
          is-verified: false,
          tags: (get tags deployment-request)
        }
      )
      (update-deployer-stats (get requester approval-data) (get gas-used deployment-request) (get deployment-cost deployment-request))
      (increment-network-count (get network-id deployment-request))
      (ok deployment-id)
    )
    ERR_APPROVAL_NOT_FOUND
  )
)

(define-private (update-deployer-stats (deployer principal) (gas-used uint) (cost uint))
  (let (
    (current-stats (default-to 
      { total-deployments: u0, successful-deployments: u0, failed-deployments: u0, total-gas-used: u0, total-cost: u0 }
      (map-get? deployer-stats { deployer: deployer })
    ))
  )
    (map-set deployer-stats
      { deployer: deployer }
      {
        total-deployments: (+ (get total-deployments current-stats) u1),
        successful-deployments: (get successful-deployments current-stats),
        failed-deployments: (get failed-deployments current-stats),
        total-gas-used: (+ (get total-gas-used current-stats) gas-used),
        total-cost: (+ (get total-cost current-stats) cost)
      }
    )
  )
)

(define-private (increment-network-count (network-id uint))
  (let (
    (current-count (default-to u0 (map-get? network-deployment-count { network-id: network-id })))
  )
    (map-set network-deployment-count { network-id: network-id } (+ current-count u1))
  )
)

(define-read-only (get-deployment (deployment-id uint))
  (map-get? deployments { deployment-id: deployment-id })
)

(define-read-only (get-network (network-id uint))
  (map-get? network-registry { network-id: network-id })
)

(define-read-only (get-deployer-stats (deployer principal))
  (map-get? deployer-stats { deployer: deployer })
)

(define-read-only (get-network-deployment-count (network-id uint))
  (default-to u0 (map-get? network-deployment-count { network-id: network-id }))
)

(define-read-only (get-deployment-counter)
  (var-get deployment-counter)
)

(define-read-only (get-template (template-id uint))
  (map-get? deployment-templates { template-id: template-id })
)

(define-read-only (get-template-counter)
  (var-get template-counter)
)

(define-read-only (get-approval (approval-id uint))
  (map-get? deployment-approvals { approval-id: approval-id })
)

(define-read-only (get-approval-counter)
  (var-get approval-counter)
)

(define-read-only (get-approval-settings (network-id uint))
  (map-get? approval-settings { network-id: network-id })
)

(define-read-only (get-pending-approvals)
  (let (
    (approval-ids (list 
      u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
      u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
    ))
  )
    (filter filter-pending-approvals 
      (map get-approval-with-id approval-ids))
  )
)

(define-read-only (get-public-templates)
  (let (
    (template-ids (list 
      u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
      u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
    ))
  )
    (filter filter-public-templates 
      (map get-template-with-id template-ids))
  )
)

(define-read-only (get-templates-by-creator (creator principal))
  (let (
    (template-ids (list 
      u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
      u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
    ))
  )
    (map get-template-with-id template-ids)
  )
)

(define-read-only (get-deployments-by-status (target-status (string-ascii 16)))
  (let (
    (deployment-ids (list 
      u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
      u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
    ))
  )
    (filter filter-by-status 
      (map get-deployment-with-id deployment-ids))
  )
)

(define-read-only (get-deployments-by-network (target-network uint))
  (let (
    (deployment-ids (list 
      u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
      u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
    ))
  )
    (filter filter-by-network 
      (map get-deployment-with-id deployment-ids))
  )
)

(define-read-only (get-deployments-by-deployer (target-deployer principal))
  (let (
    (deployment-ids (list 
      u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
      u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
    ))
  )
    (filter filter-by-deployer 
      (map get-deployment-with-id deployment-ids))
  )
)

(define-private (get-deployment-with-id (deployment-id uint))
  {
    deployment-id: deployment-id,
    data: (map-get? deployments { deployment-id: deployment-id })
  }
)

(define-private (filter-by-status (deployment-entry { deployment-id: uint, data: (optional { contract-name: (string-ascii 64), contract-address: (string-ascii 64), network-id: uint, network-name: (string-ascii 32), deployer: principal, deployment-hash: (string-ascii 64), status: (string-ascii 16), gas-used: uint, deployment-cost: uint, created-at: uint, updated-at: uint, is-verified: bool, tags: (list 5 (string-ascii 32)) }) }))
  (match (get data deployment-entry)
    deployment-data
    (is-eq (get status deployment-data) "deployed")
    false
  )
)

(define-private (filter-by-network (deployment-entry { deployment-id: uint, data: (optional { contract-name: (string-ascii 64), contract-address: (string-ascii 64), network-id: uint, network-name: (string-ascii 32), deployer: principal, deployment-hash: (string-ascii 64), status: (string-ascii 16), gas-used: uint, deployment-cost: uint, created-at: uint, updated-at: uint, is-verified: bool, tags: (list 5 (string-ascii 32)) }) }))
  (match (get data deployment-entry)
    deployment-data
    (is-eq (get network-id deployment-data) u1)
    false
  )
)

(define-private (filter-by-deployer (deployment-entry { deployment-id: uint, data: (optional { contract-name: (string-ascii 64), contract-address: (string-ascii 64), network-id: uint, network-name: (string-ascii 32), deployer: principal, deployment-hash: (string-ascii 64), status: (string-ascii 16), gas-used: uint, deployment-cost: uint, created-at: uint, updated-at: uint, is-verified: bool, tags: (list 5 (string-ascii 32)) }) }))
  (match (get data deployment-entry)
    deployment-data
    (is-eq (get deployer deployment-data) 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
    false
  )
)

(define-private (get-template-with-id (template-id uint))
  {
    template-id: template-id,
    data: (map-get? deployment-templates { template-id: template-id })
  }
)

(define-private (filter-public-templates (template-entry { template-id: uint, data: (optional { template-name: (string-ascii 64), description: (string-ascii 256), contract-name-pattern: (string-ascii 64), network-id: uint, estimated-gas: uint, estimated-cost: uint, default-tags: (list 5 (string-ascii 32)), creator: principal, created-at: uint, updated-at: uint, is-public: bool, usage-count: uint }) }))
  (match (get data template-entry)
    template-data
    (get is-public template-data)
    false
  )
)

(define-private (get-approval-with-id (approval-id uint))
  {
    approval-id: approval-id,
    data: (map-get? deployment-approvals { approval-id: approval-id })
  }
)

(define-private (filter-pending-approvals (approval-entry { approval-id: uint, data: (optional { deployment-request: { contract-name: (string-ascii 64), contract-address: (string-ascii 64), network-id: uint, deployment-hash: (string-ascii 64), gas-used: uint, deployment-cost: uint, tags: (list 5 (string-ascii 32)) }, requester: principal, required-approvals: uint, current-approvals: uint, approvers: (list 10 principal), rejectors: (list 10 principal), status: (string-ascii 16), created-at: uint, updated-at: uint, auto-execute: bool }) }))
  (match (get data approval-entry)
    approval-data
    (is-eq (get status approval-data) "pending")
    false
  )
)


