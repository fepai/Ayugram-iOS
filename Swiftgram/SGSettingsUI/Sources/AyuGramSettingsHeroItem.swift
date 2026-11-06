import Foundation
import UIKit
import Display
import SwiftSignalKit
import ItemListUI
import AppBundle

/// Rounded, Settings-style icon with a white SF Symbol (iOS 13+).
func ayuGramRowIcon(_ symbol: String, color: UIColor) -> UIImage {
    let size = CGSize(width: 29.0, height: 29.0)
    return UIGraphicsImageRenderer(size: size).image { _ in
        color.setFill()
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 7.0).fill()
        let configuration = UIImage.SymbolConfiguration(pointSize: 14.0, weight: .semibold)
        guard let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
            return
        }
        let fitted = glyph.size.width > 0.0 && glyph.size.height > 0.0 ? min(1.0, min(19.0 / glyph.size.width, 19.0 / glyph.size.height)) : 1.0
        let glyphSize = CGSize(width: glyph.size.width * fitted, height: glyph.size.height * fitted)
        glyph.draw(in: CGRect(x: (size.width - glyphSize.width) / 2.0, y: (size.height - glyphSize.height) / 2.0, width: glyphSize.width, height: glyphSize.height))
    }
}

/// A bundled picture cut to the same rounded square as the symbol icons.
func ayuGramRowImage(_ name: String) -> UIImage? {
    guard let image = UIImage(bundleImageName: name) else {
        return nil
    }
    let size = CGSize(width: 29.0, height: 29.0)
    return UIGraphicsImageRenderer(size: size).image { _ in
        UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 7.0).addClip()
        image.draw(in: CGRect(origin: .zero, size: size))
    }
}

enum AyuGramRowColor {
    static let purple = UIColor(red: 0.36, green: 0.32, blue: 0.90, alpha: 1.0)
    static let indigo = UIColor(red: 0.30, green: 0.42, blue: 0.86, alpha: 1.0)
    static let blue = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
    static let teal = UIColor(red: 0.02, green: 0.66, blue: 0.62, alpha: 1.0)
    static let green = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0)
    static let orange = UIColor(red: 1.0, green: 0.58, blue: 0.0, alpha: 1.0)
    static let red = UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1.0)
    static let pink = UIColor(red: 0.94, green: 0.25, blue: 0.51, alpha: 1.0)
    static let gray = UIColor(red: 0.56, green: 0.56, blue: 0.58, alpha: 1.0)
    static let lavender = UIColor(red: 0.62, green: 0.51, blue: 0.94, alpha: 1.0)
}

/// The fork's own mark: a rounded shield with an eye slit, drawn in the card's
/// indigo-to-teal palette. Deliberately unlike the upstream AyuGram logo.
func ayuGramEmblemIcon(size: CGFloat = 48.0) -> UIImage {
    return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { context in
        let cg = context.cgContext
        let unit = size / 48.0
        cg.translateBy(x: 0.0, y: size)
        cg.scaleBy(x: unit, y: -unit)

        // Shield body: vertical gradient fill, rounded shield silhouette.
        let colors = [UIColor(red: 0.36, green: 0.32, blue: 0.90, alpha: 1.0).cgColor, UIColor(red: 0.02, green: 0.66, blue: 0.62, alpha: 1.0).cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0.0, 1.0]) else {
            return
        }

        let shield = CGMutablePath()
        shield.move(to: CGPoint(x: 24.0, y: 42.0))
        shield.addCurve(to: CGPoint(x: 8.0, y: 36.0), control1: CGPoint(x: 18.5, y: 41.4), control2: CGPoint(x: 12.5, y: 39.6))
        shield.addLine(to: CGPoint(x: 8.0, y: 22.0))
        shield.addCurve(to: CGPoint(x: 24.0, y: 6.0), control1: CGPoint(x: 8.0, y: 13.0), control2: CGPoint(x: 15.0, y: 6.0))
        shield.addCurve(to: CGPoint(x: 40.0, y: 22.0), control1: CGPoint(x: 33.0, y: 6.0), control2: CGPoint(x: 40.0, y: 13.0))
        shield.addLine(to: CGPoint(x: 40.0, y: 36.0))
        shield.addCurve(to: CGPoint(x: 24.0, y: 42.0), control1: CGPoint(x: 40.0, y: 39.6), control2: CGPoint(x: 29.5, y: 41.4))
        shield.closeSubpath()
        cg.addPath(shield)
        cg.saveGState()
        cg.clip(using: .evenOdd)
        cg.drawLinearGradient(gradient, start: CGPoint(x: 8.0, y: 6.0), end: CGPoint(x: 40.0, y: 42.0), options: [])
        cg.restoreGState()

        // Eye slit across the shield: two arcs and a pupil dot, cut in white.
        UIColor.white.withAlphaComponent(0.96).setFill()
        let lens = CGMutablePath()
        lens.move(to: CGPoint(x: 14.0, y: 24.0))
        lens.addQuadCurve(to: CGPoint(x: 34.0, y: 24.0), control: CGPoint(x: 24.0, y: 31.0))
        lens.addQuadCurve(to: CGPoint(x: 14.0, y: 24.0), control: CGPoint(x: 24.0, y: 17.0))
        lens.closeSubpath()
        cg.addPath(lens)
        cg.fillPath()

        UIColor(red: 0.20, green: 0.24, blue: 0.55, alpha: 1.0).setFill()
        cg.fill(CGRect(x: 21.0, y: 21.6, width: 6.0, height: 4.8))

        UIColor.white.withAlphaComponent(0.9).setFill()
        cg.fill(CGRect(x: 21.6, y: 24.0, width: 1.6, height: 1.2))
    }
}

