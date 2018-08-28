//
//  TreeController.swift
//  TreeController
//
//  Created by Artem Shimanski on 02.08.2018.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import UIKit

let salt = Int(truncatingIfNeeded: 0x9e3779b9 as UInt64)

func hashCombine(seed: inout Int, value: Int) {
	seed ^= value &+ salt &+ (seed << 6) &+ (seed >> 2);
}


extension Array: Diffable, TreeItem where Element: TreeItem {
	public typealias Child = Element
	public var children: [Element]? {
		return self
	}
	
	public var hashValue: Int {
		return reduce(into: 0) {
			hashCombine(seed: &$0, value: $1.hashValue)
		}
	}
	
	public typealias DiffIdentifier = Int
	public var diffIdentifier: Int {
		return 0
	}
}

extension Int: TreeItem {}
extension String: TreeItem {}

public protocol TreeItem: Hashable, Diffable {
	associatedtype Child: TreeItem = TreeItemNull
	associatedtype Children: Collection = [Child] where Children.Element == Child
	var children: Children? {get}
}

public struct TreeItemNull: TreeItem {
	public var children: [TreeItemNull]?
	public var hashValue: Int { return 0 }
}

public extension TreeItem where Child == TreeItemNull {
	var children: [TreeItemNull]? {return nil}
}

public struct AnyTreeItem: TreeItem {
	fileprivate var box: TreeItemBox
	
	public var children: [AnyTreeItem]? {
		return box.children
	}
	
	public var hashValue: Int {
		return box.hashValue
	}
	
	public var diffIdentifier: AnyHashable {
		return box.diffIdentifier
	}
	
	public init<T: TreeItem>(_ base: T) {
		if let base = base as? AnyTreeItem {
			self = base
		}
		else {
			self.box = ConcreteTreeItemBox(base: base)
		}
	}
	
	public init(_ base: AnyTreeItem) {
		self = base
	}
	
	public static func == (lhs: AnyTreeItem, rhs: AnyTreeItem) -> Bool {
		return lhs.box.isEqual(rhs.box)
	}
	
	public var base: Any {
		return box.unbox()
	}
	
}

public protocol TreeControllerDelegate {
	func treeController<T: TreeItem> (_ treeController: TreeController, cellIdentifierFor item: T) -> String?
	func treeController<T: TreeItem> (_ treeController: TreeController, configure cell: UITableViewCell, for item: T) -> Void
	func treeController<T: TreeItem> (_ treeController: TreeController, didSelectRowFor item: T) -> Void
	func treeController<T: TreeItem> (_ treeController: TreeController, didDeselectRowFor item: T) -> Void
	func treeController<T: TreeItem> (_ treeController: TreeController, isExpandable item: T) -> Bool
	func treeController<T: TreeItem> (_ treeController: TreeController, isExpanded item: T) -> Bool
	func treeController<T: TreeItem> (_ treeController: TreeController, didExpand item: T) -> Void
	func treeController<T: TreeItem> (_ treeController: TreeController, didCollapse item: T) -> Void
}

extension TreeControllerDelegate {
	public func treeController<T: TreeItem> (_ treeController: TreeController, didSelectRowFor item: T) -> Void { }
	public func treeController<T: TreeItem> (_ treeController: TreeController, didDeselectRowFor item: T) -> Void {}
	public func treeController<T: TreeItem> (_ treeController: TreeController, isExpandable item: T) -> Bool { return false }
	public func treeController<T: TreeItem> (_ treeController: TreeController, isExpanded item: T) -> Bool { return true }
	public func treeController<T: TreeItem> (_ treeController: TreeController, didExpand item: T) -> Void {}
	public func treeController<T: TreeItem> (_ treeController: TreeController, didCollapse item: T) -> Void {}
}


extension UITableView {
	
	open func performRowUpdates(diff: Diff, sectionBeforeUpdate: Int, sectionAfterUpdate: Int, with animation: TreeController.RowAnimation) {
		insertRows(at: diff.insertions.map { IndexPath(row: $0, section: sectionAfterUpdate) }, with: animation.insertion)
		deleteRows(at: diff.deletions.map { IndexPath(row: $0, section: sectionBeforeUpdate) }, with: animation.deletion)
		reloadRows(at: diff.updates.map { IndexPath(row: $0.0, section: sectionBeforeUpdate) }, with: animation.update)
		diff.moves.forEach {
			moveRow(at: IndexPath(row: $0.0, section: sectionBeforeUpdate), to: IndexPath(row: $0.1, section: sectionAfterUpdate))
		}
	}
	
	open func performSectionUpdates(diff: Diff, with animation: TreeController.RowAnimation) {
		insertSections(diff.insertions, with: animation.insertion)
		deleteSections(diff.deletions, with: animation.deletion)
		diff.moves.forEach {
			moveSection($0.0, toSection: $0.1)
		}
	}
}

