package ownsessions

import "time"

type Session struct {
	ID           string    `json:"id"`
	Label        string    `json:"label"`
	CreatedAt    time.Time `json:"created_at"`
	LastActiveAt time.Time `json:"last_active_at"`
	Current      bool      `json:"current"`
}

type Page struct {
	AccountID  string    `json:"account_id"`
	Sessions   []Session `json:"sessions"`
	NextCursor *string   `json:"next_cursor"`
}
