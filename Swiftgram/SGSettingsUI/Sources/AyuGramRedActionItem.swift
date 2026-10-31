import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData

/// Destructive settings row in the AyuGram Android style: a red icon on the
/// left, red title and a gray detail label on the right ("Clear Ayu Database").
final class AyuGramRedActionItem: ListViewItem, ItemListItem {
    let presentationData: ItemListPresentationData
    let systemStyle: ItemListSystemStyle
    let icon: UIImage?
    let title: String
    let label: String
    let sectionId: ItemListSectionId
    let style: ItemListStyle
    let action: () -> Void

    init(presentationData: ItemListPresentationData, systemStyle: ItemListSystemStyle = .legacy, icon: UIImage?, title: String, label: String, sectionId: ItemListSectionId, style: ItemListStyle, action: @escaping () -> Void) {
        self.presentationData = presentationData
        self.systemStyle = systemStyle
        self.icon = icon
        self.title = title
        self.label = label
        self.sectionId = sectionId
        self.style = style
        self.action = action
    }

    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = AyuGramRedActionItemNode()
            let (layout, apply) = node.asyncLayout()(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in apply(false) })
                })
            }
        }
    }

    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? AyuGramRedActionItemNode {
                let makeLayout = nodeValue.asyncLayout()
                async {
                    let (layout, apply) = makeLayout(self, params, itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)))
                    Queue.mainQueue().async {
                        completion(layout, { _ in
                            apply(false)
                        })
                    }
                }
            }
        }
    }

    public var selectable: Bool = true

    public func selected(listView: ListView) {
        listView.clearHighlightAnimated(true)
        self.action()
    }
}

private final class AyuGramRedActionItemNode: ListViewItemNode, ItemListItemNode {
    private let backgroundNode: ASDisplayNode
    private let highlightNode: ASDisplayNode
    private let topStripeNode: ASDisplayNode
    private let bottomStripeNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode

    private let iconNode: ASImageNode
    private let titleNode: TextNode
    private let labelNode: TextNode

    private let activateArea: AccessibilityAreaNode

    private var item: AyuGramRedActionItem?

    public var tag: ItemListItemTag? {
        return nil
    }

    init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true

        self.highlightNode = ASDisplayNode()
        self.highlightNode.isLayerBacked = true

        self.maskNode = ASImageNode()
        self.topStripeNode = ASDisplayNode()
        self.topStripeNode.isLayerBacked = true

        self.bottomStripeNode = ASDisplayNode()
        self.bottomStripeNode.isLayerBacked = true

        self.iconNode = ASImageNode()
        self.iconNode.isUserInteractionEnabled = false

        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.contentMode = .left
        self.titleNode.contentsScale = UIScreen.main.scale

        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.contentMode = .left
        self.labelNode.contentsScale = UIScreen.main.scale

        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true

        self.activateArea = AccessibilityAreaNode()

        super.init(layerBacked: false)

