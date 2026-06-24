import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'models/message.dart';
import 'api_client.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _sessionId;
  bool _isLoading = false;
  bool _apiReady = false;
  String _statusText = ''; // 思考中 / 调用工具: xxx

  @override
  void initState() {
    super.initState();
    _loadSession();
    _checkApi();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _sessionId = prefs.getString('session_id'));
  }

  Future<void> _saveSession(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_id', id);
    setState(() => _sessionId = id);
  }

  Future<void> _checkApi() async {
    final ok = await HermesApi.checkHealth();
    setState(() => _apiReady = ok);
  }

  void _sendMessage({String? filePath, String? fileName}) async {
    final text = _textController.text.trim();
    final hasFile = filePath != null;
    if (text.isEmpty && !hasFile) return;
    if (_isLoading) return;

    setState(() {
      _messages.add(Message(
        text: hasFile ? '[$fileName] ${text.isNotEmpty ? text : ""}' : text,
        isUser: true,
      ));
      _isLoading = true;
      _statusText = '思考中...';
    });
    _textController.clear();
    _scrollToBottom();

    try {
      final (response, newSid) = await HermesApi.sendMessage(
        text: text.isNotEmpty ? text : '请分析这个文件',
        sessionId: _sessionId,
        filePath: filePath,
        onStatus: (status) {
          setState(() {
            if (status.status == 'thinking') {
              _statusText = '思考中...';
            } else if (status.status == 'calling_tool') {
              _statusText = '调用工具: ${status.toolName ?? "..."}';
            }
          });
        },
      );

      if (newSid != null && _sessionId == null) {
        await _saveSession(newSid);
      }

      setState(() {
        _messages.add(Message(text: response, isUser: false));
        _isLoading = false;
        _statusText = '';
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(Message(text: '连接失败: $e', isUser: false));
        _isLoading = false;
        _statusText = '';
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (image == null) return;
    _sendMessage(filePath: image.path, fileName: '图片');
  }



  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hermes Chat'),
        actions: [
          Icon(_apiReady ? Icons.cloud_done : Icons.cloud_off,
              color: _apiReady ? Colors.green : Colors.red),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                // 加载指示器
                if (_isLoading && index == _messages.length) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _statusText.isNotEmpty ? _statusText : '...',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                final isUser = msg.isUser;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue.shade100 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(msg.text, style: const TextStyle(fontSize: 15)),
                  ),
                );
              },
            ),
          ),
          // 输入栏
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image),
                    onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                    tooltip: '发送图片',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      enabled: !_isLoading,
                      decoration: const InputDecoration(
                        hintText: '输入消息...',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _isLoading ? null : () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
