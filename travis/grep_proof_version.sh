#!/bin/bash

# Copyright 2018, OpenSoft Inc.
# All rights reserved.

# Redistribution and use in source and binary forms, with or without modification, are permitted
# provided that the following conditions are met:

#     * Redistributions of source code must retain the above copyright notice, this list of
# conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright notice, this list of
# conditions and the following disclaimer in the documentation and/or other materials provided
# with the distribution.
#     * Neither the name of OpenSoft Inc. nor the names of its contributors may be used to endorse
# or promote products derived from this software without specific prior written permission.

# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER
# IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT
# OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Author: denis.kormalev@opensoftdev.com (Denis Kormalev)

EMPTY="PROOF_VERSION=0"
PATTERN="s;^PROOF_VERSION.*= *\([[:digit:]]\);\1;"
FEATURE=$1/features/proof_common.prf

PROOF_VMAJOR=`(grep $FEATURE -e "^PROOF_VERSION_MAJOR" 2> /dev/null || echo "$EMPTY") | sed "$PATTERN"`;
PROOF_VYEAR=`(grep $FEATURE -e "^PROOF_VERSION_YEAR" 2> /dev/null || echo "$EMPTY") | sed "$PATTERN"`;
PROOF_VMONTH=`(grep $FEATURE -e "^PROOF_VERSION_MONTH" 2> /dev/null || echo "$EMPTY") | sed "$PATTERN"`;
PROOF_VDAY=`(grep $FEATURE -e "^PROOF_VERSION_DAY" 2> /dev/null || echo "$EMPTY") | sed "$PATTERN"`;
echo "$PROOF_VMAJOR.$PROOF_VYEAR.$PROOF_VMONTH.$PROOF_VDAY"
