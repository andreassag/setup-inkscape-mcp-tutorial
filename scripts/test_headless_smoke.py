#!/usr/bin/env python3
"""
Smoke test for inkscape-mcp installation and headless operation.
Used by CI to verify that inkscape-mcp installs and functions headlessly
across Ubuntu, macOS, and Windows.
"""
import asyncio
import os
import sys

# Ensure UTF-8 output across all operating systems and consoles
if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def main() -> int:
    print("=== Testing inkscape_mcp installation and headless operation ===")

    # 1. Test module import
    try:
        import inkscape_mcp
        from inkscape_mcp.main import InkscapeMCPServer

        print(f"[OK] Successfully imported inkscape_mcp from: {inkscape_mcp.__file__}")
    except ImportError as e:
        print(f"[FAIL] Failed to import inkscape_mcp: {e}", file=sys.stderr)
        return 1

    # 2. Test server initialization and Inkscape detection
    print("\n--- Initializing InkscapeMCPServer ---")
    server = InkscapeMCPServer()
    init_ok = asyncio.run(server.initialize())
    if not init_ok:
        print("[FAIL] Server initialization returned False", file=sys.stderr)
        return 1
    print("[OK] Server initialized successfully")

    inkscape_bin = server.config.inkscape_executable
    print(f"Detected Inkscape binary: {inkscape_bin}")
    if not inkscape_bin or not server.cli_wrapper:
        print("[FAIL] Inkscape binary not detected or CLI wrapper not available", file=sys.stderr)
        return 1
    print("[OK] Inkscape CLI wrapper active")

    # 3. Test headless vector export
    print("\n--- Testing headless vector export ---")
    test_svg = os.path.abspath("test_smoke.svg")
    test_png = os.path.abspath("test_smoke.png")

    try:
        with open(test_svg, "w", encoding="utf-8") as f:
            f.write(
                '<svg width="100" height="100" xmlns="http://www.w3.org/2000/svg">\n'
                '  <rect width="100" height="100" fill="#10b981" rx="15"/>\n'
                "</svg>\n"
            )
        print(f"Created temporary SVG at {test_svg}")

        out_path = asyncio.run(
            server.cli_wrapper.export_file(
                input_path=test_svg,
                output_path=test_png,
                export_type="png",
                dpi=96,
            )
        )
        if not os.path.exists(test_png) or os.path.getsize(test_png) == 0:
            print(f"[FAIL] Exported PNG does not exist or is empty: {test_png}", file=sys.stderr)
            return 1

        print(f"[OK] Headless export verified: {out_path} ({os.path.getsize(test_png)} bytes)")
    except Exception as e:
        print(f"[FAIL] Headless export failed: {e}", file=sys.stderr)
        return 1
    finally:
        for f in (test_svg, test_png):
            if os.path.exists(f):
                try:
                    os.remove(f)
                except OSError:
                    pass

    print("\n[OK] All headless smoke tests passed successfully!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
