package searchmessages

import (
	"regexp"
	"time"
)

// Boundaries are explicit instants, never server-local calendar dates.
var instantPattern = regexp.MustCompile(`^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?(Z|[+-]([01][0-9]|2[0-3]):[0-5][0-9])$`)

func parseDateRange(from, before string) (*time.Time, *time.Time, error) {
	start, err := parseInstant(from)
	if err != nil {
		return nil, nil, err
	}
	end, err := parseInstant(before)
	if err != nil {
		return nil, nil, err
	}
	if start != nil && end != nil && !start.Before(*end) {
		return nil, nil, ErrInvalidInput
	}
	return start, end, nil
}

func parseInstant(value string) (*time.Time, error) {
	if value == "" {
		return nil, nil
	}
	if !instantPattern.MatchString(value) {
		return nil, ErrInvalidInput
	}
	instant, err := time.Parse(time.RFC3339Nano, value)
	if err != nil || instant.Year() < 1 {
		return nil, ErrInvalidInput
	}
	instant = instant.UTC()
	return &instant, nil
}
