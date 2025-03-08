defmodule MPG.Generator do
  @moduledoc """
  Generates content for the different game types
  """

  @doc """
  Generates a trivia quiz
  """
  def generate_quiz_questions(title) do
    # capture current time to measure duration

    system_prompt =
      """
        You are a quiz question generator that generates fun and interesting trivia questions on a specified topic."
        Each question on should have 4 possible answers.
        Unless I specify the difficulty (Easy, Medium or Hard), the questions should be of a difficulty level
        appropriate for an adult who is familiar with the subject.
        Each question should include the `correct_answer`, which is the zero-based index of the correct answer in the list.
        Each question should have a brief explanation about the correct answer.
        I will give you the subject of the trivia and you will generate 10 questions on that subject.
        IMPORTANT: Please be sure the correct answer is correct and it matches the explanation!
        Respond ONLY with the JSON with no additional text.
        Please generate each of the questions in JSON format like the example below:

        User: "Subject: Interesting insects"

        You:

        {
          "questions":
            [
              {
                "text": "What is the first movie in the MCU?",
                "answers": ["Iron Man", "Captain America: The First Avenger", "The Incredible Hulk", "Thor"],
                "correct_answer": 0,
                "explanation": "Iron Man (2008) kicked off the Marvel Cinematic Universe."
              },
              /* 9 more questions */
            ]
        }
      """

    user_prompt = "Subject: #{title}"

    get_completion("gpt-4o-mini", system_prompt, user_prompt,
      temperature: 0.8,
      response_format: %{type: "json_object"}
    )
    |> parse_chat()
    |> decode_json()
    |> Map.get(:questions)
  end

  @doc """
  Generates suggested quiz topics.

  When given a topic, generates 5 slightly more specific, random quiz topics within that area.
  When given a list of topics, generates 10 more similar topics, but not the same as the ones provided.
  """
  def generate_quiz_topics(topic) when is_binary(topic) do
    system_prompt = """
         I would like you to act as a quiz topic generator that generates topics for fun quizzes.
         If I say "start", please provide me with 5 random high level quiz categories to choose from,
         similar to the example below, but different each time.
         If I give you a quiz category, please provide me with 5 quiz topics within that category.
         If I give you a specific quiz topic, please provide me with 5 similar but different quiz topics.
         The quizzes will be text only, and should not reference images, audio, or video.
         Please respond only with JSON in the format below and no additional text.
         Below is an example conversation:

         Me: "start"

         You:

          {
            "topics":
            [
              "Pop Culture & Entertainment – Movies, TV shows, music, and celebrity trivia",
              "Science & Nature – Space, animals, inventions, and weird scientific facts",
              "History & Geography – World events, historical figures, and places around the globe",
              "Games & Hobbies – Video games, board games, sports, and creative activities",
              "Random & Wacky – Unusual facts, urban legends, and 'Which one is fake?' style quizzes"
            ]
          }

         Me: "Random & Wacky"

         You:

         {
           "topics":
           [
             "Fact or Fiction – Can you tell the difference between real and made-up facts?",
             "Bizarre Laws Around the World – Guess which strange laws actually exist",
             "Weird Animal Superpowers – Animals with abilities that sound like science fiction",
             "The Most Unusual World Records – Can you guess which world records are real?",
             "Strange but True: Food Edition – Weird food facts and traditions from around the world."
           ]
         }

         Me: "Weird Animal Superpowers – Animals with abilities that sound like science fiction"

         You:

          {
            "topics":
            [
              "Incredible Animal Adaptations – How animals have evolved to survive in extreme environments",
              "The Science of Animal Communication – How animals talk to each other in the wild",
              "The World's Strangest Creatures – Animals that look like they're from another planet",
              "The Secret Lives of Animals – Surprising behaviors of animals in the wild",
              "The Animal Kingdom's Superheroes – Animals with real-life superpowers"
            ]
          }
    """

    user_prompt = topic

    get_completion("gpt-4o-mini", system_prompt, user_prompt,
      temperature: 0.8,
      response_format: %{type: "json_object"}
    )
    |> parse_chat()
    |> decode_json()
    |> Map.get(:topics)
  end

  def generate_quiz_topics(topics) when is_list(topics) do
    system_prompt = """
      You are a quiz topic generator that generates fun and interesting trivia topics.
      I will give you a list of topics.
      Please generate 10 more similar topics, but not the same as the ones I provide.
      Respond ONLY with the JSON with no additional text.

      User: "Traditions around the world, Famous song lyrics, Unusual animals, Mythical creatures, Greek mythology"

      You:

      {
        "topics": [
          "Inventions that changed the world",
          "Unsolved mysteries in history",
          "Famous landmarks and their stories",
          "Incredible survival stories",
          "The evolution of fashion through the decades",
          "Culinary dishes from different cultures",
          "The history of board games",
          "Record-breaking feats and accomplishments",
          "Famous art movements and their impact",
          "Legends and folklore from around the globe"
        ]
      }
    """

    user_prompt = topics |> Enum.join(", ")

    get_completion("gpt-4o-mini", system_prompt, user_prompt,
      temperature: 0.8,
      response_format: %{type: "json_object"}
    )
    |> parse_chat()
    |> decode_json()
    |> Map.get(:topics)
  end

  def get_completion(model, system_prompt, user_prompt, options) do
    messages = [
      %{role: "system", content: system_prompt},
      %{role: "user", content: user_prompt}
    ]

    args = Keyword.merge([model: model, messages: messages], options)

    OpenAI.chat_completion(args)
  end

  defp parse_chat({:ok, %{choices: [%{"message" => %{"content" => content}} | _]}}),
    do: {:ok, content}

  defp parse_chat({:error, %{"error" => %{"message" => message}}}), do: {:error, message}

  defp decode_json({:ok, json}) do
    Jason.decode!(json, keys: :atoms)
  end

  @things [
    "cannibals think about while dining",
    "dogs are actually saying when they bark",
    "grown-ups wish they could still do.",
    "you should never put in your mouth",
    "not to do in a hospital",
    "not to do while driving",
    "not to tell your mother",
    "paramedics shouldn't say to a patient on the way to the hospital",
    "people do when no one is looking",
    "that are good",
    "that are harder than they look",
    "that are your favorite foods",
    "that you can use to get from one place to another",
    "that confirm your house is haunted",
    "that confirm your life is going downhill",
    "that go bad",
    "that jiggle",
    "that make you feel stupid",
    "that make you giggle",
    "that make you uncomfortable",
    "that must be magic",
    "that shouldn't be made into video games",
    "that shouldn't be passed from one generation to the next",
    "that smell terrible",
    "that squirt",
    "that you will find in (name room of house..bathroom, kitchen, etc)",
    "that you can trip over",
    "that you love to watch on TV",
    "that you shouldn't do in public",
    "that you shouldn't swallow",
    "that you shouldn't throw off of a building",
    "that your parents would kill you for",
    "that would be fun to do in an elevator",
    "that would keep you out of heaven",
    "to wear to (occasion ...wedding, funeral, etc)",
    "wouldn't want to be allergic to",
    "you can never find",
    "you do to get a job",
    "you do to relieve stress",
    "you do to stay warm",
    "you don't want to find in your bed",
    "you might find in a library",
    "given to you for Christmas that you would return",
    "you shop for on Black Friday",
    "you should be thankful for",
    "you should do to get ready for winter",
    "you should give as birthday gifts",
    "you should never put in your mouth",
    "you shouldn't attempt to juggle",
    "you shouldn't do while babysitting",
    "you shouldn't do on your birthday",
    "you shouldn't do with glue",
    "you shouldn't give trick-or-treaters",
    "you shouldn't lick",
    "you shouldn't play catch with",
    "you shouldn't say when trying to make a good impression",
    "you shouldn't send your friends in a pic",
    "you shouldn't swallow",
    "you shouldn't tie to the roof of your car",
    "you use to remove snow from your car",
    "you wish for",
    "you would ask a psychic",
    "you would buy if you were rich",
    "you would do if you were a giant",
    "you would rather forget",
    "you would rather put off till tomorrow",
    "you would wish for if you were stranded on an island",
    "you wouldn't do for a million dollars",
    "you wouldn't want made into a movie",
    "you wouldn't want to do in cemetery",
    "you'd rather forget",
    "your friends text you",
    "your parents forgot to tell you",
    "you'll do when you retire",
    "that would get a doctor sued for malpractice",
    "you shouldn't do in front of a crowd",
    "that give you a headache",
    "you wouldn't want to clean",
    "a gentleman shouldn't do",
    "women know more about than men",
    "you shouldn't give as a gift",
    "that make you go ahhhh",
    "you shouldn't do at the dinner table",
    "you would consider strange to include on a resume",
    "there should be an award for",
    "you shouldn't do when having dinner with the Queen",
    "you shouldn't make fun of",
    "that make you giggle",
    "you shouldn't teach your pets to do",
    "you shouldn't photograph",
    "you shouldn't do in the classroom",
    "that make ballet more exciting",
    "men know more about then women",
    "you would say to a pig if it could talk",
    "you can do to get rid of unwanted guests",
    "you like about yourself",
    "you shouldn't say to your boyfriend/girlfriend",
    "you would line up to see",
    "a chicken thinks about when the farmer picks up the eggs",
    "you wish grew on trees",
    "you shouldn't say to you dentist",
    "you wish you could borrow from a library",
    "you shouldn't do while taking a final exam",
    "you shouldn't teach your parrot to say",
    "that go bad",
    "that shouldn't go into a time capsule",
    "that hurt your back",
    "you shouldn't mix",
    "you just can't believe",
    "that are politically incorrect",
    "that happen once in a blue moon",
    "about the opposite sex that frustrate you",
    "that are harder than they look",
    "kids know more about than adults",
    "that cause trouble",
    "that make you relax",
    "you wouldn't want to be allergic to",
    "you shouldn't shout at the top of your lungs",
    "you need to survive",
    "you shouldn't do in a car",
    "you would like to play with",
    "you can't stop",
    "you shouldn't do on vacation",
    "you would wish for if you found a genie in a bottle",
    "that seem to take an eternity",
    "that confirm you are losing your memory",
    "you shouldn't display in your china cabinet",
    "you would like as your last words",
    "that shouldn't be passed from one generation to the next",
    "you shouldn't put off until tomorrow",
    "that shouldn't be lumpy",
    "fish think about as they swim in their aquarium",
    "you could use as an excuse on judgement day",
    "that would make golf more exciting",
    "you shouldn't advertise in the classified ads",
    "you shouldn't do at home",
    "that would make work more exciting",
    "that are wild",
    "that require an assistant",
    "you would like to say to the President",
    "you would like to ask a psychic",
    "you shouldn't encourage your children to do",
    "you wish you could do with your feet",
    "you never see on television",
    "you wish worked by remote control",
    "you shouldn't exaggerate",
    "a waiter shouldn't do",
    "you shouldn't collect",
    "that confirm you still haven't grown up",
    "you shouldn't touch",
    "you shouldn't attempt at your age",
    "that confirm your small town is backward",
    "that would make school more exciting",
    "you shouldn't tie to the roof of your car",
    "you shouldn't send in the mail",
    "that usually make you feel better",
    "you would like to do on vacation",
    "that cause an accident",
    "you shouldn't say to get out of a speeding ticket",
    "you shouldn't say about your children",
    "you shouldn't hold while riding a bike",
    "you wish you could predict",
    "that hurt",
    "you shouldn't give away",
    "you hate as punishment",
    "you shouldn't advertise on a billboard",
    "that are embarrassing",
    "you shouldn't do in public",
    "that require a lot of patience",
    "you shouldn't say to your boss",
    "you shouldn't let an amateur do",
    "you wish you could erase",
    "you say to a telemarketer",
    "you wouldn't want to find in your sandwich",
    "you shouldn't put in your mouth",
    "that exhaust you",
    "you shouldn't do at the theatre",
    "you shouldn't do in the bathtub",
    "you shouldn't write on a Valentine's card",
    "you shouldn't say to your grandmother",
    "that make you jump",
    "you won't find in a dictionary",
    "you shouldn't say to a flight attendant",
    "you shouldn't put on the front lawn",
    "that drive you mad",
    "that jiggle",
    "you shouldn't do in your backyard",
    "you wouldn't want to find in your Christmas stocking",
    "you wish people would stop talking about",
    "you just can't beat",
    "you shouldn't do with your mouth open",
    "that would make your love life more exciting",
    "you shouldn't do at a party",
    "that are dirty",
    "you've paid too much for",
    "you shouldn't laugh at",
    "you should keep to yourself",
    "you wouldn't want your mother to talk about with your girlfriend/boyfriend",
    "you shouldn't do on your desk",
    "you would like to do in a blackout",
    "that make you cry",
    "you would do if you had super-human powers",
    "that are naughty",
    "that make you go ooooh",
    "that really need a referee",
    "you shouldn't put on the kitchen table",
    "you would do if you changed genders for a day",
    "you would rather forget",
    "that would be considered a bad habit",
    "you would rather be doing right now",
    "you shouldn't bite",
    "astronauts complain about in space",
    "you shouldn't do with your tongue",
    "you wouldn't want to know about your grandmother",
    "that make you gag",
    "you shouldn't say to your mother",
    "a chimp thinks about when he sees you at the zoo",
    "you shouldn't forget",
    "a doctor shouldn't do while performing surgery",
    "you shouldn't say to the First Lady",
    "you shouldn't do with glue",
    "you hate about the hospital",
    "that should have an expiration date",
    "you shouldn't do at the beach",
    "people like about you",
    "you shouldn't say to your doctor",
    "that confirm you are losing your mind",
    "that don't last very long",
    "you didn't realize until it was too late",
    "you keep hidden",
    "you would like to see in your horoscope",
    "you shouldn't lend",
    "that take courage",
    "you shouldn't say to your teacher",
    "you shouldn't do right after you eat",
    "you shouldn't do on your first day on the job",
    "you shouldn't do at the circus",
    "you shouldn't capture on videotape",
    "women talk about when they go to the restroom together",
    "that should come with a manual",
    "you shouldn't do on a first date",
    "that hang",
    "that confirm you have been abducted by aliens",
    "you never see in the country",
    "you shouldn't try to hold on to",
    "that prove you're in a bad restaurant",
    "you shouldn't say in group therapy",
    "that could get you arrested",
    "children shouldn't play with",
    "you shouldn't say to your father",
    "you want to do before you die",
    "you know nothing about",
    "a lady shouldn't do",
    "that confirm your car is a lemon",
    "that could result in a war",
    "you shouldn't say to your wife",
    "you would have a robot do",
    "cats think about humans",
    "you would do if you were a dictator",
    "you would like to change",
    "you would do if you were a giant",
    "you shouldn't pick up",
    "that would make meetings more exciting",
    "you never remember",
    "you keep in your car",
    "you shouldn't doodle on",
    "that don't make sense",
    "you wish you could do in your sleep",
    "you would like to study",
    "you might complain about in Hell",
    "you shouldn't celebrate",
    "you hope you can still do when you are 85",
    "you shouldn't share",
    "you will never see in your lifetime",
    "that could spoil your appetite",
    "you don't like about family gatherings",
    "that could use a good cleaning",
    "you shouldn't do on an airplane",
    "that are funny",
    "you hate to be called",
    "that would get you discharged from the army",
    "you would like to make someone do under hypnosis",
    "you shouldn't title a children's book",
    "that don't exist but you wish they did",
    "you shouldn't do with a computer",
    "you would like to do with a bald head",
    "that make you scream",
    "that would get you fired",
    "that warrant an apology",
    "you would hate to do for a living",
    "you shouldn't leave open",
    "that very old people shouldn't do",
    "you shouldn't do if you want to make a good first impression",
    "big dogs think about when they see a Chihuahua",
    "that make you feel young",
    "you shouldn't play catch with",
    "you shouldn't say to your troops before they go to battle",
    "you wish you didn't know",
    "you shouldn't use as an opening line",
    "that make people jealous",
    "you would like to add to the Ten Commandments",
    "you love to shop for",
    "you shouldn't try to do in the dark",
    "you would do if you were invisible",
    "you shouldn't do in a group of people",
    "you can't believe someone actually did",
    "that make you angry",
    "you shouldn't have to pay for",
    "you wish had been taught in school",
    "that make you nervous",
    "you wish were delivered",
    "you would like to wake up to",
    "you shouldn't do in a cemetery",
    "that are impossible to measure",
    "you shouldn't do at your wedding",
    "that are better late than never",
    "you never see in the city",
    "that would probably keep you out of heaven",
    "you would like to try",
    "you shouldn't do while golfing",
    "you shouldn't experiment with",
    "that are useless",
    "you shouldn't do on a bus",
    "you would like to do with chocolate",
    "you shouldn't say to break the silence in a conversation",
    "you would do with a million dollars",
    "you wish you could buy out of vending machines",
    "you shoudn't do at a job interview",
    "you shouldn't accept from strangers",
    "you shouldn't do quickly"
  ]

  @doc """
  Gets a random thing
  """
  def random_thing do
    Enum.random(@things)
  end

  @quiz_topics [
    "Traditions from around the world",
    "Famous song lyrics",
    "Unusual animals",
    "Mythical creatures",
    "Greek mythology",
    "Inventions that changed the world",
    "Unsolved mysteries in history",
    "Famous landmarks and their stories",
    "Incredible survival stories",
    "The evolution of fashion through the decades",
    "Culinary dishes from different cultures",
    "The history of board games",
    "Record-breaking feats and accomplishments",
    "Legends and folklore from around the globe",
    "Unique festivals celebrated around the world",
    "Influential musicians",
    "Bizarre natural phenomena",
    "Fictional worlds in literature",
    "Ancient civilizations and their achievements",
    "Iconic movie quotes",
    "The science behind popular myths",
    "Historical figures who changed society",
    "Traditional crafts and their significance",
    "Architectural wonders and their histories",
    "Famous historical speeches",
    "The role of animals in various cultures",
    "Innovative technologies of the future",
    "Cultural significance of music genres",
    "The art of storytelling through the ages",
    "Notable explorers and their journeys",
    "The symbolism of colors in different cultures",
    "Remarkable archaeological discoveries",
    "The influence of social media on modern society",
    "Fascinating superstitions from around the world",
    "The history of space exploration",
    "The history of video games",
    "Influential women in history",
    "The origins of popular idioms",
    "Cultural taboos and their meanings",
    "Myths and facts about the human brain",
    "Unique architectural styles across continents",
    "The history of traditional medicine",
    "Famous duels in history",
    "The impact of climate change",
    "Famous young adult novels",
    "The Paleolithic era and human evolution",
    "Interesting facts about cats"
  ]

  @doc """
  Lists all quiz topics
  """
  def list_quiz_topics, do: @quiz_topics

  @doc """
  Gets a random quiz topic
  """
  def random_quiz_topic do
    Enum.random(@quiz_topics)
  end
end
