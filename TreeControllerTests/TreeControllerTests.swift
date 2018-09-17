//
//  TreeControllerTests.swift
//  TreeControllerTests
//
//  Created by Artem Shimanski on 15.09.2018.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//

import XCTest
import UIKit

class TreeControllerTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testUpdate1() {
		let vc = TreeViewController(style: .plain)
		vc.loadViewIfNeeded()

		var data = [Item("A", [Item("A1"), Item("A2"), Item("A3")])]
		vc.treeController.reloadData(data, with: .none)
		
		XCTAssertEqual(vc.tableView.numberOfSections, 1)
		XCTAssertEqual(vc.tableView.numberOfRows(inSection: 0), 4)
		data[0].children?.append(Item("A4"))
		vc.treeController.update(contentsOf: data[0], options: [], with: .fade)
		XCTAssertEqual(vc.tableView.numberOfRows(inSection: 0), 5)
		data.append(Item("B"))
		vc.treeController.reloadData(data, options: [], with: .fade)
		XCTAssertEqual(vc.tableView.numberOfSections, 2)
		XCTAssertEqual(vc.tableView.numberOfRows(inSection: 0), 5)
		XCTAssertEqual(vc.tableView.numberOfRows(inSection: 1), 1)
		XCTAssertEqual(vc.tableView.indexPathsForVisibleRows?.sorted().map{vc.tableView.cellForRow(at: $0)}.compactMap{$0?.textLabel?.text}, ["A", "A1", "A2", "A3", "A4", "B"])
    }

	func testUpdate2() {
		let vc = TreeViewController(style: .plain)
		vc.loadViewIfNeeded()
		
		var data = [Item("A", [Item("A1"), Item("A2"), Item("A3")], nil),
					Item("B", [Item("B1")], nil)]
		vc.treeController.reloadData(data, with: .none)
		XCTAssertEqual(vc.tableView.indexPathsForVisibleRows?.sorted().map{vc.tableView.cellForRow(at: $0)}.compactMap{$0?.textLabel?.text}, ["A1", "A2", "A3", "B1"])

		data[0].children![0].children = [Item("A1_1"), Item("A1_2")]
		vc.treeController.update(contentsOf: data[0], options: [], with: .fade)
		XCTAssertEqual(vc.tableView.indexPathsForVisibleRows?.sorted().map{vc.tableView.cellForRow(at: $0)}.compactMap{$0?.textLabel?.text}, ["A1", "A1_1", "A1_2", "A2", "A3", "B1"])

		data[0].children![0].children = [Item("A1_3"), Item("A1_2"), Item("A1_1")]
		vc.treeController.update(contentsOf: data[0].children![0], options: [], with: .fade)
		XCTAssertEqual(vc.tableView.indexPathsForVisibleRows?.sorted().map{vc.tableView.cellForRow(at: $0)}.compactMap{$0?.textLabel?.text}, ["A1", "A1_3", "A1_2", "A1_1", "A2", "A3", "B1"])
		
		data[0].children![0].children = [Item("A1_1"), Item("A1_2")]
		data[1].children![0].children = [Item("A1_3")]
		vc.treeController.reloadData(data, with: .fade)
		XCTAssertEqual(vc.tableView.indexPathsForVisibleRows?.sorted().map{vc.tableView.cellForRow(at: $0)}.compactMap{$0?.textLabel?.text}, ["A1", "A1_1", "A1_2", "A2", "A3", "B1", "A1_3"])
		
		data[1].children![0].children = []
		vc.treeController.update(contentsOf: data[1], options: [], with: .fade)
		XCTAssertEqual(vc.tableView.indexPathsForVisibleRows?.sorted().map{vc.tableView.cellForRow(at: $0)}.compactMap{$0?.textLabel?.text}, ["A1", "A1_1", "A1_2", "A2", "A3", "B1"])
	}
	
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}

struct Item: TreeItem, CustomStringConvertible {
	var text: String
	var children: [Item]?
	var cellIdentifier: String?
	
	init(_ text: String, _ children: [Item]? = nil, _ cellIdentifier: String? = "Cell") {
		self.text = text
		self.children = children
		self.cellIdentifier = cellIdentifier
		self.diffIdentifier = text
	}
	
	var diffIdentifier: String
	
	var description: String {
		return text
	}
}

class TreeViewController: UITableViewController {
	let treeController = TreeController()

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
		treeController.tableView = tableView
		treeController.delegate = self
	}
}

extension TreeViewController: TreeControllerDelegate {
	func treeController<T>(_ treeController: TreeController, cellIdentifierFor item: T) -> String? where T : TreeItem {
		return (item as? Item)?.cellIdentifier
	}
	
	func treeController<T>(_ treeController: TreeController, configure cell: UITableViewCell, for item: T) where T : TreeItem {
		cell.textLabel?.text = "\(item)"
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
	}
	
	func treeController<T>(_ treeController: TreeController, didExpand item: T) where T : TreeItem {
	}
	
	func treeController<T>(_ treeController: TreeController, canEdit item: T) -> Bool where T : TreeItem {
		return true
	}
	
	func treeController<T>(_ treeController: TreeController, canMove item: T) -> Bool where T : TreeItem {
		return true
	}
	
	func treeController<T, S, D>(_ treeController: TreeController, canMove item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int, inParent newParent: D?) -> Bool where T : TreeItem, S : TreeItem, D : TreeItem {
		return true
	}
	
	func treeController<T, S, D>(_ treeController: TreeController, move item: T, at fromIndex: Int, inParent oldParent: S?, to toIndex: Int, inParent newParent: D?) where T : TreeItem, S : TreeItem, D : TreeItem {
	}
}
