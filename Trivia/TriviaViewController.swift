//
//  ViewController.swift
//  Trivia
//
//  Created by Mari Batilando on 4/6/23.
//

import UIKit

class TriviaViewController: UIViewController {

  @IBOutlet weak var currentQuestionNumberLabel: UILabel!
  @IBOutlet weak var questionContainerView: UIView!
  @IBOutlet weak var questionLabel: UILabel!
  @IBOutlet weak var categoryLabel: UILabel!
  @IBOutlet weak var answerButton0: UIButton!
  @IBOutlet weak var answerButton1: UIButton!
  @IBOutlet weak var answerButton2: UIButton!
  @IBOutlet weak var answerButton3: UIButton!

  private var questions = [TriviaQuestion]()
  private var currQuestionIndex = 0
  private var numCorrectQuestions = 0
  private var isLoading = false
  private let apiUrl = "https://opentdb.com/api.php"

  // New properties for categories and difficulties
  private var selectedCategory: Int? = nil
  private var selectedDifficulty: String? = nil
  private let categories = [
    (name: "Any Category", id: nil),
    (name: "General Knowledge", id: 9),
    (name: "Entertainment: Books", id: 10),
    (name: "Entertainment: Film", id: 11),
    (name: "Entertainment: Music", id: 12),
    (name: "Entertainment: Television", id: 14),
    (name: "Science & Nature", id: 17),
    (name: "Science: Computers", id: 18),
    (name: "Science: Mathematics", id: 19),
    (name: "Sports", id: 21),
    (name: "Geography", id: 22),
    (name: "History", id: 23),
  ]

  private let difficulties = [
    (name: "Any Difficulty", value: nil),
    (name: "Easy", value: "easy"),
    (name: "Medium", value: "medium"),
    (name: "Hard", value: "hard"),
  ]

  private var answerSelected = false
 
