import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:install_plugin/install_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(
        title: 'Update App Demo',
        onPermissionGranted: () {
          print('Permission granted! You can now proceed with the app logic.');
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

typedef PermissionCallback = void Function();

class MyHomePage extends StatefulWidget {
  final PermissionCallback onPermissionGranted;
  const MyHomePage(
      {super.key, required this.title, required this.onPermissionGranted});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool downloading = false;

  Future<void> _downloadAndInstallApp() async {
    setState(() {
      downloading = true;
    });
    const apkUrl =
        'https://firebasestorage.googleapis.com/v0/b/update-de78d.appspot.com/o/app-release.apk?alt=media&token=36d8763f-7ba9-4aa5-9100-2c11c5547c55';

    final response = await http.get(Uri.parse(apkUrl));

    if (response.statusCode == 200) {
      final appDir = await getExternalStorageDirectory();
      final file = File('${appDir?.path}/app.apk');

      await file.writeAsBytes(response.bodyBytes);

      // After downloading, prompt the user to install the APK
      if (await file.exists()) {
        await openInstaller(file);
      }
    }
  }

  Future<void> openInstaller(File file) async {
    if (Platform.isAndroid) {
      // Use the package_info_plus plugin to get package info
      // to determine if the app installer should be shown
      // Install the package_info_plus package by adding it to your pubspec.yaml

      // Import the package
      // import 'package:package_info_plus/package_info_plus.dart';

      // final packageInfo = await PackageInfo.fromPlatform();
      // final version = int.parse(packageInfo.buildNumber);

      // Uncomment the above lines and add the condition for version check
      // if (version < YOUR_MINIMUM_VERSION) {
      // Only show the installer if the app is not already installed or the version is outdated
      await InstallPlugin.installApk(file.path,
          appId: 'com.example.demo_update');
      // }
    }
  }

  Future<bool> _checkStoragePermission() async {
    // Check if the storage permission is granted
    PermissionStatus status = await Permission.storage.status;
    return status == PermissionStatus.granted;
  }

  void _onDownloadButtonPressed(BuildContext context) async {
    bool hasPermission = await _checkStoragePermission();

    if (hasPermission) {
      _downloadAndInstallApp();
    } else {
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content:
                const Text('We need permission to download the latest version'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings(); // Open app settings manually
                },
                child: const Text('Go to settings'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );
    }
  }

  // // This method will be called when the app comes to the foreground (resumes)
  // @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   if (state == AppLifecycleState.resumed) {
  //     // Check the permission status again when the app resumes
  //     _checkPermissionStatus();
  //   }
  // }

  // Helper method to check the permission status
  // Future<void> _checkPermissionStatus() async {
  //   final status = await Permission.storage.status;
  //   if (status == PermissionStatus.granted) {
  //     // Execute your function when the permission is already granted
  //     _executeFunction();
  //   }
  // }

  //   void _executeFunction() {
  //   // Your function to be executed after permission is granted
  //   print('Function executed successfully!');
  //   // _downloadAndInstallApp();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color.fromARGB(120, 189, 189, 189)),
              child: downloading
                  ? Column(
                      children: const [
                        Text("Downloading"),
                        SizedBox(
                          height: 20,
                        ),
                        CircularProgressIndicator()
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text("New Update is Available"),
                        const SizedBox(
                          height: 35,
                        ),
                        ElevatedButton(
                            onPressed: () {
                              _onDownloadButtonPressed(context);
                            },
                            child: const Text("Update Now")),
                        ElevatedButton(
                            onPressed: () {},
                            child: const Text("Update on next Launch")),
                      ],
                    ),
            ),
            const SizedBox(
              height: 20,
            ),
            TextButton(onPressed: () {}, child: const Text("Skip >>"))
          ],
        ),
      ),
    );
  }
}
