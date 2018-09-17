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

    func testBase() {
		let window = UIWindow(frame: CGRect(origin: .zero, size: CGSize(width: 320, height: 480)))
		window.screen = UIScreen.main
		window.makeKeyAndVisible()
		
		let vc = TreeViewController(style: .plain)
		window.rootViewController = vc
		vc.loadViewIfNeeded()
		vc.viewWillAppear(true)

		var data = [Item("A", [Item("A1"), Item("A2"), Item("A3")])]
		vc.treeController.reloadData(data, with: .fade)
		
		let exp = expectation(description: "end")
		
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			XCTAssertEqual(vc.tableView.numberOfSections, 1)
			XCTAssertEqual(vc.tableView.numberOfRows(inSection: 0), 3)
			data[0].children?.append(Item("A4"))
			vc.treeController.update(contentsOf: data[0])
			XCTAssertEqual(vc.tableView.numberOfRows(inSection: 0), 4)

			exp.fulfill()
		}
		
		wait(for: [exp], timeout: 10)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
}

struct Item: TreeItem {
	var text: String
	var children: [Item]?
	init(_ text: String, _ children: [Item]? = nil) {
		self.text = text
		self.children = children
	}
	
	var diffIdentifier: String {
		return text
	}
}

class TreeViewController: UITableViewController {
	let treeController = TreeController()

	override func viewDidLoad() {
		super.viewDidLoad()
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
		treeController.tableView = tableView
	}
}

extension TreeViewController: TreeControllerDelegate {
	func treeController<T>(_ treeController: TreeController, cellIdentifierFor item: T) -> String? where T : TreeItem {
		return "Cell"
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
