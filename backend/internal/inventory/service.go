package inventory

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"sort"
	"strings"
	"sync"
	"time"
)

var ErrItemUnavailable = errors.New("item_unavailable")
var ErrInvalidGrant = errors.New("invalid_inventory_grant")

type Item struct {
	PlayerID     string        `json:"player_id"`
	ItemID       string        `json:"item_id"`
	Owned        int           `json:"owned"`
	Locked       int           `json:"locked"`
	Available    int           `json:"available"`
	Reservations []Reservation `json:"reservations,omitempty"`
}

type Reservation struct {
	PlayerID    string `json:"player_id"`
	ItemID      string `json:"item_id"`
	SourceID    string `json:"source_id"`
	Reason      string `json:"reason"`
	Quantity    int    `json:"quantity"`
	CreatedUnix int64  `json:"created_unix"`
}

type Transfer struct {
	ItemID   string `json:"item_id"`
	Quantity int    `json:"quantity"`
	From     Item   `json:"from"`
	To       Item   `json:"to"`
}

type Grant struct {
	ItemID   string `json:"item_id"`
	Quantity int    `json:"quantity"`
}

type GrantRequest struct {
	PlayerID string  `json:"player_id"`
	Items    []Grant `json:"items"`
}

type Service interface {
	Items(ctx context.Context, playerID string) ([]Item, error)
	Grant(ctx context.Context, request GrantRequest) ([]Item, error)
	Lock(ctx context.Context, playerID string, itemID string) (bool, error)
	LockForSource(ctx context.Context, playerID string, itemID string, sourceID string, reason string) (bool, error)
	Unlock(ctx context.Context, playerID string, itemID string) error
	UnlockForSource(ctx context.Context, playerID string, itemID string, sourceID string) error
	Deliver(ctx context.Context, sellerID string, buyerID string, itemID string) (Transfer, error)
	DeliverForSource(ctx context.Context, sellerID string, buyerID string, itemID string, sourceID string) (Transfer, error)
}

type MemoryService struct {
	mu           sync.Mutex
	items        map[string]map[string]Item
	reservations map[string]map[string]map[string]Reservation
}

var defaultItems = []Item{
	{ItemID: "simple_chair", Owned: 1},
	{ItemID: "arcade_cabinet", Owned: 1},
	{ItemID: "potted_plant", Owned: 1},
}

var idPattern = regexp.MustCompile(`^[a-zA-Z0-9_-]{1,96}$`)
var sourcePattern = regexp.MustCompile(`^[a-zA-Z0-9:_./-]{1,160}$`)

func NewMemoryService() Service {
	return &MemoryService{
		items:        map[string]map[string]Item{},
		reservations: map[string]map[string]map[string]Reservation{},
	}
}

func (s *MemoryService) Items(_ context.Context, playerID string) ([]Item, error) {
	playerID = NormalizePlayerID(playerID)
	s.mu.Lock()
	defer s.mu.Unlock()
	s.seedLocked(playerID)
	items := make([]Item, 0, len(s.items[playerID]))
	for _, item := range s.items[playerID] {
		item.Locked = s.lockedQuantity(playerID, item.ItemID)
		item.Reservations = s.reservationList(playerID, item.ItemID)
		items = append(items, item.Normalized())
	}
	sortItems(items)
	return items, nil
}

func (s *MemoryService) Grant(_ context.Context, request GrantRequest) ([]Item, error) {
	request = normalizeGrantRequest(request)
	if err := validateGrantRequest(request); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	items := make([]Item, 0, len(request.Items))
	for _, grant := range request.Items {
		items = append(items, s.grantLocked(request.PlayerID, grant))
	}
	sortItems(items)
	return items, nil
}

func (s *MemoryService) Lock(_ context.Context, playerID string, itemID string) (bool, error) {
	return s.lockForSourceLocked(playerID, itemID, legacySourceID(itemID), "legacy")
}

func (s *MemoryService) LockForSource(
	_ context.Context,
	playerID string,
	itemID string,
	sourceID string,
	reason string,
) (bool, error) {
	return s.lockForSourceLocked(playerID, itemID, sourceID, reason)
}

