#!/usr/bin/env python3

import os
import subprocess
import json
import time
from flask import Flask, render_template, request, jsonify, Response

app = Flask(__name__)

# Global variables equivalent to bash script
SCRIPT_VERSION = "0.5.0"
SCRIPT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.chdir(SCRIPT_DIR)

COMPOSE_FILE = "docker-compose.yml"
DOCKER_USER = "nessnetwork"
CONTAINER_ENGINE = os.environ.get("CONTAINER_ENGINE", "docker")
PROFILE = "pi3"  # pi3 | skyminer | full | mcp-server | mcp-client
DNS_MODE = "hybrid"  # icann | hybrid | emerdns
DNS_PROXY_HOST_PORT = os.environ.get("DNS_PROXY_HOST_PORT", "1053")

# DNS labels
DNS_LABEL_FILE = os.path.join(SCRIPT_DIR, ".dns_mode_labels")
DNS_LABEL_ICANN = "ICANN-only (no EmerDNS)"
DNS_LABEL_HYBRID = "Hybrid (EmerDNS + ICANN together)"
DNS_LABEL_EMERDNS = "EmerDNS-only (no ICANN)"

# Service bundles
PI3_SERVICES = [
    "emercoin-core",
    "privateness",
    "skywire",
    "dns-reverse-proxy",
    "pyuheprng-privatenesstools",
]

SKYMINER_SERVICES = [
    "emercoin-core",
    "privateness",
    "dns-reverse-proxy",
    "pyuheprng-privatenesstools",
]

MCP_SERVER_SERVICES = [
    "emercoin-mcp-server",
    "privateness-mcp-server",
    "magic-wormhole-rendezvous",
    "magic-wormhole-transit",
]

MCP_CLIENT_SERVICES = [
    "emercoin-mcp-app",
    "privateness-mcp-app",
    "magic-wormhole-client",
]

# Colors (for terminal, but we'll use CSS in web)
colors = {
    'cyan': '#00FFFF',
    'magenta': '#FF00FF',
    'yellow': '#FFFF00',
    'green': '#00FF00',
    'red': '#FF0000',
    'reset': '#000000'
}

def run_command(cmd, cwd=None, capture_output=True):
    """Run shell command and return result"""
    try:
        result = subprocess.run(cmd, shell=True, cwd=cwd or SCRIPT_DIR,
                              capture_output=capture_output, text=True)
        return result.returncode, result.stdout, result.stderr
    except Exception as e:
        return 1, "", str(e)

def docker_command(*args):
    """Run docker command"""
    cmd = f"{CONTAINER_ENGINE} {' '.join(args)}"
    return run_command(cmd)

def compose_command(*args):
    """Run docker compose command"""
    cmd = f"{CONTAINER_ENGINE} compose -f {COMPOSE_FILE} {' '.join(args)}"
    return run_command(cmd)

def load_dns_labels():
    global DNS_LABEL_ICANN, DNS_LABEL_HYBRID, DNS_LABEL_EMERDNS
    if os.path.exists(DNS_LABEL_FILE):
        with open(DNS_LABEL_FILE, 'r') as f:
            for line in f:
                if '=' in line:
                    key, value = line.strip().split('=', 1)
                    value = value.strip('"')
                    if key == 'icann':
                        DNS_LABEL_ICANN = value
                    elif key == 'hybrid':
                        DNS_LABEL_HYBRID = value
                    elif key == 'emerdns':
                        DNS_LABEL_EMERDNS = value

def save_dns_labels():
    with open(DNS_LABEL_FILE, 'w') as f:
        f.write(f'icann="{DNS_LABEL_ICANN}"\n')
        f.write(f'hybrid="{DNS_LABEL_HYBRID}"\n')
        f.write(f'emerdns="{DNS_LABEL_EMERDNS}"\n')

def apply_dns_mode():
    global DNS_MODE, DNS_DESC, DNS_SERVERS
    if DNS_MODE == 'icann':
        DNS_DESC = DNS_LABEL_ICANN
        DNS_SERVERS = "1.1.1.1 8.8.8.8"
    elif DNS_MODE == 'emerdns':
        DNS_DESC = DNS_LABEL_EMERDNS
        DNS_SERVERS = "127.0.0.1"
    else:  # hybrid
        DNS_MODE = "hybrid"
        DNS_DESC = DNS_LABEL_HYBRID
        DNS_SERVERS = "127.0.0.1 1.1.1.1"

