# Reservation Repair Playbook v1

Status: diagnostic-only. Do not mutate production inventory from this playbook.

## Purpose

This playbook is for investigating inventory locks that affect housing placement,
trade listings, and legacy inventory rows. It keeps the first version safe: the
LiveOps console can inspect inventory reservations, but it cannot repair or
delete locks.

## Entry Point

Use LiveOps Console -> Ops -> Inventory Audit.

Required inputs:
- Admin token with viewer or higher role.
- Player ID from support ticket, backend logs, or online room debug data.

Backend route:

```text
GET /admin/inventory/audit?player_id=<player_id>
```

The response includes:
- `items`: inventory rows with `owned`, `locked`, `available`, and `reservations`.
- `totals`: aggregate counts by reservation source.
- `flags`: diagnostic warnings that need human review.

## Normal Sources

| Source reason | Expected owner | Meaning |
| --- | --- | --- |
| `housing` | Housing placement flow | Item is placed in a room and should unlock when removed. |
| `trade` | Trade listing flow | Item is escrowed by an active trade listing and should unlock on cancel or deliver on buy. |
| `legacy` | Pre-source lock compatibility | Old aggregate lock without a source row. Treat as migration residue unless tied to an old listing. |

## Diagnostic Flags

| Flag | Meaning | First check |
| --- | --- | --- |
| `locked_without_reservation` | `locked` is higher than reservation detail total. | Check if this is legacy data or a failed old rollback. |
| `reservation_exceeds_locked` | Reservation detail total is higher than `locked`. | Check recent trade/housing writes for partial aggregate update failure. |
| `unknown_reservation_reason` | Reservation reason is not `housing`, `trade`, or `legacy`. | Check new feature code before assuming data corruption. |

## Triage Flow

1. Run Inventory Audit for the player.
2. If there are no flags, inspect normal source counts:
   - Housing count means the item is probably placed in a room.
   - Trade count means the item is probably in an active listing.
   - Legacy count means the item came from an older lock path.
3. If `locked_without_reservation` appears, compare `locked` and the reservation list for that item.
4. If `reservation_exceeds_locked` appears, treat it as a backend consistency bug and capture the response body.
5. If `unknown_reservation_reason` appears, search for the reason string in code and recent feature changes.
6. Do not change player balance, inventory, housing layout, or listings manually until the owning flow is identified.

## Source-Specific Checks

Housing:
- Check the player's home layout for the same `item_id`.
- Confirm the placed item has `inventory_locked: true` and a matching `reservation_id`.
- Removing the item through the normal housing API should release the matching `housing:*` reservation.

Trade:
- Check active listings for the player and item.
- A listed item should have a `trade:<listing_id>` reservation.
- Canceling the listing through the normal trade API should release that exact reservation.

Legacy:
- Legacy rows do not have a source row by design.
- Prefer leaving them untouched unless they block a player and no active housing/trade owner exists.
- A future repair tool must require owner role, confirmation, operator note, and audit logging.

## Escalation Packet

When escalating, capture:
- Player ID.
- Full `/admin/inventory/audit` JSON.
- Relevant room layout item, if housing is involved.
- Relevant listing ID, if trade is involved.
- Exact user-facing symptom.
- Timestamp and environment.

## Repair Boundary

Allowed in v1:
- Read audit data.
- Use normal user-facing APIs to remove housing items or cancel trade listings.
- Document the result.

Not allowed in v1:
- Direct database edits.
- Manual coin refunds.
- Force-unlock buttons.
- Deleting reservations without an owning housing/trade action.
