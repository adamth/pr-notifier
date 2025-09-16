import Foundation

struct PullRequest: Codable {
    let id: Int
    let title: String
    let htmlURL: String
    let user: User
    let number: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, user, number
        case htmlURL = "html_url"
    }
    
    struct User: Codable {
        let login: String
    }
}

struct GitHubReviewRequest: Codable {
    let url: String
    let htmlURL: String
    let pullRequestURL: String
    
    enum CodingKeys: String, CodingKey {
        case url
        case htmlURL = "html_url"
        case pullRequestURL = "pull_request_url"
    }
}

enum GitHubError: Error, LocalizedError {
    case noToken
    case invalidURL
    case noData
    case decodingError(Error)
    case networkError(Error)
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .noToken:
            return "No GitHub token found. Configure it in Settings."
        case .invalidURL:
            return "Invalid GitHub API URL"
        case .noData:
            return "No data received from GitHub API"
        case .decodingError(let error):
            return "Failed to decode GitHub API response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let code):
            return "HTTP error \(code): \(httpErrorMessage(for: code))"
        }
    }
    
    private func httpErrorMessage(for code: Int) -> String {
        switch code {
        case 401:
            return "Unauthorized - check your GitHub token"
        case 403:
            return "Forbidden - token may lack required permissions"
        case 404:
            return "Not found - check API endpoint"
        case 422:
            return "Unprocessable entity - check search query"
        default:
            return "Unknown HTTP error"
        }
    }
}

class GitHubService {
    private let baseURL = "https://api.github.com"
    private var token: String? {
        GitHubTokenManager.shared.token
    }
    
    func fetchPendingReviews() async -> [PullRequest] {
        guard let token = token else {
            print("🚫 No GitHub token found - configure it in Settings")
            return []
        }
        
        print("🔗 Making GitHub API request to search for pending reviews...")
        
        guard let url = URL(string: "\(baseURL)/search/issues") else {
            print("❌ Invalid GitHub API URL")
            return []
        }

        // Search for PRs where the current user is requested as a reviewer
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: "type:pr state:open review-requested:@me"),
            URLQueryItem(name: "sort", value: "updated"),
            URLQueryItem(name: "order", value: "desc")
        ]

        guard let searchURL = components.url else {
            print("❌ Invalid search URL components")
            return []
        }
        
        var request = URLRequest(url: searchURL)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                print("📡 GitHub API response: HTTP \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("❌ HTTP Error \(httpResponse.statusCode): \(httpErrorMessage(for: httpResponse.statusCode))")
                    return []
                }
            }

            // Debug: print raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 Raw API response: \(jsonString.prefix(500))...")
            }

            let searchResult = try JSONDecoder().decode(GitHubSearchResult.self, from: data)
            print("📊 Decoded \(searchResult.items.count) pull requests from GitHub API")
            return searchResult.items

        } catch let decodingError as DecodingError {
            print("❌ Failed to decode GitHub API response: \(decodingError.localizedDescription)")
            return []
        } catch {
            print("❌ Network error connecting to GitHub: \(error.localizedDescription)")
            return []
        }
    }

    private func httpErrorMessage(for code: Int) -> String {
        switch code {
        case 401:
            return "Unauthorized - check your GitHub token"
        case 403:
            return "Forbidden - token may lack required permissions"
        case 404:
            return "Not found - check API endpoint"
        case 422:
            return "Unprocessable entity - check search query"
        default:
            return "Unknown HTTP error"
        }
    }
    
    // Throwing version for explicit connection testing (Settings UI)
    func getCurrentUser() async throws -> String {
        guard let token = token else {
            throw GitHubError.noToken
        }

        guard let url = URL(string: "\(baseURL)/user") else {
            throw GitHubError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 {
                    throw GitHubError.httpError(httpResponse.statusCode)
                }
            }

            let user = try JSONDecoder().decode(GitHubUser.self, from: data)
            return user.login

        } catch let decodingError as DecodingError {
            throw GitHubError.decodingError(decodingError)
        } catch let githubError as GitHubError {
            throw githubError
        } catch {
            throw GitHubError.networkError(error)
        }
    }
}

struct GitHubSearchResult: Codable {
    let items: [PullRequest]
}

struct GitHubUser: Codable {
    let login: String
}