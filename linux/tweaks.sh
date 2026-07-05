#!bin/bash

# sync; echo 3 > /proc/sys/vm/drop_caches

sysctl -w vm.swappiness=10
sysctl -w vm.vfs_cache_pressure=50
sysctl -w vm.dirty_background_ratio=5
sysctl -w vm.dirty_ratio=10
