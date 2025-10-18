//
//  RealTimeRecognitionView.swift
//  lovpic
//
//  Created by Codex on 2025-01-14.
//

import SwiftUI
import AVFoundation
import Vision
import CoreML
import UIKit

struct RealTimeRecognitionView: View {
    @StateObject private var viewModel = RealTimeRecognitionViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()
                .overlay {
                    GeometryReader { proxy in
                        ForEach(viewModel.detections) { detection in
                            DetectionOverlayView(detection: detection, canvasSize: proxy.size)
                        }
                    }
                }

            if viewModel.isPermissionDenied {
                PermissionOverlayView(
                    title: "需要摄像头权限",
                    message: "请在系统设置中允许“lovpic”访问摄像头，以便实时识别实景中的物体。",
                    primaryAction: .init(title: "前往设置") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                )
            } else if viewModel.isSessionUnavailable {
                PermissionOverlayView(
                    title: "无法启动相机",
                    message: "当前设备不支持摄像头或被其他应用占用，请稍后再试。",
                    primaryAction: nil
                )
            } else if viewModel.modelLoadFailed {
                PermissionOverlayView(
                    title: "模型加载失败",
                    message: "无法加载识别模型，请尝试重新启动应用或检查模型文件是否存在。",
                    primaryAction: nil
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.start()
            } else if newPhase == .background {
                viewModel.stop()
            }
        }
    }
}

// MARK: - Detection Overlay

struct DetectionOverlayView: View {
    let detection: DetectedObject
    let canvasSize: CGSize

    private var convertedRect: CGRect {
        let rect = detection.boundingBox
        let width = rect.width * canvasSize.width
        let height = rect.height * canvasSize.height
        let x = rect.origin.x * canvasSize.width
        let y = (1 - rect.origin.y - rect.height) * canvasSize.height
        return CGRect(x: x, y: y, width: width, height: height)
    }

    var body: some View {
        let rect = convertedRect

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.yellow, lineWidth: 3)

            Text("\(detection.label) • \(detection.confidenceText)")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
                .padding(8)
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .position(x: rect.midX, y: rect.midY)
        .animation(.easeInOut(duration: 0.2), value: detection.id)
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected AVCaptureVideoPreviewLayer.")
        }
        return layer
    }
}

// MARK: - Permission Overlay

struct PermissionOverlayView: View {
    struct Action {
        let title: String
        let handler: () -> Void
    }

    let title: String
    let message: String
    let primaryAction: Action?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .padding(.bottom, 4)

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 16, weight: .regular))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal)

            if let action = primaryAction {
                Button(action: action.handler) {
                    Text(action.title)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 32)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.65))
    }
}

// MARK: - Model & ViewModel

struct DetectedObject: Identifiable, Equatable {
    let id: UUID
    let label: String
    let confidence: Float
    /// Bounding box in Vision normalized coordinates (origin bottom-left).
    let boundingBox: CGRect

    var confidenceText: String {
        String(format: "%.0f%%", confidence * 100)
    }
}

final class RealTimeRecognitionViewModel: NSObject, ObservableObject {
    @Published var detections: [DetectedObject] = []
    @Published var isPermissionDenied = false
    @Published var isSessionUnavailable = false
    @Published var modelLoadFailed = false

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.lovpic.objectdetection.session")
    private let outputQueue = DispatchQueue(label: "com.lovpic.objectdetection.output")
    private var isConfigured = false
    private var frameCounter = 0
    private lazy var coreMLRequest: VNCoreMLRequest? = {
        do {
            let configuration = MLModelConfiguration()
            configuration.computeUnits = .all
            let model = try YOLOv3Tiny(configuration: configuration)
            let visionModel = try VNCoreMLModel(for: model.model)
            let request = VNCoreMLRequest(model: visionModel) { [weak self] request, error in
                self?.handleDetections(request: request, error: error)
            }
            request.imageCropAndScaleOption = .scaleFill
            return request
        } catch {
            DispatchQueue.main.async {
                self.modelLoadFailed = true
                self.isSessionUnavailable = false
            }
            return nil
        }
    }()

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSessionIfNeeded()
        case .notDetermined:
            requestCameraAccess()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.isPermissionDenied = true
            }
        @unknown default:
            DispatchQueue.main.async {
                self.isPermissionDenied = true
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.frameCounter = 0
            DispatchQueue.main.async {
                self.detections = []
            }
        }
    }

    private func requestCameraAccess() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            DispatchQueue.main.async {
                self.isPermissionDenied = !granted
            }
            if granted {
                self.configureSessionIfNeeded()
            }
        }
    }

    private func configureSessionIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isConfigured else {
                DispatchQueue.main.async {
                    self.isPermissionDenied = false
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                return
            }

            guard self.coreMLRequest != nil else {
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.isSessionUnavailable = true
                }
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.isSessionUnavailable = true
                }
                return
            }

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: self.outputQueue)

            if self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
            } else {
                self.session.commitConfiguration()
                DispatchQueue.main.async {
                    self.isSessionUnavailable = true
                }
                return
            }

            if let connection = videoOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            }

            self.session.commitConfiguration()
            self.isConfigured = true
            DispatchQueue.main.async {
                self.isPermissionDenied = false
                self.isSessionUnavailable = false
            }
            self.frameCounter = 0

            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func handleDetections(request: VNRequest, error: Error?) {
        guard error == nil else { return }
        guard let observations = request.results as? [VNRecognizedObjectObservation] else { return }

        let objects: [DetectedObject] = observations
            .sorted(by: { ($0.labels.first?.confidence ?? 0) > ($1.labels.first?.confidence ?? 0) })
            .prefix(6)
            .compactMap { observation in
                guard let bestLabel = observation.labels.first, bestLabel.confidence >= 0.25 else { return nil }
                return DetectedObject(id: observation.uuid, label: bestLabel.identifier, confidence: bestLabel.confidence, boundingBox: observation.boundingBox)
            }

        DispatchQueue.main.async {
            self.detections = objects
        }
    }
}

extension RealTimeRecognitionViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % 6 == 0 else {
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = coreMLRequest else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            // Ignore transient errors and keep the session alive.
        }
    }
}
