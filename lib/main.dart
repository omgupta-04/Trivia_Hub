import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as htmlParser;
import 'dart:async';

void main() {
  runApp(TriviaApp());
}

class TriviaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.blueGrey,
      ),
      home: QuizScreen(),
    );
  }
}

class QuizScreen extends StatefulWidget {
  @override
  quizScreenState createState() => quizScreenState();
}

class Question {
  final String text;
  final List<String> options;
  final int correctIndex;

  Question({
    required this.text,
    required this.options,
    required this.correctIndex,
  });

  factory Question.fromJson( json) {
    List<String> options = List<String>.from(json['incorrect_answers']);
    options.add(json['correct_answer']);
    options.shuffle();
    return Question(
      text: decodeHtml(json['question']),
      options: options.map((option) => decodeHtml(option)).toList(),
      correctIndex: options.indexOf(decodeHtml(json['correct_answer'])),
    );
  }

  static String decodeHtml(String htmlString) {
    return htmlParser.parse(htmlString).body!.text;
  }
}

class quizScreenState extends State<QuizScreen> {
  int currentQuestionIndex = 0;
  bool showResult = false;
  bool isCorrect = false;
  List<Question> questions = [];
  bool isLoading = true;
  int score = 0;
  int remainingTime = 20;
  Timer? timer;
  bool quizStarted = false;

  @override
  void initState() {
    super.initState();
    fetchQuestions();
  }

  Future fetchQuestions() async {
    setState(() {
      isLoading = true;
    });
    final response = await http.get(Uri.parse('https://opentdb.com/api.php?amount=10'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final results = data['results'] as List;
      setState(() {
        questions = results.map((json) => Question.fromJson(json)).toList();
        currentQuestionIndex = 0;
        showResult = false;
        isLoading = false;
        score = 0;
        quizStarted = false;
      });
    } else {
      throw Exception('Failed to load questions');
    }
  }

  void startQuiz() {
    setState(() {
      quizStarted = true;
      startTimer();
    });
  }

  void startTimer() {
    timer?.cancel();
    setState(() {
      remainingTime = 20;
    });
    timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (remainingTime > 0) {
          remainingTime--;
        } else {
          timer.cancel();
          checkAnswer(-1);
        }
      });
    });
  }

  void checkAnswer(int selectedIndex) {
    timer?.cancel();
    bool correct = (selectedIndex == questions[currentQuestionIndex].correctIndex);
    int points = correct ? remainingTime * 5 : 0;
    setState(() {
      isCorrect = correct;
      score += points;
      showResult = true;
    });
  }

  void nextQuestion() {
    setState(() {
      if (currentQuestionIndex < questions.length - 1) {
        currentQuestionIndex++;
        showResult = false;
        startTimer();
      } else {
        fetchQuestions();
      }
    });
  }

  void resetQuiz() {
    fetchQuestions();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!quizStarted) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: startQuiz,
            child: Text("Start Quiz"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.lightGreenAccent,
              minimumSize: Size(200, 60),
            ),
          ),
        ),
      );
    }

    Question currentQuestion = questions[currentQuestionIndex];
    double progress = (currentQuestionIndex + 1) / questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text("Trivia Quiz", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: showResult
            ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isCorrect ? "Correct!" : "Incorrect!",
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(height: 20),
                Text(
                  "Score: $score",
                  style: TextStyle(fontSize: 24),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: nextQuestion,
                  child: Text(currentQuestionIndex == questions.length - 1 ? "Finish Quiz" : "Next Question", style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.lightGreenAccent),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: resetQuiz,
                  child: Text("Reset Quiz", style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.lightGreenAccent),
            ),
            SizedBox(height: 20),
            Text(
              "Question ${currentQuestionIndex + 1}: ${currentQuestion.text}",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              "Time left: $remainingTime seconds",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            for (int index = 0; index < currentQuestion.options.length; index++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ElevatedButton(
                  onPressed: () => checkAnswer(index),
                  child: Text(currentQuestion.options[index]),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightGreenAccent,
                    minimumSize: Size(double.infinity, 40),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
