package services

import "time"

// ResolveLocation parses an IANA timezone name (e.g. "Asia/Shanghai",
// "America/Los_Angeles") into *time.Location. Empty or unknown names fall back
// to UTC so callers never need to nil-check. The container ships with tzdata
// (see Dockerfile.prod) so LoadLocation works on prod.
func ResolveLocation(tz string) *time.Location {
	if tz == "" {
		return time.UTC
	}
	if loc, err := time.LoadLocation(tz); err == nil {
		return loc
	}
	return time.UTC
}

// StartOfDay returns 00:00:00 of the calendar day containing `t`, in `loc`.
// Subsequent `Add(24*time.Hour)` is safe except across DST transitions —
// for daily aggregates that's acceptable (one day per year ±1 hour drift
// matters less than getting the boundary roughly right for 99.7% of days).
func StartOfDay(t time.Time, loc *time.Location) time.Time {
	in := t.In(loc)
	return time.Date(in.Year(), in.Month(), in.Day(), 0, 0, 0, 0, loc)
}
