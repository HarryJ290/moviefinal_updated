import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:http_parser/http_parser.dart';
import 'package:animated_splash_screen/animated_splash_screen.dart'; // ✅ Added

const String apiKey = '98a778cd48257c0eed3939d0bbdd1145';
const String baseUrl = 'https://api.themoviedb.org/3/genre/movie/list';
const String moviesByGenreUrl = 'https://api.themoviedb.org/3/discover/movie';
const String searchUrl = 'https://api.themoviedb.org/3/search/movie';
const String imageUrl = 'https://image.tmdb.org/t/p/w500';

late List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Movie UI',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AnimatedSplashScreen(
        splash: Icons.movie,
        duration: 3000,
        splashTransition: SplashTransition.fadeTransition,
        backgroundColor: Colors.blue,
        nextScreen: const PlaceholderHomeScreen(), // Replace with your home screen
      ),
    );
  }
}

// ✅ Temporary home screen after splash (you can replace this)
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text("Welcome to Movie App!", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}

// ... Your LoadingPage and MovieListPage code goes below unchanged

class LoadingPage extends StatefulWidget {
  final Uint8List imageBytes;

  const LoadingPage({super.key, required this.imageBytes});

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  String? emotion;
  final Map<String, List<String>> emotionGenres = {
    "Angry": ["Action", "Crime", "War", "Thriller"],
    "Fear": ["Horror", "Mystery"],
    "Happy": ["Comedy", "Music", "Fantasy"],
    "Neutral": ["Drama", "Documentary", "Family", "History", "TV Movie", "Western"],
    "Sad": ["Romance", "Drama"],
    "Surprise": ["Science Fiction", "Animation", "Adventure"],
  };

  @override
  void initState() {
    super.initState();
    _fetchEmotion();
  }

  Future<void> _fetchEmotion() async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://127.0.0.1:5000/upload'),
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        widget.imageBytes,
        filename: 'captured_image.jpg',
        contentType: MediaType('image', 'jpeg'),
      ),
    );

    var response = await request.send();
    var responseData = await response.stream.bytesToString();
    var jsonResponse = jsonDecode(responseData);

    if (!mounted) return;
    setState(() {
      emotion = jsonResponse["predicted_emotion"];
    });
  }

  Future<List<dynamic>> fetchMoviesByGenre(String genre) async {
    final response = await http.get(Uri.parse('$moviesByGenreUrl?api_key=$apiKey&with_genres=$genre'));
    if (response.statusCode == 200) {
      return json.decode(response.body)['results'];
    } else {
      throw Exception('Failed to load movies');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: emotion == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text("Detecting Emotion... Please wait"),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(20),
                    margin: EdgeInsets.symmetric(horizontal: 30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "You Are Feeling : $emotion",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          "We recommend you ${emotionGenres[emotion]!.join(", ")} movies.",
                          style: TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Previous"),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          List<dynamic> movies = await fetchMoviesByGenre(emotionGenres[emotion]!.first);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MovieListPage(movies: movies),
                            ),
                          );
                        },
                        child: Text("Get Movies"),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class MovieListPage extends StatelessWidget {
  final List<dynamic> movies;

  const MovieListPage({super.key, required this.movies});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Recommended Movies")),
      body: ListView.builder(
        itemCount: movies.length,
        itemBuilder: (context, index) {
          var movie = movies[index];
          return ListTile(
            leading: Image.network('$imageUrl${movie['poster_path']}', width: 50, height: 75, fit: BoxFit.cover),
            title: Text(movie['title']),
            subtitle: Text(movie['overview']),
          );
        },
      ),
    );
  }
}
