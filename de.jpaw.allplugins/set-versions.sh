#!/bin/bash
echo "Process for releases is:"
echo "1) merge all changes of branch develop into master"
echo "2) run this script on the master branch, with a new EVEN minor build number and NO SNAPSHOT"
echo "3) commit this into master"
echo "4) checkout develop again"
echo "5) run this script on develop, with an ODD minor build (higher than previous EVEN) and -SNAPSHOT"
echo "6) commit into develop"
if [ x$1 = x ]; then
    exit
fi
mvn versions:set -DnewVersion=$1
