#!/bin/bash

# 1. AWSアカウントを選択 (AWSプロファイ名を入力)
echo "Enter AWS Profile Name:"
read aws_profile

# 2. クラスター一覧を表示し選択
clusters=$(aws ecs list-clusters --profile $aws_profile | jq -r .clusterArns[] | awk -F '/' '{print $2}')
cluster=$(echo "$clusters" | fzf --prompt "Select a cluster: ")
if [ -z "$cluster" ]; then
    echo "No cluster selected. Exiting."
    exit 1
fi

# 3. タスク一覧を取得
tasks=$(aws ecs list-tasks --cluster $cluster --profile $aws_profile | jq -r .taskArns[])

declare -a container_task_pairs

for task in $tasks; do
    containers=$(aws ecs describe-tasks --cluster $cluster --tasks $task --profile $aws_profile | jq -r .tasks[].containers[].name)
    for container in $containers; do
        container_task_pairs+=("$container@$task")
    done
done

container_task_pair=$(printf "%s\n" "${container_task_pairs[@]}" | fzf --prompt "Select a container: ")
if [ -z "$container_task_pair" ]; then
    echo "No container selected. Exiting."
    exit 1
fi

IFS="@" read -r container task <<< "$container_task_pair"

# 4. 情報をもとにコマンドを実行
cmd="aws ecs execute-command \
--cluster $cluster \
--task $task \
--container $container \
--interactive \
--command \"/bin/sh\" \
--profile $aws_profile"

echo "Executing command:"
echo $cmd
eval $cmd
