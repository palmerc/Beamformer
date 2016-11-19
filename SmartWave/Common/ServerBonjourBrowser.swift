import UIKit



class ServerBonjourBrowser: NSObject, NSNetServiceDelegate, NSNetServiceBrowserDelegate
{
    var browser: NSNetServiceBrowser!
    var services: [NSNetService]?
    var updateCallback: (() -> ())?

    override init() {
        super.init()

        let browser = NSNetServiceBrowser()
        browser.delegate = self
        browser.searchForServicesOfType("_verasonics-ws._tcp", inDomain: "")
        self.browser = browser
    }

    func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool)
    {
        var newServices = [NSNetService]()
        if let services = self.services {
            newServices.appendContentsOf(services)
        }

        service.delegate = self
        service.resolveWithTimeout(0.0)
        newServices.append(service)

        self.services = newServices
        if moreComing == false {
            if let updateCallback = self.updateCallback {
                updateCallback()
            }
        }
    }

    func netServiceBrowser(browser: NSNetServiceBrowser, didRemoveService service: NSNetService, moreComing: Bool)
    {
        self.services = self.services?.filter({
            (aService: NSNetService) -> Bool in
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

    func netServiceDidResolveAddress(service: NSNetService)
    {
        if let updateCallback = self.updateCallback {
            updateCallback()
        }
    }

    func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber])
    {
        print("Error: \(errorDict)")
    }
}