func (s *MemoryService) lockForSourceLocked(
	playerID string,
	itemID string,
	sourceID string,
	reason string,
) (bool, error) {
	playerID = NormalizePlayerID(playerID)
	itemID = NormalizeItemID(itemID)
	sourceID = NormalizeSourceID(sourceID)
	if itemID == "" || sourceID == "" {
		return false, ErrItemUnavailable
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.seedLocked(playerID)
	item := s.items[playerID][itemID]
	item.Locked = s.lockedQuantity(playerID, itemID)
	item = item.Normalized()
	if item.Available <= 0 {
		return false, nil
	}
	reservation := s.reservationLocked(playerID, itemID, sourceID)
	reservation.Reason = NormalizeReason(reason)
	reservation.Quantity++
	reservation.CreatedUnix = nonzeroUnix(reservation.CreatedUnix)
	s.reservations[playerID][itemID][sourceID] = reservation
	item.Locked = s.lockedQuantity(playerID, itemID)
	s.items[playerID][itemID] = item.Normalized()
	return true, nil
}

func (s *MemoryService) Unlock(_ context.Context, playerID string, itemID string) error {
	playerID = NormalizePlayerID(playerID)
	itemID = NormalizeItemID(itemID)
	if itemID == "" {
		return ErrItemUnavailable
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.seedLocked(playerID)
	_ = s.unlockAnyLocked(playerID, itemID)
	item := s.items[playerID][itemID]
	item.Locked = s.lockedQuantity(playerID, itemID)
	s.items[playerID][itemID] = item.Normalized()
	return nil
}

func (s *MemoryService) UnlockForSource(_ context.Context, playerID string, itemID string, sourceID string) error {
	playerID = NormalizePlayerID(playerID)
	itemID = NormalizeItemID(itemID)
	sourceID = NormalizeSourceID(sourceID)
	if itemID == "" || sourceID == "" {
		return ErrItemUnavailable
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.seedLocked(playerID)
	if itemReservations, ok := s.reservations[playerID][itemID]; ok {
		delete(itemReservations, sourceID)
	}
	item := s.items[playerID][itemID]
	item.Locked = s.lockedQuantity(playerID, itemID)
	s.items[playerID][itemID] = item.Normalized()
	return nil
}

func (s *MemoryService) Deliver(_ context.Context, sellerID string, buyerID string, itemID string) (Transfer, error) {
	return s.deliverForSource(sellerID, buyerID, itemID, "")
}

func (s *MemoryService) DeliverForSource(
	_ context.Context,
	sellerID string,
	buyerID string,
	itemID string,
	sourceID string,
) (Transfer, error) {
	return s.deliverForSource(sellerID, buyerID, itemID, sourceID)
}

func (s *MemoryService) deliverForSource(
	sellerID string,
	buyerID string,
	itemID string,
	sourceID string,
) (Transfer, error) {
	sellerID = NormalizePlayerID(sellerID)
	buyerID = NormalizePlayerID(buyerID)
	itemID = NormalizeItemID(itemID)
	if itemID == "" {
		return Transfer{}, ErrItemUnavailable
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.seedLocked(sellerID)
	s.seedLocked(buyerID)
	seller := s.items[sellerID][itemID].Normalized()
	if seller.Owned <= 0 {
		return Transfer{}, ErrItemUnavailable
	}
	sourceID = NormalizeSourceID(sourceID)
	released := false
	if sourceID == "" {
		released = s.unlockAnyLocked(sellerID, itemID)
	} else if itemReservations, ok := s.reservations[sellerID][itemID]; ok {
		reservation, reservationOK := itemReservations[sourceID]
		if reservationOK && reservation.Quantity > 0 {
			delete(itemReservations, sourceID)
			released = true
		}
	}
	if !released {
		return Transfer{}, ErrItemUnavailable
	}
	seller.Locked = s.lockedQuantity(sellerID, itemID)
	seller.Owned--
	buyer := s.items[buyerID][itemID].Normalized()
	buyer.PlayerID = buyerID
	buyer.ItemID = itemID
	buyer.Owned++
	s.items[sellerID][itemID] = seller.Normalized()
	s.items[buyerID][itemID] = buyer.Normalized()
	return Transfer{ItemID: itemID, Quantity: 1, From: seller.Normalized(), To: buyer.Normalized()}, nil
}

func (s *MemoryService) seedLocked(playerID string) {
	if _, ok := s.items[playerID]; ok {
		if _, reservationsOK := s.reservations[playerID]; !reservationsOK {
			s.reservations[playerID] = map[string]map[string]Reservation{}
		}
		for itemID := range s.items[playerID] {
			if _, itemOK := s.reservations[playerID][itemID]; !itemOK {
				s.reservations[playerID][itemID] = map[string]Reservation{}
			}
		}
		return
	}
	s.items[playerID] = map[string]Item{}
	s.reservations[playerID] = map[string]map[string]Reservation{}
	for _, item := range defaultItems {
		item.PlayerID = playerID
		s.items[playerID][item.ItemID] = item.Normalized()
		s.reservations[playerID][item.ItemID] = map[string]Reservation{}
	}
}

func (s *MemoryService) grantLocked(playerID string, grant Grant) Item {
	s.seedLocked(playerID)
	item := s.items[playerID][grant.ItemID].Normalized()
	item.PlayerID = playerID
	item.ItemID = grant.ItemID
	item.Owned += grant.Quantity
	if _, ok := s.reservations[playerID][grant.ItemID]; !ok {
		s.reservations[playerID][grant.ItemID] = map[string]Reservation{}
	}
	s.items[playerID][grant.ItemID] = item.Normalized()
	return s.items[playerID][grant.ItemID]
}

func (s *MemoryService) lockedQuantity(playerID string, itemID string) int {
	total := 0
	for _, reservation := range s.reservations[playerID][itemID] {
		total += max(0, reservation.Quantity)
	}
	return total
}

func (s *MemoryService) reservationLocked(playerID string, itemID string, sourceID string) Reservation {
	if _, ok := s.reservations[playerID]; !ok {
		s.reservations[playerID] = map[string]map[string]Reservation{}
	}
	if _, ok := s.reservations[playerID][itemID]; !ok {
		s.reservations[playerID][itemID] = map[string]Reservation{}
	}
	reservation := s.reservations[playerID][itemID][sourceID]
	reservation.PlayerID = playerID
	reservation.ItemID = itemID
	reservation.SourceID = sourceID
	return reservation
}

func (s *MemoryService) reservationList(playerID string, itemID string) []Reservation {
	reservations := []Reservation{}
	for _, reservation := range s.reservations[playerID][itemID] {
		if reservation.Quantity > 0 {
			reservations = append(reservations, reservation)
		}
	}
	sortReservations(reservations)
	return reservations
}

func (s *MemoryService) unlockAnyLocked(playerID string, itemID string) bool {
	keys := make([]string, 0, len(s.reservations[playerID][itemID]))
	for sourceID := range s.reservations[playerID][itemID] {
		keys = append(keys, sourceID)
	}
	sort.Strings(keys)
	for _, sourceID := range keys {
		reservation := s.reservations[playerID][itemID][sourceID]
		if reservation.Quantity <= 0 {
			delete(s.reservations[playerID][itemID], sourceID)
			continue
		}
		reservation.Quantity--
		if reservation.Quantity <= 0 {
			delete(s.reservations[playerID][itemID], sourceID)
		} else {
			s.reservations[playerID][itemID][sourceID] = reservation
		}
		return true
	}
	return false
}

func (item Item) Normalized() Item {
	if item.Owned < 0 {
		item.Owned = 0
	}
	if item.Locked < 0 {
		item.Locked = 0
	}
	if item.Locked > item.Owned {
		item.Locked = item.Owned
	}
	item.Available = item.Owned - item.Locked
	return item
}

func NormalizePlayerID(playerID string) string {
	playerID = strings.TrimSpace(playerID)
	if playerID == "" {
		return "offline-player"
	}
	return playerID
}

func NormalizeItemID(itemID string) string {
	itemID = strings.TrimSpace(itemID)
	if !idPattern.MatchString(itemID) {
		return ""
	}
	return itemID
}

func NormalizeSourceID(sourceID string) string {
	sourceID = strings.TrimSpace(sourceID)
	if !sourcePattern.MatchString(sourceID) {
		return ""
	}
	return sourceID
}

func NormalizeReason(reason string) string {
	reason = strings.TrimSpace(reason)
	if reason == "" {
		return "reservation"
	}
	if len(reason) > 64 {
		return reason[:64]
	}
	return reason
}

func legacySourceID(itemID string) string {
	return fmt.Sprintf("legacy:%s:%d", NormalizeItemID(itemID), time.Now().UnixNano())
}

func nonzeroUnix(value int64) int64 {
	if value > 0 {
		return value
	}
	return time.Now().Unix()
}

func normalizeGrantRequest(request GrantRequest) GrantRequest {
	request.PlayerID = NormalizePlayerID(request.PlayerID)
	items := make([]Grant, 0, len(request.Items))
	for _, item := range request.Items {
		item.ItemID = NormalizeItemID(item.ItemID)
		if item.Quantity <= 0 {
			continue
		}
		items = append(items, item)
	}
	request.Items = items
	return request
}

func validateGrantRequest(request GrantRequest) error {
	if request.PlayerID == "" || len(request.Items) == 0 {
		return ErrInvalidGrant
	}
	for _, item := range request.Items {
		if item.ItemID == "" || item.Quantity <= 0 {
			return ErrInvalidGrant
		}
	}
	return nil
}

func sortItems(items []Item) {
	sort.Slice(items, func(left int, right int) bool {
		return items[left].ItemID < items[right].ItemID
	})
}

func sortReservations(reservations []Reservation) {
	sort.Slice(reservations, func(left int, right int) bool {
		if reservations[left].CreatedUnix == reservations[right].CreatedUnix {
			return reservations[left].SourceID < reservations[right].SourceID
		}
		return reservations[left].CreatedUnix < reservations[right].CreatedUnix
	})
}
