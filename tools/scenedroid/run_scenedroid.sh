#!/bin/bash
set -euo pipefail

APK_FILE=$1 # e.g., xx.apk
OUTPUT_DIR=$2
TEST_TIME=$3 # e.g., 10s, 10m, 10h

AVD_SERIAL=emulator-5554 # e.g., emulator-5554
AVD_NAME=api_28 # e.g., base
HEADLESS=-no-window # e.g., -no-window

TOOL_DIR=./SceneDroid
TOOL_NAME=scenedroid

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

current_dir=$(pwd)


app_package_name=$(../base/get_package_name.sh $APK_FILE)

result_dir=$(../base/create_result_dir.sh $APK_FILE $OUTPUT_DIR $AVD_SERIAL $AVD_NAME $TOOL_NAME)
#apk_file_name=`basename $APK_FILE`
#result_dir=$OUTPUT_DIR/$apk_file_name.$TOOL_NAME.result.$AVD_SERIAL.$AVD_NAME
echo "** CREATING RESULT DIR (${AVD_SERIAL}): " $result_dir

../base/run_emulator.sh $AVD_SERIAL $AVD_NAME $HEADLESS $result_dir $app_package_name

# run SceneDroid
echo "** RUN SceneDroid (${AVD_SERIAL})"
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL
cd $TOOL_DIR
tool_exit=0
python3 main_ATGEmpirical.py --apk_file $APK_FILE --result $result_dir --timeout $TEST_TIME --emulator_name $AVD_SERIAL 2>&1 | tee $result_dir/scenedroid.log || tool_exit=$?
cd $current_dir
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL

../base/stop_emulator.sh $AVD_SERIAL

echo "@@@@@@ Finish (${AVD_SERIAL}): " $app_package_name "@@@@@@@"
exit $tool_exit
