async function updateDashboard() {
    const response = await fetch('/api/stats');
    const data = await response.json();

    // CPU, RAM, Disk bars
    document.getElementById('cpu-fill').style.width = data.cpu + '%';
    document.getElementById('ram-fill').style.width = data.ram + '%';
    document.getElementById('disk-fill').style.width = data.disk + '%';
    
    // Labels: CPU, RAM, TEMP, DISK
    document.getElementById('cpu-txt').innerText = Math.round(data.cpu) + '%';
    document.getElementById('ram-txt').innerText = Math.round(data.ram) + '%';
    const temp = parseFloat(data.temp) || 0;
    document.getElementById('temp-txt').innerText = Math.round(temp) + '°C';
    document.getElementById('disk-val').innerText = Math.round(data.disk) + '%';
    
    // RAM detail: "Used: 3.70GB / Total: 18.00GB"
    document.getElementById('ram-detail').innerText = 'Used: ' + (data.ram_used || '0GB') + ' / Total: ' + (data.ram_total || '0GB');
    
    // Disk detail: "Free: 51Gi / Total: 460Gi"
    document.getElementById('disk-detail').innerText = 'Free: ' + (data.disk_free || '0GB') + ' / Total: ' + (data.disk_total || '0GB');
    
    // Thermometer fill (height and color)
    (function updateThermometer(t){
        const minT = 20; // °C mapped to 0%
        const maxT = 100; // °C mapped to 100%
        let pct = Math.round(((t - minT) / (maxT - minT)) * 100);
        pct = Math.max(0, Math.min(100, pct));
        const fill = document.getElementById('temp-fill');
        if(fill){
            fill.style.height = pct + '%';
            fill.style.background = tempColorForPercent(pct);
        }
    })(temp);
    
    // SMART Status
    const smartTag = document.getElementById('smart-status');
    smartTag.innerText = "SMART: " + data.smart;
    smartTag.style.color = data.smart === "PASSED" ? "#10b981" : "#ef4444";
    
    // GPU Vendor and Temp
    const gpuVendorTag = document.getElementById('gpu-vendor');
    const gpuVendor = data.gpu_vendor || 'Unknown';
    gpuVendorTag.innerText = 'GPU: ' + gpuVendor;
    gpuVendorTag.style.color = gpuVendor === 'NVIDIA' ? '#76b900' : (gpuVendor === 'AMD' ? '#ed1c24' : '#a2aaad');
    
    const gpuTempVal = data.gpu_temp || 'N/A';
    const gpuTempDisplay = gpuTempVal === 'N/A' ? 'N/A' : Math.round(parseFloat(gpuTempVal)) + '°C';
    document.getElementById('gpu-temp-txt').innerText = gpuTempDisplay;
    
    document.getElementById('gpu-detail').innerText = 'Details: ' + (data.gpu_full || 'N/A');
    
    // Network
    document.getElementById('net-stats').innerText = data.network;

    // Raw console log
    document.getElementById('raw-log').innerText = data.raw;
}

// Update every 5 seconds (reduced from 2 seconds)
setInterval(updateDashboard, 5000);
updateDashboard();

// Helper: interpolate colors for thermometer
function tempColorForPercent(pct){
    // pct: 0..100
    // 0 -> green (#10b981), 50 -> yellow (#f59e0b), 100 -> red (#ef4444)
    function hexToRgb(hex){
        const h = hex.replace('#','');
        return [parseInt(h.substring(0,2),16), parseInt(h.substring(2,4),16), parseInt(h.substring(4,6),16)];
    }
    function rgbToHex(r,g,b){
        return '#'+[r,g,b].map(x=>{const s=x.toString(16);return s.length===1?'0'+s:s;}).join('');
    }
    function lerp(a,b,t){return Math.round(a + (b-a)*t);}    

    if(pct <= 50){
        const t = pct/50;
        const g = hexToRgb('#10b981');
        const y = hexToRgb('#f59e0b');
        return rgbToHex(lerp(g[0], y[0], t), lerp(g[1], y[1], t), lerp(g[2], y[2], t));
    } else {
        const t = (pct-50)/50;
        const y = hexToRgb('#f59e0b');
        const r = hexToRgb('#ef4444');
        return rgbToHex(lerp(y[0], r[0], t), lerp(y[1], r[1], t), lerp(y[2], r[2], t));
    }
}
