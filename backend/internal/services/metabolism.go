package services

import (
	"strings"
	"time"

	"github.com/your-org/loss-weight/backend/internal/models"
)

// Metabolism is the pre-computed set of energy numbers we derive from a
// user's profile. Kept in lock-step with frontend lib/utils/macros.dart so
// the AI prompt, the dashboard card, and any future surface agree on the
// same BMR/TDEE — that contract is called out in CLAUDE.md.
type Metabolism struct {
	BMR                float64 // Mifflin-St Jeor, kcal/day; 0 when profile incomplete
	TDEE               float64 // BMR × activity multiplier, kcal/day; 0 when BMR or activity missing
	ActivityMultiplier float64 // 1.2 … 1.9; 0 when activity_level not set
	Age                int
	HasBMR             bool
	HasTDEE            bool
}

// computeMetabolism derives BMR and TDEE from a profile. Returns zeros for
// fields it can't compute (instead of erroring) so callers can degrade to
// "show what you know" on the UI.
//
// Plan B deficit policy (see commit introducing the metabolism card): the
// caller computes deficit = TDEE − eaten. Logged exercise calories are
// shown separately and NOT added to expenditure, to avoid double-counting
// against an activity level the user already said covers their workouts.
func computeMetabolism(profile *models.UserProfile) Metabolism {
	m := Metabolism{}
	if profile == nil {
		return m
	}

	// Age from birthday. 365.25 to average out leap years over a lifetime.
	if profile.Birthday != nil && !profile.Birthday.IsZero() {
		a := int(time.Since(*profile.Birthday).Hours() / 24 / 365.25)
		if a > 0 && a < 120 {
			m.Age = a
		}
	}

	// Mifflin-St Jeor. Requires all four inputs or the number is noise.
	if m.Age > 0 && profile.Height > 0 && profile.CurrentWeight > 0 && profile.Gender != "" {
		w := float64(profile.CurrentWeight)
		h := float64(profile.Height)
		bmr := 10*w + 6.25*h - 5*float64(m.Age)
		g := strings.ToLower(string(profile.Gender))
		if g == "male" || g == "m" || g == "男" || g == "男性" {
			bmr += 5
		} else {
			bmr -= 161
		}
		m.BMR = bmr
		m.HasBMR = true
	}

	// Activity multiplier. Standard Harris-Benedict style mapping for the
	// five-point scale we collect in quick-setup.
	if profile.ActivityLevel >= 1 && profile.ActivityLevel <= 5 {
		mults := [6]float64{0, 1.2, 1.375, 1.55, 1.725, 1.9}
		m.ActivityMultiplier = mults[profile.ActivityLevel]
	}

	if m.HasBMR && m.ActivityMultiplier > 0 {
		m.TDEE = m.BMR * m.ActivityMultiplier
		m.HasTDEE = true
	}

	return m
}
