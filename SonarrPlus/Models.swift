import Foundation

// Helper for dynamic decoding
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int? { return nil }

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

struct Show: Identifiable, Codable {
    let id: Int
    let title: String
    let sortTitle: String
    let status: String
    let ended: Bool
    let overview: String?
    let network: String?
    let airTime: String?
    let year: Int?
    let runtime: Int?
    let firstAired: String?
    let nextAiring: String?
    let previousAiring: String?
    var monitored: Bool
    let genres: [String]?
    let ratings: Ratings?
    let seasons: [Season]?
    let images: [Image]?
    var notificationsEnabled: Bool? // Optional for decoding safety
    var cleanTitle: String?
    var path: String?
    var qualityProfileId: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case sortTitle
        case status
        case ended
        case overview
        case network
        case airTime
        case year
        case runtime
        case firstAired
        case nextAiring
        case previousAiring
        case monitored
        case genres
        case ratings
        case seasons
        case images
        case notificationsEnabled
        case cleanTitle
        case path
        case qualityProfileId
    }
}


struct Ratings: Codable {
    let votes: Int
    let value: Double
}

struct Season: Identifiable, Codable {
    var id: Int { seasonNumber } // Use `seasonNumber` as the unique ID
    let seasonNumber: Int
    let monitored: Bool
    let statistics: Statistics?

    enum CodingKeys: String, CodingKey {
        case seasonNumber
        case monitored
        case statistics
    }
}

struct Statistics: Codable {
    let episodeFileCount: Int
    let episodeCount: Int
    let totalEpisodeCount: Int
    let sizeOnDisk: Int
    let releaseGroups: [String]
    let percentOfEpisodes: Double?
}

struct Image: Codable {
    let coverType: String
    let url: String
    let remoteUrl: String
}

struct Episode: Identifiable, Codable {
    let id: Int
    let title: String
    let seasonNumber: Int
    let episodeNumber: Int
    let airDate: String?
    let monitored: Bool
    let hasFile: Bool
    var showTitle: String? // Add this property

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case seasonNumber
        case episodeNumber
        case airDate
        case monitored
        case hasFile
    }
}

struct RootFolder: Codable {
    let id: Int
    let path: String
    let freeSpace: Int64 // Optional: Includes free space information in bytes
}

struct DiscoverResponse: Codable {
    let results: [DiscoverShow]
}

struct DiscoverShow: Codable, Identifiable {
    let id: Int
    let name: String
    let title: String?
    let overview: String?
    let posterPath: String? // Add this property
    let posterUrl: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let tvdbId: Int? // Add this property for TvdbId
    var rootFolderPath: String?
    var images: [Image]?
    var ratings: Ratings?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case title
        case overview
        case posterPath = "poster_path" // Map JSON key to camelCase
        case firstAirDate
        case voteAverage
        case tvdbId = "tvdb_id" // Map the JSON key to tvdbId
        case images
        case ratings
    }
    
    enum ImageKeys: String, CodingKey {
        case coverType
        case remoteUrl
    }

    enum RatingsKeys: String, CodingKey {
        case value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idVal = try? container.decodeIfPresent(Int.self, forKey: .id) {
            id = idVal
        } else if let tvdbId = try? container.decodeIfPresent(Int.self, forKey: .tvdbId) {
            id = tvdbId
        } else {
            let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
            if let fallbackId = try? dynamicContainer.decode(Int.self, forKey: DynamicCodingKeys(stringValue: "tvdbId")!) {
                id = fallbackId
            } else {
                throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Neither 'tvdbId' nor 'tvdb_id' could be decoded.")
            }
        } // Use -1 as a fallback for missing ids
        // Handle name or title mapping
        if let nameValue = try? container.decode(String.self, forKey: .name) {
            name = nameValue
        } else if let titleValue = try? container.decode(String.self, forKey: .title) {
            name = titleValue
        } else {
            name = "Unknown"
            throw DecodingError.dataCorruptedError(forKey: .name, in: container, debugDescription: "Neither 'name' nor 'title' could be decoded.")
        }
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        firstAirDate = try container.decodeIfPresent(String.self, forKey: .firstAirDate)

        // Extract posterPath from images
        if let posterPathVal = try container.decodeIfPresent(String.self, forKey: .posterPath) {
            posterPath = posterPathVal
        } else {
            posterPath = nil
        }
        
        if let images = try container.decodeIfPresent([Image].self, forKey: .images) {
            posterUrl = images.first(where: { $0.coverType == "poster" })?.remoteUrl
        } else {
            posterUrl = nil
        }
        
        print("here 2", posterPath)

        // Extract voteAverage from ratings
        if let ratings = try container.decodeIfPresent([String: Double].self, forKey: .ratings) {
            voteAverage = ratings["value"]
        } else {
            voteAverage = nil
        }
        title = name
        tvdbId = try container.decodeIfPresent(Int.self, forKey: .id) ?? -1 // Use -1 as a fallback for missing ids
    }

    struct Image: Codable {
        let coverType: String
        let remoteUrl: String
    }
}

