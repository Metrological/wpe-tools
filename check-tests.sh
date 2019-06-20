#!/bin/bash

test_log=$1

if [ -z "$test_log" ]; then
    test_log=`ls -1t jsc-tests-*.log |head -1`
fi

echo "Test results showing in ${test_log}:"
for pattern in '^Running' 'Timed out' '^FAIL'; do
    echo "$pattern:"
    grep -c "$pattern" $test_log
done
