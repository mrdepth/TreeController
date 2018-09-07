//
//  TreeController.swift
//  TreeController
//
//  Created by Artem Shimanski on 02.08.2018.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import UIKit

typealias AnyDiffIdentifier = AnyHashable

public protocol TreeItem: Hashable, Diffable {
	associatedtype Child: TreeItem = TreeItemNull
	var children: [Child]? {get}
}

public struct TreeItemNull: TreeItem {
	public var children: [TreeItemNull]? { return nil }
	public var hashValue: Int { return 0 }
}

public extension TreeItem where Child == TreeItemNull {
	var children: [Child]? {return nil}
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
	
//	public var base: Any {
//		return box.unbox()
//	}
	
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
	
	func treeController<T: TreeItem> (_ treeController: TreeController, canEdit item: T) -> Bool
	func treeController<T: TreeItem> (_ treeController: TreeController, editingStyleFor item: T) -> UITableViewCell.EditingStyle
	func treeController<T: TreeItem> (_ treeController: TreeController, editActionsFor item: T) -> [UITableViewRowAction]?
	func treeController<T: TreeItem> (_ treeController: TreeController, commit editingStyle: UITableViewCell.EditingStyle, for item: T) -> Void
	func treeController<T: TreeItem> (_ treeController: TreeController, accessoryButtonTappedFor item: T) -> Void
	func treeController<T: TreeItem, S: TreeItem, D: TreeItem> (_ treeController: TreeController, canMove item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int, inParent newParent: D?) -> Bool

}

extension TreeControllerDelegate {
	public func treeController<T: TreeItem> (_ treeController: TreeController, didSelectRowFor item: T) -> Void { }
	public func treeController<T: TreeItem> (_ treeController: TreeController, didDeselectRowFor item: T) -> Void {}
	public func treeController<T: TreeItem> (_ treeController: TreeController, isExpandable item: T) -> Bool { return false }
	public func treeController<T: TreeItem> (_ treeController: TreeController, isExpanded item: T) -> Bool { return true }
	public func treeController<T: TreeItem> (_ treeController: TreeController, didExpand item: T) -> Void {}
	public func treeController<T: TreeItem> (_ treeController: TreeController, didCollapse item: T) -> Void {}

	public func treeController<T: TreeItem> (_ treeController: TreeController, canEdit item: T) -> Bool { return false }
	public func treeController<T: TreeItem> (_ treeController: TreeController, editingStyleFor item: T) -> UITableViewCell.EditingStyle { return .none }
	public func treeController<T: TreeItem> (_ treeController: TreeController, editActionsFor item: T) -> [UITableViewRowAction]? { return nil }
	public func treeController<T: TreeItem> (_ treeController: TreeController, commit editingStyle: UITableViewCell.EditingStyle, for item: T) -> Void {}
	public func treeController<T: TreeItem> (_ treeController: TreeController, accessoryButtonTappedFor item: T) -> Void {}
	public func treeController<T: TreeItem, S: TreeItem, D: TreeItem> (_ treeController: TreeController, canMove item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int, inParent newParent: D?) -> Bool { return false }

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
	open weak var scrollViewDelegate: UIScrollViewDelegate?
	
	open var tableView: UITableView? {
		didSet {
			tableView?.dataSource = self
			tableView?.delegate = self
		}
	}
	
	private var sections: [Node]?
	private var flattened: [[Node]]?
	fileprivate var nodes: [AnyDiffIdentifier: Node] = [:]
	private var root: AnyTreeItem?
	
