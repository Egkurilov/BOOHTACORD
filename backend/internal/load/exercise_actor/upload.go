package exercise_actor

import (
	"bytes"
	"context"
	"crypto/sha256"
	"errors"
	"io"
	"mime/multipart"
)

type zeros struct{}

func (zeros) Read(p []byte) (int, error) { clear(p); return len(p), nil }
func multipartFile(size int) (Upload, error) {
	var body bytes.Buffer
	writer := multipart.NewWriter(&body)
	part, err := writer.CreateFormFile("file", "synthetic.bin")
	if err != nil {
		return Upload{}, err
	}
	if _, err = io.CopyN(part, zeros{}, int64(size)); err != nil {
		return Upload{}, err
	}
	if err = writer.Close(); err != nil {
		return Upload{}, err
	}
	return Upload{bytes.NewReader(body.Bytes()), writer.FormDataContentType()}, nil
}
func (a *Actor) Upload(ctx context.Context, receivers []*Actor) error {
	file, err := multipartFile(a.Manifest.UploadBytes)
	if err != nil {
		return err
	}
	var attachment struct {
		ID    string `json:"id"`
		Bytes int    `json:"byte_size"`
	}
	if err = a.Request(ctx, "upload", "POST", "/channels/"+a.Manifest.Text+"/attachments", file, 201, &attachment); err != nil {
		return err
	}
	if attachment.ID == "" || attachment.Bytes != a.Manifest.UploadBytes {
		return errors.New("incorrect uploaded byte size")
	}
	if err = a.Message(ctx, receivers, []string{attachment.ID}); err != nil {
		return err
	}
	hash := sha256.New()
	expected := sha256.New()
	io.CopyN(expected, zeros{}, int64(a.Manifest.UploadBytes))
	if err = a.Request(ctx, "download", "GET", "/channels/"+a.Manifest.Text+"/attachments/"+attachment.ID, nil, 200, hash); err != nil {
		return err
	}
	if !bytes.Equal(hash.Sum(nil), expected.Sum(nil)) {
		return errors.New("download byte integrity failure")
	}
	return nil
}
func (a *Actor) UploadLimit(ctx context.Context) error {
	file, err := multipartFile(25000001)
	if err != nil {
		return err
	}
	return a.Request(ctx, "upload_limit", "POST", "/channels/"+a.Manifest.Text+"/attachments", file, 413, nil)
}
