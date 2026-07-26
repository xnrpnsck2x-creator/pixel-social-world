package creatorregistry

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"sort"
	"strconv"
	"strings"
)

const defaultPageLimit = 50
const maxPageLimit = 100

type Service struct {
	config  Config
	entries map[string]RegistryEntry
	modes   map[string]Mode
	etag    string
}

func (s *Service) Revision() string {
	return s.config.Revision
}

func (s *Service) ETag() string {
	return s.etag
}

func (s *Service) Get(id string) (RegistryEntry, bool) {
	entry, ok := s.entries[strings.TrimSpace(id)]
	return cloneEntry(entry), ok
}

func (s *Service) Mode(id string) (Mode, bool) {
	mode, ok := s.modes[strings.TrimSpace(id)]
	return cloneMode(mode), ok
}

func (s *Service) Search(query Query) Page {
	locale := query.Locale
	if locale == "" {
		locale = s.config.DefaultLocale
	}
	text := normalizeSearchText(query.Text)
	items := make([]RegistryEntry, 0, len(s.entries))
	for _, entry := range s.entries {
		if query.Kind != "" && entry.Kind != query.Kind {
			continue
		}
		if query.ModeID != "" && !supportsMode(entry.CompatibleModes, query.ModeID) {
			continue
		}
		if text != "" && !entryMatches(entry, locale, text) {
			continue
		}
		items = append(items, cloneEntry(entry))
	}
	sort.Slice(items, func(i, j int) bool { return items[i].ID < items[j].ID })
	cursor := query.Cursor
	if cursor < 0 {
		cursor = 0
	}
	limit := query.Limit
	if limit <= 0 {
		limit = defaultPageLimit
	}
	if limit > maxPageLimit {
		limit = maxPageLimit
	}
	if cursor > len(items) {
		cursor = len(items)
	}
	end := cursor + limit
	if end > len(items) {
		end = len(items)
	}
	page := Page{
		Revision: s.config.Revision,
		Items:    append([]RegistryEntry{}, items[cursor:end]...),
		Count:    end - cursor,
	}
	if end < len(items) {
		page.NextCursor = strconv.Itoa(end)
	}
	return page
}

func (s *Service) Discover(request DiscoveryRequest) DiscoveryResponse {
	locale := request.Locale
	if locale == "" {
		locale = s.config.DefaultLocale
	}
	limit := request.Limit
	if limit <= 0 || limit > 20 {
		limit = 12
	}
	needle := normalizeSearchText(request.Text)
	matches := make([]DiscoveryMatch, 0)
	for _, entry := range s.entries {
		if entry.Kind != "keyword" {
			continue
		}
		if request.ModeID != "" && !supportsMode(entry.CompatibleModes, request.ModeID) {
			continue
		}
		score := discoveryScore(entry, locale, needle)
		if score <= 0 {
			continue
		}
		matches = append(matches, DiscoveryMatch{
			ID:      entry.ID,
			Kind:    entry.Kind,
			Version: entry.Version,
			Name:    localizedName(entry, locale),
			Score:   score,
		})
	}
	sort.Slice(matches, func(i, j int) bool {
		if matches[i].Score == matches[j].Score {
			return matches[i].ID < matches[j].ID
		}
		return matches[i].Score > matches[j].Score
	})
	if len(matches) > limit {
		matches = matches[:limit]
	}
	return DiscoveryResponse{Revision: s.config.Revision, Matches: matches}
}

func (s *Service) validateReferences() error {
	for _, mode := range s.modes {
		for _, id := range mode.Capabilities {
			entry, ok := s.entries[id]
			if !ok || entry.Kind != "capability" {
				return errors.New("creator_registry_mode_capability_missing:" + mode.ID + ":" + id)
			}
		}
	}
	for _, entry := range s.entries {
		for _, dependency := range entry.Dependencies {
			if _, ok := s.entries[dependency]; !ok {
				return errors.New("creator_registry_dependency_missing:" + entry.ID + ":" + dependency)
			}
		}
	}
	return nil
}

func supportsMode(modes []string, modeID string) bool {
	if len(modes) == 0 {
		return true
	}
	for _, mode := range modes {
		if mode == "*" || mode == modeID {
			return true
		}
	}
	return false
}

func entryMatches(entry RegistryEntry, locale string, needle string) bool {
	if strings.Contains(normalizeSearchText(entry.ID), needle) ||
		strings.Contains(normalizeSearchText(localizedName(entry, locale)), needle) {
		return true
	}
	for _, alias := range aliasesForLocale(entry, locale) {
		if strings.Contains(normalizeSearchText(alias), needle) {
			return true
		}
	}
	return false
}

func discoveryScore(entry RegistryEntry, locale string, needle string) int {
	if needle == "" {
		return 1
	}
	score := 0
	values := append([]string{entry.ID, localizedName(entry, locale)}, aliasesForLocale(entry, locale)...)
	for _, value := range values {
		normalized := normalizeSearchText(value)
		switch {
		case normalized == needle:
			score = max(score, 100)
		case strings.Contains(normalized, needle) || strings.Contains(needle, normalized):
			score = max(score, 70)
		default:
			for _, token := range strings.Fields(needle) {
				if len([]rune(token)) >= 2 && strings.Contains(normalized, token) {
					score += 10
				}
			}
		}
	}
	return score
}

func localizedName(entry RegistryEntry, locale string) string {
	if value := entry.Name[locale]; value != "" {
		return value
	}
	if value := entry.Name["en"]; value != "" {
		return value
	}
	for _, value := range entry.Name {
		return value
	}
	return entry.ID
}

func aliasesForLocale(entry RegistryEntry, locale string) []string {
	aliases := append([]string{}, entry.Aliases[locale]...)
	if locale != "en" {
		aliases = append(aliases, entry.Aliases["en"]...)
	}
	return aliases
}

func normalizeSearchText(value string) string {
	value = strings.ToLower(strings.TrimSpace(value))
	return strings.Join(strings.Fields(value), " ")
}

func digestJSON(value any) string {
	encoded, _ := json.Marshal(value)
	digest := sha256.Sum256(encoded)
	return hex.EncodeToString(digest[:])
}

func cloneEntry(entry RegistryEntry) RegistryEntry {
	entry.Name = cloneStringMap(entry.Name)
	entry.Aliases = cloneAliases(entry.Aliases)
	entry.CompatibleModes = append([]string{}, entry.CompatibleModes...)
	entry.Dependencies = append([]string{}, entry.Dependencies...)
	entry.Permissions = append([]string{}, entry.Permissions...)
	return entry
}

func cloneMode(mode Mode) Mode {
	mode.Capabilities = append([]string{}, mode.Capabilities...)
	mode.RuntimeContract = cloneStringMap(mode.RuntimeContract)
	return mode
}

func cloneStringMap(source map[string]string) map[string]string {
	result := make(map[string]string, len(source))
	for key, value := range source {
		result[key] = value
	}
	return result
}

func cloneAliases(source map[string][]string) map[string][]string {
	result := make(map[string][]string, len(source))
	for key, value := range source {
		result[key] = append([]string{}, value...)
	}
	return result
}
