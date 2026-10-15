import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'models/quiz_arguments.dart';
import 'pages/favorite_page.dart';
import 'pages/home_page.dart';
import 'pages/quiz_page.dart';
import 'pages/settings_page.dart';
import 'pages/stats_page.dart';
import 'pages/wrong_book_page.dart';
import 'providers/favorite_provider.dart';
import 'providers/practice_provider.dart';
import 'providers/question_provider.dart';
import 'providers/stats_provider.dart';
import 'providers/wrong_book_provider.dart';

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<QuestionProvider>(
          create: (_) => QuestionProvider()..init(),
        ),
        ChangeNotifierProvider<PracticeProvider>(
          create: (_) => PracticeProvider(),
        ),
        ChangeNotifierProvider<WrongBookProvider>(
          create: (_) => WrongBookProvider(),
        ),
        ChangeNotifierProvider<FavoriteProvider>(
          create: (_) => FavoriteProvider(),
        ),
        ChangeNotifierProvider<StatsProvider>(
          create: (_) => StatsProvider(),
        ),
      ],
      child: MaterialApp(
        title: '国家电网刷题助手',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1565C0),
          ),
        ),
        initialRoute: AppRoutes.home,
        routes: <String, WidgetBuilder>{
          AppRoutes.home: (_) => const HomePage(),
          AppRoutes.wrongBook: (_) => const WrongBookPage(),
          AppRoutes.favorites: (_) => const FavoritePage(),
          AppRoutes.stats: (_) => const StatsPage(),
          AppRoutes.settings: (_) => const SettingsPage(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.quiz) {
            final arguments = settings.arguments;
            if (arguments is QuizArguments) {
              return MaterialPageRoute<dynamic>(
                builder: (_) => QuizPage(arguments: arguments),
                settings: settings,
              );
            }
          }
          return null;
        },
      ),
    );
  }
}