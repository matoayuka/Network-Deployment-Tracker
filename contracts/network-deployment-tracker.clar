(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_DEPLOYMENT_NOT_FOUND (err u404))
(define-constant ERR_INVALID_NETWORK (err u400))
(define-constant ERR_DEPLOYMENT_EXISTS (err u409))
(define-constant ERR_INVALID_STATUS (err u422))

(define-data-var deployment-counter uint u0)

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
