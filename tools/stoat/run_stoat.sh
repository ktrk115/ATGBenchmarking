#!/bin/bash
set -euo pipefail

APK_FILE=$1 # e.g., xx.apk
OUTPUT_DIR=$2
TEST_TIME=$3 # e.g., 10s, 10m, 10h

AVD_SERIAL=emulator-5554 # e.g., emulator-5554
AVD_NAME=api_28 # e.g., base
HEADLESS=-no-window # e.g., -no-window

TOOL_DIR=./Stoat/Stoat/bin
TOOL_NAME=stoat

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

current_dir=$(pwd)

app_package_name=$(../base/get_package_name.sh $APK_FILE)

result_dir=$(../base/create_result_dir.sh $APK_FILE $OUTPUT_DIR $AVD_SERIAL $AVD_NAME $TOOL_NAME)
echo "** CREATING RESULT DIR (${AVD_SERIAL}): " $result_dir

../base/run_emulator.sh $AVD_SERIAL $AVD_NAME $HEADLESS $result_dir $app_package_name

../base/install_app.sh $APK_FILE $AVD_SERIAL $result_dir

# run Stoat
echo "** RUN STOAT (${AVD_SERIAL})"
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL
cd $TOOL_DIR
avd_port=${AVD_SERIAL:9:13}
base_num=3554
stoat_port="$(($avd_port-$base_num))"
# Split TEST_TIME into model_time (1/6) and mcmc_time (5/6) with 1:5 ratio
# Enforce a minimum of 60s for model_time so A3E has enough time to connect
MODEL_TIME_RAW=$(($TEST_TIME / 6))
if [ "$MODEL_TIME_RAW" -lt 60 ]; then MODEL_TIME_RAW=60; fi
MODEL_TIME="${MODEL_TIME_RAW}s"
MCMC_TIME="$(($TEST_TIME - $MODEL_TIME_RAW))s"
# Wrap the entire pipeline in timeout so it kills the whole process group,
# including ruby's forked children (stoat server, rec.rb, etc.)
tool_exit=0
timeout --kill-after=10 $TEST_TIME bash -c "ruby run_stoat_testing.rb --app_dir $result_dir --apk_path $APK_FILE --avd_port $avd_port --stoat_port $stoat_port --model_time $MODEL_TIME --mcmc_time $MCMC_TIME --project_type gradle 2>&1 | tee $result_dir/stoat.log" || tool_exit=$?
cd $current_dir
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL

../base/stop_emulator.sh $AVD_SERIAL

echo "@@@@@@ Finish (${AVD_SERIAL}): " $app_package_name "@@@@@@@"
exit $tool_exit
