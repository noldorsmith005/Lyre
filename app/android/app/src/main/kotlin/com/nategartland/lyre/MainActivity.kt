package com.nategartland.lyre

import android.content.ComponentName
import android.content.pm.PackageManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.nategartland.lyre/icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setAppIcon") {
                val iconName = call.argument<String>("icon") ?: "red"
                try {
                    setDynamicIcon(iconName)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ICON_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun setDynamicIcon(iconName: String) {
        val pm = applicationContext.packageManager
        val packageName = applicationContext.packageName

        val aliases = listOf("red", "green", "blue", "purple")
        val targetAlias = if (iconName in aliases) iconName else "red"

        for (alias in aliases) {
            val aliasClassName = "$packageName.MainActivity${alias.replaceFirstChar { it.uppercase() }}"
            val componentName = ComponentName(packageName, aliasClassName)
            val state = if (alias == targetAlias) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(
                componentName,
                state,
                PackageManager.DONT_KILL_APP
            )
        }
    }
}
