import Foundation


extension NSNetService
{
    func humanReadableIPAddresses() -> [String]?
    {
        guard let addresses = self.addresses else {
            return nil
        }

        var humanReadableIPAddresses = [String]()
        for address in addresses {
            var socketAddressStorage = sockaddr_storage()
            address.getBytes(&socketAddressStorage, length: sizeof(sockaddr_storage))
            if Int32(socketAddressStorage.ss_family) == AF_INET {
                let addr4 = withUnsafePointer(&socketAddressStorage) { UnsafePointer<sockaddr_in>($0).memory }
                if let addressString = String(CString: inet_ntoa(addr4.sin_addr), encoding: NSASCIIStringEncoding) {
                    humanReadableIPAddresses.append(addressString)
                }
            }
        }

        return humanReadableIPAddresses
    }
}