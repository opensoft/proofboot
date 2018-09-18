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
from pathlib import Path
import shutil

global_allow_private = True

def setup_parser():
    parser = argparse.ArgumentParser(description="Bootstrap tool for Proof")

    parser.add_argument('--src', dest='src_dir', action='store', required=True,
                       help='Directory with Proof sources (or module root if --single-module is used)')
    parser.add_argument('--dest', dest='dest_dir', action='store', required=True,
                       help='Directory where Proof will be deployed')
    parser.add_argument('--single-module', dest='single_module', action='store_true',
                       help='Bootstrap only single module (with src as path to its root)')
    parser.add_argument('--gtest-only', dest='gtest_only', action='store_true',
                       help='Bootstrap only googletest (with src as path to its root, doesn\'t work with --single-module)')
    parser.add_argument('--boot-only', dest='boot_only', action='store_true',
                       help='Bootstrap only stuff from proofboot (doesn\'t work with --single-module)')
    parser.add_argument('--skip-private', dest='allow_private', action='store_false',
                       help='Bootstrap without private parts (private headers and qml files)')
    return parser

def process_include_dir(src_path, dest_path, allow_private):
    global global_allow_private
    allow_private = allow_private and global_allow_private
    if not src_path.exists():
        print(src_path, "doesn't exist, skipping it")
        return
    if not dest_path.exists():
        dest_path.mkdir(parents=True)
    for entry in src_path.iterdir():
        entry_name = entry.name
        if entry_name[0] == ".":
            continue
        if entry.is_dir() and (allow_private or entry.name != "private"):
            process_include_dir(entry, dest_path/entry_name, allow_private)
        elif (entry_name[-2:] == ".h" or entry_name[-4:] == ".hpp") and (allow_private or (not "_p.h" in entry_name and not "_p.hpp" in entry_name)):
            shutil.copy2(entry.as_posix(), (dest_path/entry_name).as_posix())

def process_qml_dir(src_path, dest_path):
    global global_allow_private
    if not global_allow_private:
        return
    if not src_path.exists():
        print(src_path, "doesn't exist, skipping it")
        return
    if not dest_path.exists():
        dest_path.mkdir(parents=True)
    for entry in src_path.iterdir():
        entry_name = entry.name
        if entry_name[0] == ".":
            continue
        if entry.is_dir():
            process_qml_dir(entry, dest_path/entry_name)
        elif entry_name[-3:] == ".js" or entry_name[-4:] == ".qml" or entry_name == "qmldir":
            shutil.copy2(entry.as_posix(), (dest_path/entry_name).as_posix())

def copy_dir(src_path, dest_path):
    if not dest_path.exists():
        dest_path.mkdir(parents=True)
    for entry in src_path.iterdir():
        entry_name = entry.name
        if entry_name[0] == ".":
            continue
        if entry.is_file():
            shutil.copy2(entry.as_posix(), (dest_path/entry_name).as_posix())
        elif entry.is_dir():
            copy_dir(entry, dest_path/entry_name)

def process_module(src_module_path, dest_path):
    process_include_dir(src_module_path/"include", dest_path/"include", True)
    process_include_dir(src_module_path/"3rdparty", dest_path/"include/3rdparty", False)
    process_qml_dir(src_module_path/"qml", dest_path/"qml")
    copy_dir(src_module_path/"features", dest_path/"features")
    if (src_module_path/"android/common").exists():
        copy_dir(src_module_path/"android/common", dest_path/"android")
        copy_dir(src_module_path/"android/common", dest_path/"android/common")
    if (src_module_path/"android/stations").exists():
        copy_dir(src_module_path/"android/stations", dest_path/"android")
    extra_boot_path = src_module_path/"boot"
    if extra_boot_path.exists():
        for entry in extra_boot_path.iterdir():
            entry_name = entry.name
            if entry_name[0] == ".":
                continue
            if entry_name[-3:] == ".py" or entry_name[-4:] == ".pri":
                shutil.copy2(entry.as_posix(), (dest_path/entry_name).as_posix())

