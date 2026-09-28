package ru.boohtacord.app

import android.app.Activity
import android.app.ActivityManager
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "boohtacord/download"
    private val screenShareChannelName = "boohtacord/screen_share"
    private val audioDevicesChannelName = "boohtacord/audio_devices"
    private val usbOutputRoutePrefix = "android-usb-route:"
    private val backgroundServiceClassName =
        "de.julianassmann.flutter_background.IsolateHolderService"
    private val requestCode = 7641
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "save") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (pendingSaveResult != null) {
                    result.error("SAVE_IN_PROGRESS", "A save dialog is already open.", null)
                    return@setMethodCallHandler
                }
                val bytes = call.argument<ByteArray>("bytes")
                val name = call.argument<String>("filename")
                val mime = call.argument<String>("mimeType") ?: "application/octet-stream"
                if (bytes == null || name.isNullOrBlank()) {
                    result.error("INVALID_ARGUMENT", "File name and bytes are required.", null)
                    return@setMethodCallHandler
                }
                pendingBytes = bytes
                pendingSaveResult = result
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = mime
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    startActivityForResult(intent, requestCode)
                } catch (error: Exception) {
                    pendingBytes = null
                    pendingSaveResult = null
                    result.error("SAVE_FAILED", error.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, screenShareChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "awaitForegroundService") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val timeoutMs = (call.argument<Int>("timeoutMs") ?: 3000)
                    .coerceIn(250, 5000)
                val startedAt = SystemClock.elapsedRealtime()
                val activityManager =
                    getSystemService(ACTIVITY_SERVICE) as ActivityManager

                fun checkForegroundState() {
                    val isForeground = activityManager
                        .getRunningServices(Int.MAX_VALUE)
                        .any { service ->
                            service.service.className == backgroundServiceClassName &&
                                service.foreground
                        }
                    if (isForeground) {
                        result.success(true)
                    } else if (SystemClock.elapsedRealtime() - startedAt >= timeoutMs) {
                        result.success(false)
                    } else {
                        mainHandler.postDelayed(::checkForegroundState, 50)
                    }
                }

                checkForegroundState()
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioDevicesChannelName)
            .setMethodCallHandler { call, result ->
                val audioManager = getSystemService(AUDIO_SERVICE) as AudioManager
                when (call.method) {
                    "enumerateUsb" -> {
                        val usbTypes = setOf(
                            AudioDeviceInfo.TYPE_USB_DEVICE,
                            AudioDeviceInfo.TYPE_USB_HEADSET,
                        )
                        val devices = mutableListOf<Map<String, String>>()

                        val inputs = audioManager
                            .getDevices(AudioManager.GET_DEVICES_INPUTS)
                            .filter { it.type in usbTypes }
                        inputs.forEachIndexed { index, device ->
                            devices += mapOf(
                                "deviceId" to device.id.toString(),
                                "kind" to "audioinput",
                                "label" to device.productName.toString().ifBlank {
                                    "USB-микрофон ${index + 1}"
                                },
                                "groupId" to "usb:${device.id}",
                            )
                        }

                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            audioManager.availableCommunicationDevices
                                .filter { it.type in usbTypes }
                                .forEachIndexed { index, device ->
                                    devices += mapOf(
                                        "deviceId" to usbOutputRoutePrefix + device.id,
                                        "kind" to "audiooutput",
                                        "label" to device.productName.toString().ifBlank {
                                            "USB-аудиоустройство ${index + 1}"
                                        },
                                        "groupId" to "usb:${device.id}",
                                    )
                                }
                        }
                        result.success(devices)
                    }
                    "selectUsbOutput" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val requestedId = call.argument<String>("deviceId")
                            ?.toIntOrNull()
                        val route = audioManager.availableCommunicationDevices
                            .firstOrNull {
                                it.id == requestedId &&
                                    (it.type == AudioDeviceInfo.TYPE_USB_DEVICE ||
                                        it.type == AudioDeviceInfo.TYPE_USB_HEADSET)
                            }
                        result.success(route != null && audioManager.setCommunicationDevice(route))
                    }
                    "clearUsbOutput" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            audioManager.clearCommunicationDevice()
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Android, retained for Flutter activity result routing")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != this.requestCode) return
        val result = pendingSaveResult ?: return
        val bytes = pendingBytes
        pendingSaveResult = null
        pendingBytes = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(false)
            return
        }
        val uri: Uri? = data?.data
        if (uri == null || bytes == null) {
            result.error("SAVE_FAILED", "The document provider returned no file.", null)
            return
        }
        try {
            contentResolver.openOutputStream(uri)?.use { output -> output.write(bytes) }
                ?: throw IllegalStateException("Could not open the selected document.")
            result.success(true)
        } catch (error: Exception) {
            result.error("SAVE_FAILED", error.message, null)
        }
    }
}
