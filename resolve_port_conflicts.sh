#!/bin/bash

# Port list from docker-compose.yml
tcp_ports=(6661 6662 8775 9001 7657 4444 6668 9002 8000 6006 6660 5000 8888 1053 8053 8002)
udp_ports=(1053 51820 51821)

# Determine netstat syntax
if [[ "$(uname)" == "Linux" ]]; then
  netstat_cmd="netstat -tuln"
  udp_cmd="netstat -uln"
  pid_column=7
else
  # Git Bash (Windows) syntax
  netstat_cmd="netstat -ano -p tcp"
  udp_cmd="netstat -ano -p udp"
  pid_column=5
fi

echo "Checking TCP port conflicts..."
for port in "${tcp_ports[@]}"
do
  # Find processes listening on port
  pids=$($netstat_cmd | awk -v port=":$port " '$4 ~ port && $6 ~ /LISTEN/ {print $'$pid_column'}' | cut -d: -f2 | sort | uniq)
  
  if [ -z "$pids" ]; then
    echo "Port $port: free"
  else
    for pid in $pids
    do
      # Get process name
      proc_name=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
      echo "Port $port is occupied by PID $pid ($proc_name)"
      
      # Ask for termination
      read -p "Terminate process? (y/n): " answer
      if [[ "$answer" == "y" ]]; then
        if kill -9 $pid 2>/dev/null; then
          echo "Process $pid terminated"
        else
          echo "Failed to terminate process $pid"
        fi
      fi
    done
  fi
done

echo "Checking UDP port conflicts..."
for port in "${udp_ports[@]}"
do
  pids=$($udp_cmd | awk -v port=":$port " '$4 ~ port {print $'$pid_column'}' | cut -d: -f2 | sort | uniq)
  
  if [ -z "$pids" ]; then
    echo "Port $port: free"
  else
    for pid in $pids
    do
      proc_name=$(ps -p $pid -o comm= 2>/dev/null || echo "unknown")
      echo "Port $port is occupied by PID $pid ($proc_name)"
      
      read -p "Terminate process? (y/n): " answer
      if [[ "$answer" == "y" ]]; then
        if kill -9 $pid 2>/dev/null; then
          echo "Process $pid terminated"
        else
          echo "Failed to terminate process $pid"
        fi
      fi
    done
  fi
done

echo "Pre-flight check complete"
