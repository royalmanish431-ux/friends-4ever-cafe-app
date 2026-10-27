import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
    home: FriendsCafeApp(),
    debugShowCheckedModeBanner: false,
  ));
}

class FriendsCafeApp extends StatefulWidget {
  const FriendsCafeApp({super.key});

  @override
  State<FriendsCafeApp> createState() => _FriendsCafeAppState();
}

class _FriendsCafeAppState extends State<FriendsCafeApp> {
  late final WebViewController controller;
  bool isOffline = false;
  bool isLoading = true;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

  final String targetUrl = 'https://friend4evercoffee.netlify.app/';

  @override
  void initState() {
    super.initState();
    _requestPermissions();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFFFFFFF))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              isLoading = true;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              isLoading = false;
              if (url.startsWith('http')) {
                isOffline = false;
              }
            });
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? true) {
              setState(() {
                isOffline = true;
                isLoading = false;
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final String url = request.url;

            // WhatsApp, Call, SMS, Email Links
            if (url.startsWith('whatsapp://') ||
                url.startsWith('intent://') ||
                url.startsWith('https://wa.me/') ||
                url.startsWith('https://api.whatsapp.com/') ||
                url.startsWith('tel:') ||
                url.startsWith('mailto:') ||
                url.startsWith('sms:')) {
              final Uri uri = Uri.parse(url);
              try {
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
                }
              } catch (_) {
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              }
              return NavigationDecision.prevent;
            }

            // PDF Bill Download / Open handler
            if (url.endsWith('.pdf') ||
                url.contains('.pdf?') ||
                url.contains('/pdf') ||
                url.startsWith('blob:') ||
                url.startsWith('data:application/pdf')) {
              final Uri uri = Uri.parse(url);
              try {
                // PDF ko system default PDF viewer / browser me launch karega
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );

    _checkInitialConnectivity();

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final bool hasNoConnection = results.contains(ConnectivityResult.none);
      if (hasNoConnection) {
        setState(() {
          isOffline = true;
        });
      } else if (isOffline) {
        setState(() {
          isOffline = false;
        });
        controller.loadRequest(Uri.parse(targetUrl));
      }
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.microphone,
    ].request();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      setState(() {
        isOffline = true;
      });
    } else {
      controller.loadRequest(Uri.parse(targetUrl));
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: controller),

            // Splash Screen
            if (isLoading && !isOffline)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.coffee_rounded, size: 80, color: Color(0xFFD97706)),
                      SizedBox(height: 16),
                      Text(
                        'Friends 4ever cafe',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD97706),
                        ),
                      ),
                      SizedBox(height: 24),
                      CircularProgressIndicator(color: Color(0xFFD97706)),
                    ],
                  ),
                ),
              ),

            // Offline Screen
            if (isOffline)
              Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 50, color: Colors.grey),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() => isOffline = false);
                          _checkInitialConnectivity();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
