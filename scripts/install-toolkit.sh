#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Autor / Author: Ignacio Gutiérrez Serrera
# GitHub: https://github.com/Ignacio0407 (@Ignacio0407)
# Contact / Email: ignaciogutierrezserrera@gmail.com
#
# ⚡ Spring-React CRUD Toolkit & Accelerator
# Automated Integration Script (Bash / POSIX)
# -----------------------------------------------------------------------------

set -e

# Terminal colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

print_banner() {
    echo -e "${CYAN}${BOLD}"
    echo "======================================================================"
    echo "  [+] Spring-React CRUD Toolkit - Project Integrator (Bash)"
    echo "  Author: Ignacio Gutiérrez Serrera (@Ignacio0407)"
    echo "======================================================================"
    echo -e "${RESET}"
}

# Resolve script directory and toolkit root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/backend/src/main/java/toolkit" ]; then
    TOOLKIT_ROOT="$SCRIPT_DIR"
elif [ -d "$SCRIPT_DIR/../backend/src/main/java/toolkit" ]; then
    TOOLKIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -d "$(pwd)/backend/src/main/java/toolkit" ]; then
    TOOLKIT_ROOT="$(pwd)"
elif [ -d "$(pwd)/spring-react-crud-toolkit/backend/src/main/java/toolkit" ]; then
    TOOLKIT_ROOT="$(pwd)/spring-react-crud-toolkit"
else
    echo -e "${RED}Error: Could not locate spring-react-crud-toolkit root directory.${RESET}" >&2
    exit 1
fi

PARENT_DIR="$(cd "$TOOLKIT_ROOT/.." && pwd)"

# Default arguments
TARGET_PROJECT=""
TARGET_PACKAGE=""
INCLUDE_FRONTEND=false
SKIP_TESTS=false
DRY_RUN=false
FORCE=false
NON_INTERACTIVE=false

usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -t, --target <path|name>   Target project directory name or path"
    echo "  -p, --package <package>    Target Java package for toolkit classes"
    echo "  -f, --include-frontend     Also copy React frontend components & utilities"
    echo "  -s, --skip-tests           Skip copying backend test suites"
    echo "  -d, --dry-run              Preview actions without modifying files"
    echo "  -y, --force                Overwrite existing files without prompt"
    echo "  -n, --non-interactive      Disable interactive prompts"
    echo "  -h, --help                 Show this help message"
    echo ""
    exit 0
}

# Parse options
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--target)
            TARGET_PROJECT="$2"
            shift 2
            ;;
        -p|--package)
            TARGET_PACKAGE="$2"
            shift 2
            ;;
        -f|--include-frontend)
            INCLUDE_FRONTEND=true
            shift
            ;;
        -s|--skip-tests)
            SKIP_TESTS=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -y|--force)
            FORCE=true
            shift
            ;;
        -n|--non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            if [ -z "$TARGET_PROJECT" ]; then
                TARGET_PROJECT="$1"
                shift
            else
                echo -e "${RED}Unknown argument: $1${RESET}" >&2
                usage
            fi
            ;;
    esac
done

print_banner
echo -e "${BOLD}Source Toolkit:${RESET} $TOOLKIT_ROOT"

# Resolve Target Directory
TARGET_DIR=""
if [ -n "$TARGET_PROJECT" ]; then
    if [ -d "$TARGET_PROJECT" ]; then
        TARGET_DIR="$(cd "$TARGET_PROJECT" && pwd)"
    elif [ -d "$PARENT_DIR/$TARGET_PROJECT" ]; then
        TARGET_DIR="$(cd "$PARENT_DIR/$TARGET_PROJECT" && pwd)"
    else
        echo -e "${RED}Error: Target directory '$TARGET_PROJECT' not found.${RESET}" >&2
        exit 1
    fi
