@echo off
setlocal enabledelayedexpansion

:: Port list from docker-compose.yml
set tcp_ports=6661 6662 8775 9001 7657 4444 6668 9002 8000 6006 6660 5000 8888 1053 8053 8002
set udp_ports=1053 51820 51821

echo Checking TCP port conflicts...
for %%p in (%tcp_ports%) do (
  netstat -ano | findstr ":%%p" | findstr "LISTENING"
  if !errorlevel! equ 0 (
    echo Port %%p is occupied
    set /p kill="Terminate process on port %%p? (y/n): "
    if /i "!kill!"=="y" (
      for /f "tokens=5" %%i in ('netstat -ano ^| findstr ":%%p" ^| findstr "LISTENING"') do (
        taskkill /PID %%i /F
        echo Process %%i terminated
      )
    )
  ) else (
    echo Port %%p: free
  )
)

echo Checking UDP port conflicts...
for %%p in (%udp_ports%) do (
  netstat -ano -p udp | findstr ":%%p"
  if !errorlevel! equ 0 (
    echo Port %%p is occupied
    set /p kill="Terminate process on port %%p? (y/n): "
    if /i "!kill!"=="y" (
      for /f "tokens=5" %%i in ('netstat -ano -p udp ^| findstr ":%%p"') do (
        taskkill /PID %%i /F
        echo Process %%i terminated
      )
    )
  ) else (
    echo Port %%p: free
  )
)

echo Pre-flight check complete
