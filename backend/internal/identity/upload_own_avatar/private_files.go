package uploadownavatar

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type PrivateFiles struct{ directory string }

func NewPrivateFiles(directory string) (PrivateFiles, error) {
	if directory == "" {
		return PrivateFiles{}, errors.New("avatar directory is required")
	}
	if err := os.MkdirAll(directory, 0o700); err != nil {
		return PrivateFiles{}, fmt.Errorf("create avatar directory: %w", err)
	}
	if err := os.Chmod(directory, 0o700); err != nil {
		return PrivateFiles{}, fmt.Errorf("secure avatar directory: %w", err)
	}
	return PrivateFiles{directory: directory}, nil
}

func (files PrivateFiles) SavePNG(ctx context.Context, data []byte) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", err
	}
	var random [32]byte
	if _, err := rand.Read(random[:]); err != nil {
		return "", fmt.Errorf("generate avatar key: %w", err)
	}
	key := hex.EncodeToString(random[:])
	file, err := os.OpenFile(filepath.Join(files.directory, key+".png"), os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0o600)
	if err != nil {
		return "", fmt.Errorf("create avatar file: %w", err)
	}
	if _, err := file.Write(data); err != nil {
		_ = file.Close()
		_ = os.Remove(filepath.Join(files.directory, key+".png"))
		return "", fmt.Errorf("write avatar file: %w", err)
	}
	if err := file.Sync(); err != nil {
		_ = file.Close()
		_ = os.Remove(filepath.Join(files.directory, key+".png"))
		return "", fmt.Errorf("sync avatar file: %w", err)
	}
	if err := file.Close(); err != nil {
		_ = os.Remove(filepath.Join(files.directory, key+".png"))
		return "", fmt.Errorf("close avatar file: %w", err)
	}
	return key, nil
}

func (files PrivateFiles) ReadPNG(ctx context.Context, key string) ([]byte, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	path, err := files.path(key)
	if err != nil {
		return nil, err
	}
	return os.ReadFile(path)
}

func (files PrivateFiles) Delete(ctx context.Context, key string) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	path, err := files.path(key)
	if err != nil {
		return err
	}
	if err := os.Remove(path); errors.Is(err, os.ErrNotExist) {
		return nil
	} else if err != nil {
		return err
	}
	return nil
}

func (files PrivateFiles) path(key string) (string, error) {
	if len(key) != 64 || strings.Trim(key, "0123456789abcdef") != "" {
		return "", errors.New("invalid avatar key")
	}
	return filepath.Join(files.directory, key+".png"), nil
}
