package com.squadly.health_connect_bridge

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.widget.TextView

class HealthPermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val rationale = TextView(this).apply {
            text = "Squadly 仅在你主动导入运动记录时读取运动时段和对应距离。记录会先保存为仅自己可见的个人素材；只有你再次确认分享后，才会发布一份固定快照。我们不在后台持续读取健康数据。"
            textSize = 18f
            setPadding(48, 48, 48, 48)
            gravity = Gravity.CENTER_VERTICAL
        }
        setContentView(rationale)
    }
}
