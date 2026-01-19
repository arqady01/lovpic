//
//  PoseDetectionView.swift
//  lovpic
//
//  Created by Codex on 2025-01-14.
//

import SwiftUI
import AVFoundation
import Vision
import UIKit

struct PoseDetectionView: View {
    @StateObject private var viewModel = PoseDetectionViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            CameraPreview(session: viewModel.session)
                .ignoresSafeArea()

            if let pose = viewModel.currentPose {
                PoseSkeletonOverlayView(pose: pose)
                    .transition(.opacity.combined(with: .scale))
            }

            if viewModel.isPermissionDenied {
                PermissionOverlayView(
                    title: "需要摄像头权限",
                    message: "请在系统设置中允许“lovpic”访问摄像头，以开始人体姿态检测。",
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
            } else {
                VStack {
                    Spacer()
                    PoseDebugPanel(status: viewModel.statusText, latency: viewModel.currentLatency)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            }
        }
        .navigationTitle("姿态检测")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                viewModel.start()
            case .inactive, .background:
                viewModel.stop()
            @unknown default:
                break
            }
        }
    }
}

// MARK: - Overlay Views

private struct PoseSkeletonOverlayView: View {
    let pose: PoseSkeleton

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let joints = pose.jointsByName
                let scaleTransform = CGAffineTransform.identity

                for edge in PoseSkeletonOverlayView.skeletonEdges {
                    guard
                        let jointA = joints[edge.0],
                        let jointB = joints[edge.1],
                        jointA.confidence >= pose.confidenceThreshold,
                        jointB.confidence >= pose.confidenceThreshold
                    else { continue }

                    let pointA = PoseSkeletonOverlayView.point(in: size, from: jointA.location, transform: scaleTransform)
                    let pointB = PoseSkeletonOverlayView.point(in: size, from: jointB.location, transform: scaleTransform)

                    var path = Path()
                    path.move(to: pointA)
                    path.addLine(to: pointB)
                    context.stroke(path, with: .color(pose.edgeColor.opacity(0.85)), lineWidth: 6)
                }

                for joint in pose.joints where joint.confidence >= pose.confidenceThreshold {
                    let point = PoseSkeletonOverlayView.point(in: size, from: joint.location, transform: scaleTransform)
                    let circle = Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                    context.fill(circle, with: .color(pose.jointColor))

                    if let depth = joint.depth {
                        let depthText = String(format: "%.2fm", depth)
                        let text = Text(depthText)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                        context.draw(text, at: CGPoint(x: point.x, y: point.y - 14), anchor: .center)
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                if let bounds = pose.boundingBox {
                    PoseSkeletonOverlayView.boundingBoxView(bounds: bounds)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
        .ignoresSafeArea()
    }

    private static func point(in size: CGSize, from location: CGPoint, transform: CGAffineTransform) -> CGPoint {
        let normalized = CGPoint(x: location.x, y: 1 - location.y)
        let transformed = normalized.applying(transform)
        return CGPoint(x: transformed.x * size.width, y: transformed.y * size.height)
    }

    @ViewBuilder
    private static func boundingBoxView(bounds: CGRect) -> some View {
        GeometryReader { proxy in
            let rect = CGRect(
                x: bounds.origin.x * proxy.size.width,
                y: (1 - bounds.origin.y - bounds.height) * proxy.size.height,
                width: bounds.width * proxy.size.width,
                height: bounds.height * proxy.size.height
            )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.cyan.opacity(0.55), lineWidth: 3)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .shadow(color: .cyan.opacity(0.35), radius: 12)
        }
    }

    private static let skeletonEdges: [(PoseJoint.Name, PoseJoint.Name)] = [
        (.nose, .neck),
        (.neck, .leftShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.neck, .rightShoulder),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.neck, .leftHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.neck, .rightHip),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
        (.leftShoulder, .rightShoulder),
        (.leftHip, .rightHip)
    ]
}

