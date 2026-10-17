#!/bin/bash
# Q8：repair 时识别并停止采集器、修复 HTTP 服务；cleanup 时停止修复后的服务。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

action=${3:-repair}
# TODO：删除下方提示和 exit 77，再填写你的命令。
source "$input/process.env"
source "$input/server.conf"

service_dir="$output/service"

stop_pid() {
    local pid="$1"
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        for _ in $(seq 1 10); do
            kill -0 "$pid" 2>/dev/null || return 0
            sleep 0.1
        done
        kill -9 "$pid" 2>/dev/null || true
    fi
}

if [ "$action" = "repair" ]; then
    ps -p "$TARGET_PID" -o pid=,user=,stat=,args= > "$output/process.txt" || true

    : > "$output/collector-sample.log"
    for _ in $(seq 1 10); do
        if [ -f "$WORKER_LOG" ]; then
            grep 'TICK' "$WORKER_LOG" | tail -n 2 >> "$output/collector-sample.log" || true
            [ -s "$output/collector-sample.log" ] && break
        fi
        sleep 0.1
    done

    stop_pid "$TARGET_PID"
    stop_pid "$SERVICE_PID"

    cat > "$output/server.conf" <<EOF
bind=127.0.0.1
port=$TARGET_PORT
route=/status
EOF

    rm -rf "$service_dir"
    mkdir -p "$service_dir"
    bash "$START_TOOL" "$output/server.conf" "$service_dir" > /dev/null 2>&1 || true

    for _ in $(seq 1 10); do
        if curl -fsS --max-time 0.2 "http://127.0.0.1:$TARGET_PORT/status" -o "$output/http-body.txt" -w '%{http_code}\n' > "$output/http-status.txt" 2>/dev/null; then
            if [ "$(cat "$output/http-status.txt")" = "200" ]; then
                break
            fi
        fi
        sleep 0.1
    done

elif [ "$action" = "cleanup" ]; then
    if [ -f "$service_dir/pid" ]; then
        stop_pid "$(cat "$service_dir/pid")"
    fi
    for _ in $(seq 1 10); do
        if ! ss -ltn 2>/dev/null | grep -q ":$TARGET_PORT "; then
            break
        fi
        sleep 0.1
    done
fi
