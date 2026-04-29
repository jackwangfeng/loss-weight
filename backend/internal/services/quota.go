package services

import (
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"
)

// QuotaTracker caps per-user daily AI calls so a single abusive client
// can't blow up Gemini cost (vision @ ~$0.001-0.003/image, chat round-trip
// @ ~$0.0005). In-memory single-instance counter — fine while there's one
// backend pod. Swap to Redis when we run >1 replica.
//
// Day boundary is UTC. The "today" the user sees may be a different
// calendar day, but for cost capping that's irrelevant — what matters is
// that the counter resets within ~24h.
type QuotaTracker struct {
	mu     sync.Mutex
	counts map[string]int // key = "uid:bucket:YYYY-MM-DD"
	limits map[string]int
}

// Bucket names. Add new buckets sparingly — every bucket means more
// product complexity (which limit do you hit when?).
const (
	QuotaBucketText      = "text"      // chat / chat-stream / daily-brief / encouragement
	QuotaBucketExpensive = "expensive" // vision recognize
)

// ErrQuotaExceeded is returned by Check when the daily limit is reached.
var ErrQuotaExceeded = errors.New("daily AI quota exceeded")

func NewQuotaTracker(textLimit, expensiveLimit int) *QuotaTracker {
	q := &QuotaTracker{
		counts: make(map[string]int),
		limits: map[string]int{
			QuotaBucketText:      textLimit,
			QuotaBucketExpensive: expensiveLimit,
		},
	}
	go q.gcLoop()
	return q
}

// Check increments userID's counter for `bucket` and returns
// ErrQuotaExceeded if it's at or past the configured limit. Atomic.
func (q *QuotaTracker) Check(userID uint, bucket string) error {
	limit, ok := q.limits[bucket]
	if !ok {
		// Unknown bucket: don't silently allow — fail closed.
		return fmt.Errorf("unknown quota bucket %q", bucket)
	}
	key := todayKey(userID, bucket)
	q.mu.Lock()
	defer q.mu.Unlock()
	if q.counts[key] >= limit {
		return ErrQuotaExceeded
	}
	q.counts[key]++
	return nil
}

// Used reports (used, limit) for an introspection / UI use case.
func (q *QuotaTracker) Used(userID uint, bucket string) (int, int) {
	key := todayKey(userID, bucket)
	q.mu.Lock()
	defer q.mu.Unlock()
	return q.counts[key], q.limits[bucket]
}

func todayKey(userID uint, bucket string) string {
	return fmt.Sprintf("%d:%s:%s", userID, bucket, time.Now().UTC().Format("2006-01-02"))
}

// gcLoop drops keys not from today every hour. Without this the map grows
// forever as new users come and go.
func (q *QuotaTracker) gcLoop() {
	for {
		time.Sleep(1 * time.Hour)
		today := time.Now().UTC().Format("2006-01-02")
		q.mu.Lock()
		for k := range q.counts {
			if !strings.HasSuffix(k, today) {
				delete(q.counts, k)
			}
		}
		q.mu.Unlock()
	}
}
