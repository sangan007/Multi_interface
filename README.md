Multi-Interface Download Monitor

A Flutter application designed to simulate a specific Linux GTK tool behavior. It downloads a single file by splitting it into two parts, downloading them in parallel (simulating two network interfaces), and merging them upon completion.

Features

Parallel Downloading: Uses HTTP Range headers to fetch two halves of a file simultaneously.

GTK-Style UI: Terminal-like log output, specific status bars, and control layout.

Resilience: Retry logic with exponential backoff for transient network errors.

Visual Feedback: Real-time progress logging for both "interfaces".

Architecture

State Management: flutter_riverpod (Notifier pattern).

Networking: dio for streaming response handling and cancellation.

Storage: path_provider to handle App Documents and Temporary directories securely.

Getting Started

Prerequisites

Flutter SDK 3.10+

Android Device/Emulator (API 21+) or iOS Simulator.

Installation

Clone repository.

Run flutter pub get.

Run flutter run.

Local Integration Testing

To verify the exact reconstruction of a binary file, use the built-in integration test or manual testing against a local Python server.

Create Test File:

# Linux/Mac
dd if=/dev/urandom of=test.bin bs=1M count=2


Start Server:

python3 -m http.server 8000 --bind 127.0.0.1


In App:

Android Emulator: Use URL http://10.0.2.2:8000/test.bin

iOS Simulator: Use URL http://127.0.0.1:8000/test.bin

Interface 1: wlan0 (label only)

Interface 2: eth0 (label only)

Output: downloaded.bin

Verify:
Check the logs for "✓ Download successful!".

Notes on Android Storage

This app uses getApplicationDocumentsDirectory. On Android, this maps to the App-specific storage (Sandbox), so no dangerous Runtime Permissions (MANAGE_EXTERNAL_STORAGE) are required.

Future Improvements

True Multi-Interface Binding: Currently, Flutter does not support binding a socket to a specific network interface (e.g., forcing traffic over WiFi vs Cellular) natively. This would require:

Android Native code (ConnectivityManager.requestNetwork with NetworkSpecifier).

Platform Channels to pass the specific Network handle to the Dart layer.

A modified Http Client adapter that uses that specific native socket.
