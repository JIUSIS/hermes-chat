class Message {
  final String text;
  final bool isUser; // true: 用户发的, false: Hermes 回的
  final String? imagePath; // 图片路径（可选）

  Message({required this.text, required this.isUser, this.imagePath});
}
