package com.bayu.bulk_dl

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.StringReader

/** In-app WireGuard tunnel (Android VpnService via the official tunnel library). */
class VpnBridge(private val activity: Activity) {
    companion object {
        const val REQUEST_PREPARE = 7301
    }

    private val main = Handler(Looper.getMainLooper())
    private val backend = GoBackend(activity.applicationContext)
    private val tunnel = object : Tunnel {
        override fun getName() = "bulkdl"
        override fun onStateChange(newState: Tunnel.State) {}
    }

    private var pendingConfig: String? = null
    private var pendingResult: MethodChannel.Result? = null

    fun up(config: String, result: MethodChannel.Result) {
        val intent = GoBackend.VpnService.prepare(activity)
        if (intent != null) {
            pendingConfig = config
            pendingResult = result
            activity.startActivityForResult(intent, REQUEST_PREPARE)
        } else {
            start(config, result)
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode != REQUEST_PREPARE) return false
        val cfg = pendingConfig
        val res = pendingResult
        pendingConfig = null
        pendingResult = null
        if (res != null) {
            if (resultCode == Activity.RESULT_OK && cfg != null) start(cfg, res)
            else res.error("denied", "VPN permission denied", null)
        }
        return true
    }

    private fun start(config: String, result: MethodChannel.Result) {
        Thread {
            try {
                val cfg = Config.parse(BufferedReader(StringReader(config)))
                backend.setState(tunnel, Tunnel.State.UP, cfg)
                main.post { result.success(true) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message ?: e.toString(), null) }
            }
        }.start()
    }

    fun down(result: MethodChannel.Result) {
        Thread {
            try {
                backend.setState(tunnel, Tunnel.State.DOWN, null)
                main.post { result.success(true) }
            } catch (e: Exception) {
                main.post { result.error("failed", e.message ?: e.toString(), null) }
            }
        }.start()
    }

    fun isUp(): Boolean = try {
        backend.getState(tunnel) == Tunnel.State.UP
    } catch (e: Exception) {
        false
    }
}
