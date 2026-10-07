package publishscreendescriptorapi

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"mime"
	"net/http"
	"strings"

	sessionapi "voice-platform/backend/internal/identity/authenticate_session/api"
	publishdescriptor "voice-platform/backend/internal/media/publish_screen_descriptor"
)

const maxDescriptorBytes = 4096

type Operations interface {
	Apply(context.Context, publishdescriptor.Principal, string, string, publishdescriptor.Descriptor) error
}

type Handler struct {
	operations     Operations
	sessions       sessionapi.Authenticator
	expectedOrigin string
}

func RegisterRoutes(mux *http.ServeMux, sessions sessionapi.Authenticator, operations Operations, expectedOrigin string) {
	handler := Handler{operations: operations, sessions: sessions, expectedOrigin: expectedOrigin}
	mux.Handle("PUT /api/v1/voice/leases/{leaseID}/screen-profile/v1", handler.protect(http.HandlerFunc(handler.update)))
}

func (handler Handler) protect(next http.Handler) http.Handler {
	next = sessionapi.Require(handler.sessions)(next)
	return http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Cache-Control", "private, no-store, max-age=0")
		writer.Header().Set("Pragma", "no-cache")
		writer.Header().Set("Expires", "0")
		writer.Header().Set("X-Content-Type-Options", "nosniff")
		writer.Header().Set("Vary", "Cookie")
		next.ServeHTTP(writer, request)
	})
}

func (handler Handler) update(writer http.ResponseWriter, request *http.Request) {
	if handler.expectedOrigin == "" || request.Header.Get("Origin") != handler.expectedOrigin {
		writeError(writer, http.StatusForbidden, "FORBIDDEN")
		return
	}
	mediaType, params, err := mime.ParseMediaType(request.Header.Get("Content-Type"))
	if err != nil || !strings.EqualFold(mediaType, "application/json") || len(params) != 0 {
		writeError(writer, http.StatusUnsupportedMediaType, "UNSUPPORTED_MEDIA_TYPE")
		return
	}
	body, err := io.ReadAll(http.MaxBytesReader(writer, request.Body, maxDescriptorBytes))
	if err != nil {
		var oversized *http.MaxBytesError
		if errors.As(err, &oversized) {
			writeError(writer, http.StatusRequestEntityTooLarge, "PAYLOAD_TOO_LARGE")
		} else {
			writeError(writer, http.StatusBadRequest, "VALIDATION_FAILED")
		}
		return
	}
	if !completeShape(body) {
		writeError(writer, http.StatusBadRequest, "VALIDATION_FAILED")
		return
	}
	decoder := json.NewDecoder(bytes.NewReader(body))
	decoder.DisallowUnknownFields()
	var descriptor publishdescriptor.Descriptor
	if decoder.Decode(&descriptor) != nil || !publishdescriptor.Validate(descriptor) {
		writeError(writer, http.StatusBadRequest, "VALIDATION_FAILED")
		return
	}
	var trailing any
	if err := decoder.Decode(&trailing); err != io.EOF {
		writeError(writer, http.StatusBadRequest, "VALIDATION_FAILED")
		return
	}
	principal, ok := sessionapi.PrincipalFrom(request.Context())
	if !ok {
		writeError(writer, http.StatusUnauthorized, "UNAUTHENTICATED")
		return
	}
	who := publishdescriptor.Principal{AccountID: principal.AccountID, SessionDigest: principal.SessionDigest}
	err = handler.operations.Apply(request.Context(), who, request.PathValue("leaseID"), handler.expectedOrigin, descriptor)
	if err != nil {
		writeOperationFailure(writer, err)
		return
	}
	writer.Header().Set("X-Screen-Profile-Operation-Revision", uintString(descriptor.Scope.OperationRevision))
	writer.WriteHeader(http.StatusNoContent)
}
