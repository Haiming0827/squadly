package com.squadly.squadly

import android.content.Context
import com.xiaomi.mipush.sdk.MiPushCommandMessage
import com.xiaomi.mipush.sdk.MiPushMessage
import com.xiaomi.mipush.sdk.PushMessageReceiver

/** Keep vendor payloads out of logs; Flutter syncs the canonical conversation on open. */
class MiPushMessageReceiver : PushMessageReceiver() {
    override fun onNotificationMessageClicked(context: Context, message: MiPushMessage) = Unit

    override fun onNotificationMessageArrived(context: Context, message: MiPushMessage) = Unit

    override fun onCommandResult(context: Context, message: MiPushCommandMessage) = Unit

    override fun onReceiveRegisterResult(context: Context, message: MiPushCommandMessage) = Unit

    override fun onRequirePermissions(context: Context, permissions: Array<out String>) = Unit
}
