package clientupdates

import (
	"encoding/json"
	"fmt"
	"io"
)

func Parse(source io.Reader, allowedHosts []string) (*Catalog, error) {
	limited := io.LimitReader(source, maxCatalogBytes+1)
	payload, err := io.ReadAll(limited)
	if err != nil {
		return nil, fmt.Errorf("read catalog: %w", err)
	}
	if len(payload) > maxCatalogBytes {
		return nil, fmt.Errorf("catalog exceeds %d bytes", maxCatalogBytes)
	}
	decoder := json.NewDecoder(bytesReader(payload))
	decoder.DisallowUnknownFields()
	var catalog Catalog
	if err := decoder.Decode(&catalog); err != nil {
		return nil, fmt.Errorf("decode catalog: %w", err)
	}
	if err := ensureEOF(decoder); err != nil {
		return nil, err
	}
	if err := catalog.validate(allowedHosts); err != nil {
		return nil, err
	}
	return &catalog, nil
}

func ensureEOF(decoder *json.Decoder) error {
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		return fmt.Errorf("catalog contains trailing JSON")
	}
	return nil
}

type byteReader struct {
	payload []byte
	offset  int
}

func bytesReader(payload []byte) *byteReader { return &byteReader{payload: payload} }
func (reader *byteReader) Read(target []byte) (int, error) {
	if reader.offset >= len(reader.payload) {
		return 0, io.EOF
	}
	n := copy(target, reader.payload[reader.offset:])
	reader.offset += n
	return n, nil
}
