#!/usr/bin/env bash

TRASH="${HOME}/.Trash/Office/"

WORD_PATH="/Applications/Microsoft Word.app"
EXCEL_PATH="/Applications/Microsoft Excel.app"
ONENOTE_PATH="/Applications/Microsoft OneNote.app"
OUTLOOK_PATH="/Applications/Microsoft Outlook.app"
POWERPOINT_PATH="/Applications/Microsoft PowerPoint.app"

PATHS=(
  "$WORD_PATH"
  "$EXCEL_PATH"
  "$ONENOTE_PATH"
  "$OUTLOOK_PATH"
  "$POWERPOINT_PATH"
)

target_path=""
trim_paths=()

backup_file() {
  local filename="$1"
  local dest_filename="${TRASH}${filename}"

  mkdir -p "$(dirname "$dest_filename")"
  printf 'Move %s to %s\n' "$filename" "$dest_filename"
  mv "$filename" "$dest_filename"
}

find_and_trim_same_files() {
  local target_dir="$1"
  local dir="$2"
  local filename
  local rel_path
  local target_file
  local source_inode
  local target_inode

  while IFS= read -r -d '' filename; do
    [[ -L "$filename" ]] && continue

    rel_path="${filename#"$dir"}"
    target_file="${target_dir}${rel_path}"

    [[ -f "$target_file" ]] || continue
    [[ -L "$target_file" ]] && continue

    source_inode="$(stat -f '%i' "$filename")"
    target_inode="$(stat -f '%i' "$target_file")"

    [[ "$source_inode" == "$target_inode" ]] && continue
    cmp -s "$target_file" "$filename" || continue

    backup_file "$filename"
    ln "$target_file" "$filename"
  done < <(find "$dir" -type f -print0)
}

main() {
  local pathname

  if [[ "$(id -u)" != "0" ]]; then
    printf 'Need root privilege, Please run: sudo bash %s\n' "$0"
    exit 1
  fi

  for pathname in "${PATHS[@]}"; do
    if [[ -d "$pathname" ]]; then
      if [[ -n "$target_path" ]]; then
        trim_paths+=("$pathname")
      else
        target_path="$pathname"
      fi
    fi
  done

  if [[ -z "$target_path" ]]; then
    printf "Don't exist path in %s\n" "${PATHS[*]}"
    exit 1
  fi

  printf 'Trim %s with %s\n' "${trim_paths[*]}" "$target_path"
  for pathname in "${trim_paths[@]}"; do
    printf '%s, %s\n' "$target_path" "$pathname"
    find_and_trim_same_files "$target_path" "$pathname"
  done

  printf 'Office thinning completed!\n'
  printf 'Backup files in %s, you view or delete the files later by Finder Trash.\n' "$TRASH"
}

main "$@"
