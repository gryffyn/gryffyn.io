#!/usr/bin/env bash
IFS=$'\n'
INDEX="_index.md"
FILELIST=`fd -t f -d 1 --strip-cwd-prefix`

for f in $FILELIST
do
  if [[ "$f" == "$INDEX" ]]
  then
    continue
  fi

  filename="${f%.*}"
  mkdir "$filename"
  mv "$f" "$filename/."
  cp "$INDEX" "$filename/index.md"
done
