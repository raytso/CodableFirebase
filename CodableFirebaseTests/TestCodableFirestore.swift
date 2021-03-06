//
//  TestCodableFirestore.swift
//  SlapTests
//
//  Created by Oleksii on 20/10/2017.
//  Copyright © 2017 Slap. All rights reserved.
//

import XCTest
import CodableFirebase

fileprivate struct Document: Codable, Equatable {
    let stringExample: String
    let booleanExample: Bool
    let numberExample: Double
    let dateExample: Date
    let arrayExample: [String]
    let nullExample: Int?
    let objectExample: [String: String]
    
    static func == (lhs: Document, rhs: Document) -> Bool {
        return lhs.stringExample == rhs.stringExample
            && lhs.booleanExample == rhs.booleanExample
            && lhs.numberExample == rhs.numberExample
            && lhs.dateExample == rhs.dateExample
            && lhs.arrayExample == rhs.arrayExample
            && lhs.nullExample == rhs.nullExample
            && lhs.objectExample == rhs.objectExample
    }
}

/// Wraps a type T so that it can be encoded at the top level of a payload.
struct TopLevelWrapper<T> : Codable, Equatable where T : Codable, T : Equatable {
    enum CodingKeys : String, CodingKey {
        case value
    }
    
    let value: T
    
    init(_ value: T) {
        self.value = value
    }
    
    static func ==(_ lhs: TopLevelWrapper<T>, _ rhs: TopLevelWrapper<T>) -> Bool {
        return lhs.value == rhs.value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try container.decode(T.self, forKey: .value)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
    }
}

class TestCodableFirestore: XCTestCase {
    
    func testFirebaseEncoder() {
        let model = Document(
            stringExample: "Hello world!",
            booleanExample: true,
            numberExample: 3.14159265,
            dateExample: Date(),
            arrayExample: ["hello", "world"],
            nullExample: nil,
            objectExample: ["objectExample": "one"]
        )
        
        let dict: [String : Any] = [
            "stringExample": "Hello world!",
            "booleanExample": true,
            "numberExample": 3.14159265,
            "dateExample": model.dateExample,
            "arrayExample": ["hello", "world"],
            "objectExample": ["objectExample": "one"]
        ]
        
        XCTAssertEqual((try FirestoreEncoder().encode(model)) as NSDictionary, dict as NSDictionary)
        XCTAssertEqual(try? FirestoreDecoder().decode(Document.self, from: dict) , model)
    }
    
    // MARK: - Encoder Features
    func testNestedContainerCodingPaths() {
        do {
            let _ = try FirestoreEncoder().encode(NestedContainersTestType())
        } catch let error as NSError {
            XCTFail("Caught error during encoding nested container types: \(error)")
        }
    }
    
    func testSuperEncoderCodingPaths() {
        do {
            let _ = try FirestoreEncoder().encode(NestedContainersTestType(testSuperEncoder: true))
        } catch let error as NSError {
            XCTFail("Caught error during encoding nested container types: \(error)")
        }
    }
    
    func testInterceptData() {
        let data = try! JSONSerialization.data(withJSONObject: [], options: [])
        _testRoundTrip(of: TopLevelWrapper(data), expected: ["value": data])
    }
    
    func testInterceptDate() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        _testRoundTrip(of: TopLevelWrapper(date), expected: ["value": date])
    }
    
    private func _testEncodeFailure<T : Encodable>(of value: T) {
        do {
            let _ = try FirestoreEncoder().encode(value)
            XCTFail("Encode of top-level \(T.self) was expected to fail.")
        } catch {}
    }
    
    private func _testRoundTrip<T>(of value: T, expected dict: [String: Any]? = nil) where T : Codable, T : Equatable {
        var payload: [String: Any]! = nil
        do {
            payload = try FirestoreEncoder().encode(value)
        } catch {
            XCTFail("Failed to encode \(T.self) to plist: \(error)")
        }
        
        if let expectedDict = dict {
            XCTAssertEqual(payload as NSDictionary, expectedDict as NSDictionary, "Produced dictionary not identical to expected dictionary")
        }
        
        do {
            let decoded = try FirestoreDecoder().decode(T.self, from: payload)
            XCTAssertEqual(decoded, value, "\(T.self) did not round-trip to an equal value.")
        } catch {
            XCTFail("Failed to decode \(T.self) from plist: \(error)")
        }
    }
}

func expectEqualPaths(_ lhs: [CodingKey], _ rhs: [CodingKey], _ prefix: String) {
    if lhs.count != rhs.count {
        XCTFail("\(prefix) [CodingKey].count mismatch: \(lhs.count) != \(rhs.count)")
        return
    }
    
    for (key1, key2) in zip(lhs, rhs) {
        switch (key1.intValue, key2.intValue) {
        case (.none, .none): break
        case (.some(let i1), .none):
            XCTFail("\(prefix) CodingKey.intValue mismatch: \(type(of: key1))(\(i1)) != nil")
            return
        case (.none, .some(let i2)):
            XCTFail("\(prefix) CodingKey.intValue mismatch: nil != \(type(of: key2))(\(i2))")
            return
        case (.some(let i1), .some(let i2)):
            guard i1 == i2 else {
                XCTFail("\(prefix) CodingKey.intValue mismatch: \(type(of: key1))(\(i1)) != \(type(of: key2))(\(i2))")
                return
            }
            
            break
        }
        
        XCTAssertEqual(key1.stringValue, key2.stringValue, "\(prefix) CodingKey.stringValue mismatch: \(type(of: key1))('\(key1.stringValue)') != \(type(of: key2))('\(key2.stringValue)')")
    }
}