def process_proofboot(sources_path, dest_path):
    boot_path = sources_path/"proofboot"
    print ("Copying features...")
    copy_dir(boot_path/"features", dest_path/"features")
    print ("Features copied.")

    dest_dev_tools_path = dest_path/"dev-tools"

    if not dest_dev_tools_path.exists():
        dest_dev_tools_path.mkdir(parents=True)

    print ("Copying travis related stuff...")
    copy_dir(boot_path/"travis", dest_dev_tools_path/"travis")
    print ("Travis stuff copied.")

    print ("Copying deployment stuff...")
    copy_dir(boot_path/"deploy", dest_dev_tools_path/"deploy")
    print ("Deployment stuff copied.")

    print ("Copying project includes...")
    shutil.copy2((boot_path/"proof.pri").as_posix(), (dest_path/"proof.pri").as_posix())
    shutil.copy2((boot_path/"proof_app.pri").as_posix(), (dest_path/"proof_app.pri").as_posix())
    shutil.copy2((boot_path/"proof_qmlplugin.pri").as_posix(), (dest_path/"proof_qmlplugin.pri").as_posix())
    shutil.copy2((boot_path/"proof_service.pri").as_posix(), (dest_path/"proof_service.pri").as_posix())
    shutil.copy2((boot_path/"proof_build_package.pri").as_posix(), (dest_path/"proof_build_package.pri").as_posix())
    shutil.copy2((boot_path/"proof_functions.pri").as_posix(), (dest_path/"proof_functions.pri").as_posix())
    shutil.copy2((boot_path/"proof_translation.pri").as_posix(), (dest_path/"proof_translation.pri").as_posix())
    shutil.copy2((boot_path/"app_tests.pri").as_posix(), (dest_path/"app_tests.pri").as_posix())
    shutil.copy2((boot_path/"proof_tests.pri").as_posix(), (dest_path/"proof_tests.pri").as_posix())
    print ("Project includes copied.")

    shutil.copy2((boot_path/"generate_translation.py").as_posix(), (dest_path/"generate_translation.py").as_posix())
    print ("Translations generator script copied.")
    shutil.copy2((boot_path/"bootstrap.py").as_posix(), (dest_path/"bootstrap.py").as_posix())
    print ("Bootstrap script copied.")

def process_gtest(sources_path, dest_path):
    print ("Copying Google Test includes...")
    process_include_dir(sources_path/"gtest", dest_path/"include/gtest", False)
    shutil.copy2((sources_path/"test_global.h").as_posix(), (dest_path/"include/gtest/test_global.h").as_posix())
    shutil.copy2((sources_path/"test_fakeserver.h").as_posix(), (dest_path/"include/gtest/test_fakeserver.h").as_posix())
    print ("Google Test includes copied.")

def full_bootstrap(sources_path, dest_path):
    for module in ("proofseed", "proofbase", "proofutils", "proofgui", "proofprofit", "proofnetworkjdf", "proofnetworkonp", "proofnetworkmms", "proofnetworktracker", "proofhardware", "proofscissorhands", "proofcv", "proofhardwareslitter"):
        src_module_path = sources_path / module
        if not src_module_path.exists() or not src_module_path.is_dir():
            continue
        print ("Processing", module, "...")
        process_module(src_module_path, dest_path)
        print (module, "done")

    print ("Bootstrap finished.")

def main():
    parser = setup_parser()
    args = parser.parse_args()
    global global_allow_private
    global_allow_private = args.allow_private

    sources_path = Path(args.src_dir).resolve()
    dest_path = Path(args.dest_dir)
    if not dest_path.exists():
        dest_path.mkdir(parents=True)
    dest_path = dest_path.resolve()

    if not sources_path.exists() or not sources_path.is_dir():
        print (sources_path, " doesn't exist")
        return

    if args.single_module:
        print ("Processing", sources_path, "...")
        process_module(sources_path, dest_path)
        print (sources_path, "done")
    elif args.gtest_only:
        process_gtest(sources_path, dest_path)
    else:
        process_proofboot(sources_path, dest_path)
        if not args.boot_only:
            process_gtest(sources_path/"3rdparty/proof-gtest", dest_path)
            full_bootstrap(sources_path, dest_path)

main()
