import Blocksmith from "../../contracts/Blocksmith.cdc"

// This script returns the Blueprint struct for an NFT in an account's collection.

pub fun main(creatorID: UInt32, blueprintID: UInt32): {String: String} {
    
    let metadata = Blocksmith.getBlueprintMetaData(creatorID: creatorID, blueprintID: blueprintID) 
        ?? panic("Blueprint doesn't exist")

    return metadata
}
