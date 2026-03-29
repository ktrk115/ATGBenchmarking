#!/bin/bash
set -euo pipefail

APK_FILE=$1 # e.g., xx.apk
OUTPUT_DIR=$2
TEST_TIME=$3 # e.g., 10s, 10m, 10h

AVD_SERIAL=emulator-5554 # e.g., emulator-5554
AVD_NAME=api_28 # e.g., base
HEADLESS=-no-window # e.g., -no-window

TOOL_DIR=./Fastbot_Android
TOOL_NAME=fastbot

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

app_package_name=$(../base/get_package_name.sh $APK_FILE)

result_dir=$(../base/create_result_dir.sh $APK_FILE $OUTPUT_DIR $AVD_SERIAL $AVD_NAME $TOOL_NAME)
echo "** CREATING RESULT DIR (${AVD_SERIAL}): " $result_dir

../base/run_emulator.sh $AVD_SERIAL $AVD_NAME $HEADLESS $result_dir $app_package_name

../base/install_app.sh $APK_FILE $AVD_SERIAL $result_dir

sleep 20

# install Fastbot
echo "** INSTALL Fastbot (${AVD_SERIAL})"
adb -s $AVD_SERIAL push $TOOL_DIR/monkeyq.jar /sdcard/monkeyq.jar
adb -s $AVD_SERIAL push $TOOL_DIR/fastbot-thirdpart.jar /sdcard/fastbot-thirdpart.jar
adb -s $AVD_SERIAL push $TOOL_DIR/libs/* /data/local/tmp/
adb -s $AVD_SERIAL push $TOOL_DIR/framework.jar /sdcard/framework.jar

cat <<EOL > /max.config
max.randomPickFromStringList = false
max.takeScreenshot = true
max.takeScreenshotForEveryStep = true
max.saveGUITreeToXmlEveryStep = true
max.execSchema = true
max.execSchemaEveryStartup = true
max.grantAllPermission = true
EOL

head /max.config

adb -s $AVD_SERIAL push /max.config /sdcard

# pull Fastbot's results
echo "** PULL FASTBOT RESULTS (${AVD_SERIAL})"
mkdir -p $result_dir/sdcard_log
function pull_fastbot_results() {
  echo "start to pulling fastbot results..."
  while true; do
    echo "pulling fastbot results..."
    adb -s $AVD_SERIAL pull /sdcard/crash-dump.log $result_dir/
    adb -s $AVD_SERIAL pull /sdcard/log/ $result_dir/sdcard_log/
    sleep 60
  done
}

pull_fastbot_results &

# run fastbot
echo "** RUN FASTBOT (${AVD_SERIAL})"
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL
tool_exit=0
timeout $TEST_TIME adb -s $AVD_SERIAL shell CLASSPATH=/sdcard/monkeyq.jar:/sdcard/framework.jar:/sdcard/fastbot-thirdpart.jar exec app_process /system/bin com.android.commands.monkey.Monkey -p $app_package_name --agent robot --running-minutes $TEST_TIME --throttle 200 -v -v --output-directory /sdcard/log --bugreport 1000000 2>&1 | tee $result_dir/fastbot.log || tool_exit=$?
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL

kill %1 2>/dev/null || true

../base/stop_emulator.sh $AVD_SERIAL

echo "@@@@@@ Finish (${AVD_SERIAL}): " $app_package_name "@@@@@@@"
exit $tool_exit
