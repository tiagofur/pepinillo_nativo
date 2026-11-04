#!/usr/bin/env python3
"""Fail on high-confidence secrets without printing their values."""

from __future__ import annotations

import argparse
import collections
import math
import re
import subprocess
import sys
import tempfile
from pathlib import Path


DETECTORS = (
    ("private-key-material", re.compile(rb"-----" + rb"BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----")),
    ("github-token", re.compile(rb"\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b|\bgithub_pat_[A-Za-z0-9_]{20,}\b")),
    ("aws-access-key", re.compile(rb"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")),
    ("google-api-key", re.compile(rb"\bAIza[0-9A-Za-z_-]{30,}\b")),
    ("sendgrid-api-key", re.compile(rb"\bSG\.[A-Za-z0-9_-]{16,}\.[A-Za-z0-9_-]{20,}\b")),
    ("stripe-live-secret", re.compile(rb"\b(?:sk|rk)_live_[A-Za-z0-9]{16,}\b")),
    ("secret-key-prefix", re.compile(rb"(?<![A-Za-z0-9])sk_[A-Za-z0-9_-]{20,}\b")),
    ("jwt-token", re.compile(rb"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b")),
    ("bearer-credential", re.compile(rb"(?i)\bBearer\s+[A-Za-z0-9._~+/-]{20,}")),
)

ASSIGNMENT = re.compile(
    rb"(?im)^[ \t]*(?:export[ \t]+)?[A-Z][A-Z0-9_]*(?:SECRET|PASSWORD|PRIVATE_KEY|TOKEN)"
    rb"[A-Z0-9_]*[ \t]*[:=][ \t]*[\"']?([A-Za-z0-9+/=_-]{20,})"
)
DOCUMENTED_PLACEHOLDERS = {
    b"CHANGEME_MINIO_SECRET_KEY",
    b"CHANGEME_GENERATE_32_PLUS_BYTES_HERE",
}
def detect(data: bytes) -> list[tuple[str, int]]:
    findings: list[tuple[str, int]] = []
    for detector_id, pattern in DETECTORS:
        for match in pattern.finditer(data):
            findings.append((detector_id, data.count(b"\n", 0, match.start()) + 1))
    for match in ASSIGNMENT.finditer(data):
        value = match.group(1)
        counts = collections.Counter(value)
        entropy = -sum((count / len(value)) * math.log2(count / len(value)) for count in counts.values())
        if value not in DOCUMENTED_PLACEHOLDERS and entropy >= 3.5:
            findings.append(("high-entropy-secret-assignment", data.count(b"\n", 0, match.start()) + 1))
    return findings


def git_output(cwd: Path | str, *args: str) -> bytes:
    return subprocess.check_output(["git", *args], cwd=cwd)


def tracked_findings(cwd: Path | str = ".") -> list[tuple[str, str, int]]:
    paths = git_output(cwd, "ls-files", "-z").decode().split("\0")
    findings: list[tuple[str, str, int]] = []
    for path in filter(None, paths):
        candidate = Path(cwd, path)
        if candidate.is_symlink() or not candidate.is_file():
            continue
        data = candidate.read_bytes()
        findings.extend((detector_id, path, line) for detector_id, line in detect(data))
    return findings


def range_findings(git_range: str, cwd: Path | str = ".") -> list[tuple[str, str, int]]:
    if not re.fullmatch(r"[0-9a-fA-F]{7,40}\.\.[0-9a-fA-F]{7,40}", git_range):
        raise ValueError("git range must be two explicit commit SHAs")
    revisions = git_range.split("..")
    try:
        base, head = (
            subprocess.check_output(
                ["git", "rev-parse", "--verify", f"{revision}^{{commit}}"], cwd=cwd,
                stderr=subprocess.DEVNULL,
            ).decode().strip()
            for revision in revisions
        )
    except subprocess.CalledProcessError:
        raise ValueError("git range contains an unknown commit") from None
    findings: list[tuple[str, str, int]] = []
    for commit in git_output(cwd, "rev-list", "--topo-order", f"{base}..{head}").decode().splitlines():
        changed = set(filter(None, git_output(
            cwd, "diff-tree", "--root", "-m", "--no-commit-id", "--name-only",
            "--no-renames", "-r", "-z", commit,
        ).split(b"\0")))
        for entry in filter(None, git_output(cwd, "ls-tree", "-r", "-z", commit).split(b"\0")):
            metadata, path = entry.split(b"\t", 1)
            _, kind, object_id = metadata.split()
            if kind != b"blob" or path not in changed:
                continue
            data = git_output(cwd, "cat-file", "blob", object_id.decode())
            decoded_path = path.decode("utf-8", "replace")
            findings.extend((detector_id, decoded_path, line) for detector_id, line in detect(data))
    return findings