elif [ "$NON_INTERACTIVE" = false ] && [ -t 0 ]; then
    echo -e "\n${BOLD}Detected projects in parent folder ($PARENT_DIR):${RESET}"
    siblings=()
    i=1
    for dir in "$PARENT_DIR"/*/; do
        [ -d "$dir" ] || continue
        base="$(basename "$dir")"
        if [ "$base" != "$(basename "$TOOLKIT_ROOT")" ] && [[ ! "$base" =~ ^\. ]]; then
            is_spring=""
            if [ -f "$dir/pom.xml" ] || [ -d "$dir/src/main/java" ]; then
                is_spring=" [Spring Boot detected]"
            fi
            echo -e "  [$i] $base${GREEN}$is_spring${RESET}"
            siblings+=("$dir")
            ((i++))
        fi
    done
    echo "  [$i] Enter custom path manually"

    echo ""
    read -rp "Select target project [1-$i]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$i" ]; then
        idx=$((choice - 1))
        TARGET_DIR="$(cd "${siblings[$idx]}" && pwd)"
    elif [ "$choice" -eq "$i" ]; then
        read -rp "Enter path to target project: " custom_path
        TARGET_DIR="$(cd "$custom_path" && pwd)"
    else
        TARGET_DIR="$(cd "$choice" && pwd)"
    fi
else
    echo -e "${RED}Error: Target project must be specified using -t/--target in non-interactive mode.${RESET}" >&2
    exit 1
fi

if [ -z "$TARGET_DIR" ] || [ ! -d "$TARGET_DIR" ]; then
    echo -e "${RED}Error: Invalid target project directory.${RESET}" >&2
    exit 1
fi

echo -e "${BOLD}Target Project:${RESET} $TARGET_DIR"

# Detect backend layout
MAIN_JAVA=""
TEST_JAVA=""
if [ -d "$TARGET_DIR/backend/src/main/java" ]; then
    MAIN_JAVA="$TARGET_DIR/backend/src/main/java"
    TEST_JAVA="$TARGET_DIR/backend/src/test/java"
elif [ -d "$TARGET_DIR/src/main/java" ]; then
    MAIN_JAVA="$TARGET_DIR/src/main/java"
    TEST_JAVA="$TARGET_DIR/src/test/java"
else
    echo -e "${RED}Error: Could not find Java source directory in '$TARGET_DIR'. Expected 'src/main/java' or 'backend/src/main/java'.${RESET}" >&2
    exit 1
fi

echo -e "${BOLD}Target main java:${RESET} $MAIN_JAVA"
echo -e "${BOLD}Target test java:${RESET} $TEST_JAVA"

# Auto-detect base package
DETECTED_BASE_PKG=""
while IFS= read -r f; do
    if grep -q "@SpringBootApplication" "$f" 2>/dev/null; then
        DETECTED_BASE_PKG="$(grep -m 1 "^[[:space:]]*package[[:space:]]\+" "$f" | sed -E 's/^[[:space:]]*package[[:space:]]+([a-zA-Z0-9_.]+)[[:space:]]*;/\1/')"
        [ -n "$DETECTED_BASE_PKG" ] && break
    fi
done < <(find "$MAIN_JAVA" -type f -name "*.java" 2>/dev/null)

DEFAULT_PKG="toolkit"
if [ -n "$DETECTED_BASE_PKG" ]; then
    DEFAULT_PKG="${DETECTED_BASE_PKG}.toolkit"
fi

FINAL_PKG="$TARGET_PACKAGE"
if [ -z "$FINAL_PKG" ]; then
    if [ "$NON_INTERACTIVE" = false ] && [ -t 0 ]; then
        echo -e "\n${CYAN}Detected base package:${RESET} ${DETECTED_BASE_PKG:-None}"
        read -rp "Enter target package for toolkit classes [$DEFAULT_PKG]: " user_pkg
        FINAL_PKG="${user_pkg:-$DEFAULT_PKG}"
    else
        FINAL_PKG="$DEFAULT_PKG"
    fi
fi

echo -e "${BOLD}Target Package:${RESET} ${GREEN}$FINAL_PKG${RESET}"

# Ask for frontend if interactive
if [ "$INCLUDE_FRONTEND" = false ] && [ "$NON_INTERACTIVE" = false ] && [ -t 0 ]; then
    read -rp "Also copy React frontend components & utilities? [y/N]: " front_resp
    case "$front_resp" in
        [yY]|[yY][eE][sS]|[sS]|[sS][iI]) INCLUDE_FRONTEND=true ;;
    esac
fi

echo -e "\n${BOLD}Starting Integration...${RESET}"
if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}Running in DRY-RUN mode. No files will be modified.${RESET}\n"
fi

# Transform and Copy function
transform_and_copy_file() {
    local src_file="$1"
    local dst_file="$2"
    local target_pkg="$3"

    mkdir -p "$(dirname "$dst_file")"

    # Use awk/sed pipeline to safely rewrite packages, imports, and references
    awk -v pkg="$target_pkg" '
    {
        line = $0
        # Package declarations
        if (line ~ /^[[:space:]]*package[[:space:]]+toolkit;/) {
            sub(/toolkit;/, pkg ";", line)
        } else if (line ~ /^[[:space:]]*package[[:space:]]+toolkit\./) {
            sub(/toolkit\./, pkg ".", line)
        }
        # Imports
        else if (line ~ /^[[:space:]]*import[[:space:]]+toolkit\./) {
            sub(/toolkit\./, pkg ".", line)
        } else if (line ~ /^[[:space:]]*import[[:space:]]+static[[:space:]]+toolkit\./) {
            sub(/toolkit\./, pkg ".", line)
        }
        # Code references to subpackages
        gsub(/([^a-zA-Z0-9_.]|^)toolkit\.(configuration|controller|exception|model|repository|security|service|user)/, "\\1" pkg ".\\2", line)
        print line
    }' "$src_file" > "$dst_file"
}

copy_java_tree() {
    local src_dir="$1"
    local dst_root="$2"
    local pkg="$3"

    local pkg_path="${pkg//.//}"
    local dst_pkg_dir="$dst_root/$pkg_path"
    local count=0

    while IFS= read -r src_file; do
        [ -f "$src_file" ] || continue
        local rel="${src_file#$src_dir/}"
        local dst_file="$dst_pkg_dir/$rel"

        if [ -f "$dst_file" ] && [ "$FORCE" = false ]; then
            echo -e "  ${YELLOW}[EXISTS]${RESET} $dst_file (skipping, use -y/--force to overwrite)" >&2
            continue
        fi

        ((count++))
        if [ "$DRY_RUN" = true ]; then
            echo -e "  ${CYAN}[DRY-RUN]${RESET} Would copy: $(basename "$src_file") -> $dst_file" >&2
        else
            transform_and_copy_file "$src_file" "$dst_file" "$pkg"
            echo -e "  ${GREEN}[OK]${RESET} $rel -> ${dst_file#$dst_root/}" >&2
        fi
    done < <(find "$src_dir" -type f -name "*.java" 2>/dev/null)

    echo "$count"
}

# 1. Backend Main
SRC_MAIN_TOOLKIT="$TOOLKIT_ROOT/backend/src/main/java/toolkit"
echo -e "\n${CYAN}[1/3] Processing Backend Main Classes...${RESET}"
MAIN_COUNT=$(copy_java_tree "$SRC_MAIN_TOOLKIT" "$MAIN_JAVA" "$FINAL_PKG")

# 2. Backend Test
TEST_COUNT=0
if [ "$SKIP_TESTS" = false ]; then
    SRC_TEST_TOOLKIT="$TOOLKIT_ROOT/backend/src/test/java/toolkit"
    echo -e "\n${CYAN}[2/3] Processing Backend Test Suites...${RESET}"
    TEST_COUNT=$(copy_java_tree "$SRC_TEST_TOOLKIT" "$TEST_JAVA" "$FINAL_PKG")

    SRC_PROPS="$TOOLKIT_ROOT/backend/src/test/resources/application.properties"
    DST_PROPS_DIR="$(dirname "$TEST_JAVA")/resources"
    DST_PROPS="$DST_PROPS_DIR/application.properties"
    if [ -f "$SRC_PROPS" ]; then
        if [ ! -f "$DST_PROPS" ] || [ "$FORCE" = true ]; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "  ${CYAN}[DRY-RUN]${RESET} Would copy test application.properties -> $DST_PROPS"
            else
                mkdir -p "$DST_PROPS_DIR"
                cp "$SRC_PROPS" "$DST_PROPS"
                echo -e "  ${GREEN}[OK]${RESET} Copied test application.properties -> $DST_PROPS"
            fi
        fi
    fi
else
    echo -e "\n${YELLOW}[2/3] Backend Test Suites skipped (--skip-tests).${RESET}"
fi

# 3. Frontend
FRONT_COUNT=0
if [ "$INCLUDE_FRONTEND" = true ]; then
    SRC_FRONT="$TOOLKIT_ROOT/frontend/src"
    echo -e "\n${CYAN}[3/3] Processing Frontend UI Components & Utils...${RESET}"
    if [ -d "$SRC_FRONT" ]; then
        DST_FRONT=""
        if [ -d "$TARGET_DIR/frontend/src" ]; then
            DST_FRONT="$TARGET_DIR/frontend/src"
        elif [ -d "$TARGET_DIR/src/components" ] || [ -f "$TARGET_DIR/package.json" ]; then
            DST_FRONT="$TARGET_DIR/src"
        else
            DST_FRONT="$TARGET_DIR/frontend/src"
        fi

        for folder in components interfaces services util; do
            if [ -d "$SRC_FRONT/$folder" ]; then
                while IFS= read -r f; do
                    [ -f "$f" ] || continue
                    rel="${f#$SRC_FRONT/}"
                    dst_f="$DST_FRONT/$rel"
                    if [ -f "$dst_f" ] && [ "$FORCE" = false ]; then
                        continue
                    fi
                    ((FRONT_COUNT++))
                    if [ "$DRY_RUN" = true ]; then
                        echo -e "  ${CYAN}[DRY-RUN]${RESET} Would copy frontend: $rel -> $dst_f"
                    else
                        mkdir -p "$(dirname "$dst_f")"
                        cp "$f" "$dst_f"
                        echo -e "  ${GREEN}[OK]${RESET} Frontend: $rel"
                    fi
                done < <(find "$SRC_FRONT/$folder" -type f 2>/dev/null)
            fi
        done
    else
        echo -e "  ${YELLOW}[WARN]${RESET} Source frontend/src not found."
    fi
else
    echo -e "\n${CYAN}[3/3] Frontend integration omitted.${RESET}"
fi

# Summary
echo -e "\n${GREEN}${BOLD}======================================================================${RESET}"
echo -e "${GREEN}${BOLD}  [+] INTEGRATION COMPLETED SUCCESSFULLY!${RESET}"
echo -e "${GREEN}${BOLD}======================================================================${RESET}"
echo -e "  - Backend Main Classes Refactored: $MAIN_COUNT"
echo -e "  - Backend Test Suites Refactored:  $TEST_COUNT"
if [ "$INCLUDE_FRONTEND" = true ]; then
    echo -e "  - Frontend Files Copied:           $FRONT_COUNT"
fi
echo -e "  - Target Package:                  $FINAL_PKG"
echo -e "  - Target Location:                 $MAIN_JAVA/${FINAL_PKG//.//}"
echo -e "\n${BOLD}Next Steps for your project:${RESET}"
echo "  1. Ensure your pom.xml contains:"
echo "     - spring-boot-starter-web"
echo "     - spring-boot-starter-data-jpa"
echo "     - spring-boot-starter-validation"
echo "     - spring-boot-starter-security"
echo "     - spring-boot-starter-websocket"
echo "     - io.jsonwebtoken:jjwt-api:0.12.6, jjwt-impl, jjwt-jackson"
echo "  2. Run backend tests to verify:"
echo -e "     ${CYAN}mvn test${RESET}"
if [ "$INCLUDE_FRONTEND" = true ]; then
    echo "  3. Ensure frontend dependencies are installed in your React app:"
    echo -e "     ${CYAN}npm install @stomp/stompjs sockjs-client react-hook-form reactstrap bootstrap react-router-dom @fortawesome/fontawesome-free${RESET}"
fi
echo ""
