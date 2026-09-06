package com.example.sehatpass

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import com.google.zxing.BarcodeFormat
import com.google.zxing.qrcode.QRCodeWriter

class EmergencyQrActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Configure window for lock-screen display without requiring phone unlock
        setupLockScreenFlags()

        setContentView(R.layout.activity_emergency_qr)

        setupEmergencyData()
        setupListeners()
    }

    private fun setupLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }

        // Keep screen bright while viewing emergency QR
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        // Increase screen brightness for reliable QR scanning
        val layoutParams = window.attributes
        layoutParams.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL
        window.attributes = layoutParams
    }

    private fun setupEmergencyData() {
        val manager = LockScreenEmergencyManager.getInstance(this)
        val data = manager.getStoredEmergencyData()

        val qrUrl = data[LockScreenEmergencyManager.KEY_QR_URL] ?: ""
        val patientName = data[LockScreenEmergencyManager.KEY_PATIENT_NAME] ?: ""
        val bloodGroup = data[LockScreenEmergencyManager.KEY_BLOOD_GROUP] ?: ""
        val emergencyContact = data[LockScreenEmergencyManager.KEY_EMERGENCY_CONTACT]
        val token = data[LockScreenEmergencyManager.KEY_TOKEN] ?: ""

        val imgQr = findViewById<ImageView>(R.id.imgEmergencyQr)
        val tvPatientName = findViewById<TextView>(R.id.tvPatientName)
        val tvBloodGroup = findViewById<TextView>(R.id.tvBloodGroup)
        val layoutBloodGroup = findViewById<LinearLayout>(R.id.layoutBloodGroup)
        val tvEmergencyContact = findViewById<TextView>(R.id.tvEmergencyContact)
        val tvTokenId = findViewById<TextView>(R.id.tvTokenId)

        // Set Patient Name
        tvPatientName.text = if (patientName.isNotBlank()) patientName else "Emergency Patient Profile"

        // Set Blood Group
        if (bloodGroup.isNotBlank()) {
            tvBloodGroup.text = "Blood Group: $bloodGroup"
            layoutBloodGroup.visibility = View.VISIBLE
        } else {
            layoutBloodGroup.visibility = View.GONE
        }

        // Set Emergency Contact
        if (!emergencyContact.isNullOrBlank()) {
            tvEmergencyContact.text = "Emergency Contact: $emergencyContact"
            tvEmergencyContact.visibility = View.VISIBLE
        } else {
            tvEmergencyContact.visibility = View.GONE
        }

        // Set Token
        if (token.isNotBlank()) {
            tvTokenId.text = "Token: $token"
            tvTokenId.visibility = View.VISIBLE
        } else {
            tvTokenId.visibility = View.GONE
        }

        // Generate QR code Bitmap
        if (qrUrl.isNotBlank()) {
            val qrBitmap = generateQrBitmap(qrUrl, 600)
            if (qrBitmap != null) {
                imgQr.setImageBitmap(qrBitmap)
            } else {
                imgQr.setImageResource(R.mipmap.ic_launcher)
            }
        } else {
            imgQr.setImageResource(R.mipmap.ic_launcher)
        }
    }

    private fun setupListeners() {
        val btnCloseTop = findViewById<TextView>(R.id.btnCloseTop)
        val btnDone = findViewById<Button>(R.id.btnDone)

        val closeAction = View.OnClickListener {
            finish()
        }

        btnCloseTop?.setOnClickListener(closeAction)
        btnDone?.setOnClickListener(closeAction)
    }

    private fun generateQrBitmap(content: String, sizePx: Int): Bitmap? {
        if (content.isBlank()) return null
        return try {
            val bitMatrix = QRCodeWriter().encode(
                content,
                BarcodeFormat.QR_CODE,
                sizePx,
                sizePx
            )
            val width = bitMatrix.width
            val height = bitMatrix.height
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.RGB_565)
            for (x in 0 until width) {
                for (y in 0 until height) {
                    bitmap.setPixel(x, y, if (bitMatrix[x, y]) Color.BLACK else Color.WHITE)
                }
            }
            bitmap
        } catch (e: Exception) {
            null
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        super.onBackPressed()
        finish()
    }
}
