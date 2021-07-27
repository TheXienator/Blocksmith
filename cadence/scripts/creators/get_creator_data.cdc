import Blocksmith from "../../contracts/Blocksmith.cdc"

// This script returns the Creator struct for a given ID.

pub fun main(creatorID: UInt32): Blocksmith.Creator? {
    return Blocksmith.getCreator(creatorID: creatorID)
}