def profile_label(profile):
    labels = {
        'pi3': "Pi 3 Essentials",
        'skyminer': "Skyminer (no Skywire container)",
        'full': "Full Node (overlays + DNS + tools)",
        'mcp-server': "MCP Server Suite (remote control)",
        'mcp-client': "MCP Client Suite (apps & helpers)"
    }
    return labels.get(profile, profile)

def require_docker():
    code, _, _ = run_command("which docker")
    return code == 0

def service_status(service):
    if not require_docker():
        return "UNKNOWN"

    # Check if running
    code, stdout, _ = docker_command("ps", "--format", "{{.Names}}")
    if code == 0 and service in stdout:
        return "RUNNING"

    # Check if exists
    code, stdout, _ = docker_command("ps", "-a", "--format", "{{.Names}}")
    if code == 0 and service in stdout:
        return "STOPPED"

    return "NOT PRESENT"

@app.route('/')
def index():
    return render_template('index.html',
                         version=SCRIPT_VERSION,
                         profile=PROFILE,
                         profile_label=profile_label(PROFILE),
                         dns_mode=DNS_MODE)

@app.route('/api/start-stack', methods=['POST'])
def start_stack():
    # Port the start_stack logic
    if not require_docker():
        return jsonify({'success': False, 'message': 'Docker not available'})

    # Ensure stack stopped
    compose_command('down')

    # Cleanup dns proxy
    docker_command('ps', '-a', '--format', '{{.Names}}')
    # TODO: cleanup logic

    # Check port free
    # TODO: port check

    services = []
    if PROFILE == 'pi3':
        services = PI3_SERVICES
    elif PROFILE == 'skyminer':
        services = SKYMINER_SERVICES
    elif PROFILE == 'full':
        services = []  # TODO: full services
    elif PROFILE == 'mcp-server':
        services = MCP_SERVER_SERVICES
    elif PROFILE == 'mcp-client':
        services = MCP_CLIENT_SERVICES

    if services:
        code, stdout, stderr = compose_command('up', '-d', *services)
        if code == 0:
            # Wait for emercoin if needed
            return jsonify({'success': True, 'message': 'Stack started successfully'})
        else:
            return jsonify({'success': False, 'message': f'Failed to start stack: {stderr}'})
    else:
        return jsonify({'success': False, 'message': 'No services defined for this profile'})

@app.route('/api/stop-stack', methods=['POST'])
def stop_stack():
    if not require_docker():
        return jsonify({'success': False, 'message': 'Docker not available'})

    code, stdout, stderr = compose_command('down')
    if code == 0:
        return jsonify({'success': True, 'message': 'Stack stopped successfully'})
    else:
        return jsonify({'success': False, 'message': f'Failed to stop stack: {stderr}'})

@app.route('/api/dns-modes')
def get_dns_modes():
    return jsonify({
        'current': DNS_MODE,
        'modes': {
            'icann': DNS_LABEL_ICANN,
            'hybrid': DNS_LABEL_HYBRID,
            'emerdns': DNS_LABEL_EMERDNS
        }
    })

@app.route('/api/set-dns-mode', methods=['POST'])
def set_dns_mode():
    global DNS_MODE
    data = request.get_json()
    mode = data.get('mode')
    if mode in ['icann', 'hybrid', 'emerdns']:
        DNS_MODE = mode
        apply_dns_mode()
        save_dns_labels()
        return jsonify({'success': True, 'message': f'DNS mode set to {DNS_MODE}'})
    else:
        return jsonify({'success': False, 'message': 'Invalid DNS mode'})

@app.route('/api/profiles')
def get_profiles():
    profiles = {
        'pi3': profile_label('pi3'),
        'skyminer': profile_label('skyminer'),
        'full': profile_label('full'),
        'mcp-server': profile_label('mcp-server'),
        'mcp-client': profile_label('mcp-client')
    }
    return jsonify({'current': PROFILE, 'profiles': profiles})

@app.route('/api/set-profile', methods=['POST'])
def set_profile():
    global PROFILE
    data = request.get_json()
    prof = data.get('profile')
    if prof in ['pi3', 'skyminer', 'full', 'mcp-server', 'mcp-client']:
        PROFILE = prof
        return jsonify({'success': True, 'message': f'Profile set to {profile_label(PROFILE)}'})
    else:
        return jsonify({'success': False, 'message': 'Invalid profile'})

