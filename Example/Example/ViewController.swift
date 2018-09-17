//
//  ViewController.swift
//  Example1
//
//  Created by Artem Shimanski on 09.03.17.
//  Copyright © 2017 Artem Shimanski. All rights reserved.
//

import UIKit
import TreeController
import CoreData

extension String: TreeItem {}

struct Country: Hashable, TreeItem {
	typealias Child = Region
	struct Region: Hashable, TreeItem {
		typealias Child = String
		var name: String
		var children: [String]?
		var hashValue: Int {
			return name.hashValue
		}
		var diffIdentifier: String {
			return "r:" + name
		}
		
		init(_ arg: (String, [String])) {
			name = arg.0
			children = arg.1.sorted()
		}
	}
	
	var name: String
	var description: String = ""
	var children: [Region]?
	var hashValue: Int {
		return name.hashValue
	}
	var diffIdentifier: String {
		return "c:" + name
	}
	
	init(_ arg: (String, [String:[String]])) {
		name = arg.0
		children = arg.1.sorted{$0.key < $1.key}.map{Region($0)}
	}
}

class Cell: UITableViewCell {
	@IBOutlet weak var expandMark: UILabel?
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var indentationConstraint: NSLayoutConstraint?

	func setExpanded(_ expanded: Bool, animated: Bool) {
		expandMark?.text = expanded ? "[-]" : "[+]"
	}
}

class ViewController: UITableViewController {

	lazy var treeController: TreeController = TreeController()
	override func viewDidLoad() {
		super.viewDidLoad()
		navigationItem.rightBarButtonItem = editButtonItem
		treeController.tableView = tableView
		treeController.delegate = self
		
		let dic = try! JSONSerialization.jsonObject(with: Data.init(contentsOf: Bundle.main.url(forResource: "cities", withExtension: "json")!), options: []) as! [String: [String: [String]]]
		let countries = dic.sorted{$0.key < $1.key}.map {Country($0)}[0...2]
		
		treeController.reloadData(countries)
	}
	
}


extension ViewController: TreeControllerDelegate {
	func treeController<T>(_ treeController: TreeController, cellIdentifierFor item: T) -> String? where T : TreeItem {
		return item.children?.isEmpty == false ? "SectionCell" : "Cell"
	}
	
	func treeController<T>(_ treeController: TreeController, configure cell: UITableViewCell, for item: T) where T : TreeItem {
		guard let cell = cell as? Cell else {return}
		cell.expandMark?.text = treeController.isItemExpanded(item) ? "[-]" : "[+]"
		cell.indentationConstraint?.constant = 8 * CGFloat(treeController.indentationLevel(for: item) + 1)
		switch item {
		case let item as Country:
			cell.titleLabel.text = item.name
		case let item as Country.Region:
			cell.titleLabel.text = item.name
		case let item as String:
			cell.titleLabel.text = item
		default:
			break
		}
	}
	
	func treeController<T>(_ treeController: TreeController, isExpandable item: T) -> Bool where T : TreeItem {
		return true
	}
	
	func treeController<T>(_ treeController: TreeController, isExpanded item: T) -> Bool where T : TreeItem {
		return true
	}
	
	func treeController<T>(_ treeController: TreeController, didSelectRowFor item: T) where T : TreeItem {
		treeController.deselectCell(for: item, animated: true)
	}
	
	func treeController<T>(_ treeController: TreeController, didCollapse item: T) where T : TreeItem {
		guard let cell = treeController.cell(for: item) as? Cell else {return}
		cell.expandMark?.text = "[+]"
	}
	
	func treeController<T>(_ treeController: TreeController, didExpand item: T) where T : TreeItem {
		guard let cell = treeController.cell(for: item) as? Cell else {return}
		cell.expandMark?.text = "[-]"
	}
	
	func treeController<T>(_ treeController: TreeController, canEdit item: T) -> Bool where T : TreeItem {
		return true
	}
	
	func treeController<T>(_ treeController: TreeController, canMove item: T) -> Bool where T : TreeItem {
		return true
	}
	
	func treeController<T, S, D>(_ treeController: TreeController, canMove item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int, inParent newParent: D?) -> Bool where T : TreeItem, S : TreeItem, D : TreeItem {
		let result = (item is Country.Region.Child && newParent is Country.Region) ||
			(item is Country.Region && newParent is Country) ||
			(item is Country && newParent == nil)
//		print("\(type(of: item)): \(result) \(newParent)")
		return result
	}
	
	func treeController<T, S, D>(_ treeController: TreeController, move item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int, inParent newParent: D?) where T : TreeItem, S : TreeItem, D : TreeItem {
	}
}
