import UIKit


let serverSelectionTableViewCellReuseIdentifier = "serverSelectionTableViewCellReuseIdentifier"
let unwindToUltrasoundViewControllerSegueIdentifer = "unwindToUltrasoundViewControllerSegueIdentifier"

protocol ServerSelectionDelegate
{
    func didSelectNetService(service: NSNetService?)
}

class ServerSelectionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource
{
    @IBOutlet var cancel: UIBarButtonItem!
    @IBOutlet var tableView: UITableView!
    var serverBonjourBrowser: ServerBonjourBrowser!
    var delegate: ServerSelectionDelegate?

    private var _selectedService: NSNetService?
    var selectedService: NSNetService? {
        get {
            return self._selectedService
        }
        set {
            let selectedService = newValue

            if selectedService == self._selectedService {
                self._selectedService = nil
            } else {
                self._selectedService = selectedService
            }

            if let delegate = self.delegate {
                delegate.didSelectNetService(self._selectedService)
            }

            if self.tableView != nil {
                NSTimer.scheduledTimerWithTimeInterval(0.2, target: self.tableView, selector: #selector(UITableView.reloadData), userInfo: nil, repeats: false)
            }
        }
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()

        let browser = ServerBonjourBrowser()
        browser.updateCallback = {
            self.tableView.reloadData()
        }
        self.serverBonjourBrowser = browser
    }

    func numberOfSectionsInTableView(tableView: UITableView) -> Int
    {
        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        var numberOfRowsInSection = 0
        if let services = self.serverBonjourBrowser.services {
            numberOfRowsInSection = services.count
        }

        return numberOfRowsInSection
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        var reusableCell = tableView.dequeueReusableCellWithIdentifier(serverSelectionTableViewCellReuseIdentifier)
        if reusableCell == nil {
            reusableCell = UITableViewCell(style: .Subtitle, reuseIdentifier: serverSelectionTableViewCellReuseIdentifier)
        }

        if let services = self.serverBonjourBrowser.services {
            let service = services[indexPath.row]
            reusableCell?.textLabel?.text = "\(service.name)"

            var detailText: String?
            let portText = "Port: \(service.port)"
            if let addresses = service.humanReadableIPAddresses() {
                detailText = addresses.joinWithSeparator(", ")
                detailText?.appendContentsOf(" - \(portText)")
            } else {
                detailText = portText
            }

            reusableCell?.detailTextLabel?.text = detailText

            var accessoryType = UITableViewCellAccessoryType.None
            if service == self.selectedService {
                accessoryType = .Checkmark
            }
            reusableCell?.accessoryType = accessoryType
        }

        return reusableCell!
    }

    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        if let services = self.serverBonjourBrowser.services {
            let service = services[indexPath.row]
            if service == self.selectedService {
                self.selectedService = nil
            } else if service.addresses?.count > 0 {
                self.selectedService = service
            }
        }
    }
}