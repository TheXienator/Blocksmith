import Blocksmith from "../../contracts/Blocksmith.cdc"

// This script returns the SetData struct for a set in an account's collection.

pub fun main(creatorID: UInt32, setID: UInt32): Blocksmith.SetData {
    
    let setData = Blocksmith.SetData(creatorID: creatorID, setID: setID)

    return setData
}
