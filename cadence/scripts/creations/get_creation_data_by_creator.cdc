import Blocksmith from "../../contracts/Blocksmith.cdc"

// This script returns the CreationData for an NFT in an account's collection.

pub fun main(address: Address, creatorID: UInt32, creationID: UInt32): Blocksmith.CreationData {

    // get the public account object for the token owner
    let owner = getAccount(address)

    let collectionBorrow = owner.getCapability(Blocksmith.CollectionPublicPath)
        .borrow<&{Blocksmith.CreationCollectionPublic}>()
        ?? panic("Could not borrow CreationCollectionPublic")

    // borrow a reference to a specific NFT in the collection
    let creation = collectionBorrow.borrowCreatorCreation(creatorID: creatorID, creationID: creationID)
        ?? panic("No such creator/creation combination in that collection")

    return creation.data
}
