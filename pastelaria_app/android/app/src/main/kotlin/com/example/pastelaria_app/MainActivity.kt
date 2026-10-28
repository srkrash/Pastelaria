package com.example.pastelaria_app

import android.os.Bundle
import android.os.Build
import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private var fileResult: MethodChannel.Result? = null
    private var backupBytes: ByteArray? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pastelaria/server").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "saveBackup" -> {
                        if (fileResult != null) { result.error("BUSY", "Seletor de arquivo já aberto.", null); return@setMethodCallHandler }
                        backupBytes = call.argument<ByteArray>("bytes")
                        fileResult = result
                        startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/octet-stream"
                            putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
                        }, 4101)
                    }
                    "readBackup" -> {
                        if (fileResult != null) { result.error("BUSY", "Seletor de arquivo já aberto.", null); return@setMethodCallHandler }
                        fileResult = result
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                        }, 4102)
                    }
                    "start" -> {
                        val intent = Intent(this, LocalServerService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent) else startService(intent)
                        result.success(null)
                    }
                    "stop" -> { stopService(Intent(this, LocalServerService::class.java)); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { fileResult = null; backupBytes = null; result.error("SERVER_SERVICE", e.message, null) }
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 4101 && requestCode != 4102) return
        val reply = fileResult ?: return
        fileResult = null
        try {
            val uri = data?.data
            if (resultCode != RESULT_OK || uri == null) { reply.success(null); return }
            if (requestCode == 4101) {
                val bytes = backupBytes ?: throw IllegalStateException("Backup ausente")
                contentResolver.openOutputStream(uri)?.use { it.write(bytes) } ?: throw IllegalStateException("Arquivo indisponível")
                reply.success(true)
            } else {
                val bytes = contentResolver.openInputStream(uri)?.use { input ->
                    val output = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    var count = input.read(buffer)
                    while (count != -1) {
                        if (output.size() + count > 64 * 1024 * 1024) throw IllegalArgumentException("Backup excede 64 MB")
                        output.write(buffer, 0, count)
                        count = input.read(buffer)
                    }
                    output.toByteArray()
                } ?: throw IllegalStateException("Arquivo indisponível")
                reply.success(bytes)
            }
        } catch (e: Exception) { reply.error("BACKUP_FILE", e.message, null) }
        finally { backupBytes = null }
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
