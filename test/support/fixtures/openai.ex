defmodule MPG.Fixtures.OpenAI do
  def chat_response_quiz_questions do
    questions = make_questions()
    content = %{questions: questions} |> Jason.encode!()

    %{
      id: "chatcmpl-AcgX5cZX5Xl3x69jxGDDtWfEPoLAg",
      usage: %{
        "completion_tokens" => 418,
        "completion_tokens_details" => %{
          "accepted_prediction_tokens" => 0,
          "audio_tokens" => 0,
          "reasoning_tokens" => 0,
          "rejected_prediction_tokens" => 0
        },
        "prompt_tokens" => 233,
        "prompt_tokens_details" => %{"audio_tokens" => 0, "cached_tokens" => 0},
        "total_tokens" => 651
      },
      created: 1_733_783_323,
      model: "gpt-4o-mini-2024-07-18",
      choices: [
        %{
          "finish_reason" => "stop",
          "index" => 0,
          "logprobs" => nil,
          "message" => %{
            "content" => content,
            "refusal" => nil,
            "role" => "assistant"
          }
        }
      ],
      object: "chat.completion",
      system_fingerprint: "fp_bba3c8e70b"
    }
    |> Jason.encode!()
  end

  defp make_questions do
    [
      %{
        text: "What is the first movie in the MCU?",
        answers: ["Iron Man", "Captain America: The First Avenger", "The Incredible Hulk", "Thor"],
        correct_answer: 0,
        explanation: "Iron Man (2008) kicked off the Marvel Cinematic Universe."
      },
      %{
        text: "Which Infinity Stone is first introduced in the MCU?",
        answers: ["Power Stone", "Space Stone", "Mind Stone", "Reality Stone"],
        correct_answer: 1,
        explanation:
          "The Space Stone, hidden inside the Tesseract, is the first Infinity Stone introduced in Captain America: The First Avenger."
      },
      %{
        text: "Who is Tony Stark's father?",
        answers: ["Howard Stark", "Obadiah Stane", "James Rhodes", "Nick Fury"],
        correct_answer: 0,
        explanation: "Howard Stark is Tony Stark's father and a founding member of S.H.I.E.L.D."
      },
      %{
        text: "In which film does Spider-Man make his first appearance in the MCU?",
        answers: [
          "Spider-Man: Homecoming",
          "Avengers: Age of Ultron",
          "Captain America: Civil War",
          "Iron Man 3"
        ],
        correct_answer: 2,
        explanation: "Spider-Man makes his first MCU appearance in Captain America: Civil War."
      },
      %{
        text: "What planet is Thor from?",
        answers: ["Midgard", "Asgard", "Vanaheim", "Jotunheim"],
        correct_answer: 1,
        explanation: "Thor is from Asgard, the home of the Norse gods."
      },
      %{
        text: "Who is the director of S.H.I.E.L.D. when the Avengers first assemble?",
        answers: ["Maria Hill", "Nick Fury", "Phil Coulson", "Alexander Pierce"],
        correct_answer: 1,
        explanation: "Nick Fury is the director of S.H.I.E.L.D. and brings the Avengers together."
      },
      %{
        text: "What type of doctor is Stephen Strange?",
        answers: ["Neurosurgeon", "Cardiologist", "Orthopedic Surgeon", "Oncologist"],
        correct_answer: 0,
        explanation:
          "Stephen Strange is a skilled neurosurgeon before becoming the Sorcerer Supreme."
      },
      %{
        text: "Which Avenger has a twin sibling who dies in Avengers: Age of Ultron?",
        answers: ["Thor", "Black Widow", "Scarlet Witch", "Hawkeye"],
        correct_answer: 2,
        explanation: "Scarlet Witch's twin brother, Quicksilver, dies in Avengers: Age of Ultron."
      },
      %{
        text: "What is the name of the realm where Hela was imprisoned?",
        answers: ["Nidavellir", "Hel", "Vanaheim", "Sakaar"],
        correct_answer: 1,
        explanation: "Hela was imprisoned in Hel, a realm within Norse mythology."
      },
      %{
        text:
          "What is the name of the AI created by Tony Stark and Bruce Banner in Avengers: Age of Ultron?",
        answers: ["Jarvis", "Ultron", "Friday", "Vision"],
        correct_answer: 1,
        explanation:
          "Ultron is the AI created by Tony Stark and Bruce Banner that turns against them."
      }
    ]
  end

  def chat_response_quiz_suggestions(topics) do
    content = %{topics: topics} |> Jason.encode!()

    %{
      id: "chatcmpl-B5Znp5z8W2oN9rKUvqcdw2jgGOo5v",
      usage: %{
        "completion_tokens" => 94,
        "completion_tokens_details" => %{
          "accepted_prediction_tokens" => 0,
          "audio_tokens" => 0,
          "reasoning_tokens" => 0,
          "rejected_prediction_tokens" => 0
        },
        "prompt_tokens" => 188,
        "prompt_tokens_details" => %{"audio_tokens" => 0, "cached_tokens" => 0},
        "total_tokens" => 282
      },
      created: 1_740_668_965,
      object: "chat.completion",
      model: "gpt-4o-mini-2024-07-18",
      choices: [
        %{
          "finish_reason" => "stop",
          "index" => 0,
          "logprobs" => nil,
          "message" => %{
            "content" => content,
            "refusal" => nil,
            "role" => "assistant"
          }
        }
      ],
      service_tier: "default",
      system_fingerprint: "fp_06737a9306"
    }
    |> Jason.encode!()
  end
end
