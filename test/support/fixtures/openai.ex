defmodule MPG.Fixtures.OpenAI do
  import Mox

  @bingo_prompts [
    "Changed your opinion about something",
    "Had a 'fail' moment",
    "Pushed yourself outside your comfort zone",
    "Saw something beautiful in nature",
    "Heard or read a quote that stuck with you",
    "Tried a new food or recipe",
    "Learned something interesting",
    "Made someone laugh",
    "Did something kind for someone",
    "Had an encounter with an animal",
    "Solved a problem",
    "Received a compliment",
    "Helped a friend or co-worker",
    "Learned a new word or phrase",
    "Faced a fear",
    "Noticed something beautiful",
    "Made a new friend or acquaintance",
    "Completed a goal or task",
    "Had a moment of relaxation",
    "Experienced a moment of gratitude",
    "Observed an act of kindness",
    "Learned from a mistake",
    "Felt inspired by something or someone",
    "Saw something new on the way to school/work",
    "Tried a new activity"
  ]

  def mock_quiz_questions do
    content = %{questions: make_questions()} |> Jason.encode!()

    MPG.AI.MockClient
    |> expect(:get_completion, fn _model, _system, _user, _opts -> {:ok, content} end)
  end

  def stub_quiz_questions do
    content = %{questions: make_questions()} |> Jason.encode!()

    MPG.AI.MockClient
    |> stub(:get_completion, fn _model, _system, _user, _opts -> {:ok, content} end)
  end

  def mock_quiz_topics(topics) do
    content = %{topics: topics} |> Jason.encode!()

    MPG.AI.MockClient
    |> expect(:get_completion, fn _model, _system, _user, _opts -> {:ok, content} end)
  end

  def mock_bingo_cells(prompts \\ @bingo_prompts) do
    content = %{prompts: prompts} |> Jason.encode!()

    MPG.AI.MockClient
    |> expect(:get_completion, fn _model, _system, _user, _opts -> {:ok, content} end)
  end

  def stub_bingo_cells do
    content = %{prompts: @bingo_prompts} |> Jason.encode!()

    MPG.AI.MockClient
    |> stub(:get_completion, fn _model, _system, _user, _opts -> {:ok, content} end)
  end

  @likely_questions [
    %{text: "Who's most likely to survive a zombie apocalypse?"},
    %{text: "Who's most likely to become famous?"},
    %{text: "Who's most likely to forget their own birthday?"},
    %{text: "Who's most likely to win a reality TV show?"},
    %{text: "Who's most likely to talk to animals?"},
    %{text: "Who's most likely to become a millionaire?"},
    %{text: "Who's most likely to sleep through an alarm?"},
    %{text: "Who's most likely to cry during a movie?"},
    %{text: "Who's most likely to get lost in their own city?"},
    %{text: "Who's most likely to laugh at the worst time?"}
  ]

  @likely_roasts %{
    "Alice" =>
      "Based on your results, you're basically the main character of everyone's chaos. Most likely to survive a zombie apocalypse AND forget your own birthday? Priorities, clearly.",
    "Bob" =>
      "You got voted most likely to become famous and cry during a movie. So basically, you're destined to be a very emotional celebrity. Prepare your Oscar speech."
  }

  def mock_likely_questions do
    content = %{questions: @likely_questions} |> Jason.encode!()

    MPG.AI.MockClient
    |> expect(:get_completion, fn _model, _system, _user, _opts -> {:ok, content} end)
  end

  def stub_likely_questions do
    content = %{questions: @likely_questions} |> Jason.encode!()

    MPG.AI.MockClient
    |> stub(:get_completion, fn _model, _system, _user, _opts -> {:ok, content} end)
  end

  def mock_likely_roasts(roasts \\ @likely_roasts) do
    content = %{roasts: roasts} |> Jason.encode!()

    MPG.AI.MockClient
    |> expect(:get_completion, fn _model, _system, _user, _opts -> {:ok, content} end)
  end

  def stub_likely_roasts do
    content = %{roasts: @likely_roasts} |> Jason.encode!()

    MPG.AI.MockClient
    |> stub(:get_completion, fn _model, _system, _user, _opts -> {:ok, content} end)
  end

  def make_questions do
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
end
