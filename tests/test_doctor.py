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


def test_kit_templates_are_clean():
    findings = []
    for f in (_ROOT / "templates").glob("*.swift"):
        findings += doctor.lint_text(str(f), f.read_text())
    assert findings == [], [x.format() for x in findings]
