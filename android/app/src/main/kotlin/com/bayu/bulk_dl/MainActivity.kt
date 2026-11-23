package com.bayu.bulk_dl

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var pendingShare: String? = null

    private fun sharedText(i: Intent?): String? =
        if (i?.action == Intent.ACTION_SEND) i.getStringExtra(Intent.EXTRA_TEXT) else null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        pendingShare = sharedText(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sharedText(intent)?.let { channel?.invokeMethod("shared", it) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bulk_dl/files")
        channel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "export" -> {
                        val path = call.argument<String>("path")!!
                        val name = call.argument<String>("name")!!
                        Thread {
                            val r = try { export(path, name) } catch (e: Exception) { null }
                            main.post { result.success(r) }
                        }.start()
                    }
                    "exists" -> result.success(exists(call.argument<String>("uri")!!))
                    "open" -> result.success(launch(call.argument<String>("uri")!!, false))
                    "share" -> result.success(launch(call.argument<String>("uri")!!, true))
                    "initialShare" -> {
                        result.success(pendingShare)
                        pendingShare = null
                    }
                    "delete" -> result.success(delete(call.argument<String>("uri")!!))
                    else -> result.notImplemented()
                }
            }
    }

    /** Copies [path] into the public Movies/BulkDL folder (gallery visible). */
    private fun export(path: String, name: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, name)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/BulkDL")
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values) ?: return null
        try {
            resolver.openOutputStream(uri)!!.use { out ->
                File(path).inputStream().use { it.copyTo(out, 256 * 1024) }
            }
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        } catch (e: Exception) {
            resolver.delete(uri, null, null)
            return null
        }
        return uri.toString()
    }

    private fun exists(uri: String): Boolean = try {
        contentResolver.openFileDescriptor(Uri.parse(uri), "r")?.use { true } ?: false
    } catch (e: Exception) {
        false
    }

    private fun delete(uri: String): Boolean = try {
        contentResolver.delete(Uri.parse(uri), null, null) > 0
    } catch (e: Exception) {
        false
    }

    private fun launch(uri: String, share: Boolean): Boolean = try {
        val u = Uri.parse(uri)
        val i = if (share) {
            Intent.createChooser(
                Intent(Intent.ACTION_SEND).apply {
                    type = "video/mp4"
                    putExtra(Intent.EXTRA_STREAM, u)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }, null
            )
        } else {
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(u, "video/mp4")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }
        startActivity(i)
        true
    } catch (e: Exception) {
        false
    }
}
