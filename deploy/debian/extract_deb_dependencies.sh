#!/bin/bash

if [ -z "$VERSION_CHECK_PATTERN" ]; then
    VERSION_CHECK_PATTERN=ALL
fi

LIBS=`find "$1" -type f \( -executable -o -name "*.so" \) -exec ldd "{}" \; | awk '{print $1}' | sort | uniq`

for l in $LIBS; do
    IGNORE=0
    package=`find $(echo $LD_LIBRARY_PATH | sed "s/:/ /g") /lib /usr/lib -name "$(basename $l)" -exec dpkg -S '{}' \; -quit | awk -F: '{print $1}'`
    if [ -z "$package" ]; then
        continue
    fi

    for p in $(echo $IGNORE_PACKAGES_PATTERN | tr -s ':' ' '); do
        echo $package | grep -q $p &> /dev/null
        if [ $? -eq 0 ]; then
            IGNORE=1
            break
        fi
    done

    test $IGNORE -ne 0 && continue

    dpkg -s "$package" &> /dev/null
    if [ $? -ne 0 ]; then
        continue
    fi

    echo -n $package
    if [ "x$VERSION_CHECK_PATTERN" == "xALL" ]; then
        echo -n \ \(\>=`dpkg -s "$package" | grep -m 1 -e "Version:" | awk '{print $2}'`\)
    else
        for p in $(echo $VERSION_CHECK_PATTERN | tr -s ':' ' '); do
             echo $package | grep -q $p &> /dev/null
             if [ $? -eq 0 ]; then
                echo -n \ \(\>=`dpkg -s "$package" | grep -m 1 -e "Version:" | awk '{print $2}'`\)
                break
             fi
        done
    fi
    echo
done | sort | uniq
