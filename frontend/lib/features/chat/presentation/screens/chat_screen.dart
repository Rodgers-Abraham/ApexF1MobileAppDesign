import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../shared/theme/theme_provider.dart';
import '../../../../core/utils/api_config.dart';
import '../../../../shared/widgets/pro_gate.dart';

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
  final int freeMessagesUsed;
  final String? error;

  ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.freeMessagesUsed = 0,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    int? freeMessagesUsed,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      freeMessagesUsed: freeMessagesUsed ?? this.freeMessagesUsed,
      error: error,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.baseUrl));

  ChatNotifier(this._ref) : super(ChatState()) {
    // Initial welcome message from the assistant
    state = ChatState(
      messages: [
        ChatMessage(
          text: "Hi! I am F1-IQ, your strictly Formula 1 AI assistant. Ask me anything about F1 history, statistics, standings, rules, or telemetry. What's on your mind today?",
          isUser: false,
        )
      ]
    );
  }

  Future<void> sendMessage(String text) async {
    final auth = _ref.read(authProvider);
    
    // Check free message limits
    if (!auth.isPro && state.freeMessagesUsed >= 7) {
      state = state.copyWith(error: "Daily free message limit reached. Upgrade to Pro for unlimited access!");
      return;
    }

    final userMsg = ChatMessage(text: text, isUser: true);
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isLoading: true,
      error: null,
    );

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
        },
      );

      final responseText = response.data['response'] as String;

      // Extract citations (e.g. searching for text inside square brackets [Ergast API] or [OpenF1])
      final citationRegex = RegExp(r'\[([^\]]+)\]');
      final citations = citationRegex.allMatches(responseText).map((m) => m.group(1)!).toList();
      
      // Clean text of citation brackets if needed, or leave it for display
      final cleanedText = responseText;

      final assistantMsg = ChatMessage(
        text: cleanedText,
        isUser: false,
        citations: citations,
      );

      state = state.copyWith(
        messages: [...state.messages, assistantMsg],
        isLoading: false,
        freeMessagesUsed: auth.isPro ? 0 : state.freeMessagesUsed + 1,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to connect to F1-IQ server. Please try again.",
      );
    }
  }

  void resetLimit() {
    state = state.copyWith(freeMessagesUsed: 0, error: null);
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
        curve: Curves.easeOut,
      );
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
    final themeState = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);
    final chatState = ref.watch(chatNotifierProvider);
    final accentColor = themeState.selectedTeam.primaryColor;

    final isLimitReached = !authState.isPro && chatState.freeMessagesUsed >= 7;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.psychology_rounded, color: accentColor, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('F1-IQ CHATBOT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Strictly F1 Expert Assistant', style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          if (!authState.isPro)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Text(
                    '${7 - chatState.freeMessagesUsed} FREE LEFT',
                    style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // If limit reached, show ProGate style paywall prompt banner
          if (isLimitReached)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.amber.withOpacity(0.08),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_clock, color: Colors.amber),
                      SizedBox(width: 8),
                      Text(
                        'Daily Free Limits Reached',
                        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unlock unlimited chatbot access and interactive ML predictions with Apex Pro.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      ref.read(authProvider.notifier).upgradeToPro();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    ),
                    child: const Text('Upgrade for \$3.99/mo', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: chatState.messages.length + (chatState.isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == chatState.messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E1E),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final msg = chatState.messages[index];
                return Align(
                  alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: msg.isUser ? accentColor : const Color(0xFF161616),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
                        bottomRight: Radius.circular(msg.isUser ? 4 : 16),
                      ),
                      border: msg.isUser 
                          ? null
                          : Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg.text,
                          style: TextStyle(
                            color: msg.isUser ? Colors.white : const Color(0xFFE1E1E1),
                            fontSize: 14.5,
                            height: 1.4,
                          ),
                        ),
                        if (msg.citations.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: msg.citations.map((cite) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: accentColor.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bookmark_outline, size: 10, color: accentColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      cite,
                                      style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (chatState.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                chatState.error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
            
          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F0F),
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !isLimitReached,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: isLimitReached ? 'Daily limit reached. Upgrade to ask more.' : 'Ask about driver history, rules, schedules...',
                      hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF161616),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: isLimitReached ? null : _send,
                  icon: Icon(Icons.send_rounded, color: isLimitReached ? Colors.grey : accentColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