extension DiscoverShow {
    func toSonarrModel(rootFolderPath: String) -> ShowToAdd {
        guard let tvdbId = self.tvdbId, tvdbId > 0 else {
            fatalError("Invalid TvdbId. TvdbId must be greater than 0.")
        }

        return ShowToAdd(
            title: self.name,
            qualityProfileId: nil, // To be filled later
            monitored: true,
            path: "\(rootFolderPath)/\(self.name)", // Combine root folder and show name
            rootFolderPath: rootFolderPath,
            tvdbId: tvdbId,
            addOptions: nil // To be filled later
        )
    }
}


extension DiscoverShow {
    func withTvdbId(_ tvdbId: Int) -> DiscoverShow {
        return DiscoverShow(
            id: self.id,
            name: self.name,
            overview: self.overview,
            posterPath: self.posterPath,
            firstAirDate: self.firstAirDate,
            voteAverage: self.voteAverage,
            tvdbId: tvdbId // Update tvdbId here
        )
    }
}

extension DiscoverShow {
    init(id: Int, name: String, overview: String?, posterPath: String?, firstAirDate: String?, voteAverage: Double?, tvdbId: Int?) {
        self.id = id
        self.name = name
        self.overview = overview
        self.posterPath = posterPath
        self.firstAirDate = firstAirDate
        self.voteAverage = voteAverage
        self.tvdbId = tvdbId
        self.title = name
        self.posterUrl = nil
    }
}

struct AddOptions: Codable {
    let searchForMissingEpisodes: Bool
}

struct ShowToAdd: Codable {
    let title: String
    var qualityProfileId: Int?
    var monitored: Bool
    var path: String
    var rootFolderPath: String
    let tvdbId: Int? // Add this property for TvdbId
    var addOptions: AddOptions?
}

struct SonarrStats: Decodable {
    let totalShows: Int?
    let totalEpisodes: Int?
    let diskSpaceUsed: Double?
    let diskSpaceFree: Double?
}

struct Series: Decodable {
    let id: Int
    let title: String
}

struct DiskSpace: Decodable {
    let path: String
    let label: String
    let freeSpace: Double
    let totalSpace: Double

    var usedSpace: Double {
        totalSpace - freeSpace
    }
}

struct History: Decodable {
    let records: [HistoryRecord]
}

struct HistoryRecord: Decodable {
    let eventType: String
}

struct DownloadItem: Decodable, Identifiable {
    let id: Int
    let title: String
    let size: Double // Total size in bytes
    let sizeleft: Double // Remaining size in bytes
    let status: String
    let timeleft: String
    let quality: Quality
    let estimatedCompletionTime: String

    struct Quality: Decodable {
        let quality: QualityDetail

        struct QualityDetail: Decodable {
            let name: String
            let resolution: Int
        }
    }
}

struct DownloadQueueResponse: Decodable {
    let records: [DownloadItem]
}
