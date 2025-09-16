import Foundation

struct PullRequest: Codable {
    let id: Int
    let title: String
    let htmlURL: String
    let user: User
    let number: Int
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?
    let reviewRequestCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, user, number, additions, deletions
        case htmlURL = "html_url"
        case changedFiles = "changed_files"
        case reviewRequestCount
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

            // Fetch detailed info for each PR to get line changes
            var detailedPRs: [PullRequest] = []
            for pr in searchResult.items {
                if let detailedPR = await fetchDetailedPR(pr: pr) {
                    detailedPRs.append(detailedPR)
                } else {
                    // If we can't get detailed info, use the original PR
                    detailedPRs.append(pr)
                }
            }

            return detailedPRs

        } catch let decodingError as DecodingError {
            print("❌ Failed to decode GitHub API response: \(decodingError.localizedDescription)")
            return []
        } catch {
            print("❌ Network error connecting to GitHub: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchDetailedPR(pr: PullRequest) async -> PullRequest? {
        guard let token = token else {
            return nil
        }

        // Extract repo info from the PR's HTML URL
        // URL format: https://github.com/owner/repo/pull/123
        let urlComponents = pr.htmlURL.components(separatedBy: "/")
        guard urlComponents.count >= 5,
              urlComponents[2] == "github.com",
              let owner = urlComponents.dropFirst(3).first,
              let repo = urlComponents.dropFirst(4).first else {
            print("❌ Could not parse repo info from URL: \(pr.htmlURL)")
            return nil
        }

        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/pulls/\(pr.number)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            var detailedPR = try JSONDecoder().decode(PullRequest.self, from: data)

            // Fetch review request count
            let reviewRequestCount = await fetchReviewRequestCount(owner: owner, repo: repo, prNumber: pr.number)

            // Create a new PR with the review request count
            detailedPR = PullRequest(
                id: detailedPR.id,
                title: detailedPR.title,
                htmlURL: detailedPR.htmlURL,
                user: detailedPR.user,
                number: detailedPR.number,
                additions: detailedPR.additions,
                deletions: detailedPR.deletions,
                changedFiles: detailedPR.changedFiles,
                reviewRequestCount: reviewRequestCount
            )

            print("📈 Fetched detailed info for PR #\(pr.number): +\(detailedPR.additions ?? 0)/-\(detailedPR.deletions ?? 0), requests: \(reviewRequestCount)")
            return detailedPR
        } catch {
            print("❌ Failed to fetch detailed PR info for #\(pr.number): \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchReviewRequestCount(owner: String, repo: String, prNumber: Int) async -> Int {
        guard let token = token else {
            return 1 // Default to 1 if we can't check
        }

        // Fetch current user to get our username
        guard let currentUser = await getCurrentUsername() else {
            return 1
        }

        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(repo)/issues/\(prNumber)/timeline") else {
            return 1
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let timeline = try JSONDecoder().decode([TimelineEvent].self, from: data)

            // Count review_requested events for the current user
            let requestCount = timeline.filter { event in
                event.event == "review_requested" &&
                event.requestedReviewer?.login == currentUser
            }.count

            return max(requestCount, 1) // At least 1 since we're currently requested
        } catch {
            print("❌ Failed to fetch timeline for PR #\(prNumber): \(error.localizedDescription)")
            return 1
        }
    }

    private func getCurrentUsername() async -> String? {
        guard let token = token else { return nil }

        guard let url = URL(string: "\(baseURL)/user") else { return nil }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let user = try JSONDecoder().decode(GitHubUser.self, from: data)
            return user.login
        } catch {
            return nil
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

struct TimelineEvent: Codable {
    let event: String
    let requestedReviewer: PullRequest.User?

    enum CodingKeys: String, CodingKey {
        case event
        case requestedReviewer = "requested_reviewer"
    }
}

struct GitHubUser: Codable {
    let login: String
}