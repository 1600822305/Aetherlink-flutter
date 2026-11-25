package com.example.aetherlink_flutter

import android.app.Application
import com.example.aetherlink_flutter.background.BackgroundRuntime

class AetherlinkApplication : Application() {
    val backgroundRuntime by lazy { BackgroundRuntime(this) }
}
