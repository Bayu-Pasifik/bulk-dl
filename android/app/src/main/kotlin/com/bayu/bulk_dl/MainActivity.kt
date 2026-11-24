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

    private var vpn: VpnBridge? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (vpn?.onActivityResult(requestCode, resultCode) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = VpnBridge(this)
        vpn = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bulk_dl/vpn")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "up" -> bridge.up(call.argument<String>("config")!!, result)
                    "down" -> bridge.down(result)
                    "isUp" -> result.success(bridge.isUp())
                    else -> result.notImplemented()
                }
            }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bulk_dl/files")
        channel!!.setMethodCallHandler { call, result ->
                when (call.method) {
                    "export" -> {
                        val path = call.argument<String>("path")!!
                        val name = call.argument<String>("name")!!
                        val mime = call.argument<String>("mime") ?: "application/octet-stream"
                        Thread {
                            val r = try { export(path, name, mime) } catch (e: Exception) { null }
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

    /** Copies [path] into a public BulkDL folder matching [mime] (gallery/files visible). */
    private fun export(path: String, name: String, mime: String): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val (collection, dir) = when {
            mime.startsWith("video/") -> MediaStore.Video.Media.EXTERNAL_CONTENT_URI to "Movies/BulkDL"
            mime.startsWith("audio/") -> MediaStore.Audio.Media.EXTERNAL_CONTENT_URI to "Music/BulkDL"
            mime.startsWith("image/") -> MediaStore.Images.Media.EXTERNAL_CONTENT_URI to "Pictures/BulkDL"
            else -> MediaStore.Downloads.EXTERNAL_CONTENT_URI to "Download/BulkDL"
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH, dir)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = contentResolver
        val uri = resolver.insert(collection, values) ?: return null
        try {
            resolver.openOutputStream(uri)!!.use { out ->
                File(path).inputStream().use { it.copyTo(out, 256 * 1024) }
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
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
                    type = contentResolver.getType(u) ?: "*/*"
                    putExtra(Intent.EXTRA_STREAM, u)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }, null
            )
        } else {
            Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(u, contentResolver.getType(u) ?: "*/*")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
        }
        startActivity(i)
        true
    } catch (e: Exception) {
        false
    }
}
