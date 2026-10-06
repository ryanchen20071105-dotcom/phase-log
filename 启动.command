#!/bin/zsh
# 打开阶段日志：优先打开同一文件夹里的 App；还没编译 App 时退回浏览器版
cd "$(dirname "$0")"
if [[ -d "阶段日志.app" ]]; then
  open "阶段日志.app"
else
  PY=$(command -v python3 || echo /usr/bin/python3)
  "$PY" server.py
fi
