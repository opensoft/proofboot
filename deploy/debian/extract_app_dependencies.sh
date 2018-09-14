#!/bin/bash

if [ -z "$VERSION_CHECK_PATTERN" ]; then
    VERSION_CHECK_PATTERN=ALL
fi

LIBS=`find "$1" -type f \( -executable -o -name "*.so*" \) -exec ldd "{}" \; | awk '{print $1}' | sort | uniq`
QT_LIBS=`find "/opt/Opensoft/Qt" -type f \( -executable -o -name "*.so*" \) -exec ldd "{}" \; | awk '{print $1}' | sort | uniq`
OPENCV_LIBS=`find "/usr/local/lib" -type f \( -name "libopencv*.so*" \) -exec ldd "{}" \; | awk '{print $1}' | sort | uniq`
LOCAL_LIBS=`find "$1" -type f,l \( -executable -o -name "*.so*" \) -exec basename "{}" \; | sort | uniq`
OPENCV_NEEDED=`echo "$LIBS" | grep libopencv | wc -l`
LIBS=`( echo "$LIBS"; echo "$QT_LIBS"; echo "$QT_LIBS"; echo "$OPENCV_LIBS"; echo "$OPENCV_LIBS"; echo "$LOCAL_LIBS"; echo "$LOCAL_LIBS" ) | sort | uniq -u`

FOUND_PACKAGES=$( (echo "qt5-opensoft"; echo "qca-opensoft"; test $OPENCV_NEEDED -ne 0 && echo "opencv-opensoft"; for l in $LIBS; do
    IGNORE=0
    package=`find $(echo $LD_LIBRARY_PATH | sed "s/:/ /g") /lib /usr/lib /usr/local/lib -name "$(basename $l)" -exec dpkg -S '{}' \; -quit | awk -F: '{print $1}'`
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
    if [ $? -eq 0 ]; then
        echo $package
    fi
done) | sort | uniq )

for package in $FOUND_PACKAGES; do
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
done