def self_test() -> None:
    secret = b"sk_" + b"A1b2" * 7
    public_key = b"appl_" + b"A1b2" * 7
    jwt = b"eyJ" + b"A" * 12 + b"." + b"B" * 12 + b"." + b"C" * 12
    assignment = b"WEBHOOK_TOKEN=" + b"A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6"
    ids = {detector_id for detector_id, _ in detect(secret + b"\n" + jwt + b"\n" + assignment)}
    assert {"secret-key-prefix", "jwt-token", "high-entropy-secret-assignment"}.issubset(ids)
    assert not detect(public_key)
    assert not detect(b"MINIO_SECRET_KEY=CHANGEME_MINIO_SECRET_KEY")
    for marker in (b"test", b"your"):
        assert any(item[0] == "high-entropy-secret-assignment" for item in detect(b"WEBHOOK_TOKEN=A1b2C3d4" + marker + b"E5f6G7h8I9j0K1l2M3n4"))
    assert "secret-key-prefix" in {detector_id for detector_id, _ in detect(b"\0" + secret + b"\0")}
    print("pattern and binary/NUL self-tests passed")

    with tempfile.TemporaryDirectory() as temporary_directory:
        repo = Path(temporary_directory)
        def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[bytes]:
            return subprocess.run(
                ["git", *args], cwd=repo, check=check,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
        run("init", "-q")
        run("config", "user.name", "Secret Scanner Test")
        run("config", "user.email", "scanner@example.invalid")
        (repo / "conflict.txt").write_text("base\n")
        run("add", "--", "conflict.txt"); run("commit", "-qm", "base")
        base = git_output(repo, "rev-parse", "HEAD").decode().strip()

        def branch_commit(branch: str, path: str, data: bytes) -> str:
            run("checkout", "-q", base); run("checkout", "-qb", branch)
            (repo / path).write_bytes(data); run("add", "--", path); run("commit", "-qm", branch)
            return git_output(repo, "rev-parse", "HEAD").decode().strip()

        normal = branch_commit("normal", "credential.txt", secret + b"\n")
        assert any(item[0] == "secret-key-prefix" for item in range_findings(f"{base}..{normal}", repo))
        binary = branch_commit("binary", "credential.bin", b"\0" + secret + b"\0")
        assert any(item[0] == "secret-key-prefix" for item in range_findings(f"{base}..{binary}", repo))
        branch_commit("left", "conflict.txt", b"left\n")
        branch_commit("right", "conflict.txt", b"right\n")
        run("checkout", "-q", "left")
        assert run("merge", "--no-ff", "--no-commit", "right", check=False).returncode != 0
        (repo / "conflict.txt").write_bytes(secret + b"\n")
        run("add", "--", "conflict.txt"); run("commit", "-qm", "merge resolution")
        merged = git_output(repo, "rev-parse", "HEAD").decode().strip()
        assert any(item[0] == "secret-key-prefix" for item in range_findings(f"{base}..{merged}", repo))
        for invalid_range in (f"{base}..{merged};touch", f"{'0' * 40}..{merged}"):
            try:
                range_findings(invalid_range, repo)
            except ValueError:
                continue
            raise AssertionError("invalid range was accepted")
    print("normal, binary, merge-resolution, and invalid-range self-tests passed")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--git-range")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    findings = range_findings(args.git_range) if args.git_range else tracked_findings()
    if not findings:
        print("secret scan passed")
        return 0
    print(f"secret scan failed: {len(findings)} redacted finding(s)", file=sys.stderr)
    for detector_id, path, line in sorted(set(findings)):
        print(f"{detector_id}\t{path}:{line}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
