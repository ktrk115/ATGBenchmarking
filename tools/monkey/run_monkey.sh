#!/bin/bash
set -euo pipefail

APK_FILE=$1 # e.g., xx.apk
OUTPUT_DIR=$2
TEST_TIME=$3 # e.g., 10s, 10m, 10h

AVD_SERIAL=emulator-5554 # e.g., emulator-5554
AVD_NAME=api_28 # e.g., base
HEADLESS=-no-window # e.g., -no-window

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

TOOL_NAME=monkey

app_package_name=$(../base/get_package_name.sh $APK_FILE)

result_dir=$(../base/create_result_dir.sh $APK_FILE $OUTPUT_DIR $AVD_SERIAL $AVD_NAME $TOOL_NAME)
echo "** CREATING RESULT DIR (${AVD_SERIAL}): " $result_dir

../base/run_emulator.sh $AVD_SERIAL $AVD_NAME $HEADLESS $result_dir $app_package_name

../base/install_app.sh $APK_FILE $AVD_SERIAL $result_dir

../base/screenshot.sh $AVD_SERIAL $result_dir 2>&1 | tee $result_dir/screenshots.log &

# run monkey
echo "** RUN MONKEY (${AVD_SERIAL})"
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL
tool_exit=0
timeout $TEST_TIME adb -s $AVD_SERIAL shell monkey -p $app_package_name -v --throttle 200 --ignore-crashes --ignore-timeouts --ignore-security-exceptions --bugreport 1000000 2>&1 | tee $result_dir/monkey.log || tool_exit=$?
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL

# stop monkey
echo "** STOP MONKEY (${AVD_SERIAL})"
adb -s $AVD_SERIAL shell kill $(adb -s $AVD_SERIAL shell ps | grep 'monkey' | awk '{print $2}') || true

../base/stop_emulator.sh $AVD_SERIAL

echo "@@@@@@ Finish (${AVD_SERIAL}): " $app_package_name "@@@@@@@"
exit $tool_exit
