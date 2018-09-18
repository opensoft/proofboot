#!/usr/bin/env python3

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

import argparse
import shutil
import os

def setup_parser():
    parser = argparse.ArgumentParser(description="Translation generator for Proof")
    parser.add_argument('--target', dest='target', action='store', required=True, help='Target name')
    parser.add_argument('--ts_dir', dest='ts_dir', action='store', required=True, help='Translations dir')
    parser.add_argument('--lst', dest='ts_lst', action='store', required=True, help='File with targets for lupdate')
    parser.add_argument('--keep_ts', dest='keep_ts', action='store_true', help="Don't update ts file it was already created but outdated")
    parser.add_argument('langs', metavar='LANG', nargs='+', help='Languages to generate')
    return parser

def main():
    parser = setup_parser()
    args = parser.parse_args()

    os.chdir(args.ts_dir)

    for lang in args.langs:
        real_ts_filepath = '{0}/{1}.{2}.ts'.format(args.ts_dir, args.target, lang)
        temp_ts_filepath = '{0}/_{1}.{2}.ts'.format(args.ts_dir, args.target, lang)
        try:
            shutil.copy2(real_ts_filepath, temp_ts_filepath)
        except FileNotFoundError:
            pass

    result = 0 == os.system('lupdate @{0} -ts {1}'
                       .format(args.ts_lst,
                               ' '.join(map(lambda lang: '{0}/_{1}.{2}.ts'.format(args.ts_dir, args.target, lang), args.langs)))
                       )

    if result:
        for lang in args.langs:
            real_ts_filepath = '{0}/{1}.{2}.ts'.format(args.ts_dir, args.target, lang)
            temp_ts_filepath = '{0}/_{1}.{2}.ts'.format(args.ts_dir, args.target, lang)
            qm_filepath = '{0}/{1}.{2}.qm'.format(args.ts_dir, args.target, lang)

            release_needed = False
            if not args.keep_ts or not os.access(real_ts_filepath, os.F_OK) or os.stat(real_ts_filepath).st_size == 0:
                temp_ts = ""
                real_ts = ""
                try:
                    temp_ts = open(temp_ts_filepath, encoding='utf-8').read()
                except IOError:
                    result = False
                try:
                    real_ts = open(real_ts_filepath, encoding='utf-8').read()
                except IOError:
                    pass
                try:
                    if real_ts != temp_ts:
                        release_needed = True
                        shutil.copy2(temp_ts_filepath, real_ts_filepath)
                except IOError:
                    pass
            if (release_needed
            or not os.access(qm_filepath, os.F_OK)
            or os.stat(qm_filepath).st_size == 0
            or os.stat(real_ts_filepath).st_mtime > os.stat(qm_filepath).st_mtime):
                os.system('lrelease {0} -qm {1}'.format(real_ts_filepath, qm_filepath))

    for lang in args.langs:
        try:
            os.remove('{0}/_{1}.{2}.ts'.format(args.ts_dir, args.target, lang))
        except OSError:
            pass

    if not result:
        quit(1)

main()
