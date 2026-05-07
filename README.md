# System Monitor Dashboard

A real-time hardware monitoring dashboard for macOS built with Flask, Bash, HTML, CSS, and JavaScript. It collects live system metrics from the host machine and displays them in a browser with an auto-refreshing interface.

## Features

- CPU usage monitoring
- RAM usage monitoring with used/total breakdown
- CPU temperature display with animated thermometer
- Disk usage and SMART health status
- GPU vendor detection for NVIDIA, AMD, and Apple Silicon
- GPU temperature and GPU details display
- Network packet statistics
- Live console output for debugging
- Cached API responses to reduce system load

## How It Works

- `monitor.sh` gathers system metrics from macOS command-line tools.
- `app.py` runs the script, parses its output, caches the result, and exposes it through `/api/stats`.
- `templates/index.html` defines the dashboard layout.
- `static/style.css` styles the interface.
- `static/script.js` polls the API every few seconds and updates the UI.

## Project Structure

```text
sys_moniter/
├── app.py
├── monitor.sh
├── README.md
├── templates/
│   └── index.html
└── static/
    ├── script.js
    └── style.css
```

## Requirements

- Python 3
- Flask
- macOS utilities such as `ps`, `sysctl`, `vm_stat`, `df`, `netstat`, and `powermetrics`

Optional tools:
- `smartctl` for SMART health checks
- `nvidia-smi` for NVIDIA GPUs
- `rocm-smi` for AMD GPUs

## Setup

1. Create and activate a virtual environment if needed.
2. Install Flask:

```bash
pip install flask
```

3. Make sure the monitor script is executable:

```bash
chmod +x monitor.sh
```

4. Run the Flask app:

```bash
python3 app.py
```

5. Open the dashboard in your browser:

```text
http://127.0.0.1:8080
```

## Usage

Once the server is running, the dashboard refreshes automatically. The browser sends periodic requests to `/api/stats`, and the backend returns the latest system metrics as JSON.

## API Endpoint

### `GET /api/stats`

Returns a JSON response containing:

- `cpu`
- `ram`
- `ram_used`
- `ram_total`
- `temp`
- `disk`
- `disk_total`
- `disk_free`
- `smart`
- `network`
- `gpu_vendor`
- `gpu_temp`
- `gpu_full`
- `raw`

## Notes

- The app uses a short cache TTL to reduce repeated script execution.
- On Apple Silicon, GPU temperature falls back to the shared thermal package temperature.
- The dashboard is designed for live presentation and debugging.

## Documentation

- [Full explanation](explain.txt)
- [PDF version](explain.pdf)

## License

No license has been added yet.
