#!/bin/bash

for file in `cat files`
do
  echo "$file"
  sed -i "s#10.45.142.33#10.27.75.166#" "$file"
done