	open func reloadData<T: Collection>(_ data: T, options: BatchUpdateOptions = [], with animation: TreeController.RowAnimation = .none, completion: (() -> Void)? = nil) where T.Element: TreeItem {
		root = nil
		let noAnimation = animation == .none
		
		if noAnimation {
			nodes.removeAll()
		}
		
		let sections = data.enumerated().map { (i, item) -> Node in
			let node = self.node(for: item)
			node.section = i
			return node
		}
		
		let flattened = sections.enumerated().map { (i, section) -> [Node] in
			var array = [Node]()
			section.flatten(into: &array)
			return array
		}
			
		if noAnimation {
			self.sections = sections
			self.flattened = flattened
			tableView?.reloadData()
			completion?()
		}
		else {
			let oldSections = self.sections
			let oldFlattened = self.flattened
			
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
						nodes[old[$0].diffIdentifier] = nil
					}
				}
				
				tableView?.performSectionUpdates(diff: diff, with: animation)
				self.sections = sections
				self.flattened = flattened
				tableView?.endUpdates()
				completion?()
			}
		}
	}
	
	open func reloadData<T: TreeItem>(from item: T, options: BatchUpdateOptions = [], with animation: TreeController.RowAnimation = .none, completion: (() -> Void)? = nil) {
		if let children = item.children {
			reloadData(children, options: options, with: animation, completion: completion)
		}
		else {
			reloadData(Array<T.Child>(), options: options, with: animation, completion: completion)
		}
		root = AnyTreeItem(item)
	}

	open func update<T: TreeItem>(contentsOf item: T, options: BatchUpdateOptions = [], with animation: TreeController.RowAnimation = .none, completion: (() -> Void)? = nil) {
		if AnyTreeItem(item) == root {
			reloadData(from: item, options: options, with: animation, completion: completion)
		}
		else {
			guard self.flattened != nil, let node = self.nodes[AnyHashable(item.diffIdentifier)] else {
				completion?()
				return
			}
			
			
			let indexPath = node.indexPath!
			let range = (indexPath.item + 1)...(indexPath.item + node.numberOfChildren)

			node.item = AnyTreeItem(item)
			
			let noAnimation = animation == .none
			
			var flattened = [Node]()
			node.flatten(into: &flattened)

			
			let n = flattened.count  - range.count
			if n != 0 {
				if let parent = node.parent {
//					let from = node.offset + node.numberOfChildren
//					parent.children?.upperBound(where: {$0.offset > from}).forEach {
					parent.children?[(node.index + 1)...].forEach {
						$0.offset += n
					}
				}
				
				sequence(first: node, next: {$0.parent}).forEach { i in
					i.numberOfChildren += n
				}
			}

			
			if noAnimation {
				self.flattened?[indexPath.section].replaceSubrange(range, with: flattened)
				tableView?.reloadData()
				completion?()
			}
			else {
				let oldFlattened = self.flattened?[node.section][range]
				
				if options.contains(.concurent) {
					DispatchQueue.global(qos: .utility).async {
						var diff = Diff(oldFlattened?.map{$0} ?? [], flattened.map{$0})
						diff.shift(by: range.lowerBound)
						
						DispatchQueue.main.async {
							self.tableView?.beginUpdates()
							self.tableView?.performRowUpdates(diff: diff, sectionBeforeUpdate: node.section, sectionAfterUpdate: node.section, with: animation)
							self.flattened?[node.section].replaceSubrange(range, with: flattened)
							self.tableView?.endUpdates()
							completion?()
						}
					}
				}
				else {
					tableView?.beginUpdates()
					var diff = Diff(oldFlattened ?? [], flattened)
					diff.shift(by: range.lowerBound)
					tableView?.performRowUpdates(diff: diff, sectionBeforeUpdate: node.section, sectionAfterUpdate: node.section, with: animation)
					self.flattened?[node.section].replaceSubrange(range, with: flattened)
					tableView?.endUpdates()
					completion?()
				}
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
		guard let node = nodes[item.diffIdentifier]?.parent else {return 0}
		return sequence(first: node, next: {$0.parent}).reduce(0, {$0 + ($1.cellIdentifier != nil ? 1 : 0)})
	}
	
	open func selectedItems() -> [Any]? {
		return tableView?.indexPathsForSelectedRows?.map { indexPath -> Any in
			let node = self.node(at: indexPath)
			let base: Any = node.item.box.unbox()
			return base
		}
	}
}

extension TreeController {
	fileprivate class Node: Diffable {
		
		static func == (lhs: TreeController.Node, rhs: TreeController.Node) -> Bool {
			return lhs.item == rhs.item
		}
		
		var diffIdentifier: AnyHashable {
			return item.diffIdentifier
		}
		
		struct Flags: OptionSet {
			var rawValue: UInt32
			static let isExpandable = Flags(rawValue: 1 << 0)
			static let isExpanded = Flags(rawValue: 1 << 1)
		}
		
		let cellIdentifier: String?
		var flags: Flags
		var estimatedRowHeight: CGFloat?

		weak var parent: Node?
		
		private var _children: [Node]??
		
		var children: [Node]?  {
			if _children == nil {
				var i: Int = 0
				var j: Int = 0
				_children = .some(item.children?.map {
					let child = $0.box.node(treeController: treeController)
					child.offset = i
					child.index = j
					j += 1
					child.parent = self
					if child.cellIdentifier != nil {
						i += 1
					}
					return child
				})
			}
			return _children!
		}
		
		func flatten(into array: inout [Node]) {
			if cellIdentifier != nil {
				array.append(self)
			}
			if cellIdentifier == nil || flags.contains(.isExpanded) {
				children?.forEach {
					$0.flatten(into: &array)
				}
			}
		}
		
		private var _numberOfChildren: Int?
		
		var numberOfChildren: Int {
			get {
				if _numberOfChildren == nil {
					if cellIdentifier == nil || flags.contains(.isExpanded) {
						_numberOfChildren = children?.reduce(0, {$0 + $1.numberOfChildren}) ?? 0
					}
					else {
						_numberOfChildren = 0
					}
				}
				return _numberOfChildren!
			}
			set {
				_numberOfChildren = newValue
			}
		}

		var _section: Int?
		
		var section: Int {
			get {
				return _section ?? parent!.section
			}
			set {
				_section = newValue
			}
		}

		var offset: Int = 0
		var index: Int = 0
		
		var indexPath: IndexPath? {
			guard cellIdentifier != nil else {return nil}
			
			let row = sequence(first: self, next: {$0.parent}).reduce(-1, {$0 + $1.offset + ($1.cellIdentifier == nil ? 0 : 1)})
			return IndexPath(row: row, section: section)
		}
		
		var item: AnyTreeItem {
			didSet {
				_children = nil
				_numberOfChildren = nil
			}
		}
		
		unowned var treeController: TreeController
		
		init<T: TreeItem>(_ item: T, treeController: TreeController) {
			self.treeController = treeController
			self.item = AnyTreeItem(item)
			cellIdentifier = treeController.delegate?.treeController(treeController, cellIdentifierFor: item)
			flags = []
			if treeController.delegate?.treeController(treeController, isExpandable: item) == true {
				flags.insert(.isExpandable)
				if treeController.delegate?.treeController(treeController, isExpanded: item) == true {
					flags.insert(.isExpanded)
				}
			}
		}
		
		func isDescendant(of node: Node) -> Bool {
			return sequence(first: self, next: {$0.parent}).contains(where: {$0 === node})
		}
		
		var isLeaf: Bool {
			return parent?.children?.last(where: {$0.cellIdentifier != nil}) === self
		}
	}
	
	fileprivate func node<T: TreeItem>(for item: T) -> Node {
		if let node = nodes[item.diffIdentifier] {
			node.item = AnyTreeItem(item)
			return node
		}
		else {
			let node = Node(item, treeController: self)
			nodes[item.diffIdentifier] = node
			return node
		}
	}
	
	/*@discardableResult
	private func flatten1(_ item: AnyTreeItem, into: inout [AnyTreeItem], from indexPath: IndexPath, parent: Node?) -> Range<Int> {
		let node = nodes[item.diffIdentifier] ?? newNode(for: item)
		node.section = indexPath.section
		node.children = []
		if parent != nil {
			node.parent = parent
			parent?.children?.append(node)
		}
		
		var indexPath = indexPath

		if node.cellIdentifier != nil {
			node.row = indexPath.row
			node.range = Range(indexPath.row...indexPath.row)
			into.append(item)
			indexPath.row += 1
		}
		else {
			node.range = indexPath.row..<indexPath.row
		}
		if node.flags.contains(.isExpanded) || node.cellIdentifier == nil {
			item.children?.forEach {
				let before = into.count
				
				
				node.range = node.range.lowerBound..<flatten1($0, into: &into, from: indexPath, parent: node).upperBound
				
				let after = into.count
				indexPath.row += after - before
			}
		}
		return node.range
	}*/
	
	private func indexPath<T: TreeItem>(for item: T) -> IndexPath? {
		return nodes[item.diffIdentifier]?.indexPath
	}
	
	private func node(at indexPath: IndexPath) -> Node {
		return flattened![indexPath.section][indexPath.item]
	}
	
	private func handleRowSelection(for item: AnyTreeItem, at indexPath: IndexPath) {
		let node = nodes[item.diffIdentifier]!
		if node.flags.contains(.isExpandable) {
			if node.flags.contains(.isExpanded) {
				let range = (indexPath.item + 1)...(indexPath.item + node.numberOfChildren)
				flattened?[indexPath.section].removeSubrange(range)
				node.flags.remove(.isExpanded)
				
				let n = range.count
				if let parent = node.parent {
//					let from = node.offset + node.numberOfChildren
//					parent.children?.upperBound(where: {$0.offset > from}).forEach {
					parent.children?[(node.index + 1)...].forEach {
						$0.offset -= n
					}
				}

				sequence(first: node, next: {$0.parent}).forEach { i in
					i.numberOfChildren -= n
				}

				
				tableView?.deleteRows(at: range.map{IndexPath(row: $0, section: indexPath.section)}, with: .fade)
				item.box.treeControllerDidCollapseItem(self)
			}
			else {
				node.flags.insert(.isExpanded)
				var array = [Node]()
				node.flatten(into: &array)
				
				let range = (indexPath.item)..<(indexPath.item + array.count)
				flattened?[indexPath.section].replaceSubrange(indexPath.item...indexPath.item, with: array)
				
				let n = range.count - 1
				if let parent = node.parent {
//					let from = node.offset + node.numberOfChildren
//					parent.children?.upperBound(where: {$0.offset > from}).forEach {
					parent.children?[(node.index + 1)...].forEach {
						$0.offset += n
					}
				}

				sequence(first: node, next: {$0.parent}).forEach { i in
					i.numberOfChildren += n
				}
				
				tableView?.insertRows(at: range.dropFirst().map{IndexPath(row: $0, section: indexPath.section)}, with: .fade)
				item.box.treeControllerDidExpandItem(self)
			}
		}
	}
	
	private func moveTarget(fromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> (node: Node, to: Int, newParent: Node?)? {
		var indexPath = proposedDestinationIndexPath
		
		if indexPath.section < flattened!.count && indexPath.item >= flattened![indexPath.section].count {
			indexPath.section += 1
			indexPath.item = 0
		}
		guard indexPath.section < flattened!.count else {return nil}

		if indexPath < sourceIndexPath {
			let before = node(at: indexPath)
		}
		else if indexPath > sourceIndexPath {
			let after = node(at: indexPath)
		}
		else {
			return nil
		}
		
		guard indexPath.section < flattened!.count && indexPath.item < flattened![indexPath.section].count else {return nil}
		let src = node(at: sourceIndexPath)
		
		if indexPath == IndexPath(item: 0, section: 0) {
			if let dst = node(at: indexPath).parent {
				let node = sequence(first: dst) {$0.parent}.first { dst in
					src.item.box.treeController(self, canMoveAt: src.index, inParent: src.parent?.item, to: dst.index, inParent: dst.parent?.item) == true
				}
				if let dst = node {
					return (node: src, to: dst.index, newParent: dst.parent)
				}
			}
			else if src.item.box.treeController(self, canMoveAt: src.index, inParent: src.parent?.item, to: 0, inParent: nil) == true {
				return (node: src, to: 0, newParent: nil)
			}
			return nil
		}
		
		if indexPath < sourceIndexPath {
			if indexPath.item == 0 {
				indexPath.section -= 1
				indexPath.item = flattened![indexPath.section].count - 1
			}
			else {
				indexPath.item -= 1
			}
		}
		
		let dst = node(at: indexPath)
		
		if dst.flags.contains(.isExpanded) && src.item.box.treeController(self, canMoveAt: src.index, inParent: src.parent?.item, to: 0, inParent: dst.item) == true {
			return (node: src, to: 0, dst)
		}
		else if dst.numberOfChildren == 0 {
			let node = sequence(first: dst) { node in
				return node.isLeaf ? node.parent : nil
			}.first { dst in
				src.item.box.treeController(self, canMoveAt: src.index, inParent: src.parent?.item, to: dst.index, inParent: dst.parent?.item) == true
			}
			if let node = node {
				return (node: src, to: node.index, node.parent)
			}
		}
		return nil
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
//		let item = flattened![indexPath.section][indexPath.item]
		let node = self.node(at: indexPath)
		let cell = tableView.dequeueReusableCell(withIdentifier: node.cellIdentifier!, for: indexPath)
		node.item.box.treeController(self, configure: cell)
		return cell
	}
	
	open func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		let node = self.node(at: indexPath)
		return node.item.box.canEdit(self) ?? false
	}
	
	open func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		let node = self.node(at: indexPath)
		node.item.box.treeController(self, commit: editingStyle)
	}
	
	open func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
		return true
	}
	
	open func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
	}
}

