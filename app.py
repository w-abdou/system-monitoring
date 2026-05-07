from flask import Flask, jsonify, render_template
import subprocess
import re
import time

app = Flask(__name__)

# Cache for stats to avoid calling monitor.sh too often
_stats_cache = {"data": None, "timestamp": 0}
CACHE_TTL = 3  # seconds

def get_hardware_names():
    try:
        cpu = subprocess.check_output(['sysctl', '-n', 'machdep.cpu.brand_string']).decode().strip()
        gpu_info = subprocess.check_output(['system_profiler', 'SPDisplaysDataType']).decode()
        m = re.search(r'Chipset Model: (.*)', gpu_info)
        gpu = m.group(1) if m else "Apple GPU"
        return cpu, gpu
    except:
        return "Apple Silicon", "Apple GPU"

@app.route('/')
def index():
    cpu, gpu = get_hardware_names()
    return render_template('index.html', cpu_name=cpu, gpu_name=gpu)

@app.route('/api/stats')
def get_stats():
    global _stats_cache
    now = time.time()
    
    # Return cached data if still valid
    if _stats_cache["data"] and (now - _stats_cache["timestamp"]) < CACHE_TTL:
        return jsonify(_stats_cache["data"])
    
    try:
        raw_output = subprocess.check_output(['bash', './monitor.sh'], stderr=subprocess.STDOUT, timeout=10).decode('utf-8')
        
        # CPU, RAM, TEMP, DISK
        cpu = re.search(r'DATA_CPU:\s+([0-9.]+)', raw_output)
        ram_line = re.search(r'DATA_RAM:\s+([0-9.]+%\s*\|\s*Used:\s*[^\s]+\s*\|\s*Total:\s*[^\s]+)', raw_output)
        temp = re.search(r'DATA_TEMP:\s+([0-9.]+)', raw_output)
        disk_line = re.search(r'DATA_DISK:\s+([0-9.]+%\s*\|\s*Total:\s*[^\s]+\s*\|\s*Free:\s*[^\s]+\s*\|\s*SMART:\s*\w+)', raw_output)
        
        # GPU fields
        gpu_vendor = re.search(r'DATA_GPU_VENDOR:\s+(\w+)', raw_output)
        gpu_temp = re.search(r'DATA_GPU_TEMP:\s+(.+?)(?:\n|$)', raw_output)
        gpu_full = re.search(r'DATA_GPU_FULL:\s+(.+?)(?:\n|$)', raw_output)
        
        # Extract SMART and network
        smart = re.search(r'SMART:\s+(\w+)', raw_output)
        network = re.search(r'Network:\s+(.*)', raw_output)
        
        # Parse RAM: "20.00% | Used: 3.70GB | Total: 18.00GB"
        ram_percent = 0
        ram_used = "0GB"
        ram_total = "0GB"
        if ram_line:
            full_ram = ram_line.group(1)
            # Extract percent: "20.00%"
            pct_match = re.search(r'([0-9.]+)%', full_ram)
            if pct_match:
                ram_percent = float(pct_match.group(1))
            # Extract Used: "3.70GB"
            used_match = re.search(r'Used:\s*([0-9.]+GB)', full_ram)
            if used_match:
                ram_used = used_match.group(1)
            # Extract Total: "18.00GB"
            total_match = re.search(r'Total:\s*([0-9.]+GB)', full_ram)
            if total_match:
                ram_total = total_match.group(1)
        
        # Parse Disk: "22% | Total: 460Gi | Free: 51Gi | SMART: PASSED"
        disk_percent = 0
        disk_total = "0GB"
        disk_free = "0GB"
        if disk_line:
            full_disk = disk_line.group(1)
            # Extract percent: "22%"
            pct_match = re.search(r'([0-9.]+)%', full_disk)
            if pct_match:
                disk_percent = float(pct_match.group(1))
            # Extract Total: "460Gi"
            total_match = re.search(r'Total:\s*([0-9.]+[GTM]i?)', full_disk)
            if total_match:
                disk_total = total_match.group(1)
            # Extract Free: "51Gi"
            free_match = re.search(r'Free:\s*([0-9.]+[GTM]i?)', full_disk)
            if free_match:
                disk_free = free_match.group(1)
        
        result = {
            "cpu": float(cpu.group(1)) if cpu else 0,
            "ram": ram_percent,
            "ram_used": ram_used,
            "ram_total": ram_total,
            "temp": float(temp.group(1)) if temp else 0,
            "disk": disk_percent,
            "disk_total": disk_total,
            "disk_free": disk_free,
            "smart": smart.group(1) if smart else "N/A",
            "network": network.group(1) if network else "No Link",
            "gpu_vendor": gpu_vendor.group(1) if gpu_vendor else "Unknown",
            "gpu_temp": gpu_temp.group(1) if gpu_temp else "N/A",
            "gpu_full": gpu_full.group(1) if gpu_full else "N/A",
            "raw": raw_output
        }
        
        # Cache the result
        _stats_cache = {"data": result, "timestamp": now}
        return jsonify(result)
    except subprocess.TimeoutExpired as e:
        return jsonify({"error": "monitor.sh timeout", "raw": (e.output.decode('utf-8', errors='ignore') if e.output else '')}), 500
    except subprocess.CalledProcessError as e:
        out = e.output.decode('utf-8', errors='ignore') if e.output else ''
        return jsonify({"error": "monitor.sh failed", "raw": out}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500
if __name__ == '__main__':
    app.run(debug=True, port=8080)