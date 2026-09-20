package stageupload

import (
	"context"
	"errors"
	"os"
	"strings"
	"testing"

	reserveuploadspace "voice-platform/backend/internal/storage/reserve_upload_space"
)

func TestStageRemovesTemporaryFileWhenSpaceFallsDuringRead(t *testing.T) {
	directory := t.TempDir()
	manager := newManager(t, &sequenceSpace{snapshots: []reserveuploadspace.Snapshot{
		spaceAtReserve(), spaceAtReserve(), spaceAtReserve(), spaceBelowReserve(),
	}})
	stager := newStager(t, manager, directory)
	source := &twoReadSource{}
	_, err := stager.Stage(context.Background(), source)
	if !errors.Is(err, reserveuploadspace.ErrInsufficientStorage) || source.reads != 2 {
		t.Fatalf("reads = %d, error = %v", source.reads, err)
	}
	assertDirectoryEmpty(t, directory)
	if manager.ReservedBytes() != 0 {
		t.Fatalf("reserved bytes = %d", manager.ReservedBytes())
	}
}

func TestStageReturnsPrivateTemporaryFileAndReleasesReservation(t *testing.T) {
	directory := t.TempDir()
	manager := newManager(t, &sequenceSpace{snapshots: []reserveuploadspace.Snapshot{spaceAtReserve()}})
	stager := newStager(t, manager, directory)
	result, err := stager.Stage(context.Background(), strings.NewReader("bytes"))
	if err != nil || result.SizeBytes != 5 || manager.ReservedBytes() != 0 {
		t.Fatalf("result = %#v, reserved = %d, error = %v", result, manager.ReservedBytes(), err)
	}
	if err := os.Remove(result.TempPath); err != nil {
		t.Fatal(err)
	}
}

func TestStageRejectsAdmissionBeforeReadingOrCreatingFile(t *testing.T) {
	directory := t.TempDir()
	manager := newManager(t, &sequenceSpace{snapshots: []reserveuploadspace.Snapshot{spaceBelowReserve()}})
	stager := newStager(t, manager, directory)
	source := &twoReadSource{}
	_, err := stager.Stage(context.Background(), source)
	if !errors.Is(err, reserveuploadspace.ErrInsufficientStorage) || source.reads != 0 {
		t.Fatalf("reads = %d, error = %v", source.reads, err)
	}
	assertDirectoryEmpty(t, directory)
}
