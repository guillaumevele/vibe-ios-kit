"""Tests for vibe-ios-doctor: it must catch real violations AND stay green on
the kit's own (correct) templates."""
import importlib.util
from importlib.machinery import SourceFileLoader
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent
_loader = SourceFileLoader("doctor", str(_ROOT / "bin" / "vibe-ios-doctor"))
_spec = importlib.util.spec_from_loader("doctor", _loader)
doctor = importlib.util.module_from_spec(_spec)
_loader.exec_module(doctor)


def _tiers(findings):
    return {f.tier for f in findings}


def test_emoji_in_source_fails():
    findings = doctor.lint_text("X.swift", 'let label = "Done \U0001F389"\n')
    assert any(f.tier == 1 and "emoji" in f.message for f in findings)


def test_unchecked_sendable_without_invariant_fails():
    findings = doctor.lint_text("X.swift", "final class C: @unchecked Sendable {}\n")
    assert any(f.tier == 1 and "Sendable" in f.message for f in findings)


def test_unchecked_sendable_with_invariant_passes():
    src = "// invariant: only touched on the main actor\nfinal class C: @unchecked Sendable {}\n"
    findings = doctor.lint_text("X.swift", src)
    assert not any("Sendable" in f.message for f in findings)


def test_formatter_in_body_fails():
    src = "struct V: View {\n    var body: some View {\n        Text(DateFormatter().string(from: .now))\n    }\n}\n"
    findings = doctor.lint_text("X.swift", src)
    assert any(f.tier == 1 and "DateFormatter" in f.message for f in findings)


def test_ungated_timeline_warns():
    src = "struct V: View {\n    var body: some View {\n        TimelineView(.animation) { _ in Color.red }\n    }\n}\n"
    findings = doctor.lint_text("X.swift", src)
    assert any(f.tier == 2 and "ungated" in f.message for f in findings)


def test_gated_timeline_passes():
    src = ("struct V: View {\n    @Environment(\\.scenePhase) var scenePhase\n"
           "    var body: some View {\n        TimelineView(.animation) { _ in Color.red }\n    }\n}\n")
    findings = doctor.lint_text("X.swift", src)
    assert not any(f.tier == 2 for f in findings)


def test_substring_guard_token_does_not_suppress():
    # `isActiveSubscription` contains `isActive` but must NOT count as a guard:
    # this is the VeraOrbV4 shape and must be flagged.
    src = ("struct Orb: View {\n    @State private var isActiveSubscription = true\n"
           "    var body: some View {\n        TimelineView(.animation) { _ in Color.red }\n"
           "            .repeatForever(autoreverses: true)\n    }\n}\n")
    findings = doctor.lint_text("X.swift", src)
    assert any(f.tier == 2 for f in findings), "substring token wrongly suppressed the warning"


def test_guard_token_in_comment_does_not_suppress():
    src = ("struct Orb: View {\n    // we used to gate this on scenePhase\n"
           "    var body: some View {\n        TimelineView(.animation) { _ in Color.red }\n    }\n}\n")
    findings = doctor.lint_text("X.swift", src)
    assert any(f.tier == 2 for f in findings), "a guard token in a comment wrongly suppressed it"


def test_parameter_gated_leaf_passes():
    # A leaf view gated by a passed-in Bool is correct — must NOT be flagged
    # (the parent owns the gate). Avoids false positives under --strict.
    src = ("struct Halo: View {\n    let active: Bool\n    var body: some View {\n"
           "        if active { TimelineView(.animation) { _ in Color.red } }\n    }\n}\n")
    findings = doctor.lint_text("X.swift", src)
    assert not any(f.tier == 2 for f in findings)


def test_multiline_trigger_is_detected():
    src = ("struct Orb: View {\n    var body: some View {\n        TimelineView(\n"
           "            .animation\n        ) { _ in Color.red }\n    }\n}\n")
    findings = doctor.lint_text("X.swift", src)
    assert any(f.tier == 2 for f in findings), "multi-line TimelineView(.animation) evaded detection"


def test_emoji_in_comment_is_flagged():
    findings = doctor.lint_text("X.swift", "// shipped ⭐\nlet x = 1\n")
    assert any(f.tier == 1 and "emoji" in f.message for f in findings)


def test_kit_templates_are_clean():
    findings = []
    for f in (_ROOT / "templates").glob("*.swift"):
        findings += doctor.lint_text(str(f), f.read_text())
    assert findings == [], [x.format() for x in findings]


def test_run_exits_1_on_bad_fixture():
    bad = _ROOT / "tests" / "fixtures" / "bad.swift"
    assert doctor.run([str(bad)], strict=False) == 1   # tier-1 fails -> exit 1


def test_run_exits_2_on_missing_path():
    assert doctor.run(["/no/such/path/Sources"], strict=False) == 2


def test_run_survives_non_utf8_file(tmp_path):
    # Real codebases contain the odd non-UTF-8 byte; the run must not crash.
    bad = tmp_path / "Weird.swift"
    bad.write_bytes(b"struct V {}\n// caf\xe9 latin-1 byte\n")
    assert doctor.run([str(tmp_path)], strict=False) == 0


def test_run_clean_on_templates():
    assert doctor.run([str(_ROOT / "templates")], strict=True) == 0
