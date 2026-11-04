import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPTS_DIR = REPO_ROOT / "scripts"


class FactoryScriptsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = Path(tempfile.mkdtemp(prefix="sf-test-"))
        subprocess.run(["git", "init", "-b", "main"], cwd=self.temp_dir, check=True, capture_output=True)
        subprocess.run(["git", "config", "user.email", "test@example.com"], cwd=self.temp_dir, check=True)
        subprocess.run(["git", "config", "user.name", "Factory Test"], cwd=self.temp_dir, check=True)

        # Populate minimal required factory structure in temp repo
        for rel in [
            "AGENTS.md",
            "CHECKPOINTS.md",
            "README.md",
            "Makefile",
            "feature_list.json",
            ".atl/skill-registry.md",
            ".agents/skills/leader/SKILL.md",
            ".agents/skills/explorer/SKILL.md",
            ".agents/skills/implementer/SKILL.md",
            ".agents/skills/reviewer/SKILL.md",
            "contracts/openapi.yaml",
            ".github/PULL_REQUEST_TEMPLATE.md",
        ]:
            target = self.temp_dir / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            if rel.endswith(".json"):
                target.write_text('{"schema_version": 2}\n', encoding="utf-8")
            else:
                target.write_text(f"# {rel}\n", encoding="utf-8")

        subprocess.run(["git", "add", "."], cwd=self.temp_dir, check=True)
        subprocess.run(["git", "commit", "-m", "chore: base commit"], cwd=self.temp_dir, check=True, capture_output=True)

    def tearDown(self) -> None:
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    def test_preflight_passes_on_valid_repo_and_fails_when_dirty_or_missing_files(self) -> None:
        script = SCRIPTS_DIR / "factory_preflight.py"
        self.assertTrue(script.is_file(), f"Missing script: {script}")

        # Clean valid repo passes with --require-clean
        res = subprocess.run(
            [sys.executable, str(script), "--root", str(self.temp_dir), "--require-clean", "--json"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, msg=res.stderr or res.stdout)
        payload = json.loads(res.stdout)
        self.assertEqual(payload["status"], "PREFLIGHT_OK_NOT_VERIFIED")
        self.assertTrue(payload["clean_working_tree"])

        # Dirty working tree fails --require-clean
        (self.temp_dir / "untracked.txt").write_text("dirty\n", encoding="utf-8")
        res_dirty = subprocess.run(
            [sys.executable, str(script), "--root", str(self.temp_dir), "--require-clean"],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res_dirty.returncode, 0)

        # Missing required file fails preflight
        (self.temp_dir / "untracked.txt").unlink()
        (self.temp_dir / "CHECKPOINTS.md").unlink()
        res_missing = subprocess.run(
            [sys.executable, str(script), "--root", str(self.temp_dir)],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res_missing.returncode, 0)

    def test_check_pr_metadata_enforces_fail_closed_contract(self) -> None:
        script = SCRIPTS_DIR / "check_pr_metadata.py"
        self.assertTrue(script.is_file(), f"Missing script: {script}")

        valid_body = "\n".join(
            [
                "Closes #42",
                "Delivery: complete",
                "",
                "## Summary",
                "- Implemented health endpoint contract and handler.",
                "",
                "## Decisions Made Without Asking",
                "- Used standard RFC 9457 ProblemDetails error shape.",
                "",
                "## Verification Evidence",
                "- `make test`: PASS",
                "",
                "## Clean-Context Review Handoff",
                f"- **Base SHA**: `{'a' * 40}`",
                f"- **Head SHA**: `{'b' * 40}`",
                f"- **Scope Digest (SHA-256)**: `{'c' * 64}`",
                "- **Independent Reviewer Verdict**: `APPROVED`",
                "",
                "## Risk",
                "Risk: none",
            ]
        )
        body_file = self.temp_dir / "pr_body.md"
        body_file.write_text(valid_body, encoding="utf-8")

        res_ok = subprocess.run(
            [sys.executable, str(script), "--body-file", str(body_file)],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res_ok.returncode, 0, msg=res_ok.stderr or res_ok.stdout)

        # Mismatched Refs #42 with Delivery: complete must fail
        invalid_mismatch = valid_body.replace("Closes #42", "Refs #42", 1)
        body_file.write_text(invalid_mismatch, encoding="utf-8")
        res_mismatch = subprocess.run(
            [sys.executable, str(script), "--body-file", str(body_file)],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res_mismatch.returncode, 0)

        # Missing Risk line must fail
        invalid_no_risk = valid_body.replace("Risk: none", "No risk at all")
        body_file.write_text(invalid_no_risk, encoding="utf-8")
        res_no_risk = subprocess.run(
            [sys.executable, str(script), "--body-file", str(body_file)],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res_no_risk.returncode, 0)

    def test_factory_handoff_generates_stateless_clean_context_bundle_and_detects_high_risk(self) -> None:
        script = SCRIPTS_DIR / "factory_handoff.py"
        self.assertTrue(script.is_file(), f"Missing script: {script}")

        base_sha = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=self.temp_dir, text=True
        ).strip()

        # Modify OpenAPI contract to trigger high-risk / judgment-day flag
        (self.temp_dir / "contracts/openapi.yaml").write_text(
            "openapi: 3.1.0\ninfo:\n  title: Test\n  version: 0.2.0\n", encoding="utf-8"
        )
        subprocess.run(["git", "add", "contracts/openapi.yaml"], cwd=self.temp_dir, check=True)
        subprocess.run(
            ["git", "commit", "-m", "feat(contracts): bump openapi version"],
            cwd=self.temp_dir,
            check=True,
            capture_output=True,
        )
        head_sha = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=self.temp_dir, text=True
        ).strip()

        out_json = self.temp_dir / "bundle.json"
        out_md = self.temp_dir / "bundle.md"
        res = subprocess.run(
            [
                sys.executable,
                str(script),
                "--root",
                str(self.temp_dir),
                "--base",
                base_sha,
                "--head",
                head_sha,
                "--issue",
                "42",
                "--acceptance",
                "S1: contract version is bumped",
                "--verification-note",
                "V1 unit suite passed",
                "--output-json",
                str(out_json),
                "--output-md",
                str(out_md),
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, msg=res.stderr or res.stdout)
        self.assertTrue(out_json.is_file())
        self.assertTrue(out_md.is_file())

        bundle = json.loads(out_json.read_text(encoding="utf-8"))
        self.assertEqual(bundle["issue"], 42)
        self.assertEqual(bundle["base_sha"], base_sha)
        self.assertEqual(bundle["head_sha"], head_sha)
        self.assertIn("contracts/openapi.yaml", bundle["changed_files"])
        self.assertTrue(bundle["judgment_day_required"])
        self.assertEqual(len(bundle["scope_sha256"]), 64)
        self.assertNotIn("chat_history", bundle)
        self.assertNotIn("implementer_rationale", bundle)

    def test_init_project_scaffolds_selected_topology_and_rejects_invalid_options(self) -> None:
        script = SCRIPTS_DIR / "init-project.sh"
        self.assertTrue(script.is_file(), f"Missing script: {script}")

        res = subprocess.run(
            [
                "bash",
                str(script),
                "--root",
                str(self.temp_dir),
                "--name",
                "orbital-erp",
                "--db",
                "postgres",
                "--surfaces",
                "backend,web,desktop-tauri,ios-native",
            ],
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, msg=res.stderr or res.stdout)

        manifest_path = self.temp_dir / "factory.manifest.json"
        self.assertTrue(manifest_path.is_file())
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        self.assertEqual(manifest["project_name"], "orbital-erp")
        self.assertEqual(manifest["database"], "postgres")
        self.assertEqual(
            manifest["surfaces"],
            ["backend", "web", "desktop-tauri", "ios-native"],
        )

        # Verify ADR-0000 and selected surface Makefiles were created
        self.assertTrue((self.temp_dir / "docs/architecture/adr/ADR-0000-project-topology.md").is_file())
        self.assertTrue((self.temp_dir / "backend/Makefile").is_file())
        self.assertTrue((self.temp_dir / "apps/web/Makefile").is_file())
        self.assertTrue((self.temp_dir / "apps/desktop/Makefile").is_file())
        self.assertTrue((self.temp_dir / "apps/ios/Makefile").is_file())
        self.assertFalse((self.temp_dir / "apps/android/Makefile").exists())

        # Invalid DB must fail closed
        res_bad_db = subprocess.run(
            [
                "bash",
                str(script),
                "--root",
                str(self.temp_dir),
                "--name",
                "orbital-erp",
                "--db",
                "oracle-db",
                "--surfaces",
                "backend",
            ],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res_bad_db.returncode, 0)


class ContractsGateTest(unittest.TestCase):
    """The contract gate (C2) must fail closed and match scaffolded paths."""

    def test_contracts_lint_fails_closed_when_spectral_runner_is_unavailable(self) -> None:
        res = subprocess.run(
            ["make", "-C", str(REPO_ROOT / "contracts"), "lint", "NPX=/nonexistent/npx"],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res.returncode, 0, msg="lint must not pass without Spectral")

    def test_contracts_diff_fails_closed_when_oasdiff_is_unavailable(self) -> None:
        res = subprocess.run(
            [
                "make",
                "-C",
                str(REPO_ROOT / "contracts"),
                "diff",
                "BASE=HEAD",
                "GO=/nonexistent/go",
            ],
            capture_output=True,
            text=True,
        )
        self.assertNotEqual(res.returncode, 0, msg="diff must not pass without oasdiff")

    def test_contracts_generate_paths_match_scaffolded_native_surfaces(self) -> None:
        makefile = (REPO_ROOT / "contracts" / "Makefile").read_text(encoding="utf-8")
        init_script = (REPO_ROOT / "scripts" / "init-project.sh").read_text(encoding="utf-8")
        self.assertNotIn("apps/ios-native", makefile)
        self.assertNotIn("apps/android-native", makefile)
        self.assertIn("apps/ios", init_script)
        self.assertIn("apps/android", init_script)
        self.assertIn("apps/ios/", makefile)
        self.assertIn("apps/android/", makefile)


class PrTemplateTest(unittest.TestCase):
    def test_pr_template_includes_rollback_commits_and_ux_evidence_sections(self) -> None:
        template = (REPO_ROOT / ".github" / "PULL_REQUEST_TEMPLATE.md").read_text(encoding="utf-8")
        for heading in ("## Commits (Work Units)", "## Rollback", "## Visual Evidence"):
            self.assertIn(heading, template)

    def _check(self, body: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPTS_DIR / "check_pr_metadata.py"), "--body", body],
            capture_output=True,
            text=True,
        )

    def test_unedited_pr_template_is_rejected(self) -> None:
        template = (REPO_ROOT / ".github" / "PULL_REQUEST_TEMPLATE.md").read_text(encoding="utf-8")
        res = self._check(template)
        self.assertNotEqual(res.returncode, 0, msg="placeholder template must not pass C5")

    def test_filled_pr_template_satisfies_metadata_contract(self) -> None:
        template = (REPO_ROOT / ".github" / "PULL_REQUEST_TEMPLATE.md").read_text(encoding="utf-8")
        filled = (
            template.replace("#<issue>", "#42")
            .replace("<base_sha>", "a" * 40)
            .replace("<head_sha>", "b" * 40)
            .replace("<scope_sha256>", "c" * 64)
            .replace("<APPROVED | CHANGES_REQUESTED | BLOCKED>", "APPROVED")
        )
        res = self._check(filled)
        self.assertEqual(res.returncode, 0, msg=res.stderr or res.stdout)


