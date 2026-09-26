package ru.boohtacord.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "boohtacord/download"
    private val requestCode = 7641
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