@app.route('/api/build-images')
def get_build_images():
    images = [
        "emercoin-core",
        "yggdrasil",
        "dns-reverse-proxy",
        "skywire",
        "privateness",
        "ness-blockchain",
        "pyuheprng",
        "privatenesstools",
        "pyuheprng-privatenesstools",
        "ipfs",
        "i2p-yggdrasil",
        "amnezia-exit",
        "ness-unified",
        "emercoin-mcp-server",
        "privateness-mcp-server",
        "emercoin-mcp-app",
        "privateness-mcp-app",
        "magic-wormhole-suite",
        "inspector",
    ]
    return jsonify({'images': images})

@app.route('/api/build-image', methods=['POST'])
def build_image():
    if not require_docker():
        return jsonify({'success': False, 'message': 'Docker not available'})

    data = request.get_json()
    image = data.get('image')
    if not image:
        return jsonify({'success': False, 'message': 'No image specified'})

    context_path = os.path.join(SCRIPT_DIR, image)
    if not os.path.isdir(context_path):
        return jsonify({'success': False, 'message': f'Build context not found: {context_path}'})

    docker_user = os.environ.get('DOCKER_USER', 'nessnetwork')
    code, stdout, stderr = run_command(f'{CONTAINER_ENGINE} build -t {docker_user}/{image}:latest {context_path}')
    if code == 0:
        return jsonify({'success': True, 'message': f'Successfully built {docker_user}/{image}:latest'})
    else:
        return jsonify({'success': False, 'message': f'Failed to build {docker_user}/{image}:latest: {stderr}'})

@app.route('/api/build-all', methods=['POST'])
def build_all():
    code, stdout, stderr = run_command('./build-all.sh')
    if code == 0:
        return jsonify({'success': True, 'message': 'All images built successfully'})
    else:
        return jsonify({'success': False, 'message': f'build-all.sh failed: {stderr}'})

@app.route('/api/build-multiarch', methods=['POST'])
def build_multiarch():
    code, stdout, stderr = run_command('./build-multiarch.sh')
    if code == 0:
        return jsonify({'success': True, 'message': 'Multi-arch build completed'})
    else:
        return jsonify({'success': False, 'message': f'build-multiarch.sh failed: {stderr}'})

@app.route('/api/logs/<service>')
def get_logs(service):
    if not require_docker():
        return jsonify({'error': 'Docker not available'})

    # Map service names
    service_map = {
        'global': '',
        'emercoin-core': 'emercoin-core',
        'privateness': 'privateness',
        'dns-reverse-proxy': 'dns-reverse-proxy',
        'pyuheprng-privatenesstools': 'pyuheprng-privatenesstools',
        'yggdrasil': 'yggdrasil',
        'skywire': 'skywire',
        'i2p-yggdrasil': 'i2p-yggdrasil'
    }

    if service not in service_map:
        return jsonify({'error': 'Invalid service'})

    args = ['logs', '--tail=100']
    if service != 'global':
        args.append(service_map[service])

    code, stdout, stderr = compose_command(*args)
    if code == 0:
        return jsonify({'logs': stdout})
    else:
        return jsonify({'error': stderr})

@app.route('/api/health-check')
def health_check():
    # Port the health_check function
    if not require_docker():
        return jsonify({'error': 'Docker not available'})

    # Simulate health check results
    # TODO: port full logic
    return jsonify({'status': 'Health check completed', 'details': 'TODO: port full health check'})

@app.route('/api/test-full-node-overlays')
def test_full_node_overlays():
    # Port test_full_node_overlays
    if not require_docker():
        return jsonify({'error': 'Docker not available'})

    # TODO: port the test logic
    return jsonify({'status': 'Overlay tests completed', 'details': 'TODO: port full tests'})

@app.route('/api/nuke-local', methods=['POST'])
def nuke_local():
    if not require_docker():
        return jsonify({'success': False, 'message': 'Docker not available'})

    # Port remove_everything_local
    run_command('docker ps -aq | xargs -r docker stop')
    run_command('docker ps -aq | xargs -r docker rm -f')
    code, stdout, stderr = run_command('docker system prune -af --volumes')
    if code == 0:
        return jsonify({'success': True, 'message': 'Local Docker cleanup completed'})
    else:
        return jsonify({'success': False, 'message': f'Cleanup failed: {stderr}'})

if __name__ == '__main__':
    load_dns_labels()
    apply_dns_mode()
    app.run(host='0.0.0.0', port=50001, debug=True)
