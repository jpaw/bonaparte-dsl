#!/bin/bash
echo "Usage: set-others (oldversion) (newversion)"
if [ x$2 = x ]; then
    exit
fi
./gres $1 $2 ../*/META-INF/MANIFEST.MF
./gres $1 $2 ../*/feature.xml ../de.jpaw.updatesite/*.xml
