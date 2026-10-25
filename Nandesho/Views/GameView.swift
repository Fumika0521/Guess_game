import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel

    private static let answerOptions = ["はい", "たぶんはい", "わからない", "たぶんいいえ", "いいえ"]

    init(apiKey: String) {
        _viewModel = StateObject(wrappedValue: GameViewModel(service: AkinatorGameService(apiKey: apiKey)))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            content

            Spacer()

            if viewModel.hasStarted {
                Button("もう一度あそぶ") {
                    viewModel.startNewGame()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .navigationTitle("なんでしょ")
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.hasStarted {
            VStack(spacing: 16) {
                Text("なんでも当てます")
                    .font(.largeTitle.bold())
                Text("人・キャラクター・動物・物…何か一つ思い浮かべて、質問に答えてください")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("はじめる") {
                    viewModel.startNewGame()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        } else if viewModel.isLoading {
            ProgressView("考え中...")
        } else if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.red)
            }
        } else if viewModel.hasGivenUp {
            Text("わかりませんでした...お見事です！")
                .font(.title2.bold())
        } else if let guess = viewModel.currentGuess {
            VStack(spacing: 20) {
                Text("もしかして…")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(guess.text)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                if let confidence = guess.confidence {
                    Text("自信度 \(Int(confidence * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 16) {
                    Button("当たり！") { viewModel.confirmGuess(correct: true) }
                        .buttonStyle(.borderedProminent)
                    Button("違う") { viewModel.confirmGuess(correct: false) }
                        .buttonStyle(.bordered)
                }
            }
        } else if let question = viewModel.currentQuestion {
            VStack(spacing: 24) {
                Text(question)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                VStack(spacing: 10) {
                    ForEach(Self.answerOptions, id: \.self) { option in
                        Button(option) {
                            viewModel.answer(option)
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }
}
