// Package databasecheck guards the disposable database used by native CI tests.
package databasecheck

import (
	"errors"
	"fmt"
	"github.com/jackc/pgx/v5"
)

func Config(primary, legacy string) (*pgx.ConnConfig, error) {
	if primary == "" || primary != legacy {
		return nil, errors.New("both test database variables must select the same disposable database")
	}
	config, err := pgx.ParseConfig(primary)
	if err != nil {
		return nil, errors.New("invalid test database configuration")
	}
	if config.Database != "voice_platform_test" || config.User != "voice_platform_test" {
		return nil, errors.New("test database and user must both be voice_platform_test")
	}
	if config.Host != "127.0.0.1" && config.Host != "localhost" && config.Host != "::1" {
		return nil, errors.New("test database must be exposed on loopback")
	}
	return config, nil
}

func Version(actual, expectedMajor int) error {
	if actual/10000 != expectedMajor {
		return fmt.Errorf("test PostgreSQL major is %d; required %d", actual/10000, expectedMajor)
	}
	return nil
}
