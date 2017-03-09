//
//  ViewController.swift
//  Example1
//
//  Created by Artem Shimanski on 09.03.17.
//  Copyright © 2017 Artem Shimanski. All rights reserved.
//

import UIKit
import TreeController

class SectionCell: UITableViewCell, Expandable {
	@IBOutlet weak var expandMark: UILabel?
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var indentationConstraint: NSLayoutConstraint?
	
	func setExpanded(_ expanded: Bool, animated: Bool) {
		expandMark?.text = expanded ? "[-]" : "[+]"
	}
}

class BaseNode: TreeNode {
	let title: String
	
	init(cellIdentifier: String, title: String) {
		self.title = title
		super.init(cellIdentifier: cellIdentifier)
	}
	
	override func configure(cell: UITableViewCell) {
		guard let cell = cell as? SectionCell else {return}
		cell.titleLabel.text = title
		cell.indentationConstraint?.constant = CGFloat(8 * (cell.indentationLevel + 1))
	}

}

class CountryNode: BaseNode {
	let provinces: [String:[String]]
	
	init(country: String, provinces: [String:[String]]) {
		self.provinces = provinces
		super.init(cellIdentifier: "SectionCell", title: country)
		isExpanded = false
	}
	
	override func loadChildren() {
		children = provinces.sorted(by: {$0.0.key < $0.1.key}).map {ProvinceNode(province: $0.key, cities: $0.value)}
	}
	
}

class ProvinceNode: BaseNode {
	let cities: [String]
	
	init(province: String, cities: [String]) {
		self.cities = cities
		super.init(cellIdentifier: cities.count > 0 ? "SectionCell" : "Cell", title: province)
		isExpanded = false
	}
	
	override func loadChildren() {
		children = cities.sorted(by: {$0 < $1}).map {CityNode(city: $0)}
	}
	
}

class CityNode: BaseNode {
	
	init(city: String) {
		super.init(cellIdentifier:"Cell", title: city)
	}
	
}

class ViewController: UITableViewController {

	@IBOutlet var treeController: TreeController!
	override func viewDidLoad() {
		super.viewDidLoad()
		let data = try! Data(contentsOf: Bundle.main.url(forResource: "cities", withExtension: "json")!)
		let json = (try! JSONSerialization.jsonObject(with: data, options: [])) as! [String:[String:[String]]]
		
		let countries = json.sorted(by: {$0.0.key < $0.1.key}).map {CountryNode(country: $0.key, provinces: $0.value)}
		let content = TreeNode()
		content.children = countries
		treeController.content = content
	}

}

