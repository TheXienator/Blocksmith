import Blocksmith from "../../contracts/Blocksmith.cdc"

// This script returns the Blueprint metadata given a creatorID and blueprintID

pub fun main(creatorID: UInt32, blueprintID: UInt32): {String: String} {
    return Blocksmith.getBlueprintMetaData(creatorID: creatorID, blueprintID: blueprintID) 
        ?? panic("Blueprint doesn't exist")
}
