#!/bin/bash
set -euo pipefail

APK_FILE=$1 # e.g., xx.apk
OUTPUT_DIR=$2
TEST_TIME=$3 # e.g., 10s, 10m, 10h

AVD_SERIAL=emulator-5554 # e.g., emulator-5554
AVD_NAME=api_28 # e.g., base
HEADLESS=-no-window # e.g., -no-window

TOOL_DIR=./Humanoid
TOOL_NAME=humanoid

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

locale

current_dir=$(pwd)

app_package_name=$(../base/get_package_name.sh $APK_FILE)

result_dir=$(../base/create_result_dir.sh $APK_FILE $OUTPUT_DIR $AVD_SERIAL $AVD_NAME $TOOL_NAME)
echo "** CREATING RESULT DIR (${AVD_SERIAL}): " $result_dir

# run droidbot
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
cd $TOOL_DIR
pwd
kill -9 $(lsof -t -i:50405) || true
python3 agent.py -c config.json > $result_dir/agent_output.log 2>&1 &
cd $current_dir

../base/run_emulator.sh $AVD_SERIAL $AVD_NAME $HEADLESS $result_dir $app_package_name

../base/install_app.sh $APK_FILE $AVD_SERIAL $result_dir

# Check the stdout for the droidbot
while true; do
#    if there is process with port 50405, break the loop
    if lsof -i:50405 || grep "=== Humanoid RPC service ready at localhost:50405 ===" $result_dir/agent_output.log; then
        break
    fi
    sleep 10
    echo "Waiting for the agent to start..."
done

# run humandroid
echo "** RUN Humandroid (${AVD_SERIAL})"
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL
tool_exit=0
if [[ ${LOGIN_SCRIPT:-} != "" ]]
then
    timeout $TEST_TIME droidbot -d $AVD_SERIAL -a $APK_FILE -o $result_dir -timeout 21600 -count 100000 -keep_app -keep_env -random -policy dfs_greedy -humanoid localhost:50405 -grant_perm -is_emulator 2>&1 | tee $result_dir/humandroid.log || tool_exit=$?
else
    timeout $TEST_TIME droidbot -d $AVD_SERIAL -a $APK_FILE -o $result_dir -timeout 21600 -count 100000 -random -policy dfs_greedy -humanoid localhost:50405 -grant_perm -is_emulator 2>&1 | tee $result_dir/humandroid.log || tool_exit=$?
fi
../base/log_time.sh $result_dir $TOOL_NAME $AVD_SERIAL

# kill the agent
kill $(lsof -t -i:50405) 2>/dev/null || true

../base/stop_emulator.sh $AVD_SERIAL

echo "@@@@@@ Finish (${AVD_SERIAL}): " $app_package_name "@@@@@@@"
exit $tool_exit
