package com.julong.mine_repair_flutter

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import cn.jpush.android.api.JPushInterface
import java.util.HashSet

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.julong.mine_repair_flutter/jpush"
        private const val NOTIFICATION_PERMISSION_REQUEST = 1001
        private const val NOTIFICATION_CHANNEL_ID = "message"
        private const val NOTIFICATION_CHANNEL_NAME = "消息通知"

        // 暂存 Flutter 引擎未就绪时的通知点击数据
        private var pendingNotificationData: Bundle? = null
    }

    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Android 8.0+ 创建通知渠道（必须有渠道才有声音和震动）
        createNotificationChannel()
        // 初始化极光推送
        JPushInterface.setDebugMode(true)
        JPushInterface.init(applicationContext)
        // 检查是否从通知点击启动
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        handleNotificationIntent(intent)
    }

    /** 提取通知 extras 并发送到 Flutter */
    private fun handleNotificationIntent(intent: android.content.Intent?) {
        if (intent == null) return
        val extras = intent.extras ?: return
        // JPush 推送的 extras 直接以 key-value 形式存放
        val type = extras.getString("type") ?: return
        val data = mapOf(
            "type" to type,
            "order_id" to extras.getString("order_id"),
            "cn.jpush.android.NOTIFICATION_ID" to extras.getInt("cn.jpush.android.NOTIFICATION_ID", 0).toString()
        ).filterValues { it != null }

        val channel = this.channel
        if (channel != null) {
            channel.invokeMethod("onOpenNotification", data)
        } else {
            // Flutter 引擎尚未就绪，暂存数据待后续处理
            pendingNotificationData = Bundle().apply {
                putString("type", type)
                putString("order_id", extras.getString("order_id"))
            }
        }
    }

    /**
     * 创建高优先级通知渠道 — 没有渠道则 Android 8.0+ 通知无声音/无震动
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                NOTIFICATION_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH  // 声音 + 震动 + 通知栏弹出
            ).apply {
                description = "维修工单、审批、隐患等实时通知"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                enableLights(true)
                lightColor = 0xFFC8A04A.toInt()
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        this.channel = ch
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "setup" -> {
                        result.success(true)
                        // 引擎就绪后处理暂存的通知点击
                        pendingNotificationData?.let { data ->
                            val type = data.getString("type") ?: return@let
                            ch.invokeMethod("onOpenNotification", mapOf(
                                "type" to type,
                                "order_id" to data.getString("order_id")
                            ).filterValues { it != null })
                            pendingNotificationData = null
                        }
                    }

                    "getRegistrationID" -> {
                        val rid = JPushInterface.getRegistrationID(applicationContext)
                        result.success(rid ?: "")
                    }

                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            if (ContextCompat.checkSelfPermission(
                                    this, Manifest.permission.POST_NOTIFICATIONS
                                ) != PackageManager.PERMISSION_GRANTED
                            ) {
                                ActivityCompat.requestPermissions(
                                    this,
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    NOTIFICATION_PERMISSION_REQUEST
                                )
                            }
                        }
                        // 总是返回 true，低于 Android 13 或已授权的设备直接过
                        result.success(true)
                    }

                    "setAlias" -> {
                        val alias = call.argument<String>("alias") ?: ""
                        JPushInterface.setAlias(applicationContext, 0, alias)
                        result.success(true)
                    }

                    "deleteAlias" -> {
                        JPushInterface.deleteAlias(applicationContext, 0)
                        result.success(true)
                    }

                    "addTags" -> {
                        val tags = call.argument<List<String>>("tags") ?: emptyList()
                        JPushInterface.addTags(applicationContext, 0, HashSet(tags))
                        result.success(true)
                    }

                    "removeTags" -> {
                        val tags = call.argument<List<String>>("tags") ?: emptyList()
                        JPushInterface.deleteTags(applicationContext, 0, HashSet(tags))
                        result.success(true)
                    }

                    "cleanTags" -> {
                        JPushInterface.cleanTags(applicationContext, 0)
                        result.success(true)
                    }

                    "stopPush" -> {
                        JPushInterface.stopPush(applicationContext)
                        result.success(true)
                    }

                    "resumePush" -> {
                        JPushInterface.resumePush(applicationContext)
                        result.success(true)
                    }

                    "isPushStopped" -> {
                        result.success(JPushInterface.isPushStopped(applicationContext))
                    }

                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("JPUSH_ERROR", e.message, null)
            }
        }
    }
}
