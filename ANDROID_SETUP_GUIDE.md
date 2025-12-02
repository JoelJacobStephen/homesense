# HomeSense Android App Installation & Testing Guide

This comprehensive guide explains how to install the HomeSense Android app on your physical device using USB or wireless debugging, run the backend locally, and connect everything for testing.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Enable Developer Options on Android](#enable-developer-options-on-android)
3. [Method 1: USB Debugging](#method-1-usb-debugging)
4. [Method 2: Wireless Debugging](#method-2-wireless-debugging)
5. [Running the Backend Locally](#running-the-backend-locally)
6. [Connecting the Mobile App to Local Backend](#connecting-the-mobile-app-to-local-backend)
7. [Building & Installing the App](#building--installing-the-app)
8. [Testing the Complete Setup](#testing-the-complete-setup)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### On Your Development Machine (Mac/Linux/Windows)

#### 1. Flutter SDK

```bash
# Check if Flutter is installed
flutter --version

# If not installed, follow: https://docs.flutter.dev/get-started/install
# For macOS with Homebrew:
brew install --cask flutter

# Verify installation
flutter doctor
```

#### 2. Android SDK & ADB

ADB (Android Debug Bridge) is required for both USB and wireless debugging.

```bash
# Check if ADB is installed
adb --version

# If not installed:
# Option 1: Install via Android Studio (recommended)
# Download from: https://developer.android.com/studio

# Option 2: Install ADB only (macOS with Homebrew)
brew install --cask android-platform-tools

# Option 3: Install ADB only (Ubuntu/Debian)
sudo apt install adb

# Verify ADB is working
adb devices
```

#### 3. Python 3.10+ (for the backend)

```bash
# Check Python version
python3 --version

# If not installed (macOS):
brew install python@3.10

# If not installed (Ubuntu/Debian):
sudo apt install python3.10 python3.10-venv python3-pip
```

### Verify Flutter Setup

Run the Flutter doctor to ensure everything is configured:

```bash
flutter doctor -v
```

You should see:
- ✓ Flutter (Channel stable)
- ✓ Android toolchain
- ✓ Connected device (once phone is connected)

---

## Enable Developer Options on Android

Before you can use USB or wireless debugging, you need to enable Developer Options on your Android phone:

### Step 1: Enable Developer Options

1. Open **Settings** on your Android phone
2. Scroll down and tap **About phone** (or "About device")
3. Find **Build number** (might be under "Software information")
4. **Tap "Build number" 7 times** rapidly
5. You'll see a message: "You are now a developer!"

### Step 2: Enable USB Debugging

1. Go back to **Settings**
2. Tap **Developer options** (now visible, usually near the bottom)
3. Toggle **USB debugging** to ON
4. (Optional but recommended) Enable **Install via USB** if available

### Step 3: Enable Wireless Debugging (Android 11+)

1. In **Developer options**
2. Toggle **Wireless debugging** to ON
3. You may need to confirm on the popup dialog

---

## Method 1: USB Debugging

This is the most reliable method for development and testing.

### Step 1: Connect Your Phone via USB

1. Connect your Android phone to your computer with a USB cable
2. On your phone, you'll see a popup asking "Allow USB debugging?"
3. Check **"Always allow from this computer"** (recommended)
4. Tap **Allow**

### Step 2: Verify the Connection

```bash
# List connected devices
adb devices
```

You should see output like:

```
List of devices attached
XXXXXXXXXX	device
```

If you see `unauthorized` instead of `device`, check your phone for the permission popup.

### Step 3: Verify Flutter Can See the Device

```bash
# List devices Flutter can see
flutter devices
```

Output should include your Android device:

```
Found 2 connected devices:
  Pixel 6 (mobile) • XXXXXXXXXX • android-arm64 • Android 14 (API 34)
  Chrome (web)     • chrome     • web-javascript • Google Chrome
```

### Step 4: Run the App

```bash
# Navigate to the Flutter app directory
cd FlutterApp

# Get dependencies
flutter pub get

# Run on connected device (debug mode)
flutter run

# Or specify the device if multiple are connected
flutter run -d XXXXXXXXXX
```

### Step 5: Build and Install APK (Optional)

If you want to install the APK without running in debug mode:

```bash
# Build debug APK
flutter build apk --debug

# Install to connected device
adb install build/app/outputs/flutter-apk/app-debug.apk

# Or build and install in one command
flutter install
```

---

## Method 2: Wireless Debugging

Wireless debugging allows you to deploy and test without a USB cable. Requires Android 11 or later.

### Option A: Wireless Debugging (Android 11+) - Pairing Code Method

#### Step 1: Enable Wireless Debugging

1. Ensure your phone and computer are on the **same WiFi network**
2. On your phone, go to **Settings > Developer options > Wireless debugging**
3. Toggle it **ON** and confirm

#### Step 2: Pair Your Computer with Your Phone

1. In **Wireless debugging** settings, tap **"Pair device with pairing code"**
2. You'll see:
   - IP address & Port (e.g., `192.168.1.100:37215`)
   - A 6-digit pairing code

3. On your computer, pair using ADB:

```bash
# Pair with the device (use the IP:PORT and pairing code shown on your phone)
adb pair 192.168.1.100:37215
# Enter the pairing code when prompted
```

#### Step 3: Connect to the Device

After pairing, you need to connect. Note that the **connection port is different** from the pairing port.

1. Look at your phone's Wireless debugging screen
2. Find the **IP address & Port** shown (e.g., `192.168.1.100:43567`)
   - This is NOT the pairing port, it's the connection port

```bash
# Connect to the device
adb connect 192.168.1.100:43567
```

#### Step 4: Verify Connection

```bash
# Should show your device
adb devices

# Output:
# List of devices attached
# 192.168.1.100:43567	device
```

### Option B: Traditional Wireless ADB (Any Android Version)

This method works with older Android versions but requires initial USB connection.

#### Step 1: Connect via USB First

```bash
# Connect phone via USB and verify
adb devices
```

#### Step 2: Enable TCP/IP Mode

```bash
# Set ADB to listen on port 5555
adb tcpip 5555
```

#### Step 3: Find Your Phone's IP Address

On your phone:
1. Go to **Settings > WiFi**
2. Tap on your connected network
3. Find the **IP address** (e.g., `192.168.1.100`)

Or use ADB:

```bash
adb shell ip route | grep wlan0
# Look for the IP address in the output
```

#### Step 4: Disconnect USB and Connect Wirelessly

```bash
# Disconnect the USB cable first, then:
adb connect 192.168.1.100:5555
```

#### Step 5: Verify Connection

```bash
adb devices
# Output:
# List of devices attached
# 192.168.1.100:5555	device
```

### Running the App Over Wireless

Once connected wirelessly, Flutter commands work the same way:

```bash
cd FlutterApp

# Run the app
flutter run

# Or specify the wireless device
flutter run -d 192.168.1.100:43567
```

---

## Running the Backend Locally

The HomeSense backend is a FastAPI server that handles room inference, calibration, and suggestions.

### Step 1: Navigate to Backend Directory

```bash
cd backend
```

### Step 2: Set Up Python Virtual Environment (Recommended)

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
# On macOS/Linux:
source venv/bin/activate

# On Windows:
# venv\Scripts\activate
```

### Step 3: Install Dependencies

```bash
# Option 1: Using pip with pyproject.toml
pip install -e .

# Option 2: If you prefer poetry
pip install poetry
poetry install
```

### Step 4: Run the Backend Server

```bash
# Run with uvicorn (binds to all interfaces on port 8000)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

**Important:** The `--host 0.0.0.0` flag is crucial! It allows connections from other devices on your network (like your phone), not just localhost.

### Step 5: Verify Backend is Running

```bash
# Test health endpoint
curl http://localhost:8000/health

# Should return:
# {"status":"healthy"}
```

You can also visit the API documentation:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## Connecting the Mobile App to Local Backend

For your Android phone to communicate with the backend running on your laptop, you need to configure the correct IP address.

### Step 1: Find Your Computer's Local IP Address

#### On macOS:

```bash
# Method 1: Using ipconfig
ipconfig getifaddr en0

# Method 2: Using ifconfig
ifconfig | grep "inet " | grep -v 127.0.0.1

# Method 3: System Preferences
# Go to System Preferences > Network > WiFi > IP Address
```

#### On Linux:

```bash
# Method 1
hostname -I | awk '{print $1}'

# Method 2
ip addr show | grep "inet " | grep -v 127.0.0.1
```

#### On Windows:

```bash
# In Command Prompt
ipconfig
# Look for "IPv4 Address" under your WiFi adapter
```

Your IP will look something like `192.168.1.XXX` or `10.0.0.XXX`.

### Step 2: Update the Flutter App's API Service

Open `FlutterApp/lib/services/api_service.dart` and update the IP address:

```dart
static String _defaultBaseUrl() {
  if (kIsWeb) return 'http://localhost:8000';
  if (Platform.isAndroid) {
    // Replace with YOUR computer's actual IP address
    return 'http://192.168.1.XXX:8000';  // <-- YOUR IP HERE
  }
  return 'http://localhost:8000';
}

Future<void> resolveReachableBaseUrl({Duration timeout = const Duration(seconds: 2)}) async {
  final candidates = <String>[
    _baseUrl,
    'http://192.168.1.XXX:8000',  // <-- YOUR IP HERE
    'http://10.0.2.2:8000',       // Android emulator
    'http://localhost:8000',
  ];
  // ...
}
```

### Step 3: Ensure Same Network

**Critical:** Both your phone and laptop must be on the **same WiFi network** for this to work.

### Step 4: Test Connectivity from Phone (Optional)

If you want to verify connectivity before running the app:

1. Open a browser on your Android phone
2. Navigate to `http://YOUR_LAPTOP_IP:8000/docs`
3. You should see the Swagger API documentation

If it doesn't load:
- Check firewall settings (see Troubleshooting)
- Verify both devices are on the same network
- Verify the backend is running with `--host 0.0.0.0`

---

## Building & Installing the App

### Option 1: Debug Build (Recommended for Testing)

```bash
cd FlutterApp

# Run directly on device (includes hot reload)
flutter run

# Or build and install APK
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
```

### Option 2: Release Build

```bash
cd FlutterApp

# Build release APK
flutter build apk --release

# Install release APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Option 3: Build App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

### Useful ADB Commands

```bash
# List installed packages
adb shell pm list packages | grep homesense

# Uninstall the app
adb uninstall com.example.test_flutter_app

# View app logs
adb logcat -s flutter

# Clear app data
adb shell pm clear com.example.test_flutter_app

# Restart ADB server (if having connection issues)
adb kill-server
adb start-server
```

---

## Testing the Complete Setup

Follow this checklist to ensure everything works:

### 1. Start the Backend

```bash
# Terminal 1: Start backend
cd backend
source venv/bin/activate  # if using venv
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Verify Backend is Accessible

```bash
# From your laptop
curl http://localhost:8000/health

# Test from the IP that your phone will use
curl http://YOUR_LAPTOP_IP:8000/health
```

### 3. Connect Your Phone

```bash
# USB debugging
adb devices

# Or wireless debugging
adb connect YOUR_PHONE_IP:PORT
```

### 4. Run the Flutter App

```bash
# Terminal 2: Run Flutter app
cd FlutterApp
flutter pub get
flutter run
```

### 5. Verify App-Backend Communication

In the app:
1. Open the app on your phone
2. Navigate to a page that makes API calls
3. Check the backend terminal for incoming requests
4. Verify responses in the app

### 6. Monitor Logs

```bash
# Terminal 3: Watch Flutter logs
flutter logs

# Or watch ADB logcat
adb logcat -s flutter
```

---

## Troubleshooting

### ADB Device Not Found

```bash
# Restart ADB
adb kill-server
adb start-server

# Check USB debugging is enabled on phone
# Try a different USB cable (some cables are charge-only)
# Try a different USB port
```

### Wireless Debugging Connection Failed

```bash
# Ensure both devices are on same WiFi network
# Check if port is blocked by firewall
# Re-pair the device (in Wireless debugging settings)
# Try restarting Wireless debugging on phone
```

### App Can't Connect to Backend

1. **Check backend is running:**
   ```bash
   curl http://localhost:8000/health
   ```

2. **Check backend is accessible from network:**
   ```bash
   # Make sure you started with --host 0.0.0.0
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

3. **Check firewall (macOS):**
   ```bash
   # Allow incoming connections
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/python3
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/local/bin/python3
   ```

4. **Check firewall (Linux):**
   ```bash
   # Allow port 8000
   sudo ufw allow 8000
   ```

5. **Check firewall (Windows):**
   - Open Windows Defender Firewall
   - Click "Allow an app through firewall"
   - Add Python or allow port 8000

6. **Verify IP address in app:**
   - Make sure you updated `api_service.dart` with correct IP
   - Rebuild and reinstall the app after changes

### Flutter Run Fails

```bash
# Clean and rebuild
cd FlutterApp
flutter clean
flutter pub get
flutter run
```

### Device Shows "Unauthorized"

1. Revoke USB debugging authorizations on phone:
   - Settings > Developer options > Revoke USB debugging authorizations
2. Disconnect and reconnect USB
3. Accept the new authorization popup

### Hot Reload Not Working

```bash
# Make sure you're running in debug mode
flutter run --debug

# Check the terminal for errors
# Press 'r' in terminal for hot reload
# Press 'R' for hot restart
```

### Backend Database Issues

```bash
# Reset the database
cd backend
rm homesense.db
# Restart the server - it will create a fresh database
```

---

## Quick Reference Commands

### Backend Commands

```bash
# Start backend
cd backend && uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Test health
curl http://localhost:8000/health

# View API docs
open http://localhost:8000/docs
```

### Flutter Commands

```bash
# Navigate to Flutter app
cd FlutterApp

# Get dependencies
flutter pub get

# Run app (debug)
flutter run

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Install APK via ADB
adb install build/app/outputs/flutter-apk/app-debug.apk

# View logs
flutter logs
```

### ADB Commands

```bash
# List devices
adb devices

# USB debugging setup (done automatically when connected)
# Just accept the popup on your phone

# Wireless debugging (Android 11+)
adb pair IP:PAIRING_PORT      # Enter pairing code
adb connect IP:CONNECTION_PORT

# Traditional wireless (any Android)
adb tcpip 5555
adb connect IP:5555

# Disconnect wireless
adb disconnect

# View device logs
adb logcat

# Restart ADB
adb kill-server && adb start-server
```

### Finding IP Addresses

```bash
# Your laptop's IP (macOS)
ipconfig getifaddr en0

# Your laptop's IP (Linux)
hostname -I | awk '{print $1}'

# Your phone's IP (via ADB)
adb shell ip route | grep wlan0
```

---

## Summary

1. **Enable Developer Options** and USB/Wireless debugging on your Android phone
2. **Connect your phone** via USB or wireless ADB
3. **Start the backend** with `uvicorn app.main:app --reload --host 0.0.0.0 --port 8000`
4. **Update the API service** with your laptop's IP address
5. **Run the Flutter app** with `flutter run`
6. **Test** the app communicates with the backend successfully

For any issues, refer to the [Troubleshooting](#troubleshooting) section above.

