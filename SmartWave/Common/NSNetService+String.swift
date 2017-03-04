import Foundation


extension NetService
{
    func humanReadableIPAddresses() -> [String]?
    {
        guard let addresses = self.addresses else {
            return nil
        }

        var humanReadableIPAddresses = [String]()
        for address in addresses {
            var socketAddressStorage = sockaddr_storage()
            (address as NSData).getBytes(&socketAddressStorage, length: MemoryLayout<sockaddr_storage>.size)
            if Int32(socketAddressStorage.ss_family) == AF_INET {
                let addr4 = withUnsafePointer(to: &socketAddressStorage) { UnsafeRawPointer($0).load(as: sockaddr_in.self) }
                if let addressString = String(cString: inet_ntoa(addr4.sin_addr), encoding: String.Encoding.ascii) {
                    humanReadableIPAddresses.append(addressString)
                }
            }
        }

        return humanReadableIPAddresses
    }
}
