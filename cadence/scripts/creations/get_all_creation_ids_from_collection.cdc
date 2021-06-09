import Blocksmith from "../../contracts/Blocksmith.cdc"

// This script returns an array of all the NFT IDs in an account's collection.

pub fun main(address: Address): [UInt64] {
    let account = getAccount(address)

    let collectionRef = account.getCapability(Blocksmith.CollectionPublicPath)
        .borrow<&{Blocksmith.CreationCollectionPublic}>()
        ?? panic("Could not borrow capability from public collection")
    
    return collectionRef.getIDs()
}
