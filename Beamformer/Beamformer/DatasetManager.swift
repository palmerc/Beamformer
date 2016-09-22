import Foundation


struct Dataset {
    var name: String
    var fileURLs: [NSURL]
}



let kDatasetsDirectory = "no.ntnu.dmf.isb.Datasets"
let kDefaultDatasetName = "Default"
let kWebSocketFileExtension = "ws"

class DatasetManager
{
    private static var sharedInstance = DatasetManager()
    private var datasets: [Dataset]?
    private var frameCache: NSCache
    private var dataCache: NSCache



    static func defaultManager() -> DatasetManager
    {
        return sharedInstance
    }

    func defaultDataset() -> Dataset?
    {
        var result: Dataset?
        if let datasets = self.datasets {
            for dataset in datasets {
                if dataset.name == kDefaultDatasetName {
                    result = dataset
                }
            }
        }

        return result
    }

    func cachedVerasonicsFrameWithURL(URL: NSURL) -> VerasonicsFrame?
    {
        var verasonicsFrame = self.frameCache.objectForKey(URL) as? VerasonicsFrame
        if verasonicsFrame == nil {
            let data = self.cachedDataWithURL(URL)
            if let data = data {
                let frame = VerasonicsFrameJSON(JSONData: data)
                self.frameCache.setObject(frame, forKey: URL)
                verasonicsFrame = frame
            }
        }

        return verasonicsFrame
    }

    func cachedDataWithURL(URL: NSURL) -> NSData?
    {
        var data = self.dataCache.objectForKey(URL) as? NSData
        if data == nil {
            let newData = NSData(contentsOfURL: URL)
            if let newData = newData {
                self.dataCache.setObject(newData, forKey: URL)
                data = newData
            }
        }

        return data
    }

    private init()
    {
        self.dataCache = NSCache()
        self.dataCache.removeAllObjects()
        self.frameCache = NSCache()
        self.frameCache.removeAllObjects()
        self.copyDefaultDatasetsToDocumentsDirectory()
        self.loadDatasets()
    }

    private func loadDatasets()
    {
        let fileManager = NSFileManager.defaultManager()
        if let datasetDirectory = self.datasetDirectory() {
            do {
            let subURLs = try fileManager.contentsOfDirectoryAtURL(datasetDirectory, includingPropertiesForKeys: nil, options: .SkipsHiddenFiles)
                let directories = subURLs.filter({ (aURL: NSURL) -> Bool in
                    var result = false
                    if let path = aURL.path {
                        var isDirectory = ObjCBool(true)
                        if fileManager.fileExistsAtPath(path, isDirectory: &isDirectory) {
                            result = true
                        }
                    }

                    return result
                })

                var datasets = [Dataset]()
                for directory in directories {
                    if let datasetName = directory.lastPathComponent {
                        if let fileURLs = self.filesMatchingExtension(kWebSocketFileExtension, inDirectory: directory) {
                            let dataset = Dataset(name: datasetName, fileURLs: fileURLs)
                            datasets.append(dataset)
                        }
                    }
                }

                if datasets.count > 0 {
                    self.datasets = datasets
                }
            } catch let error as NSError {
                print("\(error.localizedDescription)")
            }
        }
    }

    private func copyDefaultDatasetsToDocumentsDirectory()
    {
        let mainBundle = NSBundle.mainBundle()
        let bundleWebSocketFileURLs = mainBundle.URLsForResourcesWithExtension(kWebSocketFileExtension, subdirectory: nil)
        if let webSocketFileURLs = bundleWebSocketFileURLs, documentsDirectory = DatasetManager.documentsDirectory() {
            let datasetsDirectory = documentsDirectory.URLByAppendingPathComponent(kDatasetsDirectory)
            let defaultDatasetDirectory = datasetsDirectory!.URLByAppendingPathComponent(kDefaultDatasetName)
            self.createDirectory(defaultDatasetDirectory!)
            self.copyFilesToDirectory(webSocketFileURLs, toDestinationDirectory: defaultDatasetDirectory!)
        }
    }

    private func createDirectory(directoryURL: NSURL)
    {
        if let directoryPath = directoryURL.path {
            let fileManager = NSFileManager.defaultManager()
            if fileManager.fileExistsAtPath(directoryPath) == false {
                do {
                    try fileManager.createDirectoryAtURL(directoryURL, withIntermediateDirectories: true, attributes: nil)
                    print("Created directory \(directoryPath)")
                } catch let error as NSError {
                    print("Unable to create \(directoryPath) - \(error.localizedDescription)")
                }
            }
        }
    }

    private func copyFilesToDirectory(fileURLs: [NSURL], toDestinationDirectory destinationDirectory: NSURL)
    {
        for fileURL in fileURLs {
            let fileManager = NSFileManager.defaultManager()

            if let filename = fileURL.lastPathComponent, filePath = fileURL.path {
                let destinationURL = destinationDirectory.URLByAppendingPathComponent(filename)
                if let destinationPath = destinationURL!.path {
                    if fileManager.contentsEqualAtPath(filePath, andPath: destinationPath) == false {
                        do {
                            try fileManager.removeItemAtURL(destinationURL!)
                        } catch let error as NSError {
                            print("Unable to delete \(fileURL) - \(error.localizedDescription)")
                        }

                        do {
                            try fileManager.copyItemAtURL(fileURL, toURL: destinationURL!)
                            print("Copied file \(filename) in \(destinationDirectory) directory")
                        } catch let error as NSError {
                            print("Unable to copy \(fileURL) - \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    static func documentsDirectory() -> NSURL?
    {
        var documentsDirectory: NSURL?
        if let directory: NSString = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first {
            documentsDirectory = NSURL.init(fileURLWithPath: directory as String, isDirectory: true)
        }

        return documentsDirectory
    }

    private func datasetDirectory() -> NSURL?
    {
        var datasetDirectory: NSURL?
        if let documentsDirectory = DatasetManager.documentsDirectory() {
            datasetDirectory = documentsDirectory.URLByAppendingPathComponent(kDatasetsDirectory)
        }

        return datasetDirectory
    }

    private func filesMatchingExtension(fileExtension: String, inDirectory directory: NSURL) -> [NSURL]?
    {
        var fileURLs: [NSURL]?
        do {
            let files = try NSFileManager.defaultManager().contentsOfDirectoryAtURL(directory, includingPropertiesForKeys: nil, options: NSDirectoryEnumerationOptions.init(rawValue: 0))
            var matchingFiles = [NSURL]()
            for file in files {
                let pathExtension = file.pathExtension
                if pathExtension == fileExtension {
                    matchingFiles.append(file)
                }
            }
            matchingFiles.sortInPlace({
                (lhs: NSURL, rhs: NSURL) -> Bool in
                let leftHandPath = lhs.absoluteString
                let rightHandPath = rhs.absoluteString
                let options = NSStringCompareOptions.CaseInsensitiveSearch.union(.NumericSearch)
                return leftHandPath!.compare(rightHandPath!, options: options) == NSComparisonResult.OrderedAscending
            })
            if matchingFiles.count > 0 {
                fileURLs = matchingFiles
            }
        } catch let error as NSError {
            print("\(error.localizedDescription)")
        }

        return fileURLs
    }

}
