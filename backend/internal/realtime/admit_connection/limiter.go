package admitconnection

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"sync"
)

var ErrInvalidConfig = errors.New("invalid realtime connection quota")

type Config struct {
	GlobalLimit  int
	AccountLimit int
	SessionLimit int
}

type Limiter struct {
	mutex        sync.Mutex
	globalLimit  int
	accountLimit int
	sessionLimit int
	active       int
	accounts     map[string]int
	sessions     map[string]int
}

type Stats struct{ ActiveConnections, ActiveAccounts, ActiveSessions int }

func New(config Config) (*Limiter, error) {
	if config.GlobalLimit < 1 || config.AccountLimit < 1 || config.SessionLimit < 1 {
		return nil, ErrInvalidConfig
	}
	return &Limiter{globalLimit: config.GlobalLimit, accountLimit: config.AccountLimit,
		sessionLimit: config.SessionLimit, accounts: make(map[string]int), sessions: make(map[string]int)}, nil
}

func (limiter *Limiter) TryAcquire(accountID string, digest [sha256.Size]byte) (func(), bool) {
	if accountID == "" {
		return func() {}, false
	}
	sessionKey := hex.EncodeToString(digest[:])
	limiter.mutex.Lock()
	if limiter.active >= limiter.globalLimit || limiter.accounts[accountID] >= limiter.accountLimit || limiter.sessions[sessionKey] >= limiter.sessionLimit {
		limiter.mutex.Unlock()
		return func() {}, false
	}
	limiter.active++
	limiter.accounts[accountID]++
	limiter.sessions[sessionKey]++
	limiter.mutex.Unlock()

	var once sync.Once
	return func() { once.Do(func() { limiter.release(accountID, sessionKey) }) }, true
}

func (limiter *Limiter) release(accountID, sessionKey string) {
	limiter.mutex.Lock()
	defer limiter.mutex.Unlock()
	limiter.active--
	decrement(limiter.accounts, accountID)
	decrement(limiter.sessions, sessionKey)
}

func decrement(counts map[string]int, key string) {
	if counts[key] <= 1 {
		delete(counts, key)
		return
	}
	counts[key]--
}

func (limiter *Limiter) Stats() Stats {
	limiter.mutex.Lock()
	defer limiter.mutex.Unlock()
	return Stats{ActiveConnections: limiter.active, ActiveAccounts: len(limiter.accounts), ActiveSessions: len(limiter.sessions)}
}
