import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Colors, DefaultMaterialLocalizations;
import 'package:flutter/services.dart';
import 'core/localization.dart';
import 'core/ui_components.dart';
import 'pages/root_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await initLang();
  await initTheme();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLang>(
      valueListenable: appLang,
      builder: (_, lang, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: isMaterial,
          builder: (_, materialMode, __) {
            return CupertinoApp(
              // Rebuilds the entire widget tree when language or theme changes.
              key: ValueKey('${lang.name}-$materialMode'),
              debugShowCheckedModeBanner: false,
              theme: const CupertinoThemeData(
                brightness: Brightness.light,
                primaryColor: kAccent,
                scaffoldBackgroundColor: Colors.transparent,
              ),
              localizationsDelegates: const [
                DefaultMaterialLocalizations.delegate,
                DefaultCupertinoLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
              ],
              home: const RootPage(),
            );
          },
        );
      },
    );
  }
}
