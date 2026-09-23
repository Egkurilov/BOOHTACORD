package uploadownavatar

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"runtime"
	"testing"
)

func TestPrivateFilesRoundTripAndDelete(t *testing.T) {
	files, err := NewPrivateFiles(filepath.Join(t.TempDir(), "avatars"))
	if err != nil {
		t.Fatal(err)
	}
	want := []byte("normalized png")
	key, err := files.SavePNG(context.Background(), want)
	if err != nil {
		t.Fatal(err)
	}
	got, err := files.ReadPNG(context.Background(), key)
	if err != nil || !bytes.Equal(got, want) {
		t.Fatalf("ReadPNG() = %q, %v", got, err)
	}
	info, err := os.Stat(filepath.Join(files.directory, key+".png"))
	if err != nil || (runtime.GOOS != "windows" && info.Mode().Perm() != 0o600) {
		t.Fatalf("avatar permissions = %v, %v", info, err)
	}
	if err := files.Delete(context.Background(), key); err != nil {
		t.Fatal(err)
	}
	if _, err := files.ReadPNG(context.Background(), key); !os.IsNotExist(err) {
		t.Fatalf("read deleted avatar error = %v", err)
	}
}

func TestPrivateFilesRejectsUntrustedKeys(t *testing.T) {
	files, err := NewPrivateFiles(filepath.Join(t.TempDir(), "avatars"))
	if err != nil {
		t.Fatal(err)
	}
	for _, key := range []string{"../outside", "", "a/b", "bad.png"} {
		if _, err := files.ReadPNG(context.Background(), key); err == nil {
			t.Fatalf("ReadPNG(%q) succeeded", key)
		}
		if err := files.Delete(context.Background(), key); err == nil {
			t.Fatalf("Delete(%q) succeeded", key)
		}
	}
}
