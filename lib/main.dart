import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app_state.dart';
import 'ui/shell.dart';

/// بنسجل أي خطأ بالتشغيل بملف عشان نعرف السبب لو التطبيق ما فتح.
void _logCrash(Object e, StackTrace? st) {
  try {
    File(p.join(Directory.systemTemp.path, 'ReelsMaker-crash.txt'))
        .writeAsStringSync('${DateTime.now()}\n$e\n$st\n\n', mode: FileMode.append);
  } catch (_) {}
}

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (d) {
      FlutterError.presentError(d);
      _logCrash(d.exception, d.stack);
    };
    try {
      MediaKit.ensureInitialized();
    } catch (e, st) {
      // المشغّل اختياري: التطبيق لازم يفتح حتى لو فشل
      _logCrash(e, st);
    }
    final state = AppState();
    runApp(ReelsMakerApp(state: state, ready: state.init()));
  }, _logCrash);
}

class ReelsMakerApp extends StatelessWidget {
  final AppState state;
  final Future<void> ready;
  const ReelsMakerApp({super.key, required this.state, required this.ready});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7C3AED);
    ThemeData theme(Brightness b) => ThemeData(
          useMaterial3: true,
          brightness: b,
          colorSchemeSeed: seed,
          fontFamily: 'Tajawal',
          inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
        );
    return MaterialApp(
      title: 'صانع الريلز',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: FutureBuilder(
        future: ready,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(
                body: Center(
                    child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('صار خطأ بالتشغيل:\n${snap.error}', textAlign: TextAlign.center),
            )));
          }
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.movie_filter_rounded, size: 72),
                  SizedBox(height: 16),
                  Text('صانع الريلز', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                  SizedBox(height: 16),
                  CircularProgressIndicator(),
                ]),
              ),
            );
          }
          return Shell(state: state);
        },
      ),
    );
  }
}
