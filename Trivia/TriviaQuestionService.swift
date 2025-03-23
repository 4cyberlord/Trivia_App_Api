//
//  TriviaQuestionService.swift
//  Trivia
//

import Foundation

class TriviaQuestionService {
    // API URL constants
    private let baseUrl = "https://opentdb.com/api.php"
    
    // Callback type for question fetching
    typealias QuestionFetchCompletion = (Result<[TriviaQuestion], Error>) -> Void
    
    // Custom errors
    enum TriviaServiceError: Error {
        case invalidURL
        case networkError(String)
        case noData
        case parsingError(String)
        case apiError(Int)
    }
    
    // Fetch questions from the API
    func fetchQuestions(amount: Int = 10, completion: @escaping QuestionFetchCompletion) {
        // Build URL with query parameters
        var urlComponents = URLComponents(string: baseUrl)
        urlComponents?.queryItems = [
            URLQueryItem(name: "amount", value: "\(amount)")
        ]
        
        guard let url = urlComponents?.url else {
            completion(.failure(TriviaServiceError.invalidURL))
            return
        }
        
        // Create and start network request
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Handle network error
            if let error = error {
                completion(.failure(TriviaServiceError.networkError(error.localizedDescription)))
                return
            }
            
            // Check for data
            guard let data = data else {
                completion(.failure(TriviaServiceError.noData))
                return
            }
            
            // Parse JSON manually
            do {
                // Convert data to JSON dictionary
                guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(.failure(TriviaServiceError.parsingError("Failed to parse JSON")))
                    return
                }
                
                // Check response code
                guard let responseCode = jsonDict["response_code"] as? Int else {
                    completion(.failure(TriviaServiceError.parsingError("Missing response code")))
                    return
                }
                
                // Handle API errors
                if responseCode != 0 {
                    completion(.failure(TriviaServiceError.apiError(responseCode)))
                    return
                }
                
                // Get results array
                guard let resultsArray = jsonDict["results"] as? [[String: Any]] else {
                    completion(.failure(TriviaServiceError.parsingError("No results found")))
                    return
                }
                
                // Parse questions
                var questions: [TriviaQuestion] = []
                
                for result in resultsArray {
                    guard let category = result["category"] as? String,
                          let question = result["question"] as? String,
                          let correctAnswer = result["correct_answer"] as? String,
                          let incorrectAnswers = result["incorrect_answers"] as? [String] else {
                        continue
                    }
                    
                    // Create new TriviaQuestion
                    let triviaQuestion = TriviaQuestion(
                        category: self.decodeHtmlEntities(category),
                        question: self.decodeHtmlEntities(question),
                        correctAnswer: self.decodeHtmlEntities(correctAnswer),
                        incorrectAnswers: incorrectAnswers.map { self.decodeHtmlEntities($0) }
                    )
                    
                    questions.append(triviaQuestion)
                }
                
                // Return the parsed questions
                completion(.success(questions))
                
            } catch {
                completion(.failure(TriviaServiceError.parsingError(error.localizedDescription)))
            }
        }
        
        task.resume()
    }
    
    // Helper function to decode HTML entities
    private func decodeHtmlEntities(_ string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        
        return string
    }
} 