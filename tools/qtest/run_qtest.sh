#!/bin/bash
set -euo pipefail

APK_FILE=$1 # e.g., xx.apk
OUTPUT_DIR=$2
TEST_TIME=$3 # e.g., 10s, 10m, 10h

AVD_SERIAL=emulator-5554 # e.g., emulator-5554
AVD_NAME=api_28 # e.g., base
HEADLESS=-no-window # e.g., -no-window

TOOL_DIR=/Q-testing
TOOL_NAME=qtesting

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

app_package_name=$(../base/get_package_name.sh $APK_FILE)

result_dir=$(../base/create_result_dir.sh $APK_FILE $OUTPUT_DIR $AVD_SERIAL $AVD_NAME $TOOL_NAME)
echo "** CREATING RESULT DIR (${AVD_SERIAL}): " $result_dir

../base/run_emulator.sh $AVD_SERIAL $AVD_NAME $HEADLESS $result_dir $app_package_name

../base/install_app.sh $APK_FILE $AVD_SERIAL $result_dir

../base/screenshot.sh $AVD_SERIAL $result_dir 2>&1 | tee $result_dir/screenshots.log &

### create config file before running qtesting
config_file=$TOOL_DIR/"Config_"${apk_file_name%.apk}-${AVD_SERIAL}".txt"
rm -rf $config_file
touch $config_file
echo "[Path]" >> $config_file
real_path_of_qtesting=$(realpath $TOOL_DIR)
echo "Benchmark = ${real_path_of_qtesting}/subjects/" >> $config_file
unique_apk_file_name=$AVD_SERIAL-${apk_file_name%.*}".apk"
mkdir -p $TOOL_DIR/subjects
cp $APK_FILE $TOOL_DIR/subjects/$unique_apk_file_name
echo "APK_NAME = ${unique_apk_file_name}" >> $config_file
echo "" >> $config_file
echo "" >> $config_file
echo "# For instrumented APKs" >> $config_file
echo "APP_SOURCE_PATH = /Users/Your_Name/Projects/test" >> $config_file
echo "MANIFEST_FILE = /Users/Your_Name/Projects/test/src/main/AndroidManifest.xml" >> $config_file
echo "" >> $config_file
echo "" >> $config_file
echo "[Setting]" >> $config_file
echo "DEVICE_ID = ${AVD_SERIAL}" >> $config_file
echo "TIME_LIMIT = 21600" >> $config_file
echo "test_index = 0" >> $config_file

# delete the old output dir if exists
rm -rf ${real_path_of_qtesting}/subjects/"${AVD_SERIAL}*"
### end

# run Q-testing
echo "** RUN Q-testing (${AVD_SERIAL})"
adb -s $AVD_SERIAL shell date "+%Y-%m-%d-%H:%M:%S" >> $result_dir/qtesting_testing_time_on_emulator.txt
cd ${TOOL_DIR} || exit
config_file_name=$(basename $config_file)
tool_exit=0
timeout $TEST_TIME ${TOOL_DIR}/main -r $config_file_name > $result_dir/q-testing.log 2>&1 || tool_exit=$?
# add an additional package: -p com.android.camera
adb -s $AVD_SERIAL shell date "+%Y-%m-%d-%H:%M:%S" >> $result_dir/qtesting_testing_time_on_emulator.txt

# stop Q-testing
echo "** STOP Q-testing (${AVD_SERIAL})"

../base/stop_emulator.sh $AVD_SERIAL

echo "@@@@@@ Finish (${AVD_SERIAL}): " $app_package_name "@@@@@@@"
exit $tool_exit
