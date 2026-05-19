import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../data/api_client.dart';
import '../data/token_store.dart';
import '../models/models.dart';
import 'dashboard_screen.dart';
import 'loading_screen.dart';
import 'login_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  final _api = ApiClient();
  final _store = TokenStore();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;
  AuthTokens? _tokens;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _linkSub = _appLinks.uriLinkStream.listen(_handleLink);
    final initialUri = await _appLinks.getInitialLink();
    if (!mounted) return;
    if (initialUri != null) {
      await _handleLink(initialUri);
    } else {
      final tokens = await _store.read();
      if (!mounted) return;
      setState(() {
        _tokens = tokens;
        _loading = false;
      });
    }
  }

  Future<void> _handleLink(Uri uri) async {
    final redirectUri = Uri.parse(mobileRedirectUri);
    final isConfiguredCallback = uri.scheme == redirectUri.scheme &&
        uri.host == redirectUri.host &&
        uri.path == redirectUri.path;
    final isLegacyCallback = uri.scheme == 'runsense' &&
        uri.host == 'auth' &&
        uri.path == '/callback';
    final isAuthCallback = isConfiguredCallback || isLegacyCallback;
    if (!isAuthCallback) return;
    final code = uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error = 'Authorization failed. No Strava code was returned.';
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final tokens = await _api.exchangeCode(code);
      await _store.write(tokens);
      if (!mounted) return;
      setState(() {
        _tokens = tokens;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _connect() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url = await _api.getAuthUrl();
      final launched =
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched) throw ApiException('Could not open Strava authorization.');
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    await _store.clear();
    if (!mounted) return;
    setState(() => _tokens = null);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingScreen(label: 'Loading RunSense...');
    if (_tokens == null) {
      return LoginScreen(error: _error, onConnect: _connect);
    }
    return DashboardScreen(tokens: _tokens!, onReconnect: _signOut);
  }
}
