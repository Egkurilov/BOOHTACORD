package main

import (
	"fmt"
	"os"
	"time"

	cleanupstalestagingfiles "voice-platform/backend/internal/storage/cleanup_stale_staging_files"
)

func main() {
	removed, err := cleanupstalestagingfiles.RemoveExpired(os.Getenv("ATTACHMENTS_DIRECTORY"), time.Now().UTC())
	if err != nil {
		fmt.Fprintln(os.Stderr, "could not remove stale staging files")
		os.Exit(1)
	}
	fmt.Printf("Removed %d stale staging files.\n", removed)
}
