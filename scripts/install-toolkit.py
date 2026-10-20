#!/usr/bin/env python3
"""
-----------------------------------------------------------------------------
Autor / Author: Ignacio Gutiérrez Serrera
GitHub: https://github.com/Ignacio0407 (@Ignacio0407)
Contact / Email: ignaciogutierrezserrera@gmail.com

⚡ Spring-React CRUD Toolkit & Accelerator
Automated Integration Script (Python)
-----------------------------------------------------------------------------
This script automates copying and integrating the toolkit's backend (main & test)
and frontend components into a target Spring Boot + React project.
It automatically refactors package declarations and imports to match the
target project's architecture.
"""

import os
import sys
import re
import shutil
import argparse
from pathlib import Path

# Safe UTF-8 configuration for Windows consoles
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# Terminal colors for pretty formatting
GREEN = "\033[92m"
CYAN = "\033[96m"
YELLOW = "\033[93m"
RED = "\033[91m"
BOLD = "\033[1m"
RESET = "\033[0m"


def print_banner():
    print(f"{CYAN}{BOLD}")
    print("=" * 70)
    print("  [+] Spring-React CRUD Toolkit - Project Integrator (Python)")
    print("  Author: Ignacio Gutiérrez Serrera (@Ignacio0407)")
    print("=" * 70)
    print(f"{RESET}")


def find_toolkit_root() -> Path:
    """Finds the root directory of spring-react-crud-toolkit."""
    script_path = Path(__file__).resolve()
    # Check if running from scripts/ or root
    if (script_path.parent / "backend" / "src" / "main" / "java" / "toolkit").exists():
        return script_path.parent
    if (script_path.parent.parent / "backend" / "src" / "main" / "java" / "toolkit").exists():
        return script_path.parent.parent
    # Fallback to current working directory
    cwd = Path.cwd()
    if (cwd / "backend" / "src" / "main" / "java" / "toolkit").exists():
        return cwd
    if (cwd / "spring-react-crud-toolkit" / "backend" / "src" / "main" / "java" / "toolkit").exists():
        return cwd / "spring-react-crud-toolkit"
    raise RuntimeError("Could not locate spring-react-crud-toolkit root directory.")


def list_sibling_projects(toolkit_root: Path) -> list[Path]:
    """Finds sibling directories in the same parent directory."""
    parent = toolkit_root.parent
    siblings = []
    for item in parent.iterdir():
        if item.is_dir() and item.name != toolkit_root.name and not item.name.startswith("."):
            # Prioritize projects with pom.xml, build.gradle, or package.json
            has_backend = (item / "pom.xml").exists() or (item / "backend" / "pom.xml").exists() or (item / "build.gradle").exists()
            has_frontend = (item / "package.json").exists() or (item / "frontend" / "package.json").exists()
            if has_backend or has_frontend or (item / "src").exists():
                siblings.append(item)
    return siblings


def detect_target_backend(target_dir: Path) -> tuple[Path, Path]:
    """Detects target main and test java source directories."""
    # Check Option 1: Multi-module or backend folder (target/backend/src/main/java)
    if (target_dir / "backend" / "src" / "main" / "java").exists():
        main_java = target_dir / "backend" / "src" / "main" / "java"
        test_java = target_dir / "backend" / "src" / "test" / "java"
        return main_java, test_java
    # Check Option 2: Standard layout (target/src/main/java)
    if (target_dir / "src" / "main" / "java").exists():
        main_java = target_dir / "src" / "main" / "java"
        test_java = target_dir / "src" / "test" / "java"
        return main_java, test_java
    raise FileNotFoundError(
        f"Could not find Java source directory in '{target_dir}'. "
        "Expected 'src/main/java' or 'backend/src/main/java'."
    )


def detect_target_base_package(main_java: Path) -> str | None:
    """Scans for @SpringBootApplication to detect base package."""
    for root, _, files in os.walk(main_java):
        for file in files:
            if file.endswith(".java"):
                file_path = Path(root) / file
                try:
                    content = file_path.read_text(encoding="utf-8")
                    if "@SpringBootApplication" in content:
                        match = re.search(r"^\s*package\s+([a-zA-Z0-9_.]+)\s*;", content, re.MULTILINE)
                        if match:
                            return match.group(1)
                except Exception:
                    continue
    return None


