"""The grader must pass the reference fixture on every check and fail the
negative witness on every check. Needs Xcode; skipped where xcrun is absent."""
import importlib.util
import shutil
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("grade", ROOT / "chonk" / "grade.py")
grade = importlib.util.module_from_spec(spec)
spec.loader.exec_module(grade)
FIX = ROOT / "chonk" / "tests" / "fixtures"

needs_xcode = pytest.mark.skipif(shutil.which("xcrun") is None, reason="needs Xcode")


@needs_xcode
def test_reference_fixture_passes_every_check():
    g = grade.grade_sources(FIX / "good")
    failed = [c for c, ok in g["checks"].items() if not ok]
    assert failed == [], (failed, g["details"])


@needs_xcode
def test_negative_witness_fails_every_check():
    g = grade.grade_sources(FIX / "bad")
    passed = [c for c, ok in g["checks"].items() if ok]
    assert passed == [], (passed, g["details"])


def test_blanking_ignores_comments_and_strings():
    code = grade.blank_noncode('let a = "NavigationView" // ObservableObject\n')
    assert "NavigationView" not in code and "ObservableObject" not in code


def test_icon_button_with_label_after_closure_is_accepted():
    ok = 'Button { go() } label: { Image(systemName: "plus") }\n    .accessibilityLabel("Add")\n'
    bad = 'Button { go() } label: { Image(systemName: "plus") }\n    .padding()\n'
    assert grade.unlabelled_icon_buttons(grade.blank_noncode(ok)) == []
    assert grade.unlabelled_icon_buttons(grade.blank_noncode(bad)) == [1]


def test_catch_that_only_prints_does_not_store_the_error():
    assert not grade.catch_stores_error("do { try f() } catch { print(error) }")
    assert grade.catch_stores_error("do { try f() } catch {\n state = .failed(error)\n}")
    assert not grade.catch_stores_error("do { try f() } catch {\n if a == b { log() }\n}")


@needs_xcode
def test_deprecated_api_that_still_compiles_is_caught():
    g = grade.grade_sources(FIX / "deprecated")
    assert g["checks"]["compiles_swift5"] is True
    assert g["checks"]["no_deprecation_warnings"] is False, g["details"]


def _chonk():
    s = importlib.util.spec_from_file_location("chonk", ROOT / "chonk" / "chonk.py")
    m = importlib.util.module_from_spec(s)
    s.loader.exec_module(m)
    return m


def test_extract_names_files_from_the_file_comment(tmp_path):
    reply = ("Here.\n```swift\n// FILE: A.swift\nlet a = 1\n```\n"
             "```swift\nlet b = 2\n```\n```swift\n// FILE: A.swift\nlet a = 3\n```\n")
    names = _chonk().extract(reply, tmp_path)
    assert names == ["A.swift", "File2.swift"]
    assert "let a = 3" in (tmp_path / "A.swift").read_text()


def test_bare_arm_sends_no_system_prompt(monkeypatch, tmp_path):
    c = _chonk()
    seen = {}

    def fake_chat(messages, seed):
        seen.setdefault("calls", []).append([m["role"] for m in messages])
        return "no code", {"prompt_tokens": 1, "completion_tokens": 1}

    monkeypatch.setattr(c, "chat", fake_chat)
    c.generate("Create an app.", "bare", 1, tmp_path / "bare")
    c.generate("Create an app.", "kit", 1, tmp_path / "kit")
    assert seen["calls"] == [["user"], ["system", "user"]]
