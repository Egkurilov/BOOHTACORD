package admitupload

import (
	"errors"
	"net/http"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
)

var ErrInvalidConfig = errors.New("invalid upload concurrency quota")

type Config struct{ GlobalLimit, AccountLimit int }
type Limiter struct {
	mutex                             sync.Mutex
	globalLimit, accountLimit, active int
	accounts                          map[string]int
	started                           map[uint64]time.Time
	nextID                            uint64
}

func New(config Config) (*Limiter, error) {
	if config.GlobalLimit < 1 || config.AccountLimit < 1 {
		return nil, ErrInvalidConfig
	}
	return &Limiter{globalLimit: config.GlobalLimit, accountLimit: config.AccountLimit, accounts: make(map[string]int), started: make(map[uint64]time.Time)}, nil
}

func (limiter *Limiter) TryAcquire(accountID string) (func(), bool) {
	if accountID == "" {
		return func() {}, false
	}
	limiter.mutex.Lock()
	if limiter.active >= limiter.globalLimit || limiter.accounts[accountID] >= limiter.accountLimit {
		limiter.mutex.Unlock()
		return func() {}, false
	}
	limiter.active++
	limiter.accounts[accountID]++
	limiter.nextID++
	id := limiter.nextID
	limiter.started[id] = time.Now()
	limiter.mutex.Unlock()
	var once sync.Once
	return func() { once.Do(func() { limiter.release(accountID, id) }) }, true
}

func (limiter *Limiter) release(accountID string, id uint64) {
	limiter.mutex.Lock()
	defer limiter.mutex.Unlock()
	limiter.active--
	delete(limiter.started, id)
	if limiter.accounts[accountID] <= 1 {
		delete(limiter.accounts, accountID)
	} else {
		limiter.accounts[accountID]--
	}
}

func (limiter *Limiter) Describe(channel chan<- *prometheus.Desc) {
	channel <- prometheus.NewDesc("voice_platform_uploads_inflight", "Currently active attachment uploads.", nil, nil)
	channel <- prometheus.NewDesc("voice_platform_upload_oldest_inflight_seconds", "Age of the oldest active attachment upload.", nil, nil)
}

func (limiter *Limiter) Collect(channel chan<- prometheus.Metric) {
	limiter.mutex.Lock()
	active, oldest := limiter.active, time.Duration(0)
	now := time.Now()
	for _, started := range limiter.started {
		if age := now.Sub(started); age > oldest {
			oldest = age
		}
	}
	limiter.mutex.Unlock()
	channel <- prometheus.MustNewConstMetric(prometheus.NewDesc("voice_platform_uploads_inflight", "Currently active attachment uploads.", nil, nil), prometheus.GaugeValue, float64(active))
	channel <- prometheus.MustNewConstMetric(prometheus.NewDesc("voice_platform_upload_oldest_inflight_seconds", "Age of the oldest active attachment upload.", nil, nil), prometheus.GaugeValue, oldest.Seconds())
}

func (limiter *Limiter) Middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		principal, ok := sessionapi.PrincipalFrom(request.Context())
		if !ok {
			http.Error(writer, "internal", http.StatusInternalServerError)
			return
		}
		release, ok := limiter.TryAcquire(principal.AccountID)
		if !ok {
			writer.Header().Set("Retry-After", "1")
			writer.Header().Set("Content-Type", "application/json; charset=utf-8")
			writer.WriteHeader(http.StatusTooManyRequests)
			_, _ = writer.Write([]byte(`{"error":{"code":"UPLOAD_CONCURRENCY_LIMITED","message":"Слишком много одновременных загрузок"}}`))
			return
		}
		defer release()
		next.ServeHTTP(writer, request)
	})
}
