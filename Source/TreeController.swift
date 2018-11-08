//
//  TreeController.swift
//  TreeController
//
//  Created by Artem Shimanski on 02.08.2018.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import UIKit

//typealias AnyDiffIdentifier = AnyHashable

struct Weak<T: AnyObject> {
	weak var base: T?
	
	init(_ base: T) {
		self.base = base
	}
}

struct AnyDiffIdentifier: Hashable {
	var base: AnyHashable
	init(_ base: AnyHashable) {
		self.base = sequence(first: base) {
			return type(of:$0.base) == AnyHashable.self ? $0.base as? AnyHashable : nil
		}.map{$0}.last ?? base
	}

	var hashValue: Int {
		return base.hashValue
	}

	static func== (lhs: AnyDiffIdentifier, rhs: AnyDiffIdentifier) -> Bool {
		return lhs.base == rhs.base
	}
}

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
	
	func treeController<T: TreeItem> (_ treeController: TreeController, canEdit item: T) -> Bool
	func treeController<T: TreeItem> (_ treeController: TreeController, editingStyleFor item: T) -> UITableViewCell.EditingStyle
	func treeController<T: TreeItem> (_ treeController: TreeController, editActionsFor item: T) -> [UITableViewRowAction]?
	func treeController<T: TreeItem> (_ treeController: TreeController, commit editingStyle: UITableViewCell.EditingStyle, for item: T) -> Void
	func treeController<T: TreeItem> (_ treeController: TreeController, accessoryButtonTappedFor item: T) -> Void
	func treeController<T: TreeItem> (_ treeController: TreeController, canMove item: T) -> Bool
	func treeController<T: TreeItem, S: TreeItem, D: TreeItem> (_ treeController: TreeController, canMove item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int, inParent newParent: D?) -> Bool
	func treeController<T: TreeItem, S: TreeItem, D: TreeItem> (_ treeController: TreeController, move item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int, inParent newParent: D?) -> Void

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
	public func treeController<T: TreeItem> (_ treeController: TreeController, canMove item: T) -> Bool { return false }
	public func treeController<T: TreeItem, S: TreeItem, D: TreeItem> (_ treeController: TreeController, canMove item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int, inParent newParent: D?) -> Bool { return false }
	public func treeController<T: TreeItem, S: TreeItem, D: TreeItem> (_ treeController: TreeController, move item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int, inParent newParent: D?) -> Void {}
}


extension UITableView {
	
