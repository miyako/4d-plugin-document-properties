"""Unsigned macOS engine-boundary regressions; never builds/publishes a bundle."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[2]
BASELINE = "697c8694a9534914f6fc5a30466c64a944f4f01a"
FAILURES = {
    "path": "double disposal of transferred path string",
    "bytes": "all owned strings, handles and picture refs released",
    "copy": "AddressSanitizer: heap-buffer-overflow",
    "copy-empty": "all owned strings, handles and picture refs released",
    "gray": "all owned strings, handles and picture refs released",
    "size": "all owned strings, handles and picture refs released",
    "thumbnail": "all owned strings, handles and picture refs released",
}
CASES = (*FAILURES, "arrays", "scalars")


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", action="store_true",
                        help="Require named defects in immutable baseline to fail")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="document-properties-ownership-") as directory:
        work = Path(directory)
        source = ROOT
        if args.baseline:
            source = work / "baseline"
            source.mkdir()
            archive = subprocess.run(
                ["git", "-C", str(ROOT), "archive", BASELINE],
                check=True, stdout=subprocess.PIPE,
            )
            subprocess.run(["tar", "-xf", "-", "-C", str(source)],
                           input=archive.stdout, check=True)
        sdk = source / "4D Plugin API"
        binary = work / "native-ownership"
        subprocess.run([
            "xcrun", "clang++", "-std=c++11", "-x", "objective-c++",
            "-include", "Carbon/Carbon.h", "-Wno-deprecated-declarations",
            "-fsanitize=address,undefined", "-fno-sanitize=alignment",
            "-fno-omit-frame-pointer", "-g",
            "-I", str(sdk), "-I", str(sdk / "Classes"),
            str(ROOT / ".github/tests/native_ownership.mm"),
            str(source / "4DPlugin.cpp"), str(sdk / "4DPluginAPI.c"),
            *map(str, sorted((sdk / "Classes").glob("*.cpp"))),
            "-framework", "Cocoa", "-framework", "Carbon", "-o", str(binary),
        ], check=True)
        env = dict(os.environ, ASAN_OPTIONS="detect_leaks=0:abort_on_error=1",
                   UBSAN_OPTIONS="halt_on_error=1")
        for case in CASES:
            for representation in ("allocated-empty", "null-empty"):
                result = subprocess.run([str(binary), case, representation],
                                        env=env, text=True, capture_output=True)
                expected_failure = args.baseline and case in FAILURES
                if expected_failure:
                    evidence = result.stdout + result.stderr
                    # Null empty strings allocate nothing, but copy-empty still
                    # leaks the overwritten initial picture on the baseline.
                    if result.returncode == 0 or FAILURES[case] not in evidence:
                        raise AssertionError(f"{case}: missing baseline defect\n{evidence}")
                    print(f"EXPECTED BASELINE FAILURE {case} ({representation})")
                    print(evidence[:1600])
                else:
                    if result.returncode:
                        raise AssertionError(result.stdout + result.stderr)
                    print(result.stdout.strip())


if __name__ == "__main__":
    run()
