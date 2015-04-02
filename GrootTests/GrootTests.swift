//
//  GrootTests.swift
//  Groot
//
//  Created by Guille Gonzalez on 29/03/15.
//  Copyright (c) 2015 Guille Gonzalez. All rights reserved.
//

import XCTest
import CoreData
import Groot

class GrootTests: XCTestCase {
    var store: ManagedStore?
    var context: NSManagedObjectContext?

    override func setUp() {
        super.setUp()
        
        store = ManagedStore(model: NSManagedObjectModel.testModel()!, error: nil)
        XCTAssertNotNil(store)
        
        context = store?.contextWithConcurrencyType(.MainQueueConcurrencyType)
        XCTAssertNotNil(context)
        
        let transformerName = "GrootTests.Transformer"
        
        if NSValueTransformer(forName: transformerName) == nil {
            func toInt(value: String) -> Int? {
                return value.toInt()
            }
            
            func toString(value: Int) -> String? {
                return "\(value)"
            }
            
            NSValueTransformer.setValueTransformerWithName(transformerName,
                transform: toInt, reverseTransform: toString)
        }
    }
    
    override func tearDown() {
        context = nil
        store = nil
        
        super.tearDown()
    }
    
    func testInsertObject() {
        let batmanJSON: JSONObject = [
            "name": "Batman",
            "real_name": "Bruce Wayne",
            "id": "1699",
            "powers": [
                [
                    "id": "4",
                    "name": "Agility"
                ],
                NSNull(),
                [
                    "id": "9",
                    "name": "Insanely Rich"
                ]
            ],
            "publisher": [
                "id": "10",
                "name": "DC Comics"
            ]
        ]
        
        var error: NSError? = nil
        if let batman = Character.fromJSONObject(batmanJSON, inContext: context!, mergeChanges: false, error: &error) {
            XCTAssertNil(error, "shouldn't return an error")
            XCTAssertEqual(1699, batman.identifier, "should serialize attributes")
            XCTAssertEqual("Batman", batman.name!, "should serialize attributes")
            XCTAssertEqual("Bruce Wayne", batman.realName!, "should serialize attributes")
            
            XCTAssertEqual(2, batman.powers!.count, "should serialize to-many relationships")
            
            if let agility = batman.powers?[0] as? Power {
                XCTAssertEqual(4, agility.identifier, "should serialize to-many relationships")
                XCTAssertEqual("Agility", agility.name!, "should serialize to-many relationships")
            } else {
                XCTFail("should serialize to-many relationships")
            }
            
            if let wealth = batman.powers?[1] as? Power {
                XCTAssertEqual(9, wealth.identifier, "should serialize to-many relationships")
                XCTAssertEqual("Insanely Rich", wealth.name!, "should serialize to-many relationships")
            } else {
                XCTFail("should serialize to-many relationships")
            }
            
            if let publisher = batman.publisher {
                XCTAssertEqual(10, publisher.identifier, "should serialize to-one relationships")
                XCTAssertEqual("DC Comics", publisher.name!, "should serialize to-one relationships")
            } else {
                XCTFail("should serialize to-one relationships: \(batman)")
            }
        } else {
            XCTFail("serialization failed with error: \(error)")
        }
    }
    
    func testInsertInvalidToOneRelationship() {
        let batmanJSON: JSONObject = [
            "id": "1699",
            "name": "Batman",
            "real_name": "Bruce Wayne",
            "publisher": "DC"   // This should be a JSON dictionary
        ]
        
        var error: NSError? = nil
        let batman: Character? = importJSONObject(batmanJSON, inContext: context!, mergeChanges: false, error: &error)
        
        XCTAssertNil(batman, "should return nil on error")
        XCTAssertNotNil(error, "should return an error")
        
        XCTAssertEqual(Groot.errorDomain, error!.domain, "should return a Groot error")
        XCTAssertEqual(Groot.Error.InvalidJSONObject.rawValue, error!.code, "should return an invalid JSON error")
    }
    
    func testInsertInvalidToManyRelationship() {
        let batmanJSON: JSONObject = [
            "id": "1699",
            "name": "Batman",
            "real_name": "Bruce Wayne",
            "powers": [ // This should be a JSON array
                "id": "4",
                "name": "Agility"
            ]
        ]
        
        var error: NSError? = nil
        let batman: Character? = importJSONObject(batmanJSON, inContext: context!, mergeChanges: false, error: &error)
        
        XCTAssertNil(batman, "should return nil on error")
        XCTAssertNotNil(error, "should return an error")
        
        XCTAssertEqual(Groot.errorDomain, error!.domain, "should return a Groot error")
        XCTAssertEqual(Groot.Error.InvalidJSONObject.rawValue, error!.code, "should return an invalid JSON error")
    }
    