class PrMetadataReviewGateTest(unittest.TestCase):
    """C5 must mechanically prove that C4 happened."""

    def _body(self, **overrides: str) -> str:
        values = {
            "line1": "Closes #42",
            "base": "a" * 40,
            "head": "b" * 40,
            "digest": "c" * 64,
            "verdict": "APPROVED",
        }
        values.update(overrides)
        return "\n".join(
            [
                values["line1"],
                "Delivery: complete",
                "## Summary",
                "- x",
                "## Decisions Made Without Asking",
                "- None",
                "## Verification Evidence",
                "- `make test`: PASS",
                "## Clean-Context Review Handoff",
                f"- **Base SHA**: `{values['base']}`",
                f"- **Head SHA**: `{values['head']}`",
                f"- **Scope Digest (SHA-256)**: `{values['digest']}`",
                f"- **Independent Reviewer Verdict**: `{values['verdict']}`",
                "## Risk",
                "Risk: none",
            ]
        )

    def _check(self, body: str) -> int:
        return subprocess.run(
            [sys.executable, str(SCRIPTS_DIR / "check_pr_metadata.py"), "--body", body],
            capture_output=True,
            text=True,
        ).returncode

    def test_valid_review_handoff_passes(self) -> None:
        self.assertEqual(self._check(self._body()), 0)

    def test_issue_zero_is_rejected(self) -> None:
        self.assertNotEqual(self._check(self._body(line1="Closes #0")), 0)

    def test_placeholder_or_short_shas_are_rejected(self) -> None:
        self.assertNotEqual(self._check(self._body(base="<base_sha>")), 0)
        self.assertNotEqual(self._check(self._body(head="def5678")), 0)
        self.assertNotEqual(self._check(self._body(digest="<scope_sha256>")), 0)

    def test_non_approved_verdict_is_rejected(self) -> None:
        self.assertNotEqual(self._check(self._body(verdict="CHANGES_REQUESTED")), 0)
        self.assertNotEqual(self._check(self._body(verdict="<APPROVED | CHANGES_REQUESTED | BLOCKED>")), 0)


