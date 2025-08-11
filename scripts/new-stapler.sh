#!/usr/bin/env bash

curdir=$(basename "$PWD")
if [ "$curdir" != "staplers" ]; then
  echo "run script from staplers dir"
  exit 1
fi

metadata=()

echo -n "Folder name: "
read -r folder_name

mkdir -p $folder_name
cp index.tmpl "${folder_name}/index.md"

echo -n "Title: "
read -r title
metadata+=("title")

PS3='Manufacturer: '
options=("Parrot Speed Fastener Co." "Speed Products Co." "Speed Products Co. Inc." "Swingline, Inc." "Other")
select opt in "${options[@]}"; do
  manuf=$opt
  case $opt in
  "Other")
    echo -n "Other edge type: "
    read -r manuf
    break
    ;;
  esac
  break
done
metadata+=("manuf")

echo -n "Model: "
read -r model
metadata+=("model")

echo -n "Version: "
read -r version
metadata+=("version")

echo -n "Approx manufacture date: "
read -r date
metadata+=("date")

for idx in "${!metadata[@]}"; do
  arg=${metadata[$idx]}
  sed -i -e "s/@$arg@/${!arg}/g" "$folder_name/index.md"
done

read -r -p "Edit? [y/N] " edit
case $edit in
[yY])
  nano "$folder_name/index.md"
  ;;
*) exit ;;
esac
