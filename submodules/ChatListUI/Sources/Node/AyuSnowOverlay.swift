import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import SGSimpleSettings

/// exteraGram-style snow particles over the chat list. Attached lazily to the
/// controller node; visibility follows the AyuGram appearance setting.
final class AyuSnowOverlay: UIView {
    private let emitter = CAEmitterLayer()
    private var observer: NSObjectProtocol?

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.isUserInteractionEnabled = false
        self.layer.addSublayer(self.emitter)
        self.emitter.emitterShape = .line
        self.emitter.emitterMode = .outline
        self.emitter.renderMode = .unordered

        let cell = CAEmitterCell()
        cell.birthRate = 5.0
        cell.lifetime = 9.0
        cell.velocity = 26.0
        cell.velocityRange = 12.0
        cell.xAcceleration = 6.0
        cell.yAcceleration = 14.0
        cell.spin = 0.18
        cell.spinRange = 0.6
        cell.scale = 0.11
        cell.scaleRange = 0.06
        cell.emissionRange = .pi
        cell.alphaSpeed = -0.02
        cell.contents = AyuSnowOverlay.snowImage().cgImage
        self.emitter.emitterCells = [cell]

        self.observer = NotificationCenter.default.addObserver(forName: AyuGramSettings.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.applyState()
        }
        self.applyState()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let observer = self.observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.emitter.emitterPosition = CGPoint(x: self.bounds.midX, y: -8.0)
        self.emitter.emitterSize = CGSize(width: self.bounds.width, height: 1.0)
    }

    private func applyState() {
        self.isHidden = !AyuGramSettings.shared.extra.snowEnabled
    }

    private static func snowImage() -> UIImage {
        let size = CGSize(width: 18.0, height: 18.0)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 1.0, alpha: 0.9).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 4.0, y: 4.0, width: 10.0, height: 10.0))
        }
    }
}

/// Idempotently attaches and resizes the snow overlay inside a node's view.
/// Called from the chat list controller node's layout pass.
func ayuUpdateSnowOverlay(on node: ASDisplayNode) {
    var overlay: AyuSnowOverlay?
    for subview in node.view.subviews {
        if let found = subview as? AyuSnowOverlay {
            overlay = found
            break
        }
    }
    if overlay == nil {
        let created = AyuSnowOverlay(frame: CGRect(origin: .zero, size: node.view.bounds.size))
        node.view.addSubview(created)
        node.view.bringSubviewToFront(created)
        overlay = created
    }
    overlay?.frame = CGRect(origin: .zero, size: node.view.bounds.size)
}