/// Custom red trash glyph for the destructive "Clear Ayu Database" row, drawn
/// in the AyuGram Android style: red icon next to red text.
func ayuGramTrashIcon(size: CGFloat = 29.0) -> UIImage {
    let red = AyuGramRowColor.red
    return UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { context in
        let cg = context.cgContext
        let scale = size / 29.0
        cg.translateBy(x: 0.0, y: size)
        cg.scaleBy(x: scale, y: -scale)
        red.setFill()

        // Handle and lid.
        cg.addPath(CGPath(roundedRect: CGRect(x: 10.1, y: 21.0, width: 8.8, height: 1.7), cornerWidth: 0.85, cornerHeight: 0.85, transform: nil))
        cg.fillPath()
        cg.addPath(CGPath(roundedRect: CGRect(x: 4.6, y: 18.9, width: 19.8, height: 1.8), cornerWidth: 0.9, cornerHeight: 0.9, transform: nil))
        cg.fillPath()

        // Tapered body with three slots cut out (even-odd fill).
        let body = CGMutablePath()
        body.move(to: CGPoint(x: 6.2, y: 18.3))
        body.addLine(to: CGPoint(x: 22.8, y: 18.3))
        body.addLine(to: CGPoint(x: 21.0, y: 6.6))
        body.addLine(to: CGPoint(x: 8.0, y: 6.6))
        body.closeSubpath()
        let slotHalf: CGFloat = 0.7
        for centerX in [11.0, 14.5, 18.0] {
            body.move(to: CGPoint(x: centerX - slotHalf, y: 15.6))
            body.addLine(to: CGPoint(x: centerX + slotHalf, y: 15.6))
            body.addLine(to: CGPoint(x: centerX + slotHalf, y: 8.9))
            body.addLine(to: CGPoint(x: centerX - slotHalf, y: 8.9))
            body.closeSubpath()
        }
        cg.addPath(body)
        cg.fillPath(using: .evenOdd)
    }
}

/// Summary card at the top of the AyuGram screen: the fork's shield-eye mark,
/// Ghost Mode state and how many activity signals are currently hidden.
final class AyuGramSettingsHeroItem: ListViewItem, ItemListItem {
    let data: ItemListPresentationData
    let title: String
    let status: String
    let detail: String
    let isActive: Bool
    let sectionId: ItemListSectionId
    var isAlwaysPlain: Bool { true }

    init(data: ItemListPresentationData, title: String, status: String, detail: String, isActive: Bool, sectionId: ItemListSectionId) {
        self.data = data
        self.title = title
        self.status = status
        self.detail = detail
        self.isActive = isActive
        self.sectionId = sectionId
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        Queue.mainQueue().async {
            let node = AyuGramSettingsHeroNode()
            let layout = node.update(self, params: params)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            completion(node, { (nil, { _ in }) })
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let node = node() as? AyuGramSettingsHeroNode else { return }
            completion(node.update(self, params: params), { _ in })
        }
    }
}

private final class AyuGramSettingsHeroNode: ListViewItemNode {
    private let card = UIView()
    private let gradient = CAGradientLayer()
    private let sheen = CAGradientLayer()
    private let iconBackground = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailBackground = UIView()
    private let detailIcon = UIImageView()
    private let detailLabel = UILabel()