def transform_java_content(content: str, target_package: str) -> str:
    """Replaces toolkit package declarations and imports with the target package."""
    # 1. Package declarations:
    # package toolkit; -> package <target_package>;
    # package toolkit.controller; -> package <target_package>.controller;
    content = re.sub(
        r"^(\s*package\s+)toolkit(\b|(?=\.))",
        rf"\g<1>{target_package}",
        content,
        flags=re.MULTILINE,
    )

    # 2. Imports:
    # import toolkit.controller.BaseRestController; -> import <target_package>.controller.BaseRestController;
    # import static toolkit.xxx; -> import static <target_package>.xxx;
    content = re.sub(
        r"^(\s*import\s+(?:static\s+)?)toolkit(\b|(?=\.))",
        rf"\g<1>{target_package}",
        content,
        flags=re.MULTILINE,
    )

    # 3. Fully qualified code references to toolkit packages (controller, service, repository, etc.)
    content = re.sub(
        r"(?<=[^\w\.])toolkit\.(configuration|controller|exception|model|repository|security|service|user)",
        rf"{target_package}.\1",
        content,
    )

    return content


def copy_and_refactor_tree(
    src_toolkit_dir: Path,
    dst_root_dir: Path,
    target_package: str,
    dry_run: bool = False,
    force: bool = False,
) -> int:
    """Copies all Java files from src_toolkit_dir to dst_root_dir under target_package structure."""
    package_dir_rel = Path(*target_package.split("."))
    dst_package_dir = dst_root_dir / package_dir_rel

    count = 0
    for root, _, files in os.walk(src_toolkit_dir):
        for file in files:
            if not file.endswith(".java"):
                continue

            src_file = Path(root) / file
            rel_to_toolkit = src_file.relative_to(src_toolkit_dir)
            dst_file = dst_package_dir / rel_to_toolkit

            if dst_file.exists() and not force:
                print(f"  {YELLOW}[EXISTS]{RESET} {dst_file} (skipping, use --force to overwrite)")
                continue

            count += 1
            if dry_run:
                print(f"  {CYAN}[DRY-RUN]{RESET} Would copy: {src_file.name} -> {dst_file}")
                continue

            content = src_file.read_text(encoding="utf-8")
            transformed = transform_java_content(content, target_package)

            dst_file.parent.mkdir(parents=True, exist_ok=True)
            dst_file.write_text(transformed, encoding="utf-8")
            print(f"  {GREEN}[OK]{RESET} {rel_to_toolkit} -> {dst_file.relative_to(dst_root_dir)}")

    return count


def copy_test_resources(src_res: Path, dst_res: Path, dry_run: bool = False, force: bool = False):
    """Copies test application.properties if target does not have one."""
    src_props = src_res / "application.properties"
    if not src_props.exists():
        return

    dst_props = dst_res / "application.properties"
    if dst_props.exists() and not force:
        print(f"  {YELLOW}[EXISTS]{RESET} Test application.properties exists in target. Leaving untouched.")
        return

    if dry_run:
        print(f"  {CYAN}[DRY-RUN]{RESET} Would copy test application.properties -> {dst_props}")
        return

    dst_res.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src_props, dst_props)
    print(f"  {GREEN}[OK]{RESET} Copied test application.properties -> {dst_props}")


def copy_frontend_components(toolkit_root: Path, target_dir: Path, dry_run: bool = False, force: bool = False) -> int:
    """Copies frontend UI components and utilities to target frontend."""
    src_front = toolkit_root / "frontend" / "src"
    if not src_front.exists():
        print(f"  {YELLOW}[WARN]{RESET} Source frontend/src not found in toolkit.")
        return 0

    # Locate target frontend
    if (target_dir / "frontend" / "src").exists():
        dst_front = target_dir / "frontend" / "src"
    elif (target_dir / "src" / "components").exists() or (target_dir / "package.json").exists():
        dst_front = target_dir / "src"
    else:
        dst_front = target_dir / "frontend" / "src"

    count = 0
    folders_to_copy = ["components", "interfaces", "services", "util"]
    for folder in folders_to_copy:
        src_sub = src_front / folder
        if not src_sub.exists():
            continue
        dst_sub = dst_front / folder

        for root, _, files in os.walk(src_sub):
            for file in files:
                src_file = Path(root) / file
                rel = src_file.relative_to(src_front)
                dst_file = dst_front / rel

                if dst_file.exists() and not force:
                    continue

                count += 1
                if dry_run:
                    print(f"  {CYAN}[DRY-RUN]{RESET} Would copy frontend: {rel} -> {dst_file}")
                else:
                    dst_file.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src_file, dst_file)
                    print(f"  {GREEN}[OK]{RESET} Frontend: {rel}")

    return count


