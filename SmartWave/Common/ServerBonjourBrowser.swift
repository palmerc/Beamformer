import Foundation



class ServerBonjourBrowser: NSObject, NetServiceDelegate, NetServiceBrowserDelegate
{
    var browser: NetServiceBrowser!
    var services: [NetService]?
    var updateCallback: (() -> ())?

    override init() {
        super.init()

        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: "_smartwave-ws._tcp", inDomain: "")
        self.browser = browser
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool)
    {
        var newServices = [NetService]()
        if let services = self.services {
            newServices.append(contentsOf: services)
        }

        service.delegate = self
        service.resolve(withTimeout: 0.0)
        newServices.append(service)

        self.services = newServices
        if moreComing == false {
            if let updateCallback = self.updateCallback {
                updateCallback()
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool)
    {
        self.services = self.services?.filter({
            (aService: NetService) -> Bool in
            if aService == service {
                return false
            } else {
                return true
            }
        })

        if moreComing == false {
            if let updateCallback = self.updateCallback {
                updateCallback()
            }
        }
    }

    func netServiceDidResolveAddress(_ service: NetService)
    {
        if let updateCallback = self.updateCallback {
            updateCallback()
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String : NSNumber])
    {
        print("Error: \(errorDict)")
    }
}
