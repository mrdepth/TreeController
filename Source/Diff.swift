//
//  Diff.swift
//  TreeController
//
//  Created by Artem Shimanski on 02.08.2018.
//  Copyright © 2018 Artem Shimanski. All rights reserved.
//
// Based on Paul Heckel's Diff Algorithm 'Isolating Differences Between Files' https://gist.github.com/ndarville/3166060

import UIKit

public protocol Diffable: Equatable {
	associatedtype DiffIdentifier: Hashable
	var diffIdentifier: DiffIdentifier {get}
}

public extension Diffable where Self: Hashable {
	var diffIdentifier: Self {
		return self
	}
}

extension String: Diffable {}
extension Int: Diffable {}
extension UInt: Diffable {}
extension Int64: Diffable {}
extension UInt64: Diffable {}
extension Int32: Diffable {}
extension UInt32: Diffable {}
extension Int16: Diffable {}
extension UInt16: Diffable {}
extension Int8: Diffable {}
extension UInt8: Diffable {}
extension Double: Diffable {}
extension Float: Diffable {}
extension NSObject: Diffable {}

public struct Diff {
	public enum Operation {
		case insert(Int)
		case delete(Int)
	}
	public var insertions = IndexSet()
	public var deletions = IndexSet()
	public var moves = [(Int, Int)]()
	public var updates = [(Int, Int)]()
	public var indicesMap = [(Int, Int)]()
	
	public init<T1: Collection, T2: Collection>(_ old: T1, _ new: T2) where T1.Element: Diffable, T1.Index == Int, T1.Element == T2.Element, T1.Index == T2.Index {
		var table = [T1.Element.DiffIdentifier: Entry.Symbol]()
		var oa = [Entry]()
		var na = [Entry]()
		
		//Pass 1
		for item in new {
			let entry = table[item.diffIdentifier] ?? Entry.Symbol()
			table[item.diffIdentifier] = entry
			entry.nc += 1
			na.append(.symbol(entry))
		}
		
		//Pass 2
		for (index, item) in old.enumerated() {
			let entry = table[item.diffIdentifier] ?? Entry.Symbol()
			table[item.diffIdentifier] = entry
			entry.oc += 1
			entry.olno.insert(index)
			oa.append(.symbol(entry))
		}
		
		//Pass 3
		for case let (index, .symbol(entry)) in na.enumerated() where entry.nc == 1 && entry.oc == 1 && !entry.olno.isEmpty {
			let oldIndex = entry.olno.first!
			entry.olno.remove(oldIndex)
			na[index] = .index(oldIndex)
			oa[oldIndex] = .index(index)
		}
		
		//Pass 4
		
		var i = 0
		while i < na.count - 1 {
			if case let .index(j) = na[i], j + 1 < oa.count,
				case let .symbol(newEntry) = na[i + 1],
				case let .symbol(oldEntry) = oa[j + 1], newEntry === oldEntry {
				na[i + 1] = .index(j + 1)
				oa[j + 1] = .index(i + 1)
				oldEntry.olno.remove(j + 1)
			}
			
			i += 1
		}
		
		//Pass 5
		
		i = na.count - 1
		while i > 0 {
			if case let .index(j) = na[i], j - 1 >= 0,
				case let .symbol(newEntry) = na[i - 1],
				case let .symbol(oldEntry) = oa[j - 1], newEntry === oldEntry {
				na[i - 1] = .index(j - 1)
				oa[j - 1] = .index(i - 1)
				oldEntry.olno.remove(j - 1)
			}
			
			i -= 1
		}
		
		//Pass 6
		for case let (index, .symbol(entry)) in na.enumerated() where entry.nc != 0 && entry.oc != 0 && !entry.olno.isEmpty {
			let oldIndex = entry.olno.first!
			entry.olno.remove(oldIndex)
			na[index] = .index(oldIndex)
			oa[oldIndex] = .index(index)
		}
		
		//Final Pass
		
		//Deletions
		var deleteOffsets = Array(repeating: 0, count: old.count)
		var runningOffset = 0
		for (index, item) in oa.enumerated() {
			deleteOffsets[index] = runningOffset
			if case .symbol = item {
				deletions.insert(index)
				runningOffset += 1
			}
		}
		
		runningOffset = 0
		//Insertions, moves, updates
		for (index, item) in na.enumerated() {
			switch item {
			case .symbol:
				insertions.insert(index)
				runningOffset += 1
			case let .index(oldIndex):
				if old[oldIndex] != new[index] {
					updates.append((oldIndex, index))
				}
				
				let deleteOffset = deleteOffsets[oldIndex]
				if (oldIndex - deleteOffset + runningOffset) != index {
					moves.append((oldIndex, index))
				}
				indicesMap.append((oldIndex, index))
			}
		}
	}
	
	public func orderedOperations() -> [Operation] {
		return deletions.union(IndexSet(moves.map{$0.0})).map{Operation.delete($0)}.reversed() +
			insertions.union(IndexSet(moves.map{$0.1})).map{Operation.insert($0)}
	}
}

extension Diff: CustomStringConvertible {
	public var description: String {
		return "Diff:{\n" +
			"\tdeletions: [\(deletions.map{$0.description}.joined(separator: ","))]\n" +
			"\tinsertions: [\(insertions.map{$0.description}.joined(separator: ","))]\n" +
			"\tmoves: [\(moves.map{"[\($0.0)->\($0.1)]"}.joined(separator: ","))]\n" +
		"\tupdates: [\(updates.map{$0.0.description}.joined(separator: ","))]\n}"
	}
}

extension Diff {
	private enum Entry {
		class Symbol {
			var oc = 0
			var nc = 0
			var olno = IndexSet()
			
		}
		case symbol(Symbol)
		case index(Int)
	}
}

extension Diff {
	public mutating func shift(by delta: Int) {
		deletions.shift(startingAt: 0, by: delta)
		insertions.shift(startingAt: 0, by: delta)
		moves = moves.map { ($0 + delta, $1 + delta) }
		updates = updates.map { ($0 + delta, $1 + delta) }
		indicesMap = indicesMap.map { ($0 + delta, $1 + delta) }
	}
}
