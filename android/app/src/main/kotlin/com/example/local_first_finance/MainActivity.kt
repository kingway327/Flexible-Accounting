package com.example.local_first_finance

import android.os.Bundle
import java.util.Calendar
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val isDaytime = hour in 6..17
        val launchTheme = if (isDaytime) {
            R.style.LaunchThemeDay
        } else {
            R.style.LaunchThemeNight
        }
        setTheme(launchTheme)
        super.onCreate(savedInstanceState)
    }
}
