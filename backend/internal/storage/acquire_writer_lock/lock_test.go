package writerlock

import (
	"bufio"
	"errors"
	"os"
	"os/exec"
	"testing"
)

func TestOneWriterAndHandover(t *testing.T) {
	root := t.TempDir()
	first, err := Acquire(root)
	if err != nil {
		t.Fatal(err)
	}
	defer first.Close()
	if second, err := Acquire(root); !errors.Is(err, ErrBusy) {
		if second != nil {
			second.Close()
		}
		t.Fatalf("second writer should fail: %v", err)
	}
	if err := first.Close(); err != nil {
		t.Fatal(err)
	}
	second, err := Acquire(root)
	if err != nil {
		t.Fatal(err)
	}
	defer second.Close()
	if err := first.Close(); err != nil {
		t.Fatal(err)
	}
	if third, err := Acquire(root); !errors.Is(err, ErrBusy) {
		if third != nil {
			third.Close()
		}
		t.Fatalf("repeated old close released new owner: %v", err)
	}
}

func TestIndependentProcessCrashRelease(t *testing.T) {
	root := t.TempDir()
	child := exec.Command(os.Args[0], "-test.run=^TestWriterChild$")
	child.Env = append(os.Environ(), "QA_WRITER_CHILD="+root)
	stdout, err := child.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	stdin, err := child.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	defer stdin.Close()
	if err := child.Start(); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { child.Process.Kill(); child.Wait() })
	line, err := bufio.NewReader(stdout).ReadString('\n')
	if err != nil || line != "ready\n" {
		t.Fatalf("child not ready: %v", err)
	}
	if second, err := Acquire(root); !errors.Is(err, ErrBusy) {
		if second != nil {
			second.Close()
		}
		t.Fatalf("independent writer not rejected: %v", err)
	}
	if err := child.Process.Kill(); err != nil {
		t.Fatal(err)
	}
	child.Wait()
	next, err := Acquire(root)
	if err != nil {
		t.Fatal(err)
	}
	defer next.Close()
}

func TestWriterChild(t *testing.T) {
	root := os.Getenv("QA_WRITER_CHILD")
	if root == "" {
		return
	}
	lock, err := Acquire(root)
	if err != nil {
		os.Exit(2)
	}
	os.Stdout.WriteString("ready\n")
	bufio.NewReader(os.Stdin).ReadByte()
	lock.Close()
	os.Exit(0)
}

func TestInvalidDirectory(t *testing.T) {
	if lock, err := Acquire(""); err == nil {
		lock.Close()
		t.Fatal("empty directory must fail")
	}
}
