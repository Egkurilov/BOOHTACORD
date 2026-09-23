package uploadownavatar

import (
	"bytes"
	"context"
	"errors"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"testing"
)

func TestUploadAcceptsPNGAndJPEGThenStoresNormalizedPNG(t *testing.T) {
	for _, format := range []string{"image/png", "image/jpeg"} {
		store, files := &fakeStore{}, &fakeFiles{}
		service := New(store, files)
		body := pngImage(t, 3, 2)
		if format == "image/jpeg" {
			body = jpegImage(t, 3, 2)
		}
		key, err := service.Upload(context.Background(), Input{AccountID: "account-1", ContentType: format, Data: body})
		if err != nil || key == "" || store.accountID != "account-1" || store.newKey != key || files.savedFormat != "png" {
			t.Fatalf("Upload(%s) key=%q err=%v store=%#v files=%#v", format, key, err, store, files)
		}
	}
}

func TestUploadRejectsInvalidBytesOversizeAndDimensionsBeforeWriting(t *testing.T) {
	for _, input := range []Input{
		{AccountID: "account-1", ContentType: "image/gif", Data: pngImage(t, 1, 1)},
		{AccountID: "account-1", ContentType: "image/png", Data: []byte("not an image")},
		{AccountID: "account-1", ContentType: "image/png", Data: bytes.Repeat([]byte("x"), maxUploadBytes+1)},
		{AccountID: "account-1", ContentType: "image/png", Data: pngImage(t, maxDimension+1, 1)},
	} {
		store, files := &fakeStore{}, &fakeFiles{}
		if _, err := New(store, files).Upload(context.Background(), input); !errors.Is(err, ErrInvalidImage) || files.saved {
			t.Fatalf("Upload() error=%v, file saved=%v", err, files.saved)
		}
	}
}

func TestUploadReplacesAndRemovesOldAvatarKey(t *testing.T) {
	store, files := &fakeStore{oldKey: "older-key"}, &fakeFiles{}
	key, err := New(store, files).Upload(context.Background(), Input{AccountID: "account-1", ContentType: "image/png", Data: pngImage(t, 2, 2)})
	if err != nil || key != "new-key" || files.deleted != "older-key" {
		t.Fatalf("Upload() key=%q err=%v deleted=%q", key, err, files.deleted)
	}
}

func pngImage(t *testing.T, width, height int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	img.Set(0, 0, color.RGBA{R: 10, G: 20, B: 30, A: 255})
	var output bytes.Buffer
	if err := png.Encode(&output, img); err != nil {
		t.Fatal(err)
	}
	return output.Bytes()
}

func jpegImage(t *testing.T, width, height int) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, width, height))
	img.Set(0, 0, color.RGBA{R: 10, G: 20, B: 30, A: 255})
	var output bytes.Buffer
	if err := jpeg.Encode(&output, img, nil); err != nil {
		t.Fatal(err)
	}
	return output.Bytes()
}

type fakeStore struct{ accountID, oldKey, newKey string }

func (store *fakeStore) ReplaceAvatarKey(_ context.Context, accountID, key string) (string, error) {
	store.accountID, store.newKey = accountID, key
	return store.oldKey, nil
}
func (store *fakeStore) ClearAvatarKey(_ context.Context, _ string) (string, error) {
	return store.oldKey, nil
}

type fakeFiles struct {
	saved                bool
	savedFormat, deleted string
}

func (files *fakeFiles) SavePNG(_ context.Context, _ []byte) (string, error) {
	files.saved, files.savedFormat = true, "png"
	return "new-key", nil
}
func (files *fakeFiles) Delete(_ context.Context, key string) error { files.deleted = key; return nil }
