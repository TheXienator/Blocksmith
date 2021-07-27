import Blocksmith from "../../contracts/Blocksmith.cdc"

// This script returns the Blueprint struct given a creatorID and blueprintID

pub fun main(creatorID: UInt32, blueprintID: UInt32): Blocksmith.Blueprint {
    return Blocksmith.getBlueprint(creatorID: creatorID, blueprintID: blueprintID) 
        ?? panic("Blueprint doesn't exist")
}
