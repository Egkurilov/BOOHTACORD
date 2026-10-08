package ru.boohtacord.voice.start

import android.app.Activity
import android.app.Application
import android.os.Bundle

class Visibility : Application.ActivityLifecycleCallbacks {
    var owner: Activity? = null
    var visible = false
        private set
    fun attach(activity: Activity) { owner = activity; visible = activity.hasWindowFocus() }
    fun detach() { owner = null; visible = false }
    override fun onActivityResumed(activity: Activity) { if (owner === activity) visible = true }
    override fun onActivityPaused(activity: Activity) { if (owner === activity) visible = false }
    override fun onActivityStopped(activity: Activity) { if (owner === activity) visible = false }
    override fun onActivityDestroyed(activity: Activity) { if (owner === activity) detach() }
    override fun onActivityCreated(activity: Activity, state: Bundle?) {}
    override fun onActivityStarted(activity: Activity) {}
    override fun onActivitySaveInstanceState(activity: Activity, state: Bundle) {}
}