extension TreeController: UITableViewDelegate {
	
	open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let node = self.node(at: indexPath)
		node.item.box.treeControllerDidSelectRow(self)
		handleRowSelection(for: node.item, at: indexPath)
	}
	
	open func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
		let node = self.node(at: indexPath)
		node.item.box.treeControllerDidDeselectRow(self)
	}
	
	open func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
		guard let node = self.node(at: indexPath).parent else {return 0}
		return sequence(first: node, next: {$0.parent}).reduce(0, {$0 + ($1.cellIdentifier != nil ? 1 : 0)})
	}
	
	open func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
		let item = flattened![indexPath.section][indexPath.item]
		let node = nodes[item.diffIdentifier]
		return node?.estimatedRowHeight ?? tableView.estimatedRowHeight
	}
	
	open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		let item = flattened![indexPath.section][indexPath.item]
		let node = nodes[item.diffIdentifier]
		node?.estimatedRowHeight = cell.bounds.height
	}
	
	open func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
		let node = self.node(at: indexPath)
		return node.item.box.editActions(self)
	}
	
	public func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
		let node = self.node(at: indexPath)
		return node.item.box.editingStyle(self) ?? .none
	}
	
	open func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
		let node = self.node(at: indexPath)
		node.item.box.treeControllerDidTapAccessoryButton(self)
	}

	open func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
		return moveTarget(fromRowAt: sourceIndexPath, toProposedIndexPath: proposedDestinationIndexPath) == nil ? sourceIndexPath : proposedDestinationIndexPath
	}
}

