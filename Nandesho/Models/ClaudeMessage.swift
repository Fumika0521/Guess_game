import Foundation

/// The game's one tool — Claude must call this every turn (`tool_choice`
/// forces it), so a turn is always either a question to ask or a guess
/// to make, never freeform text.
struct GameTurnInput: Codable {
    var action: String // "ask_question" | "make_guess"
    var question: String?
    var guess: String?
    var confidence: Double?
}

/// One content block in a Messages API message. Not every field applies
/// to every `type` — `text` for "text", `id`/`name`/`input` for
/// "tool_use", `tool_use_id`/`content` for "tool_result".
struct ContentBlock: Codable {
    var type: String
    var text: String?
    var id: String?
    var name: String?
    var input: GameTurnInput?
    var tool_use_id: String?
    var content: String?

    static func text(_ value: String) -> ContentBlock {
        ContentBlock(type: "text", text: value, id: nil, name: nil, input: nil, tool_use_id: nil, content: nil)
    }

    static func toolResult(toolUseID: String, result: String) -> ContentBlock {
        ContentBlock(type: "tool_result", text: nil, id: nil, name: nil, input: nil, tool_use_id: toolUseID, content: result)
    }
}

struct ClaudeMessage: Codable {
    var role: String
    var content: [ContentBlock]
}

struct ToolDefinition: Codable {
    var name: String
    var description: String
    var input_schema: InputSchema
    var strict: Bool
}

struct InputSchema: Codable {
    var type: String
    var properties: [String: PropertySchema]
    var required: [String]
    var additionalProperties: Bool
}

struct PropertySchema: Codable {
    var type: String
    var description: String?
    var `enum`: [String]?
}

struct ToolChoice: Codable {
    var type: String
    var name: String
}

struct MessagesRequest: Codable {
    var model: String
    var max_tokens: Int
    var system: String
    var tools: [ToolDefinition]
    var tool_choice: ToolChoice
    var messages: [ClaudeMessage]
}

struct MessagesResponse: Codable {
    var id: String
    var role: String
    var content: [ContentBlock]
    var stop_reason: String?
}
