// lib/features/ai/screens/ai_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/ai_provider.dart';
import '../../inventory/services/inventory_repo_service.dart';
import '../../feedback/services/feedback_service.dart';

class AiChatScreen extends StatefulWidget {
  final String? userMobile;
  const AiChatScreen({Key? key, this.userMobile}) : super(key: key);

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    if (_isInitialized) return;
    
    try {
      final aiProvider = Provider.of<AIProvider>(context, listen: false);
      final userMobile = widget.userMobile;
      
      if (userMobile == null || userMobile.isEmpty) {
        setState(() {
          _messages.add(ChatMessage(
            content: '⚠️ Please log in to use the AI assistant.',
            isUser: false,
          ));
        });
        _isInitialized = true;
        return;
      }
      
      print('📱 AI Chat Screen - Initializing with user: $userMobile');
      
      // Initialize AI Provider if not already initialized
      if (!aiProvider.isInitialized) {
        // FIXED: Use positional argument, not named parameter
        final inventoryService = InventoryService(userMobile); // ← FIXED
        final feedbackService = FeedbackService(userMobile);   // ← FIXED
        
        await aiProvider.initialize(
          inventoryService,
          feedbackService: feedbackService,
          userMobile: userMobile,
        );
      } else if (aiProvider.sarvamService != null) {
        // Update user mobile if already initialized
        aiProvider.sarvamService!.setUserMobile(userMobile);
        if (aiProvider.sarvamService != null) {
          final feedbackService = FeedbackService(userMobile);
          aiProvider.sarvamService!.setFeedbackService(feedbackService);
        }
      }
      
      print('✅ AI Chat Screen - Initialized successfully');
      
      // Add welcome message with actual data
      if (aiProvider.isAvailable && aiProvider.sarvamService != null) {
        final response = await aiProvider.sarvamService!.queryInventory('help');
        setState(() {
          _messages.add(ChatMessage(content: response, isUser: false));
        });
      } else {
        setState(() {
          _messages.add(ChatMessage(
            content: '👋 Hello! I\'m your AI inventory assistant.\n\n'
                'Type "help" to see what I can do for you!\n\n'
                '⚠️ Note: AI service is currently unavailable. Please check your configuration.',
            isUser: false,
          ));
        });
      }
    } catch (e) {
      print('❌ AI Chat Screen - Error: $e');
      setState(() {
        _messages.add(ChatMessage(
          content: '❌ Failed to initialize AI assistant: $e\n\nPlease try again or contact support.',
          isUser: false,
        ));
      });
    } finally {
      setState(() => _isInitialized = true);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final userMessage = _messageController.text.trim();
    setState(() {
      _messages.add(ChatMessage(content: userMessage, isUser: true));
      _messageController.clear();
      _isLoading = true;
    });
    
    _scrollToBottom();

    try {
      final aiProvider = Provider.of<AIProvider>(context, listen: false);
      
      if (!aiProvider.isAvailable || aiProvider.sarvamService == null) {
        setState(() {
          _messages.add(ChatMessage(
            content: '⚠️ AI assistant is not available. Please check your configuration.\n\nError: ${aiProvider.errorMessage}',
            isUser: false,
          ));
        });
      } else {
        final response = await aiProvider.sarvamService!
            .queryInventory(userMessage);
        
        setState(() {
          _messages.add(ChatMessage(content: response, isUser: false));
        });
      }
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _messages.add(ChatMessage(
          content: '❌ Sorry, I encountered an error: $e\n\nPlease try again or type "help" for assistance.',
          isUser: false,
        ));
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Consumer<AIProvider>(
            builder: (context, aiProvider, child) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: aiProvider.isAvailable ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        aiProvider.isAvailable ? 'Online' : 'Offline',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _messages.clear();
                _isInitialized = false;
              });
              _initializeAI();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message, isDark);
              },
            ),
          ),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isDark) {
    final isUser = message.isUser;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.blue,
              child: Icon(Icons.smart_toy, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser 
                    ? (isDark ? Colors.blue.shade700 : Colors.blue.shade100)
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: SelectableText(
                message.content,
                style: TextStyle(
                  color: isUser 
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.green,
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 4,
            color: Colors.black12,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Ask me anything...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? Colors.grey.shade800
                    : Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _sendMessage(),
              enabled: !_isLoading,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: theme.primaryColor,
            child: IconButton(
              icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String content;
  final bool isUser;
  
  ChatMessage({required this.content, required this.isUser});
}