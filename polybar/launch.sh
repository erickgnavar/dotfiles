#!/usr/bin/env bash
set -euo pipefail

killall -q polybar
polybar -c ~/.config/polybar/config.ini
