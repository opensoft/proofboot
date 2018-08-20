#!/bin/bash

if [ -z "$ERRORS_FILE" ]; then
    ERRORS_FILE="$HOME/builder_logs/errors.log";
fi

if [ -z "$ERRORS_TOLERANCE_LEVEL" ]; then
    ERRORS_TOLERANCE_LEVEL=0
fi

FOUND=1;

if [ ! -f "$ERRORS_FILE" ]; then
    FOUND=0;
elif [ `grep -sc -v '^ *$' "$ERRORS_FILE"` -le "$ERRORS_TOLERANCE_LEVEL" ]; then
    FOUND=0;
fi

if [ $FOUND -eq 0 ]; then
    echo -e "\033[1;35mNo messages to stderr from $1!\033[0m";
else
    echo -e "\033[1;35mMessages to stderr from $1:\033[0m";
    cat $ERRORS_FILE;
fi

exit $FOUND
