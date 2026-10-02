// Package postgres owns disposable-schema test infrastructure, never domain seeds.
package postgres

import (
	"errors"
	"net"

	"github.com/jackc/pgx/v5/pgxpool"
)

type HostPolicy bool

const (
	LoopbackIP          HostPolicy = false
	LoopbackOrLocalhost HostPolicy = true
)

func config(dsn string, policy HostPolicy) (*pgxpool.Config, error) {
	value, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return nil, errors.New("invalid test database configuration")
	}
	hosts := []string{value.ConnConfig.Host}
	for _, fallback := range value.ConnConfig.Fallbacks {
		hosts = append(hosts, fallback.Host)
	}
	for _, host := range hosts {
		address := net.ParseIP(host)
		if policy == LoopbackOrLocalhost && host == "localhost" {
			continue
		}
		if address == nil || !address.IsLoopback() {
			return nil, errors.New("test database must use an allowed loopback address")
		}
	}
	return value, nil
}
