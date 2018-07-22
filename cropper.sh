#!/bin/bash


# Stop on all errors
set -e

# Uncomment for debugging output
# set -x


# Landscape width and height definitions in pixels
LANDSCAPE_WIDTH=5120
LANDSCAPE_HEIGHT=2880

# Portrait width and height definitions in pixels
PORTRAIT_WIDTH=2880
PORTRAIT_HEIGHT=5120


# Input arguments check
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input-directory> <output-directory>"
    echo "Example: $0 "'"/Users/dominic/Background Images" "/Users/dominic/Converted Background Images"'
    exit -1
fi


if ! hash convert 2>/dev/null;
then
        echo -e "This script requires 'convert' from 'ImageMagick' but it cannot be detected. Aborting..."
        exit 1
fi


if ! hash exiftool 2>/dev/null;
then
        echo -e "This script requires 'exiftool' but it cannot be detected. Aborting..."
        exit 1
fi


# Input directories (eventually converted to absolute paths)
INPUT_DIRECTORY="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
OUTPUT_DIRECTORY="$(cd "$(dirname "$2")"; pwd)/$(basename "$2")"


# Directories
LANDSCAPE_DIRECTORY="Landscape"
PORTRAIT_DIRECTORY="Portrait"
LANDSCAPE_OUTPUT_DIRECTORY="${OUTPUT_DIRECTORY}/${LANDSCAPE_DIRECTORY}"
PORTRAIT_OUTPUT_DIRECTORY="${OUTPUT_DIRECTORY}/${PORTRAIT_DIRECTORY}"
mkdir -p "${LANDSCAPE_OUTPUT_DIRECTORY}"
mkdir -p "${PORTRAIT_OUTPUT_DIRECTORY}"




pushd "${INPUT_DIRECTORY}" > /dev/null

# Walk ${INPUT_DIRECTORY} and crop all images
find . -type d ! -path '*/\.*' ! -path . -print0 |
    while IFS= read -r -d $'\0' directory; do
        gravity=$(echo ${directory} | sed 's/.\///g')
        echo "Processing directory '${gravity}'..."
        pushd ${directory} > /dev/null
        find . -type f ! -path '*/\.*' -print0 |
            while IFS= read -r -d $'\0' file
            do
                # File name handling
                filename=$(echo ${file} | sed 's/.\///g')
                non_jpeg_filename="${filename%.*}"
                jpeg_filename="${non_jpeg_filename}".jpg
                
                # Determine the ${filename}'s orientation: Landscape or Portrait?
                image_width=$(exiftool -s3 -imagewidth "${filename}")
                image_height=$(exiftool -s3 -imageheight "${filename}")
                orientation=$(exiftool -s3 -orientation "${filename}")
                orientation_hash=$(exiftool -s3 -orientation# "${filename}")
                # Simulate '$imagewidth > $imageheight xor (defined $orientation and $orientation# > 4)' as described on <http://u88.n24.queensu.ca/exiftool/forum/index.php?topic=7523.0>
                # Here, XOR is simulated by '( ($imagewidth <= $imageheight) AND (defined $orientation and $orientation# > 4) ) || ( ($imagewidth > $imageheight) AND (undefined $orientation OR $orientation# <= 4) )'
                if [[ ( ("${image_width}" -le "${image_height}") && ("${orientation}" != "" && "${orientation_hash}" -gt 4) )    ||    ( ("${image_width}" -gt "${image_height}") && ("${orientation}" = "" || "${orientation_hash}" -le 4 )) ]]
                then
                    is_landscape=1
                    output_directory="${LANDSCAPE_OUTPUT_DIRECTORY}"
                else
                    is_landscape=0
                    output_directory="${PORTRAIT_OUTPUT_DIRECTORY}"
                fi
                outfile="${output_directory}/${jpeg_filename}"
                
                # Skip cropping if ${filename} has already been cropped
                if [ -e "${outfile}" ]
                then
                    echo "  ${filename} has already been cropped"
                else
                    # Crop ${filename} according to its orientation
                    if [ "${is_landscape}" -eq 1 ]
                    then
                        echo -n "  Cropping landscape ${filename}..."
                        convert "${filename}" -resize ${LANDSCAPE_WIDTH} -gravity ${gravity} -crop "${LANDSCAPE_WIDTH}x${LANDSCAPE_HEIGHT}+0+0" jpg:"${outfile}"
                    else
                        echo -n "  Cropping portrait ${filename}..."
                        convert "${filename}" -gravity ${gravity} -auto-orient -resize x${PORTRAIT_HEIGHT} -crop "${PORTRAIT_WIDTH}x${PORTRAIT_HEIGHT}+0+0" jpg:"${outfile}"
                    fi

                    # TIFF file handling
                    smaller_tiff_file="${output_directory}/${non_jpeg_filename}"-1.jpg
                    if [ -f "${smaller_tiff_file}" ]
                    then
                       rm "${output_directory}/${non_jpeg_filename}"-1.jpg
                    fi
                    # Rename the bigger one to "${jpeg_path}" if it exists
                    larger_tiff_file="${output_directory}/${non_jpeg_filename}"-0.jpg
                    if [ -f "${larger_tiff_file}" ]
                    then
                        mv "${output_directory}/${non_jpeg_filename}"-0.jpg "${outfile}"
                        # Copy the EXIF tags from "${non_jpeg_file}" to "${jpeg_path}"
                        exiftool -overwrite_original -TagsFromFile "${file}" "${outfile}"
                    fi

                    echo "done!"
                fi
            done
        echo "...done processing directory '${gravity}'!"
        popd > /dev/null
    done

popd > /dev/null
