//go:build !windows
// +build !windows

package pty

import (
	"os"
	"os/exec"
	"runtime"
	"sync"

	"github.com/creack/pty"
)

func newPty() (PTY, error) {
	ptyFile, ttyFile, err := pty.Open()
	if err != nil {
		return nil, err
	}

	return &otherPty{
		pty: ptyFile,
		tty: ttyFile,
	}, nil
}

type otherPty struct {
	mutex    sync.Mutex
	pty, tty *os.File
}

type otherProcess struct {
	pty *os.File
	cmd *exec.Cmd

	// cmdDone protects access to cmdErr: anything reading cmdErr should read from cmdDone first.
	cmdDone chan any
	cmdErr  error
}

func (p *otherPty) Input() ReadWriter {
	return ReadWriter{
		Reader: p.tty,
		Writer: p.pty,
	}
}

func (p *otherPty) Output() ReadWriter {
	return ReadWriter{
		Reader: p.pty,
		Writer: p.tty,
	}
}

func (p *otherPty) Resize(height uint16, width uint16) error {
	p.mutex.Lock()
	defer p.mutex.Unlock()
	return pty.Setsize(p.pty, &pty.Winsize{
		Rows: height,
		Cols: width,
	})
}

func (p *otherPty) Close() error {
	p.mutex.Lock()
	defer p.mutex.Unlock()

	err := p.pty.Close()
	if err != nil {
		_ = p.tty.Close()
		return err
	}

	err = p.tty.Close()
	if err != nil {
		return err
	}
	return nil
}

func (p *otherProcess) Wait() error {
	<-p.cmdDone
	return p.cmdErr
}

func (p *otherProcess) Kill() error {
	return p.cmd.Process.Kill()
}

func (p *otherProcess) waitInternal() {
	// The GC can garbage collect the TTY FD before the command
	// has finished running. See:
	// https://github.com/creack/pty/issues/127#issuecomment-932764012
	p.cmdErr = p.cmd.Wait()
	runtime.KeepAlive(p.pty)
	close(p.cmdDone)
}
