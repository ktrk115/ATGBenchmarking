#!/bin/bash
set -euo pipefail

APK_FILE=$1 # e.g., xx.apk
OUTPUT_DIR=$2
TEST_TIME=$3 # e.g., 10s, 10m, 10h

AVD_SERIAL=emulator-5554 # e.g., emulator-5554
AVD_NAME=api_28 # e.g., base
HEADLESS=-no-window # e.g., -no-window

TOOL_DIR=./ape-bin
TOOL_NAME=ape

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

app_package_name=$(../base/get_package_name.sh $APK_FILE)

result_dir=$(../base/create_result_dir.sh $APK_FILE $OUTPUT_DIR $AVD_SERIAL $AVD_NAME $TOOL_NAME)
echo "** CREATING RESULT DIR (${AVD_SERIAL}): " $result_dir

../base/run_emulator.sh $AVD_SERIAL $AVD_NAME $HEADLESS $result_dir $app_package_name

../base/install_app.sh $APK_FILE $AVD_SERIAL $result_dir


# install Ape
sleep 20
adb -s $AVD_SERIAL push $TOOL_DIR/ape.jar /data/local/tmp/
echo "** INSTALL Ape (${AVD_SERIAL})"

adb -s $AVD_SERIAL shell cd /data/local/tmp/ \; chmod 777 ape.jar

#../base/screenshot.sh $AVD_SERIAL $result_dir 2>&1 | tee $result_dir/screenshots.log &

# pull Fastbot's results
echo "** PULL FASTBOT RESULTS (${AVD_SERIAL})"
mkdir -p $result_dir/sdcard_log
function pull_results() {
  echo "start to pulling ape results..."
  while true; do
    echo "pulling ape results..."
    adb -s $AVD_SERIAL pull /sdcard/ $result_dir/sdcard_log/
    sleep 60
  done
}

pull_results &

sleep 10
# run Ape
echo "** RUN APE (${AVD_SERIAL})"
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL
tool_exit=0
timeout $TEST_TIME adb -s $AVD_SERIAL shell CLASSPATH=/data/local/tmp/ape.jar /system/bin/app_process /data/local/tmp/ com.android.commands.monkey.Monkey -p $app_package_name --running-minutes 360 --ape sata 2>&1 | tee $result_dir/ape.log || tool_exit=$?
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL

# pull Ape's results
echo "** PULL APE RESULTS (${AVD_SERIAL})"
adb -s $AVD_SERIAL pull /sdcard/sata-${app_package_name}-ape-sata-running-minutes-360 $result_dir/ || true

kill %1 2>/dev/null || true

../base/stop_emulator.sh $AVD_SERIAL

echo "@@@@@@ Finish (${AVD_SERIAL}): " $app_package_name "@@@@@@@"
exit $tool_exit
