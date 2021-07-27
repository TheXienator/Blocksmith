import Blocksmith from "../../contracts/Blocksmith.cdc"

// This script returns the Blueprints struct given a creatorID

pub fun main(creatorID: UInt32): [Blocksmith.Blueprint] {
    return Blocksmith.getBlueprints(creatorID: creatorID)
}
