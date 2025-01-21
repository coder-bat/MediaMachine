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

protocol ShowType {}

struct Show: Identifiable, Codable, ShowType {
    let id: Int
    let name: String
    let overview: String?
    let posterPath: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let tvdbId: Int?
    let title: String?
    let sortTitle: String?
    let status: String?
    let ended: Bool?
    let network: String?
    let airTime: String?
    let year: Int?
    let runtime: Int?
    let firstAired: String? //
    let nextAiring: String?
    let previousAiring: String?
    var monitored: Bool?
    let genres: [String]?
    let ratings: Ratings?
    let seasons: [Season]?
    let images: [Image]?
    var notificationsEnabled: Bool?
    let cleanTitle: String?
    var path: String?
    var qualityProfileId: Int?
    let posterUrl: String? //
    var rootFolderPath: String?
    var tmdbId: Int?


    enum CodingKeys: String, CodingKey {
        case id //
        case title //
        case sortTitle
        case status
        case ended
        case overview //
        case network
        case airTime
        case year
        case runtime
        case firstAired //
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
        case name //
        case posterUrl //
        case rootFolderPath
        case posterPath = "poster_path" // Map JSON key to camelCase //
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average" //
        case tvdbId = "tvdb_id" // Map the JSON key to tvdbId //
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
        
        // Extract voteAverage from ratings
        if let ratings = try container.decodeIfPresent([String: Double].self, forKey: .ratings) {
            voteAverage = ratings["value"]
        } else {
            voteAverage = nil
        }
        title = name
        tvdbId = try container.decodeIfPresent(Int.self, forKey: .id) ?? -1 // Use -1 as a fallback for missing ids
        
        sortTitle = try container.decodeIfPresent(String.self, forKey: .sortTitle)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        
        ended = try container.decodeIfPresent(Bool.self, forKey: .ended)
        network = try container.decodeIfPresent(String.self, forKey: .network)
        airTime = try container.decodeIfPresent(String.self, forKey: .airTime)
        year = try container.decodeIfPresent(Int.self, forKey: .year)
        runtime = try container.decodeIfPresent(Int.self, forKey: .runtime)
        nextAiring = try container.decodeIfPresent(String.self, forKey: .nextAiring)
        
        previousAiring = try container.decodeIfPresent(String.self, forKey: .previousAiring)
        monitored = try container.decodeIfPresent(Bool.self, forKey: .monitored)
        genres = try container.decodeIfPresent([String].self, forKey: .genres)
        ratings = try container.decodeIfPresent(Ratings.self, forKey: .ratings)
        seasons = try container.decodeIfPresent([Season].self, forKey: .seasons)
        firstAired = try container.decodeIfPresent(String.self, forKey: .firstAired)
        images = try container.decodeIfPresent([Image].self, forKey: .images) ?? []
        
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled)
        cleanTitle = try container.decodeIfPresent(String.self, forKey: .cleanTitle)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        qualityProfileId = try container.decodeIfPresent(Int.self, forKey: .qualityProfileId)
        rootFolderPath = try container.decodeIfPresent(String.self, forKey: .rootFolderPath)
    }

}

extension Show {
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


extension Show {
    func withTvdbId(_ tvdbId: Int) -> Show {
        return Show(
            id: self.id,
            name: self.name,
            overview: self.overview,
            posterPath: self.posterPath,
            firstAirDate: self.firstAirDate,
            voteAverage: self.voteAverage,
            tvdbId: tvdbId,
            title: self.title,
            sortTitle: self.sortTitle,
            status: self.status,
            ended: self.ended,
            network: self.network,
            airTime: self.airTime,
            year: self.year,
            runtime: self.runtime,
            firstAired: self.firstAired, //
            nextAiring: self.nextAiring,
            previousAiring: self.previousAiring,
            monitored: self.monitored,
            genres: self.genres,
            ratings: self.ratings,
            seasons: self.seasons,
            images: self.images,
            notificationsEnabled: self.notificationsEnabled,
            cleanTitle: self.cleanTitle,
            path: self.path,
            qualityProfileId: self.qualityProfileId,
            posterUrl: self.posterUrl, //
            rootFolderPath: self.rootFolderPath

        )
    }
}

extension Show {
    init(
        id: Int,
        name: String,
        overview: String?,
        posterPath: String?,
        firstAirDate: String?,
        voteAverage: Double?,
        tvdbId: Int?,
        title: String?,
        sortTitle: String?,
        status: String?,
        ended: Bool?,
        network: String?,
        airTime: String?,
        year: Int?,
        runtime: Int?,
        firstAired: String?, //
        nextAiring: String?,
        previousAiring: String?,
        monitored: Bool?,
        genres: [String]?,
        ratings: Ratings?,
        seasons: [Season]?,
        images: [Image]?,
        notificationsEnabled: Bool?,
        cleanTitle: String?,
        path: String?,
        qualityProfileId: Int?,
        posterUrl: String?, //
        rootFolderPath: String?

    ) {
        self.id = id
        self.name = name
        self.overview = overview
        self.posterPath = posterPath
        self.firstAirDate = firstAirDate
        self.voteAverage = voteAverage
        self.tvdbId = tvdbId
        self.title = title
        self.sortTitle = sortTitle
        self.status = status
        self.ended = ended
        self.network = network
        self.airTime = airTime
        self.year = year
        self.runtime = runtime
        self.firstAired = firstAired
        self.nextAiring = nextAiring
        self.previousAiring = previousAiring
        self.monitored = monitored
        self.genres = genres
        self.ratings = ratings
        self.seasons = seasons
        self.images = images
        self.notificationsEnabled = notificationsEnabled
        self.cleanTitle = cleanTitle
        self.path = path
        self.qualityProfileId = qualityProfileId
        self.posterUrl = posterUrl //
       self.rootFolderPath = rootFolderPath
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
    let results: [Show]
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
    let disks: [DiskSpace]
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
