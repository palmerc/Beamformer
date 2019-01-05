import Foundation
import Zip



let kDatasetsDirectory = "no.uio.ifi.smartwave.Datasets"
let kDatasetsCatalog = "datasets"
let kDatasetsJSONKeyDatasets = "datasets"
let kZipFileExtension = "zip"

class DatasetManager
{
    fileprivate static var sharedInstance = DatasetManager()
    fileprivate var datasets: Dictionary<String, Dataset>?
    fileprivate var dataCache: NSCache<AnyObject, AnyObject>

    static func defaultManager() -> DatasetManager
    {
        return sharedInstance
    }
    
    func defaultDataset() -> Dataset?
    {
        guard let datasetName = self.datasets?.keys.first else {
            print("No datasets available.")
            return nil
        }
        
        return self.datasets?[datasetName]
    }

    func dataset(named: String) -> Dataset?
    {
        guard let dataset = self.datasets?[named] else {
            print("No dataset by the name '\(named)'.")
            return nil
        }
        return dataset
    }
    
    func cachedDataWithURL(_ URL: Foundation.URL) -> Data?
    {
        var data = self.dataCache.object(forKey: URL as AnyObject) as? Data
        if data == nil {
            let newData = try? Data(contentsOf: URL)
            if let newData = newData {
                self.dataCache.setObject(newData as AnyObject, forKey: URL as AnyObject)
                data = newData
            }
        }

        return data
    }

    fileprivate init()
    {
        self.dataCache = NSCache()
        self.dataCache.removeAllObjects()
        self.unzipDatasets()
        self.loadDatasets()
    }
    
    fileprivate func unzipDatasets()
    {
        guard let catalogURL = Bundle.main.url(forResource: kDatasetsCatalog, withExtension: "json") else {
            print("Dataset catalog not found.")
            return
        }
        
        do {
            let data = try Data(contentsOf: catalogURL)
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                let datasets = json[kDatasetsJSONKeyDatasets] as? [NSString] {
                for dataset in datasets {
                    let resourceName = dataset.deletingPathExtension
                    let resourceExtension = dataset.pathExtension
                    let datasetURL = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
                    let destinationURL = self.datasetDirectory()?.appendingPathComponent(dataset as String, isDirectory: true)
                    
                    try Zip.unzipFile(datasetURL!, destination: destinationURL!, overwrite: true, password: nil, progress: nil)
                }
            }
        } catch let error {
            print("Failed to unzip bundled datasets -  \(error.localizedDescription)")
        }
        
    }

    fileprivate func loadDatasets()
    {
        let fileManager = FileManager.default
        if let datasetDirectory = self.datasetDirectory() {
            do {
                let subURLs = try fileManager.contentsOfDirectory(at: datasetDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                let directories = subURLs.filter({ (aURL: URL) -> Bool in
                    var result = false
                    var isDirectory = ObjCBool(true)
                    if fileManager.fileExists(atPath: aURL.path, isDirectory: &isDirectory) {
                        result = true
                    }

                    return result
                })

                var datasets = Dictionary<String, Dataset>()
                for directory in directories {
                    let settingsURL = directory.appendingPathComponent("dataset.json")
                    guard let data = try? Data(contentsOf: settingsURL) else {
                        print("Unable to read JSON dataset description. - \(settingsURL)")
                        continue
                    }
                    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                        print("Unable to deserialize JSON dataset description.")
                        continue
                    }
                    guard let json = jsonObject as? [String: Any] else {
                        print("Unable to cast JSON object to JSON dictionary")
                        continue
                    }
                    guard let dataset = try? Dataset(json: json, directory: directory) else {
                        print("Unable to convert JSON to Dataset")
                        continue
                    }
                    
                    print("Adding Dataset '\(dataset.name)'")
                    datasets[dataset.name] = dataset
                }
                
                if datasets.count > 0 {
                    self.datasets = datasets
                }
            } catch let error as NSError {
                print("\(error.localizedDescription)")
            }
        }
    }

    fileprivate func copyDefaultDatasetsToDocumentsDirectory()
    {
//        let mainBundle = Bundle.main
        if let documentsDirectory = DatasetManager.documentsDirectory() {
            self.createDirectory(documentsDirectory)
        }
        
//        let bundleWebSocketFileURLs = mainBundle.urls(forResourcesWithExtension: kProtobufFileExtension, subdirectory: nil)
//        if let webSocketFileURLs = bundleWebSocketFileURLs, let documentsDirectory = DatasetManager.documentsDirectory() {
//            let datasetsDirectory = documentsDirectory.appendingPathComponent(kDatasetsDirectory)
//            let defaultDatasetDirectory = datasetsDirectory.appendingPathComponent(kDefaultDatasetName)
//            self.createDirectory(defaultDatasetDirectory)
//            self.copyFilesToDirectory(webSocketFileURLs, toDestinationDirectory: defaultDatasetDirectory)
//        }
    }
    
    
    // MARK: File and directory methods
    fileprivate func createDirectory(_ directoryURL: URL)
    {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: directoryURL.path) == false {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
                print("Created directory \(directoryURL.path)")
            } catch let error as NSError {
                print("Unable to create \(directoryURL.path) - \(error.localizedDescription)")
            }
        }
    }

    fileprivate func copyFilesToDirectory(_ fileURLs: [URL], toDestinationDirectory destinationDirectory: URL)
    {
        for fileURL in fileURLs {
            let fileManager = FileManager.default

            let destinationURL = destinationDirectory.appendingPathComponent(fileURL.lastPathComponent)
            if fileManager.contentsEqual(atPath: fileURL.path, andPath: destinationURL.path) == false {
                do {
                    try fileManager.removeItem(at: destinationURL)
                } catch let error as NSError {
                    print("Unable to delete \(fileURL) - \(error.localizedDescription)")
                }

                do {
                    try fileManager.copyItem(at: fileURL, to: destinationURL)
                    print("Copied file \(fileURL.lastPathComponent) in \(destinationDirectory) directory")
                } catch let error as NSError {
                    print("Unable to copy \(fileURL) - \(error.localizedDescription)")
                }
            }
        }
    }

    static func documentsDirectory() -> URL?
    {
        var documentsDirectory: URL?
        if let directory: NSString = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first as NSString? {
            documentsDirectory = URL.init(fileURLWithPath: directory as String, isDirectory: true)
        }

        return documentsDirectory
    }

    fileprivate func datasetDirectory() -> URL?
    {
        var datasetDirectory: URL?
        if let documentsDirectory = DatasetManager.documentsDirectory() {
            datasetDirectory = documentsDirectory.appendingPathComponent(kDatasetsDirectory)
        }

        return datasetDirectory
    }

    fileprivate func filesMatchingExtension(_ fileExtension: String, inDirectory directory: URL) -> [URL]?
    {
        var fileURLs: [URL]?
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil, options: FileManager.DirectoryEnumerationOptions.init(rawValue: 0))
            var matchingFiles = [URL]()
            for file in files {
                let pathExtension = file.pathExtension
                if pathExtension == fileExtension {
                    matchingFiles.append(file)
                }
            }
            matchingFiles.sort(by: {
                (lhs: URL, rhs: URL) -> Bool in
                let leftHandPath = lhs.absoluteString
                let rightHandPath = rhs.absoluteString
                let options = NSString.CompareOptions.caseInsensitive.union(.numeric)
                return leftHandPath.compare(rightHandPath, options: options) == ComparisonResult.orderedAscending
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
