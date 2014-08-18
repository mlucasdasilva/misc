#!/bin/bash

mkrepo(){
    git init
    git add .
    git commit -m "tidy code" &> /dev/null
}

cleanrepo(){
    rm .git -rf
}

tidyEndBlankLine(){
    pattern="new blank line at EOF."
    func='$d'

    for file in `grep "$pattern" $1 | awk -F':' '{print $1}' | uniq`; do
        sed -i "$func" $file
    done
}

tidySpanceBeforeTab(){
    pattern="space before tab in indent."
    func='s/\t/    /g'

    for file in `grep "$pattern" $1 | awk -F':' '{print $1}' | uniq`; do
        sed -i "$func" $file
    done
}

tidyWhitespace(){
    pattern="trailing whitespace."
    func1='s/ *$//g'
    func2='s/\t*$//g'

    for file in `grep "$pattern" $1 | awk -F':' '{print $1}' | uniq`; do
        sed -i "$func1" $file
        sed -i "$func2" $file
    done
}

tidyWhitespaceAndTab(){
    pattern="trailing whitespace, space before tab in indent."

    tidyWhitespace $1
    tidySpanceBeforeTab $1
}

dosTounix(){
    pattern="trailing whitespace."

    for file in `grep "$pattern" $1 | awk -F':' '{print $1}' | uniq`; do
        dos2unix $file
    done
}

#main
tempfile=$(mktemp)
myself=$(basename $0)

cleanrepo
mkrepo
git show --check | grep -v $myself | grep -v $tempfile > $tempfile
dosTounix $tempfile

sum=1000
while [ $sum -gt 6 ]; do
    cleanrepo
    mkrepo
    git show --check | grep -v $myself | grep -v $tempfile > $tempfile
    sum=$(git show --check | wc -l)
    tidyWhitespace $tempfile
    tidySpanceBeforeTab $tempfile
    tidyEndBlankLine $tempfile
done

cleanrepo

rm -f $tempfile
