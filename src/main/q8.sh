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

# 辅助函数：正常停止进程
stop_pid() {
    local pid="$1"
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        for _ in $(seq 1 50); do
            kill -0 "$pid" 2>/dev/null || return 0
            sleep 0.1
        done
        kill -9 "$pid" 2>/dev/null || true
    fi
}

if [ "$action" = "repair" ]; then
    # A. 定位与停止采集器
    ps -p "$TARGET_PID" -o pid=,user=,stat=,args= > "$output/process.txt"

    # 提取 TICK 日志
    : > "$output/collector-sample.log"
    for _ in $(seq 1 50); do
        if [ -f "$WORKER_LOG" ]; then
            grep 'TICK' "$WORKER_LOG" | tail -n 2 >> "$output/collector-sample.log" || true
            [ -s "$output/collector-sample.log" ] && break
        fi
        sleep 0.1
    done

    stop_pid "$TARGET_PID"
    stop_pid "$SERVICE_PID"

    # B. 恢复 HTTP 服务
    cat > "$output/server.conf" <<EOF
bind=127.0.0.1
port=$TARGET_PORT
route=/status
EOF

    rm -rf "$service_dir"
    mkdir -p "$service_dir"
    bash "$START_TOOL" "$output/server.conf" "$service_dir"

    # 有界重试请求 HTTP
    for _ in $(seq 1 100); do
        if curl -fsS --max-time 1 "http://127.0.0.1:$TARGET_PORT/status" -o "$output/http-body.txt" -w '%{http_code}'\n > "$output/http-status.txt" 2>/dev/null; then
            if [ "$(cat "$output/http-status.txt")" = "200" ]; then
                break
            fi
        fi
        sleep 0.1
    done

elif [ "$action" = "cleanup" ]; then
    # 停止修复后的服务，保留报告
    if [ -f "$service_dir/pid" ]; then
        stop_pid "$(cat "$service_dir/pid")"
    fi
    # 等待端口释放
    for _ in $(seq 1 100); do
        if ! ss -ltn 2>/dev/null | grep -q ":$TARGET_PORT "; then
            break
        fi
        sleep 0.1
    done
fi
