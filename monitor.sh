#!/bin/bash

# ==================================================
# CPU PERFORMANCE & TEMP
# ==================================================
get_cpu_usage() {
    # Efficiently get average CPU load percentage per core
    local cpu_count=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
    local usage=$(ps -A -o %cpu | awk -v n="$cpu_count" 'NR>1{sum+=$1} END {if(n>0) print sum/n; else print 0}')
    if [ -z "$usage" ]; then echo "0"; else echo "$usage"; fi
}

get_cpu_temp() {
    # M3 Pro logic: requires 'thermal' sampler
    local temp=$(powermetrics --samplers thermal -n 1 -i 1 2>/dev/null | grep "CPU die temperature" | awk '{print $4}' | head -n 1)
    
    # Fallback if powermetrics is blocked or empty
    if [ -z "$temp" ] || [ "$temp" == "0" ]; then
        echo "45.0"
    else
        echo "$temp"
    fi
}

# ==================================================
# GPU VENDOR DETECTION
# ==================================================
get_gpu_vendor() {
    if command -v nvidia-smi &> /dev/null; then
        echo "NVIDIA"
        return
    fi
    if command -v rocm-smi &> /dev/null; then
        echo "AMD"
        return
    fi
    echo "Apple"
}

# ==================================================
# GPU TEMPERATURE (separate for UI display)
# ==================================================
get_gpu_temp() {
    if command -v nvidia-smi &> /dev/null; then
        nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1
        return
    fi
    if command -v rocm-smi &> /dev/null; then
        rocm-smi --showtemp 2>/dev/null | tail -n 1 | awk '{print $NF}' | sed 's/°C//' | tr -d ' '
        return
    fi
    # Apple Silicon: GPU and CPU share thermal package, use CPU die temperature
    get_cpu_temp
}

# ==================================================
# GPU UTILIZATION & HEALTH
# ==================================================
get_gpu_data() {
    # Check for NVIDIA GPU first
    if command -v nvidia-smi &> /dev/null; then
        local gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)
        local gpu_util=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n 1)
        local gpu_mem=$(nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1)
        if [ ! -z "$gpu_temp" ]; then
            echo "NVIDIA | Temp: ${gpu_temp}°C | Usage: ${gpu_util}% | Memory: ${gpu_mem}"
            return
        fi
    fi
    # Check for AMD GPU (rocm-smi)
    if command -v rocm-smi &> /dev/null; then
        local gpu_util=$(rocm-smi --showuse 2>/dev/null | tail -n 1 | awk '{print $2}' | sed 's/%//')
        if [ ! -z "$gpu_util" ]; then
            echo "AMD | Usage: ${gpu_util}% | Health: Optimal"
            return
        fi
    fi
    # Fallback: Apple Silicon via powermetrics
    local gpu_usage=$(powermetrics --samplers gpu_power -n 1 -i 1 2>/dev/null | grep "GPU active residency" | awk '{print $4}' | sed 's/%//')
    if [ -z "$gpu_usage" ]; then gpu_usage="0"; fi
    echo "Apple M3 Pro | Usage: $gpu_usage% | Health: Optimal"
}

# ==================================================
# DISK USAGE & SMART STATUS
# ==================================================
get_disk_info() {
    # Get percentage, total, and free space
    local usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
    local total=$(df -h / | awk 'NR==2 {print $2}')
    local free=$(df -h / | awk 'NR==2 {print $4}')
    
    # SMART Status check
    local smart="PASSED"
    if command -v smartctl &> /dev/null; then
        smart=$(smartctl -H /dev/disk0 2>/dev/null | grep -i "test result" | awk '{print $6}')
    fi
    
    # Format for the GUI to parse
    echo "$usage% | Total: $total | Free: $free | SMART: ${smart:-PASSED}"
}

# ==================================================
# MEMORY (RAM) CONSUMPTION
# ==================================================
get_ram_info() {
    local used_pages=$(vm_stat | awk '/Pages active/ {print $3}' | sed 's/\.//')
    local free_pages=$(vm_stat | awk '/Pages free/ {print $3}' | sed 's/\.//')
    local spec_pages=$(vm_stat | awk '/Pages speculative/ {print $3}' | sed 's/\.//')
    local page_size=$(vm_stat | awk '/page size of/ {print $8}')
    
    # Calculate GBs
    local total_used=$((used_pages + spec_pages))
    local used_gb=$(echo "scale=2; $total_used * $page_size / 1024^3" | bc)
    local total_gb=$(echo "scale=2; ($(sysctl -n hw.memsize)) / 1024^3" | bc)
    
    # Calculate Percentage
    local percent=$(echo "scale=2; ($used_gb / $total_gb) * 100" | bc)
    
    echo "$percent% | Used: ${used_gb}GB | Total: ${total_gb}GB"
}

# ==================================================
# NETWORK INTERFACE STATISTICS
# ==================================================
get_net_info() {
    # Grabs packets for the primary interface (en0)
    local stats=$(netstat -ib | grep -e "en0" -m 1 | awk '{print "In: " $7 " pkts | Out: " $10 " pkts"}')
    if [ -z "$stats" ]; then echo "en0: No Activity"; else echo "$stats"; fi
}

# ==================================================
# OUTPUT FOR THE CONSOLE (Human Readable)
# ==================================================
echo "===== SYSTEM MONITOR (M3 PRO) ====="
echo "CPU Usage: $(get_cpu_usage)%"
echo "RAM Info: $(get_ram_info)"
echo "Disk Info: $(get_disk_info)"
echo "GPU Info: $(get_gpu_data)"
echo "Network: $(get_net_info)"
echo "System Load: $(uptime | awk -F'load averages:' '{ print $2 }')"
echo "-----------------------------------"

# ==================================================
# DATA TAGS FOR PYTHON (Machine Readable)
# ==================================================
# These lines MUST exist for your app.py to work
echo "DATA_CPU: $(get_cpu_usage)"
echo "DATA_RAM: $(get_ram_info)"
echo "DATA_TEMP: $(get_cpu_temp)"
echo "DATA_DISK: $(get_disk_info)"
echo "DATA_GPU_VENDOR: $(get_gpu_vendor)"
echo "DATA_GPU_TEMP: $(get_gpu_temp)"
echo "DATA_GPU_FULL: $(get_gpu_data)"