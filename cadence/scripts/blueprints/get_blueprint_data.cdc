import Blocksmith from "../../contracts/Blocksmith.cdc"

// This script returns the Blueprint struct for an NFT in an account's collection.

pub fun main(creatorID: UInt32, blueprintID: UInt32): {String: String} {
    return Blocksmith.getBlueprintMetaData(creatorID: creatorID, blueprintID: blueprintID) 
        ?? {"error": "Blueprint doesn't exist"}
}
