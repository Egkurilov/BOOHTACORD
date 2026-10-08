package ru.boohtacord.voice.start

object AdmissionPolicy {
    fun permitsStart(active: Boolean, visible: Boolean, microphoneGranted: Boolean): Boolean =
        microphoneGranted && (active || visible)
}