class HandoffBundleTest(unittest.TestCase):
    """C4 bundle must be complete, fail closed, and classify risk precisely."""

    def setUp(self) -> None:
        self.repo = Path(tempfile.mkdtemp(prefix="sf-handoff-"))
        for cmd in (
            ["git", "init", "-b", "main"],
            ["git", "config", "user.email", "test@example.com"],
            ["git", "config", "user.name", "Factory Test"],
        ):
            subprocess.run(cmd, cwd=self.repo, check=True, capture_output=True)
        (self.repo / "README.md").write_text("# base\n", encoding="utf-8")
        self._commit("chore: base")
        self.base = self._sha()

    def tearDown(self) -> None:
        shutil.rmtree(self.repo, ignore_errors=True)

    def _sha(self) -> str:
        return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=self.repo, text=True).strip()

    def _commit(self, message: str) -> None:
        subprocess.run(["git", "add", "-A"], cwd=self.repo, check=True)
        subprocess.run(["git", "commit", "-m", message], cwd=self.repo, check=True, capture_output=True)

    def _write(self, rel: str, content: str = "x\n") -> None:
        target = self.repo / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")

    def _run(self, *extra: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPTS_DIR / "factory_handoff.py"),
                "--root",
                str(self.repo),
                "--base",
                self.base,
                "--head",
                "HEAD",
                "--issue",
                "7",
                *extra,
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

    def test_documented_out_flag_writes_markdown_with_full_diff(self) -> None:
        self._write("internal/app/service.go", "package app\n// UNIQUE_DIFF_MARKER\n")
        self._commit("feat: service")
        out = self.repo.parent / f"{self.repo.name}-bundle.md"
        res = self._run("--acceptance", "S1: service exists", "--verification-note", "go test PASS", "--out", str(out))
        self.assertEqual(res.returncode, 0, msg=res.stderr or res.stdout)
        md = out.read_text(encoding="utf-8")
        out.unlink()
        self.assertIn("UNIQUE_DIFF_MARKER", md)
        self.assertIn("```diff", md)
        self.assertIn("S1: service exists", md)
        self.assertIn("go test PASS", md)

    def test_missing_acceptance_source_blocks(self) -> None:
        self._write("internal/app/service.go")
        self._commit("feat: service")
        res = self._run("--verification-note", "go test PASS")
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("HANDOFF_BLOCKED", res.stderr)

    def test_missing_verification_evidence_blocks(self) -> None:
        self._write("internal/app/service.go")
        self._commit("feat: service")
        res = self._run("--acceptance", "S1: service exists")
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("HANDOFF_BLOCKED", res.stderr)

    def test_task_file_supplies_acceptance_and_allowed_surfaces(self) -> None:
        self._write(
            "odd/tasks/7-service.md",
            "# ODD Feature\n\n## Specs\n- **S1**: service exists\n\n"
            "## Allowed edit surfaces\n- `internal/app/**`\n- `odd/tasks/7-service.md`\n\n## Log\n",
        )
        self._write("internal/app/service.go")
        self._write("web/src/App.tsx")
        self._commit("feat: service")
        out_json = self.repo.parent / f"{self.repo.name}-bundle.json"
        evidence = self.repo.parent / f"{self.repo.name}-evidence.txt"
        evidence.write_text("ok  internal/app  0.01s\n", encoding="utf-8")
        res = self._run("--verification-file", str(evidence), "--output-json", str(out_json))
        evidence.unlink()
        self.assertEqual(res.returncode, 0, msg=res.stderr or res.stdout)
        bundle = json.loads(out_json.read_text(encoding="utf-8"))
        out_json.unlink()
        self.assertIn("S1", bundle["acceptance_criteria"])
        self.assertEqual(bundle["allowed_edit_surfaces"], ["internal/app/**", "odd/tasks/7-service.md"])
        self.assertEqual(bundle["out_of_scope_files"], ["web/src/App.tsx"])
        self.assertIn("internal/app", bundle["verification_evidence"])

    def test_high_risk_detection_has_no_substring_false_positives(self) -> None:
        sys.path.insert(0, str(SCRIPTS_DIR))
        try:
            from factory_handoff import detect_high_risk_triggers
        finally:
            sys.path.pop(0)
        benign = [
            "apps/web/package-lock.json",
            "apps/web/src/components/Block.tsx",
            "apps/web/src/utils/clock.ts",
            "AUTHORS.md",
            "apps/web/src/design/tokens.css",
        ]
        self.assertEqual(detect_high_risk_triggers(benign), [])
        risky = [
            "apps/desktop/src-tauri/capabilities/default.json",
            "apps/desktop/src-tauri/tauri.conf.json",
            "CHECKPOINTS.md",
            "backend/internal/auth/middleware.go",
            "apps/web/src/services/AuthService.ts",
            "backend/migrations/0001_init.sql",
            "contracts/openapi.yaml",
            "scripts/factory_handoff.py",
            ".github/workflows/ci.yml",
            "docs/architecture/adr/ADR-0004-x.md",
        ]
        flagged = detect_high_risk_triggers(risky)
        for path in risky:
            self.assertTrue(any(path in t for t in flagged), msg=f"not flagged: {path}")

    def test_diff_over_review_budget_triggers_judgment_day(self) -> None:
        self._write("internal/app/big.go", "".join(f"// line {i}\n" for i in range(401)))
        self._commit("feat: big")
        out_json = self.repo.parent / f"{self.repo.name}-big.json"
        res = self._run("--acceptance", "S1", "--verification-note", "PASS", "--output-json", str(out_json))
        self.assertEqual(res.returncode, 0, msg=res.stderr or res.stdout)
        bundle = json.loads(out_json.read_text(encoding="utf-8"))
        out_json.unlink()
        self.assertTrue(bundle["judgment_day_required"])
        self.assertTrue(any(t.startswith("size-exception") for t in bundle["high_risk_triggers"]))