	open func performRowUpdates(diff: Diff, sectionBeforeUpdate: Int, sectionAfterUpdate: Int, with animation: TreeController.RowAnimation) {
		insertRows(at: diff.insertions.map { IndexPath(row: $0, section: sectionAfterUpdate) }, with: animation.insertion)
		deleteRows(at: diff.deletions.map { IndexPath(row: $0, section: sectionBeforeUpdate) }, with: animation.deletion)
//		reloadRows(at: diff.updates.map { IndexPath(row: $0.0, section: sectionBeforeUpdate) }, with: animation.update)
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
	private var flattened: [[AnyTreeItem]]?
	fileprivate var nodes: [AnyDiffIdentifier: Weak<Node>] = [:]
	private var root: AnyTreeItem?
	
	open func reloadData<T: Collection>(_ data: T, options: BatchUpdateOptions = [], with animation: TreeController.RowAnimation = .none, completion: (() -> Void)? = nil) where T.Element: TreeItem {
		root = nil
		let noAnimation = animation == .none
		
		if noAnimation {
			nodes.removeAll()
			self.sections = nil
			self.flattened = nil
		}
		
		let sections = data.enumerated().map { (i, item) -> Node in
			let node = self.node(for: item)
			node.item = AnyTreeItem(item)
			node.section = i
			return node
		}
		
		let flattened = sections.enumerated().map { (i, section) -> [AnyTreeItem] in
			var array = [AnyTreeItem]()
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
						oldSections?[$0].children.forEach {
							nodes[AnyDiffIdentifier($0.diffIdentifier)] = nil
						}
					}
					
					var deletions = Set<AnyDiffIdentifier>()
					var insertions = Set<AnyDiffIdentifier>()

					var rowUpdates = [(Diff, Int, Int)]()
					for (i, j) in diff.indicesMap {
						let old = oldFlattened?[i] ?? []
						let new = flattened[j]
						
						let diff = Diff(old, new)
						rowUpdates.append((diff, i, j))
						diff.deletions.forEach {
							deletions.insert(AnyDiffIdentifier(old[$0].diffIdentifier))
						}
						diff.insertions.forEach {
							insertions.insert(AnyDiffIdentifier(new[$0].diffIdentifier))
						}
					}
					
					deletions.subtract(insertions)
					deletions.forEach {
						nodes[$0] = nil
					}

					DispatchQueue.main.async {
						var reloadIndexPaths = [IndexPath]()
						
						self.tableView?.beginUpdates()
						for (diff, before, after) in rowUpdates {
							self.tableView?.performRowUpdates(diff: diff, sectionBeforeUpdate: before, sectionAfterUpdate: after, with: animation)
							reloadIndexPaths.append(contentsOf: diff.updates.map { IndexPath(row: $0.1, section: after) })
						}
						self.tableView?.performSectionUpdates(diff: diff, with: animation)
						self.sections = sections
						self.flattened = flattened
						self.nodes = nodes
						self.tableView?.endUpdates()
						
						if !reloadIndexPaths.isEmpty {
							self.tableView?.reloadRows(at: reloadIndexPaths, with: animation.update)
						}
						
						completion?()
					}
				}
			}
			else {
				var reloadIndexPaths = [IndexPath]()

				tableView?.beginUpdates()
				
				let diff = Diff(oldSections?.map{$0.diffIdentifier} ?? [], sections.map{$0.diffIdentifier})
				
				diff.deletions.forEach {
					oldSections?[$0].children.forEach {
						nodes[AnyDiffIdentifier($0.diffIdentifier)] = nil
					}
				}
				
				for (i, j) in diff.indicesMap {
					let old = oldFlattened?[i] ?? []
					let new = flattened[j]
					let diff = Diff(old, new)
					tableView?.performRowUpdates(diff: diff, sectionBeforeUpdate: i, sectionAfterUpdate: j, with: animation)
					reloadIndexPaths.append(contentsOf: diff.updates.map { IndexPath(row: $0.1, section: j) })
				}
				
				tableView?.performSectionUpdates(diff: diff, with: animation)
				self.sections = sections
				self.flattened = flattened
				tableView?.endUpdates()
				
				if !reloadIndexPaths.isEmpty {
					self.tableView?.reloadRows(at: reloadIndexPaths, with: animation.update)
				}

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
			
			guard self.flattened != nil, let node = self.nodes[AnyDiffIdentifier(item.diffIdentifier)]?.base else {
				completion?()
				return
			}
			
			let indexPath = node.indexPath
			let range = node.cellIdentifier == nil ?
				(indexPath.item)..<(indexPath.item + node.numberOfChildren) :
				(indexPath.item)..<(indexPath.item + 1 + node.numberOfChildren)

			node.item = AnyTreeItem(item)
			
			let noAnimation = animation == .none
			
			var flattened = [AnyTreeItem]()
			node.flatten(into: &flattened)

			
			let n = flattened.count  - range.count
			if n != 0 {
				if let parent = node.parent {
					parent.children[(node.index + 1)...].forEach {
						$0.offset += n
					}
					sequence(first: parent, next: {$0.parent}).forEach { i in
						i._numberOfChildren = i._numberOfChildren.map{$0 + n}
						i.parent?.children[(i.index + 1)...].forEach {
							$0.offset += n
						}

					}
				}
			}

			
			if noAnimation {
				self.flattened?[indexPath.section].replaceSubrange(range, with: flattened)
				tableView?.reloadData()
				completion?()
			}
			else {
				let oldFlattened = range.isEmpty ? [] : self.flattened?[node.section][range] ?? []
				
				if options.contains(.concurent) {
					DispatchQueue.global(qos: .utility).async {
						var diff = Diff(oldFlattened.map{$0}, flattened.map{$0})
						diff.shift(by: range.lowerBound)
						
						DispatchQueue.main.async {
							let reloadIndexPaths = diff.updates.map { IndexPath(row: $0.1, section: node.section) }

							self.tableView?.beginUpdates()
							self.tableView?.performRowUpdates(diff: diff, sectionBeforeUpdate: node.section, sectionAfterUpdate: node.section, with: animation)
							self.flattened?[node.section].replaceSubrange(range, with: flattened)
							self.tableView?.endUpdates()
							
							if !reloadIndexPaths.isEmpty {
								self.tableView?.reloadRows(at: reloadIndexPaths, with: animation.update)
							}

							completion?()
						}
						

					}
				}
				else {
					tableView?.beginUpdates()
					var diff = Diff(oldFlattened, flattened)
					let reloadIndexPaths = diff.updates.map { IndexPath(row: $0.1, section: node.section) }

					diff.shift(by: range.lowerBound)
					tableView?.performRowUpdates(diff: diff, sectionBeforeUpdate: node.section, sectionAfterUpdate: node.section, with: animation)
					if range.isEmpty {
						self.flattened?[node.section].insert(contentsOf: flattened, at: range.lowerBound)
					}
					else {
						self.flattened?[node.section].replaceSubrange(range, with: flattened)
					}
					tableView?.endUpdates()
					
					if !reloadIndexPaths.isEmpty {
						self.tableView?.reloadRows(at: reloadIndexPaths, with: animation.update)
					}

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
		let node = self.node(for: item)
//		node.item = AnyTreeItem(item)
		node.cellIdentifier = node.item.box.cellIdentifier(self)
		
		tableView?.reloadRows(at: [indexPath], with: animation)
	}
	
	open func isItemExpanded<T: TreeItem>(_ item: T) -> Bool {
		return nodes[AnyDiffIdentifier(item.diffIdentifier)]?.base?.flags.contains(.isExpanded) == true
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
		guard let node = nodes[AnyDiffIdentifier(item.diffIdentifier)]?.base?.parent else {return 0}
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
		
		var cellIdentifier: String?
		var flags: Flags
		var estimatedRowHeight: CGFloat?

		weak var parent: Node?
		
		private var _children: [Node]?
		
		private func getChildren() -> [Node] {
			var i: Int = 0
			var j: Int = 0
			return item.children?.map {
				let child = $0.box.node(treeController: treeController)
				child.item = $0
				child.offset = i
				child.index = j
				j += 1
				child.parent = self
				if child.cellIdentifier != nil {
					i += 1
				}
				if child.flags.contains(.isExpanded) {
					i += child.numberOfChildren
				}
				return child
			} ?? []
		}
		
		var children: [Node]  {
			get {
				if _children == nil {
					_children = getChildren()
				}
				return _children!
			}
			set {
				_children = newValue
			}
		}
		
		func flatten(into array: inout [AnyTreeItem]) {
			if cellIdentifier != nil {
				array.append(item)
			}
			if cellIdentifier == nil || flags.contains(.isExpanded) {
				children.forEach {
					$0.flatten(into: &array)
				}
			}
		}
		
		fileprivate var _numberOfChildren: Int?
		
		private func getNumberOfChildren() -> Int {
			if cellIdentifier == nil || flags.contains(.isExpanded) {
				return children.reduce(0, {$0 + $1.numberOfChildren + ($1.cellIdentifier == nil ? 0 : 1)})
			}
			else {
				return 0
			}
		}
		
		var numberOfChildren: Int {
			get {
				if _numberOfChildren == nil {
					_numberOfChildren = getNumberOfChildren()
				}
				return _numberOfChildren!
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
		
		var indexPath: IndexPath {
			var indexPath = parent?.indexPath ?? IndexPath(row: offset, section: section)
			indexPath.row += offset
			if parent?.cellIdentifier != nil {
				indexPath.row += 1
			}
			return indexPath
		}
		
		var item: AnyTreeItem {
			didSet {
				if _children != nil {
					withExtendedLifetime(_children) {
						_children = getChildren()
					}
				}
				_numberOfChildren = nil
			}
		}
		
		unowned var treeController: TreeController
		
		init<T: TreeItem>(_ item: T, treeController: TreeController) {
			self.treeController = treeController
			let anyItem = AnyTreeItem(item)
			self.item = anyItem
			cellIdentifier = anyItem.box.cellIdentifier(treeController)
			flags = []
			if cellIdentifier == nil {
				flags.insert(.isExpanded)
			}
			else if anyItem.box.isExpandable(treeController) == true {
				flags.insert(.isExpandable)
				if anyItem.box.isExpanded(treeController) == true {
					flags.insert(.isExpanded)
				}
			}
			else {
				flags.insert(.isExpanded)
			}
		}
		
//		init<T: TreeItem>(_ item: T, other node: Node) {
//			self.treeController = node.treeController
//			self.item = AnyTreeItem(item)
//			cellIdentifier = node.cellIdentifier
//			flags = node.flags
//		}
		
		deinit {
			treeController.nodes[AnyDiffIdentifier(diffIdentifier)] = nil
		}
		
		func isDescendant(of node: Node) -> Bool {
			return sequence(first: self, next: {$0.parent}).contains(where: {$0 === node})
		}
		
//		var isLeaf: Bool {
//			return parent?.children?.last(where: {$0.cellIdentifier != nil}) === self
//		}
	}
	
	fileprivate func node<T: TreeItem>(for item: T) -> Node {
		if let node = nodes[AnyDiffIdentifier(item.diffIdentifier)]?.base {
//			node.item = AnyTreeItem(item)
			return node
		}
		else {
			let node = Node(item, treeController: self)
			nodes[AnyDiffIdentifier(item.diffIdentifier)] = Weak(node)
			return node
		}
	}
	
	private func indexPath<T: TreeItem>(for item: T) -> IndexPath? {
		guard let node = nodes[AnyDiffIdentifier(item.diffIdentifier)]?.base else {return nil}
		guard node.cellIdentifier != nil else {return nil}
		return node.indexPath
	}
	
	private func node(at indexPath: IndexPath) -> Node {
		return nodes[AnyDiffIdentifier(flattened![indexPath.section][indexPath.item].diffIdentifier)]!.base!
//		return flattened![indexPath.section][indexPath.item]
	}
	
	private func handleRowSelection(for item: AnyTreeItem, at indexPath: IndexPath) {
		guard tableView?.isEditing == false else {return}
		let node = nodes[AnyDiffIdentifier(item.diffIdentifier)]!.base!
		if node.flags.contains(.isExpandable) {
			if node.flags.contains(.isExpanded) {
				let range = (indexPath.item + 1)..<(indexPath.item + 1 + node.numberOfChildren)
				flattened?[indexPath.section].removeSubrange(range)
				node.flags.remove(.isExpanded)

				if !range.isEmpty {
					let n = range.count
					if let parent = node.parent {
						parent.children[(node.index + 1)...].forEach {
							$0.offset -= n
						}
					}
					
					sequence(first: node, next: {$0.parent}).forEach { i in
						i._numberOfChildren = i._numberOfChildren.map{$0 - n}
					}
					
					
					tableView?.deleteRows(at: range.map{IndexPath(row: $0, section: indexPath.section)}, with: .fade)
				}

				item.box.treeControllerDidCollapseItem(self)
			}
			else {
				node.flags.insert(.isExpanded)
				var array = [AnyTreeItem]()
				node.flatten(into: &array)
				
				let range = (indexPath.item)..<(indexPath.item + array.count)
				flattened?[indexPath.section].replaceSubrange(indexPath.item...indexPath.item, with: array)
				
				let n = range.count - 1
				if let parent = node.parent {
					parent.children[(node.index + 1)...].forEach {
						$0.offset += n
					}
				}

				sequence(first: node, next: {$0.parent}).forEach { i in
					i._numberOfChildren = i._numberOfChildren.map{$0 + n}
				}
				
				tableView?.insertRows(at: range.dropFirst().map{IndexPath(row: $0, section: indexPath.section)}, with: .fade)
				item.box.treeControllerDidExpandItem(self)
			}
		}
	}
	
	private struct MoveTarget {
		var node: Node
		var newParent: Node?
		var index: Int
		var indexPath: IndexPath
	}
	
	private func moveTarget(fromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> MoveTarget? {
		var indexPath = proposedDestinationIndexPath
		if indexPath.section < flattened!.count && indexPath.item >= flattened![indexPath.section].count {
			indexPath.section += 1
			indexPath.item = 0
		}
		let src = node(at: sourceIndexPath)
		
		let nodes = flattened!.joined().map{self.nodes[AnyDiffIdentifier($0.diffIdentifier)]!.base!}
		let after: Node
		
		if indexPath.section < flattened!.count {
			var i = flattened![0..<indexPath.section].map{$0.count}.reduce(indexPath.row, +)
			if i == 0 {
				if let node = nodes[nodes.index(nodes.startIndex, offsetBy: i)].parent {
					after = sequence(first: node) { $0.children.first?.cellIdentifier == nil ? $0.children.first : nil }.lazy.map{$0}.last ?? node
				}
				else if src.item.box.treeController(self, canMoveAt: src.index, inParent: src.parent?.item, to: 0, inParent: nil) == true {
					return MoveTarget(node: src, newParent: nil, index: 0, indexPath: proposedDestinationIndexPath)
				}
				else {
					return nil
				}
			}
			else {
//				if sourceIndexPath.section != indexPath.section {
				if indexPath < sourceIndexPath || sourceIndexPath.section != indexPath.section {
					i -= 1
				}
				let node = nodes[nodes.index(nodes.startIndex, offsetBy: i)]
				after = sequence(first: node) { $0.children.first?.cellIdentifier == nil ? $0.children.first : nil }.lazy.map{$0}.last ?? node
			}
		}
		else {
			guard let node = nodes.last else {return nil}
			after = sequence(first: node) { $0.children.first?.cellIdentifier == nil ? $0.children.first : nil }.lazy.map{$0}.last ?? node
		}

		guard !after.isDescendant(of: src) else {return nil}
		
		if after.flags.contains(.isExpanded) && src.item.box.treeController(self, canMoveAt: src.index, inParent: src.parent?.item, to: 0, inParent: after.item) == true {
			indexPath = after.indexPath
			if after.cellIdentifier != nil {
				indexPath.row += 1
			}
			if indexPath.section == sourceIndexPath.section && indexPath > sourceIndexPath {
				indexPath.row -= 1
			}
			return MoveTarget(node: src, newParent: after, index: 0, indexPath: indexPath)
		}
		else {
			let node = sequence(first: after) {$0.parent}.first { node in
				after.flags.contains(.isExpanded) && src.item.box.treeController(self, canMoveAt: src.index, inParent: src.parent?.item, to: node.index, inParent: node.parent?.item) == true
			}
			if let node = node {
				var indexPath = node.indexPath
				if indexPath > sourceIndexPath {
					indexPath.row += node.numberOfChildren
				}
				return MoveTarget(node: src, newParent: node.parent, index: node.index, indexPath: indexPath)
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
		let node = self.node(at: indexPath)
		return node.item.box.canMove(self) ?? false
	}
	
	open func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
		guard let target = moveTarget(fromRowAt: sourceIndexPath, toProposedIndexPath: destinationIndexPath) else {return}
		let item = flattened![sourceIndexPath.section].remove(at: sourceIndexPath.item)
		let node = nodes[AnyDiffIdentifier(item.diffIdentifier)]!.base!
		let moveFrom = (node.index, node.parent?.item)
		let n = node.numberOfChildren + (node.cellIdentifier == nil ? 0 : 1)

		sequence(first: node, next: {$0.parent}).reversed().forEach { node in
			node.parent?.children[(node.index + 1)...].forEach {
				$0.offset -= n
			}
			node.parent?._numberOfChildren = (node.parent?._numberOfChildren).map {$0 - n}
		}
		node.parent?.children.remove(at: node.index)
		node.parent?.children[node.index...].forEach {$0.index -= 1}
		
		target.newParent?.children[target.index...].forEach {$0.index += 1}
		node.index = target.index
		if let children = target.newParent?.children, children.count > target.index {
			node.offset = children[target.index].offset
		}
		else if target.newParent != nil {
			node.offset = 0
		}
		else {
			node.offset = target.index
		}
		
		node.parent = target.newParent
		target.newParent?.children.insert(node, at: target.index)

		sequence(first: node, next: {$0.parent}).reversed().forEach { node in
			node.parent?.children[(node.index + 1)...].forEach {
				$0.offset += n
			}
			node.parent?._numberOfChildren = (node.parent?._numberOfChildren).map {$0 + n}
		}

		

		flattened![destinationIndexPath.section].insert(item, at: destinationIndexPath.item)
		DispatchQueue.main.async {
			self.tableView!.beginUpdates()


			if sourceIndexPath < destinationIndexPath {
				let range = sourceIndexPath.item..<(sourceIndexPath.item + node.numberOfChildren)
				let children = self.flattened![sourceIndexPath.section][range]
				self.flattened![destinationIndexPath.section].insert(contentsOf: children, at: destinationIndexPath.item + 1)
				self.flattened![sourceIndexPath.section].removeSubrange(range)
				
				let dn = sourceIndexPath.section == destinationIndexPath.section ? 1 - children.count : 1
				for (i, row) in range.enumerated() {
					self.tableView?.moveRow(at: IndexPath(row: row, section: sourceIndexPath.section), to: IndexPath(row: destinationIndexPath.row + i + dn, section: destinationIndexPath.section))
				}
			}
			else {
				let range: Range<Int>
				if sourceIndexPath.section == destinationIndexPath.section {
					range = (sourceIndexPath.item + 1)..<(sourceIndexPath.item + 1 + node.numberOfChildren)
				}
				else {
					range = (sourceIndexPath.item)..<(sourceIndexPath.item + node.numberOfChildren)
				}
				let children = self.flattened![sourceIndexPath.section][range]
				self.flattened![sourceIndexPath.section].removeSubrange(range)
				self.flattened![destinationIndexPath.section].insert(contentsOf: children, at: destinationIndexPath.item + 1)
				
				for (i, row) in range.enumerated() {
					self.tableView?.moveRow(at: IndexPath(row: row, section: sourceIndexPath.section), to: IndexPath(row: destinationIndexPath.row + i + 1, section: destinationIndexPath.section))
				}
			}
			
			self.tableView!.endUpdates()
			
			node.item.box.treeController(self, moveAt: moveFrom.0, inParent: moveFrom.1, to: target.index, inParent: target.newParent?.item)
		}
	}
}

extension TreeController: UITableViewDelegate {
	
	open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let node = self.node(at: indexPath)
		handleRowSelection(for: node.item, at: indexPath)
		node.item.box.treeControllerDidSelectRow(self)
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
		let node = self.node(at: indexPath)
		return node.estimatedRowHeight ?? tableView.estimatedRowHeight
	}
	
	open func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		let node = self.node(at: indexPath)
		node.estimatedRowHeight = cell.bounds.height
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
		guard let target = moveTarget(fromRowAt: sourceIndexPath, toProposedIndexPath: proposedDestinationIndexPath) else {
			return sourceIndexPath
		}

		return target.indexPath
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
	func cellIdentifier(_ treeController: TreeController) -> String?
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
	func canMove(_ treeController: TreeController) -> Bool?
	func treeController(_ treeController: TreeController, canMoveAt fromIndex: Int, inParent oldParent: AnyTreeItem?, to toIndex: Int, inParent newParent: AnyTreeItem?) -> Bool?
	func treeController<T: TreeItem> (_ treeController: TreeController, canMove item: T, at fromIndex: Int, to toIndex: Int, inParent newParent: AnyTreeItem?) -> Bool?
	func treeController<T: TreeItem, S: TreeItem> (_ treeController: TreeController, canMove item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int) -> Bool?
	func treeController(_ treeController: TreeController, moveAt fromIndex: Int, inParent oldParent: AnyTreeItem?, to toIndex: Int, inParent newParent: AnyTreeItem?) -> Void
	func treeController<T: TreeItem> (_ treeController: TreeController, move item: T, at fromIndex: Int, to toIndex: Int, inParent newParent: AnyTreeItem?) -> Void
	func treeController<T: TreeItem, S: TreeItem> (_ treeController: TreeController, move item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int) -> Void


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
	
	func cellIdentifier(_ treeController: TreeController) -> String? {
		return treeController.delegate?.treeController(treeController, cellIdentifierFor: base)
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
	
	func canMove(_ treeController: TreeController) -> Bool? {
		return treeController.delegate?.treeController(treeController, canMove: base)
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

	func treeController(_ treeController: TreeController, moveAt fromIndex: Int, inParent oldParent: AnyTreeItem?, to toIndex: Int, inParent newParent: AnyTreeItem?) {
		if let oldParent = oldParent {
			oldParent.box.treeController(treeController, move: base, at: fromIndex, to: toIndex, inParent: newParent)
		}
		else if let newParent = newParent {
			newParent.box.treeController(treeController, move: base, at: fromIndex, inParent: nil as AnyTreeItem?, to: toIndex)
		}
		else {
			treeController.delegate?.treeController(treeController, move: base, at: fromIndex, inParent: nil as TreeItemNull?, to: toIndex, inParent: nil as TreeItemNull?)
		}
	}
	
	func treeController<T: TreeItem> (_ treeController: TreeController, move item: T, at fromIndex: Int, to toIndex: Int, inParent newParent: AnyTreeItem?) {
		if let newParent = newParent {
			newParent.box.treeController(treeController, move: item, at: fromIndex, inParent: base, to: toIndex)
		}
		else {
			treeController.delegate?.treeController(treeController, move: item, at: fromIndex, inParent: base, to: toIndex, inParent: nil as TreeItemNull?)
		}
	}
	
	func treeController<T: TreeItem, S: TreeItem> (_ treeController: TreeController, move item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int) {
		treeController.delegate?.treeController(treeController, move: item, at: fromIndex, inParent: oldParent, to: toIndex, inParent: base)
	}
}

extension TreeController {

	open override var debugDescription: String {
		var output = [String]()
		
		func dump(_ node: Node) {
			let level: Int = {
				guard let node = nodes[AnyDiffIdentifier(node.item.diffIdentifier)]?.base?.parent else {return 0}
				return sequence(first: node, next: {$0.parent}).reduce(0, {$0 + ($1.cellIdentifier != nil ? 1 : 0)})
			}()

			let base: Any = node.item.box.unbox()
			output.append("\(String.init(repeating: " ", count: level * 4))- \(node.indexPath): \(base) (\(node.item.diffIdentifier))")
		}
		
		flattened?.forEach {
			$0.forEach { dump(nodes[AnyDiffIdentifier($0.diffIdentifier)]!.base!)
				
			}
		}
		
		output.append("\nNodes:")
		output.append(self.dump)
		return output.joined(separator: "\n")
	}
	
	fileprivate var dump: String {
		var output = [String]()
		
		func dumpItem(_ node: Node) {
			let level: Int = {
				guard let node = nodes[AnyDiffIdentifier(node.item.diffIdentifier)]?.base?.parent else {return 0}
				return sequence(first: node, next: {$0.parent}).map{$0}.count
			}()

			let base: Any = node.item.box.unbox()
			output.append("\(String.init(repeating: " ", count: level * 4))- \(node.indexPath):\(node.cellIdentifier == nil ? "" : "*") | \(node.numberOfChildren) \(type(of:base))")
			node.children.forEach {
				dumpItem($0)
			}
		}
		
		sections?.forEach { section in
			dumpItem(section)
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
