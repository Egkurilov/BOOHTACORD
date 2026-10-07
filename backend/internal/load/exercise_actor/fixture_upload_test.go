package exercise_actor

import (
	"encoding/json"
	"github.com/google/uuid"
	"io"
	"net/http"
)

func (f *fixture) upload(w http.ResponseWriter, r *http.Request) {
	if r.Method == "GET" {
		if f.corrupt {
			w.Write([]byte("corrupt"))
		} else {
			w.Write(f.attachment)
		}
		return
	}
	reader, err := r.MultipartReader()
	if err != nil {
		w.WriteHeader(400)
		return
	}
	part, err := reader.NextPart()
	if err != nil {
		w.WriteHeader(400)
		return
	}
	data, err := io.ReadAll(io.LimitReader(part, 25000001))
	if err != nil {
		w.WriteHeader(400)
		return
	}
	if len(data) > 25000000 {
		w.WriteHeader(413)
		return
	}
	f.attachment = data
	w.WriteHeader(201)
	json.NewEncoder(w).Encode(map[string]any{"id": uuid.NewString(), "byte_size": len(data)})
}
