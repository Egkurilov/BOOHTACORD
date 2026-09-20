package cleanupstalestagingfiles

import (
	"errors"
	"path/filepath"
	"time"
)

const StagingRetention = time.Hour

var ErrInvalidAttachmentsDirectory = errors.New("invalid attachments directory")

func RemoveExpired(attachmentsDirectory string, now time.Time) (int, error) {
	if attachmentsDirectory == "" || !filepath.IsAbs(attachmentsDirectory) || now.IsZero() {
		return 0, ErrInvalidAttachmentsDirectory
	}
	service, err := New(filepath.Join(attachmentsDirectory, "staging"))
	if err != nil {
		return 0, err
	}
	return service.RemoveBefore(now.Add(-StagingRetention))
}
