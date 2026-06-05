package main

import (
	"testing"
)

func TestResolveDelay(t *testing.T) {
	tests := []struct {
		name      string
		flagVal   float64
		envVal    string
		wantSecs  float64
		wantError bool
	}{
		{name: "zero both", flagVal: 0, envVal: "", wantSecs: 0},
		{name: "valid float env", flagVal: 0, envVal: "0.5", wantSecs: 0.5},
		{name: "valid int env", flagVal: 0, envVal: "5", wantSecs: 5.0},
		{name: "non-numeric env", flagVal: 0, envVal: "abc", wantError: true},
		{name: "negative env", flagVal: 0, envVal: "-1", wantError: true},
		{name: "flag overrides env", flagVal: 2.0, envVal: "10", wantSecs: 2.0},
		{name: "negative flag", flagVal: -1.0, envVal: "", wantError: true},
		{name: "zero flag uses env", flagVal: 0, envVal: "3.5", wantSecs: 3.5},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got, err := resolveDelay(tc.flagVal, tc.envVal)
			if tc.wantError {
				if err == nil {
					t.Errorf("expected error, got nil (result=%g)", got)
				}
				return
			}
			if err != nil {
				t.Errorf("unexpected error: %v", err)
				return
			}
			if got != tc.wantSecs {
				t.Errorf("expected %g, got %g", tc.wantSecs, got)
			}
		})
	}
}

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
