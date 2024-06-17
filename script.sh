function cli {
	audio_file="$1"
	shift

	image_files=()
	num_images=0

	for arg; do
		image_files+=("$arg")
		num_images=$((num_images + 1))
	done

	generate_video "$audio_file" "$image_files" "$num_images"
}

function stdin {
	while true; do
		read -r -p "Specify the file path fo the audio file: " audio_file

		if [[ "${#audio_file}" == 0 ]]; then
			clear
			echo "You did not specify an audio file. Please try again."
		else
			read -r -p "Are you sure the audio file is correct? [y/n] " confirm
			clear

			if [[ "$confirm" == "y" ]]; then
				break
			fi
		fi
	done

	image_files=()
	num_images=1

	echo "Specify the file path to an image."
	echo "Note that the images will display in the order that you specify them."
	echo "When you are finished, press Enter without specifying a file path"
	echo ""

	while true; do
		read -r -p "Image #${num_images} file path: " image_file

		if [[ "${#image_file}" == 0 ]]; then
			if [[ "$num_images" == 1 ]]; then
				echo "You have not specified any images. Please try again."
				continue
			fi

			echo "Are you sure you are done specifying images? [y/n] "
			read -r confirm
			echo ""

			if [[ "$confirm" == "y" ]]; then
				num_images=$(num_images - 1)
				break
			fi
		else
			read -r -p "Are you sure the image file is correct? [y/n] " confirm

			if [[ "$confirm" == "y" ]]; then
				image_files+=($image_file)
				num_images=$(num_images + 1)
			fi
		fi
	done

	clear
	echo "Generating video..."
	generate_video "$audio_file" "$image_files" "$num_images"
	echo "Complete! Your video is located at $(echo $PWD)/output.mp4"
}

function generate_video {
	audio_file="$1"
	image_files="$2"
	num_images="$3"

	audio_length=$(ffprobe -i "$audio_file" -show_entries format=duration -v quiet -of csv="p=0")
	image_duration=$(echo "6k $audio_length $num_images / p" | dc)

	filter_complex=""
	for i in $(seq 1 "$num_images"); do
		filter_complex+="[$i:v]fade=t=in:st=0:d=1,fade=t=out:st=$(echo "6k $image_duration 1 - p" | dc):d=1[img$i];"
	done
	for i in $(seq 1 "$num_images"); do
		filter_complex+="[img$i]"
	done
	filter_complex+="concat=n=$num_images:v=1:a=0[v]"

	ffmpeg_args=(-y -i "$audio_file")
	for image_file in "${image_files[@]}"; do
		ffmpeg_args+=(-loop 1 -t "$image_duration" -i "$image_file")
	done
	ffmpeg_args+=(-filter_complex "$filter_complex" -map "[v]" -map 0:a -r 60 -shortest output.mp4 -nostats -loglevel 0)

	ffmpeg "${ffmpeg_args[@]}"
}

if [[ "${#1}" == 0 && "${#2}" == 0 ]]; then
	stdin
else
	cli "$@"
fi