extension TreeController: UIScrollViewDelegate {
	open func scrollViewDidScroll(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewDidScroll?(scrollView)
	}
	
	open func scrollViewDidZoom(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewDidZoom?(scrollView)
	}
	
	open func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewWillBeginDragging?(scrollView)
	}
	
	open func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
		scrollViewDelegate?.scrollViewWillEndDragging?(scrollView, withVelocity: velocity, targetContentOffset: targetContentOffset)
	}
	
	open func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		scrollViewDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
	}
	
	open func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewWillBeginDecelerating?(scrollView)
	}
	
	open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewDidEndDecelerating?(scrollView)
	}
	open func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewDidEndScrollingAnimation?(scrollView)
	}
	
	open func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return scrollViewDelegate?.viewForZooming?(in: scrollView)
	}
	
	open func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
		scrollViewDelegate?.scrollViewWillBeginZooming?(scrollView, with: view)
	}
	
	open func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
		scrollViewDelegate?.scrollViewDidEndZooming?(scrollView, with: view, atScale: scale)
	}
	
	open func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
		return scrollViewDelegate?.scrollViewShouldScrollToTop?(scrollView) ?? true
	}
	
	open func scrollViewDidScrollToTop(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewDidScrollToTop?(scrollView)
	}
	
	@available(iOS 11.0, *)
	open func scrollViewDidChangeAdjustedContentInset(_ scrollView: UIScrollView) {
		scrollViewDelegate?.scrollViewDidChangeAdjustedContentInset?(scrollView)
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
	func node(treeController: TreeController) -> TreeController.Node
	func treeController(_ treeController: TreeController, configure cell: UITableViewCell) -> Void
	func treeControllerDidSelectRow(_ treeController: TreeController) -> Void
	func treeControllerDidDeselectRow(_ treeController: TreeController) -> Void
	func isExpandable(_ treeController: TreeController) -> Bool?
	func isExpanded(_ treeController: TreeController) -> Bool?
	func treeControllerDidExpandItem(_ treeController: TreeController) -> Void
	func treeControllerDidCollapseItem(_ treeController: TreeController) -> Void
	func canEdit(_ treeController: TreeController) -> Bool?
	func editingStyle(_ treeController: TreeController) -> UITableViewCell.EditingStyle?
	func editActions(_ treeController: TreeController) -> [UITableViewRowAction]?
	func treeController(_ treeController: TreeController, commit editingStyle: UITableViewCell.EditingStyle) -> Void
	func treeControllerDidTapAccessoryButton (_ treeController: TreeController) -> Void
	func treeController(_ treeController: TreeController, canMoveAt fromIndex: Int, inParent oldParent: AnyTreeItem?, to toIndex: Int, inParent newParent: AnyTreeItem?) -> Bool?
	func treeController<T: TreeItem> (_ treeController: TreeController, canMove item: T, at fromIndex: Int, to toIndex: Int, inParent newParent: AnyTreeItem?) -> Bool?
	func treeController<T: TreeItem, S: TreeItem> (_ treeController: TreeController, canMove item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int) -> Bool?

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
	
	func node(treeController: TreeController) -> TreeController.Node {
		return treeController.node(for: base)
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
	
	func isExpandable(_ treeController: TreeController) -> Bool? {
		return treeController.delegate?.treeController(treeController, isExpandable: base)
	}
	
	func isExpanded(_ treeController: TreeController) -> Bool? {
		return treeController.delegate?.treeController(treeController, isExpanded: base)
	}

	
	func treeControllerDidExpandItem(_ treeController: TreeController) -> Void {
		treeController.delegate?.treeController(treeController, didExpand: base)
	}
	
	func treeControllerDidCollapseItem(_ treeController: TreeController) -> Void {
		treeController.delegate?.treeController(treeController, didCollapse: base)
	}
	
	func canEdit(_ treeController: TreeController) -> Bool? {
		return treeController.delegate?.treeController(treeController, canEdit: base)
	}
	
	func editingStyle(_ treeController: TreeController) -> UITableViewCell.EditingStyle? {
		return treeController.delegate?.treeController(treeController, editingStyleFor: base)
	}
	
	func editActions(_ treeController: TreeController) -> [UITableViewRowAction]? {
		return treeController.delegate?.treeController(treeController, editActionsFor: base)
	}
	
	func treeController(_ treeController: TreeController, commit editingStyle: UITableViewCell.EditingStyle) -> Void {
		treeController.delegate?.treeController(treeController, commit: editingStyle, for: base)
	}
	
	func treeControllerDidTapAccessoryButton (_ treeController: TreeController) -> Void {
		treeController.delegate?.treeController(treeController, accessoryButtonTappedFor: base)
	}
	
	func treeController(_ treeController: TreeController, canMoveAt fromIndex: Int, inParent oldParent: AnyTreeItem?, to toIndex: Int, inParent newParent: AnyTreeItem?) -> Bool? {
		if let oldParent = oldParent {
			return oldParent.box.treeController(treeController, canMove: base, at: fromIndex, to: toIndex, inParent: newParent)
		}
		else if let newParent = newParent {
			return newParent.box.treeController(treeController, canMove: base, at: fromIndex, inParent: nil as AnyTreeItem?, to: toIndex)
		}
		else {
			return treeController.delegate?.treeController(treeController, canMove: base, at: fromIndex, inParent: nil as TreeItemNull?, to: toIndex, inParent: nil as TreeItemNull?)
		}
	}
	
	func treeController<T: TreeItem> (_ treeController: TreeController, canMove item: T, at fromIndex: Int, to toIndex: Int, inParent newParent: AnyTreeItem?) -> Bool? {
		if let newParent = newParent {
			return newParent.box.treeController(treeController, canMove: item, at: fromIndex, inParent: base, to: toIndex)
		}
		else {
			return treeController.delegate?.treeController(treeController, canMove: item, at: fromIndex, inParent: base, to: toIndex, inParent: nil as TreeItemNull?)
		}
	}
	
	func treeController<T: TreeItem, S: TreeItem> (_ treeController: TreeController, canMove item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int) -> Bool? {
		return treeController.delegate?.treeController(treeController, canMove: item, at: fromIndex, inParent: oldParent, to: toIndex, inParent: base)
	}

}

extension TreeController {

	open override var debugDescription: String {
		var output = [String]()
		
		func dump(_ node: Node) {
			let level: Int = {
				guard let node = nodes[node.item.diffIdentifier]?.parent else {return 0}
				return sequence(first: node, next: {$0.parent}).reduce(0, {$0 + ($1.cellIdentifier != nil ? 1 : 0)})
			}()

			let base: Any = node.item.box.unbox()
			output.append("\(String.init(repeating: " ", count: level * 4))- \(node.indexPath!): \(base) (\(node.item.diffIdentifier))")
		}
		
		flattened?.forEach {
			$0.forEach { dump($0)
				
			}
		}
		
		return output.joined(separator: "\n")
	}
}

extension RandomAccessCollection {
	
	public func lowerBound(where predicate: (Element) throws -> Bool) rethrows -> Self.SubSequence {
		guard !indices.isEmpty else {return self[endIndex...]}
		var lower = indices.first!
		var count = indices.count
		
		while count > 0 {
			let step = count / 2
			let j = index(lower, offsetBy: step)
			
			if try predicate(self[j]) {
				lower = index(after: j)
				count -= step + 1
			}
			else {
				count = step
			}
		}
		
		return self[..<lower]
	}
	
	public func upperBound(where predicate: (Element) throws -> Bool) rethrows -> Self.SubSequence {
		guard !indices.isEmpty else {return self[endIndex...]}
		var lower = indices.first!
		var count = indices.count
		
		while count > 0 {
			let step = count / 2
			let j = index(lower, offsetBy: step)
			
			if try !predicate(self[j]) {
				lower = index(after: j)
				count -= step + 1
			}
			else {
				count = step
			}
		}
		
		return self[lower...]
	}
	
	public func equalRange(lowerBound: (Element) throws -> Bool, upperBound: (Element) throws -> Bool) rethrows -> Self.SubSequence {
		let lower = try self.lowerBound(where: lowerBound)
		let upper = try self[lower.endIndex...].upperBound(where: upperBound)
		return self[lower.endIndex..<upper.startIndex]
	}
	
}