def main():
    print_banner()

    toolkit_root = find_toolkit_root()
    print(f"{BOLD}Source Toolkit:{RESET} {toolkit_root}")

    parser = argparse.ArgumentParser(
        description="Integrate spring-react-crud-toolkit into a downstream Spring Boot & React project."
    )
    parser.add_argument(
        "-t", "--target",
        help="Target project directory name or path (relative to parent or absolute).",
    )
    parser.add_argument(
        "-p", "--package",
        help="Target Java package name for toolkit classes (e.g. com.example.myapp.toolkit).",
    )
    parser.add_argument(
        "-f", "--include-frontend",
        action="store_true",
        help="Also copy React frontend components and utilities to the target project.",
    )
    parser.add_argument(
        "-s", "--skip-tests",
        action="store_true",
        help="Skip copying backend automated test suites.",
    )
    parser.add_argument(
        "-d", "--dry-run",
        action="store_true",
        help="Preview changes without modifying any files.",
    )
    parser.add_argument(
        "-y", "--force",
        action="store_true",
        help="Overwrite files without prompt.",
    )
    parser.add_argument(
        "--non-interactive",
        action="store_true",
        help="Disable interactive menus and prompts.",
    )

    args = parser.parse_args()

    # Determine target project directory
    target_dir: Path | None = None
    if args.target:
        candidate = Path(args.target)
        if candidate.is_absolute() and candidate.exists():
            target_dir = candidate
        elif (toolkit_root.parent / args.target).exists():
            target_dir = toolkit_root.parent / args.target
        elif candidate.exists():
            target_dir = candidate.resolve()
        else:
            print(f"{RED}Error: Target directory '{args.target}' not found.{RESET}")
            sys.exit(1)
    elif not args.non_interactive and sys.stdin.isatty():
        siblings = list_sibling_projects(toolkit_root)
        print(f"\n{BOLD}Detected projects in parent folder ({toolkit_root.parent}):{RESET}")
        for idx, sib in enumerate(siblings, 1):
            is_spring = (sib / "pom.xml").exists() or (sib / "src" / "main" / "java").exists()
            label = " [Spring Boot detected]" if is_spring else ""
            print(f"  [{idx}] {sib.name}{CYAN}{label}{RESET}")
        print(f"  [{len(siblings) + 1}] Enter custom path manually")

        choice = input(f"\nSelect target project [1-{len(siblings) + 1}]: ").strip()
        try:
            choice_idx = int(choice)
            if 1 <= choice_idx <= len(siblings):
                target_dir = siblings[choice_idx - 1]
            elif choice_idx == len(siblings) + 1:
                custom_path = input("Enter path to target project: ").strip()
                target_dir = Path(custom_path).resolve()
        except ValueError:
            target_dir = Path(choice).resolve()
    else:
        print(f"{RED}Error: Target project must be specified using --target in non-interactive mode.{RESET}")
        sys.exit(1)

    if not target_dir or not target_dir.exists():
        print(f"{RED}Error: Invalid target project directory.{RESET}")
        sys.exit(1)

    print(f"{BOLD}Target Project:{RESET} {target_dir}")

    # Detect Java directories
    try:
        main_java, test_java = detect_target_backend(target_dir)
        print(f"{BOLD}Target main java:{RESET} {main_java}")
        print(f"{BOLD}Target test java:{RESET} {test_java}")
    except Exception as e:
        print(f"{RED}Error: {e}{RESET}")
        sys.exit(1)

    # Detect / Determine target package
    detected_base_pkg = detect_target_base_package(main_java)
    default_pkg = f"{detected_base_pkg}.toolkit" if detected_base_pkg else "toolkit"

    target_pkg = args.package
    if not target_pkg:
        if not args.non_interactive and sys.stdin.isatty():
            print(f"\n{CYAN}Detected base package:{RESET} {detected_base_pkg or 'None'}")
            user_pkg = input(f"Enter target package for toolkit classes [{default_pkg}]: ").strip()
            target_pkg = user_pkg if user_pkg else default_pkg
        else:
            target_pkg = default_pkg

    print(f"{BOLD}Target Package:{RESET} {GREEN}{target_pkg}{RESET}")

    # Ask for frontend if not provided
    include_frontend = args.include_frontend
    if not include_frontend and not args.non_interactive and sys.stdin.isatty():
        front_resp = input("\nAlso copy React frontend components & utilities? [y/N]: ").strip().lower()
        include_frontend = front_resp in ["y", "yes", "s", "si", "sí"]

    print(f"\n{BOLD}Starting Integration...{RESET}")
    if args.dry_run:
        print(f"{YELLOW}Running in DRY-RUN mode. No files will be modified.{RESET}\n")

    # 1. Copy & refactor backend main
    src_main_toolkit = toolkit_root / "backend" / "src" / "main" / "java" / "toolkit"
    print(f"\n{CYAN}[1/3] Processing Backend Main Classes...{RESET}")
    main_count = copy_and_refactor_tree(
        src_toolkit_dir=src_main_toolkit,
        dst_root_dir=main_java,
        target_package=target_pkg,
        dry_run=args.dry_run,
        force=args.force,
    )

    # 2. Copy & refactor backend test
    test_count = 0
    if not args.skip_tests:
        src_test_toolkit = toolkit_root / "backend" / "src" / "test" / "java" / "toolkit"
        print(f"\n{CYAN}[2/3] Processing Backend Test Suites...{RESET}")
        test_count = copy_and_refactor_tree(
            src_toolkit_dir=src_test_toolkit,
            dst_root_dir=test_java,
            target_package=target_pkg,
            dry_run=args.dry_run,
            force=args.force,
        )

        # Copy test resources
        src_test_res = toolkit_root / "backend" / "src" / "test" / "resources"
        dst_test_res = test_java.parent / "resources"
        copy_test_resources(src_test_res, dst_test_res, dry_run=args.dry_run, force=args.force)
    else:
        print(f"\n{YELLOW}[2/3] Backend Test Suites skipped (--skip-tests).{RESET}")

    # 3. Copy frontend components
    front_count = 0
    if include_frontend:
        print(f"\n{CYAN}[3/3] Processing Frontend UI Components & Utils...{RESET}")
        front_count = copy_frontend_components(toolkit_root, target_dir, dry_run=args.dry_run, force=args.force)
    else:
        print(f"\n{CYAN}[3/3] Frontend integration omitted.{RESET}")

    # Summary
    print(f"\n{GREEN}{BOLD}" + "=" * 70)
    print("  🎉 INTEGRATION COMPLETED SUCCESSFULLY!")
    print("=" * 70 + f"{RESET}")
    print(f"  - {BOLD}Backend Main Classes Refactored:{RESET} {main_count}")
    print(f"  - {BOLD}Backend Test Suites Refactored:{RESET}  {test_count}")
    if include_frontend:
        print(f"  - {BOLD}Frontend Files Copied:{RESET}           {front_count}")
    print(f"  - {BOLD}Target Package:{RESET}                  {target_pkg}")
    print(f"  - {BOLD}Target Location:{RESET}                 {main_java / Path(*target_pkg.split('.'))}")
    print(f"\n{BOLD}Next Steps for your project:{RESET}")
    print(f"  1. Ensure your {BOLD}pom.xml{RESET} contains:")
    print("     - spring-boot-starter-web")
    print("     - spring-boot-starter-data-jpa")
    print("     - spring-boot-starter-validation")
    print("     - spring-boot-starter-security")
    print("     - spring-boot-starter-websocket")
    print("     - io.jsonwebtoken:jjwt-api:0.12.6, jjwt-impl, jjwt-jackson")
    print(f"  2. Run backend tests to verify:")
    print(f"     {CYAN}mvn test{RESET}")
    if include_frontend:
        print(f"  3. Ensure frontend dependencies are installed in your React app:")
        print(f"     {CYAN}npm install @stomp/stompjs sockjs-client react-hook-form reactstrap bootstrap react-router-dom @fortawesome/fontawesome-free{RESET}")
    print()


if __name__ == "__main__":
    main()
