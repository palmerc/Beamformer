import Foundation


enum SerializationError: Error {
    case missing(String)
    case invalid(String, Any)
}

enum DatasetType: String {
    case protobuf
    case json
}

struct Dataset: Hashable {
    var type: DatasetType
    var name: String
    var settings: URL
    var frames: [URL]
    
    var hashValue: Int {
        return name.hashValue
    }
}

func ==(lhs: Dataset, rhs: Dataset) -> Bool {
    return lhs.name == rhs.name
}
//{
//    "type": "protobuf",
//    "name": "Phantom Cyst",
//    "settings": "Settings",
//    "frames": ["Frame01"]
//}

let kDatasetJSONKeyType = "type"
let kDatasetJSONKeyName = "name"
let kDatasetJSONKeySettings = "settings"
let kDatasetJSONKeyFrames = "frames"

extension Dataset {
    init(json: [String: Any], directory: URL?) throws {
        guard let typeJSON = json[kDatasetJSONKeyType] as? String else {
            throw SerializationError.missing(kDatasetJSONKeyType)
        }
        guard let type = DatasetType(rawValue: typeJSON) else {
            throw SerializationError.missing(kDatasetJSONKeyType)
        }
        
        // Extract name
        guard let name = json[kDatasetJSONKeyName] as? String else {
            throw SerializationError.missing(kDatasetJSONKeyName)
        }
        
        guard let settingsName = json[kDatasetJSONKeySettings] as? String else {
            throw SerializationError.missing(kDatasetJSONKeySettings)
        }
        guard let settings = directory?.appendingPathComponent(settingsName) else {
            throw SerializationError.missing(kDatasetJSONKeySettings)
        }
        
        // Extract and validate meals
        guard let framesNames = json[kDatasetJSONKeyFrames] as? [String] else {
            throw SerializationError.missing(kDatasetJSONKeyFrames)
        }
        
        var frames = [URL]()
        for frameName in framesNames {
            guard let frame = directory?.appendingPathComponent(frameName) else {
                throw SerializationError.missing(kDatasetJSONKeyFrames)
            }
            frames.append(frame)
        }
        
        // Initialize properties
        self.name = name
        self.type = type
        self.settings = settings
        self.frames = frames
    }
}