open class TreeController: NSObject {
	public struct BatchUpdateOptions: OptionSet {
		public let rawValue: UInt
		public static let concurent = BatchUpdateOptions(rawValue: 1 << 0)
		
		public init(rawValue: UInt) {
			self.rawValue = rawValue
		}
	}
	
	public struct RowAnimation: Equatable {
		public var insertion: UITableView.RowAnimation
		public var deletion: UITableView.RowAnimation
		public var update: UITableView.RowAnimation
		
		public init(insertion: UITableView.RowAnimation, deletion: UITableView.RowAnimation, update: UITableView.RowAnimation) {
			self.insertion = insertion
			self.deletion = deletion
			self.update = update
		}
		
		public init(_ animation: UITableView.RowAnimation) {
			insertion = animation
			deletion = animation
			update = animation
		}
		
		public static let automatic = RowAnimation(.automatic)
		public static let fade = RowAnimation(.fade)
		public static let right = RowAnimation(.right)
		public static let left = RowAnimation(.left)
		public static let top = RowAnimation(.top)
		public static let bottom = RowAnimation(.bottom)
		public static let middle = RowAnimation(.middle)
		public static let none = RowAnimation(.none)
	}
	
	open var delegate: TreeControllerDelegate?
	open var tableView: UITableView? {
		didSet {
			tableView?.dataSource = self
			tableView?.delegate = self
		}
	}
	
	private var sections: [AnyTreeItem]?
	private var flattened: [[AnyTreeItem]]?
	private var nodes: [AnyHashable: Node] = [:]
	
	open func reload<T: TreeItem>(_ content: [T], options: BatchUpdateOptions = [], with animation: TreeController.RowAnimation = .none, completion: (() -> Void)? = nil) {
		
		let noAnimation = animation == .none
		
		if noAnimation {
			nodes.removeAll()
		}
		
		let sections = content.map{AnyTreeItem($0)}
		let flattened = sections.enumerated().map { (i, section) -> [AnyTreeItem] in
			var array = [AnyTreeItem]()
			flatten(section, into: &array, from: IndexPath(row: 0, section: i), level: 0)
			return array
		}
		
		
		if animation == .none {
			self.sections = sections
			self.flattened = flattened
			tableView?.reloadData()
			completion?()
		}
		else {
			let oldSections = self.sections
			let oldFlattened = self.flattened
			let sections = content.map{AnyTreeItem($0)}
			let flattened = sections.enumerated().map { (i, section) -> [AnyTreeItem] in
				var array = [AnyTreeItem]()
				flatten(section, into: &array, from: IndexPath(row: 0, section: i), level: 0)
				return array
			}
			
			if options.contains(.concurent) {
				var nodes = self.nodes
				DispatchQueue.global(qos: .utility).async {
					let diff = Diff(oldSections?.map{$0.diffIdentifier} ?? [], sections.map{$0.diffIdentifier})
					
					diff.deletions.forEach {
						oldSections?[$0].children?.forEach {
							nodes[$0.diffIdentifier] = nil
						}
					}
					
					var rowUpdates = [(Diff, Int, Int)]()
					for (i, j) in diff.indicesMap {
						let old = oldFlattened?[i] ?? []
						let new = flattened[j]
						
						let diff = Diff(old, new)
						rowUpdates.append((diff, i, j))
						diff.deletions.forEach {
							nodes[old[$0].diffIdentifier] = nil
						}
					}
					DispatchQueue.main.async {
						self.tableView?.beginUpdates()
						rowUpdates.forEach {
							self.tableView?.performRowUpdates(diff: $0.0, sectionBeforeUpdate: $0.1, sectionAfterUpdate: $0.2, with: animation)
						}
						self.tableView?.performSectionUpdates(diff: diff, with: animation)
						self.sections = sections
						self.flattened = flattened
						self.nodes = nodes
						self.tableView?.endUpdates()
						completion?()
					}
				}
			}
			else {
				tableView?.beginUpdates()
				
				let diff = Diff(oldSections?.map{$0.diffIdentifier} ?? [], sections.map{$0.diffIdentifier})
				
				diff.deletions.forEach {
					oldSections?[$0].children?.forEach {
						nodes[$0.diffIdentifier] = nil
					}
				}
				
				for (i, j) in diff.indicesMap {
					let old = oldFlattened?[i] ?? []
					let new = flattened[j]
					
					let diff = Diff(old, new)
					tableView?.performRowUpdates(diff: diff, sectionBeforeUpdate: i, sectionAfterUpdate: j, with: animation)
					diff.deletions.forEach {
						nodes[old[$0.diffIdentifier]] = nil
					}
				}
				
				tableView?.performSectionUpdates(diff: diff, with: .fade)
				self.sections = sections
				self.flattened = flattened
				tableView?.endUpdates()
				completion?()
			}
		}
	}
	
