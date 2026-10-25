import Foundation

enum AkinatorGameError: LocalizedError {
    case missingAPIKey
    case httpError(Int, String)
    case noToolUse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "APIキーが設定されていません。Secrets.xcconfigにANTHROPIC_API_KEYを設定してください。"
        case .httpError(let code, let message):
            return "通信エラー（\(code)）: \(message)"
        case .noToolUse:
            return "予期しない応答でした"
        }
    }
}

/// Drives one 20-questions-style round via the Claude Messages API —
/// raw HTTP, since there's no official Anthropic SDK for Swift.
/// `tool_choice` forces every turn through the single `game_turn` tool,
/// so the response is always structured (ask_question or make_guess),
/// never freeform text that would need fragile parsing.
final class AkinatorGameService {
    private let apiKey: String
    private let model = "claude-opus-5"

    private static let systemPrompt = """
    あなたは「20の質問」風の当てっこゲームの出題者です。ユーザーが心の中で思い浮かべている、人物・キャラクター・動物・物など何でも良いものを、はい/いいえ系の質問を繰り返して当ててください。

    ルール:
    - 一度に1つだけ質問してください（はい/いいえ/たぶんはい/たぶんいいえ/わからない、で答えられる質問にしてください）
    - 質問は絞り込みに効果的なものを選んでください（カテゴリ→特徴→具体名、の順で狭めていくイメージ）
    - 十分に絞り込めたと判断したら、具体的な一つの答えを推測してください
    - 推測が外れた場合は、それまでの回答を踏まえてさらに質問を続けるか、別の推測をしてください
    - 必ず日本語で質問・推測してください
    """

    private static let tool = ToolDefinition(
        name: "game_turn",
        description: "次に行う1手を決める：質問を続けるか、具体的な推測をするか。",
        input_schema: InputSchema(
            type: "object",
            properties: [
                "action": PropertySchema(type: "string", description: "ask_question（質問を続ける）または make_guess（推測する）", enum: ["ask_question", "make_guess"]),
                "question": PropertySchema(type: "string", description: "actionがask_questionの場合に聞く、はい/いいえ系で答えられる質問文", enum: nil),
                "guess": PropertySchema(type: "string", description: "actionがmake_guessの場合の、具体的な推測内容（名前など）", enum: nil),
                "confidence": PropertySchema(type: "number", description: "推測の自信度（0〜1）。make_guessの場合のみ指定", enum: nil)
            ],
            required: ["action"],
            additionalProperties: false
        ),
        strict: true
    )

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func nextTurn(messages: [ClaudeMessage]) async throws -> MessagesResponse {
        guard !apiKey.isEmpty, apiKey != "your-api-key-here" else {
            throw AkinatorGameError.missingAPIKey
        }

        let body = MessagesRequest(
            model: model,
            max_tokens: 1024,
            system: Self.systemPrompt,
            tools: [Self.tool],
            tool_choice: ToolChoice(type: "tool", name: "game_turn"),
            messages: messages
        )

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AkinatorGameError.httpError(-1, "no response")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AkinatorGameError.httpError(httpResponse.statusCode, message)
        }

        return try JSONDecoder().decode(MessagesResponse.self, from: data)
    }
}
