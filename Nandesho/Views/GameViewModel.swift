import Foundation

@MainActor
final class GameViewModel: ObservableObject {
    struct Guess {
        let text: String
        let confidence: Double?
    }

    @Published private(set) var currentQuestion: String?
    @Published private(set) var currentGuess: Guess?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hasGivenUp = false
    @Published private(set) var hasStarted = false

    private let service: AkinatorGameService
    private var messages: [ClaudeMessage] = []
    private var lastToolUseID: String?
    private var turnCount = 0
    private let maxTurns = 20

    init(service: AkinatorGameService) {
        self.service = service
    }

    func startNewGame() {
        messages = []
        turnCount = 0
        currentQuestion = nil
        currentGuess = nil
        hasGivenUp = false
        hasStarted = true
        Task { await requestNextTurn(userText: "ゲームを始めてください。最初の質問をどうぞ。") }
    }

    func answer(_ answerText: String) {
        Task { await requestNextTurn(toolResultText: answerText) }
    }

    func confirmGuess(correct: Bool) {
        if correct {
            currentGuess = nil
            currentQuestion = nil
        } else {
            Task { await requestNextTurn(toolResultText: "違います。推測を続けるか、質問を続けてください。") }
        }
    }

    private func requestNextTurn(userText: String? = nil, toolResultText: String? = nil) async {
        isLoading = true
        errorMessage = nil

        if let userText {
            messages.append(ClaudeMessage(role: "user", content: [.text(userText)]))
        } else if let toolResultText, let lastToolUseID {
            messages.append(ClaudeMessage(role: "user", content: [.toolResult(toolUseID: lastToolUseID, result: toolResultText)]))
        }

        do {
            let response = try await service.nextTurn(messages: messages)
            messages.append(ClaudeMessage(role: "assistant", content: response.content))

            guard let toolUse = response.content.first(where: { $0.type == "tool_use" }),
                  let input = toolUse.input else {
                errorMessage = AkinatorGameError.noToolUse.localizedDescription
                isLoading = false
                return
            }
            lastToolUseID = toolUse.id
            turnCount += 1

            if input.action == "make_guess" {
                currentQuestion = nil
                currentGuess = Guess(text: input.guess ?? "わかりません", confidence: input.confidence)
            } else if turnCount >= maxTurns {
                currentQuestion = nil
                currentGuess = nil
                hasGivenUp = true
            } else {
                currentGuess = nil
                currentQuestion = input.question ?? "うーん、もう一つ教えてください"
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
