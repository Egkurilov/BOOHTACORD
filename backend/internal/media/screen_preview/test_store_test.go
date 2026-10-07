package screenpreview

import "github.com/google/uuid"

type testStore struct {
	generation, track  string
	revision, reserved uint64
	body               []byte
}

func (store *testStore) Begin(_ string, track string) (string, error) {
	store.generation, store.track = uuid.NewString(), track
	return store.generation, nil
}
func (store *testStore) Track(_ string, generation string) (string, error) {
	if generation != store.generation {
		return "", ErrStaleGeneration
	}
	return store.track, nil
}
func (store *testStore) Reserve(_ string, generation string, revision uint64) (string, error) {
	if generation != store.generation || revision <= store.revision {
		return "", ErrStaleGeneration
	}
	store.reserved = revision
	return store.track, nil
}
func (store *testStore) Commit(_ string, generation string, revision uint64, body []byte) error {
	if generation != store.generation || revision != store.reserved {
		return ErrStaleGeneration
	}
	store.body, store.revision = append([]byte(nil), body...), revision
	return nil
}
func (store *testStore) Read(_ string, generation string) ([]byte, uint64, bool, error) {
	if generation != store.generation {
		return nil, 0, false, ErrStaleGeneration
	}
	return append([]byte(nil), store.body...), store.revision, len(store.body) > 0, nil
}
func (store *testStore) Invalidate(_ string, generation string) error {
	if generation == store.generation {
		store.body = nil
		store.generation = ""
	}
	return nil
}