  override func viewDidLoad() {
    super.viewDidLoad()
    addGradient()
    questionContainerView.layer.cornerRadius = 8.0
    setupUI()

    // Add settings button
    let settingsButton = UIBarButtonItem(
      image: UIImage(systemName: "gear"), style: .plain, target: self,
      action: #selector(showSettings))
    navigationItem.rightBarButtonItem = settingsButton

    // Style answer buttons
    for button in [answerButton0, answerButton1, answerButton2, answerButton3] {
      button?.layer.cornerRadius = 8
      button?.clipsToBounds = true
    }

    fetchNewQuestions()
  }

  @objc private func showSettings() {
    let alertController = UIAlertController(
      title: "Settings", message: "Choose your game options", preferredStyle: .actionSheet)

    let chooseCategoryAction = UIAlertAction(title: "Select Category", style: .default) {
      [weak self] _ in
      self?.showCategoryPicker()
    }

    let chooseDifficultyAction = UIAlertAction(title: "Select Difficulty", style: .default) {
      [weak self] _ in
      self?.showDifficultyPicker()
    }

    let startNewGameAction = UIAlertAction(title: "Start New Game", style: .default) {
      [weak self] _ in
      self?.fetchNewQuestions()
    }

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

    alertController.addAction(chooseCategoryAction)
    alertController.addAction(chooseDifficultyAction)
    alertController.addAction(startNewGameAction)
    alertController.addAction(cancelAction)

    // For iPad compatibility
    if let popoverController = alertController.popoverPresentationController {
      popoverController.barButtonItem = navigationItem.rightBarButtonItem
    }

    present(alertController, animated: true)
  }

  private func showCategoryPicker() {
    let alertController = UIAlertController(
      title: "Select Category", message: nil, preferredStyle: .actionSheet)

    for category in categories {
      let action = UIAlertAction(title: category.name, style: .default) { [weak self] _ in
        self?.selectedCategory = category.id
        self?.showSettingsConfirmation()
      }
      alertController.addAction(action)
    }

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
    alertController.addAction(cancelAction)

    // For iPad compatibility
    if let popoverController = alertController.popoverPresentationController {
      popoverController.barButtonItem = navigationItem.rightBarButtonItem
    }

    present(alertController, animated: true)
  }

  private func showDifficultyPicker() {
    let alertController = UIAlertController(
      title: "Select Difficulty", message: nil, preferredStyle: .actionSheet)

    for difficulty in difficulties {
      let action = UIAlertAction(title: difficulty.name, style: .default) { [weak self] _ in
        self?.selectedDifficulty = difficulty.value
        self?.showSettingsConfirmation()
      }
      alertController.addAction(action)
    }

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
    alertController.addAction(cancelAction)

    // For iPad compatibility
    if let popoverController = alertController.popoverPresentationController {
      popoverController.barButtonItem = navigationItem.rightBarButtonItem
    }

    present(alertController, animated: true)
  }

  private func showSettingsConfirmation() {
    // Find names for the selected options
    let categoryName =
      categories.first(where: { $0.id == selectedCategory })?.name ?? "Any Category"
    let difficultyName =
      difficulties.first(where: { $0.value == selectedDifficulty })?.name ?? "Any Difficulty"

    let message =
      "Category: \(categoryName)\nDifficulty: \(difficultyName)\n\nStart a new game with these settings?"

    let alertController = UIAlertController(
      title: "Game Settings", message: message, preferredStyle: .alert)

    let startAction = UIAlertAction(title: "Start New Game", style: .default) { [weak self] _ in
      self?.fetchNewQuestions()
    }

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

    alertController.addAction(startAction)
    alertController.addAction(cancelAction)

    present(alertController, animated: true)
  }

  private func setupUI() {
    // Hide all answer buttons initially
    answerButton0.isHidden = true
    answerButton1.isHidden = true
    answerButton2.isHidden = true
    answerButton3.isHidden = true

    // Reset buttons to system default appearance
    answerButton0.backgroundColor = nil
    answerButton1.backgroundColor = nil
    answerButton2.backgroundColor = nil
    answerButton3.backgroundColor = nil

    // Set loading state
    questionLabel.text = "Loading questions..."
    categoryLabel.text = ""
    currentQuestionNumberLabel.text = ""
  }

  private func fetchNewQuestions() {
    isLoading = true
    setupUI()

    // Build URL with query parameters
    var urlComponents = URLComponents(string: apiUrl)
    var queryItems = [URLQueryItem(name: "amount", value: "10")]

    // Add category if selected
    if let categoryId = selectedCategory {
      queryItems.append(URLQueryItem(name: "category", value: "\(categoryId)"))
    }

    // Add difficulty if selected
    if let difficulty = selectedDifficulty {
      queryItems.append(URLQueryItem(name: "difficulty", value: difficulty))
    }

    urlComponents?.queryItems = queryItems

    guard let url = urlComponents?.url else {
      showErrorAlert(message: "Invalid URL. Please try again.")
      return
    }

    // Create and start network request
    let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
      guard let self = self else { return }

      // Handle network error
      if let error = error {
        DispatchQueue.main.async {
          self.isLoading = false
          self.showErrorAlert(message: "Network error: \(error.localizedDescription)")
        }
        return
      }

      // Check for data
      guard let data = data else {
        DispatchQueue.main.async {
          self.isLoading = false
          self.showErrorAlert(message: "No data received. Please try again.")
        }
        return
      }

      // Parse JSON manually
      do {
        // Convert data to JSON dictionary
        guard let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          DispatchQueue.main.async {
            self.isLoading = false
            self.showErrorAlert(message: "Failed to parse JSON")
          }
          return
        }

        // Check response code
        guard let responseCode = jsonDict["response_code"] as? Int else {
          DispatchQueue.main.async {
            self.isLoading = false
            self.showErrorAlert(message: "API error. Please try again.")
          }
          return
        }

        if responseCode != 0 {
          DispatchQueue.main.async {
            self.isLoading = false
            var message = "API error. "
            switch responseCode {
            case 1:
              message += "No results found for these settings. Try different options."
            case 2:
              message += "Invalid parameter."
            default:
              message += "Please try again."
            }
            self.showErrorAlert(message: message)
          }
          return
        }

        // Get results array
        guard let resultsArray = jsonDict["results"] as? [[String: Any]] else {
          DispatchQueue.main.async {
            self.isLoading = false
            self.showErrorAlert(message: "No questions found")
          }
          return
        }

        // Parse questions
        var fetchedQuestions: [TriviaQuestion] = []

        for result in resultsArray {
          guard let category = result["category"] as? String,
            let question = result["question"] as? String,
            let correctAnswer = result["correct_answer"] as? String,
            let incorrectAnswers = result["incorrect_answers"] as? [String]
          else {
            continue
          }

          // Create new TriviaQuestion
          let triviaQuestion = TriviaQuestion(
            category: self.decodeHtmlEntities(category),
            question: self.decodeHtmlEntities(question),
            correctAnswer: self.decodeHtmlEntities(correctAnswer),
            incorrectAnswers: incorrectAnswers.map { self.decodeHtmlEntities($0) }
          )

          fetchedQuestions.append(triviaQuestion)
        }

        // Update UI on the main thread
        DispatchQueue.main.async {
          self.isLoading = false
          self.questions = fetchedQuestions
          self.currQuestionIndex = 0
          self.numCorrectQuestions = 0

          if !self.questions.isEmpty {
            self.updateQuestion(withQuestionIndex: 0)
          } else {
            self.showErrorAlert(message: "No questions available. Please try again.")
          }
        }

      } catch {
        DispatchQueue.main.async {
          self.isLoading = false
          self.showErrorAlert(message: "Error processing data: \(error.localizedDescription)")
        }
      }
    }