    init() {
        super.init(layerBacked: false)
        card.isUserInteractionEnabled = false
        card.clipsToBounds = true
        card.layer.cornerRadius = 18.0
        card.layer.addSublayer(gradient)
        card.layer.addSublayer(sheen)
        gradient.startPoint = CGPoint(x: 0.0, y: 1.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 0.0)
        sheen.type = .radial
        sheen.startPoint = CGPoint(x: 0.9, y: 0.1)
        sheen.endPoint = CGPoint(x: 1.7, y: 1.2)
        sheen.colors = [UIColor.white.withAlphaComponent(0.22).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
        view.addSubview(card)

        iconBackground.layer.cornerRadius = 14.0
        iconBackground.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        iconView.contentMode = .scaleAspectFit
        iconView.image = ayuGramEmblemIcon(size: 52.0)
        iconView.clipsToBounds = true
        card.addSubview(iconBackground)
        iconBackground.addSubview(iconView)

        titleLabel.font = .monospacedSystemFont(ofSize: 22.0, weight: .bold)
        titleLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 15.0, weight: .medium)
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        statusLabel.numberOfLines = 2
        card.addSubview(titleLabel)
        card.addSubview(statusLabel)

        detailBackground.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        detailBackground.layer.cornerRadius = 12.0
        detailBackground.layer.borderWidth = 1.0
        detailBackground.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        detailIcon.tintColor = .white
        detailIcon.contentMode = .scaleAspectFit
        detailLabel.font = .systemFont(ofSize: 13.0, weight: .semibold)
        detailLabel.textColor = .white
        card.addSubview(detailBackground)
        detailBackground.addSubview(detailIcon)
        detailBackground.addSubview(detailLabel)
        card.isAccessibilityElement = true
    }

    func update(_ item: AyuGramSettingsHeroItem, params: ListViewItemLayoutParams) -> ListViewItemNodeLayout {
        let width = max(200.0, params.width - params.leftInset - params.rightInset - 32.0)
        let colors: [UIColor]
        if item.isActive {
            colors = [UIColor(red: 0.02, green: 0.55, blue: 0.54, alpha: 1.0), UIColor(red: 0.24, green: 0.25, blue: 0.62, alpha: 1.0)]
        } else {
            colors = [UIColor(red: 0.16, green: 0.17, blue: 0.24, alpha: 1.0), UIColor(red: 0.25, green: 0.27, blue: 0.38, alpha: 1.0)]
        }
        gradient.colors = colors.map { $0.cgColor }

        titleLabel.text = item.title
        statusLabel.text = item.status
        detailLabel.text = item.detail
        let symbol = item.isActive ? "eye.slash.fill" : "eye.fill"
        detailIcon.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 12.0, weight: .semibold))?.withRenderingMode(.alwaysTemplate)

        let inset: CGFloat = 16.0
        let iconSize: CGFloat = 58.0
        iconBackground.frame = CGRect(x: inset, y: inset, width: iconSize, height: iconSize)
        iconView.frame = iconBackground.bounds.insetBy(dx: 4.0, dy: 4.0)
        let textX = inset + iconSize + 13.0
        let textWidth = max(1.0, width - textX - inset)
        titleLabel.frame = CGRect(x: textX, y: inset + 2.0, width: textWidth, height: 28.0)
        let statusHeight = ceil(statusLabel.sizeThatFits(CGSize(width: textWidth, height: 44.0)).height)
        statusLabel.frame = CGRect(x: textX, y: inset + 31.0, width: textWidth, height: min(44.0, statusHeight))

        let pillY = max(iconBackground.frame.maxY, statusLabel.frame.maxY) + 12.0
        let labelWidth = min(width - inset * 2.0 - 34.0, ceil(detailLabel.sizeThatFits(CGSize(width: width, height: 20.0)).width))
        detailBackground.frame = CGRect(x: inset, y: pillY, width: labelWidth + 36.0, height: 25.0)
        detailIcon.frame = CGRect(x: 10.0, y: 5.5, width: 16.0, height: 14.0)
        detailLabel.frame = CGRect(x: 28.0, y: 2.5, width: labelWidth, height: 20.0)

        let height = detailBackground.frame.maxY + inset
        card.frame = CGRect(x: params.leftInset + 16.0, y: 10.0, width: width, height: height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = card.bounds
        sheen.frame = card.bounds
        CATransaction.commit()
        card.accessibilityLabel = [item.title, item.status, item.detail].joined(separator: ". ")
        return ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: height + 16.0), insets: .zero)
    }
}