private struct PoseDebugPanel: View {
    let status: String
    let latency: TimeInterval?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 18, weight: .semibold))
            Text(status)
                .font(.system(size: 15, weight: .medium))

            Spacer()

            if let latency {
                Text(String(format: "%.0f ms", latency * 1000))
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

// MARK: - Data Models

struct PoseSkeleton: Identifiable {
    let id = UUID()
    let joints: [PoseJoint]
    let boundingBox: CGRect?
    let confidenceThreshold: VNConfidence
    let edgeColor: Color
    let jointColor: Color
    let is3DDataAvailable: Bool

    var jointsByName: [PoseJoint.Name: PoseJoint] {
        Dictionary(uniqueKeysWithValues: joints.map { ($0.name, $0) })
    }

    var visibleJointCount: Int {
        joints.filter { $0.confidence >= confidenceThreshold }.count
    }

    var depthRangeText: String? {
        let depths = joints.compactMap { $0.depth }
        guard let min = depths.min(), let max = depths.max() else { return nil }
        return String(format: "%.2f m - %.2f m", min, max)
    }
}

struct PoseJoint: Identifiable {
    enum Name: String {
        case nose
        case neck
        case leftShoulder
        case leftElbow
        case leftWrist
        case rightShoulder
        case rightElbow
        case rightWrist
        case leftHip
        case leftKnee
        case leftAnkle
        case rightHip
        case rightKnee
        case rightAnkle
        case root
    }

    let id = UUID()
    let name: Name
    let location: CGPoint
    let confidence: VNConfidence
    let depth: Float?
}

// MARK: - View Model

final class PoseDetectionViewModel: NSObject, ObservableObject {
    @Published var currentPose: PoseSkeleton?
    @Published var isPermissionDenied = false
    @Published var isSessionUnavailable = false
    @Published var currentLatency: TimeInterval?

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.lovpic.posedetection.session")
    private let outputQueue = DispatchQueue(label: "com.lovpic.posedetection.output")
    private var isConfigured = false
    private var frameCounter = 0
    private let confidenceThreshold: VNConfidence = 0.35
    private lazy var poseRequest: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        return request
    }()

    private lazy var pose3DRequest: VNRequest? = {
        guard let requestType = NSClassFromString("VNDetectHumanBodyPose3DRequest") as? VNRequest.Type else {
            return nil
        }
        return requestType.init()
    }()

    private let jointLookup: [PoseJoint.Name: VNHumanBodyPoseObservation.JointName] = [
        .nose: .nose,
        .neck: .neck,
        .leftShoulder: .leftShoulder,
        .leftElbow: .leftElbow,
        .leftWrist: .leftWrist,
        .rightShoulder: .rightShoulder,
        .rightElbow: .rightElbow,
        .rightWrist: .rightWrist,
        .leftHip: .leftHip,
        .leftKnee: .leftKnee,
        .leftAnkle: .leftAnkle,
        .rightHip: .rightHip,
        .rightKnee: .rightKnee,
        .rightAnkle: .rightAnkle,
        .root: .root
    ]

    private var statusState: PoseDetectionState = .idle {
        didSet {
            DispatchQueue.main.async {
                self.statusText = self.statusState.text
            }
        }
    }

    @Published private(set) var statusText: String = PoseDetectionState.idle.text

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
                self.currentPose = nil
                self.currentLatency = nil
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

    private func analyzePose(from observation: VNHumanBodyPoseObservation, observation3D: VNHumanBodyPoseObservation?) -> PoseSkeleton? {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            return nil
        }

        let joints: [PoseJoint] = jointLookup.compactMap { pair in
            guard let point = recognizedPoints[pair.value], point.confidence >= confidenceThreshold else { return nil }

            return PoseJoint(
                name: pair.key,
                location: CGPoint(x: point.x, y: point.y),
                confidence: point.confidence,
                depth: nil
            )
        }

        guard !joints.isEmpty else { return nil }

        return PoseSkeleton(
            joints: joints,
            boundingBox: normalizedBoundingBox(for: joints),
            confidenceThreshold: confidenceThreshold,
            edgeColor: Color(red: 0.35, green: 0.84, blue: 0.98),
            jointColor: Color(red: 0.96, green: 0.33, blue: 0.58),
            is3DDataAvailable: observation3D != nil
        )
    }

    private func normalizedBoundingBox(for joints: [PoseJoint]) -> CGRect? {
        guard !joints.isEmpty else { return nil }

        let xs = joints.map { $0.location.x }
        let ys = joints.map { $0.location.y }

        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
            return nil
        }

        let width = maxX - minX
        let height = maxY - minY
        guard width > 0, height > 0 else { return nil }

        return CGRect(x: minX, y: minY, width: width, height: height)
    }
}

extension PoseDetectionViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        guard frameCounter % 2 == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        var requests: [VNRequest] = [poseRequest]
        if let pose3DRequest {
            requests.append(pose3DRequest)
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            try handler.perform(requests)

            guard let observations = poseRequest.results,
                  let observation = observations.first else {
                DispatchQueue.main.async {
                    self.currentPose = nil
                }
                return
            }

            var observation3D: VNHumanBodyPoseObservation?
            if let pose3DRequest,
               let results = pose3DRequest.results as? [VNHumanBodyPoseObservation],
               let first = results.first {
                observation3D = first
            }

            let latency = CFAbsoluteTimeGetCurrent() - startTime

            if let pose = analyzePose(from: observation, observation3D: observation3D) {
                DispatchQueue.main.async {
                    self.currentPose = pose
                    self.currentLatency = latency
                    self.statusState = .tracking(joints: pose.visibleJointCount, hasDepth: pose.is3DDataAvailable)
                }
            } else {
                DispatchQueue.main.async {
                    self.currentPose = nil
                    self.statusState = .searching
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.statusState = .error
                self.currentPose = nil
            }
        }
    }
}

// MARK: - Helpers

private enum PoseDetectionState {
    case idle
    case searching
    case tracking(joints: Int, hasDepth: Bool)
    case error

    var text: String {
        switch self {
        case .idle:
            return "等待相机输入…"
        case .searching:
            return "正在识别人体姿态…"
        case let .tracking(joints, hasDepth):
            var message = "已捕捉到 \(joints) 个关键点"
            if hasDepth {
                message.append(" · 3D深度可用")
            }
            return message
        case .error:
            return "处理图像时出现问题，请重试"
        }
    }
}

#Preview {
    NavigationStack {
        PoseDetectionView()
    }
}
