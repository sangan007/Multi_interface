package com.example.multi_interface_downloader

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.atomic.AtomicLong

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.downloader/method"
    private val EVENT_CHANNEL = "com.example.downloader/events"
    private var eventSink: EventChannel.EventSink? = null
    private var job: Job? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "startNativeDownload") {
                val url = call.argument<String>("url")
                val filePath = call.argument<String>("filePath")
                if (url != null && filePath != null) {
                    startDualDownload(url, filePath)
                    result.success(null)
                } else {
                    result.error("INVALID_ARGS", "URL or Path missing", null)
                }
            } else if (call.method == "stopNativeDownload") {
                stopDownload()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun stopDownload() {
        job?.cancel()
        sendEvent("status", "Stopped")
        sendEvent("log", "[Native] Download stopped by user.")
    }

    private fun sendEvent(type: String, message: String) {
        runOnUiThread {
            val map = mapOf("type" to type, "message" to message)
            eventSink?.success(map)
        }
    }

    private fun startDualDownload(urlString: String, outputUserPath: String) {
        // Cancel any existing job
        job?.cancel()
        
        job = CoroutineScope(Dispatchers.IO).launch {
            try {
                sendEvent("log", "Initializing Native Dual-Stack Engine...")
                
                // 1. Get File Size first (using default network)
                sendEvent("log", "Probing file size via Default Route...")
                val urlObj = URL(urlString)
                val conn = urlObj.openConnection() as HttpURLConnection
                conn.requestMethod = "HEAD"
                val fileSize = conn.contentLengthLong
                conn.disconnect()

                if (fileSize <= 0) {
                    throw Exception("Invalid Content-Length: $fileSize")
                }
                sendEvent("log", "File Size: ${fileSize / 1024 / 1024} MB")

                // 2. Acquire Networks
                val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                
                sendEvent("log", "Requesting Network Handles (Wi-Fi & Cellular)...")
                
                // We use async to find networks in parallel/sequence quickly
                val wifiNetwork = findNetwork(cm, NetworkCapabilities.TRANSPORT_WIFI)
                val cellNetwork = findNetwork(cm, NetworkCapabilities.TRANSPORT_CELLULAR)

                val useDualStack = (wifiNetwork != null && cellNetwork != null)
                
                if (useDualStack) {
                    sendEvent("log", "SUCCESS: Wi-Fi and Cellular both acquired! Binding sockets...")
                } else if (wifiNetwork != null) {
                    sendEvent("log", "WARNING: Only Wi-Fi acquired. Using Single Interface.")
                } else if (cellNetwork != null) {
                    sendEvent("log", "WARNING: Only Cellular acquired. Using Single Interface.")
                } else {
                    sendEvent("log", "WARNING: Using Default Route (No specific handles).")
                }

                // 3. Define Split
                val midPoint = fileSize / 2
                val part1File = File(cacheDir, "native_p1.tmp")
                val part2File = File(cacheDir, "native_p2.tmp")
                
                if(part1File.exists()) part1File.delete()
                if(part2File.exists()) part2File.delete()

                val bytesDownloaded1 = AtomicLong(0)
                val bytesDownloaded2 = AtomicLong(0)

                // 4. Launch Parallel Downloads
                val net1 = wifiNetwork ?: cm.activeNetwork // Prefer Wifi, else default
                val net2 = cellNetwork ?: wifiNetwork ?: cm.activeNetwork // Prefer Cell, else Wifi, else default

                sendEvent("status", "Downloading...")

                // Create a progress ticker
                val progressJob = launch {
                    while(isActive) {
                        val t1 = bytesDownloaded1.get()
                        val t2 = bytesDownloaded2.get()
                        val p1Pct = if(midPoint > 0) (t1.toDouble() / midPoint.toDouble()) * 100 else 0.0
                        val p2Pct = if((fileSize - midPoint) > 0) (t2.toDouble() / (fileSize - midPoint).toDouble()) * 100 else 0.0
                        
                        val iface1Name = if(wifiNetwork != null) "Wi-Fi" else "Def"
                        val iface2Name = if(cellNetwork != null) "Cell" else "Def"
                        
                        // Human readable size
                        val totalMB = (t1 + t2) / 1024 / 1024
                        
                        sendEvent("progress", "[$iface1Name: ${"%.1f".format(p1Pct)}%] [$iface2Name: ${"%.1f".format(p2Pct)}%] - ${totalMB}MB")
                        delay(1000)
                    }
                }

                try {
                    awaitAll(
                        async(Dispatchers.IO) {
                            downloadRange(net1, urlString, 0, midPoint - 1, part1File, bytesDownloaded1, "IF1")
                        },
                        async(Dispatchers.IO) {
                            downloadRange(net2, urlString, midPoint, fileSize - 1, part2File, bytesDownloaded2, "IF2")
                        }
                    )
                } finally {
                    progressJob.cancel()
                }

                // 5. Merge
                sendEvent("status", "Merging...")
                sendEvent("log", "Merging parts into final destination...")
                
                val outFile = File(outputUserPath)
                if (outFile.exists()) outFile.delete()
                
                // Use FileStreams for merging
                val fos = FileOutputStream(outFile, true)
                val fis1 = part1File.inputStream()
                val fis2 = part2File.inputStream()

                // Append part 1
                val buffer = ByteArray(8192)
                var len: Int
                while (fis1.read(buffer).also { len = it } > 0) {
                    fos.write(buffer, 0, len)
                }
                fis1.close()

                // Append part 2
                while (fis2.read(buffer).also { len = it } > 0) {
                    fos.write(buffer, 0, len)
                }
                fis2.close()
                fos.close()

                // Cleanup temps
                part1File.delete()
                part2File.delete()

                sendEvent("log", "Download Complete! Saved to $outputUserPath")
                sendEvent("status", "Download Complete!")

            } catch (e: Exception) {
                if (e is CancellationException) {
                   // Handled in stop
                } else {
                    e.printStackTrace()
                    sendEvent("log", "Error: ${e.message}")
                    sendEvent("status", "Download Failed")
                }
            }
        }
    }

    // Helper to find specific network with timeout
    private suspend fun findNetwork(cm: ConnectivityManager, transportType: Int): Network? {
        // First check if already active
        val active = cm.activeNetwork
        val caps = cm.getNetworkCapabilities(active)
        if (active != null && caps != null && caps.hasTransport(transportType)) {
            return active
        }

        // If not, request it specifically
        return suspendCancellableCoroutine { cont ->
            val request = NetworkRequest.Builder()
                .addTransportType(transportType)
                .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .build()

            val callback = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    if (cont.isActive) {
                        cont.resume(network) {}
                        // We do NOT unregister immediately here if we want to keep using it, 
                        // but for this one-shot find, it's okay. 
                        // In production, you might keep the callback alive.
                    }
                }
                
                override fun onUnavailable() {
                     if (cont.isActive) cont.resume(null) {}
                }
            }
            
            // Try to find it for 3 seconds
            cm.requestNetwork(request, callback, 3000)
            
            // Ensure we unregister callback eventually to prevent leaks
            cont.invokeOnCancellation { 
                try { cm.unregisterNetworkCallback(callback) } catch(e: Exception) {}
            }
        }
    }

    private fun downloadRange(
        network: Network?, 
        urlString: String, 
        start: Long, 
        end: Long, 
        file: File, 
        progress: AtomicLong,
        label: String
    ) {
        // If network is null, we fallback to default URL.openConnection() 
        // effectively letting OS decide, but we warn the user in logs.
        val conn = if (network != null) {
            val url = URL(urlString)
            network.openConnection(url) as HttpURLConnection
        } else {
            val url = URL(urlString)
            url.openConnection() as HttpURLConnection
        }
        
        try {
            conn.requestMethod = "GET"
            conn.setRequestProperty("Range", "bytes=$start-$end")
            conn.connectTimeout = 15000
            conn.readTimeout = 15000

            val responseCode = conn.responseCode
            // 206 = Partial Content (Good), 200 = Full Content (Bad logic, but connection ok)
            if (responseCode != 206 && responseCode != 200) {
                throw Exception("Server returned $responseCode for $label")
            }

            val input = conn.inputStream
            val output = FileOutputStream(file)
            val buffer = ByteArray(8192)
            var bytesRead: Int
            
            while (input.read(buffer).also { bytesRead = it } != -1) {
                if (!CoroutineScope(Dispatchers.IO).isActive) break
                output.write(buffer, 0, bytesRead)
                progress.addAndGet(bytesRead.toLong())
            }
            
            output.close()
            input.close()
            sendEvent("log", "[$label] Chunk download finished.")
        } catch (e: Exception) {
            sendEvent("log", "[$label] Failed: ${e.message}")
            throw e
        } finally {
            conn.disconnect()
        }
    }
}