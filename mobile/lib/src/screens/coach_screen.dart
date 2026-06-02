import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../data/api_client.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, required this.tokens});
  final AuthTokens tokens;
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _api = ApiClient();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<String> _starters = [];
  List<ChatMessage> _messages = [];
  List<dynamic> _history = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStarters();
  }

  Future<void> _loadStarters() async {
    final starters = await _api.starters();
    if (!mounted) return;
    setState(() => _starters = starters);
  }

  Future<void> _submit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;
    setState(() {
      _messages = [
        ..._messages,
        ChatMessage.user(trimmed),
        ChatMessage.loading()
      ];
      _loading = true;
      _controller.clear();
    });
    try {
      final result = await _api.sendMessage(
        message: trimmed,
        accessToken: widget.tokens.accessToken,
        history: _history,
      );
      if (!mounted) return;
      setState(() {
        _history = result.history;
        _messages = [
          ..._messages.take(_messages.length - 1),
          ChatMessage.assistant(result.response)
        ];
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages.take(_messages.length - 1),
          ChatMessage.assistant(
              'Something went wrong. Check your connection and try again.')
        ];
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        unawaited(Future<void>.delayed(const Duration(milliseconds: 80), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
        }));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.all(18),
            children: [
              if (_messages.isEmpty) ...[
                const Text('DATA COACH', style: KickerStyle.text),
                const SizedBox(height: 10),
                Text(
                    'Ask the hard question, ${widget.tokens.athleteName.split(' ').first}.',
                    style: const TextStyle(
                        fontSize: 36, height: .9, fontWeight: FontWeight.w900)),
                const SizedBox(height: 14),
                const Text(
                    'Ask anything about your training. RunSense pulls real data before answering.',
                    style: TextStyle(color: AppColors.muted, height: 1.45)),
                const SizedBox(height: 16),
                ..._starters.map((starter) => StarterButton(
                    label: starter, onTap: () => _submit(starter))),
              ],
              ..._messages.map(MessageBubble.new),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_loading,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your training...',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                          borderSide: BorderSide(color: AppColors.border)),
                    ),
                    onSubmitted: _submit,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _loading ? null : () => _submit(_controller.text),
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class StarterButton extends StatelessWidget {
  const StarterButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border))),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColors.foreground)),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble(this.message, {super.key});
  final ChatMessage message;
  @override
  Widget build(BuildContext context) {
    if (message.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(color: AppColors.accent),
      );
    }
    if (message.role == ChatRole.user) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(12),
          color: AppColors.accent,
          child: Text(message.text,
              style: const TextStyle(
                  color: AppColors.background, fontWeight: FontWeight.w800)),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.only(left: 14),
      decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: AppColors.accent, width: 3))),
      child: MarkdownBody(
        data: message.text,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: const TextStyle(height: 1.55, color: AppColors.foreground),
          strong: const TextStyle(
              color: AppColors.accent, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
