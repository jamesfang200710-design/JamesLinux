#!/bin/bash
# Q7：读取 input/remote.env，生成 ssh_config，用 SSH 和 SCP 获取远程数据。
# 完整接口与验收规格见 Problem.pdf。只修改本文件，不修改测试或工具。
set -eu
input=${1:?需要输入目录}
output=${2:?需要输出目录}

# TODO：删除下方提示和 exit 77，再填写你的命令。
ws="$output/sentry_ws"
mkdir -p "$ws/scripts" "$ws/config" "$ws/logs" "$ws/tmp"
touch "$ws/logs/.keep" "$ws/tmp/scratch.txt"

cat > "$ws/scripts/hello.sh" <<'EOF'
#!/bin/bash
echo "Hello, AIM Linux!"
EOF

cat > "$ws/config/robot.conf" <<'EOF'
robot=sentry
mode=training
log_level=INF0
EOF
