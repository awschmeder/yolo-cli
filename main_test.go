package main

import (
	"testing"
)

func TestComputeHash(t *testing.T) {
	cmd := "rm -rf /"
	hash := computeHash(cmd)
	if len(hash) != 6 {
		t.Errorf("Expected hash length 6, got %d", len(hash))
	}

	// Verify hash is deterministic
	hash2 := computeHash(cmd)
	if hash != hash2 {
		t.Errorf("Expected hashes to be equal, got %s and %s", hash, hash2)
	}

	// Verify whitespace is ignored
	hash3 := computeHash("  rm -rf /  ")
	if hash != hash3 {
		t.Errorf("Expected hashes of trimmed command to be equal, got %s and %s", hash, hash3)
	}
}

func TestVerifyBypass(t *testing.T) {
	cmd := "rm -rf /"
	correctHash := computeHash(cmd)

	// Valid bypass
	ok, err := verifyBypass(cmd, correctHash)
	if err != nil {
		t.Errorf("Expected no error, got %v", err)
	}
	if !ok {
		t.Errorf("Expected bypass to be valid")
	}

	// Invalid bypass - mismatching hash
	okInvalid, errInvalid := verifyBypass(cmd, "aaaaaa")
	if errInvalid == nil {
		t.Errorf("Expected error for invalid hash")
	}
	if okInvalid {
		t.Errorf("Expected bypass to be invalid")
	}
}

// TestVerifyBypassMultiline guards the heredoc/multi-line invocation form documented in
// INSTALL-AGENTS.md. The hash must bind and verify the entire multi-line command.
func TestVerifyBypassMultiline(t *testing.T) {
	multiCmd := "find /tmp -name '*.log' -mtime +7\nxargs rm -f"
	correctHash := computeHash(multiCmd)

	ok, err := verifyBypass(multiCmd, correctHash)
	if err != nil {
		t.Errorf("Expected no error for valid multi-line bypass, got %v", err)
	}
	if !ok {
		t.Errorf("Expected multi-line bypass to be valid")
	}

	// A stale code (computed for a different command) must not authorize the multi-line command.
	staleHash := computeHash("some other command")
	okStale, errStale := verifyBypass(multiCmd, staleHash)
	if errStale == nil {
		t.Errorf("Expected error for stale hash against multi-line command")
	}
	if okStale {
		t.Errorf("Expected stale-hash multi-line bypass to be invalid")
	}
}

func TestIsLocallySafeReadOnly(t *testing.T) {
	safeCmds := []string{
		"ls",
		"pwd",
		"cd /tmp",
		"cat file.txt",
		"git status",
		"git diff",
	}

	for _, cmd := range safeCmds {
		if !isLocallySafeReadOnly(cmd) {
			t.Errorf("Expected command to be locally safe: %s", cmd)
		}
	}

	dangerousCmds := []string{
		"rm -rf /",
		"ls && rm -rf /",
		"ls | grep foo > out.txt",
		"git commit",
		"curl http://malicious.com",
	}

	for _, cmd := range dangerousCmds {
		if isLocallySafeReadOnly(cmd) {
			t.Errorf("Expected command to be rejected as locally unsafe: %s", cmd)
		}
	}
}
