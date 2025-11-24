#!/bin/bash
# Bulk migrates user-facing scripts to ark.* namespace
# Internal widget implementations keep direct requires (safer!)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARKITEKT_ROOT="$(dirname "$SCRIPT_DIR")"

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================="
echo "ARKITEKT Namespace Migration"
echo "=================================="
echo ""

# Find files to migrate (user scripts only, not internal widgets)
FILES_TO_MIGRATE=$(find "$ARKITEKT_ROOT" -name "*.lua" \
  \( -path "*/scripts/*" -o -name "ARK_*.lua" -o -name "ARKITEKT.lua" \) \
  ! -path "*/arkitekt/gui/widgets/primitives/*" \
  ! -path "*/arkitekt/gui/widgets/containers/*" \
  ! -path "*/tools/*" \
  ! -path "*/tests/*" \
  ! -path "*/examples/*" \
  ! -path "*/docs/*")

FILE_COUNT=$(echo "$FILES_TO_MIGRATE" | wc -l)
echo "Found $FILE_COUNT files to migrate"
echo ""

# Module mapping (path -> namespace key)
declare -A MODULE_MAP=(
  ["arkitekt.gui.widgets.primitives.badge"]="Badge"
  ["arkitekt.gui.widgets.primitives.button"]="Button"
  ["arkitekt.gui.widgets.primitives.checkbox"]="Checkbox"
  ["arkitekt.gui.widgets.primitives.close_button"]="CloseButton"
  ["arkitekt.gui.widgets.primitives.combo"]="Combo"
  ["arkitekt.gui.widgets.primitives.corner_button"]="CornerButton"
  ["arkitekt.gui.widgets.primitives.hue_slider"]="HueSlider"
  ["arkitekt.gui.widgets.primitives.inputtext"]="InputText"
  ["arkitekt.gui.widgets.primitives.markdown_field"]="MarkdownField"
  ["arkitekt.gui.widgets.primitives.radio_button"]="RadioButton"
  ["arkitekt.gui.widgets.primitives.scrollbar"]="Scrollbar"
  ["arkitekt.gui.widgets.primitives.separator"]="Separator"
  ["arkitekt.gui.widgets.primitives.slider"]="Slider"
  ["arkitekt.gui.widgets.primitives.spinner"]="Spinner"
  ["arkitekt.gui.widgets.containers.panel"]="Panel"
  ["arkitekt.gui.widgets.containers.tile_group"]="TileGroup"
  ["arkitekt.core.colors"]="Colors"
  ["arkitekt.gui.style.defaults"]="Style"
  ["arkitekt.gui.draw"]="Draw"
  ["arkitekt.gui.fx.animation.easing"]="Easing"
  ["arkitekt.core.math"]="Math"
  ["arkitekt.core.uuid"]="UUID"
)

MIGRATED=0
SKIPPED=0

# Process each file
while IFS= read -r file; do
  # Skip empty lines
  [ -z "$file" ] && continue

  # Check if file has any arkitekt requires
  if ! grep -q "require.*arkitekt\." "$file"; then
    continue
  fi

  echo -e "${YELLOW}Processing:${NC} ${file#$ARKITEKT_ROOT/}"

  # Create backup
  cp "$file" "$file.bak"

  # Track if we need to add ark require
  NEEDS_ARK=false
  MODIFIED=false

  # Check if already has ark namespace
  if grep -q "local ark = require('arkitekt')" "$file"; then
    echo "  Already has ark namespace, skipping"
    rm "$file.bak"
    ((SKIPPED++))
    continue
  fi

  # Create temp file for processing
  TEMP_FILE=$(mktemp)
  cp "$file" "$TEMP_FILE"

  # Find and process each require
  for module_path in "${!MODULE_MAP[@]}"; do
    ns_key="${MODULE_MAP[$module_path]}"

    # Find local variable name for this module
    VAR_NAME=$(grep -o "local [A-Za-z_][A-Za-z0-9_]* = require.*${module_path}" "$TEMP_FILE" | head -1 | sed -E "s/local ([A-Za-z_][A-Za-z0-9_]*) .*/\1/")

    if [ -n "$VAR_NAME" ]; then
      echo "    $VAR_NAME -> ark.$ns_key"

      # Remove the require line
      sed -i "/^local ${VAR_NAME} = require.*${module_path//./\\.}/d" "$TEMP_FILE"

      # Replace usages: VarName. -> ark.NsKey.
      sed -i "s/\b${VAR_NAME}\\./${ns_key//.Easing/.Easing.}/" "$TEMP_FILE"
      # Note: We use ark. in the next step

      NEEDS_ARK=true
      MODIFIED=true
    fi
  done

  if [ "$MODIFIED" = true ]; then
    # Add ark namespace require after first require block
    if [ "$NEEDS_ARK" = true ]; then
      # Find first require line
      FIRST_REQUIRE_LINE=$(grep -n "^local .* = require" "$TEMP_FILE" | head -1 | cut -d: -f1)

      if [ -n "$FIRST_REQUIRE_LINE" ]; then
        # Insert after first require
        sed -i "${FIRST_REQUIRE_LINE}a\\local ark = require('arkitekt')" "$TEMP_FILE"
      else
        # No requires, add at top after comments
        FIRST_CODE_LINE=$(grep -n "^[^-]" "$TEMP_FILE" | head -1 | cut -d: -f1)
        sed -i "${FIRST_CODE_LINE}i\\local ark = require('arkitekt')\\n" "$TEMP_FILE"
      fi
    fi

    # Now replace all the widget names with ark. prefix
    for module_path in "${!MODULE_MAP[@]}"; do
      ns_key="${MODULE_MAP[$module_path]}"
      sed -i "s/\b${ns_key}\./ark.${ns_key}./g" "$TEMP_FILE"
    done

    # Move temp file back
    mv "$TEMP_FILE" "$file"
    rm "$file.bak"

    echo -e "  ${GREEN}✓ Migrated${NC}"
    ((MIGRATED++))
  else
    rm "$TEMP_FILE"
    rm "$file.bak"
    echo "  No changes needed"
    ((SKIPPED++))
  fi

  echo ""
done <<< "$FILES_TO_MIGRATE"

echo "=================================="
echo -e "${GREEN}Migration Complete${NC}"
echo "  Migrated: $MIGRATED files"
echo "  Skipped: $SKIPPED files"
echo "=================================="