	open func cell<T: TreeItem>(for item: T) -> UITableViewCell? {
		guard let indexPath = indexPath(for: item) else {return nil}
		return tableView?.cellForRow(at: indexPath)
	}
	
	open func reloadRow<T: TreeItem>(for item: T, with animation: UITableView.RowAnimation) {
		guard let indexPath = indexPath(for: item) else {return}
		tableView?.reloadRows(at: [indexPath], with: animation)
	}
	
	open func isItemExpanded<T: TreeItem>(_ item: T) -> Bool {
		return nodes[item.diffIdentifier]?.flags.contains(.isExpanded) == true
	}
	
	open func selectCell<T: TreeItem>(for item: T, animated: Bool, scrollPosition: UITableView.ScrollPosition) {
		guard let indexPath = indexPath(for: item) else {return}
		tableView?.selectRow(at: indexPath, animated: animated, scrollPosition: scrollPosition)
	}
	
	open func deselectCell<T: TreeItem>(for item: T, animated: Bool) {
		guard let indexPath = indexPath(for: item) else {return}
		tableView?.deselectRow(at: indexPath, animated: animated)
	}
	
	open func indentationLevel<T: TreeItem>(for item: T) -> Int {
		return nodes[item.diffIdentifier]?.level ?? 0
	}
}

extension TreeController {
	fileprivate class Node {
		struct Flags: OptionSet {
			var rawValue: UInt32
			static let isExpandable = Flags(rawValue: 1 << 0)
			static let isExpanded = Flags(rawValue: 1 << 1)
		}
		var flags: Flags
		var estimatedRowHeight: CGFloat?
		var indexPath: IndexPath?
		var level: Int
		let cellIdentifier: String?
		init(flags: Flags, cellIdentifier: String?, level: Int) {
			self.flags = flags
			self.cellIdentifier = cellIdentifier
			self.level = level
		}
	}
	
	private func newNode(for item: AnyTreeItem, level: Int) -> Node {
		var flags = TreeController.Node.Flags()
		if delegate!.treeController(self, isExpandable: item) {
			flags.insert(.isExpandable)
			if delegate!.treeController(self, isExpanded: item) {
				flags.insert(.isExpanded)
			}
		}
		else {
			flags.insert(.isExpanded)
		}
		let node = item.box.newNode(treeController: self, level: level)
		nodes[item.diffIdentifier] = node
		return node
	}
	
	private func flatten(_ item: AnyTreeItem, into: inout [AnyTreeItem], from indexPath: IndexPath, level: Int) {
		var level = level
		let node = nodes[item.diffIdentifier] ?? newNode(for: item, level: level)
		var indexPath = indexPath
		if node.cellIdentifier != nil {
			node.indexPath = indexPath
			into.append(item)
			indexPath.row += 1
			level += 1
		}
		if node.flags.contains(.isExpanded) || node.cellIdentifier == nil {
			item.children?.forEach {
				let before = into.count
				flatten($0, into: &into, from: indexPath, level: level)
				let after = into.count
				indexPath.row += after - before
			}
		}
	}
	
	private func numberOfItems(in item: AnyTreeItem, level: Int) -> Int {
		var level = level
		let node = nodes[item.diffIdentifier] ?? newNode(for: item, level: level)
		var count = 0
		if node.cellIdentifier != nil {
			count += 1
			level += 1
		}
		if node.flags.contains(.isExpanded) || node.cellIdentifier == nil {
			item.children?.forEach {
				count += numberOfItems(in: $0, level: level)
			}
		}
		return count
	}
	
	private func indexPath<T: TreeItem>(for item: T) -> IndexPath? {
		return nodes[item.diffIdentifier]?.indexPath
	}
	
	private func handleRowSelection(for item: AnyTreeItem, at indexPath: IndexPath) {
		let node = nodes[item.diffIdentifier]!
		if node.flags.contains(.isExpandable) {
			if node.flags.contains(.isExpanded) {
				let count = numberOfItems(in: item, level: node.level) - 1
				let range = (indexPath.item + 1)..<(indexPath.item + 1 + count)
				flattened?[indexPath.section].removeSubrange(range)
				node.flags.remove(.isExpanded)
				tableView?.deleteRows(at: range.map{IndexPath(row: $0, section: indexPath.section)}, with: .fade)
				item.box.treeControllerDidCollapseItem(self)
			}
			else {
				node.flags.insert(.isExpanded)
				var items = [AnyTreeItem]()
				flatten(item, into: &items, from: indexPath, level: node.level)
				let range = (indexPath.item + 1)..<(indexPath.item + items.count)
				flattened?[indexPath.section].replaceSubrange(indexPath.item...indexPath.item, with: items)
				tableView?.insertRows(at: range.map{IndexPath(row: $0, section: indexPath.section)}, with: .fade)
				item.box.treeControllerDidExpandItem(self)
			}
		}
	}
}

