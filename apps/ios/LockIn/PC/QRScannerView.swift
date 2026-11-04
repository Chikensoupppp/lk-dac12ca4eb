import AVFoundation
import SwiftUI

/// Full-screen camera that reads one QR code, then reports it. The simulator has no camera;
/// it shows a plain message instead.
struct QRScannerScreen: View {
    let onCode: (String) -> Void
    let onCancel: () -> Void
    @State private var unavailable: String?

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            if let unavailable {
                Text(unavailable)
                    .font(.body)
                    .foregroundStyle(Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(32)
                    .frame(maxHeight: .infinity)
                    .accessibilityIdentifier("scanner-unavailable")
            } else {
                QRScannerView(onCode: onCode, onUnavailable: { unavailable = $0 })
                    .ignoresSafeArea()
                Text("Point the camera at the QR code on your PC.")
                    .font(.footnote)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.6), in: Capsule())
                    .padding(.top, 72)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .foregroundStyle(Color.white)
                    .frame(minWidth: 44, minHeight: 44)
                    .padding(.trailing, 16)
            }
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    let onUnavailable: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onCode = onCode
        controller.onUnavailable = onUnavailable
        return controller
    }

    func updateUIViewController(_ controller: ScannerController, context: Context) {}
}

final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onCode: ((String) -> Void)?
    var onUnavailable: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var finished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let denied = "Camera access is off. Turn it on in iOS Settings > Lock In, then try again."
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.configure() } else { self?.onUnavailable?(denied) }
                }
            }
        default:
            onUnavailable?(denied)
        }
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onUnavailable?("This device has no camera to scan with.")
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onUnavailable?("The camera could not start.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        let captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { captureSession.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let captureSession = session
        DispatchQueue.global(qos: .userInitiated).async {
            if captureSession.isRunning { captureSession.stopRunning() }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !finished,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let text = object.stringValue else { return }
        finished = true
        onCode?(text)
    }
}
