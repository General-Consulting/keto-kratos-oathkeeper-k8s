max_size=$1
current_size=0
file_count=1
output_file="ALL$(printf "%02d" $file_count).YAML"

# Function to add a file to the output
add_file() {
  echo "--" >>$output_file
  echo "./$1" >>$output_file
  echo "--" >>$output_file
  cat "$1" >>$output_file
  echo "--" >>$output_file
}

# Loop through all markdown files
find . -name '*.yaml' | while read file; do
  file_size=$(wc -c <"$file")

  if [[ $(($current_size + $file_size)) -le $max_size ]]; then
    add_file "$file"
    current_size=$(($current_size + $file_size))
  else
    file_count=$(($file_count + 1))
    output_file="ALL$(printf "%02d" $file_count).YAML"
    current_size=$file_size
    add_file "$file"
  fi
done
