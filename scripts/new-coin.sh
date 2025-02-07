#!/usr/bin/env bash

curdir=$(basename $PWD)
if [ "$curdir" != "coins" ]
then
  echo "run script from coins dir"
  exit 1
fi

metadata=()

echo -n "Folder name: "
read -r folder_name

mkdir $folder_name
cp index.tmpl "${folder_name}/index.md"

echo -n "Title: "
read -r title
metadata+=( "title" )

echo -n "Description: "
read -r desc
metadata+=( "desc" )

echo -n "Issuer: "
read -r issuer
metadata+=( "issuer" )

echo -n "Value: "
read -r value
metadata+=( "value" )

echo -n "Currency: "
read -r currency
metadata+=( "currency" )

echo -n "Years produced: "
read -r years
metadata+=( "years" )

echo -n "Year on coin: "
read -r year
metadata+=( "year" )

echo -n "Composition: "
read -r composition
metadata+=( "composition" )

echo -n "Weight (g): "
read -r weight
metadata+=( "weight" )

echo -n "Diameter (mm): "
read -r diameter
metadata+=( "diameter" )

echo -n "Thickness (mm): "
read -r thickness
metadata+=( "thickness" )

PS3='Shape: '
options=("Round" "Round (hole)" "Round (irregular)" "Spanish flower" "Sided" "Scalloped" "Other")
select opt in "${options[@]}"
do
  shape=$opt
  case $opt in
  "Other")
    echo -n "Other shape: "
    read -r shape
    break
    ;;
  "Round (hole)")
    PS3='Shape: '
    options=("Round with round hole" "Round with square hole" "Round with cutout")
    select opt in "${options[@]}"
    do
      shape=$opt
    done
    break
    ;;
  "Sided")
    echo -n "Number of sides: "
    read -r sides
    shape=$(printf 'Round (%s-sided)' "$sides")
    case $sides in
    "3")
      shape="Triangular"
      ;;
    "4")
      shape="Square"
      ;;
    "5")
      shape="Pentagonal"
      ;;
    esac
    break
    ;;
  "Scalloped")
    echo -n "Number of notches: "
    read -r notches
    shape=$(printf 'Scalloped (with %s notches)' "$notches")
    break
    ;;
  esac
  break
done
metadata+=( "shape" )

PS3='Alignment: '
options=("Coin ↑↓" "Medal ↑↑" "Variable ↺")
select opt in "${options[@]}"
do
  alignment=$opt
  break
done
metadata+=( "alignment" )

PS3='Edge: '
options=("Plain" "Reeded" "Plain, incuse lettering" "Reeded, incluse lettering" "Grooved" "Other")
select opt in "${options[@]}"
do
  edge=$opt
  case $opt in
  "Other")
    echo -n "Other edge type: "
    read -r edge
    break
    ;;
  esac
  break
done
metadata+=( "edge" )

echo -n "Mint: "
read -r mint
metadata+=( "mint" )

echo -n "References: "
read -r ref
metadata+=( "ref" )

for idx in "${!metadata[@]}"
do
  arg=${metadata[$idx]}
  sed -i -e "s/@$arg@/${!arg}/g" "$folder_name/index.md"
done

read -p "Edit? [y/N] " edit
case $edit in
	[yY] )
	    nano "$folder_name/index.md"
		break;;
	* ) exit;;
esac
