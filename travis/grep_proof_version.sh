#!/bin/bash

EMPTY="PROOF_VERSION=0"
PATTERN="s;^PROOF_VERSION.*= *\([[:digit:]]\);\1;"
FEATURE=$1/features/proof_common.prf

PROOF_VMAJOR=`(grep $FEATURE -e "^PROOF_VERSION_MAJOR" 2> /dev/null || echo "$EMPTY") | sed "$PATTERN"`;
PROOF_VYEAR=`(grep $FEATURE -e "^PROOF_VERSION_YEAR" 2> /dev/null || echo "$EMPTY") | sed "$PATTERN"`;
PROOF_VMONTH=`(grep $FEATURE -e "^PROOF_VERSION_MONTH" 2> /dev/null || echo "$EMPTY") | sed "$PATTERN"`;
PROOF_VDAY=`(grep $FEATURE -e "^PROOF_VERSION_DAY" 2> /dev/null || echo "$EMPTY") | sed "$PATTERN"`;
echo "$PROOF_VMAJOR.$PROOF_VYEAR.$PROOF_VMONTH.$PROOF_VDAY"
