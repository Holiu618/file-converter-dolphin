#!/bin/bash

TARGET_FORMAT="$1"
FILE="$2"

if [ -z "$TARGET_FORMAT" ] || [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    exit 1
fi

filename=$(basename -- "$FILE")
extension="${filename##*.}"
filename_no_ext="${filename%.*}"
dir=$(dirname -- "$FILE")

OUTPUT_FILE="${dir}/${filename_no_ext}.${TARGET_FORMAT}"

if [ "$FILE" = "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="${dir}/${filename_no_ext}_converted.${TARGET_FORMAT}"
fi

CONVERT_SUCCESS=false

case "$TARGET_FORMAT" in
    jpg|jpeg|png|webp)
        magick "$FILE" "$OUTPUT_FILE" && CONVERT_SUCCESS=true
        ;;
    jxl)
        if command -v cjxl &> /dev/null; then
            cjxl "$FILE" "$OUTPUT_FILE" && CONVERT_SUCCESS=true
        else
            magick "$FILE" "$OUTPUT_FILE" && CONVERT_SUCCESS=true
        fi
        ;;
    mp3)
        ffmpeg -i "$FILE" -q:a 0 -map a "$OUTPUT_FILE" -y && CONVERT_SUCCESS=true
        ;;
    *)
        exit 1
        ;;
esac

if [ "$CONVERT_SUCCESS" = true ]; then
    if command -v kdialog &> /dev/null; then
        kdialog --passivepopup "Conversion Successful."
    fi
fi