    func testMergeObject() {
        let batmanJSON: JSONObject = [
            "name": "Batman",
            "real_name": "Bruce Wayne",
            "id": "1699",
            "powers": [
                [
                    "id": "4",
                    "name": "Agility"
                ],
                NSNull(),
                [
                    "id": "9",
                    "name": "Insanely Rich"
                ]
            ],
            "publisher": [
                "id": "10",
                "name": "DC Comics"
            ]
        ]
        
        var error: NSError? = nil
        let batman = Character.fromJSONObject(batmanJSON, inContext: context!, mergeChanges: true, error: &error)
        
        XCTAssertNil(error)
        XCTAssertNotNil(batman)
        
        let updateJSON: JSONArray = [
            [
                "id": "1699",
                "real_name": NSNull(),  // Should reset Batman real name
                "publisher" : [
                    "id": "10",
                    "name": "DC Comics"   // Should update the publisher name
                ]
            ],
            [
                "id": "1455",
                "name": "Iron Man",
                "real_name": "Tony Stark",
                "powers": [
                    [
                        "id": "31",
                        "name": "Power Suit"
                    ],
                    [
                        "id": "9",
                        "name": "Filthy Rich" // Should update the 'Rich' power name
                    ]
                ]
            ]
        ]
        
        let characters: [Character]? = importJSONArray(updateJSON, inContext: context!, mergeChanges: true, error: &error)
        
        XCTAssertNil(error)
        XCTAssertNotNil(characters)
        
        XCTAssertEqual(2, characters!.count)
        
        let updatedBatman = characters![0]
        
        XCTAssertEqual("Batman", updatedBatman.name!)
        XCTAssertEqual(1699, updatedBatman.identifier)
        XCTAssertNil(updatedBatman.realName, "should update explicit null values")
        
        let agility = updatedBatman.powers![0] as! Power
        
        XCTAssertEqual(4, agility.identifier)
        XCTAssertEqual("Agility", agility.name!)
        
        let batmanRich = updatedBatman.powers![1] as! Power
        
        XCTAssertEqual(9, batmanRich.identifier, "should serialize to-many relationships")
        XCTAssertEqual("Filthy Rich", batmanRich.name!, "should serialize to-many relationships")
        
        XCTAssertEqual(10, updatedBatman.publisher!.identifier);
        XCTAssertEqual("DC Comics", updatedBatman.publisher!.name!)
        
        let ironMan = characters![1]
        
        XCTAssertEqual("Iron Man", ironMan.name!)
        XCTAssertEqual(1455, ironMan.identifier)
        XCTAssertEqual("Tony Stark", ironMan.realName!, "should serialize attributes")
        
        let powerSuit = ironMan.powers![0] as! Power
        
        XCTAssertEqual(31, powerSuit.identifier)
        XCTAssertEqual("Power Suit", powerSuit.name!)
        
        let ironManRich = ironMan.powers![1] as! Power
        
        XCTAssertEqual(9, ironManRich.identifier)
        XCTAssertEqual("Filthy Rich", ironManRich.name!)
        
        XCTAssert(batmanRich === ironManRich, "should properly merge relationships")
    }
    
    func testMergeWithoutIdentityAttribute() {
        let entities = self.store!.managedObjectModel.entitiesByName as! [String: NSEntityDescription]
        let powerEntity = entities["Power"]!
        powerEntity.userInfo = [:] // Remove the identity attribute name from the entity
        
        let batmanJSON: JSONObject = [
            "name": "Batman",
            "real_name": "Bruce Wayne",
            "id": "1699",
            "powers": [
                [
                    "id": "4",
                    "name": "Agility"
                ]
            ]
        ]
        
        var error: NSError? = nil
        let batman = Character.fromJSONObject(batmanJSON, inContext: context!, mergeChanges: true, error: &error)
        
        XCTAssertNil(batman)
        XCTAssertNotNil(error)
        
        XCTAssertEqual(Groot.errorDomain, error!.domain, "should return a Groot error")
        XCTAssertEqual(Groot.Error.IdentityNotFound.rawValue, error!.code, "should return an identity not found error")
    }
}
