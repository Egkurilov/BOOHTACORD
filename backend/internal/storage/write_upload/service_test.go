package writeupload

import (
	"context"
	"errors"
	"io"
	"os"
	"testing"
)

func TestWriteKeepsExactlyTwentyFiveMillionBytes(t *testing.T) {
	directory := t.TempDir()
	writer, err := New(directory)
	if err != nil {
		t.Fatal(err)
	}
	result, err := writer.Write(context.Background(), &repeatedReader{remaining: MaxBytes})
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(result.TempPath)
	info, err := os.Stat(result.TempPath)
	if err != nil || result.SizeBytes != MaxBytes || info.Size() != MaxBytes {
		t.Fatalf("result = %#v, info = %#v, error = %v", result, info, err)
	}
}

func TestWriteRejectsExtraByteAndRemovesTemporaryFile(t *testing.T) {
	directory := t.TempDir()
	writer, err := New(directory)
	if err != nil {
		t.Fatal(err)
	}
	_, err = writer.Write(context.Background(), &repeatedReader{remaining: MaxBytes + 1})
	if !errors.Is(err, ErrTooLarge) {
		t.Fatalf("error = %v", err)
	}
	assertDirectoryEmpty(t, directory)
}

func TestWriteRemovesTemporaryFileAfterReadFailure(t *testing.T) {
	directory := t.TempDir()
	writer, err := New(directory)
	if err != nil {
		t.Fatal(err)
	}
	_, err = writer.Write(context.Background(), failingReader{})
	if err == nil {
		t.Fatal("expected read error")
	}
	assertDirectoryEmpty(t, directory)
}

func TestWriteRejectsCancelledContextBeforeCreatingFile(t *testing.T) {
	directory := t.TempDir()
	writer, err := New(directory)
	if err != nil {
		t.Fatal(err)
	}
	operationContext, cancel := context.WithCancel(context.Background())
	cancel()
	_, err = writer.Write(operationContext, &repeatedReader{remaining: 1})
	if !errors.Is(err, context.Canceled) {
		t.Fatalf("error = %v", err)
	}
	assertDirectoryEmpty(t, directory)
}

func assertDirectoryEmpty(t *testing.T, directory string) {
	t.Helper()
	entries, err := os.ReadDir(directory)
	if err != nil || len(entries) != 0 {
		t.Fatalf("entries = %#v, error = %v", entries, err)
	}
}

type repeatedReader struct{ remaining int64 }

func (reader *repeatedReader) Read(buffer []byte) (int, error) {
	if reader.remaining == 0 {
		return 0, io.EOF
	}
	count := int64(len(buffer))
	if count > reader.remaining {
		count = reader.remaining
	}
	for index := int64(0); index < count; index++ {
		buffer[index] = 'x'
	}
	reader.remaining -= count
	return int(count), nil
}

type failingReader struct{}

func (failingReader) Read([]byte) (int, error) { return 0, errors.New("source failed") }
