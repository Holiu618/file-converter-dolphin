#!/usr/bin/env bash
set -u

TARGET="${1:-}"
shift || true

if [ -z "$TARGET" ] || [ "$#" -eq 0 ]; then
    echo "Usage: ${0##*/} <format> <file>..." >&2
    exit 1
fi

notify() {
    local msg="$1" level="${2:-info}"
    if command -v kdialog &>/dev/null; then
        if [ "$level" = error ]; then
            kdialog --title "File Converter" --error "$msg" &
        else
            kdialog --title "File Converter" --passivepopup "$msg" 5 &
        fi
    elif command -v notify-send &>/dev/null; then
        notify-send -a "File Converter" "File Converter" "$msg"
    else
        echo "$msg" >&2
    fi
}

unique_path() {
    local base="$1" ext="$2" out n=1
    out="${base}.${ext}"
    while [ -e "$out" ]; do
        out="${base}_${n}.${ext}"
        n=$((n + 1))
    done
    printf '%s' "$out"
}

convert_one() {
    local in="$1" kind out base

    base="$(dirname -- "$in")/$(basename -- "${in%.*}")"
    kind="$(file --mime-type -b -- "$in" | cut -d/ -f1)"

    case "$TARGET" in
        jpg|jpeg|png|webp)
            out="$(unique_path "$base" "$TARGET")"
            case "$kind" in
                image)
                    local args=(-auto-orient)
                    case "$TARGET" in
                        jpg|jpeg) args+=(-background white -alpha remove -alpha off -quality 92) ;;
                        webp)     args+=(-quality 90) ;;
                    esac
                    magick "${in}[0]" "${args[@]}" "$out" ;;
                video)
                    ffmpeg -nostdin -v error -i "$in" -frames:v 1 "$out" ;;
                *) return 1 ;;
            esac ;;

        gif)
            out="$(unique_path "$base" gif)"
            case "$kind" in
                image)
                    magick "$in" -auto-orient -layers Optimize -loop 0 "$out" ;;
                video)
                    ffmpeg -nostdin -v error -i "$in" \
                        -vf "fps=12,scale='min(480,iw)':-2:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" \
                        -loop 0 "$out" ;;
                *) return 1 ;;
            esac ;;

        jxl)
            [ "$kind" = image ] || return 1
            out="$(unique_path "$base" jxl)"
            if command -v cjxl &>/dev/null && cjxl "$in" "$out" &>/dev/null; then
                :
            else
                rm -f -- "$out"
                magick "${in}[0]" -auto-orient "$out"
            fi ;;

        mp3)
            case "$kind" in audio|video) ;; *) return 1 ;; esac
            out="$(unique_path "$base" mp3)"
            ffmpeg -nostdin -v error -i "$in" -vn -codec:a libmp3lame -q:a 0 \
                -map_metadata 0 "$out" ;;

        *)
            echo "Unsupported format: $TARGET" >&2
            return 1 ;;
    esac

    local rc=$?
    [ $rc -ne 0 ] && rm -f -- "$out"
    LAST_OUT="$out"
    return $rc
}

ok=0
failed=()
LAST_OUT=""

for f in "$@"; do
    if [ ! -f "$f" ]; then
        failed+=("$(basename -- "$f")")
        continue
    fi
    if convert_one "$f"; then
        ok=$((ok + 1))
    else
        failed+=("$(basename -- "$f")")
    fi
done

if [ "${#failed[@]}" -gt 0 ]; then
    notify "Failed (${#failed[@]}):
$(printf '%s\n' "${failed[@]}")" error
    [ "$ok" -gt 0 ] && notify "Converted $ok file(s) to ${TARGET^^}."
    exit 1
elif [ "$ok" -eq 1 ]; then
    notify "Converted: $(basename -- "$LAST_OUT")"
else
    notify "Converted $ok files to ${TARGET^^}."
fi
