#!/bin/bash

LOGFILE=$1

if [ -z "$LOGFILE" ]; then
  LOGFILE=$(ls -t jsc-tests-*.log | head -1)
fi

count() {
  grep -c "$1" $LOGFILE
}

count_uniq () {
  grep "$1" $LOGFILE | sed 's/\.js.*/\.js/' | sort | uniq | wc -l
}

TESTS_DONE=$(count '^Running')
# Initial message starting run-jsc-stress-tests starts with "Running"
((TESTS_DONE--))
TESTS_UNIQ_DONE=$(count_uniq '^Running')
((TESTS_UNIQ_DONE--))
TESTS_FAIL=$(count '^FAIL')
TESTS_UNIQ_FAIL=$(count_uniq '^FAIL')
TESTS_TIMEOUT=$(count 'Timed out')
TESTS_UNIQ_TIMEOUT=$(count_uniq 'Timed out')


echo "=== Quick summary of $LOGFILE ==="
echo -e "\t\tTests\tUnique tests"
echo -e "Run:\t\t$TESTS_DONE\t$TESTS_UNIQ_DONE"
echo -e "Fail:\t\t$TESTS_FAIL\t$TESTS_UNIQ_FAIL"
echo -e "Timeout:\t$TESTS_TIMEOUT\t$TESTS_UNIQ_TIMEOUT"
