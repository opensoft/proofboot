#!/bin/bash
set -e

QML_IMPORTS=$(grep -hR --include="*.qml" "import Proof\." "$2" | awk '{print $2}' | sort | uniq)
IMPORTS_STABILIZED=0
while [ $IMPORTS_STABILIZED -eq 0 ]; do
    OLD_QML_IMPORTS="$QML_IMPORTS"
    FOUND_IMPORTS=$( for import in $QML_IMPORTS; do
        possible_import_path=$PROOF_PATH/qml/`echo $import | tr -s '.' '/'`
        if [ -f $possible_import_path/qmldir ]; then
            grep -hR --include="*.qml" "import Proof\." "$possible_import_path" | awk '{print $2}'
        fi
    done )
    QML_IMPORTS=`(echo "$QML_IMPORTS"; echo "$FOUND_IMPORTS") | sort | uniq`
    if [[ $QML_IMPORTS = $OLD_QML_IMPORTS ]]; then
        IMPORTS_STABILIZED=1
    fi
done

echo "Copying Proof QML imports to $1/imports:"
for import in $QML_IMPORTS; do
    possible_import_dir=`echo $import | tr -s '.' '/'`
    possible_import_path=$PROOF_PATH/imports/$possible_import_dir
    if [ -f $possible_import_path/qmldir ]; then
        echo "$possible_import_path"
        mkdir -p "$1/imports/$possible_import_dir";
        cp -R "$possible_import_path"/* "$1/imports/$possible_import_dir/";
    fi
done
echo "Proof QML imports copied"

PROOF_LIBS=$( for l in $(find "$1" -type f \( -executable -o -name "*.so" \) -exec ldd "{}" \; | awk '{print $1}' | sort | uniq); do
    find $PROOF_PATH -name "$(basename $l)"
done | sort | uniq )

echo -e "Copying Proof libs to $1/lib:\n$PROOF_LIBS"
if [ -n "$PROOF_LIBS" ]; then
    mkdir -p "$1/lib";
    cp -t "$1/lib" $PROOF_LIBS;
fi
echo "Proof libs copied"
