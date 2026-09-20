package writeupload

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
)

const MaxBytes int64 = 25_000_000

var (
	ErrInvalidDirectory = errors.New("invalid upload temporary directory")
	ErrInvalidSource    = errors.New("invalid upload source")
	ErrTooLarge         = errors.New("attachment exceeds maximum size")
)

type Result struct {
	TempPath  string
	SizeBytes int64
}

type Writer struct{ directory string }

func New(directory string) (Writer, error) {
	if directory == "" {
		return Writer{}, ErrInvalidDirectory
	}
	info, err := os.Stat(directory)
	if err != nil || !info.IsDir() {
		return Writer{}, ErrInvalidDirectory
	}
	return Writer{directory: directory}, nil
}

func (writer Writer) Write(ctx context.Context, source io.Reader) (Result, error) {
	return writer.write(ctx, source, nil)
}

func (writer Writer) write(ctx context.Context, source io.Reader, guard Guard) (Result, error) {
	if err := ctx.Err(); err != nil {
		return Result{}, err
	}
	if source == nil {
		return Result{}, ErrInvalidSource
	}
	file, err := os.CreateTemp(writer.directory, "upload-*.part")
	if err != nil {
		return Result{}, fmt.Errorf("create temporary upload: %w", err)
	}
	tempPath := file.Name()
	complete := false
	defer func() {
		if !complete {
			_ = file.Close()
			_ = os.Remove(tempPath)
		}
	}()

	written, err := io.Copy(file, io.LimitReader(contextReader{ctx: ctx, source: source, guard: guard}, MaxBytes+1))
	if err != nil {
		return Result{}, fmt.Errorf("stream upload: %w", err)
	}
	if written > MaxBytes {
		return Result{}, ErrTooLarge
	}
	if err := ctx.Err(); err != nil {
		return Result{}, err
	}
	if err := file.Sync(); err != nil {
		return Result{}, fmt.Errorf("sync temporary upload: %w", err)
	}
	if err := file.Close(); err != nil {
		return Result{}, fmt.Errorf("close temporary upload: %w", err)
	}
	complete = true
	return Result{TempPath: tempPath, SizeBytes: written}, nil
}
