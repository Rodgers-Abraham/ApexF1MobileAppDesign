import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../shared/theme/app_design_system.dart';
import '../../../../shared/widgets/ds_app_bar.dart';
import '../../../../shared/widgets/skeleton_widget.dart';
import '../../../../core/utils/api_config.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<String> citations;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.citations = const [],
  });
}

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error);
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  ChatNotifier(Ref ref) : super(ChatState()) {
    // Initial welcome message from the assistant
    state = ChatState(
      messages: [
        ChatMessage(
          text: "Hi! I am F1-IQ, your strictly Formula 1 AI assistant. Ask me anything about F1 history, statistics, standings, rules, or telemetry. What's on your mind today?",
          isUser: false)
      ]
    );
  }

  Future<void> sendMessage(String text) async {
    final userMsg = ChatMessage(text: text, isUser: true);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null);

    // Format chat history for backend (matching ChatMessage structure in FastAPI)
    final history = state.messages.sublist(0, state.messages.length - 1).map((m) {
      return {
        'role': m.isUser ? 'user' : 'model',
        'parts': [{'text': m.text}]
      };
    }).toList();

    try {
      final response = await _dio.post(
        '/api/chat',
        data: {
          'message': text,
          'history': history,
        });

      final responseText = response.data['response'] as String;

      // Extract citations (e.g. searching for text inside square brackets [Ergast API] or [OpenF1])
      final citationRegex = RegExp(r'\[([^\]]+)\]');
      final citations = citationRegex.allMatches(responseText).map((m) => m.group(1)!).toList();
      
      // Clean text of citation brackets if needed, or leave it for display
      final cleanedText = responseText;

      final assistantMsg = ChatMessage(
        text: cleanedText,
        isUser: false,
        citations: citations);

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to connect to F1-IQ server. Please try again.");
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

final chatNotifierProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier(ref);
});

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(chatNotifierProvider.notifier).sendMessage(text);
    
    // Auto scroll to bottom after frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeProvider); // keep theme subscription alive
    final chatState = ref.watch(chatNotifierProvider);

    final suggestions = [
      'Who leads the 2026 championship points?',
      'Best tyre strategy for Interlagos in wet?',
      'Explain DRS zones & flap aero limits',
      'Compare Verstappen vs Norris telemetry',
    ];

    return Scaffold(
      backgroundColor: DS.bg,
      appBar: DSAppBar(
        subtitle: 'APEX INTELLIGENCE',
        isLive: true,
        liveLabel: 'GEMINI',
        latencyMs: '12'),
      body: Column(
        children: [
          // Track status bar
          Container(
            color: DS.surface0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(color: DS.green, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('TRACK STATUS: GREEN', style: DS.labelCaps(size: 8, color: DS.green)),
                Text('  //  AIR 26°C · TRACK 38.4°C  |  ENGINE ACTIVE', style: DS.labelCaps(size: 8, color: DS.textMuted)),
              ])),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: chatState.messages.length == 1
                  ? chatState.messages.length + 1  // +1 for suggestions
                  : chatState.messages.length + (chatState.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                // Show AI identity card + suggestions after first message
                if (chatState.messages.length == 1 && index == 1) {
                  return _buildSuggestionsPanel(suggestions);
                }

                if (chatState.isLoading && index == chatState.messages.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AiAvatar(),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: DS.surface2, borderRadius: DS.aeroCorner, border: Border.all(color: DS.outline)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SkeletonBox(height: 10, borderRadius: 3),
                                const SizedBox(height: 8),
                                const SkeletonBox(height: 10, borderRadius: 3),
                                const SizedBox(height: 6),
                                SkeletonBox(width: MediaQuery.of(context).size.width * 0.5, height: 10, borderRadius: 3),
                              ]))),
                      ]));
                }

                final msg = chatState.messages[index];
                if (msg.isUser) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: DS.red, borderRadius: DS.aeroCorner),
                      child: Text(msg.text, style: DS.body(size: 13, color: DS.redText))));
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AiAvatar(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: DS.surface2, borderRadius: DS.aeroCorner, border: Border.all(color: DS.outline)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('APEX AI INSIGHT', style: DS.labelCaps(size: 8, color: DS.teal)),
                              const SizedBox(height: 6),
                              Text(msg.text, style: DS.body(size: 13, color: DS.textPrimary)),
                              if (msg.citations.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6, runSpacing: 4,
                                  children: msg.citations.map((cite) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: DS.surface3, borderRadius: DS.aeroCornerSm, border: Border.all(color: DS.outline)),
                                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                                        const Icon(Icons.bookmark_outline, size: 9, color: Color(0xFF29DEC9)),
                                        const SizedBox(width: 3),
                                        Text(cite, style: DS.labelCaps(size: 8, color: DS.teal)),
                                      ]));
                                  }).toList())
                              ],
                            ]))),
                    ]));
              })),

          if (chatState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: DS.red.withValues(alpha: 0.1), borderRadius: DS.aeroCornerSm, border: Border.all(color: DS.red.withValues(alpha: 0.4))),
                child: Text(chatState.error!, style: DS.body(size: 11, color: DS.red)))),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: DS.surface0,
              border: Border(top: BorderSide(color: DS.outline))),
            child: Row(
              children: [
                Icon(Icons.mic_none, size: 20, color: DS.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: DS.body(size: 13, color: DS.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask telemetry, rules, or strategy...',
                      hintStyle: DS.body(size: 13, color: DS.textMuted),
                      filled: true,
                      fillColor: DS.surface1,
                      border: OutlineInputBorder(borderRadius: DS.aeroCorner, borderSide: BorderSide(color: DS.outline)),
                      enabledBorder: OutlineInputBorder(borderRadius: DS.aeroCorner, borderSide: BorderSide(color: DS.outline)),
                      focusedBorder: OutlineInputBorder(borderRadius: DS.aeroCorner, borderSide: BorderSide(color: DS.red)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send())),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: DS.red, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18))),
              ])),
        ]));
  }

  Widget _buildSuggestionsPanel(List<String> suggestions) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI card
          DSWidgets.leftAccentCard(
            accent: DS.orange,
            bgColor: DS.surface1,
            child: Row(
              children: [
                _AiAvatar(),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('Apex Chief Strategist', style: DS.headlineMd(size: 13)),
                        const SizedBox(width: 6),
                        DSWidgets.statusChip('V1.5 PRO', color: DS.orange, size: 8),
                      ]),
                      const SizedBox(height: 4),
                      Text('Pitwall telemetry analysis, strategy simulation and F1 history ready for query.', style: DS.body(size: 11)),
                    ])),
              ])),
          const SizedBox(height: 12),
          // Suggestion chips
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 2.5, crossAxisSpacing: 8, mainAxisSpacing: 8),
            itemCount: suggestions.length,
            itemBuilder: (_, i) => GestureDetector(
              onTap: () {
                _controller.text = suggestions[i];
                _send();
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DS.surface2,
                  borderRadius: DS.aeroCornerSm,
                  border: Border(left: BorderSide(color: DS.red, width: 2))),
                child: Row(
                  children: [
                    Expanded(child: Text(suggestions[i], style: DS.body(size: 10, color: DS.textVariant))),
                    Icon(Icons.arrow_forward, size: 12, color: DS.textMuted),
                  ])))),
        ]));
  }

}

class _AiAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(color: DS.tealDark, borderRadius: DS.aeroCornerSm),
      alignment: Alignment.center,
      child: Text('A', style: DS.driverCode(size: 13, color: DS.teal)));
  }
}
