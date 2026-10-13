package com.lenga.lenga_app

import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * On-device Gemini Nano through the ML Kit GenAI Prompt API. Only used to
 * pre-generate problems; Dart validates every answer, and the challenge never
 * waits on this.
 */
object AiProblemService {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var model: GenerativeModel? = null
    private var downloading = false

    private fun client(): GenerativeModel = model ?: Generation.getClient().also { model = it }

    /** "available", "downloading" or "unavailable" (matches Dart's AiAvailability). */
    suspend fun availability(): String = try {
        when (client().checkStatus()) {
            FeatureStatus.AVAILABLE -> "available"
            FeatureStatus.DOWNLOADABLE -> {
                startDownload()
                "downloading"
            }
            FeatureStatus.DOWNLOADING -> "downloading"
            else -> "unavailable"
        }
    } catch (_: Throwable) {
        "unavailable" // unsupported device, emulator, unlocked bootloader, AICore missing...
    }

    private fun startDownload() {
        if (downloading) return
        downloading = true
        scope.launch {
            try {
                client().download().collect { status ->
                    if (status is DownloadStatus.DownloadCompleted || status is DownloadStatus.DownloadFailed) {
                        downloading = false
                    }
                }
            } catch (_: Throwable) {
                downloading = false
            }
        }
    }

    suspend fun generate(prompt: String): String {
        val response = client().generateContent(prompt)
        return response.candidates.firstOrNull()?.text ?: ""
    }
}
