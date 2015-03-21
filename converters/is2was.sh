#!/bin/sh
# gres - grep and substitute get$ to set$
for file in `find $1 -type f` 
do
    sed -e '1,$s/is\$/was\$/g' < $file > s && mv s $file
done
