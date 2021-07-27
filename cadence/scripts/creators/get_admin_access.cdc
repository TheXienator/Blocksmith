import Blocksmith from 0xBlocksmith

// This script returns the Creator Admin Access for an address
pub fun main(address: Address): {UInt32: Bool} {
  let admin = getAccount(address)
  let adminRef = admin.getCapability(Blocksmith.AdminPublicPath).borrow<&{Blocksmith.AdminPublic}>()!

  return adminRef.getCreatorAccess()
}