import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:install_plugin/install_plugin.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

class Onboard extends StatefulWidget {
  final String title;

  const Onboard({super.key, required this.title});

  @override
  State<Onboard> createState() => _OnboardState();
}

class _OnboardState extends State<Onboard> {
  int _counter = 0;

  bool _downloadButtonClicked = false;
  bool downloading = false;
  int _total = 0, _received = 0;
  http.StreamedResponse? _response;
  final List<int> _bytes = [];
  String apkUpdateUrl = '';

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );

  final DatabaseReference _versionReference =
      FirebaseDatabase.instance.ref().child('app_version');

  final DatabaseReference _updateLocationReference =
      FirebaseDatabase.instance.ref().child('url');

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
    _startUpdateListener();
    _startPermissionCheckLoop();
    _startDownloadCheckLoop();
  }

  void _startPermissionCheckLoop() async {
    while (true) {
      final status = await Permission.storage.status;
      if (status.isGranted) {
        _executeFunctionWhenPermissionGranted();
        break; // Exit the loop when permission is granted
      }
      await Future.delayed(const Duration(seconds: 1)); // Check every 1 second
    }
  }

  void _startDownloadCheckLoop() async {
    while (true) {
      final status = await Permission.storage.status;
      if (status.isGranted && _downloadButtonClicked) {
        _downloadButtonClicked = false;
        print("Download event started");
        _downloadAndInstallApp(apkUpdateUrl);
        break; // Exit the loop when permission is granted
      }
      await Future.delayed(const Duration(seconds: 1)); // Check every 1 second
    }
  }

  void _executeFunctionWhenPermissionGranted() {
    print('Storage permission granted. Executing function...');
    // _showToast();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  bool isUpdateAvailable(String latestVersion) {
    return _packageInfo.version != latestVersion;
  }

  Future<String> getLatestVersion() async {
    final snapshot = await _versionReference.get();
    if (snapshot.exists) {
      return snapshot.value.toString();
    } else {
      return 'No data available.';
    }
  }

  Future<String> getUpdateApkUrl() async {
    final snapshot = await _updateLocationReference.get();
    if (snapshot.exists) {
      return snapshot.value.toString();
    } else {
      return 'No data available.';
    }
  }

  void _startUpdateListener() {
    _versionReference.onValue.listen((DatabaseEvent event) async {
      String latestVersion = await getLatestVersion();
      if (isUpdateAvailable(latestVersion)) {
        apkUpdateUrl = await getUpdateApkUrl();
        _showUpdateDialog(latestVersion);
      }
    });
  }

  Widget _infoTile(String title, String subtitle) {
    return ListTile(
      title: Text(title),
      subtitle: Text(
        subtitle.isEmpty ? 'Not set' : subtitle,
        style: const TextStyle(
            fontSize: 25, fontWeight: FontWeight.w600, color: Colors.green),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = _total > 0 ? _received / _total : 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        child: downloading
            ? Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 100,
                    ),
                    CircularProgressIndicator(value: progress),
                    const SizedBox(height: 20),
                    Text('Progress: ${(progress * 100).toStringAsFixed(2)}%'),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'Welcome to the Updates Demo App. You can keep yourself busy with the floating button below while we check for updates. Will notify you when once find any. The app automatically checks for updates all the time',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  const Text(
                    "App Info",
                    style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w600,
                        color: Colors.red),
                  ),
                  _infoTile('Current App version', _packageInfo.version),
                  _infoTile('Build number', _packageInfo.buildNumber),
                  const SizedBox(
                    height: 30,
                  ),
                  const Text(
                    'You have pushed the button this many times:',
                  ),
                  Text(
                    '$_counter',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(
                    height: 50,
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _incrementCounter();
          _startUpdateListener(); // Check for updates when button is pressed
        },
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showUpdateDialog(String version) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Update Available',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(
                height: 20,
              ),
              const Text('What`s new?'),
              const SizedBox(
                height: 15,
              ),
              Text('Version: $version'),
              const SizedBox(
                height: 40,
              ),
              ElevatedButton(
                  onPressed: () async {
                    _downloadButtonClicked = true;
                    Navigator.pop(context);
                    bool hasPermission = await _checkStoragePermission();

                    if (hasPermission) {
                      print("Permission granted already");
                      print("Download event started");
                      _downloadAndInstallApp(apkUpdateUrl);
                      _downloadButtonClicked = false;
                      //_downloadAndInstallApp();
                    } else {
                      _permissionDialog();
                    }

                    // Initiate download and update process
                    // Show download progress and install dialog
                    // Handle download and installation
                  },
                  child: const Row(
                    children: [Spacer(), Text("Update Now"), Spacer()],
                  )),
              const SizedBox(
                height: 3,
              ),
              ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Next launch download process ...
                  },
                  child: const Row(
                    children: [
                      Spacer(),
                      Text("Update on next launch"),
                      Spacer()
                    ],
                  )),
              const SizedBox(
                height: 3,
              ),
              OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Row(
                    children: [
                      Spacer(),
                      Text("Skip this version"),
                      SizedBox(
                        width: 15,
                      ),
                      Icon(Icons.arrow_forward_ios),
                      Spacer()
                    ],
                  )),
            ],
          ),
        );
      },
    );
  }

  void _permissionDialog() {
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

  void _showToast() {
    Fluttertoast.showToast(
      msg: "Permission granted! Please return to the app.",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.grey[600],
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<bool> _checkStoragePermission() async {
    // Check if the storage permission is granted
    PermissionStatus status = await Permission.storage.status;
    return status == PermissionStatus.granted;
  }

  Future<void> _downloadAndInstallApp(String url) async {
    setState(() {
      downloading = true;
      _received = 0;
      _total = 0;
      _bytes.clear();
      _response = null;
    });

    _response = await http.Client().send(http.Request('GET', Uri.parse(url)));
    _total = _response!.contentLength ?? 0;

    _response!.stream.listen((value) {
      setState(() {
        _bytes.addAll(value);
        _received += value.length;
      });
    }).onDone(() async {
      final file =
          File('${(await getApplicationDocumentsDirectory()).path}/app.apk');
      await file.writeAsBytes(_bytes);
      if (await file.exists()) {
        setState(() {
          downloading = false;
        });
        await openInstaller(file);
        // print('APK downloaded and installed.');
      }
    });
  }

  Future<void> openInstaller(File file) async {
    if (Platform.isAndroid) {
      await InstallPlugin.installApk(file.path,
          appId: 'com.example.demo_update');
    }
  }
}
