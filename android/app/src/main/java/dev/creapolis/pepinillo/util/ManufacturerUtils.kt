package dev.creapolis.pepinillo.util

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build

object ManufacturerUtils {

    private val autoStartIntents: Map<String, List<Intent>> by lazy {
        mapOf(
            "xiaomi" to listOf(
                Intent().setComponent(
                    ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity",
                    ),
                ),
            ),
            "huawei" to listOf(
                Intent().setComponent(
                    ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                    ),
                ),
                Intent().setComponent(
                    ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.optimize.process.ProtectActivity",
                    ),
                ),
            ),
            "honor" to listOf(
                Intent().setComponent(
                    ComponentName(
                        "com.huawei.systemmanager",
                        "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                    ),
                ),
            ),
            "samsung" to listOf(
                Intent().setComponent(
                    ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.battery.ui.BatteryActivity",
                    ),
                ),
                Intent().setComponent(
                    ComponentName(
                        "com.samsung.android.lool",
                        "com.samsung.android.sm.ui.battery.BatteryActivity",
                    ),
                ),
            ),
            "oppo" to listOf(
                Intent().setComponent(
                    ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.startupapp.StartupAppListActivity",
                    ),
                ),
                Intent().setComponent(
                    ComponentName(
                        "com.oppo.safe",
                        "com.oppo.safe.permission.startup.StartupAppListActivity",
                    ),
                ),
            ),
            "realme" to listOf(
                Intent().setComponent(
                    ComponentName(
                        "com.coloros.safecenter",
                        "com.coloros.safecenter.startupapp.StartupAppListActivity",
                    ),
                ),
            ),
            "vivo" to listOf(
                Intent().setComponent(
                    ComponentName(
                        "com.vivo.permissionmanager",
                        "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                    ),
                ),
                Intent().setComponent(
                    ComponentName(
                        "com.iqoo.secure",
                        "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
                    ),
                ),
            ),
            "oneplus" to listOf(
                Intent().setComponent(
                    ComponentName(
                        "com.oneplus.security",
                        "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
                    ),
                ),
            ),
            "asus" to listOf(
                Intent().setComponent(
                    ComponentName(
                        "com.asus.mobilemanager",
                        "com.asus.mobilemanager.autostart.AutoStartActivity",
                    ),
                ),
            ),
        )
    }

    fun hasKnownAutoStartSettings(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return autoStartIntents.keys.any { manufacturer.contains(it) }
    }

    fun getAutoStartIntent(context: Context): Intent? {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val intents = autoStartIntents.entries
            .firstOrNull { manufacturer.contains(it.key) }
            ?.value ?: return null

        return intents.firstOrNull { intent ->
            context.packageManager.resolveActivity(intent, 0) != null
        }
    }

    fun getManufacturerDisplayName(): String {
        val manufacturer = Build.MANUFACTURER
        return manufacturer.replaceFirstChar { it.uppercase() }
    }
}
