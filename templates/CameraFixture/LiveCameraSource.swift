import AVFoundation
import CoreVideo
import CoreMedia

/// The real camera. Wraps an `AVCaptureSession` with an
/// `AVCaptureVideoDataOutput` and — when the device has a TrueDepth/LiDAR
/// front/back sensor — an `AVCaptureDepthDataOutput`, time-matched by an
/// `AVCaptureDataOutputSynchronizer` so each `Frame` carries an RGB buffer and
/// the depth measured at the SAME instant.
///
/// This is the only `FrameSource` compiled into a Release build. It is also the
/// thing that CANNOT run in the simulator (no camera) and cannot be exercised by
/// the agent without a human and a real face — which is exactly why the seam
/// exists.
///
/// Verified APIs (apple-docs, iOS):
///   AVCaptureVideoDataOutputSampleBufferDelegate (iOS 4.0+)
///   AVCaptureDepthDataOutput                     (iOS 11.0+)
///   AVCaptureDataOutputSynchronizer              (iOS 11.0+)
///   AVCaptureSynchronizedDepthData               (iOS 11.0+)
///   AVCaptureDevice.authorizationStatus(for:)    (iOS 7.0+)
///
/// Starter template. Type-checks against the iOS SDK; a real capture run +
/// device verification remain YOUR gate (AGENTS.md §0).
///
/// @unchecked Sendable invariant: all mutable state below is touched ONLY on
/// `sessionQueue` (configuration) or in the synchronizer/sample-buffer
/// callbacks, which AVFoundation serialises onto `callbackQueue`. The
/// continuation is the one thread-safe hand-off out to the consumer.
public final class LiveCameraSource: NSObject, FrameSource, @unchecked Sendable {

    public let providesDepth: Bool

    public private(set) lazy var frames: AsyncStream<Frame> = {
        AsyncStream { continuation in
            self.continuation = continuation
        }
    }()
    private var continuation: AsyncStream<Frame>.Continuation?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "vibe.frame.live.session")
    private let callbackQueue = DispatchQueue(label: "vibe.frame.live.callback")

    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private var synchronizer: AVCaptureDataOutputSynchronizer?
    private var started = false

    /// - Parameter wantsDepth: request the depth path. It is only actually wired
    ///   if the chosen device exposes a depth format; otherwise `providesDepth`
    ///   ends up `false` and frames are RGB-only.
    public init(wantsDepth: Bool = true) {
        // Decided for real in `configure()`; assume true until proven otherwise
        // so consumers reading `providesDepth` before start see the intent.
        self.providesDepth = wantsDepth
        super.init()
    }

    public func start() async throws {
        guard !started else { return }
        started = true

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { throw FrameSourceError.cameraNotAuthorized }
        default:
            throw FrameSourceError.cameraNotAuthorized
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try self.configure()
                    self.session.startRunning()
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    public func stop() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                if self.session.isRunning { self.session.stopRunning() }
                self.continuation?.finish()
                cont.resume()
            }
        }
    }

    // MARK: - Configuration (sessionQueue only)

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // TrueDepth front camera is the skin-scan case; fall back to wide-angle.
        let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        guard let device else { throw FrameSourceError.noCaptureDevice }

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw FrameSourceError.cannotAddInput }
        session.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else { throw FrameSourceError.cannotAddOutput }
        session.addOutput(videoOutput)

        var depthWired = false
        if providesDepth,
           session.canAddOutput(depthOutput),
           !device.activeFormat.supportedDepthDataFormats.isEmpty {
            session.addOutput(depthOutput)
            depthOutput.isFilteringEnabled = true
            depthWired = true
        }

        if depthWired {
            let sync = AVCaptureDataOutputSynchronizer(dataOutputs: [videoOutput, depthOutput])
            sync.setDelegate(self, queue: callbackQueue)
            synchronizer = sync
        } else {
            videoOutput.setSampleBufferDelegate(self, queue: callbackQueue)
        }
    }
}

// MARK: - Synchronized RGB + depth

extension LiveCameraSource: AVCaptureDataOutputSynchronizerDelegate {
    public func dataOutputSynchronizer(
        _ synchronizer: AVCaptureDataOutputSynchronizer,
        didOutput collection: AVCaptureSynchronizedDataCollection
    ) {
        guard
            let videoData = collection.synchronizedData(for: videoOutput)
                as? AVCaptureSynchronizedSampleBufferData,
            !videoData.sampleBufferWasDropped,
            let pixelBuffer = CMSampleBufferGetImageBuffer(videoData.sampleBuffer)
        else { return }

        var depth: AVDepthData?
        if let depthData = collection.synchronizedData(for: depthOutput)
            as? AVCaptureSynchronizedDepthData, !depthData.depthDataWasDropped {
            depth = depthData.depthData
        }

        continuation?.yield(Frame(
            pixelBuffer: pixelBuffer,
            depth: depth,
            presentationTime: CMSampleBufferGetPresentationTimeStamp(videoData.sampleBuffer),
            isFixture: false
        ))
    }
}

// MARK: - RGB-only fallback (no depth sensor)

extension LiveCameraSource: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        continuation?.yield(Frame(
            pixelBuffer: pixelBuffer,
            depth: nil,
            presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer),
            isFixture: false
        ))
    }
}

public enum FrameSourceError: Error, Sendable {
    case cameraNotAuthorized
    case noCaptureDevice
    case cannotAddInput
    case cannotAddOutput
    case fixtureNotFound(String)
    case fixtureDecodeFailed(String)
    case depthAuxDataMissing(String)
}
