package id.xydesk.remote.ui

import android.graphics.BitmapFactory
import androidx.activity.ComponentActivity
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import com.github.takahirom.roborazzi.captureRoboImage
import id.xydesk.remote.core.SessionState
import id.xydesk.remote.core.TelemetrySample
import id.xydesk.remote.ui.components.rememberXyNotice
import id.xydesk.remote.ui.theme.XyDeskTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.io.File

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "w854dp-h480dp-land-xhdpi")
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SessionControlsRealRenderTest {

    @get:Rule
    val composeRule = createAndroidComposeRule<ComponentActivity>()

    @Test
    fun renderAllThreeApkUiStates() {
        val outDirPath = System.getProperty("xyrdp.qa.outdir") ?: "/tmp/apk-ui-screenshots"
        val outDir = File(outDirPath).apply { mkdirs() }
        val bgPath = System.getProperty("xyrdp.qa.bg") ?: ""
        val bgBitmap = if (bgPath.isNotEmpty() && File(bgPath).exists()) {
            BitmapFactory.decodeFile(bgPath)
        } else {
            null
        }

        val sampleTelemetry = TelemetrySample(
            state = SessionState.Connected,
            width = 1920,
            height = 1080,
            fps = 60,
            rttMs = 12,
            codecLabel = "H.264 AVC444 (Lively 60Hz)",
            udpActive = true,
            colorDepth = 32,
            relayLabel = "XyRDP Zero-Lag",
            networkLabel = "Wi-Fi 5GHz",
            frameIntervalMs = 16,
            pipelineLatencyMs = 4,
        )

        composeRule.setContent {
            XyDeskTheme(dark = true) {
                var hudKeys by remember {
                    mutableStateOf(HudKey.presetLayout(HudProfilePreset.SAMP_GTA))
                }
                var inputMode by remember { mutableStateOf(InputMode.TRACKPAD) }
                val notice = rememberXyNotice()

                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color(0xFF0B1020))
                ) {
                    if (bgBitmap != null) {
                        Image(
                            bitmap = bgBitmap.asImageBitmap(),
                            contentDescription = null,
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Crop,
                        )
                    } else {
                        Canvas(modifier = Modifier.fillMaxSize()) {
                            drawRect(
                                brush = Brush.linearGradient(
                                    colors = listOf(
                                        Color(0xFF0F172A),
                                        Color(0xFF1E1B4B),
                                        Color(0xFF0F172A),
                                    )
                                )
                            )
                        }
                    }

                    SessionControls(
                        deviceId = "xyrdp-win2022-gaming",
                        hostLabel = "XyRDP Windows Server 2022 (Gaming Suite)",
                        statusText = "Terhubung · Lively 60Hz Sync",
                        remoteSize = "1920 x 1080",
                        zoomPercent = 100,
                        remoteDpi = 100,
                        telemetry = sampleTelemetry,
                        pointerScreen = Offset(520f, 310f),
                        pointerVisible = true,
                        remoteCursor = null,
                        zoom = 1f,
                        inputMode = inputMode,
                        externalInputDeviceConnected = false,
                        onInputModeChange = { inputMode = it },
                        keys = hudKeys,
                        onKeysChange = { hudKeys = it },
                        latchedKeyIds = emptySet(),
                        onKeyEdited = {},
                        onDeleteKey = {},
                        mappingMode = false,
                        onMappingModeChange = {},
                        onPhase = { _, _ -> },
                        onScrollUnits = {},
                        onZoomIn = {},
                        onZoomOut = {},
                        onFit = {},
                        onZoomActual = {},
                        onZoomScale = {},
                        onRemoteDpiChange = {},
                        onDisplayRefreshPreferenceChange = {},
                        onScreenshot = {},
                        onDisconnect = {},
                        onGoHome = {},
                        onPointerVisibilityChange = {},
                        onResetCluster = {},
                        onRotationChange = {},
                        onResolutionChange = {},
                        onOpenKeyboard = {},
                        onOpenHome = {},
                        lastClipboard = "samp.xydeskremote.biz.id:7777",
                        clipboardSyncEnabled = true,
                        onSendText = {},
                        onSendRemoteClipboardText = { true },
                        activeUsername = "xyadmin",
                        consoleAdminMode = true,
                        fpsGameMode = true,
                        rawInputUdpAlive = true,
                        voiceMicEnabled = true,
                        coreInfo = listOf(
                            "Engine: XyRDP Zero-Lag 2.11 + AVC444",
                            "Lively Wallpaper: 60 FPS Continuous Sync (Anti-Stuck)",
                            "Audio: RDPSND + VB-Cable Virtual Sound",
                        ),
                        notice = notice,
                    )
                }
            }
        }

        composeRule.waitForIdle()

        // STATE 1: HUD Utama + Rail Kanan Bawah (Panah + Keyboard) Terpisah dari Handle MENU Kanan Atas
        composeRule.onRoot().captureRoboImage(
            File(outDir, "11_APK_UI_State1_HUD_Dan_Rail_Terpisah.png")
        )

        // STATE 2: Klik Tombol Panah di atas Keyboard ("Aksi cepat") -> Membuka Bubble Aksi Cepat (TANPA membuka Menu Popup Utama!)
        composeRule.onNodeWithContentDescription("Aksi cepat").performClick()
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage(
            File(outDir, "12_APK_UI_State2_BubblePanahKeyboard_AksiCepat.png")
        )

        // STATE 3: Klik Handle MENU di Kanan Atas ("Buka panel kontrol sesi") -> Membuka Menu Popup Utama (SessionPanel + Lively 60Hz) & Menutup Bubble Panah!
        composeRule.onNodeWithContentDescription("Buka panel kontrol sesi").performClick()
        composeRule.waitForIdle()
        composeRule.onRoot().captureRoboImage(
            File(outDir, "13_APK_UI_State3_MenuPopup_PanelUtama_Lively60Hz.png")
        )
    }
}