class DocumentedCommandsTest(unittest.TestCase):
    """Every documented guardrail invocation must use flags the script accepts."""

    SCRIPTS = ("factory_handoff.py", "check_pr_metadata.py", "factory_preflight.py")
    FLAG_RE = re.compile(r"(?<![\w-])--[a-z][a-z0-9-]*")

    def _accepted_flags(self, script: str) -> set[str]:
        help_text = subprocess.run(
            [sys.executable, str(SCRIPTS_DIR / script), "--help"], capture_output=True, text=True, check=True
        ).stdout
        return set(self.FLAG_RE.findall(help_text))

    def _documented_invocations(self) -> list[tuple[str, str, str]]:
        files = [p for p in REPO_ROOT.rglob("*.md") if ".git" not in p.parts and "odd" not in p.parts]
        files += [REPO_ROOT / "Makefile", *(REPO_ROOT / ".github" / "workflows").glob("*.yml")]
        found: list[tuple[str, str, str]] = []
        for path in files:
            logical: list[str] = []
            buffer = ""
            for raw in path.read_text(encoding="utf-8").splitlines():
                if raw.rstrip().endswith("\\"):
                    buffer += raw.rstrip()[:-1] + " "
                    continue
                logical.append(buffer + raw)
                buffer = ""
            for line in logical:
                for script in self.SCRIPTS:
                    idx = line.find(f"scripts/{script}")
                    if idx != -1:
                        found.append((str(path.relative_to(REPO_ROOT)), script, line[idx:]))
        return found

    def test_documented_flags_exist_in_scripts(self) -> None:
        invocations = self._documented_invocations()
        self.assertTrue(invocations, "expected documented guardrail invocations")
        accepted = {script: self._accepted_flags(script) for script in self.SCRIPTS}
        for rel, script, command in invocations:
            for flag in self.FLAG_RE.findall(command.split("`")[0] if "`" in command else command):
                self.assertIn(flag, accepted[script], msg=f"{rel}: `{flag}` not accepted by {script}")


if __name__ == "__main__":
    unittest.main()