        self.addSubnode(self.iconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.activateArea)
    }

    public func asyncLayout() -> (_ item: AyuGramRedActionItem, _ params: ListViewItemLayoutParams, _ neighbors: ItemListNeighbors) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)

        let currentItem = self.item

        return { [weak self] item, params, neighbors in
            let titleFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)
            let labelFont = Font.regular(item.presentationData.fontSize.itemListBaseFontSize)

            var updatedTheme: PresentationTheme?
            if currentItem?.presentationData.theme !== item.presentationData.theme {
                updatedTheme = item.presentationData.theme
            }

            let availableWidth = params.width - params.leftInset - params.rightInset - 20.0 - 30.0

            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.title, font: titleFont, textColor: item.presentationData.theme.list.itemDestructiveColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: availableWidth * 0.7, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))

            let (labelLayout, labelApply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.label, font: labelFont, textColor: item.presentationData.theme.list.itemSecondaryTextColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .middle, constrainedSize: CGSize(width: availableWidth - titleLayout.size.width - 8.0, height: CGFloat.greatestFiniteMagnitude), alignment: .right, cutout: nil, insets: UIEdgeInsets()))

            let separatorHeight = UIScreenPixel
            let separatorRightInset: CGFloat = item.systemStyle == .glass ? 16.0 : 0.0

            let verticalInset: CGFloat
            switch item.systemStyle {
            case .glass:
                verticalInset = 13.0
            case .legacy:
                verticalInset = 11.0
            }

            let iconSize: CGFloat = 29.0

            let contentSize = CGSize(width: params.width, height: max(titleLayout.size.height, iconSize) + verticalInset * 2.0)

            let itemBackgroundColor: UIColor
            let itemSeparatorColor: UIColor
            let insets: UIEdgeInsets
            switch item.style {
            case .plain:
                itemBackgroundColor = item.presentationData.theme.list.plainBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemPlainSeparatorColor
                insets = itemListNeighborsPlainInsets(neighbors)
            case .blocks:
                itemBackgroundColor = item.presentationData.theme.list.itemBlocksBackgroundColor
                itemSeparatorColor = item.presentationData.theme.list.itemBlocksSeparatorColor
                insets = itemListNeighborsGroupedInsets(neighbors, params)
            }

            let layout = ListViewItemNodeLayout(contentSize: contentSize, insets: insets)

            return (layout, { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.item = item

                    strongSelf.activateArea.frame = CGRect(origin: CGPoint(x: params.leftInset, y: 0.0), size: CGSize(width: params.width - params.leftInset - params.rightInset, height: layout.contentSize.height))
                    strongSelf.activateArea.accessibilityLabel = item.title

                    if let _ = updatedTheme {
                        strongSelf.topStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.bottomStripeNode.backgroundColor = itemSeparatorColor
                        strongSelf.backgroundNode.backgroundColor = itemBackgroundColor
                        strongSelf.highlightedBackgroundNode.backgroundColor = item.presentationData.theme.list.itemHighlightedBackgroundColor
                        strongSelf.highlightNode.backgroundColor = item.presentationData.theme.list.itemSearchHighlightColor
                    }

                    let _ = titleApply()
                    let _ = labelApply()

                    strongSelf.iconNode.image = item.icon

                    let leftInset = 16.0 + params.leftInset
                    let iconVerticalOffset = floorToScreenPixels((contentSize.height - iconSize) / 2.0)

                    switch item.style {
                        case .plain:
                            if strongSelf.backgroundNode.supernode != nil {
                                strongSelf.backgroundNode.removeFromSupernode()
                            }
                            if strongSelf.topStripeNode.supernode != nil {
                                strongSelf.topStripeNode.removeFromSupernode()
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 0)
                            }
                            if strongSelf.maskNode.supernode != nil {
                                strongSelf.maskNode.removeFromSupernode()
                            }
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: leftInset, y: contentSize.height - separatorHeight), size: CGSize(width: params.width - leftInset, height: separatorHeight))
                        case .blocks:
                            if strongSelf.backgroundNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                            }
                            if strongSelf.topStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.topStripeNode, at: 1)
                            }
                            if strongSelf.bottomStripeNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.bottomStripeNode, at: 2)
                            }
                            if strongSelf.maskNode.supernode == nil {
                                strongSelf.insertSubnode(strongSelf.maskNode, at: 3)
                            }

                            let hasCorners = itemListHasRoundedBlockLayout(params)
                            var hasTopCorners = false
                            var hasBottomCorners = false
                            switch neighbors.top {
                                case .sameSection(false):
                                    strongSelf.topStripeNode.isHidden = true
                                default:
                                    hasTopCorners = true
                                    strongSelf.topStripeNode.isHidden = hasCorners
                            }
                            let bottomStripeInset: CGFloat
                            let bottomStripeOffset: CGFloat
                            switch neighbors.bottom {
                                case .sameSection(false):
                                    bottomStripeInset = 16.0 + params.leftInset
                                    bottomStripeOffset = -separatorHeight
                                    strongSelf.bottomStripeNode.isHidden = false
                                default:
                                    bottomStripeInset = 0.0
                                    bottomStripeOffset = 0.0
                                    hasBottomCorners = true
                                    strongSelf.bottomStripeNode.isHidden = hasCorners
                            }

                            strongSelf.maskNode.image = hasCorners ? PresentationResourcesItemList.cornersImage(item.presentationData.theme, top: hasTopCorners, bottom: hasBottomCorners, glass: item.systemStyle == .glass) : nil

                            strongSelf.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: contentSize.height + min(insets.top, separatorHeight) + min(insets.bottom, separatorHeight)))
                            strongSelf.highlightNode.frame = strongSelf.backgroundNode.frame
                            strongSelf.maskNode.frame = strongSelf.backgroundNode.frame.inset(by: UIEdgeInsets(top: 0.0, left: params.leftInset, bottom: 0.0, right: params.rightInset))
                            strongSelf.topStripeNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -min(insets.top, separatorHeight)), size: CGSize(width: params.width, height: separatorHeight))
                            strongSelf.bottomStripeNode.frame = CGRect(origin: CGPoint(x: bottomStripeInset, y: contentSize.height + bottomStripeOffset), size: CGSize(width: params.width - params.rightInset - bottomStripeInset - separatorRightInset, height: separatorHeight))
                    }

                    strongSelf.iconNode.frame = CGRect(origin: CGPoint(x: leftInset, y: iconVerticalOffset), size: CGSize(width: iconSize, height: iconSize))

                    let textLeftInset = leftInset + (item.icon == nil ? 0.0 : iconSize + 13.0)
                    let titleY = floorToScreenPixels((contentSize.height - titleLayout.size.height) / 2.0) + 1.0
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: textLeftInset, y: titleY), size: titleLayout.size)
                    if labelLayout.size.width > 0.1 {
                        let labelX = max(titleNodeFrameMaxX(strongSelf.titleNode.frame), params.width - params.rightInset - 16.0 - labelLayout.size.width)
                        strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: labelX, y: titleY + floor((titleLayout.size.height - labelLayout.size.height) / 2.0)), size: labelLayout.size)
                    } else {
                        strongSelf.labelNode.frame = CGRect(origin: CGPoint(x: textLeftInset, y: titleY), size: labelLayout.size)
                    }

                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: params.width, height: layout.contentSize.height + UIScreenPixel + UIScreenPixel))
                }
            })
        }
    }

    override public func setHighlighted(_ highlighted: Bool, at point: CGPoint, animated: Bool) {
        super.setHighlighted(highlighted, at: point, animated: animated)

        if highlighted {
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                var anchorNode: ASDisplayNode?
                if self.bottomStripeNode.supernode != nil {
                    anchorNode = self.bottomStripeNode
                } else if self.topStripeNode.supernode != nil {
                    anchorNode = self.topStripeNode
                } else if self.backgroundNode.supernode != nil {
                    anchorNode = self.backgroundNode
                }
                if let anchorNode = anchorNode {
                    self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: anchorNode)
                } else {
                    self.addSubnode(self.highlightedBackgroundNode)
                }
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self, completed {
                            strongSelf.highlightedBackgroundNode.removeFromSupernode()
                        }
                    })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                }
            }
        }
    }

    override public func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }

    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}

private func titleNodeFrameMaxX(_ frame: CGRect) -> CGFloat {
    return frame.maxX + 8.0
}
