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

import sys
import subprocess
from contextlib import contextmanager

@contextmanager
def travis_fold(name):
    sys.stdout.write('\033[1;33mRunning {} tests...\033[0m\n'.format(name))
    sys.stdout.write('travis_fold:start:tests.{}\r'.format(name))
    sys.stdout.flush()
    yield
    sys.stdout.write('travis_fold:end:tests.{}\r'.format(name))

def run_in_docker(command):
    docker_status = subprocess.call('docker run -id --name runner '
                                   '-v $HOME/proof-bin:/opt/Opensoft/proof opensoftdev/proof-runner tail -f /dev/null',
                                   shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if docker_status != 0:
        subprocess.call('docker rm runner --force',
                       shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return (False, False)
    docker_status = subprocess.call('docker exec runner bash -c "mkdir -p /root/.config/Opensoft '
                                   '&& echo \"proof.*=false\" > /root/.config/Opensoft/proof_tests.qtlogging.rules"',
                                   shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if docker_status != 0:
        subprocess.call('docker rm runner --force',
                       shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return (False, False)
    test_status = subprocess.call(['docker', 'exec', '-t', 'runner', command])
    docker_status = subprocess.call('docker rm runner --force',
                                   shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return (docker_status == 0, test_status == 0)

def run_test(name):
    passed = False
    docker_succeeded = True
    with travis_fold(name):
        docker_succeeded, passed = run_in_docker('/opt/Opensoft/proof/tests/{}_tests'.format(name))
    if not docker_succeeded:
        sys.stdout.write('\033[1;31mDocker manipulation failed on {}. Exiting\033[0m\n'.format(name))
        sys.exit(1)
    sys.stdout.write('\033[1;32mTests for {} passed!\033[0m\n'.format(name) if passed else '\033[1;31mTests for {} failed!\033[0m\n'.format(name))
    return passed

print("Selected suites:", sys.argv[1:])
print(" ")
result = True
for test_name in sys.argv[1:]:
    result = run_test(test_name) and result

if not result:
    sys.exit(2)
