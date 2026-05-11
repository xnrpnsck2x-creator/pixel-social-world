package trade

import "pixel-social-world/backend/internal/inventory"

const EscrowLocked = "locked"
const EscrowDelivered = "delivered"
const EscrowReturned = "returned"

type InventoryItem = inventory.Item
type ItemTransfer = inventory.Transfer
type InventoryGrant = inventory.Grant
type InventoryGrantRequest = inventory.GrantRequest