    task.resume()
  }

  // Helper function to decode HTML entities
  private func decodeHtmlEntities(_ string: String) -> String {
    guard let data = string.data(using: .utf8) else { return string }

    let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
      .documentType: NSAttributedString.DocumentType.html,
      .characterEncoding: String.Encoding.utf8.rawValue,
    ]

    if let attributedString = try? NSAttributedString(
      data: data, options: options, documentAttributes: nil)
    {
      return attributedString.string
    }

    return string
  }

  private func updateQuestion(withQuestionIndex questionIndex: Int) {
    // Reset answer selected flag
    answerSelected = false

    currentQuestionNumberLabel.text = "Question: \(questionIndex + 1)/\(questions.count)"
    let question = questions[questionIndex]
    questionLabel.text = question.question
    categoryLabel.text = question.category

    // Reset buttons to system default appearance
    answerButton0.backgroundColor = nil
    answerButton1.backgroundColor = nil
    answerButton2.backgroundColor = nil
    answerButton3.backgroundColor = nil

    // Combine correct and incorrect answers, then shuffle
    let answers = ([question.correctAnswer] + question.incorrectAnswers).shuffled()

    // Reset button visibility
    answerButton0.isHidden = true
    answerButton1.isHidden = true
    answerButton2.isHidden = true
    answerButton3.isHidden = true

    // Set answer buttons (show only as many as needed)
    if answers.count > 0 {
      answerButton0.setTitle(answers[0], for: .normal)
      answerButton0.isHidden = false
    }
    if answers.count > 1 {
      answerButton1.setTitle(answers[1], for: .normal)
      answerButton1.isHidden = false
    }
    if answers.count > 2 {
      answerButton2.setTitle(answers[2], for: .normal)
      answerButton2.isHidden = false
    }
    if answers.count > 3 {
      answerButton3.setTitle(answers[3], for: .normal)
      answerButton3.isHidden = false
    }
  }

  private func handleAnswerSelection(button: UIButton, answer: String) {
    let isCorrect = isCorrectAnswer(answer)
    
    // Show visual feedback with deeper colors
    if isCorrect {
      // Deeper green for correct answers
      button.backgroundColor = UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 0.7)
    } else {
      // Deeper red for incorrect answers
      button.backgroundColor = UIColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 0.7)
      
      // Highlight the correct answer with deeper green
      let correctAnswer = questions[currQuestionIndex].correctAnswer
      if answerButton0.titleLabel?.text == correctAnswer {
        answerButton0.backgroundColor = UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 0.7)
      } else if answerButton1.titleLabel?.text == correctAnswer {
        answerButton1.backgroundColor = UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 0.7)
      } else if answerButton2.titleLabel?.text == correctAnswer {
        answerButton2.backgroundColor = UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 0.7)
      } else if answerButton3.titleLabel?.text == correctAnswer {
        answerButton3.backgroundColor = UIColor(red: 0.0, green: 0.7, blue: 0.0, alpha: 0.7)
      }
    }
    
    // Update the score if correct
    if isCorrect {
      numCorrectQuestions += 1
    }

    // Instead of disabling buttons, use a flag to prevent multiple selections
    let selectedButtonTag = button.tag

    // Wait for 1.5 seconds before moving to the next question
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
      guard let self = self else { return }

      // Move to next question
      self.currQuestionIndex += 1
      if self.currQuestionIndex < self.questions.count {
        self.updateQuestion(withQuestionIndex: self.currQuestionIndex)
      } else {
        self.showFinalScore()
      }
    }
  }

  private func isCorrectAnswer(_ answer: String) -> Bool {
    return answer == questions[currQuestionIndex].correctAnswer
  }

  private func showFinalScore() {
    let alertController = UIAlertController(
      title: "Game over!",
      message: "Final score: \(numCorrectQuestions)/\(questions.count)",
      preferredStyle: .alert
    )

    // Add a "Play Again" action to fetch new questions
    let playAgainAction = UIAlertAction(title: "Play Again", style: .default) { [unowned self] _ in
      self.fetchNewQuestions()
    }

    // Add a "Reset" action that restarts with the same questions
    let resetAction = UIAlertAction(title: "Reset", style: .default) { [unowned self] _ in
      self.currQuestionIndex = 0
      self.numCorrectQuestions = 0
      self.updateQuestion(withQuestionIndex: self.currQuestionIndex)
    }

    // Add a "Change Settings" action
    let changeSettingsAction = UIAlertAction(title: "Change Settings", style: .default) {
      [unowned self] _ in
      self.showSettings()
    }

    alertController.addAction(playAgainAction)
    alertController.addAction(resetAction)
    alertController.addAction(changeSettingsAction)
    present(alertController, animated: true, completion: nil)
  }

  private func addGradient() {
    let gradientLayer = CAGradientLayer()
    gradientLayer.frame = view.bounds
    gradientLayer.colors = [
      UIColor(red: 0.54, green: 0.88, blue: 0.99, alpha: 1.00).cgColor,
      UIColor(red: 0.51, green: 0.81, blue: 0.97, alpha: 1.00).cgColor,
    ]
    gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
    gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
    view.layer.insertSublayer(gradientLayer, at: 0)
  }

  private func showErrorAlert(message: String) {
    let alertController = UIAlertController(
      title: "Error",
      message: message,
      preferredStyle: .alert
    )

    let okAction = UIAlertAction(title: "OK", style: .default)
    let retryAction = UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
      self?.fetchNewQuestions()
    }

    alertController.addAction(okAction)
    alertController.addAction(retryAction)

    present(alertController, animated: true)
  }

  @IBAction func didTapAnswerButton0(_ sender: UIButton) {
    if !answerSelected {
      answerSelected = true
      handleAnswerSelection(button: sender, answer: sender.titleLabel?.text ?? "")
    }
  }

  @IBAction func didTapAnswerButton1(_ sender: UIButton) {
    if !answerSelected {
      answerSelected = true
      handleAnswerSelection(button: sender, answer: sender.titleLabel?.text ?? "")
    }
  }

  @IBAction func didTapAnswerButton2(_ sender: UIButton) {
    if !answerSelected {
      answerSelected = true
      handleAnswerSelection(button: sender, answer: sender.titleLabel?.text ?? "")
    }
  }

  @IBAction func didTapAnswerButton3(_ sender: UIButton) {
    if !answerSelected {
      answerSelected = true
      handleAnswerSelection(button: sender, answer: sender.titleLabel?.text ?? "")
    }
  }
}

// API response models
struct TriviaResponse: Decodable {
  let responseCode: Int
  let results: [TriviaResult]

  enum CodingKeys: String, CodingKey {
    case responseCode = "response_code"
    case results
  }
}

struct TriviaResult: Decodable {
  let category: String
  let type: String
  let difficulty: String
  let question: String
  let correctAnswer: String
  let incorrectAnswers: [String]

  enum CodingKeys: String, CodingKey {
    case category
    case type
    case difficulty
    case question
    case correctAnswer = "correct_answer"
    case incorrectAnswers = "incorrect_answers"
  }
}
