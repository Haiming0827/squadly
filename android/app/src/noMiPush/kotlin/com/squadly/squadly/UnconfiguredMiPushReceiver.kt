package com.squadly.squadly

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Manifest-safe placeholder; Mi Push is disabled until its official AAR is supplied. */
class UnconfiguredMiPushReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = Unit
}