extension TreeController: UITableViewDataSource {
	open func numberOfSections(in tableView: UITableView) -> Int {
		return flattened?.count ?? 0
	}
	
	open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return flattened?[section].count ?? 0
	}
	
	open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item = flattened![indexPath.section][indexPath.item]
		let node = nodes[item.diffIdentifier]!
		let cell = tableView.dequeueReusableCell(withIdentifier: node.cellIdentifier!, for: indexPath)
		item.box.treeController(self, configure: cell)
		return cell
	}
}

extension TreeController: UITableViewDelegate {
	
	open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let item = flattened![indexPath.section][indexPath.item]
		item.box.treeControllerDidSelectRow(self)
		handleRowSelection(for: item, at: indexPath)
	}
	
	open func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
		let item = flattened![indexPath.section][indexPath.item]
		item.box.treeControllerDidDeselectRow(self)
//		handleRowSelection(for: item, at: indexPath)
	}
	
	open func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
		let item = flattened![indexPath.section][indexPath.item]
		return indentationLevel(for: item)
	}
	
	public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
		let item = flattened![indexPath.section][indexPath.item]
		let node = nodes[item.diffIdentifier]
		return node?.estimatedRowHeight ?? tableView.estimatedRowHeight
	}
	
	public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		let item = flattened![indexPath.section][indexPath.item]
		let node = nodes[item.diffIdentifier]
		node?.estimatedRowHeight = cell.bounds.height
	}

}

fileprivate protocol TreeItemBox {
	func unbox<T: TreeItem>() -> T?
	func unbox() -> Any
	var children: [AnyTreeItem]? {get}
	
	var hashValue: Int {get}
	var diffIdentifier: AnyHashable {get}
	func isEqual(_ other: TreeItemBox) -> Bool
	func isEqual<T: TreeItem>(_ other: T) -> Bool
	func newNode(treeController: TreeController, level: Int) -> TreeController.Node
	func treeController(_ treeController: TreeController, configure cell: UITableViewCell) -> Void
	func treeControllerDidSelectRow(_ treeController: TreeController) -> Void
	func treeControllerDidDeselectRow(_ treeController: TreeController) -> Void
	func treeControllerDidExpandItem(_ treeController: TreeController) -> Void
	func treeControllerDidCollapseItem(_ treeController: TreeController) -> Void
}

fileprivate struct ConcreteTreeItemBox<Base: TreeItem>: TreeItemBox {
	var base: Base
	
	var children: [AnyTreeItem]? {
		return base.children?.map{AnyTreeItem($0)}
	}
	
	func unbox<T>() -> T? where T : TreeItem {
		return base as? T
	}
	
	func unbox() -> Any {
		return base
	}
	
	var hashValue: Int {
		return base.hashValue
	}
	
	var diffIdentifier: AnyHashable {
		return base.diffIdentifier
	}
	
	func isEqual(_ other: TreeItemBox) -> Bool {
		guard let other: Base = other.unbox() else {return false}
		return other == base
	}
	
	func isEqual<T: TreeItem>(_ other: T) -> Bool {
		guard let other = other as? Base else {return false}
		return other == base
	}
	
	func newNode(treeController: TreeController, level: Int) -> TreeController.Node {
		var flags = TreeController.Node.Flags()
		if treeController.delegate!.treeController(treeController, isExpandable: base) {
			flags.insert(.isExpandable)
			if treeController.delegate!.treeController(treeController, isExpanded: base) {
				flags.insert(.isExpanded)
			}
		}
		else {
			flags.insert(.isExpanded)
		}
		return TreeController.Node(flags: flags, cellIdentifier: treeController.delegate!.treeController(treeController, cellIdentifierFor: base), level: level)
	}
	
	func treeController(_ treeController: TreeController, configure cell: UITableViewCell) -> Void {
		treeController.delegate?.treeController(treeController, configure: cell, for: base)
	}
	
	func treeControllerDidSelectRow(_ treeController: TreeController) -> Void {
		treeController.delegate?.treeController(treeController, didSelectRowFor: base)
	}
	
	func treeControllerDidDeselectRow(_ treeController: TreeController) -> Void {
		treeController.delegate?.treeController(treeController, didDeselectRowFor: base)
	}
	
	func treeControllerDidExpandItem(_ treeController: TreeController) -> Void {
		treeController.delegate?.treeController(treeController, didExpand: base)
	}
	
	func treeControllerDidCollapseItem(_ treeController: TreeController) -> Void {
		treeController.delegate?.treeController(treeController, didCollapse: base)
	}
}
